import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:getprio_mobile/bookings/booking_repository.dart';
import 'package:getprio_mobile/bookings/bookings_page.dart';

final scheduled = DateTime.utc(2026, 10, 9, 9, 30);
Map<String, dynamic> arrivalBooking() => {
  'id': 'booking/one',
  'reference': 'BKG-ARRIVAL',
  'status': 'confirmed',
  'paymentStatus': 'paid',
  'tenantName': 'Clinic',
  'customerSelfCheckInEnabled': true,
  'scheduledStartAt': scheduled.toIso8601String(),
  'scheduledEndAt': scheduled.add(const Duration(hours: 1)).toIso8601String(),
};
Map<String, dynamic> checkedInBooking() => {
  ...arrivalBooking(),
  'checkedInAt': scheduled.toIso8601String(),
  'linkedTicket': {
    'id': 'ticket',
    'lookupCode': 'LOOKUP',
    'ticketNumber': 'A001',
    'status': 'waiting',
  },
};

class ArrivalApi implements BookingApi {
  Map<String, dynamic> data = arrivalBooking();
  Completer<Map<String, dynamic>>? getGate, postGate;
  bool fail = false;
  int posts = 0;
  String? postPath;
  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async => getGate?.future ?? {'booking': Map<String, dynamic>.from(data)};
  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    posts++;
    postPath = path;
    if (fail) throw StateError('offline');
    return postGate?.future ?? {'booking': checkedInBooking()};
  }
}

Future<void> openArrival(
  WidgetTester tester,
  ArrivalApi api, {
  DateTime Function()? now,
  Future<void> Function(CustomerBooking)? onOpenTicket,
  VoidCallback? onCheckedIn,
}) async {
  await tester.pumpWidget(
    ShadcnApp(
      home: BookingDetailPage(
        repository: BookingRepository(api),
        booking: CustomerBooking(api.data),
        now: now ?? () => scheduled,
        onOpenTicket: onOpenTicket,
        onCheckedIn: onCheckedIn,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> showCheckIn(WidgetTester tester) async {
  await Scrollable.ensureVisible(
    tester.element(find.byKey(const Key('booking-check-in'))),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('arrival uses root schedule with inclusive 15-minute boundaries', () {
    final booking = CustomerBooking({
      ...arrivalBooking(),
      'bundleItems': [
        {
          'scheduledStartAt': scheduled
              .subtract(const Duration(hours: 3))
              .toIso8601String(),
        },
      ],
    });
    expect(
      booking.canCheckIn(scheduled.subtract(const Duration(minutes: 15))),
      isTrue,
    );
    expect(
      booking.canCheckIn(scheduled.add(const Duration(minutes: 15))),
      isTrue,
    );
    expect(
      booking.canCheckIn(
        scheduled.subtract(const Duration(minutes: 15, seconds: 1)),
      ),
      isFalse,
    );
    expect(
      booking.canCheckIn(
        scheduled.add(const Duration(minutes: 15, seconds: 1)),
      ),
      isFalse,
    );
  });
  test('vendor opt-in, status and verified payment gate customer arrival', () {
    for (final change in <Map<String, dynamic>>[
      {'customerSelfCheckInEnabled': false},
      {'customerSelfCheckInEnabled': null},
      {'status': 'pending'},
      {'status': 'canceled'},
      {'expiredAt': 'now'},
      {'checkedInAt': 'now'},
      {
        'linkedTicket': {'id': 'ticket'},
      },
      {'serviceManualPaymentRequired': true, 'paymentStatus': 'pending'},
      {'serviceManualPaymentRequired': true, 'paymentStatus': 'rejected'},
    ]) {
      expect(
        CustomerBooking({...arrivalBooking(), ...change}).canCheckIn(scheduled),
        isFalse,
      );
    }
    expect(
      CustomerBooking({
        ...arrivalBooking(),
        'serviceManualPaymentRequired': true,
        'paymentStatus': 'pending',
        'paymentVerifiedAt': 'verified',
      }).canCheckIn(scheduled),
      isTrue,
    );
  });
  testWidgets(
    'arrival blocks duplicate submits and stale poll; alert links returned ticket above card',
    (tester) async {
      final api = ArrivalApi();
      var checkedIn = 0;
      CustomerBooking? opened;
      await openArrival(
        tester,
        api,
        onCheckedIn: () => checkedIn++,
        onOpenTicket: (item) async {
          opened = item;
        },
      );
      api.getGate = Completer();
      await tester.pump(const Duration(seconds: 15));
      api.postGate = Completer();
      await showCheckIn(tester);
      await tester.tap(find.byKey(const Key('booking-check-in')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('booking-check-in')));
      expect(api.posts, 1);
      expect(api.postPath, '/api/account/bookings/booking%2Fone/arrival');
      api.postGate!.complete({'booking': checkedInBooking()});
      await tester.pumpAndSettle();
      api.data = checkedInBooking();
      api.getGate!.complete({'booking': arrivalBooking()});
      api.getGate = null;
      await tester.pumpAndSettle();
      expect(checkedIn, 1);
      expect(find.byKey(const Key('booking-check-in')), findsNothing);
      final alert = find.byKey(const Key('booking-details-alert'));
      final card = find.byKey(const Key('booking-details-card'));
      expect(
        find.descendant(
          of: alert,
          matching: find.byKey(const Key('booking-queue-link')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.textContaining('You’re checked in'),
        ),
        findsNothing,
      );
      await Scrollable.ensureVisible(tester.element(alert));
      await tester.pumpAndSettle();
      expect(
        tester.getBottomLeft(alert).dy,
        lessThanOrEqualTo(tester.getTopLeft(card).dy),
      );
      await tester.tap(find.byKey(const Key('booking-queue-link')));
      await tester.pumpAndSettle();
      expect(opened?.linkedTicket?['lookupCode'], 'LOOKUP');
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('failed arrival retains details and permits retry', (
    tester,
  ) async {
    final api = ArrivalApi()..fail = true;
    await openArrival(tester, api);
    await showCheckIn(tester);
    await tester.tap(find.byKey(const Key('booking-check-in')));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not record arrival. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('BKG-ARRIVAL'), findsOneWidget);
    api.fail = false;
    await tester.tap(find.byKey(const Key('booking-check-in')));
    await tester.pumpAndSettle();
    expect(api.posts, 2);
    expect(find.byKey(const Key('booking-queue-link')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'check-in countdown includes days hours and minutes with centered text',
    (tester) async {
      final now = scheduled.subtract(
        const Duration(days: 5, hours: 4, minutes: 30),
      );
      await openArrival(tester, ArrivalApi(), now: () => now);
      final label = find.text('Check-in available in 5days 4hrs 15mins');
      expect(label, findsOneWidget);
      expect(tester.widget<Text>(label).textAlign, TextAlign.center);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('check-in becomes available as foreground clock enters window', (
    tester,
  ) async {
    final api = ArrivalApi();
    var now = scheduled.subtract(const Duration(minutes: 16));
    await openArrival(tester, api, now: () => now);
    expect(find.text('Check-in available in 1min'), findsOneWidget);
    now = scheduled.subtract(const Duration(minutes: 15));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('I’ve arrived'), findsOneWidget);
    now = scheduled.add(const Duration(minutes: 15, seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Arrival window closed · Contact vendor'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
