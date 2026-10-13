import 'package:flutter/foundation.dart';

class InboxNotification {
  const InboxNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
  });
  final String id, title, body;
  final DateTime createdAt;
  final DateTime? readAt;
  bool get unread => readAt == null;
}

class NotificationInboxSnapshot {
  const NotificationInboxSnapshot({
    required this.items,
    required this.unreadCount,
    required this.cutoff,
    this.nextCursor,
    this.totalCount,
  });
  final List<InboxNotification> items;
  final int unreadCount;
  final int? totalCount;
  final String cutoff;
  final String? nextCursor;
}

/// Account-local adapter or authenticated account inbox API, chosen explicitly.
abstract interface class NotificationInboxApi {
  Future<NotificationInboxSnapshot> load({String? cursor});
  Future<void> markRead(String id);
  Future<void> markAllRead(String cutoff);
  Future<void> clear(String cutoff);
}

class NotificationInboxController extends ChangeNotifier {
  NotificationInboxController(this.api);
  final NotificationInboxApi api;
  final unreadCount = ValueNotifier<int>(0);
  List<InboxNotification> items = const [];
  String? nextCursor, cutoff, error;
  int? totalCount;
  bool loading = false, mutating = false, _disposed = false;
  int _revision = 0;
  Future<void> refresh() async {
    final revision = ++_revision;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final snapshot = await api.load();
      if (_disposed || revision != _revision) return;
      items = snapshot.items;
      nextCursor = snapshot.nextCursor;
      cutoff = snapshot.cutoff;
      unreadCount.value = snapshot.unreadCount;
      totalCount =
          snapshot.totalCount ??
          (snapshot.nextCursor == null ? items.length : null);
    } catch (_) {
      if (!_disposed && revision == _revision) {
        error = 'Could not refresh notifications. Please try again.';
      }
    } finally {
      if (!_disposed && revision == _revision) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    final cursor = nextCursor;
    if (loading || mutating || cursor == null) return;
    final revision = _revision;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final snapshot = await api.load(cursor: cursor);
      if (_disposed || revision != _revision) return;
      final unique = {for (final item in items) item.id: item};
      for (final item in snapshot.items) {
        unique.putIfAbsent(item.id, () => item);
      }
      items = unique.values.toList();
      nextCursor = snapshot.nextCursor;
      unreadCount.value = snapshot.unreadCount;
      totalCount = snapshot.totalCount;
    } catch (_) {
      if (!_disposed && revision == _revision) {
        error = 'Could not load more notifications. Please try again.';
      }
    } finally {
      if (!_disposed && revision == _revision) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> markRead(InboxNotification item) =>
      item.unread ? _mutate(() => api.markRead(item.id)) : Future.value();
  Future<void> markAllRead() =>
      cutoff == null ? Future.value() : _mutate(() => api.markAllRead(cutoff!));
  Future<void> clear() =>
      cutoff == null ? Future.value() : _mutate(() => api.clear(cutoff!));
  Future<void> _mutate(Future<void> Function() operation) async {
    if (mutating || loading) return;
    mutating = true;
    error = null;
    notifyListeners();
    try {
      await operation();
      if (!_disposed) await refresh();
    } catch (_) {
      if (!_disposed) error = 'Could not update your inbox. Please try again.';
    } finally {
      if (!_disposed) {
        mutating = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    unreadCount.dispose();
    super.dispose();
  }
}
