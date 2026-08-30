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
    this.position,
    this.estimatedWaitMinutes,
    this.joinedAt,
    this.vendorName,
    this.locationName,
    this.tenantSlug,
    this.locationSlug,
    this.statusReason,
    this.carryOverExpiresAt,
  });

  final String id;
  final String lookupCode;
  final int? ticketNumber;
  final String customerName;
  final TicketStatus status;
  final int? position;
  final int? estimatedWaitMinutes;
  final DateTime? joinedAt;
  final String? vendorName;
  final String? locationName;
  final String? tenantSlug;
  final String? locationSlug;
  final String? statusReason;
  final DateTime? carryOverExpiresAt;

  bool get isActive => status.isActive;

  factory QueueTicket.fromJson(Map<String, dynamic> json) {
    final status = TicketStatus.parse(json['status']);
    final rawPosition = _asInt(json['position']);
    final rawWait = _asInt(json['estimatedWaitMinutes']);
    return QueueTicket(
      id: json['id'] as String? ?? '',
      lookupCode: json['lookupCode'] as String? ?? '',
      ticketNumber: _asInt(json['ticketNumber']),
      customerName:
          _firstNonBlank([
            json['customerDisplayName'] as String?,
            json['customerName'] as String?,
          ]) ??
          'Customer',
      status: status,
      position: status == TicketStatus.waiting ? rawPosition : null,
      estimatedWaitMinutes: status == TicketStatus.waiting ? rawWait : null,
      joinedAt: _asDate(json['joinedAt']),
      vendorName: json['vendorName'] as String?,
      locationName: json['locationName'] as String?,
      tenantSlug:
          json['tenantSlug'] as String? ?? json['vendorSlug'] as String?,
      locationSlug: json['locationSlug'] as String?,
      statusReason: json['statusReason'] as String?,
      carryOverExpiresAt: _asDate(json['carryOverExpiresAt']),
    );
  }
}

class QueueSnapshot {
  const QueueSnapshot({
    required this.serverNow,
    required this.joinable,
    this.joinUnavailableReason,
    this.focusTicket,
  });

  final DateTime? serverNow;
  final bool joinable;
  final String? joinUnavailableReason;
  final QueueTicket? focusTicket;

  factory QueueSnapshot.fromJson(Map<String, dynamic> json) {
    final focus = json['focusTicket'];
    return QueueSnapshot(
      serverNow: _asDate(json['serverNow']),
      joinable: json['joinable'] as bool? ?? false,
      joinUnavailableReason:
          json['joinUnavailableReason'] as String? ?? json['reason'] as String?,
      focusTicket: focus is Map<String, dynamic>
          ? QueueTicket.fromJson(focus)
          : null,
    );
  }
}

class VendorLocation {
  const VendorLocation({
    required this.id,
    required this.name,
    this.slug,
    this.queueAvailable = false,
  });

  final String id;
  final String name;
  final String? slug;
  final bool queueAvailable;

  factory VendorLocation.fromJson(Map<String, dynamic> json) {
    final capabilities = json['capabilities'];
    return VendorLocation(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Location',
      slug: json['slug'] as String?,
      queueAvailable:
          json['queueAvailable'] as bool? ??
          (capabilities is Map<String, dynamic>
              ? capabilities['queue'] as bool? ?? false
              : false),
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
  });

  final String slug;
  final String name;
  final bool queueAvailable;
  final String? category;
  final List<VendorLocation> locations;

  factory VendorSummary.fromJson(Map<String, dynamic> json) {
    final capabilities = json['capabilities'];
    final locations = json['locations'];
    return VendorSummary(
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? 'Vendor',
      queueAvailable:
          json['queueAvailable'] as bool? ??
          (capabilities is Map<String, dynamic>
              ? capabilities['queue'] as bool? ?? false
              : false),
      category: json['category'] as String?,
      locations: locations is List
          ? locations
                .whereType<Map<String, dynamic>>()
                .map(VendorLocation.fromJson)
                .toList(growable: false)
          : const [],
    );
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
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
