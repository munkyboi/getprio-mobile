import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/account/account_settings_repository.dart';
import 'package:getprio_mobile/account/phone_formatting.dart';
import 'package:getprio_mobile/account/profile_repository.dart';
import 'package:getprio_mobile/account/security_repository.dart';
import 'package:getprio_mobile/auth/auth_models.dart';
import 'package:getprio_mobile/main.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter/services.dart';

void main() {
  test('formats Philippine mobile numbers like the web app', () {
    expect(formatPhilippineMobileNumber('09171234567'), '(0917) 123-4567');
    expect(formatPhilippineMobileNumber('+639171234567'), '(0917) 123-4567');
    expect(formatPhilippineMobileNumber('9171234567'), '(0917) 123-4567');
    expect(formatPhilippineMobileNumber('0917'), '(0917');
    expect(isPhilippineMobileNumber('(0917) 123-4567'), isTrue);
  });

  testWidgets('opens personal info from both the card and the menu row', (
    tester,
  ) async {
    final api = FakeAccountProfileApi();
    final repository = AccountProfileRepository(api);
    await tester.pumpWidget(
      ShadcnApp(
        home: AccountPage(user: api.user, profileRepository: repository),
      ),
    );

    await tester.tap(find.byKey(const Key('profile-edit-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('profile-personal-info-sheet')),
      findsOneWidget,
    );
    expect(find.text('Personal info'), findsWidgets);
    expect(find.text('(0917) 123-4567'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('Close personal info')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-personal-info')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('profile-personal-info-sheet')),
      findsOneWidget,
    );
  });

  testWidgets(
    'invalid profile email marks the field without saving partial changes',
    (tester) async {
      final api = FakeAccountProfileApi();
      await tester.pumpWidget(
        ShadcnApp(
          home: AccountPage(
            user: api.user,
            profileRepository: AccountProfileRepository(api),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('profile-edit-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('profile-full-name')),
        'Updated Name',
      );
      await tester.tap(find.byKey(const Key('profile-email-update')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('profile-email')),
        'invalid-email',
      );
      await tester.ensureVisible(find.byKey(const Key('profile-save')));
      await tester.tap(find.byKey(const Key('profile-save')));
      await tester.pumpAndSettle();
      expect(api.profileUpdates, 0);
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    },
  );

  testWidgets('saves name and display name from the personal info sheet', (
    tester,
  ) async {
    final api = FakeAccountProfileApi();
    await tester.pumpWidget(
      ShadcnApp(
        home: AccountPage(
          user: api.user,
          profileRepository: AccountProfileRepository(api),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('profile-edit-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('profile-full-name')),
      'Jordan Smith',
    );
    await tester.enterText(
      find.byKey(const Key('profile-display-name')),
      'Jordan',
    );
    final saveButton = find.byKey(const Key('profile-save'));
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(api.profileUpdates, 1);
    expect(find.byKey(const Key('profile-personal-info-sheet')), findsNothing);
    expect(find.text('Jordan'), findsOneWidget);
    expect(find.text('Profile updated.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('runs the verified email-change flow in the same sheet', (
    tester,
  ) async {
    final api = FakeAccountProfileApi();
    await tester.pumpWidget(
      ShadcnApp(
        home: AccountPage(
          user: api.user,
          profileRepository: AccountProfileRepository(api),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('profile-edit-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-email')), findsNothing);
    expect(find.byKey(const Key('profile-email-value')), findsOneWidget);
    await tester.tap(find.byKey(const Key('profile-email-update')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('profile-email')),
      'new@example.com',
    );
    final saveButton = find.byKey(const Key('profile-save'));
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(find.text('Verify your current email'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('profile-email-code')),
      '111111',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('profile-verify-code')));
    await tester.pumpAndSettle();
    expect(find.text('Verify your new email'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('profile-email-code')),
      '222222',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('profile-verify-code')));
    await tester.pumpAndSettle();

    expect(api.emailChangeVerifications, 2);
    expect(
      find.byKey(const Key('profile-personal-info-sheet')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('profile-email-code')), findsNothing);
    expect(find.byKey(const Key('profile-email')), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const Key('profile-email-value'))).data,
      'new@example.com',
    );
    expect(find.text('Email address updated.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.tap(find.byKey(const ValueKey('Close personal info')));
    await tester.pumpAndSettle();
    expect(find.text('new@example.com'), findsOneWidget);
    await tester.tap(find.byKey(const Key('profile-edit-button')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('profile-email-value'))).data,
      'new@example.com',
    );
  });

  testWidgets('opens notifications as a bottom sheet and saves the toggle', (
    tester,
  ) async {
    final settingsApi = FakeAccountSettingsApi();
    await tester.pumpWidget(
      ShadcnApp(
        home: AccountPage(
          user: FakeAccountProfileApi().user,
          settingsRepository: AccountSettingsRepository(settingsApi),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('profile-notifications')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('profile-notifications-sheet')),
      findsOneWidget,
    );
    final sheet = find.byKey(const Key('profile-notifications-sheet'));
    expect(tester.widget(sheet), isNot(isA<Container>()));
    expect(
      tester.getSize(sheet).height,
      lessThan(MediaQuery.sizeOf(tester.element(sheet)).height * 0.7),
    );
    await tester.tap(find.byKey(const Key('profile-queue-alerts')));
    await tester.pumpAndSettle();
    expect(settingsApi.lastQueueAlerts, isFalse);
    expect(find.text('Notification preferences saved.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('waits for notification content before starting its animation', (
    tester,
  ) async {
    final settingsApi = FakeAccountSettingsApi();
    final load = Completer<Map<String, dynamic>>();
    settingsApi.loadCompleter = load;
    await tester.pumpWidget(
      ShadcnApp(
        home: AccountPage(
          user: FakeAccountProfileApi().user,
          settingsRepository: AccountSettingsRepository(settingsApi),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('profile-notifications')));
    await tester.pump();
    expect(find.byKey(const Key('profile-notifications-sheet')), findsNothing);

    load.complete({
      'notificationSettings': {'queueAlerts': true},
    });
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('profile-notifications-sheet')),
      findsOneWidget,
    );
  });

  testWidgets('dismisses the keyboard when a profile field loses focus', (
    tester,
  ) async {
    final api = FakeAccountProfileApi();
    await tester.pumpWidget(
      ShadcnApp(
        home: AccountPage(
          user: api.user,
          profileRepository: AccountProfileRepository(api),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('profile-edit-button')));
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('profile-full-name'));
    await tester.tap(field);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNotNull);

    await tester.tap(
      find.text(
        'Keep your contact details current so queue updates reach you.',
      ),
    );
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('requires confirmation before logging out', (tester) async {
    var signedOut = false;
    await tester.pumpWidget(
      ShadcnApp(
        home: AccountPage(
          user: FakeAccountProfileApi().user,
          onSignOut: () => signedOut = true,
        ),
      ),
    );

    final logout = find.byKey(const Key('profile-logout'));
    await tester.drag(
      find.byKey(const Key('account-page')),
      const Offset(0, -500),
    );
    await tester.pump();
    await tester.tap(logout);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('logout-confirmation-dialog')), findsOneWidget);
    expect(signedOut, isFalse);

    await tester.tap(find.byKey(const Key('logout-cancel')));
    await tester.pumpAndSettle();
    expect(signedOut, isFalse);

    await tester.ensureVisible(logout);
    await tester.tap(logout);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout-confirm')));
    await tester.pumpAndSettle();
    expect(signedOut, isTrue);
  });

  for (final section in SecuritySection.values) {
    testWidgets('opens only ${section.name} in its security bottom sheet', (
      tester,
    ) async {
      await tester.pumpWidget(
        ShadcnApp(home: AccountPage(user: FakeAccountProfileApi().user)),
      );
      final action = find.byKey(ValueKey('profile-${section.name}'));
      await tester.scrollUntilVisible(
        action,
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('account-page')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(action);
      await tester.pumpAndSettle();
      final sheet = find.byKey(ValueKey('profile-${section.name}-sheet'));
      expect(sheet, findsOneWidget);
      final viewportHeight = MediaQuery.sizeOf(tester.element(sheet)).height;
      expect(
        tester.getSize(sheet).height,
        lessThanOrEqualTo(viewportHeight * 0.8),
      );
      expect(
        find.descendant(of: sheet, matching: find.text('Current password')),
        section == SecuritySection.password ? findsOneWidget : findsNothing,
      );
      expect(
        find.descendant(
          of: sheet,
          matching: find.byKey(const Key('mfa-setup-button')),
        ),
        section == SecuritySection.mfa ? findsOneWidget : findsNothing,
      );
      expect(
        find.descendant(
          of: sheet,
          matching: find.text(
            'Biometric login is unavailable in this session.',
          ),
        ),
        section == SecuritySection.biometrics ? findsOneWidget : findsNothing,
      );
      expect(find.text('Privacy and security'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('shows a toast when copying from the security bottom sheet', (
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

    final user = FakeAccountProfileApi().user;
    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: AccountPage(
            user: user,
            securityRepository: SecurityRepository(FakeProfileSecurityApi()),
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-mfa')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('account-page')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const Key('profile-mfa')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('mfa-setup-button')));
    await tester.tap(find.byKey(const Key('mfa-setup-button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('mfa-copy-key-button')));
    await tester.tap(find.byKey(const Key('mfa-copy-key-button')));
    await tester.pump();

    expect(clipboardCall?.arguments, {'text': 'secret-1'});
    expect(find.text('MFA setup key copied.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}

class FakeAccountProfileApi implements AccountProfileApi {
  AuthUser user = const AuthUser(
    id: 'user-1',
    email: 'customer@example.com',
    profileName: 'Ava Reyes',
    displayName: 'Ava',
    phone: '09171234567',
    emailVerified: true,
  );
  int profileUpdates = 0;
  int emailChangeVerifications = 0;

  Map<String, dynamic> _userJson() => {
    'id': user.id,
    'email': user.email,
    'name': user.profileName,
    'displayName': user.displayName,
    'phone': user.phone,
    'avatarUrl': user.avatarUrl,
    'emailVerified': user.emailVerified,
  };

  @override
  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String displayName,
  }) async {
    profileUpdates++;
    user = user.copyWith(profileName: name, displayName: displayName);
    return {'user': _userJson()};
  }

  @override
  Future<Map<String, dynamic>> uploadAvatar({
    required String fileName,
    required String contentType,
    required List<int> bytes,
  }) async => {'user': _userJson()};

  @override
  Future<Map<String, dynamic>> startEmailChange({
    required String newEmail,
  }) async => {
    'challengeId': 'email-challenge',
    'step': 'current_email',
    'deliveryTarget': 'c***@example.com',
    'expiresAt': DateTime.now()
        .add(const Duration(minutes: 10))
        .toIso8601String(),
  };

  @override
  Future<Map<String, dynamic>> verifyCurrentEmail({
    required String challengeId,
    required String code,
  }) async {
    emailChangeVerifications++;
    return {
      'challengeId': challengeId,
      'step': 'new_email',
      'deliveryTarget': 'n***@example.com',
      'expiresAt': DateTime.now()
          .add(const Duration(minutes: 10))
          .toIso8601String(),
    };
  }

  @override
  Future<Map<String, dynamic>> verifyNewEmail({
    required String challengeId,
    required String code,
  }) async {
    emailChangeVerifications++;
    user = user.copyWith(email: 'new@example.com', emailVerified: true);
    return {'user': _userJson()};
  }

  @override
  Future<Map<String, dynamic>> startPhoneChange({
    required String newPhone,
  }) async => {
    'challengeId': 'phone-challenge',
    'step': 'email_otp',
    'deliveryTarget': 'c***@example.com',
  };

  @override
  Future<Map<String, dynamic>> verifyPhoneChange({
    required String challengeId,
    required String code,
    required String password,
  }) async => {'user': _userJson()};
}

class FakeAccountSettingsApi implements AccountSettingsApi {
  bool? lastQueueAlerts;
  Completer<Map<String, dynamic>>? loadCompleter;

  @override
  Future<Map<String, dynamic>> loadNotificationSettings() {
    return loadCompleter?.future ??
        Future.value({
          'notificationSettings': {'queueAlerts': true},
        });
  }

  @override
  Future<Map<String, dynamic>> updateNotificationSettings({
    required bool queueAlerts,
  }) async {
    lastQueueAlerts = queueAlerts;
    return {
      'notificationSettings': {'queueAlerts': queueAlerts},
    };
  }
}

class FakeProfileSecurityApi implements SecurityApi {
  @override
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async => <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> startMfaEnrollment() async => {
    'secret': 'secret-1',
    'otpAuthUri': 'otpauth://totp/GetPrio:test@example.com?secret=secret-1',
  };

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
}
