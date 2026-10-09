import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/account/ticket_repository.dart';
import 'package:getprio_mobile/auth/auth_repository.dart';
import 'package:getprio_mobile/main.dart';
import 'package:getprio_mobile/navigation/lists_overview.dart';
import 'package:getprio_mobile/queue/auth_queue_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'queue_repository_test.dart' show FakeAuthApiForTransport;

void main() {
  for (final source in ['canonical', 'unavailable', 'wrong ticket']) {
    test('called preview fallback safely handles $source snapshot', () async {
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
                        'status': 'called',
                        'tenantSlug': 'clinic',
                        if (source == 'canonical') ...{
                          'customerConfirmedAt': null,
                          'serviceStartedAt': null,
                          'serviceEndedAt': null,
                          'serviceOutcome': null,
                        },
                      },
                    ],
                  }),
                  200,
                );
              }
              snapshotCalls++;
              if (source == 'unavailable') return http.Response('{}', 503);
              return http.Response(
                jsonEncode({
                  'focusTicket': {
                    'lookupCode': 'OTHER',
                    'status': 'called',
                    'customerConfirmedAt': '2026-10-10T04:00:00Z',
                    'serviceStartedAt': '2026-10-10T04:01:00Z',
                  },
                }),
                200,
              );
            }),
          ),
        ),
      );
      final ticket = (await repository.loadOverview()).single;
      expect(ticket.displayStatusLabel, 'Called');
      expect(ticket.customerConfirmedAt, isNull);
      expect(ticket.serviceStartedAt, isNull);
      expect(snapshotCalls, source == 'canonical' ? 0 : 1);
    });
  }
  for (final label in ['CONFIRMED', 'IN SERVICE']) {
    for (final page in ['Home', 'Lists', 'Tickets']) {
      testWidgets('$page resolves $label from live called ticket snapshot', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
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
                          'status': 'called',
                          'tenantName': 'Clinic',
                          'tenantSlug': 'clinic',
                          'locationSlug': 'main',
                        },
                      ],
                    }),
                    200,
                  );
                }
                if (request.url.path == '/api/v1/account/history') {
                  return http.Response('{"items":[]}', 200);
                }
                snapshotCalls++;
                expect(
                  request.url.path,
                  '/api/v1/public/tenant/clinic/location/main/queue',
                );
                expect(request.url.queryParameters['lookupCode'], 'ABC123');
                return http.Response(
                  jsonEncode({
                    'focusTicket': {
                      'lookupCode': 'ABC123',
                      'status': 'called',
                      'customerConfirmedAt': '2026-10-10T04:00:00Z',
                      if (label == 'IN SERVICE')
                        'serviceStartedAt': '2026-10-10T04:01:00Z',
                    },
                  }),
                  200,
                );
              }),
            ),
          ),
        );
        await tester.pumpWidget(
          ShadcnApp(
            home: Scaffold(
              child: switch (page) {
                'Home' => HomePage(ticketRepository: repository),
                'Lists' => ListsOverview(
                  active: true,
                  ticketRepository: repository,
                ),
                _ => TicketsPage(ticketRepository: repository),
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(label), findsOneWidget);
        expect(find.text('CALLED'), findsNothing);
        expect(snapshotCalls, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
