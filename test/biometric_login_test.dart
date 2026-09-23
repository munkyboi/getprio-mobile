import 'support/memory_onboarding_store.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/auth/auth_models.dart';
import 'package:getprio_mobile/auth/remembered_user_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:getprio_mobile/auth/auth_repository.dart';
import 'package:getprio_mobile/auth/biometric_login.dart';
import 'package:getprio_mobile/main.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'auth_repository_test.dart' show FakeAuthApi, authenticatedJson;

class FakeBiometrics implements BiometricLogin {
  bool enabled = true;
  bool available = true;
  bool accepted = true;
  int prompts = 0;
  @override
  Future<bool> isEnabled() async => enabled;
  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<bool> authenticate() async {
    prompts++;
    return accepted;
  }

  @override
  Future<bool> enable() async {
    if (!available || !await authenticate()) return false;
    enabled = true;
    return true;
  }

  @override
  Future<void> disable() async {
    enabled = false;
  }
}

class RevokedAuthApi extends FakeAuthApi {
  @override
  Future<Map<String, dynamic>> refresh(String refreshToken) async {
    throw const ApiException(401, 'SESSION_REVOKED', 'Sign in again');
  }
}

void main() {
  late FakeBiometrics biometrics;
  late FakeAuthApi api;
  late MemoryTokenStore tokens;
  late AuthRepository repository;
  setUp(() async {
    biometrics = FakeBiometrics();
    api = FakeAuthApi(
      refreshResponse: authenticatedJson(
        token: 'access',
        refreshToken: 'rotated',
      ),
      loginResponse: authenticatedJson(token: 'access', refreshToken: 'new'),
    );
    tokens = MemoryTokenStore()..refreshToken = 'saved';
    repository = AuthRepository(
      api: api,
      tokenStore: tokens,
      biometricLogin: biometrics,
    );
    await repository.rememberedUserStore.write(
      const AuthUser(
        id: 'user-1',
        email: 'customer@example.com',
        displayName: 'Display name',
      ),
    );
  });

  test(
    'cancelled biometric prompt never refreshes or exposes access',
    () async {
      biometrics.accepted = false;
      expect(await repository.restoreSession(), isNull);
      expect(api.lastRefreshToken, isNull);
      expect(repository.accessToken, isNull);
      expect(tokens.refreshToken, 'saved');
      expect(biometrics.enabled, isTrue);
    },
  );
  test(
    'successful biometric retry rotates token and preserves opt-in',
    () async {
      biometrics.accepted = false;
      await repository.restoreSession();
      biometrics.accepted = true;
      expect(await repository.restoreSession(), isNotNull);
      expect(tokens.refreshToken, 'rotated');
      expect(biometrics.prompts, 2);
      expect(biometrics.enabled, isTrue);
      await repository.restoreSession();
      expect(
        biometrics.prompts,
        2,
        reason: 'Background token refresh must not prompt again',
      );
    },
  );
  test(
    'disabled biometrics preserve existing session restore behavior',
    () async {
      biometrics.enabled = false;
      expect(await repository.restoreSession(), isNotNull);
      expect(biometrics.prompts, 0);
    },
  );
  test('concurrent restores share a single biometric prompt', () async {
    final results = await Future.wait([
      repository.restoreSession(),
      repository.restoreSession(),
    ]);
    expect(results.every((session) => session != null), isTrue);
    expect(biometrics.prompts, 1);
  });
  test('revoked session clears biometric opt-in and token', () async {
    repository = AuthRepository(
      api: RevokedAuthApi(),
      tokenStore: tokens,
      biometricLogin: biometrics,
    );
    await expectLater(
      repository.restoreSession(),
      throwsA(isA<ApiException>()),
    );
    expect(tokens.refreshToken, isNull);
    expect(biometrics.enabled, isFalse);
  });
  test('missing session does not prompt', () async {
    tokens.refreshToken = null;
    expect(await repository.restoreSession(), isNull);
    expect(biometrics.prompts, 0);
  });
  test('logout clears token and opt-in even if server logout fails', () async {
    api.logoutError = Exception('offline');
    await repository.logout();
    expect(tokens.refreshToken, isNull);
    expect(biometrics.enabled, isFalse);
  });
  test('fresh account login requires a new biometric opt-in', () async {
    await repository.rememberedUserStore.write(
      const AuthUser(id: 'other', email: 'other@example.com'),
    );
    await repository.signIn(identifier: 'another', password: 'password');
    expect(biometrics.enabled, isFalse);
    expect(tokens.refreshToken, 'new');
  });
  testWidgets('Security loads opt-in again when reopened and can disable', (
    tester,
  ) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: SecurityPage(repository: null, biometricLogin: biometrics),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Disable biometric login'), findsOneWidget);
    await tester.tap(find.byKey(const Key('biometric-login-toggle')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(biometrics.enabled, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      ShadcnApp(
        home: SecurityPage(repository: null, biometricLogin: biometrics),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Enable biometric login'), findsOneWidget);
    biometrics.accepted = false;
    await tester.tap(find.byKey(const Key('biometric-login-toggle')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(biometrics.enabled, isFalse);
  });
  testWidgets(
    'app launch waits for the biometric icon and keeps cancellation on screen',
    (tester) async {
      biometrics.accepted = false;
      await tester.pumpWidget(
        GetPrioApp(
          onboardingStore: MemoryOnboardingStore(completed: true),
          authRepository: repository,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BiometricLoginPage), findsOneWidget);
      expect(biometrics.prompts, 0);
      expect(api.lastRefreshToken, isNull);
      await tester.ensureVisible(find.byKey(const Key('biometric-login-icon')));
      await tester.ensureVisible(find.byKey(const Key('biometric-login-icon')));
      await tester.tap(find.byKey(const Key('biometric-login-icon')));
      await tester.pumpAndSettle();
      expect(biometrics.prompts, 1);
      expect(api.lastRefreshToken, isNull);
      expect(biometrics.enabled, isTrue);
      expect(find.byType(BiometricLoginPage), findsOneWidget);
      expect(
        find.text('Login was not completed. Tap the icon to try again.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(const Key('biometric-login-icon')));
      await tester.ensureVisible(find.byKey(const Key('biometric-login-icon')));
      await tester.tap(find.byKey(const Key('biometric-login-icon')));
      await tester.pumpAndSettle();
      expect(biometrics.prompts, 2);
      expect(find.byKey(const Key('sign-in-button')), findsOneWidget);
      expect(biometrics.prompts, 2);
    },
  );

  testWidgets('successful icon tap delivers the authenticated session', (
    tester,
  ) async {
    var authenticated = false;
    await tester.pumpWidget(
      ShadcnApp(
        home: BiometricLoginPage(
          authRepository: repository,
          onAuthenticated: (_) => authenticated = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(authenticated, isFalse);
    expect(biometrics.prompts, 0);
    await tester.ensureVisible(find.byKey(const Key('biometric-login-icon')));
    await tester.tap(find.byKey(const Key('biometric-login-icon')));
    await tester.pumpAndSettle();
    expect(authenticated, isTrue);
    expect(biometrics.prompts, 1);
    expect(tokens.refreshToken, 'rotated');
  });

  testWidgets('original login has a recovery link and no biometric button', (
    tester,
  ) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: SignInPage(authRepository: repository, onAuthenticated: (_) {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('biometric-sign-in')), findsNothing);
    expect(find.byKey(const Key('biometric-login-icon')), findsNothing);
    expect(find.byType(LinkButton), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('forgot-password-link')));
    await tester.tap(find.byKey(const Key('forgot-password-link')));
    await tester.pumpAndSettle();
    expect(find.byType(PasswordRecoveryPage), findsOneWidget);
  });

  testWidgets('login resizes for the keyboard and keeps fields scrollable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      tester.view.resetViewInsets();
    });
    await tester.pumpWidget(
      ShadcnApp(
        home: SignInPage(authRepository: repository, onAuthenticated: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.resizeToAvoidBottomInset, isTrue);
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    await tester.tap(find.byKey(const Key('sign-in-password')));
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    await tester.pumpAndSettle();
    final fieldRect = tester.getRect(find.byKey(const Key('sign-in-password')));
    final keyboardMediaQuery = tester.widget<MediaQuery>(
      find
          .byWidgetPredicate(
            (widget) =>
                widget is MediaQuery && widget.data.viewInsets.bottom > 0,
          )
          .first,
    );
    final keyboardTop =
        keyboardMediaQuery.data.size.height -
        keyboardMediaQuery.data.viewInsets.bottom;
    expect(fieldRect.bottom, lessThanOrEqualTo(keyboardTop - 24));
    expect(FocusManager.instance.primaryFocus, isNotNull);
  });

  for (final example in [
    (display: 'Marky', full: 'Mark Smith', expected: 'Marky'),
    (display: null, full: 'Mark Smith', expected: 'Mark S***h'),
    (display: '  ', full: ' Mark  James Smith ', expected: 'Mark J***s S***h'),
    (display: null, full: 'Mark', expected: 'M***k'),
    (display: null, full: null, expected: 'Your account'),
  ]) {
    testWidgets('biometric name displays ${example.expected} at 12px', (
      tester,
    ) async {
      await tester.pumpWidget(
        ShadcnApp(
          home: SignInPage(
            authRepository: repository,
            biometricLogin: true,
            rememberedUser: AuthUser(
              id: 'user-1',
              email: 'private@example.com',
              displayName: example.display,
              profileName: example.full,
            ),
            onAuthenticated: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final name = tester.widget<Text>(
        find.byKey(const Key('biometric-display-name')),
      );
      expect(name.data, example.expected);
      expect(name.style?.fontSize, 12);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == '${example.expected} profile photo',
        ),
        findsOneWidget,
      );
      expect(find.text('private@example.com'), findsNothing);
    });
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('saved login layout and password sign-in on $platform', (
      tester,
    ) async {
      var authenticated = false;
      await tester.pumpWidget(
        ShadcnApp(
          home: BiometricLoginPage(
            authRepository: repository,
            onAuthenticated: (_) => authenticated = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.byKey(const Key('biometric-profile-avatar')), findsOneWidget);
      expect(find.text('Display name'), findsOneWidget);
      expect(find.byKey(const Key('sign-in-identifier')), findsNothing);
      expect(
        find.text(
          platform == TargetPlatform.iOS
              ? 'Sign in with Face ID'
              : 'Sign in with biometrics',
        ),
        findsOneWidget,
      );
      expect(find.text('Google'), findsNothing);
      expect(find.text('Facebook'), findsNothing);
      expect(find.text('Create customer account'), findsNothing);
      expect(find.byType(LinkButton), findsOneWidget);
      expect(biometrics.prompts, 0);
      expect(
        tester.getTopLeft(find.byKey(const Key('sign-in-password'))).dy,
        greaterThan(
          tester
              .getBottomLeft(find.byKey(const Key('biometric-display-name')))
              .dy,
        ),
      );
      await tester.enterText(
        find.byKey(const Key('sign-in-password')),
        'password',
      );
      await tester.ensureVisible(find.byKey(const Key('sign-in-button')));
      await tester.tap(find.byKey(const Key('sign-in-button')));
      await tester.pumpAndSettle();
      expect(api.lastIdentifier, 'customer@example.com');
      expect(authenticated, isTrue);
      expect(biometrics.enabled, isTrue);
      expect(biometrics.prompts, 0);
    }, variant: TargetPlatformVariant({platform}));
  }

  testWidgets('saved-account password login still requires MFA', (
    tester,
  ) async {
    api.loginResponse!
      ..clear()
      ..addAll({
        'mfaRequired': true,
        'challengeToken': 'challenge',
        'expiresAt': '2026-09-29T10:00:00Z',
        'methods': ['totp'],
      });
    await tester.pumpWidget(
      ShadcnApp(
        home: BiometricLoginPage(
          authRepository: repository,
          onAuthenticated: (_) => fail('MFA must complete first'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('sign-in-password')),
      'password',
    );
    await tester.ensureVisible(find.byKey(const Key('sign-in-button')));
    await tester.tap(find.byKey(const Key('sign-in-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mfa-code')), findsOneWidget);
    expect(repository.accessToken, isNull);
    expect(biometrics.enabled, isTrue);
    expect(biometrics.prompts, 0);
  });

  test(
    'remembered profile persists across store instances and clears on logout',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final store = SecureRememberedUserStore();
      await store.write(
        const AuthUser(
          id: 'user-1',
          email: 'customer@example.com',
          displayName: 'Saved name',
          avatarUrl: 'https://example.com/avatar.png',
        ),
      );
      final saved = await SecureRememberedUserStore().read();
      expect(saved?.customerName, 'Saved name');
      expect(saved?.avatarUrl, 'https://example.com/avatar.png');
      final repo = AuthRepository(
        api: api,
        tokenStore: tokens,
        biometricLogin: biometrics,
        rememberedUserStore: store,
      );
      await repo.logout();
      expect(await store.read(), isNull);
    },
  );

  testWidgets('launch without saved session shows normal sign-in', (
    tester,
  ) async {
    tokens.refreshToken = null;
    await tester.pumpWidget(
      GetPrioApp(
        onboardingStore: MemoryOnboardingStore(completed: true),
        authRepository: repository,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BiometricLoginPage), findsNothing);
    expect(find.byKey(const Key('sign-in-button')), findsOneWidget);
    expect(biometrics.prompts, 0);
  });
}
