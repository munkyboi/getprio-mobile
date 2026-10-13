import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
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
