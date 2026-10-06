import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/account/security_repository.dart';
import 'package:getprio_mobile/auth/auth_repository.dart';
import 'package:getprio_mobile/queue/auth_queue_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'queue_repository_test.dart' show FakeAuthApiForTransport;

void main() {
  test('accepts a server receipt and clears local session state', () async {
    final tokens = MemoryTokenStore();
    final auth = AuthRepository(
      api: FakeAuthApiForTransport(),
      tokenStore: tokens,
    );
    await auth.signIn(identifier: 'customer', password: 'password');
    final api = RestSecurityApi(
      AuthenticatedApiClient(
        baseUrl: 'https://api.example.test',
        authRepository: auth,
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/account/delete');
          expect(request.method, 'POST');
          expect(request.body, '{"password":"current"}');
          return http.Response(
            '{"status":"accepted","requestId":"request-1","dueAt":"2026-10-07T00:00:00Z"}',
            202,
          );
        }),
      ),
    );

    final receipt = await api.deleteAccount('current');

    expect(receipt.requestId, 'request-1');
    expect(await tokens.readRefreshToken(), isNull);
    expect(await auth.rememberedUserStore.read(), isNull);
  });

  test('rejects a response that is not an accepted deletion receipt', () async {
    final auth = AuthRepository(
      api: FakeAuthApiForTransport(),
      tokenStore: MemoryTokenStore(),
    );
    await auth.signIn(identifier: 'customer', password: 'password');
    final api = RestSecurityApi(
      AuthenticatedApiClient(
        baseUrl: 'https://api.example.test',
        authRepository: auth,
        client: MockClient((_) async => http.Response('{"deleted":true}', 202)),
      ),
    );

    await expectLater(api.deleteAccount('current'), throwsStateError);
    expect(auth.accessToken, isNotNull);
  });
}
