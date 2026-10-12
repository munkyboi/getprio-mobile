import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:getprio_mobile/bookings/booking_repository.dart';
import 'package:getprio_mobile/bookings/bookings_page.dart';
import 'package:getprio_mobile/bookings/booking_payment.dart';

Map<String, dynamic> liveBooking() => {
  'id': 'booking',
  'reference': 'BKG-LIVE',
  'tenantName': 'Clinic',
  'status': 'pending',
  'paymentStatus': 'unpaid',
  'serviceManualPaymentRequired': true,
  'manualPaymentDestination': {
    'methodLabel': 'Bank Transfer',
    'amountCents': 5000,
  },
};

class LiveApi implements BookingApi {
  Map<String, dynamic> data = liveBooking();
  int requests = 0;
  bool fail = false;
  Completer<Map<String, dynamic>>? gate;
  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    requests++;
    if (fail) throw StateError('offline');
    if (gate != null) return gate!.future;
    return {'booking': Map<String, dynamic>.from(data)};
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async => {};
}

Future<void> openLive(WidgetTester tester, LiveApi api) async {
  await tester.pumpWidget(
    ShadcnApp(
      home: BookingDetailPage(
        repository: BookingRepository(api),
        booking: CustomerBooking(liveBooking()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'booking interaction postpones idle pause; only successful refresh resumes',
    (tester) async {
      final api = LiveApi();
      await openLive(tester, api);
      await tester.pump(const Duration(minutes: 4));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Booking details'));
      await tester.pump(const Duration(minutes: 4));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detail-auto-update-paused')), findsNothing);
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('detail-auto-update-paused')),
        findsOneWidget,
      );
      final calls = api.requests;
      await tester.pump(const Duration(minutes: 1));
      expect(api.requests, calls);
      api.fail = true;
      await tester.tap(find.text('Refresh and resume'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('detail-auto-update-paused')),
        findsOneWidget,
      );
      api.fail = false;
      await tester.tap(find.text('Refresh and resume'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detail-auto-update-paused')), findsNothing);
      final resumed = api.requests;
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(api.requests, resumed + 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'polls visible booking and preserves payment draft during errors',
    (tester) async {
      final api = LiveApi();
      await openLive(tester, api);
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const Key('booking-payment-reference'))),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('booking-payment-reference')),
        'REFERENCE',
      );
      api.fail = true;
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(api.requests, 2);
      expect(find.text('REFERENCE'), findsOneWidget);
      expect(find.textContaining('last available details'), findsOneWidget);
      api.fail = false;
      api.data = {
        ...liveBooking(),
        'status': 'confirmed',
        'paymentStatus': 'verified',
        'paymentProof': {'fileName': 'receipt.png'},
      };
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(find.text('Booking: confirmed'), findsOneWidget);
      expect(find.text('Payment: verified'), findsOneWidget);
      expect(find.byType(BookingPayment), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'does not poll background or covered page, resumes and stops after disposal',
    (tester) async {
      final api = LiveApi();
      await openLive(tester, api);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 30));
      expect(api.requests, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(api.requests, 2);
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.push(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => const Scaffold(child: Text('Another page')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 30));
      expect(api.requests, 2);
      nav.pop();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(api.requests, 3);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 30));
      expect(api.requests, 3);
    },
  );
  testWidgets('in-flight polling cannot overwrite newly submitted proof', (
    tester,
  ) async {
    final api = LiveApi();
    await openLive(tester, api);
    api.gate = Completer<Map<String, dynamic>>();
    await tester.pump(const Duration(seconds: 15));
    expect(api.requests, 2);
    final form = tester.widget<BookingPayment>(find.byType(BookingPayment));
    form.onSubmitted(
      CustomerBooking({
        ...liveBooking(),
        'paymentStatus': 'pending',
        'paymentProof': {'fileName': 'receipt.png'},
      }),
    );
    await tester.pump();
    api.gate!.complete({'booking': liveBooking()});
    await tester.pumpAndSettle();
    expect(find.text('Payment: pending'), findsOneWidget);
    expect(find.byType(BookingPayment), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
