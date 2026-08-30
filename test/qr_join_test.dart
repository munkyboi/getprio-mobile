import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/queue/join_repository.dart';

void main() {
  const hosts = {'app.getprio.test', 'enterprise.example.com'};
  const validId = '123e4567-e89b-42d3-a456-426614174000';

  test('accepts a canonical QR URL and keeps only trusted join data', () {
    final payload = QrJoinPayload.parse(
      'https://app.getprio.test/join/acme/makati?source=qr&id=$validId',
      allowedHosts: hosts,
    );

    expect(payload.locationQrId, validId);
    expect(payload.vendorSlug, 'acme');
    expect(payload.locationSlug, 'makati');
    expect(payload.host, 'app.getprio.test');
  });

  test('rejects an unapproved host, wrong source, and malformed id', () {
    for (final raw in [
      'https://evil.example/join/acme/makati?source=qr&id=$validId',
      'https://app.getprio.test/join/acme/makati?source=web&id=$validId',
      'https://app.getprio.test/join/acme/makati?source=qr&id=not-a-uuid',
    ]) {
      expect(
        () => QrJoinPayload.parse(raw, allowedHosts: hosts),
        throwsA(isA<QrValidationException>()),
      );
    }
  });

  test('accepts an enterprise QR URL without readable slugs', () {
    final payload = QrJoinPayload.parse(
      'https://enterprise.example.com/join?source=qr&id=$validId',
      allowedHosts: hosts,
    );

    expect(payload.vendorSlug, isNull);
    expect(payload.locationSlug, isNull);
  });

  test(
    'paid join result exposes checkout URL without claiming a ticket',
    () async {
      final api = FakeJoinApi(
        preview: {
          'locationQrId': validId,
          'vendorName': 'Acme Clinic',
          'locationName': 'Makati',
          'joinable': true,
          'fee': 150,
          'currency': 'PHP',
        },
        joinResponse: {
          'paymentRequired': true,
          'paymentAttemptId': 'attempt-1',
          'checkoutUrl': 'https://paymongo.example/checkout/opaque',
        },
      );
      final repository = JoinRepository(api);

      final result = await repository.join(
        locationQrId: validId,
        customerName: 'Preferred name',
      );

      expect(result, isA<PaymentRequired>());
      expect((result as PaymentRequired).paymentAttemptId, 'attempt-1');
      expect(api.lastJoinAttemptId, isNotEmpty);
    },
  );
}

class FakeJoinApi implements JoinApi {
  FakeJoinApi({required this.preview, required this.joinResponse});

  final Map<String, dynamic> preview;
  final Map<String, dynamic> joinResponse;
  String? lastJoinAttemptId;

  @override
  Future<Map<String, dynamic>> resolve(String locationQrId) async => preview;

  @override
  Future<Map<String, dynamic>> join({
    required String locationQrId,
    required String joinAttemptId,
    required String customerName,
  }) async {
    lastJoinAttemptId = joinAttemptId;
    return joinResponse;
  }
}
