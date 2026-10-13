import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/push/foreground_notification_presenter.dart';
import 'package:getprio_mobile/push/push_coordinator.dart';

class Presenter implements ForegroundNotificationPresenter {
  int shown = 0;
  @override
  Future<bool> initialize() async => true;
  @override
  Future<void> show({
    required String notificationId,
    String? ticketRef,
    String? title,
    String? body,
  }) async {
    shown++;
  }
}

void main() {
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
