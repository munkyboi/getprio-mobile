import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/account/ticket_repository.dart';
import 'package:getprio_mobile/main.dart';
import 'package:getprio_mobile/push/push_coordinator.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets(
    'pending developer ticket invitation opens the prompt after app startup',
    (tester) async {
      final api = _InvitationApi();

      await tester.pumpWidget(
        ShadcnApp(
          home: CustomerShell(
            ticketRepository: QueueTicketRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ticket-invitation-prompt')), findsOneWidget);
      expect(find.textContaining('Ticket #QUEUE-0001.'), findsOneWidget);
    },
  );

  testWidgets('developer ticket invitation push opens the invitation prompt', (
    tester,
  ) async {
    final api = _InvitationApi();
    api.includeInvitation = false;
    final pushSignal = ValueNotifier<PushSignal?>(null);
    addTearDown(pushSignal.dispose);

    await tester.pumpWidget(
      ShadcnApp(
        home: CustomerShell(
          ticketRepository: QueueTicketRepository(api),
          pushSignal: pushSignal,
        ),
      ),
    );
    await tester.pumpAndSettle();

    api.includeInvitation = true;
    pushSignal.value = const PushSignal(
      eventType: 'developer_ticket_invitation',
      notificationId: 'notification-1',
      ticketRef: 'invitation-1',
      route: 'tickets',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ticket-invitation-prompt')), findsOneWidget);
    expect(find.textContaining('Sandbox profile · Main queue'), findsOneWidget);
    expect(find.textContaining('Ticket #QUEUE-0001.'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('ticket-invitation-prompt')),
        matching: find.text('Not now'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ticket-invitation-prompt')), findsNothing);
    expect(find.byKey(const Key('ticket-invitations')), findsOneWidget);
  });

  testWidgets(
    'pending invitation is discovered while the app remains in the foreground',
    (tester) async {
      final api = _InvitationApi()..includeInvitation = false;

      await tester.pumpWidget(
        ShadcnApp(
          home: CustomerShell(
            ticketRepository: QueueTicketRepository(api),
          ),
        ),
      );
      await tester.pumpAndSettle();

      api.includeInvitation = true;
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ticket-invitation-prompt')), findsOneWidget);
      expect(find.textContaining('Ticket #QUEUE-0001.'), findsOneWidget);
    },
  );
}

class _InvitationApi implements AccountQueueApi, TicketInvitationApi {
  bool includeInvitation = true;

  @override
  Future<Map<String, dynamic>> loadHistory({
    required int page,
    required int limit,
  }) async => const {'items': []};

  @override
  Future<Map<String, dynamic>> loadOverview() async => const {
    'tickets': <Map<String, dynamic>>[],
  };

  @override
  Future<Map<String, dynamic>> loadInvitations() async => {
    'invitations': includeInvitation ? [_ticket()] : const [],
  };

  @override
  Future<Map<String, dynamic>> acceptInvitation(String ticketId) async => {
    'ticket': _ticket(),
  };

  Map<String, dynamic> _ticket() => {
    'id': 'invitation-1',
    'ticket_number': 'QUEUE-0001',
    'external_reference': 'visit-1',
    'verification_code': 'AB12CD34',
    'status': 'waiting',
    'profile': {
      'queue_name': 'Sandbox profile',
      'location_name': 'Main queue',
      'location_slug': 'main',
    },
    'issued_at': '2026-09-23T00:00:00Z',
    'updated_at': '2026-09-23T00:00:00Z',
  };
}
