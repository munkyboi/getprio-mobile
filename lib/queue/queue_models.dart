enum TicketStatus {
  waiting,
  pendingCarryOver,
  called,
  served,
  skipped,
  cancelled,
  unserved,
  expired,
  unknown;

  static TicketStatus parse(Object? value) {
    return switch (value) {
      'waiting' => waiting,
      'pending_carry_over' => pendingCarryOver,
      'called' => called,
      'served' => served,
      'skipped' => skipped,
      'cancelled' => cancelled,
      'unserved' => unserved,
      'expired' => expired,
      _ => unknown,
    };
  }

  String get label => switch (this) {
    waiting => 'Waiting',
    pendingCarryOver => 'Carried over',
    called => 'Called',
    served => 'Served',
    skipped => 'Skipped',
    cancelled => 'Cancelled',
    unserved => 'Unserved',
    expired => 'Expired',
    unknown => 'Unavailable',
  };

  bool get isActive =>
      this == waiting || this == pendingCarryOver || this == called;
}

class QueueTicket {
  const QueueTicket({
    required this.id,
    required this.lookupCode,
    required this.ticketNumber,
    required this.customerName,
    required this.status,
    this.verificationCode,
    this.position,
    this.estimatedWaitMinutes,
    this.queueLength,
    this.queueUpdatedAt,
    this.joinedAt,
    this.vendorName,
    this.locationName,
    this.tenantSlug,
    this.locationSlug,
    this.statusReason,
    this.carryOverExpiresAt,
    this.customerConfirmedAt,
  });

  final String id;
  final String lookupCode;
  final String? ticketNumber;
  final String customerName;
  final TicketStatus status;
  final String? verificationCode;
  final int? position;
  final int? estimatedWaitMinutes;
  final int? queueLength;
  final DateTime? queueUpdatedAt;
  final DateTime? joinedAt;
  final String? vendorName;
  final String? locationName;
  final String? tenantSlug;
  final String? locationSlug;
  final String? statusReason;
  final DateTime? carryOverExpiresAt;
  final DateTime? customerConfirmedAt;

  bool get isActive => status.isActive;

  /// A vendor scan confirms the customer's arrival without serving the ticket.
  /// The API deliberately keeps the lifecycle status as `called` until staff
  /// completes service, so this is a customer-facing display state.
  bool get isConfirmed =>
      status == TicketStatus.called && customerConfirmedAt != null;

  String get displayStatusLabel => isConfirmed ? 'Confirmed' : status.label;

  bool get canBeCancelled =>
      status == TicketStatus.waiting || status == TicketStatus.pendingCarryOver;

  String? get customerFriendlyStatusReason =>
      customerFriendlyTicketReason(statusReason);

  factory QueueTicket.fromJson(Map<String, dynamic> json) {
    final status = TicketStatus.parse(json['status']);
    final rawPosition = _asInt(json['position']);
    final rawWait = _asInt(json['estimatedWaitMinutes']);
    final rawQueueLength = _asInt(json['queueLength']);
    return QueueTicket(
      id: _asString(json['id']) ?? '',
      lookupCode: _asString(json['lookupCode']) ?? '',
      ticketNumber: _asString(json['ticketNumber']),
      customerName:
          _firstNonBlank([
            json['customerDisplayName'] as String?,
            json['customerName'] as String?,
          ]) ??
          'Customer',
      status: status,
      verificationCode: _asString(json['verificationCode']),
      position: status == TicketStatus.waiting ? rawPosition : null,
      estimatedWaitMinutes: status == TicketStatus.waiting ? rawWait : null,
      queueLength: status == TicketStatus.waiting ? rawQueueLength : null,
      queueUpdatedAt: _asDate(json['queueUpdatedAt']),
      joinedAt: _asDate(json['joinedAt'] ?? json['createdAt']),
      vendorName: _firstNonBlank([
        json['vendorName'] as String?,
        json['tenantName'] as String?,
        json['businessName'] as String?,
      ]),
      locationName: json['locationName'] as String?,
      tenantSlug:
          json['tenantSlug'] as String? ?? json['vendorSlug'] as String?,
      locationSlug: json['locationSlug'] as String?,
      statusReason: json['statusReason'] as String?,
      carryOverExpiresAt: _asDate(json['carryOverExpiresAt']),
      customerConfirmedAt: _asDate(json['customerConfirmedAt']),
    );
  }

