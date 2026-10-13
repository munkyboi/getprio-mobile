import '../queue/auth_queue_api.dart';
import 'notification_inbox.dart';

/// Opaque account-scoped cursors/cutoffs are never interpreted on the device.
class RestNotificationInboxApi implements NotificationInboxApi {
  RestNotificationInboxApi(this.client);
  final AuthenticatedApiClient client;
  static const _base = '/api/account/notifications';
  @override
  Future<NotificationInboxSnapshot> load({String? cursor}) async {
    final data = await client.get(
      cursor == null
          ? _base
          : '$_base?cursor=${Uri.encodeQueryComponent(cursor)}',
    );
    final raw = data['notifications'];
    final count = data['unreadCount'];
    final total = data['totalCount'];
    final cutoff = data['snapshotCutoff'];
    final next = data['nextCursor'];
    if (raw is! List ||
        count is! int ||
        count < 0 ||
        (total != null && (total is! int || total < count)) ||
        cutoff is! String ||
        cutoff.isEmpty ||
        (next != null && next is! String)) {
      throw const FormatException('Invalid notification inbox response');
    }
    final items = raw
        .map((row) {
          if (row is! Map ||
              row['id'] is! String ||
              (row['id'] as String).isEmpty ||
              row['title'] is! String ||
              row['body'] is! String) {
            throw const FormatException('Invalid notification');
          }
          final created = DateTime.tryParse('${row['createdAt']}');
          final read = row['readAt'] == null
              ? null
              : DateTime.tryParse('${row['readAt']}');
          if (created == null || (row['readAt'] != null && read == null)) {
            throw const FormatException('Invalid notification date');
          }
          return InboxNotification(
            id: row['id'],
            title: row['title'],
            body: row['body'],
            createdAt: created,
            readAt: read,
          );
        })
        .toList(growable: false);
    return NotificationInboxSnapshot(
      items: items,
      unreadCount: count,
      totalCount: total as int?,
      cutoff: cutoff,
      nextCursor: next == '' ? null : next as String?,
    );
  }

  @override
  Future<void> markRead(String id) async {
    await client.post('$_base/${Uri.encodeComponent(id)}/read', {});
  }

  @override
  Future<void> markAllRead(String cutoff) async {
    await client.post('$_base/read-all', {'before': cutoff});
  }

  @override
  Future<void> clear(String cutoff) async {
    await client.post('$_base/clear', {'before': cutoff});
  }
}
