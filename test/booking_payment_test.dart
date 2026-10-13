import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:getprio_mobile/bookings/booking_payment.dart';
import 'package:getprio_mobile/bookings/booking_repository.dart';
import 'package:getprio_mobile/bookings/bookings_page.dart';

Map<String, dynamic> paymentBooking() => {
  'id': 'booking-1',
  'reference': 'BKG-TEST',
  'status': 'pending',
  'paymentStatus': 'unpaid',
  'serviceManualPaymentRequired': true,
  'manualPaymentDestination': {
    'methodLabel': 'Bank Transfer',
    'bankName': 'Test Bank',
    'accountDisplayName': 'Vendor',
    'accountIdentifierDisplay': '12345',
    'amountCents': 20000,
    'currency': 'PHP',
  },
};

class PaymentApi implements BookingApi, BookingProofApi {
  int uploads = 0, submissions = 0;
  Map<String, dynamic>? submitted;
  Completer<void>? gate, uploadGate;
  bool fail = false;
  Map<String, dynamic>? data;
  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async => {'booking': data ?? paymentBooking()};
  @override
  Future<Map<String, dynamic>> uploadProof(
    String path, {
    required List<int> bytes,
    required String contentType,
    required String fileName,
  }) async {
    uploads++;
    if (uploadGate != null) await uploadGate!.future;
    expect(
      path,
      '/api/account/bookings/booking-1/payment-proof/uploads/direct',
    );
    expect(contentType, 'image/png');
    return {
      'proof': {
        'objectKey': 'private/server-key',
        'fileName': 'receipt.png',
        'contentType': 'image/png',
        'sizeBytes': bytes.length,
      },
    };
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    submissions++;
    submitted = body;
    if (gate != null) await gate!.future;
    if (fail) throw StateError('temporary failure');
    return {
      'booking': {
        ...paymentBooking(),
        'paymentStatus': 'pending',
        'paymentReference': body['paymentReference'],
        'paymentProof': {'fileName': 'receipt.png'},
      },
    };
  }
}