  QueueTicket copyWith({
    String? verificationCode,
    String? vendorName,
    String? locationName,
    String? tenantSlug,
    String? locationSlug,
  }) {
    return QueueTicket(
      id: id,
      lookupCode: lookupCode,
      ticketNumber: ticketNumber,
      customerName: customerName,
      status: status,
      verificationCode: verificationCode ?? this.verificationCode,
      position: position,
      estimatedWaitMinutes: estimatedWaitMinutes,
      queueLength: queueLength,
      queueUpdatedAt: queueUpdatedAt,
      joinedAt: joinedAt,
      vendorName: vendorName ?? this.vendorName,
      locationName: locationName ?? this.locationName,
      tenantSlug: tenantSlug ?? this.tenantSlug,
      locationSlug: locationSlug ?? this.locationSlug,
      statusReason: statusReason,
      carryOverExpiresAt: carryOverExpiresAt,
      customerConfirmedAt: customerConfirmedAt,
    );
  }
}

String? customerFriendlyTicketReason(String? reason) {
  final normalized = reason?.trim();
  if (normalized == null || normalized.isEmpty) return null;

  return switch (normalized) {
    'queue_closed_carry_over_offered' => 'The queue closed before your turn. Your ticket was saved for the next eligible queue day.',
    'queue_closed_while_called' =>
      'The queue closed before your ticket could be served.',
    'queue_closed_after_skip' =>
      'The queue closed after your ticket was skipped.',
    'carry_over_day_closed' =>
      'Your carry-over ticket expired when the queue day closed.',
    'carry_over_window_expired' =>
      'Your carry-over opportunity expired before you were served.',
    'carry_over_declined' => 'You cancelled this ticket.',
    'customer_cancelled' => 'You cancelled this ticket.',
    _ => _humanizeTicketReason(normalized),
  };
}

String _humanizeTicketReason(String reason) {
  final words = reason
      .split('_')
      .where((word) => word.isNotEmpty)
      .map((word) => word.toLowerCase())
      .toList();
  if (words.isEmpty) return 'Ticket status updated.';
  final text = words.join(' ');
  return '${text[0].toUpperCase()}${text.substring(1)}.';
}

class QueueDayStatus {
  const QueueDayStatus({
    this.state,
    this.availabilityReason,
    this.intakeMode,
    this.isClosed = false,
    this.isPaused = false,
    this.serverNow,
  });

  final String? state;
  final String? availabilityReason;
  final String? intakeMode;
  final bool isClosed;
  final bool isPaused;
  final DateTime? serverNow;

  factory QueueDayStatus.fromJson(Map<String, dynamic>? json) {
    return QueueDayStatus(
      state: json?['state'] as String?,
      availabilityReason: json?['availabilityReason'] as String?,
      intakeMode: json?['intakeMode'] as String?,
      isClosed: json?['isClosed'] as bool? ?? false,
      isPaused: json?['isPaused'] as bool? ?? false,
      serverNow: _asDate(json?['serverNow']),
    );
  }
}

class QueueIntakeStatus {
  const QueueIntakeStatus({
    this.state,
    this.stateLabel,
    this.currentWaitingCount = 0,
  });

  final String? state;
  final String? stateLabel;
  final int currentWaitingCount;

  factory QueueIntakeStatus.fromJson(Map<String, dynamic>? json) {
    return QueueIntakeStatus(
      state: json?['state'] as String?,
      stateLabel: json?['stateLabel'] as String?,
      currentWaitingCount: _asInt(json?['currentWaitingCount']) ?? 0,
    );
  }
}

class QueueStats {
  const QueueStats({
    this.waitingCount = 0,
    this.servedToday = 0,
    this.currentTicketNumber,
    this.estimatedWaitMinutes = 0,
  });

  final int waitingCount;
  final int servedToday;
  final String? currentTicketNumber;
  final int estimatedWaitMinutes;

  factory QueueStats.fromJson(Map<String, dynamic>? json) {
    return QueueStats(
      waitingCount: _asInt(json?['waitingCount']) ?? 0,
      servedToday: _asInt(json?['servedToday']) ?? 0,
      currentTicketNumber: _asString(json?['currentTicketNumber']),
      estimatedWaitMinutes: _asInt(json?['estimatedWaitMinutes']) ?? 0,
    );
  }
}

class QueueCurrentTicket {
  const QueueCurrentTicket({
    this.ticketNumber,
    this.calledAt,
    this.customerConfirmedAt,
  });

  final String? ticketNumber;
  final DateTime? calledAt;
  final DateTime? customerConfirmedAt;

