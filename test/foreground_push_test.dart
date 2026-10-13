import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:getprio_mobile/push/foreground_notification_presenter.dart';
import 'package:getprio_mobile/push/push_coordinator.dart';

class Presenter implements ForegroundNotificationPresenter {
  int shown = 0;
  String? lastPayload;
  @override
  Future<bool> initialize() async => true;
  @override
  Future<void> show({
    required String notificationId,
    String? ticketRef,
    String? payload,
    String? title,
    String? body,
  }) async {
    shown++;
    lastPayload = payload;
  }
}

void main() {
  for (final failFirstQuery in [false, true]) {
    testWidgets(
      'native launch payload delivered once with initial failure=$failFirstQuery',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        const channel = MethodChannel(
          'dexterous.com/flutter/local_notifications',
        );
        var queries = 0;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'getNotificationAppLaunchDetails') {
              queries++;
              if (failFirstQuery && queries == 1) {
                throw PlatformException(code: 'temporary');
              }
              return {
                'notificationLaunchedApp': true,
                'notificationResponse': {
                  'notificationId': 1,
                  'notificationResponseType': 0,
                  'payload': 'payload',
                },
              };
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        AndroidFlutterLocalNotificationsPlugin.registerWith();
        final presenter = NativeForegroundNotificationPresenter();
        expect(await presenter.initialize(), isTrue);
        if (failFirstQuery) {
          await expectLater(
            presenter.initialPayload,
            throwsA(isA<PlatformException>()),
          );
        }
        expect(await presenter.initialPayload, 'payload');
        await presenter.initialize();
        expect(await presenter.initialPayload, isNull);
        expect(queries, failFirstQuery ? 2 : 1);
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }
  test(
    'foreground reminder banner preserves booking link for explicit local tap',
    () async {
      final presenter = Presenter();
      const message = RemoteMessage(
        data: {
          'eventType': 'customer_booking_reminder_24h',
          'notificationId': 'reminder-24h',
          'route': '/account/bookings/123',
        },
      );
      await presentForegroundPush(message, presenter);
      expect(presenter.shown, 1);
      expect(bookingIdForPush(PushSignal.fromData(message.data)), isNull);
      final opened = openedPushPayload(presenter.lastPayload);
      expect(opened?.notificationId, 'reminder-24h');
      expect(bookingIdForPush(opened!), '123');
    },
  );

  test('silent data refresh does not display fallback notification', () async {
    final presenter = Presenter();
    for (final silent in [true, 'true']) {
      final message = RemoteMessage(
        data: {
          'eventType': 'queue.updated',
          'notificationId': 'signal-1',
          'silent': silent,
        },
      );
      await presentForegroundPush(message, presenter);
      expect(PushSignal.fromData(message.data).eventType, 'queue.updated');
    }
    expect(presenter.shown, 0);
    await presentForegroundPush(
      const RemoteMessage(
        data: {'eventType': 'queue.called', 'notificationId': 'visible-1'},
      ),
      presenter,
    );
    expect(presenter.shown, 1);
  });
}
