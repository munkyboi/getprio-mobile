import 'dart:math';

import '../auth/auth_repository.dart';
import 'auth_queue_api.dart';
import 'queue_models.dart';

class QrJoinPayload extends QrScanPayload {
  const QrJoinPayload({
    required this.locationQrId,
    required this.host,
    this.vendorSlug,
    this.locationSlug,
  });

  final String locationQrId;
  final String host;
  final String? vendorSlug;
  final String? locationSlug;

  factory QrJoinPayload.parse(String raw, {required Set<String> allowedHosts}) {
    final uri = Uri.tryParse(raw);
    final normalizedHosts = allowedHosts
        .map((host) => host.toLowerCase())
        .toSet();
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        !normalizedHosts.contains(uri.host.toLowerCase()) ||
        uri.fragment.isNotEmpty) {
      throw const QrValidationException(
        'This QR code is not a trusted GetPrio link.',
      );
    }

    final query = uri.queryParameters;
    if (uri.queryParametersAll.length != 2 ||
        query.length != 2 ||
        query['source'] != 'qr' ||
        !_isUuidV4(query['id'])) {
      throw const QrValidationException(
        'This QR code is not a valid queue link.',
      );
    }

    final segments = uri.pathSegments;
    if (segments.isEmpty || segments.first != 'join' || segments.length > 3) {
      throw const QrValidationException(
        'This QR code is not a valid queue link.',
      );
    }

    return QrJoinPayload(
      locationQrId: query['id']!,
      host: uri.host,
      vendorSlug: segments.length > 1 ? segments[1] : null,
      locationSlug: segments.length > 2 ? segments[2] : null,
    );
  }

  static bool _isUuidV4(String? value) {
    return value != null &&
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          caseSensitive: false,
        ).hasMatch(value);
  }
}

class QrValidationException implements Exception {
  const QrValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class JoinPreview {
  const JoinPreview({
    required this.locationQrId,
    required this.vendorName,
    required this.locationName,
    required this.joinable,
    this.vendorSlug,
    this.locationSlug,
    this.unavailableReason,
    this.vendorProfile,
    this.queueDetails,
    this.fee = 0,
    this.currency = 'PHP',
  });

  final String locationQrId;
  final String vendorName;
  final String? vendorSlug;
  final String locationName;
  final String? locationSlug;
  final bool joinable;
  final String? unavailableReason;
  final JoinVendorProfile? vendorProfile;
  final JoinQueueDetails? queueDetails;
  final num fee;
  final String currency;

  bool get paymentRequired => fee > 0;

  JoinPreview asUnavailable(String reason) {
    return JoinPreview(
      locationQrId: locationQrId,
      vendorName: vendorName,
      vendorSlug: vendorSlug,
      locationName: locationName,
      locationSlug: locationSlug,
      joinable: false,
      unavailableReason: reason,
      vendorProfile: vendorProfile,
      queueDetails: queueDetails,
      fee: fee,
      currency: currency,
    );
  }

  factory JoinPreview.fromJson(Map<String, dynamic> json) {
    final vendorProfile = json['vendorProfile'];
    final snapshot = json['snapshot'];
    return JoinPreview(
      locationQrId: json['locationQrId'] as String? ?? '',
      vendorName: json['vendorName'] as String? ?? 'Vendor',
      vendorSlug: _joinText([json['vendorSlug'] as String?]),
      locationName: json['locationName'] as String? ?? 'Location',
      locationSlug: _joinText([json['locationSlug'] as String?]),
      joinable: json['joinable'] as bool? ?? false,
      unavailableReason:
          json['unavailableReason'] as String? ?? json['reason'] as String?,
      vendorProfile: vendorProfile is Map<String, dynamic>
          ? JoinVendorProfile.fromJson(vendorProfile)
          : null,
      queueDetails: snapshot is Map<String, dynamic>
          ? JoinQueueDetails.fromSnapshot(snapshot)
          : null,
      fee: json['amountCents'] is num
          ? (json['amountCents'] as num)
          : json['fee'] is num
          ? json['fee'] as num
          : 0,
      currency: json['currency'] as String? ?? 'PHP',
    );
  }
}

class JoinQueueDetails {
  const JoinQueueDetails({
    this.waitingCount,
    this.currentTicketNumber,
    this.estimatedWaitMinutes,
  });