  factory QueueCurrentTicket.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const QueueCurrentTicket();
    return QueueCurrentTicket(
      ticketNumber: _asString(json['ticketNumber']),
      calledAt: _asDate(json['calledAt']),
      customerConfirmedAt: _asDate(json['customerConfirmedAt']),
    );
  }
}

class QueueLocationStatus {
  const QueueLocationStatus({this.isOpen, this.summary, this.nextOpenAt});

  final bool? isOpen;
  final String? summary;
  final DateTime? nextOpenAt;

  factory QueueLocationStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const QueueLocationStatus();
    return QueueLocationStatus(
      isOpen: json['isOpen'] as bool?,
      summary: json['summary'] as String?,
      nextOpenAt: _asDate(json['nextOpenAt']),
    );
  }
}

class QueueSnapshot {
  const QueueSnapshot({
    required this.serverNow,
    required this.joinable,
    this.joinUnavailableReason,
    this.focusTicket,
    this.queueDay = const QueueDayStatus(),
    this.queueIntake = const QueueIntakeStatus(),
    this.stats = const QueueStats(),
    this.current,
    this.locationStatus,
  });

  final DateTime? serverNow;
  final bool joinable;
  final String? joinUnavailableReason;
  final QueueTicket? focusTicket;
  final QueueDayStatus queueDay;
  final QueueIntakeStatus queueIntake;
  final QueueStats stats;
  final QueueCurrentTicket? current;
  final QueueLocationStatus? locationStatus;

  factory QueueSnapshot.fromJson(Map<String, dynamic> json) {
    final queueDay = QueueDayStatus.fromJson(_asMap(json['queueDay']));
    final queueIntake = QueueIntakeStatus.fromJson(_asMap(json['queueIntake']));
    final location = _asMap(json['location']);
    final openStatus = _asMap(location?['openStatus']);
    final focus = json['focusTicket'];
    final inferredJoinable =
        queueDay.state == 'open' &&
        !queueDay.isClosed &&
        !queueDay.isPaused &&
        queueIntake.state != 'paused' &&
        queueIntake.state != 'closed';
    return QueueSnapshot(
      serverNow: _asDate(json['serverNow']) ?? queueDay.serverNow,
      joinable: json['joinable'] as bool? ?? inferredJoinable,
      joinUnavailableReason:
          json['joinUnavailableReason'] as String? ?? json['reason'] as String?,
      focusTicket: focus is Map<String, dynamic>
          ? QueueTicket.fromJson(focus)
          : null,
      queueDay: queueDay,
      queueIntake: queueIntake,
      stats: QueueStats.fromJson(_asMap(json['stats'])),
      current: json['current'] is Map<String, dynamic>
          ? QueueCurrentTicket.fromJson(_asMap(json['current']))
          : null,
      locationStatus: openStatus == null
          ? null
          : QueueLocationStatus.fromJson(openStatus),
    );
  }
}

class VendorLocation {
  const VendorLocation({
    required this.id,
    required this.name,
    this.slug,
    this.queueAvailable = false,
    this.address,
    this.contactEmail,
    this.contactPhone,
    this.openStatus,
    this.hours = const [],
  });

  final String id;
  final String name;
  final String? slug;
  final bool queueAvailable;
  final String? address;
  final String? contactEmail;
  final String? contactPhone;
  final String? openStatus;
  final List<VendorStoreHour> hours;

  factory VendorLocation.fromJson(Map<String, dynamic> json) {
    final capabilities = json['capabilities'];
    final openStatus = _asMap(json['openStatus']);
    final rawHours = json['hours'];
    final hours = rawHours is List
        ? rawHours
              .whereType<Map<String, dynamic>>()
              .map(VendorStoreHour.fromJson)
              .toList(growable: false)
        : const <VendorStoreHour>[];
    final slug = _firstNonBlank([json['slug'] as String?]);
    return VendorLocation(
      id: _firstNonBlank([json['id'] as String?, slug]) ?? '',
      name: json['name'] as String? ?? 'Location',
      slug: slug,
      queueAvailable:
          json['queueAvailable'] as bool? ??
          openStatus?['isOpen'] as bool? ??
          (capabilities is Map<String, dynamic>
              ? capabilities['queue'] as bool?
              : null) ??
          false,
      address: _firstNonBlank([
        json['address'] as String?,
        _joinNonBlank([
          json['addressLine1'] as String?,
          json['addressLine2'] as String?,
          json['city'] as String?,
          json['province'] as String?,
          json['postalCode']?.toString(),
          json['country'] as String?,
        ]),
      ]),
      contactEmail: _firstNonBlank([json['contactEmail'] as String?]),
      contactPhone: _firstNonBlank([json['contactPhone'] as String?]),
      openStatus: _firstNonBlank([openStatus?['summary'] as String?]),
      hours: hours,
    );
  }
}

