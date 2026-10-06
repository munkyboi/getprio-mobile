import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/account/security_repository.dart';
import 'package:getprio_mobile/auth/auth_models.dart';
import 'package:getprio_mobile/main.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'security_repository_test.dart' show FakeSecurityApi;

void main() {
  testWidgets('enabled accounts cannot start enrollment', (tester) async {
    await tester.pumpWidget(
      const ShadcnApp(home: SecurityPage(repository: null, mfaEnabled: true)),
    );
    expect(find.byKey(const Key('mfa-setup-button')), findsNothing);
    expect(
      find.text('MFA is enabled. Use your authenticator app when signing in.'),
      findsOneWidget,
    );
  });

  testWidgets('confirmation updates account and reopening keeps MFA enabled', (
    tester,
  ) async {
    AuthUser? updatedUser;
    await tester.pumpWidget(
      ShadcnApp(
        home: AccountPage(
          user: const AuthUser(id: '1', email: 'test@example.com'),
          securityRepository: SecurityRepository(FakeSecurityApi()),
          onUserUpdated: (user) => updatedUser = user,
        ),
      ),
    );
    await tester.scrollUntilVisible(find.byKey(const Key('profile-mfa')), 250);
    await tester.ensureVisible(find.byKey(const Key('profile-mfa')));
    await tester.tap(find.byKey(const Key('profile-mfa')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mfa-setup-button')));
    await tester.pumpAndSettle();
    final code = find.byKey(const Key('mfa-enrollment-code'));
    await tester.ensureVisible(code);
    await tester.enterText(code, '123456');
    await tester.ensureVisible(find.byKey(const Key('mfa-confirm-button')));
    await tester.tap(find.byKey(const Key('mfa-confirm-button')));
    await tester.pumpAndSettle();
    expect(updatedUser?.mfaEnabled, isTrue);
    expect(find.byKey(const Key('mfa-recovery-codes')), findsOneWidget);
    expect(find.byKey(const Key('mfa-setup-button')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('Close MFA Setup')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('profile-mfa')), 250);
    await tester.ensureVisible(find.byKey(const Key('profile-mfa')));
    await tester.tap(find.byKey(const Key('profile-mfa')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mfa-setup-button')), findsNothing);
    expect(find.byKey(const Key('mfa-recovery-codes')), findsNothing);
    expect(
      find.text('MFA is enabled. Use your authenticator app when signing in.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
