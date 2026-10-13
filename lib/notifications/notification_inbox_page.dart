import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../navigation/scroll_aware_app_bar.dart';
import '../app_theme.dart';
import 'notification_inbox.dart';

class NotificationInboxPage extends StatefulWidget {
  const NotificationInboxPage({super.key, required this.controller});
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
              for (final item in inbox.items) ...[
                Button.ghost(
                  key: ValueKey('notification-${item.id}'),
                  onPressed: busy ? null : () => inbox.markRead(item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          item.unread ? LucideIcons.bellDot : LucideIcons.bell,
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
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(LucideIcons.circle, size: 8),
                          ),
                      ],
                    ),
                  ),
                ),
                const Divider(),
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
