import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:getprio_mobile/account/ticket_repository.dart';
import 'package:getprio_mobile/auth/auth_repository.dart';
import 'package:getprio_mobile/queue/auth_queue_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:getprio_mobile/main.dart';
import 'package:getprio_mobile/queue/queue_models.dart';
import 'package:getprio_mobile/queue/ticket_list_row.dart';
import 'package:getprio_mobile/navigation/main_page_top_bar.dart';

import 'queue_repository_test.dart' show FakeAuthApiForTransport;

Map<String, dynamic> projected(String state, {String status = 'called'}) => {
  'id': 'customer-ticket',
  'lookupCode': 'TEST1234',
  'ticketNumber': 'TEST001',
  'status': status,
  'vendorName': 'Test vendor',
  'queueLifecycle': {'version': 1, 'state': state, 'resourceWait': null},
};

void main() {
  test(
    'served notification waits for unfinished service to actually end',
    () async {
      final api = _LifecycleAccountApi()..ticket = projected('called');
      final repository = QueueTicketRepository(api);
      await repository.loadOverview();
      api.ticket = {
        ...projected('in_service', status: 'served'),
        'serviceStartedAt': '2026-10-15T01:00:00Z',
      };
      await repository.loadOverview();
      expect(repository.servedTicket.value, isNull);
      api.ticket = {
        ...projected('terminal', status: 'served'),
        'serviceStartedAt': '2026-10-15T01:00:00Z',
        'serviceEndedAt': '2026-10-15T01:20:00Z',
        'serviceOutcome': 'completed',
      };
      await repository.loadOverview();
      expect(repository.servedTicket.value?.displayStatusLabel, 'Completed');
    },
  );

  test(
    'called raw status retains completed and interrupted outcome labels',
    () {
      for (final outcome in ['completed', 'interrupted']) {
        final ticket = QueueTicket.fromJson({
          ...projected('terminal'),
          'serviceOutcome': outcome,
        });
        expect(
          ticket.displayStatusLabel,
          outcome == 'completed' ? 'Completed' : 'Interrupted',
        );
        expect(ticket.isActive, isFalse);
      }
    },
  );

  testWidgets('unfinished service is not shown as served after queue closure', (
    tester,
  ) async {
    final ticket = QueueTicket.fromJson({
      ...projected('in_service', status: 'served'),
      'serviceStartedAt': '2026-10-15T01:00:00Z',
      'serviceEndedAt': null,
    });
    await tester.pumpWidget(ShadcnApp(home: TicketDetailsPage(ticket: ticket)));
    await tester.pumpAndSettle();
    expect(find.text('Your service is in progress.'), findsOneWidget);
    expect(find.text('This ticket has already been served.'), findsNothing);
    expect(find.textContaining('Thank you for your business'), findsNothing);
    expect(ticket.isActive, isFalse);
    expect(ticket.canBeCancelled, isFalse);
    expect(find.byKey(const Key('ticket-qr-fab')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  for (final source in [
    'account',
    'live fallback',
    'live terminal',
    'mobile',
  ]) {
    test('$source transport retains customer lifecycle', () async {
      final auth = AuthRepository(
        api: FakeAuthApiForTransport(),
        tokenStore: MemoryTokenStore(),
      );
      await auth.signIn(identifier: 'customer', password: 'password');
      final client = AuthenticatedApiClient(
        baseUrl: 'https://api.example.test',
        authRepository: auth,
        client: MockClient((request) async {
          expect(request.headers['authorization'], startsWith('Bearer '));
          if (source == 'mobile') {
            expect(request.url.path, '/api/v1/mobile/tickets');
            return http.Response(
              jsonEncode({
                'tickets': [
                  {
                    'id': 'customer-ticket',
                    'external_reference': 'TEST1234',
                    'status': 'called',
                    'service_started_at': '2026-10-15T01:00:00Z',
                    'queue_lifecycle': projected(
                      'in_service',
                    )['queueLifecycle'],
                  },
                ],
              }),
              200,
            );
          }
          if (request.url.path == '/api/v1/account/overview') {
            return http.Response(
              jsonEncode({
                'tickets': [
                  {
                    ...projected('called'),
                    'tenantSlug': 'clinic',
                    if (source == 'account') ...{
                      'serviceStartedAt': '2026-10-15T01:00:00Z',
                      'serviceEndedAt': null,
                      'serviceOutcome': null,
                      'customerConfirmedAt': null,
                      'queueLifecycle': projected(
                        'in_service',
                      )['queueLifecycle'],
                    },
                  },
                ],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'focusTicket': {
                ...projected(
                  source == 'live terminal' ? 'terminal' : 'in_service',
                ),
                if (source != 'live terminal')
                  'serviceStartedAt': '2026-10-15T01:00:00Z',
              },
            }),
            200,
          );
        }),
      );
      // Exercise the existing snake_case mobile-list adapter as well as main
      // account and live tracking envelopes, without adding endpoint access.
      final repository = QueueTicketRepository(
        RestAccountQueueApi(client, sandbox: source == 'mobile'),
      );
      final ticket = (await repository.loadOverview()).single;
      expect(
        ticket.queueLifecycle?.state,
        source == 'live terminal'
            ? CustomerQueueState.terminal
            : CustomerQueueState.inService,
      );
      expect(
        ticket.displayStatusLabel,
        source == 'live terminal' ? 'Closed' : 'In service',
      );
      // Presentation enrichment does not manufacture command eligibility.
      expect(ticket.needsArrival, source == 'live terminal');
    });
  }

  for (final entry in [
    ('waiting', 'waiting', 'Waiting', true),
    ('called', 'called', 'Called', true),
    ('pending_carry_over', 'pending_carry_over', 'Carried over', true),
    ('recovery', 'skipped', 'Skipped', false),
    ('terminal', 'served', 'Served', false),
    ('terminal', 'cancelled', 'Cancelled', false),
    ('terminal', 'unserved', 'Unserved', false),
    ('terminal', 'expired', 'Expired', false),
  ]) {
    test(
      '${entry.$1}/${entry.$2} preserves raw eligibility and projection',
      () {
        final ticket = QueueTicket.fromJson(
          projected(entry.$1, status: entry.$2),
        );
        expect(ticket.displayStatusLabel, entry.$3);
        expect(ticket.status, TicketStatus.parse(entry.$2));
        expect(ticket.isActive, entry.$4);
        expect(
          ticket.copyWith(vendorName: 'Renamed vendor').queueLifecycle?.state,
          ticket.queueLifecycle?.state,
        );
        expect(ticket.customerFriendlyStatusReason, isNull);
      },
    );
  }

  test(
    'unfinished service displays before terminal without changing eligibility',
    () {
      final ticket = QueueTicket.fromJson({
        ...projected('in_service', status: 'unserved'),
        'serviceStartedAt': '2026-10-15T01:00:00Z',
        'serviceEndedAt': null,
      });
      expect(ticket.displayStatusLabel, 'In service');
      expect(ticket.serviceMessage, 'Your service is in progress.');
      expect(ticket.status, TicketStatus.unserved);
      expect(ticket.isActive, isFalse);
      expect(ticket.canBeCancelled, isFalse);
      expect(ticket.needsArrival, isFalse);
    },
  );

  test('completed and interrupted outcomes retain their existing labels', () {
    for (final outcome in ['completed', 'interrupted']) {
      final ticket = QueueTicket.fromJson({
        ...projected(
          'terminal',
          status: outcome == 'completed' ? 'served' : 'unserved',
        ),
        'serviceStartedAt': '2026-10-15T01:00:00Z',
        'serviceEndedAt': '2026-10-15T01:20:00Z',
        'serviceOutcome': outcome,
      });
      expect(
        ticket.displayStatusLabel,
        outcome == 'completed' ? 'Completed' : 'Interrupted',
      );
      expect(ticket.isActive, isFalse);
    }
  });

  test(
    'absent malformed and unsupported projections preserve legacy behavior',
    () {
      for (final projection in [
        null,
        'waiting',
        {},
        {'version': 2, 'state': 'in_service'},
        {'version': 1.0, 'state': 'in_service'},
        {'version': 1, 'state': 'published'},
        {'version': 1, 'state': 'future_state'},
        {'version': 1, 'state': 'in_service'},
        {'version': 1, 'state': 'in_service', 'resourceWait': {}},
        {'version': 1, 'state': 'in_service', 'resourceWait': 'future_reason'},
      ]) {
        final ticket = QueueTicket.fromJson({
          ...projected('called'),
          'queueLifecycle': projection,
          'customerConfirmedAt': '2026-10-15T01:00:00Z',
        });
        expect(ticket.queueLifecycle, isNull);
        expect(ticket.displayStatusLabel, 'Confirmed');
        expect(ticket.isActive, isTrue);
        expect(ticket.needsArrival, isFalse);
      }
    },
  );

  testWidgets(
    'read-only in-service projection reaches row quickstats and details',
    (tester) async {
      final ticket = QueueTicket.fromJson({
        ...projected('in_service'),
        'serviceStartedAt': '2026-10-15T01:00:00Z',
        'customerConfirmedAt': '2026-10-15T00:59:00Z',
      });
      expect(ticketQuickstats(ticket), 'TEST001 · In service');
      await tester.pumpWidget(
        ShadcnApp(
          home: TicketListRow(ticket: ticket, onPressed: () {}),
        ),
      );
      expect(find.text('IN SERVICE'), findsOneWidget);
      await tester.pumpWidget(
        ShadcnApp(home: TicketDetailsPage(ticket: ticket)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Your service is in progress.'), findsOneWidget);
      expect(find.byKey(const Key('ticket-qr-fab')), findsNothing);
      expect(find.textContaining('Waiting for resources'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

class _LifecycleAccountApi implements AccountQueueApi {
  Map<String, dynamic> ticket = {};
  @override
  Future<Map<String, dynamic>> loadOverview() async => {
    'tickets': [ticket],
  };
  @override
  Future<Map<String, dynamic>> loadHistory({
    required int page,
    required int limit,
  }) async => {'tickets': []};
}
