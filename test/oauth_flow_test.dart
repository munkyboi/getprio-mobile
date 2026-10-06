import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/auth/auth_models.dart';
import 'package:getprio_mobile/auth/auth_repository.dart';
import 'package:getprio_mobile/auth/oauth_flow.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'auth_repository_test.dart' show FakeAuthApi, authenticatedJson;

void main() {
  test('generates an S256 PKCE challenge from the verifier', () {
    final pair = PkcePair.generate();

    expect(pair.state, isNotEmpty);
    expect(pair.verifier, isNotEmpty);
    expect(pair.challenge, isNot(pair.verifier));
    expect(pair.challenge, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
  });

  test('accepts a successful verified-link callback', () {
    final callback = OAuthCallback.parse(
      Uri.parse(
        'https://app.getprio.test/oauth/mobile/callback?code=one-time&state=state-1',
      ),
    );

    expect(callback.code, 'one-time');
    expect(callback.state, 'state-1');
    expect(callback.error, isNull);
  });

  test('surfaces provider cancellation without accepting a token', () {
    final callback = OAuthCallback.parse(
      Uri.parse(
        'https://app.getprio.test/oauth/mobile/callback?error=access_denied&state=state-1',
      ),
    );

    expect(callback.code, isNull);
    expect(callback.error, 'access_denied');
  });

  test('rejects callback state mismatch', () {
    expect(
      () => OAuthFlow.validateCallback(
        OAuthCallback.parse(
          Uri.parse(
            'https://app.getprio.test/oauth/mobile/callback?code=one&state=other',
          ),
        ),
        expectedState: 'expected',
      ),
      throwsA(isA<OAuthException>()),
    );
  });

  test('uses the current callback after a previous OAuth sign-in', () async {
    final links = _FakeOAuthLinks(
      initial: Uri.parse(
        'getprio://callback?code=old-code&state=previous-attempt',
      ),
    );
    addTearDown(links.dispose);
    final oauthApi = _FakeOAuthApi();
    final repository = AuthRepository(
      api: FakeAuthApi(
        loginResponse: authenticatedJson(
          token: 'access-token',
          refreshToken: 'refresh-token',
        ),
      ),
      tokenStore: MemoryTokenStore(),
    );
    final flow = OAuthFlow(
      baseUrl: 'https://api.example.com',
      authRepository: repository,
      api: oauthApi,
      browser: _EmittingOAuthBrowser(links),
      links: links,
    );

    final result = await flow.signIn('google');

    expect(result, isA<AuthenticatedSession>());
    expect(oauthApi.code, 'current-code');
    expect(oauthApi.state, isNot('previous-attempt'));
  });

  test('shows OAuth buttons on iOS when enabled', () {
    expect(shouldShowOAuthButtons(enabled: true), isTrue);
  });

  test('shows OAuth buttons on Android when enabled', () {
    expect(shouldShowOAuthButtons(enabled: true), isTrue);
  });

  test('hides OAuth buttons when OAuth is unavailable', () {
    expect(shouldShowOAuthButtons(enabled: false), isFalse);
  });

  test('shows Apple sign-in only on iOS when OAuth is configured', () {
    expect(
      shouldShowAppleSignInButton(enabled: true, platform: TargetPlatform.iOS),
      isTrue,
    );
    expect(
      shouldShowAppleSignInButton(
        enabled: true,
        platform: TargetPlatform.android,
      ),
      isFalse,
    );
    expect(
      shouldShowAppleSignInButton(enabled: false, platform: TargetPlatform.iOS),
      isFalse,
    );
  });

  test(
    'posts Apple credentials to the versioned mobile exchange route',
    () async {
      Uri? requestUri;
      Map<String, dynamic>? requestBody;
      final api = RestOAuthApi(
        baseUrl: 'https://api.example.com/',
        client: MockClient((request) async {
          requestUri = request.url;
          requestBody = jsonDecode(request.body) as Map<String, dynamic>;
          return httpResponse(jsonEncode({'token': 'access-token'}), 200);
        }),
      );

      await api.exchangeApple(
        identityToken: 'identity-token',
        authorizationCode: 'authorization-code',
        nonce: 'nonce',
        givenName: 'Apple',
        familyName: 'Customer',
      );

      expect(requestUri?.path, '/api/v1/mobile/auth/oauth/apple');
      expect(requestBody, {
        'identityToken': 'identity-token',
        'authorizationCode': 'authorization-code',
        'nonce': 'nonce',
        'givenName': 'Apple',
        'familyName': 'Customer',
      });
    },
  );
}

http.Response httpResponse(String body, int statusCode) => http.Response(
  body,
  statusCode,
  headers: {'content-type': 'application/json'},
);

class _FakeOAuthLinks implements OAuthLinkSource {
  _FakeOAuthLinks({this.initial});

  final Uri? initial;
  final StreamController<Uri> _controller = StreamController<Uri>.broadcast();

  @override
  Future<Uri?> getInitialLink() async => initial;

  @override
  Future<Uri?> getLatestLink() async => null;

  @override
  Stream<Uri> get linkStream => _controller.stream;

  void emit(Uri uri) => _controller.add(uri);

  Future<void> dispose() => _controller.close();
}

class _EmittingOAuthBrowser implements OAuthBrowser {
  _EmittingOAuthBrowser(this.links);

  final _FakeOAuthLinks links;

  @override
  Future<bool> open(Uri uri) async {
    links.emit(
      Uri.parse(
        'getprio://callback?code=current-code&state=${uri.queryParameters['state']}',
      ),
    );
    return true;
  }
}

class _FakeOAuthApi implements OAuthApi {
  String? code;
  String? state;

  @override
  Future<Map<String, dynamic>> exchange({
    required String code,
    required String codeVerifier,
    required String state,
  }) async {
    this.code = code;
    this.state = state;
    return authenticatedJson(
      token: 'access-token',
      refreshToken: 'refresh-token',
    );
  }

  @override
  Future<Map<String, dynamic>> exchangeApple({
    required String identityToken,
    required String authorizationCode,
    required String nonce,
    String? givenName,
    String? familyName,
  }) async => throw UnimplementedError();
}
