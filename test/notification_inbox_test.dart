import 'dart:async';

import 'package:getprio_mobile/account/account_settings_repository.dart';
import 'package:getprio_mobile/notifications/notification_settings_card.dart';

import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:getprio_mobile/notifications/notification_inbox_page.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/notifications/notification_inbox.dart';

class InboxApi implements NotificationInboxApi {
  final rows = <InboxNotification>[];
  bool fail = false;
  int loads = 0;
  Completer<NotificationInboxSnapshot>? gate;
  String? readId, bulkCutoff, clearCutoff;
  @override
  Future<NotificationInboxSnapshot> load({String? cursor}) async {
    loads++;
    if (gate != null) return gate!.future;
    if (fail) throw StateError('offline');
    return NotificationInboxSnapshot(
      items: List.of(rows),
      totalCount: rows.length,
      unreadCount: rows.where((item) => item.unread).length,
      cutoff: 'snapshot-1',
    );
  }

  @override
  Future<void> markRead(String id) async {
    if (fail) throw StateError('offline');
    readId = id;
    final index = rows.indexWhere((item) => item.id == id);
    final item = rows[index];
    rows[index] = InboxNotification(
      id: item.id,
      title: item.title,
      body: item.body,
      createdAt: item.createdAt,
      readAt: DateTime.utc(2026),
    );
  }

  @override
  Future<void> markAllRead(String cutoff) async {
    bulkCutoff = cutoff;
    for (final item in List.of(rows)) {
      if (item.unread) await markRead(item.id);
    }
  }

  @override
  Future<void> clear(String cutoff) async {
    clearCutoff = cutoff;
    rows.clear();
  }
}

InboxNotification notification(String id) => InboxNotification(
  id: id,
  title: 'Your ticket was called',
  body: 'Proceed to the vendor.',
  createdAt: DateTime.utc(2026, 10, 13),
);

void main() {
  testWidgets(
    'settings card precedes actions and summary; saving failures retain preference',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = SettingsApi();
      final inbox = NotificationInboxController(PagedInboxApi());
      await tester.pumpWidget(
        ShadcnApp(
          home: NotificationInboxPage(
            controller: inbox,
            settingsRepository: AccountSettingsRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = find.byKey(const Key('notification-settings-card'));
      final actions = find.byKey(const Key('notification-read-all'));
      final summary = find.byKey(const Key('notification-inbox-summary'));
      expect(
        tester.getTopLeft(card).dy,
        lessThan(tester.getTopLeft(actions).dy),
      );
      expect(
        tester.getTopLeft(actions).dy,
        lessThan(tester.getTopLeft(summary).dy),
      );
      expect(
        tester.widget<Text>(summary).textSpan!.toPlainText(),
        'Unread: 2  |  Total: 24',
      );
      await tester.tap(find.byKey(const Key('notification-queue-alerts')));
      await tester.pumpAndSettle();
      expect(api.enabled, isFalse);
      api.fail = true;
      await tester.tap(find.byKey(const Key('notification-queue-alerts')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Switch>(find.byKey(const Key('notification-queue-alerts')))
            .value,
        isFalse,
      );
      expect(find.textContaining('Could not save'), findsOneWidget);
      await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
      inbox.dispose();
    },
  );

  testWidgets('settings load can be retried without hiding inbox actions', (
    tester,
  ) async {
    final api = SettingsApi()..fail = true;
    await tester.pumpWidget(
      ShadcnApp(
        home: NotificationSettingsCard(
          repository: AccountSettingsRepository(api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry settings'), findsOneWidget);
    api.fail = false;
    await tester.tap(find.text('Retry settings'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notification-queue-alerts')), findsOneWidget);
  });

  test(
    'pagination deduplicates rows and preserves original bulk cutoff',
    () async {
      final api = PagedInboxApi();
      final inbox = NotificationInboxController(api);
      await inbox.refresh();
      await inbox.loadMore();
      expect(inbox.items.map((item) => item.id), ['a', 'b']);
      expect(inbox.cutoff, 'original');
      expect(api.cursor, 'opaque-next');
      expect(inbox.totalCount, 24);
      inbox.dispose();
    },
  );

  testWidgets('inbox rows mark unread on tap and bulk actions update badges', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = InboxApi()..rows.addAll([notification('a'), notification('b')]);
    final inbox = NotificationInboxController(api);
    await tester.pumpWidget(
      ShadcnApp(home: NotificationInboxPage(controller: inbox)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('notification-a')));
    await tester.pumpAndSettle();
    expect(api.readId, 'a');
    expect(inbox.unreadCount.value, 1);
    await tester.tap(find.byKey(const Key('notification-read-all')));
    await tester.pumpAndSettle();
    expect(inbox.unreadCount.value, 0);
    await tester.tap(find.byKey(const Key('notification-clear')));
    await tester.pumpAndSettle();
    expect(find.text('No notifications yet'), findsOneWidget);
    expect(inbox.items, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
    inbox.dispose();
  });

  test('unread tap/read-all/empty use snapshot cutoff and refresh authoritative state', () async {
    final api = InboxApi()..rows.addAll([notification('a'), notification('b')]);
    final inbox = NotificationInboxController(api);
    await inbox.refresh();
    expect(inbox.unreadCount.value, 2);
    expect(inbox.totalCount, 2);
    await inbox.markRead(inbox.items.first);
    expect(api.readId, 'a');
    expect(inbox.unreadCount.value, 1);
    await inbox.markAllRead();
    expect(api.bulkCutoff, 'snapshot-1');
    expect(inbox.unreadCount.value, 0);
    await inbox.clear();
    expect(api.clearCutoff, 'snapshot-1');
    expect(inbox.items, isEmpty);
    expect(inbox.totalCount, 0);
    inbox.dispose();
  });
  test('failed mutation retains unread rows and exposes retry error', () async {
    final api = InboxApi()..rows.add(notification('a'));
    final inbox = NotificationInboxController(api);
    await inbox.refresh();
    api.fail = true;
    await inbox.markRead(inbox.items.first);
    expect(inbox.items.single.unread, isTrue);
    expect(inbox.unreadCount.value, 1);
    expect(inbox.error, contains('Could not update'));
    inbox.dispose();
  });
  test(
    'late responses after disposal cannot restore another session inbox',
    () async {
      final api = InboxApi()..gate = Completer();
      final inbox = NotificationInboxController(api);
      final pending = inbox.refresh();
      inbox.dispose();
      api.gate!.complete(
        NotificationInboxSnapshot(
          items: [notification('private')],
          unreadCount: 1,
          cutoff: 'x',
        ),
      );
      await pending;
      expect(inbox.items, isEmpty);
    },
  );
}

class PagedInboxApi extends InboxApi {
  String? cursor;
  @override
  Future<NotificationInboxSnapshot> load({String? cursor}) async {
    this.cursor = cursor;
    return NotificationInboxSnapshot(
      items: [notification('a'), if (cursor != null) notification('b')],
      totalCount: 24,
      unreadCount: 2,
      cutoff: cursor == null ? 'original' : 'other',
      nextCursor: cursor == null ? 'opaque-next' : null,
    );
  }
}

class SettingsApi implements AccountSettingsApi {
  bool enabled = true, fail = false;
  @override
  Future<Map<String, dynamic>> loadNotificationSettings() async {
    if (fail) throw StateError('offline');
    return {'queueAlerts': enabled};
  }

  @override
  Future<Map<String, dynamic>> updateNotificationSettings({
    required bool queueAlerts,
  }) async {
    if (fail) throw StateError('offline');
    enabled = queueAlerts;
    return {'queueAlerts': enabled};
  }
}
