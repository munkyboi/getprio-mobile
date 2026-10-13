import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../navigation/scroll_aware_app_bar.dart';
import '../app_theme.dart';
import 'notification_inbox.dart';
import '../account/account_settings_repository.dart';
import 'notification_settings_card.dart';
import 'notification_date_groups.dart';

class NotificationInboxPage extends StatefulWidget {
  const NotificationInboxPage({
    super.key,
    required this.controller,
    this.settingsRepository,
  });
  final AccountSettingsRepository? settingsRepository;
  final NotificationInboxController controller;
  @override
  State<NotificationInboxPage> createState() => _NotificationInboxPageState();
}

class _NotificationInboxPageState extends State<NotificationInboxPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.refresh();
  }

  @override
  Widget build(BuildContext context) => ScrollAwareScaffold(
    headers: [
      ScrollAwareAppBar(
        title: const Text('Notifications'),
        leading: [
          GetPrioBackButton(onPressed: () => Navigator.of(context).pop()),
        ],
      ),
    ],
    child: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final inbox = widget.controller;
        final busy = inbox.loading || inbox.mutating;
        return RefreshTrigger(
          onRefresh: inbox.refresh,
          child: ListView(
            key: const Key('notification-inbox-list'),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const ScrollAwareHeaderSpace(),
              NotificationSettingsCard(repository: widget.settingsRepository),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlineButton(
                    key: const Key('notification-read-all'),
                    onPressed: busy || inbox.unreadCount.value == 0
                        ? null
                        : inbox.markAllRead,
                    leading: const Icon(LucideIcons.checkCheck, size: 16),
                    child: const Text('Mark all as read'),
                  ),
                  OutlineButton(
                    key: const Key('notification-clear'),
                    onPressed: busy || inbox.items.isEmpty ? null : inbox.clear,
                    leading: const Icon(LucideIcons.trash2, size: 16),
                    child: const Text('Empty inbox'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text.rich(
                  key: const Key('notification-inbox-summary'),
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Unread: '),
                      TextSpan(
                        text: inbox.cutoff == null
                            ? '—'
                            : '${inbox.unreadCount.value}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(text: '  |  Total: '),
                      TextSpan(
                        text: inbox.totalCount?.toString() ?? '—',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
              if (inbox.error != null) ...[
                Text(
                  inbox.error!,
                  style: const TextStyle(color: GetPrioTheme.destructive),
                ),
                GhostButton(
                  onPressed: busy ? null : inbox.refresh,
                  child: const Text('Retry'),
                ),
              ],
              if (inbox.loading && inbox.items.isEmpty)
                const Center(child: CircularProgressIndicator())
              else if (inbox.items.isEmpty && inbox.error == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(LucideIcons.bell, size: 36),
                      SizedBox(height: 12),
                      Text('No notifications yet'),
                    ],
                  ),
                ),
              for (final group in groupInboxNotifications(
                inbox.items,
                DateTime.now(),
              ).entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 20, 0, 12),
                  child: Text(
                    group.key,
                    key: ValueKey('notification-group-${group.key}'),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: GetPrioTheme.colors(context).mutedInk,
                    ),
                  ),
                ),
                for (final item in group.value) ...[
                  DecoratedBox(
                    key: ValueKey('notification-background-${item.id}'),
                    decoration: BoxDecoration(
                      color: item.unread
                          ? GetPrioTheme.primary.withValues(
                              alpha: GetPrioTheme.colors(context).dark
                                  ? 0.12
                                  : 0.06,
                            )
                          : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Button.ghost(
                      key: ValueKey('notification-${item.id}'),
                      onPressed: busy ? null : () => inbox.markRead(item),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              switch (item.kind) {
                                InboxNotificationKind.queue =>
                                  LucideIcons.ticket,
                                InboxNotificationKind.booking =>
                                  LucideIcons.calendarDays,
                                InboxNotificationKind.general =>
                                  LucideIcons.bell,
                              },
                              size: 20,
                              color: item.unread
                                  ? GetPrioTheme.primary
                                  : GetPrioTheme.colors(context).mutedInk,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: TextStyle(
                                      fontWeight: item.unread
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  if (item.body.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(item.body),
                                  ],
                                  const SizedBox(height: 6),
                                  Text(
                                    _time(item.createdAt),
                                    style: Theme.of(context).typography.small,
                                  ),
                                ],
                              ),
                            ),
                            if (item.unread)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: SizedBox(
                                  key: ValueKey(
                                    'notification-unread-${item.id}',
                                  ),
                                  width: 8,
                                  height: 8,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: GetPrioTheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Divider(),
                ],
              ],
              if (inbox.nextCursor != null)
                GhostButton(
                  onPressed: busy ? null : inbox.loadMore,
                  child: Text(inbox.loading ? 'Loading...' : 'Load more'),
                ),
            ],
          ),
        );
      },
    ),
  );
  String _time(DateTime date) {
    final local = date.toLocal();
    return '${local.day}/${local.month}/${local.year} · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
