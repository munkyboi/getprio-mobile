import 'dart:async';

import 'package:async/async.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../auth/auth_repository.dart';
import '../mobile_environment.dart';
import '../queue/auth_queue_api.dart';
import 'foreground_notification_presenter.dart';
import 'firebase_options.dart';

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

  Future<PushSignal?> get initialSignal;
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
  final StreamController<Object> _registrationErrorController =
      StreamController<Object>.broadcast();
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<PushSignal>? _signalSubscription;
  Future<void> _pending = Future.value();
  Timer? _registrationRetryTimer;
  String? _installationId;
  String? _lastToken;
  int _sessionGeneration = 0;

  Stream<Object> get registrationErrors => _registrationErrorController.stream;

  Future<bool> initialize() async {
    final sessionGeneration = ++_sessionGeneration;
    final permission = await messaging.requestPermission();
    if (permission != PushPermission.authorized &&
        permission != PushPermission.provisional) {
      return false;
    }
    _installationId = await installationStore.getOrCreate();
    _tokenSubscription ??= messaging.onTokenRefresh.listen(
      (token) => _registerToken(token, _sessionGeneration),
    );
    _signalSubscription ??= messaging.onSignal.listen(
      (signal) => _handleSignal(signal, _sessionGeneration),
    );
    final initialSignal = await messaging.initialSignal;
    if (initialSignal != null) {
      await _handleSignal(initialSignal, sessionGeneration);
    }
    final token = await messaging.getToken();
    if (token != null && token.isNotEmpty) {
      _lastToken = token;
      await _registerToken(token, sessionGeneration);
    }
    return true;
  }

  Future<void> logout() async {
    final installationId = _installationId;
    _sessionGeneration++;
    _installationId = null;
    _lastToken = null;
    _registrationRetryTimer?.cancel();
    _registrationRetryTimer = null;
    final tokenSubscription = _tokenSubscription;
    final signalSubscription = _signalSubscription;
    _tokenSubscription = null;
    _signalSubscription = null;
    await tokenSubscription?.cancel();
    await signalSubscription?.cancel();
    if (installationId != null) {
      try {
        await api
            .deactivate(installationId)
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // Push cleanup is best effort and must not block local sign-out.
      }
    }
  }

  Future<void> flush() => _pending;

  Future<void> dispose() async {
    _registrationRetryTimer?.cancel();
    _registrationRetryTimer = null;
    await _tokenSubscription?.cancel();
    await _signalSubscription?.cancel();
    await _registrationErrorController.close();
  }

  Future<void> retryRegistration() async {
    final token = _lastToken;
    if (token == null || _installationId == null) return;
    await _registerToken(token, _sessionGeneration);
  }

  Future<void> _registerToken(String token, int sessionGeneration) async {
    _lastToken = token;
    try {
      await _enqueue(() async {
        final installationId = _installationId;
        if (installationId == null || sessionGeneration != _sessionGeneration) {
          return;
        }
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
      if (sessionGeneration == _sessionGeneration) {
        _registrationRetryTimer?.cancel();
        _registrationRetryTimer = null;
      }
    } catch (error) {
      if (sessionGeneration == _sessionGeneration) {
        if (error is ApiException && error.code == 'SANDBOX_DEVICE_LIMIT') {
          _registrationRetryTimer?.cancel();
          _registrationRetryTimer = null;
          _registrationErrorController.add(error);
          return;
        }
        _scheduleRegistrationRetry(token, sessionGeneration);
        debugPrint('[push] token registration failed: $error');
      }
    }
  }

  Future<void> _handleSignal(PushSignal signal, int sessionGeneration) {
    return _enqueue(() async {
      if (sessionGeneration != _sessionGeneration) return;
      final callback = onSignal;
      if (callback != null) await callback(signal);
    });
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _pending.then((_) => operation());
    _pending = next.catchError((_) {});
    return next;
  }

  void _scheduleRegistrationRetry(String token, int sessionGeneration) {
    _registrationRetryTimer?.cancel();
    _registrationRetryTimer = Timer(const Duration(seconds: 30), () {
      if (sessionGeneration != _sessionGeneration || _installationId == null) {
        return;
      }
      unawaited(_registerToken(token, sessionGeneration));
    });
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
  FirebaseMessagingPort({
    FirebaseMessaging? messaging,
    ForegroundNotificationPresenter? foregroundPresenter,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _foregroundPresenter =
           foregroundPresenter ?? NativeForegroundNotificationPresenter();

  final FirebaseMessaging _messaging;
  final ForegroundNotificationPresenter _foregroundPresenter;

  @override
  Future<PushPermission> requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _foregroundPresenter.initialize();
      } catch (_) {
        // A banner failure must not prevent token registration or ticket refresh.
      }
    }
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    return switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized => PushPermission.authorized,
      AuthorizationStatus.provisional => PushPermission.provisional,
      _ => PushPermission.denied,
    };
  }

  @override
  Future<String?> getToken() async {
    await _waitForApnsToken();
    return _messaging.getToken();
  }

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<PushSignal> get onSignal => StreamGroup.merge<RemoteMessage>([
    FirebaseMessaging.onMessage.asyncMap(_presentForegroundMessage),
    FirebaseMessaging.onMessageOpenedApp,
  ]).expand(_parseSignal);

  @override
  Future<PushSignal?> get initialSignal async {
    final message = await _messaging.getInitialMessage();
    if (message == null) return null;
    return _tryParseSignal(message.data);
  }

  Future<RemoteMessage> _presentForegroundMessage(RemoteMessage message) async {
    final signal = _tryParseSignal(message.data);
    if (signal != null) {
      try {
        await _foregroundPresenter.show(
          notificationId: signal.notificationId,
          ticketRef: signal.ticketRef,
          title: message.notification?.title,
          body: message.notification?.body,
        );
      } catch (_) {
        // A banner failure must not prevent the ticket refresh signal.
      }
    }
    return message;
  }

  Future<void> _waitForApnsToken() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;

    for (var attempt = 0; attempt < 20; attempt++) {
      final token = await _messaging.getAPNSToken();
      if (token != null && token.isNotEmpty) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }
}

Iterable<PushSignal> _parseSignal(RemoteMessage message) {
  final signal = _tryParseSignal(message.data);
  return signal == null ? const [] : [signal];
}

PushSignal? _tryParseSignal(Map<String, dynamic> data) {
  try {
    return PushSignal.fromData(data);
  } on FormatException {
    return null;
  }
}

Future<bool> initializeFirebase({
  GetPrioEnvironment environment = GetPrioEnvironment.production,
}) async {
  try {
    await Firebase.initializeApp(
      options: environment == GetPrioEnvironment.sandbox
          ? (defaultTargetPlatform == TargetPlatform.android
                ? sandboxFirebaseOptionsAndroid
                : sandboxFirebaseOptionsIos)
          : null,
    );
    return true;
  } on FirebaseException catch (error) {
    // Missing platform Firebase configuration is a setup state, not a reason
    // for queue reads or joins to fail.
    return error.code == 'duplicate-app';
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

String _newInstallationId() {
  final now = DateTime.now().microsecondsSinceEpoch;
  return 'install-${now.toRadixString(36)}';
}