  final int? waitingCount;
  final String? currentTicketNumber;
  final int? estimatedWaitMinutes;

  factory JoinQueueDetails.fromSnapshot(Map<String, dynamic> snapshot) {
    final stats = _joinMap(snapshot['stats']);
    final current = _joinMap(snapshot['current']);
    final currentTicketNumber = _joinText([
      current?['ticketNumber']?.toString(),
      stats?['currentTicketNumber']?.toString(),
    ]);
    return JoinQueueDetails(
      waitingCount: _joinInt(stats?['waitingCount']),
      currentTicketNumber: currentTicketNumber,
      estimatedWaitMinutes: _joinInt(stats?['estimatedWaitMinutes']),
    );
  }
}

class JoinVendorLocation {
  const JoinVendorLocation({required this.name, this.slug, this.address});

  final String name;
  final String? slug;
  final String? address;

  factory JoinVendorLocation.fromJson(Map<String, dynamic> json) {
    return JoinVendorLocation(
      name: _joinText([json['name'] as String?]) ?? 'Location',
      slug: _joinText([json['slug'] as String?]),
      address: _joinAddress([
        json['addressLine1'] as String?,
        json['addressLine2'] as String?,
        json['city'] as String?,
        json['province'] as String?,
        json['postalCode']?.toString(),
        json['country'] as String?,
      ]),
    );
  }
}

enum JoinProfileImageFit { contain, cover }

class JoinVendorProfile {
  const JoinVendorProfile({
    required this.slug,
    required this.name,
    this.category,
    this.description,
    this.logoUrl,
    this.logoFit,
    this.coverImageUrl,
    this.coverImageFit,
    this.locations = const [],
  });

  final String slug;
  final String name;
  final String? category;
  final String? description;
  final String? logoUrl;
  final JoinProfileImageFit? logoFit;
  final String? coverImageUrl;
  final JoinProfileImageFit? coverImageFit;
  final List<JoinVendorLocation> locations;

  factory JoinVendorProfile.fromJson(Map<String, dynamic> json) {
    final themeContainer = _joinMap(json['businessProfileTheme']);
    final theme = _joinMap(themeContainer?['theme']) ?? themeContainer;
    final rawLocations = json['locations'];
    return JoinVendorProfile(
      slug: json['slug'] as String? ?? '',
      name: _joinText([json['name'] as String?]) ?? 'Vendor',
      category: _joinText([json['category'] as String?]),
      description: _joinPlainText(json['description'] as String?),
      logoUrl: _joinText([
        theme?['logoUrl'] as String?,
        json['logoUrl'] as String?,
        json['imageUrl'] as String?,
      ]),
      logoFit: _joinImageFit(theme?['logoFit']),
      coverImageUrl: _joinText([
        theme?['backgroundImageUrl'] as String?,
        json['coverImageUrl'] as String?,
      ]),
      coverImageFit: _joinImageFit(theme?['backgroundImageFit']),
      locations: rawLocations is List
          ? rawLocations
                .whereType<Map<String, dynamic>>()
                .map(JoinVendorLocation.fromJson)
                .toList(growable: false)
          : const [],
    );
  }
}

JoinProfileImageFit? _joinImageFit(Object? value) {
  return switch (value?.toString().trim().toLowerCase()) {
    'contain' => JoinProfileImageFit.contain,
    'cover' => JoinProfileImageFit.cover,
    _ => null,
  };
}

Map<String, dynamic>? _joinMap(Object? value) =>
    value is Map<String, dynamic> ? value : null;

String? _joinText(Iterable<String?> values) {
  for (final value in values) {
    final normalized = value?.trim();
    if (normalized != null && normalized.isNotEmpty) return normalized;
  }
  return null;
}

int? _joinInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '');
}

