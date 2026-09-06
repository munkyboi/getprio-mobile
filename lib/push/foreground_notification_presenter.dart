import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

abstract interface class ForegroundNotificationPresenter {
  Future<bool> initialize();

  Future<void> show({
    required String notificationId,
    String? ticketRef,
    String? title,
    String? body,
  });
}

class NativeForegroundNotificationPresenter
    implements ForegroundNotificationPresenter {
  NativeForegroundNotificationPresenter({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'getprio_queue_updates';
  static const _channelName = 'Queue updates';
  static const _channelDescription =
      'Notifications about queue tickets and their status.';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  @override
  Future<bool> initialize() async {
    if (_initialized) return true;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _plugin.initialize(
        settings: const InitializationSettings(
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
            requestProvisionalPermission: false,
            defaultPresentAlert: true,
            defaultPresentBadge: true,
            defaultPresentSound: true,
            defaultPresentBanner: true,
            defaultPresentList: true,
          ),
        ),
      );
      // On iOS the plugin returns false when initialization intentionally does
      // not request permissions. Firebase owns the permission prompt here.
      _initialized = true;
      return true;
    }
    if (defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return false;

    final initialized = await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    if (initialized != true) return false;
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
    _initialized = true;
    return true;
  }

  @override
  Future<void> show({
    required String notificationId,
    String? ticketRef,
    String? title,
    String? body,
  }) async {
    if (!_initialized) {
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _plugin.show(
        id: _notificationId(notificationId),
        title: title ?? 'GetPrio queue update',
        body: body ?? 'Your ticket status has been updated.',
        notificationDetails: const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            presentBanner: true,
            presentList: true,
          ),
        ),
        payload: ticketRef,
      );
      return;
    }

    if (defaultTargetPlatform != TargetPlatform.android) return;

    await _plugin.show(
      id: _notificationId(notificationId),
      title: title ?? 'GetPrio queue update',
      body: body ?? 'Your ticket status has been updated.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: ticketRef,
    );
  }

  int _notificationId(String notificationId) {
    final id = notificationId.hashCode & 0x7fffffff;
    return id == 0 ? 1 : id;
  }
}
