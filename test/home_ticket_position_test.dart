import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/account/ticket_repository.dart';
import 'package:getprio_mobile/auth/auth_repository.dart';
import 'package:getprio_mobile/main.dart';
import 'package:getprio_mobile/queue/auth_queue_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'queue_repository_test.dart' show FakeAuthApiForTransport;

void main() {
  for (final position in [6, 2, 1, null]) {
    testWidgets('Home resolves missing overview position: $position', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = AuthRepository(
        api: FakeAuthApiForTransport(),
        tokenStore: MemoryTokenStore(),
      );
      await auth.signIn(identifier: 'customer', password: 'password');
      var snapshotCalls = 0;
      final repository = QueueTicketRepository(
        RestAccountQueueApi(
          AuthenticatedApiClient(
            baseUrl: 'https://api.example.test',
            authRepository: auth,
            client: MockClient((request) async {
              if (request.url.path == '/api/v1/account/overview') {
                return http.Response(
                  jsonEncode({
                    'tickets': [
                      {
                        'id': 'ticket-1',
                        'lookupCode': 'ABC123',
                        'ticketNumber': '101',
                        'status': 'waiting',
                        'tenantName': 'Clinic',
                        'tenantSlug': 'clinic',
                        'locationSlug': 'main',
                        'createdAt': DateTime(
                          2026,
                          9,
                          7,
                          14,
                          42,
                        ).toIso8601String(),
                      },
                    ],
                  }),
                  200,
                );
              }
              snapshotCalls++;
              expect(
                request.url.path,
                '/api/v1/public/tenant/clinic/location/main/queue',
              );
              expect(request.url.queryParameters['lookupCode'], 'ABC123');
              if (position == null) return http.Response('{}', 503);
              return http.Response(
                jsonEncode({
                  'focusTicket': {
                    'lookupCode': 'ABC123',
                    'status': 'waiting',
                    'position': position,
                    'estimatedWaitMinutes': 10,
                  },
                }),
                200,
              );
            }),
          ),
        ),
      );
      await tester.pumpWidget(
        ShadcnApp(home: HomePage(ticketRepository: repository)),
      );
      await tester.pumpAndSettle();
      expect(snapshotCalls, 1);
      expect(find.text('Clinic'), findsOneWidget);
      expect(find.text('2:42 PM'), findsOneWidget);
      expect(
        find.text(switch (position) {
          6 => 'There are 5 people in front of you',
          2 => 'There is 1 person in front of you',
          1 => 'There are 0 people in front of you',
          _ => 'Queue position is temporarily unavailable',
        }),
        findsOneWidget,
      );
      expect(find.text('Current ticket status'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