class VendorStoreHour {
  const VendorStoreHour({
    required this.weekday,
    required this.opensAt,
    required this.closesAt,
    this.isClosed = false,
  });

  final int weekday;
  final String opensAt;
  final String closesAt;
  final bool isClosed;

  factory VendorStoreHour.fromJson(Map<String, dynamic> json) {
    return VendorStoreHour(
      weekday: _asInt(json['weekday']) ?? 0,
      opensAt: json['opensAt'] as String? ?? '',
      closesAt: json['closesAt'] as String? ?? '',
      isClosed: json['isClosed'] as bool? ?? false,
    );
  }
}

class VendorSummary {
  const VendorSummary({
    required this.slug,
    required this.name,
    required this.queueAvailable,
    this.category,
    this.locations = const [],
    this.description,
    this.imageUrl,
    this.logoUrl,
    this.logoFit,
    this.coverImageUrl,
    this.coverImageFit,
    this.contactEmail,
    this.contactPhone,
  });

  final String slug;
  final String name;
  final bool queueAvailable;
  final String? category;
  final List<VendorLocation> locations;
  final String? description;
  final String? imageUrl;
  final String? logoUrl;
  final String? logoFit;
  final String? coverImageUrl;
  final String? coverImageFit;
  final String? contactEmail;
  final String? contactPhone;

  factory VendorSummary.fromJson(Map<String, dynamic> json) {
    final capabilities = json['capabilities'];
    final rawLocations = json['locations'];
    final locations = rawLocations is List
        ? rawLocations
              .whereType<Map<String, dynamic>>()
              .map(VendorLocation.fromJson)
              .toList(growable: false)
        : const <VendorLocation>[];
    final themeContainer =
        _asMap(json['businessProfileTheme']) ??
        _asMap(json['publicBoardTheme']) ??
        _asMap(json['profileTheme']);
    final theme = _asMap(themeContainer?['theme']) ?? themeContainer;
    final imageUrl = _firstNonBlank([json['imageUrl'] as String?]);
    return VendorSummary(
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? 'Vendor',
      queueAvailable:
          json['queueAvailable'] as bool? ??
          (capabilities is Map<String, dynamic>
              ? capabilities['queue'] as bool? ?? false
              : false),
      category: json['category'] as String?,
      locations: locations,
      description: _plainText(json['description'] as String?),
      imageUrl: imageUrl,
      logoUrl: _firstNonBlank([
        theme?['logoUrl'] as String?,
        json['logoUrl'] as String?,
      ]),
      logoFit: _firstNonBlank([theme?['logoFit'] as String?]),
      coverImageUrl: _firstNonBlank([
        theme?['backgroundImageUrl'] as String?,
        json['coverImageUrl'] as String?,
        imageUrl,
      ]),
      coverImageFit: _firstNonBlank([theme?['backgroundImageFit'] as String?]),
      contactEmail: _firstNonBlank([
        json['contactEmail'] as String?,
        for (final location in locations) location.contactEmail,
      ]),
      contactPhone: _firstNonBlank([
        json['contactPhone'] as String?,
        for (final location in locations) location.contactPhone,
      ]),
    );
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String? _asString(Object? value) {
  if (value == null) return null;
  final stringValue = value.toString().trim();
  return stringValue.isEmpty ? null : stringValue;
}

DateTime? _asDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

String? _firstNonBlank(Iterable<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

Map<String, dynamic>? _asMap(Object? value) =>
    value is Map<String, dynamic> ? value : null;

String? _joinNonBlank(Iterable<String?> values) {
  final parts = values
      .map((value) => value?.trim())
      .whereType<String>()
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
  return parts.isEmpty ? null : parts.join(', ');
}

String? _plainText(String? html) {
  final source = html?.trim();
  if (source == null || source.isEmpty) return null;
  final withLineBreaks = source
      .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
      .replaceAll(
        RegExp(r'</\s*(p|div|li|h[1-6])\s*>', caseSensitive: false),
        '\n',
      )
      .replaceAll(RegExp(r'<[^>]+>'), '');
  final decoded = withLineBreaks
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  final lines = decoded
      .split(RegExp(r'[\r\n]+'))
      .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  return lines.isEmpty ? null : lines.join('\n');
}
