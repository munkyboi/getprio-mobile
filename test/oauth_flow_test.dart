import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/auth/oauth_flow.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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

  test('hides legacy OAuth buttons on iOS', () {
    expect(
      shouldShowLegacyOAuthButtons(enabled: true, platform: TargetPlatform.iOS),
      isFalse,
    );
  });

  test('shows legacy OAuth buttons on Android when enabled', () {
    expect(
      shouldShowLegacyOAuthButtons(
        enabled: true,
        platform: TargetPlatform.android,
      ),
      isTrue,
    );
  });

  test('hides legacy OAuth buttons when OAuth is unavailable', () {
    expect(
      shouldShowLegacyOAuthButtons(
        enabled: false,
        platform: TargetPlatform.android,
      ),
      isFalse,
    );
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
