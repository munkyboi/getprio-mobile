import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/account/approved_vendor_store.dart';
import 'package:getprio_mobile/account/ticket_repository.dart';
import 'package:getprio_mobile/auth/auth_models.dart';
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
          home: CustomerShell(ticketRepository: QueueTicketRepository(api)),
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

  testWidgets('accepting an invitation can approve its vendor', (tester) async {
    final api = _InvitationApi();
    final store = MemoryApprovedVendorStore();
    const user = AuthUser(id: 'customer-1', email: 'customer@example.com');

    await tester.pumpWidget(
      ShadcnApp(
        home: CustomerShell(
          user: user,
          sandbox: true,
          approvedVendorStore: store,
          ticketRepository: QueueTicketRepository(api),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final checkbox = find.byKey(const Key('always-accept-ticket-invitations'));
    expect(checkbox, findsOneWidget);
    await tester.tap(checkbox);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('ticket-invitation-prompt')),
        matching: find.text('Accept ticket'),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.acceptedId, 'invitation-1');
    expect(await store.load(user.id), [
      const ApprovedVendor(
        key: 'name:sandbox profile',
        name: 'Sandbox profile',
      ),
    ]);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('invitation approval checkbox wraps within the prompt', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ShadcnApp(
        home: CustomerShell(
          user: const AuthUser(id: 'customer-1', email: 'customer@example.com'),
          sandbox: true,
          approvedVendorStore: MemoryApprovedVendorStore(),
          ticketRepository: QueueTicketRepository(_InvitationApi()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final promptRect = tester.getRect(
      find.byKey(const Key('ticket-invitation-prompt')),
    );
    final labelRect = tester.getRect(
      find.text('Always accept ticket invitations from this vendor'),
    );

    expect(labelRect.right, lessThanOrEqualTo(promptRect.right));
    expect(labelRect.height, greaterThan(20));
  });

  testWidgets('approved vendors auto-accept matching invitations', (
    tester,
  ) async {
    final api = _InvitationApi();
    final store = MemoryApprovedVendorStore();
    await store.add(
      'customer-1',
      const ApprovedVendor(
        key: 'name:sandbox profile',
        name: 'Sandbox profile',
      ),
    );

    await tester.pumpWidget(
      ShadcnApp(
        home: CustomerShell(
          user: const AuthUser(id: 'customer-1', email: 'customer@example.com'),
          sandbox: true,
          approvedVendorStore: store,
          ticketRepository: QueueTicketRepository(api),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.acceptedId, 'invitation-1');
    expect(find.byKey(const Key('ticket-invitation-prompt')), findsNothing);
  });

  testWidgets(
    'pending invitation is discovered while the app remains in the foreground',
    (tester) async {
      final api = _InvitationApi()..includeInvitation = false;

      await tester.pumpWidget(
        ShadcnApp(
          home: CustomerShell(ticketRepository: QueueTicketRepository(api)),
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
  String? acceptedId;

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
  Future<Map<String, dynamic>> acceptInvitation(String ticketId) async {
    acceptedId = ticketId;
    return {'ticket': _ticket()};
  }

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

class MemoryApprovedVendorStore implements ApprovedVendorStore {
  final Map<String, List<ApprovedVendor>> values = {};

  @override
  Future<List<ApprovedVendor>> load(String accountId) async => [
    ...values[accountId] ?? const <ApprovedVendor>[],
  ];

  @override
  Future<void> add(String accountId, ApprovedVendor vendor) async {
    final current = [...await load(accountId)];
    current.removeWhere((item) => item.key == vendor.key);
    current.add(vendor);
    values[accountId] = current;
  }

  @override
  Future<void> remove(String accountId, String vendorKey) async {
    values[accountId] = (await load(accountId))
        .where((item) => item.key != vendorKey)
        .toList(growable: false);
  }
}
