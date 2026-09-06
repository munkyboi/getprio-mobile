import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

abstract interface class BiometricLogin {
  Future<bool> isEnabled();
  Future<bool> isAvailable();
  Future<bool> authenticate();
  Future<bool> enable();
  Future<void> disable();
}

/// Device-local opt-in for unlocking a saved GetPrio session.
class DeviceBiometricLogin implements BiometricLogin {
  DeviceBiometricLogin({
    LocalAuthentication? auth,
    FlutterSecureStorage? storage,
  }) : _auth = auth ?? LocalAuthentication(),
       _storage = storage ?? const FlutterSecureStorage();

  final LocalAuthentication _auth;
  final FlutterSecureStorage _storage;
  static const _key = 'getprio.biometric_login';

  @override
  Future<bool> isEnabled() async => await _storage.read(key: _key) == 'true';

  @override
  Future<bool> isAvailable() async {
    try {
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock your GetPrio session',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      // Cancellation, lockout and unavailable hardware fall back to sign-in.
      return false;
    }
  }

  @override
  Future<bool> enable() async {
    if (!await isAvailable() || !await authenticate()) return false;
    await _storage.write(key: _key, value: 'true');
    return true;
  }

  @override
  Future<void> disable() => _storage.delete(key: _key);
}
