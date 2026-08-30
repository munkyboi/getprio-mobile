import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/auth/auth_models.dart';
import 'package:getprio_mobile/auth/auth_repository.dart';

void main() {
  test(
    'sign in stores the rotated refresh token and keeps access in memory',
    () async {
      final api = FakeAuthApi(
        loginResponse: authenticatedJson(
          token: 'access-1',
          refreshToken: 'refresh-1',
        ),
      );
      final tokens = MemoryTokenStore();
      final repository = AuthRepository(api: api, tokenStore: tokens);

      final result = await repository.signIn(
        identifier: 'customer@example.com',
        password: 'correct horse battery staple',
      );

      expect(result, isA<AuthenticatedSession>());
      expect(repository.accessToken, 'access-1');
      expect(await tokens.readRefreshToken(), 'refresh-1');
      expect(api.lastIdentifier, 'customer@example.com');
    },
  );

  test('sign in returns an MFA challenge without storing tokens', () async {
    final api = FakeAuthApi(
      loginResponse: {
        'mfaRequired': true,
        'challengeToken': 'challenge-1',
        'expiresAt': '2026-08-30T10:05:00Z',
        'methods': ['totp', 'recovery'],
      },
    );
    final tokens = MemoryTokenStore();
    final repository = AuthRepository(api: api, tokenStore: tokens);

    final result = await repository.signIn(
      identifier: 'customer@example.com',
      password: 'password',
    );

    expect(result, isA<MfaChallenge>());
    expect((result as MfaChallenge).challengeToken, 'challenge-1');
    expect(repository.accessToken, isNull);
    expect(await tokens.readRefreshToken(), isNull);
  });

  test('restore replaces the refresh token after rotation', () async {
    final api = FakeAuthApi(
      refreshResponse: authenticatedJson(
        token: 'access-2',
        refreshToken: 'refresh-2',
      ),
    );
    final tokens = MemoryTokenStore()..refreshToken = 'refresh-1';
    final repository = AuthRepository(api: api, tokenStore: tokens);

    final session = await repository.restoreSession();

    expect(session?.user.email, 'customer@example.com');
    expect(repository.accessToken, 'access-2');
    expect(await tokens.readRefreshToken(), 'refresh-2');
    expect(api.lastRefreshToken, 'refresh-1');
  });

  test(
    'customer registration creates and stores an authenticated session',
    () async {
      final api =
          FakeAuthApi(
              loginResponse: authenticatedJson(
                token: 'unused',
                refreshToken: 'unused',
              ),
            )
            ..registrationResponse = authenticatedJson(
              token: 'access-registration',
              refreshToken: 'refresh-registration',
            );
      final tokens = MemoryTokenStore();
      final repository = AuthRepository(api: api, tokenStore: tokens);

      final result = await repository.registerCustomer(
        name: 'Profile name',
        username: 'customer',
        email: 'customer@example.com',
        password: 'password',
      );

      expect(result.session.user.email, 'customer@example.com');
      expect(repository.accessToken, 'access-registration');
      expect(await tokens.readRefreshToken(), 'refresh-registration');
    },
  );
}

Map<String, dynamic> authenticatedJson({
  required String token,
  required String refreshToken,
}) {
  return {
    'token': token,
    'refreshToken': refreshToken,
    'sessionExpiresAt': '2026-09-29T10:00:00Z',
    'user': {
      'id': 'user-1',
      'email': 'customer@example.com',
      'name': 'Profile name',
      'displayName': 'Display name',
    },
  };
}

class FakeAuthApi implements AuthApi {
  FakeAuthApi({this.loginResponse, this.refreshResponse});

  final Map<String, dynamic>? loginResponse;
  final Map<String, dynamic>? refreshResponse;
  Map<String, dynamic>? registrationResponse;
  String? lastIdentifier;
  String? lastRefreshToken;

  @override
  Future<Map<String, dynamic>> registerCustomer({
    required String name,
    required String username,
    required String email,
    String? phone,
    required String password,
  }) async => registrationResponse!;

  @override
  Future<Map<String, dynamic>> requestPasswordReset(String email) async =>
      <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    lastIdentifier = identifier;
    return loginResponse!;
  }

  @override
  Future<Map<String, dynamic>> refresh(String refreshToken) async {
    lastRefreshToken = refreshToken;
    return refreshResponse!;
  }

  @override
  Future<Map<String, dynamic>> verifyMfa({
    required String challengeToken,
    String? code,
    String? recoveryCode,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout(String refreshToken) async {}
}
