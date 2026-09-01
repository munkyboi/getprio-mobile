import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/queue/join_repository.dart';
import 'package:getprio_mobile/queue/join_ui.dart';
import 'package:getprio_mobile/queue/payment_flow.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets(
    'paid join opens checkout controls in a resumable modal bottom sheet',
    (tester) async {
      final api = _CheckoutJoinApi();
      final browser = _RecordingPaymentBrowser();
      final paymentApi = _ConfirmedPaymentApi();

      await _openPaidCheckout(
        tester,
        api: api,
        browser: browser,
        paymentApi: paymentApi,
      );

      expect(find.byKey(const Key('checkout-bottom-sheet')), findsOneWidget);
      expect(find.text('Secure checkout'), findsOneWidget);
      expect(find.text('PHP 20.00'), findsOneWidget);
      expect(api.joinCalls, 1);

      await tester.tap(find.byKey(const Key('checkout-open')));
      await tester.pump();
      expect(browser.openedUrls, [
        Uri.parse('https://paymongo.example/checkout/opaque'),
      ]);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('checkout-bottom-sheet')), findsNothing);
      expect(find.text('Resume checkout'), findsOneWidget);

      await tester.tap(find.text('Resume checkout'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('checkout-bottom-sheet')), findsOneWidget);
      expect(api.joinCalls, 1);

      await tester.tap(find.byKey(const Key('checkout-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('checkout-bottom-sheet')), findsNothing);
      expect(find.text('Resume checkout'), findsOneWidget);

      await tester.tap(find.text('Resume checkout'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('checkout-bottom-sheet')), findsOneWidget);
      expect(api.joinCalls, 1);

      await tester.tap(find.byKey(const Key('checkout-check-status')));
      await tester.pumpAndSettle();
      expect(paymentApi.syncCalls, 1);
      expect(paymentApi.lastPaymentAttemptId, 'attempt-1');
      expect(paymentApi.lastTenantSlug, 'bosslot');
      expect(paymentApi.lastLocationSlug, 'main');
      expect(find.byKey(const Key('checkout-bottom-sheet')), findsNothing);
      expect(find.text('You are in the queue'), findsOneWidget);
    },
  );

  testWidgets('cancel discards the checkout attempt and returns to scanning', (
    tester,
  ) async {
    final api = _CheckoutJoinApi();

    await _openPaidCheckout(
      tester,
      api: api,
      browser: _RecordingPaymentBrowser(),
      paymentApi: _ConfirmedPaymentApi(),
    );

    await tester.tap(find.byKey(const Key('checkout-cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('checkout-bottom-sheet')), findsNothing);
    expect(find.text('Resume checkout'), findsNothing);
    expect(find.byKey(const Key('join-scan-button')), findsOneWidget);
    expect(api.joinCalls, 1);
  });

  testWidgets('confirmation closes a resumed sheet for the same payment', (
    tester,
  ) async {
    final api = _CheckoutJoinApi();
    final paymentApi = _PendingPaymentApi();

    await _openPaidCheckout(
      tester,
      api: api,
      browser: _RecordingPaymentBrowser(),
      paymentApi: paymentApi,
    );

    await tester.tap(find.byKey(const Key('checkout-check-status')));
    await tester.pump();
    expect(paymentApi.syncCalls, 1);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resume checkout'));
    expect(find.byKey(const Key('checkout-bottom-sheet')), findsNothing);

    paymentApi.confirm();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('checkout-bottom-sheet')), findsNothing);
    expect(find.text('You are in the queue'), findsOneWidget);
    expect(api.joinCalls, 1);
  });
}

Future<void> _openPaidCheckout(
  WidgetTester tester, {
  required _CheckoutJoinApi api,
  required PaymentBrowser browser,
  required PaymentApi paymentApi,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ShadcnApp(
      home: Scaffold(
        child: JoinPage(
          repository: JoinRepository(api),
          allowedHosts: const {'app.getprio.test'},
          customerName: 'Preferred name',
          paymentBrowser: browser,
          paymentApi: paymentApi,
        ),
      ),
    ),
  );

  await tester.tap(find.byKey(const Key('join-scan-button')));
  await tester.pumpAndSettle();
  final scanner = tester.widget<MobileScanner>(find.byType(MobileScanner));
  scanner.onDetect!(
    const BarcodeCapture(
      barcodes: [
        Barcode(
          rawValue: 'https://app.getprio.test/join/bosslot/main?source=qr&id=123e4567-e89b-42d3-a456-426614174000',
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('Continue to payment'));
  await tester.pumpAndSettle();
}

class _CheckoutJoinApi implements JoinApi {
  int joinCalls = 0;

  @override
  Future<Map<String, dynamic>> resolve(String locationQrId) async {
    return {
      'locationQrId': locationQrId,
      'vendorName': 'BOSSLOT ON',
      'vendorSlug': 'bosslot',
      'locationName': 'Main location',
      'locationSlug': 'main',
      'joinable': true,
      'amountCents': 2000,
      'currency': 'PHP',
    };
  }

  @override
  Future<Map<String, dynamic>> join({
    required String locationQrId,
    required String joinAttemptId,
    required String customerName,
  }) async {
    joinCalls += 1;
    return {
      'paymentRequired': true,
      'paymentAttemptId': 'attempt-1',
      'checkoutUrl': 'https://paymongo.example/checkout/opaque',
      'tenantSlug': 'bosslot',
      'locationSlug': 'main',
    };
  }
}

class _RecordingPaymentBrowser implements PaymentBrowser {
  final openedUrls = <Uri>[];

  @override
  Future<bool> open(Uri checkoutUrl) async {
    openedUrls.add(checkoutUrl);
    return true;
  }
}

class _ConfirmedPaymentApi implements PaymentApi {
  int syncCalls = 0;
  String? lastPaymentAttemptId;
  String? lastTenantSlug;
  String? lastLocationSlug;

  @override
  Future<Map<String, dynamic>> sync({
    required String paymentAttemptId,
    required String tenantSlug,
    String? locationSlug,
  }) async {
    syncCalls += 1;
    lastPaymentAttemptId = paymentAttemptId;
    lastTenantSlug = tenantSlug;
    lastLocationSlug = locationSlug;
    return {
      'ticket': {
        'id': 'ticket-1',
        'lookupCode': 'BOSS-001',
        'ticketNumber': 1,
        'customerName': 'Preferred name',
        'status': 'waiting',
      },
    };
  }
}

class _PendingPaymentApi implements PaymentApi {
  final _response = Completer<Map<String, dynamic>>();
  int syncCalls = 0;

  @override
  Future<Map<String, dynamic>> sync({
    required String paymentAttemptId,
    required String tenantSlug,
    String? locationSlug,
  }) {
    syncCalls += 1;
    return _response.future;
  }

  void confirm() {
    _response.complete({
      'ticket': {
        'id': 'ticket-1',
        'lookupCode': 'BOSS-001',
        'ticketNumber': 1,
        'customerName': 'Preferred name',
        'status': 'waiting',
      },
    });
  }
}
