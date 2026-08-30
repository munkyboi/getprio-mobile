import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../queue/auth_queue_api.dart';

enum PushPermission { authorized, provisional, denied }

class PushSignal {
  const PushSignal({
    required this.eventType,
    required this.notificationId,
    this.ticketRef,
    this.route,
  });

  final String eventType;
  final String notificationId;
  final String? ticketRef;
  final String? route;

  factory PushSignal.fromData(Map<String, dynamic> data) {
    final eventType = data['eventType'];
    final notificationId = data['notificationId'];
    if (eventType is! String ||
        eventType.isEmpty ||
        notificationId is! String ||
        notificationId.isEmpty) {
      throw const FormatException(
        'Push signal is missing its safe identifiers.',
      );
    }
    return PushSignal(
      eventType: eventType,
      notificationId: notificationId,
      ticketRef: data['ticketRef'] as String?,
      route: data['route'] as String?,
    );
  }
}

abstract interface class PushMessagingPort {
  Future<PushPermission> requestPermission();

  Future<String?> getToken();

  Stream<String> get onTokenRefresh;

  Stream<PushSignal> get onSignal;
}

abstract interface class PushRegistrationApi {
  Future<void> register(PushRegistration registration);

  Future<void> deactivate(String installationId);
}

class PushRegistration {
  const PushRegistration({
    required this.installationId,
    required this.token,
    required this.platform,
    required this.appVersion,
    required this.locale,
  });

  final String installationId;
  final String token;
  final String platform;
  final String appVersion;
  final String locale;
}

abstract interface class InstallationStore {
  Future<String> getOrCreate();
}

class SecureInstallationStore implements InstallationStore {
  SecureInstallationStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'getprio.installation_id';
  final FlutterSecureStorage _storage;

  @override
  Future<String> getOrCreate() async {
    final existing = await _storage.read(key: _key);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = _newInstallationId();
    await _storage.write(key: _key, value: created);
    return created;
  }
}

class MemoryInstallationStore implements InstallationStore {
  MemoryInstallationStore(this.id);

  final String id;

  @override
  Future<String> getOrCreate() async => id;
}

class PushCoordinator {
  PushCoordinator({
    required this.messaging,
    required this.api,
    required this.installationStore,
    required this.platform,
    required this.appVersion,
    required this.locale,
    this.onSignal,
  });

  final PushMessagingPort messaging;
  final PushRegistrationApi api;
  final InstallationStore installationStore;
  final String platform;
  final String appVersion;
  final String locale;
  final Future<void> Function(PushSignal signal)? onSignal;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<PushSignal>? _signalSubscription;
  Future<void> _pending = Future.value();
  String? _installationId;

  Future<bool> initialize() async {
    final permission = await messaging.requestPermission();
    if (permission != PushPermission.authorized &&
        permission != PushPermission.provisional) {
      return false;
    }
    _installationId = await installationStore.getOrCreate();
    _tokenSubscription ??= messaging.onTokenRefresh.listen(_registerToken);
    _signalSubscription ??= messaging.onSignal.listen(_handleSignal);
    final token = await messaging.getToken();
    if (token != null && token.isNotEmpty) await _registerToken(token);
    return true;
  }

  Future<void> logout() async {
    final installationId = _installationId;
    if (installationId != null) {
      try {
        await api.deactivate(installationId);
      } finally {
        _installationId = null;
      }
    }
  }

  Future<void> flush() => _pending;

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _signalSubscription?.cancel();
  }

  Future<void> _registerToken(String token) {
    return _enqueue(() async {
      final installationId = _installationId ??= await installationStore
          .getOrCreate();
      await api.register(
        PushRegistration(
          installationId: installationId,
          token: token,
          platform: platform,
          appVersion: appVersion,
          locale: locale,
        ),
      );
    });
  }

  Future<void> _handleSignal(PushSignal signal) {
    final callback = onSignal;
    return callback == null ? Future.value() : _enqueue(() => callback(signal));
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    _pending = _pending.then((_) => operation());
    return _pending;
  }
}

class RestPushRegistrationApi implements PushRegistrationApi {
  RestPushRegistrationApi(this.client);

  final AuthenticatedApiClient client;

  @override
  Future<void> register(PushRegistration registration) async {
    await client.put(
      '/api/mobile/push/registrations/${registration.installationId}',
      {
        'token': registration.token,
        'platform': registration.platform,
        'appVersion': registration.appVersion,
        'locale': registration.locale,
      },
    );
  }

  @override
  Future<void> deactivate(String installationId) async {
    await client.delete('/api/mobile/push/registrations/$installationId');
  }
}

class FirebaseMessagingPort implements PushMessagingPort {
  FirebaseMessagingPort({FirebaseMessaging? messaging})
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  @override
  Future<PushPermission> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: true,
    );
    return switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized => PushPermission.authorized,
      AuthorizationStatus.provisional => PushPermission.provisional,
      _ => PushPermission.denied,
    };
  }

  @override
  Future<String?> getToken() => _messaging.getToken();

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<PushSignal> get onSignal => FirebaseMessaging.onMessage.map(
    (message) => PushSignal.fromData(message.data),
  );
}

Future<bool> initializeFirebase() async {
  try {
    await Firebase.initializeApp();
    return true;
  } on FirebaseException catch (error) {
    // Missing platform Firebase configuration is a setup state, not a reason
    // for queue reads or joins to fail.
    return error.code == 'duplicate-app';
  }
}

String _newInstallationId() {
  final now = DateTime.now().microsecondsSinceEpoch;
  return 'install-${now.toRadixString(36)}';
}
