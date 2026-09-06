import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/account/security_repository.dart';
import 'package:getprio_mobile/auth/auth_repository.dart';
import 'package:getprio_mobile/form_validation.dart';
import 'package:getprio_mobile/main.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  test('validates email, verification codes and new password policy', () {
    expect(emailField('invalid@'), isNotNull);
    expect(emailField('name+queue@example.com'), isNull);
    expect(codeField('12345'), isNotNull);
    expect(codeField('123456'), isNull);
    expect(newPasswordField('weak'), isNotNull);
    expect(newPasswordField('Secure!12'), isNull);
  });

  testWidgets(
    'password validation blocks invalid requests and clears edited field errors',
    (tester) async {
      final api = _SecurityApi();
      await _open(tester, api);
      await _submit(tester);
      expect(api.calls, 0);
      expect(find.text('Current password is required.'), findsOneWidget);
      expect(find.text('Confirm your new password.'), findsOneWidget);
      expect(find.text('Please check the highlighted fields.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('change-current-password')),
        'Old!12',
      );
      await tester.pump();
      expect(find.text('Current password is required.'), findsNothing);
      await tester.enterText(
        find.byKey(const Key('change-new-password')),
        'Secure!12',
      );
      await tester.enterText(
        find.byKey(const Key('change-confirm-password')),
        'Mismatch!12',
      );
      await _submit(tester);
      expect(api.calls, 0);
      expect(find.text('Passwords do not match.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'incorrect current password highlights field and valid retry shows success',
    (tester) async {
      final api = _SecurityApi()..reject = true;
      var success = false;
      await _open(tester, api, onSuccess: () => success = true);
      await tester.enterText(
        find.byKey(const Key('change-current-password')),
        'Wrong!12',
      );
      await tester.enterText(
        find.byKey(const Key('change-new-password')),
        'Secure!12',
      );
      await tester.enterText(
        find.byKey(const Key('change-confirm-password')),
        'Secure!12',
      );
      await _submit(tester);
      expect(find.text('Current password is incorrect.'), findsOneWidget);
      expect(success, isFalse);
      api.reject = false;
      await tester.enterText(
        find.byKey(const Key('change-current-password')),
        'Correct!12',
      );
      await _submit(tester);
      expect(api.calls, 2);
      expect(success, isTrue);
      expect(
        find.text('Password changed. Please sign in again.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('change-new-password')))
            .controller!
            .text,
        isEmpty,
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('password inputs and submit are disabled during submission', (
    tester,
  ) async {
    final api = _SecurityApi()..pending = Completer<Map<String, dynamic>>();
    await _open(tester, api);
    await tester.enterText(
      find.byKey(const Key('change-current-password')),
      'Old!12',
    );
    await tester.enterText(
      find.byKey(const Key('change-new-password')),
      'Secure!12',
    );
    await tester.enterText(
      find.byKey(const Key('change-confirm-password')),
      'Secure!12',
    );
    await _submit(tester);
    expect(api.calls, 1);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('change-new-password')))
          .enabled,
      isFalse,
    );
    api.pending!.complete({});
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
  });
}

Future<void> _open(
  WidgetTester tester,
  _SecurityApi api, {
  VoidCallback? onSuccess,
}) async {
  await tester.pumpWidget(
    ShadcnApp(
      home: SecurityPage(
        repository: SecurityRepository(api),
        section: SecuritySection.password,
        asSheet: true,
        onPasswordChanged: onSuccess,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('change-password-submit')));
  await tester.tap(find.byKey(const Key('change-password-submit')));
  await tester.pumpAndSettle();
}

class _SecurityApi implements SecurityApi {
  int calls = 0;
  bool reject = false;
  Completer<Map<String, dynamic>>? pending;
  @override
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    calls++;
    if (reject) {
      throw const ApiException(
        401,
        'WRONG_PASSWORD',
        'Current password is incorrect.',
      );
    }
    return pending == null ? {} : await pending!.future;
  }

  @override
  Future<void> cancelMfaEnrollment() async {}
  @override
  Future<Map<String, dynamic>> confirmMfaEnrollment(String code) async => {};
  @override
  Future<void> disableMfa({
    required String password,
    String? code,
    String? recoveryCode,
  }) async {}
  @override
  Future<Map<String, dynamic>> startMfaEnrollment() async => {};
}
