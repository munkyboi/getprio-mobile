import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:getprio_mobile/bookings/booking_repository.dart';
import 'package:getprio_mobile/navigation/lists_overview.dart';
import 'package:getprio_mobile/account/ticket_repository.dart';
import 'package:getprio_mobile/main.dart';
import 'package:getprio_mobile/queue/queue_repository.dart';
import 'package:getprio_mobile/queue/queue_models.dart';

import 'booking_detail_live_test.dart' show LiveApi, openLive;
import 'ticket_details_test.dart' show FakeQueueApi;
import 'directory_and_ticket_repository_test.dart' show FakeAccountQueueApi;

class PendingBookings implements BookingApi {
  final first = Completer<Map<String, dynamic>>();
  int calls = 0;
  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    calls++;
    if (calls == 1) return first.future;
    return {
      'bookings': [
        {
          'id': 'new',
          'tenantName': 'Updated booking',
          'status': 'confirmed',
          'queueTicketId': 'queue',
        },
      ],
      'pagination': {'totalPages': 1},
    };
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async => {};
}

class PendingQueue extends FakeQueueApi {
  PendingQueue()
    : super(
        snapshot: {
          'focusTicket': {'id': 't', 'lookupCode': 'T', 'status': 'waiting'},
        },
      );
  final poll = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> loadQueueSnapshot({
    required String tenantSlug,
    String? locationSlug,
    String? lookupCode,
  }) {
    if (loadCalls == 1) {
      loadCalls++;
      return poll.future;
    }
    return super.loadQueueSnapshot(
      tenantSlug: tenantSlug,
      locationSlug: locationSlug,
      lookupCode: lookupCode,
    );
  }
}

void main() {
  testWidgets('booking details recovers from a stalled poll and can retry', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final api = LiveApi();
    await openLive(tester, api);
    api.gate = Completer();
    await tester.pump(const Duration(seconds: 15));
    await tester.pump(const Duration(seconds: 21));
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    api.gate = null;
    api.data = {...api.data, 'status': 'canceled'};
    await tester.ensureVisible(find.text('Try again'));
    tester
        .widget<OutlineButton>(
          find.ancestor(
            of: find.text('Try again'),
            matching: find.byType(OutlineButton),
          ),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('Booking: canceled'), findsOneWidget);
    await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
  });
  testWidgets(
    'Lists replays booking refresh received during its in-flight load',
    (tester) async {
      final api = PendingBookings();
      final signal = QueueTicketRepository(
        FakeAccountQueueApi(overview: {}, history: {}),
      );
      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: SingleChildScrollView(
              child: ListsOverview(
                active: true,
                ticketRepository: signal,
                bookingRepository: BookingRepository(api),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      signal.requestRefresh();
      signal.requestRefresh();
      api.first.complete({
        'bookings': [],
        'pagination': {'totalPages': 1},
      });
      await tester.pumpAndSettle();
      expect(api.calls, greaterThan(3));
      expect(find.text('Updated booking'), findsWidgets);
      await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
    },
  );
  testWidgets(
    'ticket push received during poll is replayed immediately after stale response',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final api = PendingQueue();
      final account = QueueTicketRepository(
        FakeAccountQueueApi(overview: {}, history: {}),
      );
      await tester.pumpWidget(
        ShadcnApp(
          home: TicketDetailsPage(
            ticket: QueueTicket.fromJson({
              'id': 't',
              'lookupCode': 'T',
              'tenantSlug': 'vendor',
              'status': 'waiting',
            }),
            queueRepository: QueueRepository(api),
            ticketRepository: account,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 15));
      account.requestRefresh();
      api.snapshot = {
        'focusTicket': {
          'id': 't',
          'lookupCode': 'T',
          'status': 'called',
          'customerConfirmedAt': '2026-10-13T01:00:00Z',
        },
      };
      api.poll.complete({
        'focusTicket': {'id': 't', 'lookupCode': 'T', 'status': 'waiting'},
      });
      await tester.pumpAndSettle();
      expect(api.loadCalls, 3);
      expect(find.text('CONFIRMED'), findsOneWidget);
      await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
    },
  );
  testWidgets(
    'account service progress wins stale public snapshot, newer completion still advances',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final raw = {
        'id': 't',
        'lookupCode': 'T',
        'tenantSlug': 'vendor',
        'status': 'called',
        'customerConfirmedAt': '2026-10-13T01:00:00Z',
        'serviceStartedAt': '2026-10-13T01:01:00Z',
      };
      final api = FakeQueueApi(
        snapshot: {
          'focusTicket': {'id': 't', 'lookupCode': 'T', 'status': 'called'},
        },
      );
      final account = QueueTicketRepository(
        FakeAccountQueueApi(
          overview: {
            'tickets': [raw],
          },
          history: {},
        ),
      );
      await tester.pumpWidget(
        ShadcnApp(
          home: TicketDetailsPage(
            ticket: QueueTicket.fromJson(raw),
            queueRepository: QueueRepository(api),
            ticketRepository: account,
          ),
        ),
      );
      await tester.pumpAndSettle();
      account.requestRefresh();
      await tester.pumpAndSettle();
      expect(find.text('IN SERVICE'), findsOneWidget);
      expect(find.byKey(const Key('ticket-qr-fab')), findsNothing);
      api.snapshot = {
        'focusTicket': {
          ...raw,
          'serviceOutcome': 'completed',
          'serviceEndedAt': '2026-10-13T01:04:00Z',
        },
      };
      account.requestRefresh();
      await tester.pumpAndSettle();
      expect(find.text('COMPLETED'), findsOneWidget);
      await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
    },
  );
}
