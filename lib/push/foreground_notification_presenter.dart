import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

abstract interface class ForegroundNotificationPresenter {
  Future<bool> initialize();

  Future<void> show({
    required String notificationId,
    String? ticketRef,
    String? payload,
    String? title,
    String? body,
  });
}

abstract interface class ForegroundNotificationTapSource {
  Future<String?> get initialPayload;
}

class NativeForegroundNotificationPresenter
    implements
        ForegroundNotificationPresenter,
        ForegroundNotificationTapSource {
  NativeForegroundNotificationPresenter({
    FlutterLocalNotificationsPlugin? plugin,
    this.onTap,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'getprio_queue_updates';
  static const _channelName = 'GetPrio updates';
  static const _channelDescription =
      'Notifications about bookings and queue tickets.';

  final FlutterLocalNotificationsPlugin _plugin;
  final ValueChanged<String?>? onTap;
  @override
  Future<String?> get initialPayload async {
    if (!_initialized || _launchPayloadConsumed) return null;
    _launchPayloadConsumed = true;
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true
        ? details?.notificationResponse?.payload
        : null;
  }

  bool _initialized = false, _launchPayloadConsumed = false;

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
      onDidReceiveNotificationResponse: (response) =>
          onTap?.call(response.payload),
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
    String? payload,
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
        payload: payload ?? ticketRef,
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
      payload: payload ?? ticketRef,
    );
  }

  int _notificationId(String notificationId) {
    final id = notificationId.hashCode & 0x7fffffff;
    return id == 0 ? 1 : id;
  }
}
