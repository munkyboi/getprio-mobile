import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/account/account_settings_repository.dart';

void main() {
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
    'queueAlerts': true,
  };

  @override
  Future<Map<String, dynamic>> updateNotificationSettings({
    required bool queueAlerts,
  }) async {
    lastQueueAlerts = queueAlerts;
    return {'queueAlerts': queueAlerts};
  }
}