String? _joinAddress(Iterable<String?> values) {
  final parts = values
      .map((value) => value?.trim())
      .whereType<String>()
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
  return parts.isEmpty ? null : parts.join(', ');
}

String? _joinPlainText(String? html) {
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

abstract class QrScanPayload {
  const QrScanPayload();

  static QrScanPayload parse(String raw, {required Set<String> allowedHosts}) {
    final normalized = raw.trim();
    if (RegExp(r'^[a-f0-9]{8}$', caseSensitive: false).hasMatch(normalized)) {
      return QrTicketClaimPayload(normalized.toUpperCase());
    }
    return QrJoinPayload.parse(normalized, allowedHosts: allowedHosts);
  }
}

class QrTicketClaimPayload extends QrScanPayload {
  const QrTicketClaimPayload(this.verificationCode);

  final String verificationCode;
}

abstract interface class JoinApi {
  Future<Map<String, dynamic>> resolve(String locationQrId);

  Future<Map<String, dynamic>> join({
    required String locationQrId,
    required String joinAttemptId,
    required String customerName,
  });
}

abstract interface class TicketClaimApi {
  Future<Map<String, dynamic>> claimTicket(String verificationCode);
}

abstract interface class DirectJoinApi {
  Future<Map<String, dynamic>> joinDirect({
    required String tenantSlug,
    String? locationSlug,
    required String joinAttemptId,
    required String customerName,
  });
}

abstract interface class JoinOtpApi {
  Future<Map<String, dynamic>> verifyOtp({
    required String otpId,
    required String code,
    required String attemptId,
  });
  Future<Map<String, dynamic>> resendOtp({
    required String otpId,
    required String attemptId,
  });
}

sealed class JoinResult {
  const JoinResult();
}

class JoinEmailVerification extends JoinResult {
  const JoinEmailVerification({
    required this.otpId,
    required this.email,
    required this.tenantSlug,
    required this.locationSlug,
    this.expiresAt,
    this.resendAvailableAt,
    this.resendsRemaining = 0,
  });
  final String otpId;
  final String email;
  final String tenantSlug;
  final String locationSlug;
  final DateTime? expiresAt;
  final DateTime? resendAvailableAt;
  final int resendsRemaining;

  factory JoinEmailVerification.fromJson(Map<String, dynamic> json) {
    final id = json['otpId']?.toString() ?? '';
    if (id.isEmpty) {
      throw const FormatException('Email verification response is incomplete.');
    }
    return JoinEmailVerification(
      otpId: id,
      email: json['deliveryTarget'] as String? ?? '',
      tenantSlug: json['tenantSlug'] as String? ?? '',
      locationSlug: json['locationSlug'] as String? ?? '',
      expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? ''),
      resendAvailableAt: DateTime.tryParse(
        json['resendAvailableAt']?.toString() ?? '',
      ),
      resendsRemaining: json['resendsRemaining'] as int? ?? 0,
    );
  }
}

class JoinedTicket extends JoinResult {
  const JoinedTicket(this.ticket);

  final QueueTicket ticket;
}

class PaymentRequired extends JoinResult {
  const PaymentRequired({
    required this.paymentAttemptId,
    required this.checkoutUrl,
    this.tenantSlug,
    this.locationSlug,
    this.fee = 0,
    this.currency = 'PHP',
  });

  final String paymentAttemptId;
  final Uri checkoutUrl;
  final String? tenantSlug;
  final String? locationSlug;
  final num fee;
  final String currency;
}

class JoinRepository {
  JoinRepository(this.api);

  final JoinApi api;

  Future<JoinPreview> resolve(QrJoinPayload payload) async {
    return JoinPreview.fromJson(await api.resolve(payload.locationQrId));
  }

