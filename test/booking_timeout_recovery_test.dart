import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:getprio_mobile/auth/auth_models.dart';
import 'package:getprio_mobile/main.dart';
import 'package:getprio_mobile/navigation/lists_page.dart';
import 'package:getprio_mobile/directory/directory_repository.dart';
import 'package:getprio_mobile/queue/auth_queue_api.dart';

import 'queue_repository_test.dart' show FakeAuthApiForTransport;

import 'package:getprio_mobile/auth/auth_repository.dart';

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

class FailedArrival extends ArrivalApi {
  FailedArrival(this.error);
  Object? error;
  bool failRead = false;
  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    posts++;
    if (error != null) throw error!;
    return {'booking': checkedInBooking()};
  }

  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) {
    if (failRead) return Future.error(StateError('read unavailable'));
    return super.get(path, query: query);
  }
}

void main() {
  test('canonical staff check-in invalidates ticket data once', () async {
    final api = ArrivalApi()..data = checkedInBooking();
    final repository = BookingRepository(api);
    final result = await repository.detail('booking/one');
    expect(result.isCheckedIn, isTrue);
    expect(repository.confirmedArrivalVersion.value, 1);
    await repository.detail('booking/one');
    expect(repository.confirmedArrivalVersion.value, 1);
  });
  for (final error in [
    http.ClientException('connection lost'),
    const ApiException(503, 'gateway', 'Unknown result'),
  ]) {
    test(
      'non-authoritative arrival failure stays blocked across failed and pre-commit reads: $error',
      () async {
        final api = FailedArrival(error);
        final repository = BookingRepository(api);
        await expectLater(
          repository.checkIn(CustomerBooking(arrivalBooking()), scheduled),
          throwsA(same(error)),
        );
        expect(repository.arrivalNeedsReconciliation('booking/one'), isTrue);
        api.failRead = true;
        await expectLater(
          repository.reconcileArrival('booking/one'),
          throwsStateError,
        );
        api.failRead = false;
        await repository.reconcileArrival('booking/one');
        expect(repository.arrivalNeedsReconciliation('booking/one'), isTrue);
        await expectLater(
          repository.checkIn(CustomerBooking(arrivalBooking()), scheduled),
          throwsStateError,
        );
        expect(api.posts, 1);
        api.data = checkedInBooking();
        await repository.reconcileArrival('booking/one');
        expect(repository.arrivalNeedsReconciliation('booking/one'), isFalse);
        expect(repository.confirmedArrivalVersion.value, 1);
      },
    );
  }
  test('definitive rejected arrival remains retryable', () async {
    final api = FailedArrival(
      const ApiException(400, 'rejected', 'Not accepted'),
    );
    final repository = BookingRepository(api);
    await expectLater(
      repository.checkIn(CustomerBooking(arrivalBooking()), scheduled),
      throwsA(isA<ApiException>()),
    );
    expect(repository.arrivalNeedsReconciliation('booking/one'), isFalse);
    api.error = null;
    final updated = await repository.checkIn(
      CustomerBooking(arrivalBooking()),
      scheduled,
    );
    expect(updated.isCheckedIn, isTrue);
    expect(api.posts, 2);
  });
  for (final replaceAccount in [false, true]) {
    testWidgets(
      'late arrival refreshes current shell once, replaced account=$replaceAccount',
      (tester) async {
        final auth = AuthRepository(
          api: FakeAuthApiForTransport(),
          tokenStore: MemoryTokenStore(),
        );
        await auth.signIn(identifier: 'customer', password: 'password');
        final response = Completer<http.Response>();
        var data = arrivalBooking();
        final client = AuthenticatedApiClient(
          baseUrl: 'https://api.example.test',
          authRepository: auth,
          client: MockClient((request) async {
            if (request.url.path.endsWith('/arrival')) return response.future;
            return http.Response(
              jsonEncode({'booking': data, 'bookings': [], 'vendors': []}),
              200,
            );
          }),
        );
        final directory = DirectoryRepository(RestDirectoryApi(client));
        final tickets = QueueTicketRepository(
          FakeAccountQueueApi(overview: {}, history: {}),
        );
        const user = AuthUser(id: 'a', email: 'a@example.test');
        Widget shell(AuthUser customer) => ShadcnApp(
          home: CustomerShell(
            user: customer,
            ticketRepository: tickets,
            directoryRepository: directory,
          ),
        );
        await tester.pumpWidget(shell(user));
        await tester.pumpAndSettle();
        final repository = tester
            .widget<ListsPage>(find.byType(ListsPage, skipOffstage: false))
            .bookingRepository!;
        final pending = repository.checkIn(
          CustomerBooking(arrivalBooking()),
          scheduled,
        );
        final timeout = expectLater(pending, throwsA(isA<TimeoutException>()));
        await tester.pump(const Duration(seconds: 21));
        await timeout;
        if (replaceAccount) {
          await tester.pumpWidget(shell(user.copyWith(id: 'b')));
          await tester.pumpAndSettle();
        }
        final previous = tickets.refreshVersion.value;
        data = checkedInBooking();
        response.complete(http.Response(jsonEncode({'booking': data}), 200));
        await tester.pumpAndSettle();
        expect(repository.confirmedArrivalVersion.value, 1);
        expect(
          tickets.refreshVersion.value,
          previous + (replaceAccount ? 0 : 1),
        );
        await repository.reconcileArrival('booking/one');
        await tester.pumpAndSettle();
        expect(repository.confirmedArrivalVersion.value, 1);
        expect(
          tickets.refreshVersion.value,
          previous + (replaceAccount ? 0 : 1),
        );
        await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
      },
    );
  }
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
        var confirmed = 0;
        Widget page() => ShadcnApp(
          home: BookingDetailPage(
            repository: repository,
            booking: CustomerBooking(arrivalBooking()),
            now: () => scheduled,
            onCheckedIn: () => confirmed++,
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
          expect(find.textContaining('still processing'), findsNothing);
          expect(confirmed, 1);
          api.postGate!.complete({'booking': checkedInBooking()});
        } else {
          api.postGate!.completeError(
            const ApiException(400, 'rejected', 'Check-in rejected'),
          );
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
