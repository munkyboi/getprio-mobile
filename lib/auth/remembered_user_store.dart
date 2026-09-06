import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_models.dart';

/// Presentation data for the saved account, never proof of authentication.
abstract interface class RememberedUserStore {
  Future<AuthUser?> read();
  Future<void> write(AuthUser user);
  Future<void> clear();
}

class MemoryRememberedUserStore implements RememberedUserStore {
  AuthUser? user;
  @override
  Future<AuthUser?> read() async => user;
  @override
  Future<void> write(AuthUser value) async {
    user = value;
  }

  @override
  Future<void> clear() async {
    user = null;
  }
}

class SecureRememberedUserStore implements RememberedUserStore {
  SecureRememberedUserStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const _key = 'getprio.remembered_user';
  @override
  Future<AuthUser?> read() async {
    final value = await _storage.read(key: _key);
    if (value == null) return null;
    try {
      final user = AuthUser.fromJson(jsonDecode(value) as Map<String, dynamic>);
      return user.id.isEmpty || user.email.isEmpty ? null : user;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Future<void> write(AuthUser user) => _storage.write(
    key: _key,
    value: jsonEncode({
      'id': user.id,
      'email': user.email,
      'name': user.profileName,
      'displayName': user.displayName,
      'avatarUrl': user.avatarUrl,
    }),
  );
  @override
  Future<void> clear() => _storage.delete(key: _key);
}
