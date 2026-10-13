import 'notification_inbox.dart';

/// Mutually exclusive calendar groups in the device's local timezone.
Map<String, List<InboxNotification>> groupInboxNotifications(
  List<InboxNotification> items,
  DateTime now,
) {
  final local = now.toLocal();
  final today = DateTime(local.year, local.month, local.day);
  final yesterday = DateTime(local.year, local.month, local.day - 1);
  final week = DateTime(local.year, local.month, local.day - local.weekday + 1);
  final lastWeek = DateTime(week.year, week.month, week.day - 7);
  final groups = <String, List<InboxNotification>>{
    'Today': [],
    'Yesterday': [],
    'This week': [],
    'Last week': [],
    'Earlier': [],
  };
  final sorted = List<InboxNotification>.of(items)
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  for (final item in sorted) {
    final date = item.createdAt.toLocal();
    final day = DateTime(date.year, date.month, date.day);
    final label = day == today
        ? 'Today'
        : day == yesterday
        ? 'Yesterday'
        : !day.isBefore(week)
        ? 'This week'
        : !day.isBefore(lastWeek)
        ? 'Last week'
        : 'Earlier';
    groups[label]!.add(item);
  }
  groups.removeWhere((_, rows) => rows.isEmpty);
  return groups;
}
