import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:getprio_mobile/account/ticket_repository.dart';
import 'package:getprio_mobile/bookings/booking_repository.dart';
import 'package:getprio_mobile/bookings/bookings_page.dart';
import 'package:getprio_mobile/navigation/lists_overview.dart';

import 'booking_check_in_test.dart'
    show ArrivalApi, arrivalBooking, checkedInBooking, scheduled, showCheckIn;
import 'review_refresh_regressions_test.dart' show PendingBookings;
import 'directory_and_ticket_repository_test.dart' show FakeAccountQueueApi;

void main() {
  testWidgets(
    'pre-settlement read cannot clear uncertain arrival after late commit',
    (tester) async {
      final api = ArrivalApi()..postGate = Completer<Map<String, dynamic>>();
      final repository = BookingRepository(api);
      final pending = repository.checkIn(
        CustomerBooking(arrivalBooking()),
        scheduled,
      );
      final deadline = expectLater(pending, throwsA(isA<TimeoutException>()));
      await tester.pump(const Duration(seconds: 21));
      await deadline;
      api.getGate = Completer<Map<String, dynamic>>();
      final staleRead = repository.reconcileArrival('booking/one');
      api.postGate!.complete({'booking': checkedInBooking()});
      await tester.pump();
      api.getGate!.complete({'booking': arrivalBooking()});
      await staleRead;
      expect(repository.arrivalNeedsReconciliation('booking/one'), isTrue);
      api.getGate = null;
      api.data = checkedInBooking();
      final fresh = await repository.reconcileArrival('booking/one');
      expect(fresh.isCheckedIn, isTrue);
      expect(repository.arrivalNeedsReconciliation('booking/one'), isFalse);
    },
  );
  for (final accepted in [false, true]) {
    testWidgets(
      'arrival timeout restores refresh; late accepted=$accepted reconciles before retry',
      (tester) async {
        final api = ArrivalApi()..postGate = Completer<Map<String, dynamic>>();
        final repository = BookingRepository(api);
        Widget page() => ShadcnApp(
          home: BookingDetailPage(
            repository: repository,
            booking: CustomerBooking(arrivalBooking()),
            now: () => scheduled,
          ),
        );
        await tester.pumpWidget(page());
        await tester.pumpAndSettle();
        await showCheckIn(tester);
        await tester.tap(find.byKey(const Key('booking-check-in')));
        await tester.pump();
        await tester.pump(const Duration(seconds: 21));
        await tester.pumpAndSettle();
        expect(find.text('Recording arrival...'), findsNothing);
        expect(
          find.text(
            'Check-in is still processing. Refresh status before trying again.',
          ),
          findsOneWidget,
        );
        expect(repository.arrivalNeedsReconciliation('booking/one'), isTrue);
        expect(
          tester
              .widget<PrimaryButton>(find.byKey(const Key('booking-check-in')))
              .onPressed,
          isNull,
        );
        await expectLater(
          repository.checkIn(CustomerBooking(arrivalBooking()), scheduled),
          throwsStateError,
        );
        expect(api.posts, 1);
        // Closing/reopening must not bypass account-session reconciliation state.
        await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
        await tester.pumpWidget(page());
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<PrimaryButton>(find.byKey(const Key('booking-check-in')))
              .onPressed,
          isNull,
        );
        if (accepted) {
          // Staff/authoritative updates can refresh even while the original POST is pending.
          api.data = checkedInBooking();
          await tester.pump(const Duration(seconds: 15));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('booking-check-in')), findsNothing);
          expect(
            find.text(
              'You’re checked in. Follow your queue ticket for service updates.',
            ),
            findsOneWidget,
          );
          api.postGate!.complete({'booking': checkedInBooking()});
        } else {
          api.postGate!.completeError(StateError('lost request'));
          api.postGate = null;
          await tester.pump();
          // Settlement alone is insufficient; retain the guard until a fresh GET.
          expect(repository.arrivalNeedsReconciliation('booking/one'), isTrue);
          await tester.pump(const Duration(seconds: 15));
          await tester.pumpAndSettle();
          expect(repository.arrivalNeedsReconciliation('booking/one'), isFalse);
          await showCheckIn(tester);
          await tester.tap(find.byKey(const Key('booking-check-in')));
          await tester.pumpAndSettle();
          expect(api.posts, 2);
          expect(find.byKey(const Key('booking-check-in')), findsNothing);
        }
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
      },
    );
  }
  for (final pendingSignal in [false, true]) {
    testWidgets(
      'Lists stalled upcoming loader recovers with pending signal=$pendingSignal',
      (tester) async {
        final api = PendingBookings();
        final signals = QueueTicketRepository(
          FakeAccountQueueApi(overview: {}, history: {}),
        );
        await tester.pumpWidget(
          ShadcnApp(
            home: Scaffold(
              child: SingleChildScrollView(
                child: ListsOverview(
                  active: true,
                  ticketRepository: signals,
                  bookingRepository: BookingRepository(api),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        if (pendingSignal) signals.requestRefresh();
        await tester.pump(const Duration(seconds: 21));
        await tester.pumpAndSettle();
        if (!pendingSignal) {
          expect(
            find.text('Could not update upcoming bookings.'),
            findsOneWidget,
          );
          signals.requestRefresh();
          await tester.pumpAndSettle();
        }
        expect(api.calls, greaterThan(3));
        expect(find.text('Updated booking'), findsWidgets);
        api.first.complete({
          'bookings': [],
          'pagination': {'totalPages': 1},
        });
        await tester.pumpAndSettle();
        expect(find.text('Updated booking'), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
      },
    );
  }
}
