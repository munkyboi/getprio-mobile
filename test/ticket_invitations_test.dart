import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/account/ticket_repository.dart';
import 'package:getprio_mobile/main.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets('shows a pending ticket invitation and accepts it', (
    tester,
  ) async {
    final api = _InvitationApi();
    await tester.pumpWidget(
      ShadcnApp(
        home: TicketsPage(ticketRepository: QueueTicketRepository(api)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ticket-invitations')), findsOneWidget);
    expect(find.text('New ticket invitation'), findsOneWidget);
    expect(find.text('Sandbox profile'), findsOneWidget);
    expect(find.text('Main queue'), findsOneWidget);
    expect(find.text('Ticket #QUEUE-0001'), findsOneWidget);
    expect(
      find.byKey(const Key('accept-ticket-invitation-invitation-1')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('accept-ticket-invitation-invitation-1')),
    );
    await tester.pumpAndSettle();

    expect(api.acceptedId, 'invitation-1');
    expect(find.byKey(const Key('ticket-invitations')), findsNothing);
    expect(find.text('Ticket accepted.'), findsOneWidget);
    expect(find.text('#QUEUE-0001'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}

class _InvitationApi implements AccountQueueApi, TicketInvitationApi {
  bool accepted = false;
  String? acceptedId;

  @override
  Future<Map<String, dynamic>> loadHistory({
    required int page,
    required int limit,
  }) async => const {'items': []};

  @override
  Future<Map<String, dynamic>> loadOverview() async => {
    'tickets': accepted ? [_ticket()] : const <Map<String, dynamic>>[],
  };

  @override
  Future<Map<String, dynamic>> loadInvitations() async => {
    'invitations': accepted ? const [] : [_ticket()],
  };

  @override
  Future<Map<String, dynamic>> acceptInvitation(String ticketId) async {
    accepted = true;
    acceptedId = ticketId;
    return {'ticket': _ticket()};
  }

  Map<String, dynamic> _ticket() => {
    'id': 'invitation-1',
    'lookupCode': 'visit-1',
    'ticketNumber': 'QUEUE-0001',
    'vendorName': 'Sandbox profile',
    'locationName': 'Main queue',
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
  };
}
