import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_repository.dart';

abstract interface class QueueApi {
  Future<Map<String, dynamic>> loadQueueSnapshot({
    required String tenantSlug,
    String? locationSlug,
    String? lookupCode,
  });

  Future<Map<String, dynamic>> cancelTicket({
    required String tenantSlug,
    required String lookupCode,
    String? locationSlug,
  });
}

class AuthenticatedApiClient {
  AuthenticatedApiClient({
    required String baseUrl,
    required this.authRepository,
    http.Client? client,
  }) : _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), ''),
       _client = client ?? http.Client();

  final String _baseUrl;
  final AuthRepository authRepository;
  final http.Client _client;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final uri = Uri.parse('$_baseUrl$path')
        .replace(queryParameters: queryParameters);
    return _send((token) => _client.get(uri, headers: _headers(token)));
  }

  Future<Map<String, dynamic>> delete(String path) async {
    return _send(
      (token) =>
          _client.delete(Uri.parse('$_baseUrl$path'), headers: _headers(token)),
    );
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    return _send(
      (token) => _client.post(
        Uri.parse('$_baseUrl$path'),
        headers: _headers(token, contentType: true),
        body: jsonEncode(body),
      ),
    );
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function(String token) request, {
    bool isRetry = false,
  }) async {
    final token = authRepository.accessToken;
    if (_baseUrl.isEmpty) {
      throw const ApiException(
        0,
        'API_BASE_URL_MISSING',
        'API base URL is not configured.',
      );
    }
    if (token == null || token.isEmpty) {
      throw const ApiException(401, 'AUTH_REQUIRED', 'Sign in is required.');
    }

    final response = await request(token);
    if (response.statusCode == 401 && !isRetry) {
      await authRepository.restoreSession();
      return _send(request, isRetry: true);
    }
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

  Map<String, String> _headers(String token, {bool contentType = false}) {
    return {
      'Authorization': 'Bearer $token',
      if (contentType) 'Content-Type': 'application/json',
    };
  }

  Map<String, dynamic>? _decode(String body) {
    if (body.trim().isEmpty) return null;
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : null;
  }
}

class RestQueueApi implements QueueApi {
  RestQueueApi(this.client);

  final AuthenticatedApiClient client;

  @override
  Future<Map<String, dynamic>> loadQueueSnapshot({
    required String tenantSlug,
    String? locationSlug,
    String? lookupCode,
  }) {
    final path = locationSlug == null
        ? '/api/public/tenant/$tenantSlug/queue'
        : '/api/public/tenant/$tenantSlug/location/$locationSlug/queue';
    return client.get(
      path,
      queryParameters: {
        ...?(lookupCode == null ? null : {'lookupCode': lookupCode}),
      },
    );
  }

  @override
  Future<Map<String, dynamic>> cancelTicket({
    required String tenantSlug,
    required String lookupCode,
    String? locationSlug,
  }) {
    final path = locationSlug == null
        ? '/api/public/tenant/$tenantSlug/tickets/$lookupCode'
        : '/api/public/tenant/$tenantSlug/location/$locationSlug/tickets/$lookupCode';
    return client.delete(path);
  }
}
