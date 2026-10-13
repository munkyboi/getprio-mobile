import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:getprio_mobile/account/ticket_repository.dart';
import 'package:getprio_mobile/bookings/booking_repository.dart';
import 'package:getprio_mobile/navigation/lists_overview.dart';

class OverviewTickets implements AccountQueueApi {
  int calls = 0;
  bool fail = false;
  @override
  Future<Map<String, dynamic>> loadOverview() async {
    calls++;
    if (fail) throw StateError('offline');
    return {
      'tickets': [
        {
          'id': 'active',
          'lookupCode': 'ACTIVE',
          'ticketNumber': 'A001',
          'status': 'called',
          'tenantName': 'Active clinic',
        },
        {
          'id': 'past',
          'lookupCode': 'PAST',
          'status': 'served',
          'tenantName': 'Past clinic',
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> loadHistory({
    required int page,
    required int limit,
  }) async => {};
}

class OverviewBookings implements BookingApi {
  final requests = <Map<String, String>>[];
  bool fail = false;
  bool checkedIn = false;
  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    requests.add(query!);
    if (fail) throw StateError('offline');
    final status = query['status']!;
    final page = query['page']!;
    final id = '$status-$page';
    return {
      'bookings': [
        {
          'id': id,
          'status': status,
          if (checkedIn && status == 'confirmed')
            'checkedInAt': '2026-10-10T09:00:00Z',
          'tenantName': 'Vendor $id',
          'paymentStatus': 'paid',
          'scheduledStartAt': '2026-10-${page == '2' ? '10' : '12'}T09:00:00Z',
        },
      ],
      'pagination': {'totalPages': status == 'pending' ? 2 : 1},
    };
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async => {};
}

void main() {
  testWidgets('refresh received during initial list load is replayed', (
    tester,
  ) async {
    final api = PendingOverview();
    final repository = QueueTicketRepository(api);
    await tester.pumpWidget(
      ShadcnApp(
        home: SingleChildScrollView(
          child: ListsOverview(active: true, ticketRepository: repository),
        ),
      ),
    );
    await tester.pump();
    expect(api.calls, 1);
    repository.requestRefresh();
    repository.requestRefresh();
    api.gate.complete({'tickets': []});
    await tester.pumpAndSettle();
    expect(api.calls, 2);
    expect(find.text('Active clinic'), findsOneWidget);
    await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
  });

  test(
    'booking row uses check-in evidence without hiding terminal statuses',
    () {
      for (final evidence in [
        {'checkedInAt': '2026-10-10T09:00:00Z'},
        {'queueTicketId': 'ticket-1'},
        {
          'linkedTicket': {'id': 'ticket-1', 'lookupCode': 'ABC123'},
        },
      ]) {
        final upcoming = CustomerBooking({'status': 'confirmed', ...evidence});
        expect(upcoming.listStatusLabel, 'checked-in');
        expect(upcoming.status, 'confirmed');
        expect(upcoming.isUpcoming, isTrue);
        expect(
          CustomerBooking({'status': 'canceled', ...evidence}).listStatusLabel,
          'canceled',
        );
      }
      expect(
        CustomerBooking({'status': 'confirmed'}).listStatusLabel,
        'confirmed',
      );
    },
  );
  testWidgets('Lists upcoming checked-in booking displays checked-in status', (
    tester,
  ) async {
    final api = OverviewBookings()..checkedIn = true;
    await tester.pumpWidget(
      ShadcnApp(
        home: SingleChildScrollView(
          child: ListsOverview(
            active: true,
            bookingRepository: BookingRepository(api),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('lists-booking-confirmed-1'));
    await Scrollable.ensureVisible(tester.element(row));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: row, matching: find.text('checked-in')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text('confirmed')),
      findsNothing,
    );
    expect(
      find.descendant(of: row, matching: find.text('Payment: paid')),
      findsOneWidget,
    );
  });
  test('upcoming includes every status page and orders by visit', () async {
    final api = OverviewBookings();
    final items = await BookingRepository(api).upcoming();
    expect(items.length, 4);
    expect(items.first.id, 'pending-2');
    expect(api.requests.map((q) => q['status']).toSet(), {
      'pending',
      'confirmed',
      'rescheduled',
    });
    expect(api.requests.where((q) => q['page'] == '2').length, 1);
  });
  testWidgets(
    'loads only while active, filters tickets, opens rows and retains sections on failure',
    (tester) async {
      final tickets = OverviewTickets();
      final repository = QueueTicketRepository(tickets);
      final bookings = OverviewBookings();
      String? openedTicket, openedBooking;
      Widget overview(bool active) => ShadcnApp(
        home: SingleChildScrollView(
          child: ListsOverview(
            active: active,
            ticketRepository: repository,
            bookingRepository: BookingRepository(bookings),
            onOpenTicket: (ticket) async {
              openedTicket = ticket.lookupCode;
            },
            onOpenBooking: (booking) async {
              openedBooking = booking.id;
            },
          ),
        ),
      );
      await tester.pumpWidget(overview(false));
      await tester.pumpAndSettle();
      expect(tickets.calls, 0);
      expect(bookings.requests, isEmpty);
      await tester.pumpWidget(overview(true));
      await tester.pumpAndSettle();
      expect(find.text('Active clinic'), findsOneWidget);
      expect(find.text('Past clinic'), findsNothing);
      expect(find.text('CALLED'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('lists-ticket-active')));
      await tester.pumpAndSettle();
      expect(openedTicket, 'ACTIVE');
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('lists-booking-pending-2'))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('lists-booking-pending-2')));
      await tester.pumpAndSettle();
      expect(openedBooking, 'pending-2');
      tickets.fail = true;
      bookings.fail = true;
      repository.requestRefresh();
      await tester.pumpAndSettle();
      expect(find.text('Could not update queue tickets.'), findsOneWidget);
      expect(find.text('Could not update upcoming bookings.'), findsOneWidget);
      expect(find.text('Active clinic'), findsOneWidget);
      expect(find.text('Vendor pending-2'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      repository.refreshVersion.dispose();
      repository.ticketStats.dispose();
      repository.servedTicket.dispose();
    },
  );
}

class PendingOverview extends OverviewTickets {
  final gate = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> loadOverview() {
    if (calls == 0) {
      calls++;
      return gate.future;
    }
    return super.loadOverview();
  }
}
