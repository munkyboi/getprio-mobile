import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/account/ticket_repository.dart';
import 'package:getprio_mobile/main.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets('home displays account totals and refreshes served count', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = StatsApi();
    final repository = QueueTicketRepository(api);
    await tester.pumpWidget(
      ShadcnApp(home: HomePage(ticketRepository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('75'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    api.served = 2;
    repository.requestRefresh();
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsNothing);
    api.fail = true;
    repository.requestRefresh();
    await tester.pumpAndSettle();
    expect(find.text('—'), findsNWidgets(2));
    expect(find.text('0'), findsNothing);
    api.fail = false;
    repository.requestRefresh();
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('loading stats do not claim zero tickets', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = StatsApi()..pending = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      ShadcnApp(home: HomePage(ticketRepository: QueueTicketRepository(api))),
    );
    expect(find.text('—'), findsNWidgets(2));
    expect(find.text('0'), findsNothing);
    api.pending!.complete({
      'tickets': [],
      'ticketStats': {'joined': 0, 'served': 0},
    });
    await tester.pumpAndSettle();
    expect(find.text('0'), findsNWidgets(2));
  });

  test('clearing a session discards account stats', () async {
    final repository = QueueTicketRepository(StatsApi());
    await repository.loadOverview();
    expect(repository.ticketStats.value?.served, 1);
    repository.clearSession();
    expect(repository.ticketStats.value, isNull);
  });

  test('missing or invalid aggregate data stays unavailable', () {
    for (final value in [
      null,
      {},
      {'joined': -1, 'served': 0},
      {'joined': 1, 'served': 2},
    ]) {
      expect(CustomerTicketStats.fromJson(value), isNull);
    }
  });
}

class StatsApi implements AccountQueueApi {
  int served = 1;
  bool fail = false;
  Completer<Map<String, dynamic>>? pending;

  @override
  Future<Map<String, dynamic>> loadOverview() async {
    if (fail) throw StateError('offline');
    if (pending != null) return pending!.future;
    return {
      'tickets': [],
      'ticketStats': {'joined': 75, 'served': served},
    };
  }

  @override
  Future<Map<String, dynamic>> loadHistory({
    required int page,
    required int limit,
  }) async => {'tickets': []};
}
