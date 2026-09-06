import '../auth/auth_models.dart';
import '../queue/auth_queue_api.dart';

class ProfileChangeChallenge {
  const ProfileChangeChallenge({
    required this.challengeId,
    required this.step,
    required this.deliveryTarget,
    required this.expiresAt,
  });

  final String challengeId;
  final String step;
  final String deliveryTarget;
  final DateTime? expiresAt;

  factory ProfileChangeChallenge.fromJson(Map<String, dynamic> json) {
    final challengeId = json['challengeId'];
    final step = json['step'];
    if (challengeId is! String || challengeId.isEmpty || step is! String) {
      throw const FormatException('Profile change response is incomplete.');
    }

    final expiresAt = json['expiresAt'];
    return ProfileChangeChallenge(
      challengeId: challengeId,
      step: step,
      deliveryTarget: json['deliveryTarget'] as String? ?? 'your email address',
      expiresAt: expiresAt is String ? DateTime.tryParse(expiresAt) : null,
    );
  }
}

abstract interface class AccountProfileApi {
  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String displayName,
  });

  Future<Map<String, dynamic>> uploadAvatar({
    required String fileName,
    required String contentType,
    required List<int> bytes,
  });

  Future<Map<String, dynamic>> startEmailChange({required String newEmail});

  Future<Map<String, dynamic>> verifyCurrentEmail({
    required String challengeId,
    required String code,
  });

  Future<Map<String, dynamic>> verifyNewEmail({
    required String challengeId,
    required String code,
  });

  Future<Map<String, dynamic>> startPhoneChange({required String newPhone});

  Future<Map<String, dynamic>> verifyPhoneChange({
    required String challengeId,
    required String code,
    required String password,
  });
}

class AccountProfileRepository {
  AccountProfileRepository(this.api);

  final AccountProfileApi api;

  Future<AuthUser> updateProfile({
    required String name,
    required String displayName,
  }) async {
    return _parseUser(
      await api.updateProfile(name: name, displayName: displayName),
    );
  }

  Future<AuthUser> uploadAvatar({
    required String fileName,
    required String contentType,
    required List<int> bytes,
  }) async {
    return _parseUser(
      await api.uploadAvatar(
        fileName: fileName,
        contentType: contentType,
        bytes: bytes,
      ),
    );
  }

  Future<ProfileChangeChallenge> startEmailChange({
    required String newEmail,
  }) async {
    return ProfileChangeChallenge.fromJson(
      await api.startEmailChange(newEmail: newEmail),
    );
  }

  Future<ProfileChangeChallenge> verifyCurrentEmail({
    required String challengeId,
    required String code,
  }) async {
    return ProfileChangeChallenge.fromJson(
      await api.verifyCurrentEmail(challengeId: challengeId, code: code),
    );
  }

  Future<AuthUser> verifyNewEmail({
    required String challengeId,
    required String code,
  }) async {
    return _parseUser(
      await api.verifyNewEmail(challengeId: challengeId, code: code),
    );
  }

  Future<ProfileChangeChallenge> startPhoneChange({
    required String newPhone,
  }) async {
    return ProfileChangeChallenge.fromJson(
      await api.startPhoneChange(newPhone: newPhone),
    );
  }

  Future<AuthUser> verifyPhoneChange({
    required String challengeId,
    required String code,
    required String password,
  }) async {
    return _parseUser(
      await api.verifyPhoneChange(
        challengeId: challengeId,
        code: code,
        password: password,
      ),
    );
  }

  AuthUser _parseUser(Map<String, dynamic> response) {
    final user = response['user'];
    if (user is! Map<String, dynamic>) {
      throw const FormatException('Profile response has no user.');
    }
    return AuthUser.fromJson(user);
  }
}

class RestAccountProfileApi implements AccountProfileApi {
  RestAccountProfileApi(this.client);

  final AuthenticatedApiClient client;

  @override
  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String displayName,
  }) {
    return client.patch('/api/account/profile', {
      'name': name,
      'displayName': displayName,
    });
  }

  @override
  Future<Map<String, dynamic>> uploadAvatar({
    required String fileName,
    required String contentType,
    required List<int> bytes,
  }) {
    return client.uploadBytes(
      '/api/account/profile/avatar',
      bytes: bytes,
      contentType: contentType,
      queryParameters: {'fileName': fileName},
    );
  }

  @override
  Future<Map<String, dynamic>> startEmailChange({required String newEmail}) {
    return client.post('/api/account/email-change/start', {
      'newEmail': newEmail,
      'method': 'current_email',
    });
  }

  @override
  Future<Map<String, dynamic>> verifyCurrentEmail({
    required String challengeId,
    required String code,
  }) {
    return client.post('/api/account/email-change/verify-current', {
      'challengeId': challengeId,
      'code': code,
    });
  }

  @override
  Future<Map<String, dynamic>> verifyNewEmail({
    required String challengeId,
    required String code,
  }) {
    return client.post('/api/account/email-change/verify-new', {
      'challengeId': challengeId,
      'code': code,
    });
  }

  @override
  Future<Map<String, dynamic>> startPhoneChange({required String newPhone}) {
    return client.post('/api/account/phone-change/start', {
      'newPhone': newPhone,
      'method': 'email',
    });
  }

  @override
  Future<Map<String, dynamic>> verifyPhoneChange({
    required String challengeId,
    required String code,
    required String password,
  }) {
    return client.post('/api/account/phone-change/verify-email', {
      'challengeId': challengeId,
      'code': code,
      'password': password,
    });
  }
}
