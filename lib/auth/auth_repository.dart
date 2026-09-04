import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'auth_models.dart';

abstract interface class AuthApi {
  Future<Map<String, dynamic>> registerCustomer({
    required String name,
    required String username,
    required String email,
    String? phone,
    required String password,
  });

  Future<Map<String, dynamic>> requestPasswordReset(String email);

  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  });

  Future<Map<String, dynamic>> refresh(String refreshToken);

  Future<Map<String, dynamic>> verifyMfa({
    required String challengeToken,
    String? code,
    String? recoveryCode,
  });

  Future<void> logout(String refreshToken);
}

abstract interface class UsernameAvailabilityApi {
  Future<Map<String, dynamic>> checkUsernameAvailability(String username);
}

abstract interface class CustomerRegistrationApi {
  Future<Map<String, dynamic>> startCustomerRegistration({
    required String name,
    required String username,
    required String email,
    required String password,
  });

  Future<Map<String, dynamic>> verifyCustomerRegistration({
    required String challengeId,
    required String code,
  });

  Future<Map<String, dynamic>> resendCustomerRegistrationCode({
    required String challengeId,
  });
}

abstract interface class TokenStore {
  Future<String?> readRefreshToken();

  Future<void> writeRefreshToken(String refreshToken);

  Future<void> clearRefreshToken();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _refreshTokenKey = 'getprio.refresh_token';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  @override
  Future<void> writeRefreshToken(String refreshToken) =>
      _storage.write(key: _refreshTokenKey, value: refreshToken);

  @override
  Future<void> clearRefreshToken() => _storage.delete(key: _refreshTokenKey);
}

class MemoryTokenStore implements TokenStore {
  String? refreshToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> writeRefreshToken(String value) async {
    refreshToken = value;
  }

  @override
  Future<void> clearRefreshToken() async {
    refreshToken = null;
  }
}

class AuthRepository {
  AuthRepository({required this.api, required this.tokenStore});

  final AuthApi api;
  final TokenStore tokenStore;
  String? _accessToken;
  Future<AuthSession?>? _restoreOperation;

  String? get accessToken => _accessToken;

  Future<LoginResult> signIn({
    required String identifier,
    required String password,
  }) async {
    final result = _parseLoginResult(
      await api.login(identifier: identifier, password: password),
    );
    await _persistIfAuthenticated(result);
    return result;
  }

  Future<LoginResult> completeLoginResponse(
    Map<String, dynamic> response,
  ) async {
    final result = _parseLoginResult(response);
    await _persistIfAuthenticated(result);
    return result;
  }

  Future<AuthenticatedSession> registerCustomer({
    required String name,
    required String username,
    required String email,
    String? phone,
    required String password,
  }) async {
    final session = AuthenticatedSession(
      AuthSession.fromJson(
        await api.registerCustomer(
          name: name,
          username: username,
          email: email,
          phone: phone,
          password: password,
        ),
      ),
    );
    await _persistSession(session.session);
    return session;
  }

  Future<UsernameAvailability> checkUsernameAvailability(
    String username,
  ) async {
    final availabilityApi = api is UsernameAvailabilityApi
        ? api as UsernameAvailabilityApi
        : null;
    if (availabilityApi == null) {
      throw const ApiException(
        0,
        'USERNAME_AVAILABILITY_UNAVAILABLE',
        'Username availability is not available. Try again later.',
      );
    }
    return UsernameAvailability.fromJson(
      await availabilityApi.checkUsernameAvailability(username),
    );
  }

  Future<CustomerRegistrationChallenge> startCustomerRegistration({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    final registrationApi = _registrationApi;
    if (registrationApi == null) {
      throw const ApiException(
        0,
        'REGISTRATION_OTP_UNAVAILABLE',
        'Email verification is not available. Try again later.',
      );
    }
    return CustomerRegistrationChallenge.fromJson(
      await registrationApi.startCustomerRegistration(
        name: name,
        username: username,
        email: email,
        password: password,
      ),
    );
  }

  Future<AuthenticatedSession> verifyCustomerRegistration({
    required String challengeId,
    required String code,
  }) async {
    final registrationApi = _registrationApi;
    if (registrationApi == null) {
      throw const ApiException(
        0,
        'REGISTRATION_OTP_UNAVAILABLE',
        'Email verification is not available. Try again later.',
      );
    }
    final session = AuthenticatedSession(
      AuthSession.fromJson(
        await registrationApi.verifyCustomerRegistration(
          challengeId: challengeId,
          code: code,
        ),
      ),
    );
    await _persistSession(session.session);
    return session;
  }

  Future<CustomerRegistrationChallenge> resendCustomerRegistrationCode({
    required String challengeId,
  }) async {
    final registrationApi = _registrationApi;
    if (registrationApi == null) {
      throw const ApiException(
        0,
        'REGISTRATION_OTP_UNAVAILABLE',
        'Email verification is not available. Try again later.',
      );
    }
    return CustomerRegistrationChallenge.fromJson(
      await registrationApi.resendCustomerRegistrationCode(
        challengeId: challengeId,
      ),
    );
  }

  CustomerRegistrationApi? get _registrationApi =>
      api is CustomerRegistrationApi ? api as CustomerRegistrationApi : null;

  Future<void> requestPasswordReset(String email) async {
    await api.requestPasswordReset(email);
  }

  Future<LoginResult> verifyMfa({
    required String challengeToken,
    String? code,
    String? recoveryCode,
  }) async {
    final result = _parseLoginResult(
      await api.verifyMfa(
        challengeToken: challengeToken,
        code: code,
        recoveryCode: recoveryCode,
      ),
    );
    await _persistIfAuthenticated(result);
    return result;
  }

  Future<AuthSession?> restoreSession() {
    return _restoreOperation ??= _restoreSessionOnce().whenComplete(() {
      _restoreOperation = null;
    });
  }

  Future<AuthSession?> _restoreSessionOnce() async {
    final refreshToken = await tokenStore.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;

    try {
      final session = AuthSession.fromJson(await api.refresh(refreshToken));
      await _persistSession(session);
      return session;
    } on ApiException catch (error) {
      if (error.statusCode == 401) await clearLocalSession();
      rethrow;
    } on FormatException {
      await clearLocalSession();
      rethrow;
    }
  }

  Future<void> logout() async {
    final refreshToken = await tokenStore.readRefreshToken();
    try {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await api.logout(refreshToken);
      }
    } finally {
      await clearLocalSession();
    }
  }

