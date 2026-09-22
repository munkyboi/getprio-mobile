import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/account/ticket_repository.dart';
import 'package:getprio_mobile/auth/auth_repository.dart';
import 'package:getprio_mobile/queue/auth_queue_api.dart';
import 'package:getprio_mobile/queue/queue_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'Sandbox tickets load from the mobile active and history views',
    () async {
      final authRepository = AuthRepository(
        api: _NoopAuthApi(),
        tokenStore: MemoryTokenStore(),
      );
      await authRepository.completeLoginResponse({
        'token': 'access-token',
        'refreshToken': 'refresh-token',
        'sessionExpiresAt': '2026-09-23T00:00:00.000Z',
        'user': {'id': 'sandbox-user', 'email': 'sandbox@example.com'},
      });

      final requestedViews = <String>[];
      final httpClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/mobile/tickets');
        final view = request.url.queryParameters['view'];
        requestedViews.add(view!);
        final tickets = view == 'history'
            ? [
                {
                  'id': 'developer-ticket-1',
                  'ticket_number': 'A-001',
                  'source': 'developer_api',
                  'display_label': 'Sandbox queue',
                  'status': 'served',
                  'profile': {
                    'queue_name': 'Sandbox queue',
                    'location_name': null,
                    'location_slug': 'main',
                  },
                  'issued_at': '2026-09-22T00:00:00.000Z',
                  'updated_at': '2026-09-22T00:05:00.000Z',
                },
              ]
            : const <Map<String, dynamic>>[];
        return http.Response(jsonEncode({'tickets': tickets}), 200);
      });

      final repository = QueueTicketRepository(
        RestAccountQueueApi(
          AuthenticatedApiClient(
            baseUrl: 'https://sandbox-api.getprio.online',
            authRepository: authRepository,
            client: httpClient,
          ),
          sandbox: true,
        ),
      );

      final tickets = await repository.loadAllTickets();

      expect(requestedViews, ['active', 'history']);
      expect(tickets, hasLength(1));
      expect(tickets.single.id, 'developer-ticket-1');
      expect(tickets.single.ticketNumber, 'A-001');
      expect(tickets.single.vendorName, 'Sandbox queue');
      expect(tickets.single.status, TicketStatus.served);
    },
  );
}

class _NoopAuthApi implements AuthApi {
  @override
  Future<Map<String, dynamic>> registerCustomer({
    required String name,
    required String username,
    required String email,
    String? phone,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> checkUsernameAvailability(String username) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> requestPasswordReset(String email) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> refresh(String refreshToken) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> verifyMfa({
    required String challengeToken,
    String? code,
    String? recoveryCode,
  }) => throw UnimplementedError();

  @override
  Future<void> logout(String refreshToken) => throw UnimplementedError();
}
