import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
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

class ExternalOAuthBrowser implements OAuthBrowser {
  @override
  Future<bool> open(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}

abstract interface class OAuthLinkSource {
  Future<Uri?> getInitialLink();

  Stream<Uri> get linkStream;
}

class AppLinksSource implements OAuthLinkSource {
  AppLinksSource({AppLinks? appLinks}) : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  @override
  Future<Uri?> getInitialLink() => _appLinks.getInitialLink();

  @override
  Stream<Uri> get linkStream => _appLinks.uriLinkStream;
}

abstract interface class OAuthApi {
  Future<Map<String, dynamic>> exchange({
    required String code,
    required String codeVerifier,
    required String state,
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
}

class OAuthFlow {
  OAuthFlow({
    required this.baseUrl,
    required this.authRepository,
    required this.api,
    OAuthBrowser? browser,
    OAuthLinkSource? links,
  }) : _browser = browser ?? ExternalOAuthBrowser(),
       _links = links ?? AppLinksSource();

  final String baseUrl;
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
    if (!await _browser.open(startUri)) {
      throw const OAuthException('Could not open the sign-in provider.');
    }
    final initial = await _links.getInitialLink();
    final callback = initial == null
        ? OAuthCallback.parse(await _links.linkStream.first)
        : OAuthCallback.parse(initial);
    validateCallback(callback, expectedState: pair.state);
    final response = await api.exchange(
      code: callback.code!,
      codeVerifier: pair.verifier,
      state: pair.state,
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
