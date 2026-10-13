import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:getprio_mobile/auth/auth_repository.dart';
import 'package:getprio_mobile/queue/auth_queue_api.dart';
import 'package:getprio_mobile/notifications/rest_notification_inbox_api.dart';

import 'queue_repository_test.dart' show FakeAuthApiForTransport;

void main() {
  test(
    'authenticated inbox paths preserve opaque cursor/cutoff and encode IDs',
    () async {
      final auth = AuthRepository(
        api: FakeAuthApiForTransport(),
        tokenStore: MemoryTokenStore(),
      );
      await auth.signIn(identifier: 'customer', password: 'password');
      final requests = <http.Request>[];
      final api = RestNotificationInboxApi(
        AuthenticatedApiClient(
          baseUrl: 'https://api.example.test',
          authRepository: auth,
          client: MockClient((request) async {
            requests.add(request);
            expect(request.headers['authorization'], startsWith('Bearer '));
            if (request.method == 'GET') {
              return http.Response(
                jsonEncode({
                  'notifications': [
                    {
                      'id': 'a/b',
                      'title': 'Ticket called',
                      'body': 'Proceed to vendor',
                      'createdAt': '2026-10-13T00:00:00Z',
                      'readAt': null,
                    },
                  ],
                  'unreadCount': 1,
                  'totalCount': 24,
                  'snapshotCutoff': 'opaque=+cutoff',
                  'nextCursor': 'opaque=+cursor',
                }),
                200,
              );
            }
            return http.Response('{"unreadCount":0}', 200);
          }),
        ),
      );
      final snapshot = await api.load(cursor: 'opaque=+cursor');
      expect(requests.single.url.path, '/api/v1/account/notifications');
      expect(requests.single.url.queryParameters['cursor'], 'opaque=+cursor');
      expect(snapshot.items.single.unread, isTrue);
      expect(snapshot.cutoff, 'opaque=+cutoff');
      expect(snapshot.totalCount, 24);
      await api.markRead(snapshot.items.single.id);
      await api.markAllRead(snapshot.cutoff);
      await api.clear(snapshot.cutoff);
      expect(requests[1].url.toString(), contains('/a%2Fb/read'));
      expect(requests[2].url.path, '/api/v1/account/notifications/read-all');
      expect(requests[3].url.path, '/api/v1/account/notifications/clear');
      expect(jsonDecode(requests[2].body), {'before': 'opaque=+cutoff'});
      expect(jsonDecode(requests[3].body), {'before': 'opaque=+cutoff'});
    },
  );
}