  Future<QueueTicket> claimTicket(QrTicketClaimPayload payload) async {
    final claimApi = api is TicketClaimApi ? api as TicketClaimApi : null;
    if (claimApi == null) {
      throw const ApiException(
        501,
        'TICKET_CLAIM_UNAVAILABLE',
        'Printed ticket QR claims are not configured for this build.',
      );
    }
    final response = await claimApi.claimTicket(payload.verificationCode);
    final ticket = response['ticket'];
    if (ticket is! Map<String, dynamic>) {
      throw const FormatException('The ticket QR response is incomplete.');
    }
    return QueueTicket.fromJson(_claimTicketJson(ticket));
  }

  Future<JoinResult> join({
    required String locationQrId,
    required String customerName,
  }) async {
    final preview = JoinPreview.fromJson(await api.resolve(locationQrId));
    if (!preview.joinable) {
      throw JoinUnavailableException(
        preview.unavailableReason ?? 'This queue is not available right now.',
      );
    }

    late final Map<String, dynamic> response;
    try {
      response = await api.join(
        locationQrId: locationQrId,
        joinAttemptId: _newAttemptId(),
        customerName: customerName,
      );
    } on ApiException catch (error) {
      if (error.statusCode == 403 || _isQueueUnavailableApiCode(error.code)) {
        throw JoinUnavailableException(error.message);
      }
      rethrow;
    }
    return _parseJoinResult(response, preview: preview);
  }

  Future<JoinResult> joinDirect({
    required String tenantSlug,
    String? locationSlug,
    required String customerName,
  }) async {
    final directApi = api;
    if (directApi is! DirectJoinApi) {
      throw const ApiException(
        501,
        'DIRECT_JOIN_UNAVAILABLE',
        'Direct queue joining is not configured for this build.',
      );
    }
    final response = await (directApi as DirectJoinApi).joinDirect(
      tenantSlug: tenantSlug,
      locationSlug: locationSlug,
      joinAttemptId: _newAttemptId(),
      customerName: customerName,
    );
    return _parseJoinResult(
      response,
      tenantSlug: tenantSlug,
      locationSlug: locationSlug,
    );
  }

  Future<JoinResult> verifyEmail(
    JoinEmailVerification challenge,
    String code,
  ) async {
    final otpApi = api;
    if (otpApi is! JoinOtpApi) {
      throw const FormatException('Email verification is unavailable.');
    }
    final response = await (otpApi as JoinOtpApi).verifyOtp(
      otpId: challenge.otpId,
      code: code,
      attemptId: _newAttemptId(),
    );
    return _parseJoinResult(
      response,
      tenantSlug: challenge.tenantSlug,
      locationSlug: challenge.locationSlug,
    );
  }

  Future<JoinEmailVerification> resendEmail(
    JoinEmailVerification challenge,
  ) async {
    final otpApi = api;
    if (otpApi is! JoinOtpApi) {
      throw const FormatException('Email verification is unavailable.');
    }
    return JoinEmailVerification.fromJson(
      await (otpApi as JoinOtpApi).resendOtp(
        otpId: challenge.otpId,
        attemptId: _newAttemptId(),
      ),
    );
  }

