import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/queue/payment_flow.dart';

void main() {
  test(
    'parses an opaque payment return reference from an approved HTTPS link',
    () {
      final result = PaymentReturn.parse(
        Uri.parse(
          'https://app.getprio.test/payment/return?reference=opaque-1&status=success',
        ),
        allowedHosts: {'app.getprio.test'},
      );

      expect(result.reference, 'opaque-1');
      expect(result.providerStatus, 'success');
    },
  );

  test('rejects payment callbacks from an unapproved host', () {
    expect(
      () => PaymentReturn.parse(
        Uri.parse('https://evil.example/payment/return?reference=opaque-1'),
        allowedHosts: {'app.getprio.test'},
      ),
      throwsA(isA<PaymentReturnException>()),
    );
  });
}
