import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/auth/auth_models.dart';
import 'package:getprio_mobile/auth/auth_repository.dart';
import 'package:getprio_mobile/auth/username_utils.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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

  test('logout clears local auth when the server logout fails', () async {
    final api = FakeAuthApi(
      loginResponse: authenticatedJson(
        token: 'access-1',
        refreshToken: 'refresh-1',
      ),
    )..logoutError = StateError('offline');
    final tokens = MemoryTokenStore();
    final repository = AuthRepository(api: api, tokenStore: tokens);

    await repository.signIn(
      identifier: 'customer@example.com',
      password: 'password',
    );
    await repository.logout();

    expect(repository.accessToken, isNull);
    expect(await tokens.readRefreshToken(), isNull);
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

  test('username utilities match the web normalization rules', () {
    expect(buildUsernameFromName('Jane Doe!'), 'jane_doe');
    expect(normalizeUsernameInput('  Jane.Doe_99  '), 'janedoe_99');
    expect(isUsernameFormatValid('abc_123'), isTrue);
    expect(isUsernameFormatValid('ab'), isFalse);
  });

  test('checks username availability through the auth endpoint', () async {
    final api = RestAuthApi(
      baseUrl: 'https://api.example.test',
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/auth/username-availability');
        expect(request.url.queryParameters['username'], 'jane_doe');
        return http.Response(
          jsonEncode({
            'username': 'jane_doe',
            'available': true,
            'valid': true,
            'message': 'Username is available.',
          }),
          200,
        );
      }),
    );

    final result = await AuthRepository(
      api: api,
      tokenStore: MemoryTokenStore(),
    ).checkUsernameAvailability('jane_doe');

    expect(result.username, 'jane_doe');
    expect(result.available, isTrue);
    expect(result.valid, isTrue);
    expect(result.message, 'Username is available.');
  });

  test(
    'sandbox password auth uses the dedicated mobile auth endpoints',
    () async {
      final paths = <String>[];
      final compatibilityHeaders = <String, String?>{};
      final api = RestAuthApi(
        baseUrl: 'https://sandbox-api.example.test',
        sandbox: true,
        client: MockClient((request) async {
          paths.add(request.url.path);
          compatibilityHeaders[request.url.path] =
              request.headers['x-auth-compatibility'];
          return http.Response(
            jsonEncode(
              authenticatedJson(
                token: 'sandbox-access',
                refreshToken: 'sandbox-refresh',
              ),
            ),
            200,
          );
        }),
      );

      await api.login(identifier: 'test-abc@sandbox.invalid', password: 'once');
      await api.refresh('sandbox-refresh');
      await api.logout('sandbox-refresh');

      expect(paths, [
        '/api/v1/mobile/auth/login',
        '/api/v1/mobile/auth/refresh',
        '/api/v1/mobile/auth/logout',
      ]);
      expect(compatibilityHeaders['/api/v1/mobile/auth/login'], isNull);
      expect(compatibilityHeaders['/api/v1/mobile/auth/refresh'], isNull);
      expect(compatibilityHeaders['/api/v1/mobile/auth/logout'], isNull);
    },
  );

  test('sandbox auth rejects production account flows locally', () async {
    final api = RestAuthApi(
      baseUrl: 'https://sandbox-api.example.test',
      sandbox: true,
      client: MockClient((_) async => http.Response('{}', 500)),
    );

    await expectLater(
      api.startCustomerRegistration(
        name: 'Synthetic user',
        username: 'synthetic',
        email: 'test-abc@sandbox.invalid',
        password: 'password',
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'SANDBOX_AUTH_UNSUPPORTED',
        ),
      ),
    );
  });

  test('turns non-JSON auth errors into an API exception', () async {
    final api = RestAuthApi(
      baseUrl: 'https://api.example.test',
      client: MockClient((request) async {
        return http.Response('<!doctype html><title>Not Found</title>', 404);
      }),
    );

    await expectLater(
      api.startCustomerRegistration(
        name: 'Jane Doe',
        username: 'jane_doe',
        email: 'jane+signup@example.com',
        password: 'Upper!12',
      ),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'status code', 404)
            .having((error) => error.message, 'message', isNotEmpty),
      ),
    );
  });

  test('starts customer registration with email verification', () async {
    final api = RestAuthApi(
      baseUrl: 'https://api.example.test',
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/auth/register/customer/otp');
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
            'expiresAt': '2026-09-04T10:10:00Z',
          }),
          201,
        );
      }),
    );

    final challenge =
        await AuthRepository(
          api: api,
          tokenStore: MemoryTokenStore(),
        ).startCustomerRegistration(
          name: 'Jane Doe',
          username: 'jane_doe',
          email: 'jane@example.com',
          password: 'Upper!12',
        );

    expect(challenge.challengeId, 'challenge-1');
    expect(challenge.deliveryTarget, 'j***@example.com');
  });

  test(
    'verifies customer registration and stores the returned session',
    () async {
      final api = RestAuthApi(
        baseUrl: 'https://api.example.test',
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/auth/register/customer/otp/verify');
          expect(jsonDecode(request.body), {
            'challengeId': 'challenge-1',
            'code': '123456',
          });
          return http.Response(
            jsonEncode(
              authenticatedJson(
                token: 'access-otp',
                refreshToken: 'refresh-otp',
              ),
            ),
            200,
          );
        }),
      );
      final tokens = MemoryTokenStore();
      final repository = AuthRepository(api: api, tokenStore: tokens);

      final session = await repository.verifyCustomerRegistration(
        challengeId: 'challenge-1',
        code: '123456',
      );

      expect(session.session.user.email, 'customer@example.com');
      expect(repository.accessToken, 'access-otp');
      expect(await tokens.readRefreshToken(), 'refresh-otp');
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
  Object? logoutError;

  @override
  Future<Map<String, dynamic>> checkUsernameAvailability(
    String username,
  ) async => {
    'username': username,
    'available': true,
    'valid': true,
    'message': 'Username is available.',
  };

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
  Future<void> logout(String refreshToken) async {
    if (logoutError != null) throw logoutError!;
  }
}
