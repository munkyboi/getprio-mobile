import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:getprio_mobile/auth/auth_repository.dart';
import 'package:getprio_mobile/queue/auth_queue_api.dart';
import 'package:getprio_mobile/queue/queue_models.dart';
import 'package:getprio_mobile/queue/queue_repository.dart';

void main() {
  test('parses a customer ticket and uses display name first', () {
    final ticket = QueueTicket.fromJson({
      'id': 'ticket-1',
      'lookupCode': 'ABC123',
      'ticketNumber': 42,
      'customerName': 'Profile name',
      'customerDisplayName': 'Preferred name',
      'status': 'waiting',
      'position': 3,
      'estimatedWaitMinutes': 15,
      'joinedAt': '2026-08-30T10:00:00Z',
      'vendorName': 'Acme Clinic',
      'locationName': 'Makati',
    });

    expect(ticket.customerName, 'Preferred name');
    expect(ticket.status, TicketStatus.waiting);
    expect(ticket.position, 3);
    expect(ticket.isActive, isTrue);
  });

  test(
    'maps account ticket aliases and preserves formatted ticket numbers',
    () {
      final ticket = QueueTicket.fromJson({
        'id': 'ticket-account',
        'lookupCode': 'ABC123',
        'ticketNumber': 'AH002',
        'tenantName': 'Acme Clinic',
        'tenantSlug': 'acme-clinic',
        'locationName': 'Main location',
        'locationSlug': 'main',
        'status': 'waiting',
        'createdAt': '2026-09-02T10:00:00Z',
      });

      expect(ticket.ticketNumber, 'AH002');
      expect(ticket.vendorName, 'Acme Clinic');
      expect(ticket.joinedAt, isNotNull);
    },
  );

  test('keeps non-waiting ticket positions hidden from the domain', () {
    final ticket = QueueTicket.fromJson({
      'id': 'ticket-2',
      'lookupCode': 'CALLED1',
      'ticketNumber': 7,
      'customerName': 'Profile name',
      'status': 'called',
      'position': 1,
      'estimatedWaitMinutes': 5,
    });

    expect(ticket.position, isNull);
    expect(ticket.estimatedWaitMinutes, isNull);
    expect(ticket.isActive, isTrue);
  });

  test('derives CONFIRMED for a called ticket after vendor scan', () {
    final ticket = QueueTicket.fromJson({
      'id': 'ticket-confirmed',
      'lookupCode': 'CONFIRM1',
      'ticketNumber': 'AH009',
      'status': 'called',
      'customerConfirmedAt': '2026-09-03T04:00:00Z',
    });

    expect(ticket.status, TicketStatus.called);
    expect(ticket.isConfirmed, isTrue);
    expect(ticket.displayStatusLabel, 'Confirmed');
  });

  test('cancellation rejects a ticket that is no longer waiting', () async {
    final api = FakeQueueApi();
    final repository = QueueRepository(api);
    final ticket = QueueTicket.fromJson({
      'id': 'ticket-2',
      'lookupCode': 'CALLED1',
      'ticketNumber': 7,
      'customerName': 'Profile name',
      'status': 'called',
    });

    expect(
      () => repository.cancelTicket(tenantSlug: 'acme-clinic', ticket: ticket),
      throwsA(isA<StateError>()),
    );
    expect(api.cancelCalled, isFalse);
  });

  test('cancellation supports a pending carry-over ticket', () async {
    final api = FakeQueueApi();
    final repository = QueueRepository(api);
    final ticket = QueueTicket.fromJson({
      'id': 'ticket-carry-over',
      'lookupCode': 'CARRY01',
      'ticketNumber': 'AH008',
      'customerName': 'Profile name',
      'status': 'pending_carry_over',
    });

    final cancelled = await repository.cancelTicket(
      tenantSlug: 'acme-clinic',
      ticket: ticket,
    );

    expect(api.cancelCalled, isTrue);
    expect(cancelled.status, TicketStatus.cancelled);
  });

  test('queue repository maps the focus ticket from a snapshot', () async {
    final repository = QueueRepository(
      FakeQueueApi(
        snapshot: {
          'serverNow': '2026-08-30T10:00:00Z',
          'joinable': true,
          'focusTicket': {
            'id': 'ticket-1',
            'lookupCode': 'ABC123',
            'ticketNumber': 42,
            'customerName': 'Profile name',
            'status': 'waiting',
            'position': 2,
          },
        },
      ),
    );

    final snapshot = await repository.loadQueueSnapshot(
      tenantSlug: 'acme-clinic',
      lookupCode: 'ABC123',
    );

    expect(snapshot.joinable, isTrue);
    expect(snapshot.focusTicket?.lookupCode, 'ABC123');
  });

  test('parses live queue status and customer confirmation data', () async {
    final repository = QueueRepository(
      FakeQueueApi(
        snapshot: {
          'queueDay': {
            'state': 'open',
            'isClosed': false,
            'isPaused': false,
            'availabilityReason': 'accepting',
          },
          'queueIntake': {
            'state': 'open',
            'stateLabel': 'Open',
            'currentWaitingCount': 2,
          },
          'stats': {
            'waitingCount': 2,
            'servedToday': 5,
            'currentTicketNumber': 17,
            'estimatedWaitMinutes': 10,
          },
          'current': {
            'id': 'ticket-current',
            'ticketNumber': 17,
            'status': 'called',
            'calledAt': '2026-09-02T10:00:00Z',
          },
          'focusTicket': {
            'id': 'ticket-1',
            'lookupCode': 'ABC123',
            'ticketNumber': 42,
            'customerName': 'Profile name',
            'status': 'called',
            'customerConfirmedAt': '2026-09-02T10:01:00Z',
          },
        },
      ),
    );

    final snapshot = await repository.loadQueueSnapshot(
      tenantSlug: 'acme-clinic',
      lookupCode: 'ABC123',
    );

    expect(snapshot.queueDay.state, 'open');
    expect(snapshot.queueIntake.stateLabel, 'Open');
    expect(snapshot.stats.waitingCount, 2);
    expect(snapshot.stats.estimatedWaitMinutes, 10);
    expect(snapshot.current?.ticketNumber, '17');
    expect(snapshot.focusTicket?.customerConfirmedAt, isNotNull);
  });

  test(
    'retries one time with the refreshed bearer token after a 401',
    () async {
      final authApi = FakeAuthApiForTransport();
      final authRepository = AuthRepository(
        api: authApi,
        tokenStore: MemoryTokenStore()..refreshToken = 'refresh-1',
      );
      await authRepository.signIn(identifier: 'customer', password: 'password');
      final requests = <http.BaseRequest>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (requests.length == 1) return http.Response('{}', 401);
        return http.Response('{"joinable":true}', 200);
      });
      final api = AuthenticatedApiClient(
        baseUrl: 'https://api.example.test',
        authRepository: authRepository,
        client: client,
      );

      final response = await api.get('/api/account/overview');

      expect(response['joinable'], isTrue);
      expect(requests, hasLength(2));
      expect(requests[0].headers['authorization'], 'Bearer access-1');
      expect(requests[1].headers['authorization'], 'Bearer access-2');
      expect(authApi.refreshCalls, 1);
    },
  );

  test('preserves the API correlation ID on a failed request', () async {
    final authApi = FakeAuthApiForTransport();
    final authRepository = AuthRepository(
      api: authApi,
      tokenStore: MemoryTokenStore()..refreshToken = 'refresh-1',
    );
    await authRepository.signIn(identifier: 'customer', password: 'password');
    final api = AuthenticatedApiClient(
      baseUrl: 'https://api.example.test',
      authRepository: authRepository,
      client: MockClient(
        (_) async => http.Response(
          '{"code":"SANDBOX_DEVICE_LIMIT","message":"Device limit reached.","correlationId":"request-42"}',
          409,
        ),
      ),
    );

    await expectLater(
      api.put('/api/mobile/push/registrations/install-1', {}),
      throwsA(
        isA<ApiException>()
            .having((error) => error.code, 'code', 'SANDBOX_DEVICE_LIMIT')
            .having(
              (error) => error.correlationId,
              'correlationId',
              'request-42',
            ),
      ),
    );
  });
}

