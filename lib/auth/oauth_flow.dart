import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_models.dart';
import 'auth_repository.dart';
import '../network/api_paths.dart';

class PkcePair {
  const PkcePair({
    required this.state,
    required this.verifier,
    required this.challenge,
  });

  final String state;
  final String verifier;
  final String challenge;

  factory PkcePair.generate() {
    final state = _randomBase64Url(32);
    final verifier = _randomBase64Url(64);
    final digest = sha256.convert(utf8.encode(verifier));
    return PkcePair(
      state: state,
      verifier: verifier,
      challenge: base64Url.encode(digest.bytes).replaceAll('=', ''),
    );
  }
}

class OAuthCallback {
  const OAuthCallback({this.code, this.state, this.error});

  final String? code;
  final String? state;
  final String? error;

  factory OAuthCallback.parse(Uri uri) {
    return OAuthCallback(
      code: uri.queryParameters['code'],
      state: uri.queryParameters['state'],
      error: uri.queryParameters['error'],
    );
  }
}

abstract interface class OAuthBrowser {
  Future<bool> open(Uri uri);
}

/// Presents provider sign-in inside the app's Safari View Controller or
/// Android Custom Tab so OAuth does not eject customers into the default
/// browser during sign-in.
class InAppOAuthBrowser implements OAuthBrowser {
  @override
  Future<bool> open(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.inAppBrowserView);
}

/// Google and Facebook are available on every platform when OAuth is
/// configured. iOS also keeps Sign in with Apple available separately to
/// satisfy Apple's equivalent-login requirement.
bool shouldShowOAuthButtons({required bool enabled}) => enabled;

bool shouldShowAppleSignInButton({
  required bool enabled,
  required TargetPlatform platform,
}) => enabled && platform == TargetPlatform.iOS;

abstract interface class OAuthLinkSource {
  Future<Uri?> getInitialLink();

  Future<Uri?> getLatestLink();

  Stream<Uri> get linkStream;
}

class AppLinksSource implements OAuthLinkSource {
  AppLinksSource({AppLinks? appLinks}) : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  @override
  Future<Uri?> getInitialLink() => _appLinks.getInitialLink();

  @override
  Future<Uri?> getLatestLink() => _appLinks.getLatestLink();

  @override
  Stream<Uri> get linkStream => _appLinks.uriLinkStream;
}

abstract interface class OAuthApi {
  Future<Map<String, dynamic>> exchange({
    required String code,
    required String codeVerifier,
    required String state,
  });

  Future<Map<String, dynamic>> exchangeApple({
    required String identityToken,
    required String authorizationCode,
    required String nonce,
    String? givenName,
    String? familyName,
  });
}

class RestOAuthApi implements OAuthApi {
  RestOAuthApi({required String baseUrl, http.Client? client})
    : _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), ''),
      _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  @override
  Future<Map<String, dynamic>> exchange({
    required String code,
    required String codeVerifier,
    required String state,
  }) async {
    final response = await _client.post(
      Uri.parse(
        '$_baseUrl${versionedApiPath('/api/mobile/auth/oauth/exchange')}',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'code': code,
        'codeVerifier': codeVerifier,
        'state': state,
      }),
    );
    final decoded = response.body.trim().isEmpty
        ? null
        : jsonDecode(response.body);
    final body = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.statusCode,
        body['code'] as String?,
        body['message'] as String? ?? 'OAuth sign-in could not be completed.',
        correlationId: body['correlationId'] as String?,
      );
    }
    return body;
  }

  @override
  Future<Map<String, dynamic>> exchangeApple({
    required String identityToken,
    required String authorizationCode,
    required String nonce,
    String? givenName,
    String? familyName,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl${versionedApiPath('/api/mobile/auth/oauth/apple')}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'identityToken': identityToken,
        'authorizationCode': authorizationCode,
        'nonce': nonce,
        if (givenName != null && givenName.isNotEmpty) 'givenName': givenName,
        if (familyName != null && familyName.isNotEmpty)
          'familyName': familyName,
      }),
    );
    final decoded = response.body.trim().isEmpty
        ? null
        : jsonDecode(response.body);
    final body = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.statusCode,
        body['code'] as String?,
        body['message'] as String? ?? 'Apple sign-in could not be completed.',
      );
    }
    return body;
  }
}

class OAuthFlow {
  OAuthFlow({
    required this.baseUrl,
    required this.authRepository,
    required this.api,
    this.appleEnabled = false,
    OAuthBrowser? browser,
    OAuthLinkSource? links,
  }) : _browser = browser ?? InAppOAuthBrowser(),
       _links = links ?? AppLinksSource();

