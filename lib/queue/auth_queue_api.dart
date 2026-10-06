import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_repository.dart';
import '../network/api_paths.dart';

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
    http.Client Function()? eventClientFactory,
  }) : _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), ''),
       _eventClientFactory = eventClientFactory ?? http.Client.new,
       _client = client ?? http.Client();

  final String _baseUrl;
  final AuthRepository authRepository;
  final http.Client _client;
  final http.Client Function() _eventClientFactory;

  /// Public queue events contain no customer data or authentication tokens.
  Stream<void> watchPublicQueue(String tenantSlug, String locationSlug) {
    late StreamController<void> controller;
    http.Client? connection;
    var cancelled = false;
    Future<void> connect() async {
      connection = _eventClientFactory();
      try {
        final request = http.Request(
          'GET',
          Uri.parse(
            '$_baseUrl${versionedApiPath('/api/public/tenant/${Uri.encodeComponent(tenantSlug)}')}'
            '/location/${Uri.encodeComponent(locationSlug)}/stream',
          ),
        )..headers['Accept'] = 'text/event-stream';
        final response = await connection!
            .send(request)
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) {
          throw StateError('Queue event stream unavailable');
        }
        var heartbeat = false;
        var hasData = false;
        await for (final line
            in response.stream
                .timeout(const Duration(seconds: 45))
                .transform(utf8.decoder)
                .transform(const LineSplitter())) {
          if (cancelled) break;
          if (line.isEmpty) {
            if (hasData && !heartbeat) controller.add(null);
            heartbeat = false;
            hasData = false;
          } else if (line.startsWith('event:')) {
            heartbeat = line.substring(6).trim() == 'heartbeat';
          } else if (line.startsWith('data:')) {
            hasData = true;
          }
        }
      } catch (error, stack) {
        if (!cancelled) controller.addError(error, stack);
      } finally {
        connection?.close();
        if (!cancelled) unawaited(controller.close());
      }
    }

    controller = StreamController<void>(
      onListen: () => unawaited(connect()),
      onCancel: () {
        cancelled = true;
        connection?.close();
      },
    );
    return controller.stream;
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? additionalHeaders,
  }) async {
    final uri = Uri.parse('$_baseUrl${versionedApiPath(path)}')
        .replace(queryParameters: queryParameters);
    return _send(
      (token) => _client.get(
        uri,
        headers: _headers(token, additionalHeaders: additionalHeaders),
      ),
    );
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, String>? additionalHeaders,
  }) async {
    return _send(
      (token) => _client.delete(
        Uri.parse('$_baseUrl${versionedApiPath(path)}'),
        headers: _headers(token, additionalHeaders: additionalHeaders),
      ),
    );
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? additionalHeaders,
  }) async {
    return _send(
      (token) => _client.post(
        Uri.parse('$_baseUrl${versionedApiPath(path)}'),
        headers: _headers(
          token,
          contentType: true,
          additionalHeaders: additionalHeaders,
        ),
        body: jsonEncode(body),
      ),
    );
  }

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? additionalHeaders,
  }) async {
    return _send(
      (token) => _client.put(
        Uri.parse('$_baseUrl${versionedApiPath(path)}'),
        headers: _headers(
          token,
          contentType: true,
          additionalHeaders: additionalHeaders,
        ),
        body: jsonEncode(body),
      ),
    );
  }

  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? additionalHeaders,
  }) async {
    return _send(
      (token) => _client.patch(
        Uri.parse('$_baseUrl${versionedApiPath(path)}'),
        headers: _headers(
          token,
          contentType: true,
          additionalHeaders: additionalHeaders,
        ),
        body: jsonEncode(body),
      ),
    );
  }

  Future<Map<String, dynamic>> uploadBytes(
    String path, {
    required List<int> bytes,
    required String contentType,
    Map<String, String>? queryParameters,
  }) async {
    final uri = Uri.parse('$_baseUrl${versionedApiPath(path)}')
        .replace(queryParameters: queryParameters);
    return _send(
      (token) => _client.post(
        uri,
        headers: _headers(
          token,
          additionalHeaders: {'Content-Type': contentType},
        ),
        body: bytes,
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

  Map<String, String> _headers(
    String token, {
    bool contentType = false,
    Map<String, String>? additionalHeaders,
  }) {
    return {
      'Authorization': 'Bearer $token',
      if (contentType) 'Content-Type': 'application/json',
      ...?additionalHeaders,
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
