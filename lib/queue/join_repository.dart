import 'dart:math';

import 'auth_queue_api.dart';
import 'queue_models.dart';

class QrJoinPayload {
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
    this.unavailableReason,
    this.fee = 0,
    this.currency = 'PHP',
  });

  final String locationQrId;
  final String vendorName;
  final String locationName;
  final bool joinable;
  final String? unavailableReason;
  final num fee;
  final String currency;

  bool get paymentRequired => fee > 0;

  factory JoinPreview.fromJson(Map<String, dynamic> json) {
    return JoinPreview(
      locationQrId: json['locationQrId'] as String? ?? '',
      vendorName: json['vendorName'] as String? ?? 'Vendor',
      locationName: json['locationName'] as String? ?? 'Location',
      joinable: json['joinable'] as bool? ?? false,
      unavailableReason:
          json['unavailableReason'] as String? ?? json['reason'] as String?,
      fee: json['amountCents'] is num
          ? (json['amountCents'] as num)
          : json['fee'] is num
          ? json['fee'] as num
          : 0,
      currency: json['currency'] as String? ?? 'PHP',
    );
  }
}

abstract interface class JoinApi {
  Future<Map<String, dynamic>> resolve(String locationQrId);

  Future<Map<String, dynamic>> join({
    required String locationQrId,
    required String joinAttemptId,
    required String customerName,
  });
}

sealed class JoinResult {
  const JoinResult();
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
  });

  final String paymentAttemptId;
  final Uri checkoutUrl;
  final String? tenantSlug;
  final String? locationSlug;
}

class JoinRepository {
  JoinRepository(this.api);

  final JoinApi api;

  Future<JoinPreview> resolve(QrJoinPayload payload) async {
    return JoinPreview.fromJson(await api.resolve(payload.locationQrId));
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

    final response = await api.join(
      locationQrId: locationQrId,
      joinAttemptId: _newAttemptId(),
      customerName: customerName,
    );
    final ticket = response['ticket'];
    if (ticket is Map<String, dynamic>) {
      return JoinedTicket(QueueTicket.fromJson(ticket));
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
      return PaymentRequired(
        paymentAttemptId: paymentAttemptId,
        checkoutUrl: uri,
        tenantSlug: response['tenantSlug'] as String?,
        locationSlug: response['locationSlug'] as String?,
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

class JoinUnavailableException implements Exception {
  const JoinUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RestJoinApi implements JoinApi {
  RestJoinApi(this.client);

  final AuthenticatedApiClient client;

  @override
  Future<Map<String, dynamic>> resolve(String locationQrId) {
    return client.get(
      '/api/mobile/queue-join/resolve',
      queryParameters: {'id': locationQrId},
    );
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
}
