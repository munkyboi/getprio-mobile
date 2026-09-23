import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/account/ticket_repository.dart';
import 'package:getprio_mobile/directory/directory_repository.dart';
import 'package:getprio_mobile/loading_skeleton.dart';
import 'package:getprio_mobile/main.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets('pulling home refreshes the ticket overview', (tester) async {
    final api = _CountingAccountQueueApi();
    await tester.pumpWidget(
      ShadcnApp(home: HomePage(ticketRepository: QueueTicketRepository(api))),
    );
    await tester.pumpAndSettle();

    expect(api.overviewCalls, 1);

    await tester.drag(find.byKey(const Key('home-page')), const Offset(0, 300));
    await tester.pumpAndSettle();

    expect(api.overviewCalls, 2);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('pulling Home shows a refresh confirmation toast', (
    tester,
  ) async {
    final api = _CountingAccountQueueApi();
    await tester.pumpWidget(
      ShadcnApp(home: HomePage(ticketRepository: QueueTicketRepository(api))),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byKey(const Key('home-page')), const Offset(0, 300));
    await tester.pumpAndSettle();

    expect(find.text('Tickets refreshed.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('refreshes the customer ticket overview while the app is open', (
    tester,
  ) async {
    final api = _PollingAccountQueueApi();
    await tester.pumpWidget(
      ShadcnApp(
        home: CustomerShell(ticketRepository: QueueTicketRepository(api)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('#101'), findsOneWidget);
    final initialOverviewCalls = api.overviewCalls;
    expect(initialOverviewCalls, greaterThanOrEqualTo(1));

    api.ticketStatus = 'called';
    api.customerConfirmed = true;
    await tester.pump(const Duration(minutes: 4, seconds: 59));
    expect(api.overviewCalls, initialOverviewCalls);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(api.overviewCalls, greaterThan(initialOverviewCalls));
    expect(find.text('CONFIRMED'), findsOneWidget);
  });

  testWidgets('refreshes the Tickets screen after five minutes', (
    tester,
  ) async {
    final api = _PollingAccountQueueApi();
    await tester.pumpWidget(
      ShadcnApp(
        home: CustomerShell(ticketRepository: QueueTicketRepository(api)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tickets'));
    await tester.pumpAndSettle();

    final initialHistoryCalls = api.historyCalls;
    expect(initialHistoryCalls, greaterThanOrEqualTo(1));

    await tester.pump(const Duration(minutes: 5, seconds: 1));
    await tester.pumpAndSettle();

    expect(api.historyCalls, greaterThan(initialHistoryCalls));
  });

  testWidgets('background ticket refresh keeps the history scroll position', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final api = _SilentRefreshAccountQueueApi();
    final repository = QueueTicketRepository(api);
    await tester.pumpWidget(
      ShadcnApp(home: TicketsPage(ticketRepository: repository)),
    );
    await tester.pumpAndSettle();

    final page = find.byKey(const Key('tickets-page'));
    await tester.fling(page, const Offset(0, -700), 1000);
    await tester.pumpAndSettle();

    final scrollable = find.descendant(
      of: page,
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    final offsetBeforeRefresh = position.pixels;
    expect(offsetBeforeRefresh, greaterThan(0));

    repository.requestRefresh();
    await tester.pump();

    expect(find.byType(TicketsSkeleton), findsNothing);
    expect(position.pixels, closeTo(offsetBeforeRefresh, 0.1));

    api.completeRefresh();
    await tester.pumpAndSettle();

    expect(position.pixels, closeTo(offsetBeforeRefresh, 0.1));
  });

  testWidgets('pulling Explore refreshes the vendor directory', (tester) async {
    final api = _CountingDirectoryApi();
    await tester.pumpWidget(
      ShadcnApp(home: ExplorePage(repository: DirectoryRepository(api))),
    );
    await tester.pumpAndSettle();

    expect(api.vendorCalls, 1);

    await tester.dragFrom(const Offset(195, 100), const Offset(0, 300));
    await tester.pumpAndSettle();

    expect(api.vendorCalls, 2);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('pulling Tickets refreshes active and historical tickets', (
    tester,
  ) async {
    final api = _CountingAccountQueueApi();
    await tester.pumpWidget(
      ShadcnApp(
        home: TicketsPage(ticketRepository: QueueTicketRepository(api)),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.overviewCalls, 1);
    expect(api.historyCalls, 1);

    await tester.dragFrom(const Offset(195, 100), const Offset(0, 300));
    await tester.pumpAndSettle();

    expect(api.overviewCalls, 2);
    expect(api.historyCalls, 2);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}

class _CountingAccountQueueApi implements AccountQueueApi {
  int overviewCalls = 0;
  int historyCalls = 0;

  @override
  Future<Map<String, dynamic>> loadOverview() async {
    overviewCalls++;
    return const {'tickets': []};
  }

  @override
  Future<Map<String, dynamic>> loadHistory({
    required int page,
    required int limit,
  }) async {
    historyCalls++;
    return const {'items': []};
  }
}

class _PollingAccountQueueApi implements AccountQueueApi {
  int overviewCalls = 0;
  int historyCalls = 0;
  String ticketStatus = 'waiting';
  bool customerConfirmed = false;

  @override
  Future<Map<String, dynamic>> loadOverview() async {
    overviewCalls++;
    return {
      'tickets': [
        {
          'id': 'active-1',
          'lookupCode': 'A0C18AF',
          'ticketNumber': '101',
          'tenantName': 'City Clinic',
          'tenantSlug': 'city-clinic',
          'locationName': 'Main location',
          'status': ticketStatus,
          if (customerConfirmed) 'customerConfirmedAt': '2026-09-03T04:00:00Z',
          'position': ticketStatus == 'waiting' ? 2 : null,
          'estimatedWaitMinutes': ticketStatus == 'waiting' ? 10 : null,
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> loadHistory({
    required int page,
    required int limit,
  }) async {
    historyCalls++;
    return const {'items': []};
  }
}

class _SilentRefreshAccountQueueApi implements AccountQueueApi {
  int historyCalls = 0;
  late final Completer<Map<String, dynamic>> _refreshCompleter =
      Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> loadOverview() async => const {'tickets': []};

  @override
  Future<Map<String, dynamic>> loadHistory({
    required int page,
    required int limit,
  }) {
    historyCalls++;
    if (historyCalls == 2) return _refreshCompleter.future;
    return Future.value({'items': _historyTickets()});
  }

  void completeRefresh() {
    _refreshCompleter.complete({'items': _historyTickets()});
  }

  List<Map<String, String>> _historyTickets() => [
    for (var index = 1; index <= 20; index++)
      {
        'id': 'history-$index',
        'lookupCode': 'H${index.toString().padLeft(5, '0')}',
        'ticketNumber': '$index',
        'tenantName': 'Clinic $index',
        'tenantSlug': 'clinic-$index',
        'locationName': 'Main location',
        'status': 'served',
        'joinedAt': '2026-09-02T03:42:00Z',
      },
  ];
}

class _CountingDirectoryApi implements DirectoryApi {
  int vendorCalls = 0;

  @override
  Future<Map<String, dynamic>> loadVendor(String tenantSlug) async => const {};

  @override
  Future<Map<String, dynamic>> loadVendors({
    String? search,
    int limit = 20,
  }) async {
    vendorCalls++;
    return const {
      'vendors': [
        {'slug': 'city-clinic', 'name': 'City Clinic', 'queueAvailable': true},
      ],
    };
  }
}
