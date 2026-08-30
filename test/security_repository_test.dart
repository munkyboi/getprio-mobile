import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/account/security_repository.dart';

void main() {
  test(
    'parses MFA enrollment and keeps recovery codes as a one-time result',
    () async {
      final repository = SecurityRepository(FakeSecurityApi());

      final enrollment = await repository.startMfaEnrollment();
      final recoveryCodes = await repository.confirmMfaEnrollment('123456');

      expect(enrollment.otpauthUri.scheme, 'otpauth');
      expect(recoveryCodes, ['recovery-1', 'recovery-2']);
    },
  );
}

class FakeSecurityApi implements SecurityApi {
  @override
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async => <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> confirmMfaEnrollment(String code) async => {
    'recoveryCodes': ['recovery-1', 'recovery-2'],
  };

  @override
  Future<void> cancelMfaEnrollment() async {}

  @override
  Future<void> disableMfa({
    required String password,
    String? code,
    String? recoveryCode,
  }) async {}

  @override
  Future<Map<String, dynamic>> startMfaEnrollment() async => {
    'secret': 'secret-1',
    'otpauthUri': 'otpauth://totp/GetPrio:test@example.com?secret=secret-1',
  };
}
