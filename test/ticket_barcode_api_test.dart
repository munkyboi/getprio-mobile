import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/account/ticket_repository.dart';
import 'package:getprio_mobile/auth/auth_repository.dart';
import 'package:getprio_mobile/queue/auth_queue_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'queue_repository_test.dart' show FakeAuthApiForTransport;

void main() {
  test('issues versioned owner barcode via authenticated POST', () async {
    final auth = AuthRepository(
      api: FakeAuthApiForTransport(),
      tokenStore: MemoryTokenStore(),
    );
    await auth.signIn(identifier: 'customer', password: 'password');
    final api = RestAccountQueueApi(
      AuthenticatedApiClient(
        baseUrl: 'https://api.example.test',
        authRepository: auth,
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(jsonDecode(request.body), isEmpty);
          expect(request.headers['content-type'], contains('application/json'));
          expect(
            request.url.path,
            '/api/v1/account/queue/tickets/ticket-1/barcode',
          );
          expect(request.headers['authorization'], startsWith('Bearer '));
          expect(request.headers['cache-control'], 'no-store');
          return http.Response(
            jsonEncode({
              'barcodeToken': 'QB0123456789ABCDEF0123456789ABCDEF',
              'issuedAt': '2026-10-11T00:00:00Z',
              'expiresAt': '2026-10-11T00:02:00Z',
              'serverNow': '2026-10-11T00:00:30Z',
            }),
            200,
          );
        }),
      ),
    );
    final token = await api.loadTicketBarcode('ticket-1');
    expect(token.code, 'QB0123456789ABCDEF0123456789ABCDEF');
    expect(
      token.expiresAt.difference(token.serverNow),
      const Duration(seconds: 90),
    );
  });

  test(
    'rejects malformed and overlong validity responses and never calls Sandbox',
    () async {
      final auth = AuthRepository(
        api: FakeAuthApiForTransport(),
        tokenStore: MemoryTokenStore(),
      );
      await auth.signIn(identifier: 'customer', password: 'password');
      var response = <String, dynamic>{'barcodeToken': 'STATIC'};
      var calls = 0;
      final client = AuthenticatedApiClient(
        baseUrl: 'https://api.example.test',
        authRepository: auth,
        client: MockClient((_) async {
          calls++;
          return http.Response(jsonEncode(response), 200);
        }),
      );
      final api = RestAccountQueueApi(client);
      await expectLater(api.loadTicketBarcode('1'), throwsStateError);
      response = {
        'barcodeToken': 'QB0123456789ABCDEF0123456789ABCDEF',
        'issuedAt': '2026-10-11T00:00:00Z',
        'expiresAt': '2026-10-11T00:03:00Z',
        'serverNow': '2026-10-11T00:00:00Z',
      };
      await expectLater(api.loadTicketBarcode('1'), throwsStateError);
      await expectLater(
        RestAccountQueueApi(client, sandbox: true).loadTicketBarcode('1'),
        throwsStateError,
      );
      expect(calls, 2);
    },
  );
}
