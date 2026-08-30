import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/push/push_coordinator.dart';

void main() {
  test(
    'registers a device only after notification permission is granted',
    () async {
      final messaging = FakeMessaging(
        permission: PushPermission.authorized,
        token: 'fcm-1',
      );
      final api = FakePushRegistrationApi();
      final coordinator = PushCoordinator(
        messaging: messaging,
        api: api,
        installationStore: MemoryInstallationStore('installation-1'),
        platform: 'ios',
        appVersion: '1.0.0',
        locale: 'en-PH',
      );

      final registered = await coordinator.initialize();

      expect(registered, isTrue);
      expect(api.registration?.installationId, 'installation-1');
      expect(api.registration?.token, 'fcm-1');
    },
  );

  test(
    'permission denial does not block initialization or register a token',
    () async {
      final messaging = FakeMessaging(
        permission: PushPermission.denied,
        token: 'fcm-1',
      );
      final api = FakePushRegistrationApi();
      final coordinator = PushCoordinator(
        messaging: messaging,
        api: api,
        installationStore: MemoryInstallationStore('installation-1'),
        platform: 'ios',
        appVersion: '1.0.0',
        locale: 'en-PH',
      );

      expect(await coordinator.initialize(), isFalse);
      expect(api.registration, isNull);
    },
  );

  test(
    'token refresh replaces the registration for the same installation',
    () async {
      final messaging = FakeMessaging(
        permission: PushPermission.authorized,
        token: 'fcm-1',
      );
      final api = FakePushRegistrationApi();
      final coordinator = PushCoordinator(
        messaging: messaging,
        api: api,
        installationStore: MemoryInstallationStore('installation-1'),
        platform: 'ios',
        appVersion: '1.0.0',
        locale: 'en-PH',
      );

      await coordinator.initialize();
      messaging.emitToken('fcm-2');
      await Future<void>.delayed(Duration.zero);
      await coordinator.flush();

      expect(api.registration?.token, 'fcm-2');
      expect(api.registration?.installationId, 'installation-1');
    },
  );

  test('safe push signal is passed to the REST refresh callback', () async {
    final messaging = FakeMessaging(
      permission: PushPermission.authorized,
      token: 'fcm-1',
    );
    final api = FakePushRegistrationApi();
    PushSignal? signal;
    final coordinator = PushCoordinator(
      messaging: messaging,
      api: api,
      installationStore: MemoryInstallationStore('installation-1'),
      platform: 'ios',
      appVersion: '1.0.0',
      locale: 'en-PH',
      onSignal: (value) async => signal = value,
    );

    await coordinator.initialize();
    messaging.emitSignal({
      'eventType': 'customer_queue_called',
      'notificationId': 'event-1',
      'ticketRef': 'ABC123',
      'route': 'ticket',
      'status': 'called',
    });
    await Future<void>.delayed(Duration.zero);
    await coordinator.flush();

    expect(signal?.eventType, 'customer_queue_called');
    expect(signal?.ticketRef, 'ABC123');
  });

  test(
    'logout deactivates the current installation even if local cleanup follows',
    () async {
      final messaging = FakeMessaging(
        permission: PushPermission.authorized,
        token: 'fcm-1',
      );
      final api = FakePushRegistrationApi();
      final coordinator = PushCoordinator(
        messaging: messaging,
        api: api,
        installationStore: MemoryInstallationStore('installation-1'),
        platform: 'ios',
        appVersion: '1.0.0',
        locale: 'en-PH',
      );

      await coordinator.initialize();
      await coordinator.logout();

      expect(api.deactivatedInstallationId, 'installation-1');
    },
  );
}

class FakeMessaging implements PushMessagingPort {
  FakeMessaging({required this.permission, required this.token});

  final PushPermission permission;
  String? token;
  final _tokens = StreamController<String>.broadcast();
  final _signals = StreamController<PushSignal>.broadcast();

  @override
  Future<PushPermission> requestPermission() async => permission;

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<String> get onTokenRefresh => _tokens.stream;

  @override
  Stream<PushSignal> get onSignal => _signals.stream;

  void emitToken(String value) {
    token = value;
    _tokens.add(value);
  }

  void emitSignal(Map<String, dynamic> data) {
    _signals.add(PushSignal.fromData(data));
  }
}

class FakePushRegistrationApi implements PushRegistrationApi {
  PushRegistration? registration;
  String? deactivatedInstallationId;

  @override
  Future<void> register(PushRegistration value) async => registration = value;

  @override
  Future<void> deactivate(String installationId) async =>
      deactivatedInstallationId = installationId;
}