  Future<void> clearLocalSession() async {
    _accessToken = null;
    await tokenStore.clearRefreshToken();
  }

  LoginResult _parseLoginResult(Map<String, dynamic> json) {
    if (json['mfaRequired'] == true) return MfaChallenge.fromJson(json);
    return AuthenticatedSession(AuthSession.fromJson(json));
  }

  Future<void> _persistIfAuthenticated(LoginResult result) async {
    if (result case AuthenticatedSession(:final session)) {
      await _persistSession(session);
    }
  }

  Future<void> _persistSession(AuthSession session) async {
    _accessToken = session.accessToken;
    await tokenStore.writeRefreshToken(session.refreshToken);
  }
}

class ApiException implements Exception {
  const ApiException(this.statusCode, this.code, this.message);

  final int statusCode;
  final String? code;
  final String message;

  @override
  String toString() => 'ApiException($statusCode, $code, $message)';
}

class RestAuthApi
    implements AuthApi, UsernameAvailabilityApi, CustomerRegistrationApi {
  RestAuthApi({required String baseUrl, http.Client? client})
    : _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), ''),
      _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  @override
  Future<Map<String, dynamic>> registerCustomer({
    required String name,
    required String username,
    required String email,
    String? phone,
    required String password,
  }) {
    return _post('/api/auth/register/customer', {
      'name': name,
      'username': username,
      'email': email,
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      'password': password,
    }, compatibilityHeader: true);
  }

  @override
  Future<Map<String, dynamic>> checkUsernameAvailability(
    String username,
  ) async {
    if (_baseUrl.isEmpty) {
      throw const ApiException(
        0,
        'API_BASE_URL_MISSING',
        'API base URL is not configured.',
      );
    }

    final uri = Uri.parse('$_baseUrl/api/auth/username-availability')
        .replace(queryParameters: {'username': username});
    final response = await _client.get(uri);
    final decoded = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.statusCode,
        decoded?['code'] as String?,
        decoded?['message'] as String? ?? 'The request could not be completed.',
      );
    }
    return decoded ?? <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> startCustomerRegistration({
    required String name,
    required String username,
    required String email,
    required String password,
  }) {
    return _post('/api/auth/register/customer/otp', {
      'name': name,
      'username': username,
      'email': email,
      'password': password,
    }, compatibilityHeader: true);
  }

  @override
  Future<Map<String, dynamic>> verifyCustomerRegistration({
    required String challengeId,
    required String code,
  }) {
    return _post('/api/auth/register/customer/otp/verify', {
      'challengeId': challengeId,
      'code': code,
    }, compatibilityHeader: true);
  }

  @override
  Future<Map<String, dynamic>> resendCustomerRegistrationCode({
    required String challengeId,
  }) {
    return _post('/api/auth/register/customer/otp/resend', {
      'challengeId': challengeId,
    }, compatibilityHeader: true);
  }

  @override
  Future<Map<String, dynamic>> requestPasswordReset(String email) {
    return _post('/api/auth/password-reset/request', {'email': email});
  }

  @override
  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) {
    return _post('/api/auth/login', {
      'identifier': identifier,
      'password': password,
    }, compatibilityHeader: true);
  }

  @override
  Future<Map<String, dynamic>> refresh(String refreshToken) {
    return _post('/api/auth/refresh', {
      'refreshToken': refreshToken,
    }, compatibilityHeader: true);
  }

  @override
  Future<Map<String, dynamic>> verifyMfa({
    required String challengeToken,
    String? code,
    String? recoveryCode,
  }) {
    return _post('/api/auth/mfa/verify', {
      'challengeToken': challengeToken,
      ...?(code == null ? null : {'code': code}),
      ...?(recoveryCode == null ? null : {'recoveryCode': recoveryCode}),
    }, compatibilityHeader: true);
  }

  @override
  Future<void> logout(String refreshToken) async {
    await _post('/api/auth/logout', {'refreshToken': refreshToken});
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    bool compatibilityHeader = false,
  }) async {
    if (_baseUrl.isEmpty) {
      throw const ApiException(
        0,
        'API_BASE_URL_MISSING',
        'API base URL is not configured.',
      );
    }

    final response = await _client.post(
      Uri.parse('$_baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        if (compatibilityHeader) 'X-Auth-Compatibility': 'bearer-v1',
      },
      body: jsonEncode(body),
    );
    final decoded = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.statusCode,
        decoded?['code'] as String?,
        decoded?['message'] as String? ?? 'The request could not be completed.',
      );
    }
    return decoded ?? <String, dynamic>{};
  }

  Map<String, dynamic>? _decode(String body) {
    if (body.trim().isEmpty) return null;
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : null;
  }
}
