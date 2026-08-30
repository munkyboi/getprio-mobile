import '../queue/auth_queue_api.dart';

class NotificationSettings {
  const NotificationSettings({required this.queueAlerts});

  final bool queueAlerts;

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      queueAlerts: json['queueAlerts'] as bool? ?? true,
    );
  }
}

abstract interface class AccountSettingsApi {
  Future<Map<String, dynamic>> loadNotificationSettings();

  Future<Map<String, dynamic>> updateNotificationSettings({
    required bool queueAlerts,
  });
}

class AccountSettingsRepository {
  AccountSettingsRepository(this.api);

  final AccountSettingsApi api;

  Future<NotificationSettings> loadNotificationSettings() async {
    return NotificationSettings.fromJson(await api.loadNotificationSettings());
  }

  Future<NotificationSettings> updateNotificationSettings({
    required bool queueAlerts,
  }) async {
    return NotificationSettings.fromJson(
      await api.updateNotificationSettings(queueAlerts: queueAlerts),
    );
  }
}

class RestAccountSettingsApi implements AccountSettingsApi {
  RestAccountSettingsApi(this.client);

  final AuthenticatedApiClient client;

  @override
  Future<Map<String, dynamic>> loadNotificationSettings() {
    return client.get('/api/account/notification-settings');
  }

  @override
  Future<Map<String, dynamic>> updateNotificationSettings({
    required bool queueAlerts,
  }) {
    return client.patch('/api/account/notification-settings', {
      'queueAlerts': queueAlerts,
    });
  }
}
