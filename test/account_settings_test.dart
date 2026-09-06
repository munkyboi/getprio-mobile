import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/account/account_settings_repository.dart';

void main() {
  test('loads the shared queue-alert preference', () async {
    final repository = AccountSettingsRepository(FakeAccountSettingsApi());

    final settings = await repository.loadNotificationSettings();

    expect(settings.queueAlerts, isFalse);
  });

  test('updates the shared queue-alert preference', () async {
    final api = FakeAccountSettingsApi();
    final repository = AccountSettingsRepository(api);

    final settings = await repository.updateNotificationSettings(
      queueAlerts: false,
    );

    expect(settings.queueAlerts, isFalse);
    expect(api.lastQueueAlerts, isFalse);
  });
}

class FakeAccountSettingsApi implements AccountSettingsApi {
  bool? lastQueueAlerts;

  @override
  Future<Map<String, dynamic>> loadNotificationSettings() async => {
    'notificationSettings': {'queueAlerts': false},
  };

  @override
  Future<Map<String, dynamic>> updateNotificationSettings({
    required bool queueAlerts,
  }) async {
    lastQueueAlerts = queueAlerts;
    return {
      'notificationSettings': {'queueAlerts': queueAlerts},
    };
  }
}
