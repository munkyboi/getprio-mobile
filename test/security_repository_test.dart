import 'dart:convert';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
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

  testWidgets('shows a QR code and manual setup key in the setup flow', (
    tester,
  ) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: SecurityPage(repository: SecurityRepository(FakeSecurityApi())),
      ),
    );

    await tester.ensureVisible(find.text('Set up MFA'));
    await tester.tap(find.text('Set up MFA'));
    await tester.pumpAndSettle();

    final qr = tester.widget<BarcodeWidget>(
      find.byKey(const Key('mfa-enrollment-qr')),
    );
    expect(
      utf8.decode(qr.data),
      'otpauth://totp/GetPrio:test@example.com?secret=secret-1',
    );
    expect(find.byKey(const Key('mfa-enrollment-key')), findsOneWidget);
    expect(find.text('secret-1'), findsOneWidget);
  });

  testWidgets('copies the MFA setup key to the clipboard', (tester) async {
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
        home: SecurityPage(
          repository: SecurityRepository(FakeSecurityApi()),
          asSheet: true,
        ),
      ),
    );

    await tester.ensureVisible(find.byKey(const Key('mfa-setup-button')));
    await tester.tap(find.byKey(const Key('mfa-setup-button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('mfa-copy-key-button')));
    await tester.tap(find.byKey(const Key('mfa-copy-key-button')));
    await tester.pump();

    expect(clipboardCall?.method, 'Clipboard.setData');
    expect(clipboardCall?.arguments, {'text': 'secret-1'});
    expect(find.text('MFA setup key copied.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('shows an error toast when copying the MFA setup key fails', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        throw PlatformException(code: 'clipboard-failed');
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(
      ShadcnApp(
        home: SecurityPage(
          repository: SecurityRepository(FakeSecurityApi()),
          asSheet: true,
        ),
      ),
    );

    await tester.ensureVisible(find.byKey(const Key('mfa-setup-button')));
    await tester.tap(find.byKey(const Key('mfa-setup-button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('mfa-copy-key-button')));
    await tester.tap(find.byKey(const Key('mfa-copy-key-button')));
    await tester.pump();

    expect(find.text('Could not copy the MFA setup key.'), findsOneWidget);
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
    'otpAuthUri': 'otpauth://totp/GetPrio:test@example.com?secret=secret-1',
  };
}