class FakeQueueApi implements QueueApi {
  FakeQueueApi({this.snapshot});

  final Map<String, dynamic>? snapshot;
  bool cancelCalled = false;

  @override
  Future<Map<String, dynamic>> loadQueueSnapshot({
    required String tenantSlug,
    String? locationSlug,
    String? lookupCode,
  }) async => snapshot ?? <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> cancelTicket({
    required String tenantSlug,
    required String lookupCode,
    String? locationSlug,
  }) async {
    cancelCalled = true;
    return <String, dynamic>{};
  }
}

class FakeAuthApiForTransport implements AuthApi {
  int refreshCalls = 0;

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
  }) async => authenticatedJson('access-1', 'refresh-1');

  @override
  Future<Map<String, dynamic>> requestPasswordReset(String email) async =>
      <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    return authenticatedJson('access-1', 'refresh-1');
  }

  @override
  Future<Map<String, dynamic>> refresh(String refreshToken) async {
    refreshCalls++;
    return authenticatedJson('access-2', 'refresh-2');
  }

  @override
  Future<Map<String, dynamic>> verifyMfa({
    required String challengeToken,
    String? code,
    String? recoveryCode,
  }) async => <String, dynamic>{};

  @override
  Future<void> logout(String refreshToken) async {}
}

Map<String, dynamic> authenticatedJson(
  String accessToken,
  String refreshToken,
) {
  return {
    'token': accessToken,
    'refreshToken': refreshToken,
    'sessionExpiresAt': '2026-09-29T10:00:00Z',
    'user': {'id': 'user-1', 'email': 'customer@example.com'},
  };
}
