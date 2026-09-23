import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/auth/auth_repository.dart';
import 'package:getprio_mobile/auth/password_utils.dart';
import 'package:getprio_mobile/main.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  test('evaluates all customer registration password requirements', () {
    expect(evaluatePasswordStrength('Upper!12').isValid, isTrue);
    expect(evaluatePasswordStrength('upper!1').hasUppercase, isFalse);
    expect(evaluatePasswordStrength('Upper!1').hasTwoNumbers, isFalse);
    expect(
      evaluatePasswordStrength('Upper!1234567890123456789012345678')
          .isWithinMaximumLength,
      isFalse,
    );
  });

  test('uses the email OTP registration endpoints', () async {
    final api = RestAuthApi(
      baseUrl: 'https://api.example.test',
      client: MockClient((request) async {
        if (request.url.path == '/api/v1/auth/register/customer/otp') {
          expect(jsonDecode(request.body), {
            'name': 'Jane Doe',
            'username': 'jane_doe',
            'email': 'jane@example.com',
            'password': 'Upper!12',
          });
          return http.Response(
            jsonEncode({
              'challengeId': 'challenge-1',
              'step': 'email_otp',
              'deliveryTarget': 'j***@example.com',
            }),
            201,
          );
        }
        expect(request.url.path, '/api/v1/auth/register/customer/otp/verify');
        expect(jsonDecode(request.body), {
          'challengeId': 'challenge-1',
          'code': '123456',
        });
        return http.Response(
          jsonEncode({
            'token': 'access-otp',
            'refreshToken': 'refresh-otp',
            'sessionExpiresAt': '2026-09-29T10:00:00Z',
            'user': {'id': 'user-1', 'email': 'jane@example.com'},
          }),
          200,
        );
      }),
    );
    final repository = AuthRepository(api: api, tokenStore: MemoryTokenStore());

    final challenge = await repository.startCustomerRegistration(
      name: 'Jane Doe',
      username: 'jane_doe',
      email: 'jane@example.com',
      password: 'Upper!12',
    );
    final session = await repository.verifyCustomerRegistration(
      challengeId: challenge.challengeId,
      code: '123456',
    );

    expect(challenge.step, 'email_otp');
    expect(session.session.user.email, 'jane@example.com');
    expect(repository.accessToken, 'access-otp');
  });

  testWidgets('debounces username generation and verifies email with OTP', (
    tester,
  ) async {
    final api = RegistrationTestApi();
    var authenticated = false;
    await tester.pumpWidget(
      ShadcnApp(
        home: RegisterPage(
          authRepository: AuthRepository(
            api: api,
            tokenStore: MemoryTokenStore(),
          ),
          onAuthenticated: (_) => authenticated = true,
        ),
      ),
    );

    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('register-full-name')),
      'Jane Doe',
    );
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('register-email')),
      'jane@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('register-password')),
      'Upper!12',
    );
    await tester.pump(const Duration(milliseconds: 301));
    await tester.ensureVisible(find.byKey(const Key('register-submit')));
    await tester.tap(find.byKey(const Key('register-submit')));
    await tester.pumpAndSettle();

    expect(api.lastUsername, 'jane_doe');
    expect(api.startCalls, 1);
    expect(find.byKey(const Key('register-otp-screen')), findsOneWidget);
    expect(find.textContaining('j***@example.com'), findsOneWidget);
    expect(authenticated, isFalse);

    await tester.enterText(find.byKey(const Key('register-otp')), '123456');
    await tester.ensureVisible(find.byKey(const Key('register-otp-submit')));
    await tester.tap(find.byKey(const Key('register-otp-submit')));
    await tester.pumpAndSettle();

    expect(api.verifyCalls, 1);
    expect(authenticated, isTrue);
  });

  testWidgets('shows the debounced password strength bar', (tester) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: RegisterPage(
          authRepository: AuthRepository(
            api: RegistrationTestApi(),
            tokenStore: MemoryTokenStore(),
          ),
          onAuthenticated: (_) {},
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('register-password')),
      'Upper!12',
    );
    await tester.pump();
    expect(find.byKey(const Key('register-password-strength')), findsNothing);
    await tester.pump(const Duration(milliseconds: 301));

    expect(find.byKey(const Key('register-password-strength')), findsOneWidget);
    expect(
      find.byKey(const Key('register-password-strength-bar')),
      findsOneWidget,
    );
    expect(find.text('Strong'), findsOneWidget);
  });
}

class RegistrationTestApi implements AuthApi, CustomerRegistrationApi {
  int startCalls = 0;
  int verifyCalls = 0;
  String? lastUsername;

  @override
  Future<Map<String, dynamic>> checkUsernameAvailability(
    String username,
  ) async {
    lastUsername = username;
    return {
      'username': username,
      'available': true,
      'valid': true,
      'message': 'Username is available.',
    };
  }

  @override
  Future<Map<String, dynamic>> startCustomerRegistration({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    startCalls++;
    return {
      'challengeId': 'challenge-1',
      'step': 'email_otp',
      'deliveryTarget': 'j***@example.com',
    };
  }

  @override
  Future<Map<String, dynamic>> verifyCustomerRegistration({
    required String challengeId,
    required String code,
  }) async {
    verifyCalls++;
    return {
      'token': 'access-otp',
      'refreshToken': 'refresh-otp',
      'sessionExpiresAt': '2026-09-29T10:00:00Z',
      'user': {'id': 'user-1', 'email': 'jane@example.com'},
    };
  }

  @override
  Future<Map<String, dynamic>> resendCustomerRegistrationCode({
    required String challengeId,
  }) async => {
    'challengeId': challengeId,
    'step': 'email_otp',
    'deliveryTarget': 'j***@example.com',
  };

  @override
  Future<Map<String, dynamic>> registerCustomer({
    required String name,
    required String username,
    required String email,
    String? phone,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> requestPasswordReset(String email) async => {};

  @override
  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> refresh(String refreshToken) async =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> verifyMfa({
    required String challengeToken,
    String? code,
    String? recoveryCode,
  }) async => throw UnimplementedError();

  @override
  Future<void> logout(String refreshToken) async {}
}