  JoinResult _parseJoinResult(
    Map<String, dynamic> response, {
    JoinPreview? preview,
    String? tenantSlug,
    String? locationSlug,
  }) {
    if (response['otpRequired'] == true) {
      return JoinEmailVerification.fromJson(response);
    }
    final ticket = response['ticket'];
    if (ticket is Map<String, dynamic>) {
      return JoinedTicket(
        queueTicketFromJoinResponse(
          response,
          preview: preview,
          tenantSlug: tenantSlug,
          locationSlug: locationSlug,
        ),
      );
    }

    if (response['paymentRequired'] == true) {
      final paymentAttemptId = response['paymentAttemptId'];
      final checkoutUrl = response['checkoutUrl'];
      if (paymentAttemptId is! String || checkoutUrl is! String) {
        throw const FormatException('Payment response is incomplete.');
      }
      final uri = Uri.tryParse(checkoutUrl);
      if (uri == null || uri.scheme != 'https') {
        throw const FormatException('Payment checkout URL is invalid.');
      }
      final queueFee = response['queueFee'];
      final payment = response['payment'];
      return PaymentRequired(
        paymentAttemptId: paymentAttemptId,
        checkoutUrl: uri,
        tenantSlug: response['tenantSlug'] as String?,
        locationSlug: response['locationSlug'] as String?,
        fee:
            response['amountCents'] as num? ??
            (queueFee is Map<String, dynamic>
                ? queueFee['amountCents'] as num?
                : null) ??
            (payment is Map<String, dynamic>
                ? payment['amountCents'] as num?
                : null) ??
            0,
        currency:
            response['currency'] as String? ??
            (queueFee is Map<String, dynamic>
                ? queueFee['currency'] as String?
                : null) ??
            (payment is Map<String, dynamic>
                ? payment['currency'] as String?
                : null) ??
            'PHP',
      );
    }

    throw const FormatException('Queue join response is incomplete.');
  }