void main() {
  test('selection totals preserve each currency and booking quantities', () {
    const services = [
      BookingService(
        slug: 'a',
        name: 'A',
        currency: 'USD',
        priceAmountCents: 10000,
      ),
      BookingService(
        slug: 'b',
        name: 'B',
        currency: 'PHP',
        priceAmountCents: 20000,
      ),
      BookingService(
        slug: 'c',
        name: 'C',
        currency: 'USD',
        priceAmountCents: 5000,
      ),
    ];
    expect(bookingServiceTotal(services), 'USD 150.00 + ₱200.00');
    expect(
      bookingServiceTotal(services, quantities: {'a': 2}),
      'USD 250.00 + ₱200.00',
    );
  });

  test('authoritative expiry blocks proof upload before private receipt leaves device', () async {
    final api = PaymentApi();
    final booking = CustomerBooking({
      ...paymentBooking(),
      'expiredAt': '2026-10-13T00:00:00Z',
    });
    expect(booking.canSubmitProof, isFalse);
    await expectLater(
      BookingRepository(api).submitPaymentProof(
        booking,
        reference: 'ref',
        bytes: [1, 2],
        contentType: 'image/png',
        fileName: 'receipt.png',
      ),
      throwsStateError,
    );
    expect(api.uploads, 0);
    expect(api.submissions, 0);
  });

  for (final settled in [
    {'paymentStatus': 'paid'},
    {'paymentVerifiedAt': '2026-10-13T00:00:00Z'},
  ]) {
    test('settled payment blocks private upload $settled', () async {
      final api = PaymentApi();
      await expectLater(
        BookingRepository(api).submitPaymentProof(
          CustomerBooking({...paymentBooking(), ...settled}),
          reference: 'ref',
          bytes: [1, 2],
          contentType: 'image/png',
          fileName: 'receipt.png',
        ),
        throwsStateError,
      );
      expect(api.uploads, 0);
      expect(api.submissions, 0);
    });
  }

  testWidgets(
    'timed out receipt upload never advances to evidence submission',
    (tester) async {
      final api = PaymentApi()..uploadGate = Completer<void>();
      final pending = BookingRepository(api).submitPaymentProof(
        CustomerBooking(paymentBooking()),
        reference: 'ref',
        bytes: [1],
        contentType: 'image/png',
        fileName: 'receipt.png',
      );
      final assertion = expectLater(pending, throwsA(isA<TimeoutException>()));
      await tester.pump(const Duration(seconds: 31));
      await assertion;
      api.uploadGate!.complete();
      await tester.pump();
      expect(api.submissions, 0);
    },
  );

  testWidgets(
    'new booking without manual payment does not open payment drawer',
    (tester) async {
      final data = {...paymentBooking(), 'serviceManualPaymentRequired': false};
      await tester.pumpWidget(
        ShadcnApp(
          home: BookingDetailPage(
            repository: BookingRepository(PaymentApi()..data = data),
            booking: CustomerBooking(data),
            openPaymentOnArrival: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('booking-manual-payment-drawer')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('booking-open-manual-payment')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('new unpaid booking automatically opens manual payment drawer', (
    tester,
  ) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: BookingDetailPage(
          repository: BookingRepository(PaymentApi()),
          booking: CustomerBooking(paymentBooking()),
          openPaymentOnArrival: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('booking-manual-payment-drawer')),
      findsOneWidget,
    );
    expect(find.text('Test Bank'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('unpaid payment QR opens a zoom viewer and preserves reference', (
    tester,
  ) async {
    final data = paymentBooking();
    (data['manualPaymentDestination'] as Map)['qrImageUrl'] =
        'https://example.com/qr.png';
    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: SingleChildScrollView(
            child: BookingPayment(
              repository: BookingRepository(PaymentApi()),
              booking: CustomerBooking(data),
              onSubmitted: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('booking-payment-reference')),
      'REF-123',
    );
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('booking-payment-qr'))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('booking-payment-qr')));
    await tester.pumpAndSettle();
    expect(find.text('Payment QR'), findsOneWidget);
    expect(find.byKey(const Key('booking-image-viewer')), findsOneWidget);
    await tester.tap(find.byKey(const Key('booking-image-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('booking-image-viewer')), findsNothing);
    expect(find.text('REF-123'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('manual evidence eligibility follows the server lifecycle', () {
    expect(CustomerBooking(paymentBooking()).canSubmitProof, isTrue);
    for (final change in [
      {'paymentStatus': 'paid'},
      {'paymentStatus': 'verified'},
      {'paymentVerifiedAt': '2026-10-13T00:00:00Z'},
      {'status': 'expired'},
      {'status': 'canceled'},
      {'checkedInAt': '2030-01-01'},
      {'linkedTicket': {}},
      {
        'paymentProof': {'fileName': 'receipt.png'},
      },
      {'bookingPaymentSource': 'group_funded'},
      {'serviceManualPaymentRequired': false},
    ]) {
      expect(
        CustomerBooking({...paymentBooking(), ...change}).canSubmitProof,
        isFalse,
      );
    }
  });
  test('invalid receipts never start an upload', () async {
    final api = PaymentApi();
    final repository = BookingRepository(api);
    await expectLater(
      repository.submitPaymentProof(
        CustomerBooking(paymentBooking()),
        reference: 'ref',
        bytes: [1],
        contentType: 'application/pdf',
        fileName: 'receipt.pdf',
      ),
      throwsArgumentError,
    );
    await expectLater(
      repository.submitPaymentProof(
        CustomerBooking(paymentBooking()),
        reference: ' ',
        bytes: [1],
        contentType: 'image/png',
        fileName: 'receipt.png',
      ),
      throwsArgumentError,
    );
    expect(api.uploads, 0);
  });
  testWidgets(
    'existing unpaid booking exposes payment destination and proof continuation',
    (tester) async {
      await tester.pumpWidget(
        ShadcnApp(
          home: BookingDetailPage(
            repository: BookingRepository(PaymentApi()),
            booking: CustomerBooking(paymentBooking()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BookingPayment), findsNothing);
      expect(find.text('Test Bank'), findsNothing);
      await tester.ensureVisible(
        find.byKey(const Key('booking-open-manual-payment')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('booking-open-manual-payment')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('booking-manual-payment-drawer')),
        findsOneWidget,
      );
      expect(find.text('Test Bank'), findsOneWidget);
      expect(find.text('Total payable: PHP 200.00'), findsOneWidget);
      expect(find.textContaining('Payment proof required.'), findsOneWidget);
      expect(find.text('Submit payment proof'), findsOneWidget);
    },
  );
  testWidgets(
    'receipt submission requires reference, blocks duplicate submits and remains pending review',
    (tester) async {
      final api = PaymentApi()
        ..gate = Completer<void>()
        ..fail = true;
      CustomerBooking? updated;
      var canceled = false;
      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: SizedBox(
              height: 600,
              child: BookingPayment(
                repository: BookingRepository(api),
                booking: CustomerBooking(paymentBooking()),
                fixedFooter: true,
                onCancel: () => canceled = true,
                pickReceipt: () async => XFile.fromData(
                  Uint8List.fromList([1, 2, 3]),
                  name: 'receipt.png',
                  path: 'receipt.png',
                  mimeType: 'image/png',
                ),
                onSubmitted: (booking) => updated = booking,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final submit = find.widgetWithText(PrimaryButton, 'Submit payment proof');
      expect(tester.widget<PrimaryButton>(submit).onPressed, isNull);
      await tester.tap(find.text('Choose payment receipt'));
      await tester.pumpAndSettle();
      expect(tester.widget<PrimaryButton>(submit).onPressed, isNull);
      await tester.enterText(
        find.byKey(const Key('booking-payment-reference')),
        '  BANK-123  ',
      );
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(tester.element(submit));
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pump();
      expect(api.submissions, 1);
      expect(
        tester.widget<PopScope>(find.byType(PopScope).last).canPop,
        isFalse,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .onPressed,
        isNull,
      );
      expect(canceled, isFalse);
      expect(
        tester
            .widget<PrimaryButton>(
              find.widgetWithText(PrimaryButton, 'Please wait...'),
            )
            .onPressed,
        isNull,
      );
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Refresh the booking status before retrying'),
        findsOneWidget,
      );
      expect(
        tester.widget<PopScope>(find.byType(PopScope).last).canPop,
        isTrue,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .onPressed,
        isNotNull,
      );
      api.gate!.complete();
      await tester.pumpAndSettle();
      expect(updated, isNull);
      expect(find.text('receipt.png'), findsOneWidget);
      expect(find.textContaining('receipt is kept here'), findsOneWidget);
      api.fail = false;
      await tester.tap(
        find.widgetWithText(PrimaryButton, 'Submit payment proof'),
      );
      await tester.pumpAndSettle();
      expect(api.submissions, 2);
      expect(api.submitted?['paymentReference'], 'BANK-123');
      expect(api.submitted?['objectKey'], 'private/server-key');
      expect(updated?.status, 'pending');
      expect(updated?.paymentStatus, 'pending');
      expect(updated?.canSubmitProof, isFalse);
      expect(updated?.nextStep, contains('Awaiting vendor review'));
    },
  );
}