  final String baseUrl;
  final bool appleEnabled;
  final AuthRepository authRepository;
  final OAuthApi api;
  final OAuthBrowser _browser;
  final OAuthLinkSource _links;

  bool get enabled => baseUrl.isNotEmpty;

  static void validateCallback(
    OAuthCallback callback, {
    required String expectedState,
  }) {
    if (callback.state != expectedState) {
      throw const OAuthException(
        'OAuth state did not match the pending sign-in.',
      );
    }
    if (callback.error != null) {
      throw OAuthException(
        'OAuth sign-in was not completed: ${callback.error}.',
      );
    }
    if (callback.code == null || callback.code!.isEmpty) {
      throw const OAuthException(
        'OAuth callback did not contain an authorization code.',
      );
    }
  }

  Future<LoginResult> signIn(String provider) async {
    if (provider != 'google' && provider != 'facebook') {
      throw const OAuthException('This OAuth provider is not supported.');
    }
    final pair = PkcePair.generate();
    final startUri =
        Uri.parse(
          '$baseUrl${versionedApiPath('/api/mobile/auth/oauth/$provider/start')}',
        ).replace(
          queryParameters: {
            'intent': 'login',
            'state': pair.state,
            'code_challenge': pair.challenge,
          },
        );
    // Subscribe before opening the provider. On a warm app, getInitialLink()
    // can keep returning the callback from the previous sign-in attempt (for
    // example, after the user logs out and signs in again). Only consume a
    // callback carrying this attempt's state.
    final callbackCompleter = Completer<Uri>();
    final callbackSubscription = _links.linkStream.listen((uri) {
      if (_isCallbackForAttempt(uri, pair.state) &&
          !callbackCompleter.isCompleted) {
        callbackCompleter.complete(uri);
      }
    });

    try {
      if (!await _browser.open(startUri)) {
        throw const OAuthException('Could not open the sign-in provider.');
      }

      // Keep cold-start support, but do not trust the first link blindly on a
      // warm app. app_links exposes both the initial and latest received URI.
      final initial = await _links.getInitialLink();
      if (!callbackCompleter.isCompleted &&
          _isCallbackForAttempt(initial, pair.state)) {
        callbackCompleter.complete(initial!);
      } else {
        final latest = await _links.getLatestLink();
        if (!callbackCompleter.isCompleted &&
            _isCallbackForAttempt(latest, pair.state)) {
          callbackCompleter.complete(latest!);
        }
      }

      final callbackUri = await callbackCompleter.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => throw const OAuthException(
          'Timed out waiting for the sign-in callback. Please try again.',
        ),
      );
      final callback = OAuthCallback.parse(callbackUri);
      validateCallback(callback, expectedState: pair.state);
      final response = await api.exchange(
        code: callback.code!,
        codeVerifier: pair.verifier,
        state: pair.state,
      );
      return await authRepository.completeLoginResponse(response);
    } finally {
      await callbackSubscription.cancel();
    }
  }

  static bool _isCallbackForAttempt(Uri? uri, String expectedState) {
    return uri?.queryParameters['state'] == expectedState;
  }

  Future<LoginResult> signInWithApple() async {
    if (!enabled || !appleEnabled) {
      throw const OAuthException('Apple sign-in is not available.');
    }
    final state = PkcePair.generate().state;
    final nonce = generateNonce();
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
      state: state,
    );
    if (credential.state != state) {
      throw const OAuthException(
        'Apple sign-in state did not match the pending sign-in.',
      );
    }
    final identityToken = credential.identityToken;
    final authorizationCode = credential.authorizationCode;
    if (identityToken == null || identityToken.isEmpty) {
      throw const OAuthException(
        'Apple sign-in did not return an identity token.',
      );
    }
    if (authorizationCode.isEmpty) {
      throw const OAuthException(
        'Apple sign-in did not return an authorization code.',
      );
    }
    final response = await api.exchangeApple(
      identityToken: identityToken,
      authorizationCode: authorizationCode,
      nonce: nonce,
      givenName: credential.givenName,
      familyName: credential.familyName,
    );
    return authRepository.completeLoginResponse(response);
  }
}

class OAuthException implements Exception {
  const OAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _randomBase64Url(int length) {
  final random = Random.secure();
  final bytes = List<int>.generate(length, (_) => random.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}