  String _newAttemptId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

QueueTicket queueTicketFromJoinResponse(
  Map<String, dynamic> response, {
  JoinPreview? preview,
  String? tenantSlug,
  String? locationSlug,
}) {
  final ticket = response['ticket'];
  if (ticket is! Map<String, dynamic>) {
    throw const FormatException('Queue join response is missing a ticket.');
  }

  final snapshot = _joinResponseMap(response['snapshot']);
  final focusTicket = _joinResponseMap(snapshot?['focusTicket']);
  final tenant = _joinResponseMap(snapshot?['tenant']);
  final location = _joinResponseMap(snapshot?['location']);
  final merged = <String, dynamic>{...?focusTicket, ...ticket};

  final vendorName = _firstJoinText([
    merged['vendorName'],
    merged['tenantName'],
    merged['businessName'],
    preview?.vendorName,
    tenant?['name'],
    tenant?['businessName'],
  ]);
  final resolvedTenantSlug = _firstJoinText([
    merged['tenantSlug'],
    merged['vendorSlug'],
    preview?.vendorSlug,
    tenant?['slug'],
    tenantSlug,
  ]);
  final locationName = _firstJoinText([
    merged['locationName'],
    preview?.locationName,
    location?['name'],
  ]);
  final resolvedLocationSlug = _firstJoinText([
    merged['locationSlug'],
    preview?.locationSlug,
    location?['slug'],
    locationSlug,
  ]);

  if (vendorName != null) merged['vendorName'] = vendorName;
  if (resolvedTenantSlug != null) {
    merged['tenantSlug'] = resolvedTenantSlug;
  }
  if (locationName != null) merged['locationName'] = locationName;
  if (resolvedLocationSlug != null) {
    merged['locationSlug'] = resolvedLocationSlug;
  }

  return QueueTicket.fromJson(merged);
}

Map<String, dynamic>? _joinResponseMap(Object? value) {
  return value is Map<String, dynamic> ? value : null;
}

String? _firstJoinText(Iterable<Object?> values) {
  for (final value in values) {
    if (value is String && value.trim().isNotEmpty) return value;
  }
  return null;
}

class JoinUnavailableException implements Exception {
  const JoinUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

const _queueUnavailableApiCodes = {
  'QUEUE_JOIN_UNAVAILABLE',
  'QUEUE_INTAKE_PAUSED',
  'QUEUE_DAY_UNOPENED',
  'QUEUE_DAY_OVERDUE',
  'QUEUE_DAY_CLOSED',
  'QUEUE_OUTSIDE_EFFECTIVE_HOURS',
  'QUEUE_STATE_CHANGED',
  'ALLOWANCE_QUEUE_TICKETS_EXHAUSTED',
};

bool _isQueueUnavailableApiCode(String? code) {
  return code != null &&
      (_queueUnavailableApiCodes.contains(code) ||
          code.startsWith('SUBSCRIPTION_'));
}

class RestJoinApi
    implements JoinApi, DirectJoinApi, JoinOtpApi, TicketClaimApi {
  RestJoinApi(this.client);

  final AuthenticatedApiClient client;

  @override
  Future<Map<String, dynamic>> verifyOtp({
    required String otpId,
    required String code,
    required String attemptId,
  }) => client.post(
    '/api/mobile/queue-join/otp/verify',
    {'otpId': otpId, 'code': code},
    additionalHeaders: {'Idempotency-Key': attemptId},
  );

  @override
  Future<Map<String, dynamic>> resendOtp({
    required String otpId,
    required String attemptId,
  }) => client.post(
    '/api/mobile/queue-join/otp/resend',
    {'otpId': otpId},
    additionalHeaders: {'Idempotency-Key': attemptId},
  );

  @override
  Future<Map<String, dynamic>> resolve(String locationQrId) async {
    final queue = await client.get(
      '/api/mobile/queue-join/resolve',
      queryParameters: {'id': locationQrId},
      additionalHeaders: const {'Cache-Control': 'no-cache'},
    );
    final vendorSlug = queue['vendorSlug'];
    if (vendorSlug is! String || vendorSlug.trim().isEmpty) return queue;

    try {
      final profileResponse = await client.get(
        '/api/public/vendors/${vendorSlug.trim()}',
      );
      final vendor = profileResponse['vendor'];
      return vendor is Map<String, dynamic>
          ? {...queue, 'vendorProfile': vendor}
          : queue;
    } on Exception {
      return queue;
    }
  }

  @override
  Future<Map<String, dynamic>> claimTicket(String verificationCode) {
    return client.post('/api/mobile/ticket-claims', {
      'verification_code': verificationCode.trim().toUpperCase(),
    });
  }

  @override
  Future<Map<String, dynamic>> join({
    required String locationQrId,
    required String joinAttemptId,
    required String customerName,
  }) {
    return client.post(
      '/api/mobile/queue-join',
      {
        'id': locationQrId,
        'joinAttemptId': joinAttemptId,
        'customerName': customerName,
      },
      additionalHeaders: {'Idempotency-Key': joinAttemptId},
    );
  }

  @override
  Future<Map<String, dynamic>> joinDirect({
    required String tenantSlug,
    String? locationSlug,
    required String joinAttemptId,
    required String customerName,
  }) {
    return client.post(
      '/api/mobile/queue-join/direct',
      {
        'tenantSlug': tenantSlug,
        if (locationSlug != null && locationSlug.trim().isNotEmpty)
          'locationSlug': locationSlug,
        'customerName': customerName,
      },
      additionalHeaders: {'Idempotency-Key': joinAttemptId},
    );
  }
}

Map<String, dynamic> _claimTicketJson(Map<String, dynamic> ticket) {
  final profile = ticket['profile'];
  final profileJson = profile is Map<String, dynamic>
      ? profile
      : const <String, dynamic>{};
  return {
    'id': ticket['id'],
    'lookupCode': ticket['external_reference'] ?? ticket['id'],
    'ticketNumber': ticket['ticket_number'],
    'verificationCode': ticket['verification_code'],
    'customerName': 'Sandbox test user',
    'status': ticket['status'],
    'statusReason': ticket['status_reason'],
    'vendorName': profileJson['queue_name'] ?? ticket['display_label'],
    'tenantSlug': profileJson['tenant_slug'] ?? profileJson['tenantSlug'],
    'locationName': profileJson['location_name'],
    'locationSlug': profileJson['location_slug'],
    'joinedAt': ticket['issued_at'],
    'updatedAt': ticket['updated_at'],
  };
}
