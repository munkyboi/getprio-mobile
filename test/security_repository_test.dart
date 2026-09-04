import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/account/security_repository.dart';
import 'package:getprio_mobile/main.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

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

  testWidgets('hides setup after MFA confirmation and copies recovery codes', (
    tester,
  ) async {
    MethodCall? clipboardCall;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboardCall = call;
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(
      ShadcnApp(
        home: SecurityPage(repository: SecurityRepository(FakeSecurityApi())),
      ),
    );

    await tester.tap(find.text('Set up MFA'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      '123456',
    );
    await tester.ensureVisible(find.byKey(const Key('mfa-confirm-button')));
    await tester.tap(find.byKey(const Key('mfa-confirm-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mfa-setup-button')), findsNothing);
    await tester.ensureVisible(
      find.byKey(const Key('mfa-copy-recovery-codes-button')),
    );
    await tester.tap(find.byKey(const Key('mfa-copy-recovery-codes-button')));
    await tester.pump();

    expect(clipboardCall?.method, 'Clipboard.setData');
    expect(clipboardCall?.arguments, {'text': 'recovery-1\nrecovery-2'});
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
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
