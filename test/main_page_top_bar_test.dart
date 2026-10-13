import 'dart:async';

import 'package:getprio_mobile/notifications/notification_inbox.dart';
import 'package:getprio_mobile/notifications/notification_inbox_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:getprio_mobile/account/ticket_repository.dart';
import 'package:getprio_mobile/main.dart';
import 'package:getprio_mobile/push/push_coordinator.dart';
import 'package:getprio_mobile/navigation/scroll_aware_app_bar.dart';
import 'package:getprio_mobile/navigation/main_page_top_bar.dart';
import 'package:getprio_mobile/queue/queue_models.dart';

import 'notification_inbox_test.dart' show InboxApi, notification;

class OverviewApi implements AccountQueueApi {
  int calls = 0;
  @override
  Future<Map<String, dynamic>> loadOverview() async {
    calls++;
    return {
      'tickets': [
        {
          'id': 'ticket',
          'lookupCode': 'REF',
          'ticketNumber': 'AH008',
          'status': 'waiting',
          'position': 2,
          'estimatedWaitMinutes': 24,
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

void main() {
  testWidgets(
    'closing inbox releases navigation guard even while refresh is stalled',
    (tester) async {
      final api = InboxApi();
      await tester.pumpWidget(
        ShadcnApp(home: CustomerShell(notificationInboxApi: api)),
      );
      await tester.pumpAndSettle();
      api.gate = Completer<NotificationInboxSnapshot>();
      await tester.tap(find.byKey(const Key('main-notification-center')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byType(GetPrioBackButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(NotificationInboxPage), findsNothing);
      await tester.tap(find.byKey(const Key('main-notification-center')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(NotificationInboxPage), findsOneWidget);
      api.gate!.complete(
        const NotificationInboxSnapshot(items: [], unreadCount: 0, cutoff: 'x'),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
    },
  );

  testWidgets(
    'silent queue signals do not fetch inbox and visible push bursts coalesce',
    (tester) async {
      final api = InboxApi();
      final signal = ValueNotifier<PushSignal?>(null);
      await tester.pumpWidget(
        ShadcnApp(
          home: CustomerShell(notificationInboxApi: api, pushSignal: signal),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.loads, 1);
      signal.value = const PushSignal(
        eventType: 'queue_moved',
        notificationId: 'silent',
        silent: true,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(api.loads, 1);
      for (var i = 0; i < 3; i++) {
        signal.value = PushSignal(
          eventType: 'customer_queue_called',
          notificationId: 'visible-$i',
        );
      }
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(api.loads, 2);
      await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
      signal.dispose();
    },
  );

  testWidgets(
    'account-scoped inbox opens from all tabs and closes on account replacement',
    (tester) async {
      final firstApi = InboxApi()..rows.add(notification('old'));
      final secondApi = InboxApi();
      Widget page(InboxApi api) =>
          ShadcnApp(home: CustomerShell(notificationInboxApi: api));
      await tester.pumpWidget(page(firstApi));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('main-page-top-bar')), findsOneWidget);
      await tester.tap(find.byKey(const Key('main-notification-center')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('notification-old')), findsOneWidget);
      await tester.pumpWidget(page(secondApi));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('notification-old')), findsNothing);
      expect(
        find.byKey(const Key('main-notification-unread-badge')),
        findsNothing,
      );
      for (final tab in ['Explore', 'Lists', 'Profile']) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('main-page-top-bar')), findsOneWidget);
        final scope = tester
            .widget<MainPageTopBar>(find.byType(MainPageTopBar))
            .scope;
        expect(
          scope.activePage,
          tab == 'Profile' ? 'account' : tab.toLowerCase(),
        );
        await tester.tap(find.byKey(const Key('main-notification-center')));
        await tester.pumpAndSettle();
        expect(find.text('No notifications yet'), findsOneWidget);
        await tester.tap(find.byType(GetPrioBackButton));
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
    },
  );

  testWidgets('multiple active tickets cycle upward and pause when inactive', (
    tester,
  ) async {
    final repo = QueueTicketRepository(OverviewApi());
    repo.overviewTickets.value = [
      for (final id in ['a', 'b'])
        QueueTicket.fromJson({
          'id': id,
          'lookupCode': id,
          'ticketNumber': id,
          'status': 'waiting',
          'position': 2,
          'estimatedWaitMinutes': 24,
        }),
    ];
    final unread = ValueNotifier<int>(0);
    String? opened;
    Widget page(bool active) => ShadcnApp(
      home: MainPageTopBarScope(
        tickets: repo,
        unreadCount: unread,
        onNotifications: () {},
        onTicket: (ticket) => opened = ticket.id,
        child: Builder(
          builder: (context) => MainPageTopBar(
            scope: MainPageTopBarScope.maybeOf(context)!,
            active: active,
          ),
        ),
      ),
    );
    await tester.pumpWidget(page(true));
    expect(find.text('a #2 in 24mins'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 140));
    final target = find.byKey(const ValueKey('main-ticket-quickstats-b'));
    final transform = find
        .ancestor(of: target, matching: find.byType(Transform))
        .first;
    expect(
      tester.widget<Transform>(transform).transform.storage[13],
      greaterThan(0),
    );
    await tester.pumpAndSettle();
    expect(find.text('b #2 in 24mins'), findsOneWidget);
    await tester.tap(target);
    expect(opened, 'b');
    await tester.pumpWidget(page(false));
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('b #2 in 24mins'), findsOneWidget);
    await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
    unread.dispose();
  });

  test('quickstats omit invented position/wait and show authoritative called status', () {
    expect(
      ticketQuickstats(
        QueueTicket.fromJson({
          'lookupCode': 'R',
          'ticketNumber': 'AH008',
          'status': 'waiting',
          'position': 2,
          'estimatedWaitMinutes': 24,
        }),
      ),
      'AH008 #2 in 24mins',
    );
    expect(
      ticketQuickstats(
        QueueTicket.fromJson({
          'lookupCode': 'R',
          'ticketNumber': 'AH008',
          'status': 'called',
          'customerConfirmedAt': '2026-10-13T00:00:00Z',
        }),
      ),
      'AH008 · Confirmed',
    );
  });
  testWidgets(
    'all main pages show scrolling topbar 20px before title without extra ticket requests',
    (tester) async {
      final api = OverviewApi();
      final tickets = QueueTicketRepository(api);
      final unread = ValueNotifier<int>(2);
      var opened = 0;
      await tester.pumpWidget(
        ShadcnApp(
          home: MainPageTopBarScope(
            tickets: tickets,
            unreadCount: unread,
            onNotifications: () => opened++,
            child: CustomerShell(ticketRepository: tickets),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('AH008 #2 in 24mins'), findsOneWidget);
      final calls = api.calls;
      tickets.overviewTickets.value = [
        QueueTicket.fromJson({
          'lookupCode': 'REF',
          'ticketNumber': 'AH009',
          'status': 'waiting',
          'position': 1,
          'estimatedWaitMinutes': 12,
        }),
      ];
      await tester.pumpAndSettle();
      expect(find.text('AH009 #1 in 12mins'), findsOneWidget);
      expect(api.calls, calls);
      final bar = find.byKey(const Key('main-page-top-bar'));
      final title = find.byKey(const Key('main-page-title'));
      expect(tester.getTopLeft(title).dy - tester.getBottomLeft(bar).dy, 20);
      expect(
        find.byKey(const Key('main-notification-unread-badge')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('main-notification-center')));
      expect(opened, 1);
      final initial = tester.getTopLeft(bar).dy;
      await tester.drag(
        find.byKey(const Key('home-page')),
        const Offset(0, -180),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(bar).dy, lessThan(initial));
      for (final label in ['Explore', 'Lists', 'Profile']) {
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(bar, findsOneWidget);
        expect(tester.getTopLeft(title).dy - tester.getBottomLeft(bar).dy, 20);
      }
      await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
      unread.dispose();
    },
  );
}
