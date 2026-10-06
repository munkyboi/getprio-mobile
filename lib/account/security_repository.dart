import '../queue/auth_queue_api.dart';

class MfaEnrollment {
  const MfaEnrollment({required this.secret, required this.otpauthUri});

  final String secret;
  final Uri otpauthUri;

  factory MfaEnrollment.fromJson(Map<String, dynamic> json) {
    final secret = json['secret'];
    final uri = json['otpAuthUri'] ?? json['otpauthUri'] ?? json['otpauthUrl'];
    if (secret is! String || uri is! String) {
      throw const FormatException('MFA enrollment response is incomplete.');
    }
    final parsedUri = Uri.tryParse(uri);
    if (parsedUri == null || parsedUri.scheme != 'otpauth') {
      throw const FormatException('MFA enrollment URI is invalid.');
    }
    return MfaEnrollment(secret: secret, otpauthUri: parsedUri);
  }
}

abstract interface class SecurityApi {
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<Map<String, dynamic>> startMfaEnrollment({String? currentCode});

  Future<Map<String, dynamic>> confirmMfaEnrollment(String code);

  Future<void> cancelMfaEnrollment();

  Future<void> disableMfa({
    required String password,
    String? code,
    String? recoveryCode,
  });
}

class AccountDeletionReceipt {
  const AccountDeletionReceipt({required this.requestId, required this.dueAt});
  final String requestId;
  final DateTime dueAt;
}

abstract interface class AccountDeletionApi {
  Future<bool> deletionRequiresPassword();
  Future<AccountDeletionReceipt> deleteAccount(String password);
}

class SecurityRepository {
  SecurityRepository(this.api);

  final SecurityApi api;

  Future<bool> deletionRequiresPassword() async {
    final deletionApi = api;
    if (deletionApi is! AccountDeletionApi) {
      throw StateError('Account deletion is unavailable.');
    }
    return (deletionApi as AccountDeletionApi).deletionRequiresPassword();
  }

  Future<AccountDeletionReceipt> deleteAccount(String password) async {
    final deletionApi = api;
    if (deletionApi is! AccountDeletionApi) {
      throw StateError('Account deletion is unavailable.');
    }
    return (deletionApi as AccountDeletionApi).deleteAccount(password);
  }

  Future<MfaEnrollment> startMfaEnrollment({String? currentCode}) async {
    return MfaEnrollment.fromJson(
      await api.startMfaEnrollment(currentCode: currentCode),
    );
  }

  Future<List<String>> confirmMfaEnrollment(String code) async {
    final response = await api.confirmMfaEnrollment(code);
    final codes = response['recoveryCodes'];
    return codes is List
        ? codes.whereType<String>().toList(growable: false)
        : const [];
  }

  Future<void> cancelMfaEnrollment() => api.cancelMfaEnrollment();

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await api.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  Future<void> disableMfa({
    required String password,
    String? code,
    String? recoveryCode,
  }) {
    return api.disableMfa(
      password: password,
      code: code,
      recoveryCode: recoveryCode,
    );
  }
}

class RestSecurityApi implements SecurityApi, AccountDeletionApi {
  RestSecurityApi(this.client);

  final AuthenticatedApiClient client;

  @override
  Future<bool> deletionRequiresPassword() async {
    final result = await client.get('/api/account/deletion-options');
    if (result['passwordRequired'] is! bool) {
      throw StateError('Could not load account verification requirements.');
    }
    return result['passwordRequired'] as bool;
  }

  @override
  Future<AccountDeletionReceipt> deleteAccount(String password) async {
    final result = await client.post('/api/account/delete', {
      'password': password,
    });
    final dueAt = DateTime.tryParse(result['dueAt']?.toString() ?? '');
    if (result['status'] != 'accepted' ||
        result['requestId'] is! String ||
        dueAt == null) {
      throw StateError('The server did not confirm the deletion request.');
    }
    await client.authRepository.clearLocalSession();
    return AccountDeletionReceipt(
      requestId: result['requestId'] as String,
      dueAt: dueAt,
    );
  }

  @override
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return client.post('/api/account/password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  @override
  Future<Map<String, dynamic>> startMfaEnrollment({String? currentCode}) {
    return client.post('/api/auth/mfa/enrollment/start', {
      'currentCode': ?currentCode,
    });
  }

  @override
  Future<Map<String, dynamic>> confirmMfaEnrollment(String code) {
    return client.post('/api/auth/mfa/enrollment/confirm', {'code': code});
  }

  @override
  Future<void> cancelMfaEnrollment() async {
    await client.post('/api/auth/mfa/enrollment/cancel', {});
  }

  @override
  Future<void> disableMfa({
    required String password,
    String? code,
    String? recoveryCode,
  }) async {
    await client.post('/api/auth/mfa/disable', {
      'password': password,
      ...?(code == null ? null : {'code': code}),
      ...?(recoveryCode == null ? null : {'recoveryCode': recoveryCode}),
    });
  }
}
