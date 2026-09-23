import 'package:flutter_test/flutter_test.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:getprio_mobile/account/ticket_repository.dart';
import 'package:getprio_mobile/auth/auth_models.dart';
import 'package:getprio_mobile/directory/directory_repository.dart';
import 'package:getprio_mobile/main.dart';
import 'package:getprio_mobile/queue/queue_models.dart';
import 'package:getprio_mobile/queue/queue_repository.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets('opens the active Home ticket in ticket details', (tester) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: CustomerShell(
          user: const AuthUser(
            id: 'user-1',
            email: 'customer@example.com',
            profileName: 'Profile name',
            displayName: 'Carlo',
          ),
          ticketRepository: QueueTicketRepository(FakeAccountQueueApi()),
          directoryRepository: FakeDirectoryRepository(),
          queueRepository: QueueRepository(
            FakeQueueApi(
              snapshot: {
                'focusTicket': {
                  'id': 'active-1',
                  'lookupCode': 'A0C18AF',
                  'ticketNumber': 'AH002',
                  'status': 'waiting',
                  'position': 2,
                  'estimatedWaitMinutes': 10,
                },
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-active-ticket-active-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ticket-details-page')), findsOneWidget);
    expect(find.text('Ticket details'), findsOneWidget);
    expect(find.text('AH002'), findsWidgets);
    expect(find.byKey(const Key('ticket-details-cancel')), findsOneWidget);
  });

  testWidgets('opens ticket details with a scannable barcode', (tester) async {
    final ticketRepository = QueueTicketRepository(FakeAccountQueueApi());
    final queueRepository = QueueRepository(
      FakeQueueApi(
        snapshot: {
          'queueDay': {'state': 'open', 'isClosed': false, 'isPaused': false},
          'queueIntake': {'state': 'open', 'stateLabel': 'Open'},
          'stats': {
            'waitingCount': 2,
            'estimatedWaitMinutes': 10,
            'servedToday': 4,
          },
          'current': {'ticketNumber': 'AH001'},
          'focusTicket': {
            'id': 'active-1',
            'lookupCode': 'A0C18AF',
            'ticketNumber': 'AH002',
            'customerName': 'Carlo Abella',
            'status': 'waiting',
            'position': 2,
            'estimatedWaitMinutes': 10,
            'queueLength': 4,
            'queueUpdatedAt': '2026-09-02T03:45:00Z',
            'joinedAt': '2026-09-02T03:42:00Z',
          },
        },
      ),
    );

    await tester.pumpWidget(
      ShadcnApp(
        home: TicketsPage(
          ticketRepository: ticketRepository,
          queueRepository: queueRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('active-ticket-active-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ticket-details-page')), findsOneWidget);
    expect(find.text('City Clinic'), findsOneWidget);
    expect(find.text('AH002'), findsWidgets);
    expect(find.text('WAITING'), findsOneWidget);
    expect(find.text('Position'), findsOneWidget);
    expect(find.text('#2'), findsOneWidget);
    expect(find.text('Estimated wait'), findsWidgets);
    expect(find.text('10 min'), findsWidgets);
    expect(find.text('Queue length'), findsOneWidget);
    expect(find.text('4 waiting'), findsOneWidget);
    expect(find.byKey(const Key('ticket-details-barcode')), findsOneWidget);
    expect(find.text('A0C18AF'), findsOneWidget);
    await tester.fling(
      find.byKey(const Key('ticket-details-page')),
      const Offset(0, -700),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.text('Waiting now'), findsOneWidget);
    expect(find.text('Completed today'), findsOneWidget);
    expect(find.text('Currently serving AH001'), findsOneWidget);
  });

  testWidgets('updates the open ticket after cancellation succeeds', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final waitingTicket = QueueTicket.fromJson({
      'id': 'active-1',
      'lookupCode': 'A0C18AF',
      'ticketNumber': 'AH002',
      'tenantName': 'City Clinic',
      'locationName': 'Main location',
      'status': 'waiting',
    });
    var cancelCalls = 0;

    await tester.pumpWidget(
      ShadcnApp(
        home: TicketDetailsPage(
          ticket: waitingTicket,
          onCancel: () async {
            cancelCalls++;
            await Future<void>.delayed(const Duration(milliseconds: 10));
            return QueueTicket(
              id: waitingTicket.id,
              lookupCode: waitingTicket.lookupCode,
              ticketNumber: waitingTicket.ticketNumber,
              customerName: waitingTicket.customerName,
              status: TicketStatus.cancelled,
              vendorName: waitingTicket.vendorName,
              locationName: waitingTicket.locationName,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ticket-details-cancel')));
    await tester.pump();
    expect(cancelCalls, 1);
    expect(find.text('Cancelling...'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('CANCELLED'), findsOneWidget);
    expect(find.byKey(const Key('ticket-details-cancel')), findsNothing);
  });

  testWidgets('shows friendly carry-over note and cancel action', (
    tester,
  ) async {
    final ticket = QueueTicket.fromJson({
      'id': 'carry-over-1',
      'lookupCode': 'CARRY01',
      'ticketNumber': 'AH008',
      'tenantName': 'City Clinic',
      'tenantSlug': 'city-clinic',
      'locationName': 'Main location',
      'status': 'pending_carry_over',
      'statusReason': 'queue_closed_carry_over_offered',
    });

    await tester.pumpWidget(
      ShadcnApp(
        home: TicketDetailsPage(
          ticket: ticket,
          onCancel: () async => QueueTicket(
            id: ticket.id,
            lookupCode: ticket.lookupCode,
            ticketNumber: ticket.ticketNumber,
            customerName: ticket.customerName,
            status: TicketStatus.cancelled,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    const note =
        'The queue closed before your turn. Your ticket was saved for the next eligible queue day.';
    expect(find.text(note), findsOneWidget);
    expect(tester.widget<Text>(find.text(note)).textAlign, TextAlign.left);
    expect(find.text('queue_closed_carry_over_offered'), findsNothing);
    expect(find.byKey(const Key('ticket-details-cancel')), findsOneWidget);
  });

  testWidgets('shows live queue status on vendor details', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ShadcnApp(
        home: VendorDetailPage(
          vendor: const VendorSummary(
            slug: 'city-clinic',
            name: 'City Clinic',
            queueAvailable: true,
            locations: [
              VendorLocation(
                id: 'main',
                slug: 'main',
                name: 'Main location',
                queueAvailable: true,
              ),
            ],
          ),
          repository: FakeDirectoryRepository(),
          queueRepository: QueueRepository(
            FakeQueueApi(
              snapshot: {
                'queueDay': {
                  'state': 'open',
                  'isClosed': false,
                  'isPaused': false,
                },
                'queueIntake': {'state': 'open', 'stateLabel': 'Open'},
                'stats': {
                  'waitingCount': 3,
                  'estimatedWaitMinutes': 15,
                  'servedToday': 6,
                },
                'current': {'ticketNumber': 'AH004'},
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vendor-queue-status-main')), findsOneWidget);
    expect(find.text('3 waiting'), findsOneWidget);
    expect(find.text('15 min estimated wait'), findsOneWidget);
    expect(find.text('Currently serving AH004'), findsOneWidget);
  });

  testWidgets('shows vendor confirmation when a ticket has been called', (
    tester,
  ) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: TicketDetailsPage(
          ticket: QueueTicket.fromJson({
            'id': 'called-1',
            'lookupCode': 'CALLED1',
            'ticketNumber': 'AH002',
            'tenantName': 'City Clinic',
            'tenantSlug': 'city-clinic',
            'locationName': 'Main location',
            'locationSlug': 'main',
            'status': 'called',
          }),
          queueRepository: QueueRepository(
            FakeQueueApi(
              snapshot: {
                'focusTicket': {
                  'id': 'called-1',
                  'lookupCode': 'CALLED1',
                  'ticketNumber': 'AH002',
                  'status': 'called',
                  'customerConfirmedAt': '2026-09-02T04:00:00Z',
                },
                'stats': {'waitingCount': 1, 'estimatedWaitMinutes': 5},
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CONFIRMED'), findsOneWidget);
    await tester.fling(
      find.byKey(const Key('ticket-details-page')),
      const Offset(0, -700),
      1000,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('ticket-details-queue-status')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Your arrival was confirmed'), findsOneWidget);
    expect(find.byKey(const Key('ticket-details-barcode')), findsOneWidget);
  });

  testWidgets('refreshes open ticket details when the repository signals', (
    tester,
  ) async {
    final ticketRepository = QueueTicketRepository(FakeAccountQueueApi());
    final queueApi = FakeQueueApi(
      snapshot: {
        'focusTicket': {
          'id': 'active-1',
          'lookupCode': 'A0C18AF',
          'ticketNumber': 'AH002',
          'tenantName': 'City Clinic',
          'tenantSlug': 'city-clinic',
          'locationName': 'Main location',
          'locationSlug': 'main',
          'status': 'waiting',
          'position': 2,
          'estimatedWaitMinutes': 10,
        },
      },
    );

    await tester.pumpWidget(
      ShadcnApp(
        home: TicketDetailsPage(
          ticket: QueueTicket.fromJson({
            'id': 'active-1',
            'lookupCode': 'A0C18AF',
            'ticketNumber': 'AH002',
            'tenantName': 'City Clinic',
            'tenantSlug': 'city-clinic',
            'locationName': 'Main location',
            'locationSlug': 'main',
            'status': 'waiting',
          }),
          ticketRepository: ticketRepository,
          queueRepository: QueueRepository(queueApi),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('WAITING'), findsOneWidget);
    queueApi.snapshot = {
      'focusTicket': {
        'id': 'active-1',
        'lookupCode': 'A0C18AF',
        'ticketNumber': 'AH002',
        'tenantName': 'City Clinic',
        'tenantSlug': 'city-clinic',
        'locationName': 'Main location',
        'locationSlug': 'main',
        'status': 'called',
      },
    };

    ticketRepository.requestRefresh();
    await tester.pumpAndSettle();

    expect(find.text('CALLED'), findsOneWidget);
    expect(
      find.text('Your ticket was called. Proceed to the vendor.'),
      findsOneWidget,
    );
    expect(queueApi.loadCalls, 2);
  });

  testWidgets('refreshes Sandbox ticket details from the account repository', (
    tester,
  ) async {
    final api = _ChangingSandboxAccountQueueApi();
    final ticketRepository = QueueTicketRepository(api);

    await tester.pumpWidget(
      ShadcnApp(
        home: TicketDetailsPage(
          ticket: QueueTicket.fromJson({
            'id': 'developer-ticket-1',
            'lookupCode': 'QUEUE1-0019',
            'ticketNumber': 'QUEUE1-0019',
            'verificationCode': 'VERIFY-0019',
            'vendorName': 'Sandbox profile',
            'locationName': 'Main location',
            'status': 'waiting',
          }),
          ticketRepository: ticketRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('WAITING'), findsOneWidget);
    final barcode = tester.widget<BarcodeWidget>(
      find.descendant(
        of: find.byKey(const Key('ticket-details-barcode')),
        matching: find.byType(BarcodeWidget),
      ),
    );
    expect(String.fromCharCodes(barcode.data), 'VERIFY-0019');
    expect(find.text('VERIFY-0019'), findsOneWidget);

    api.status = 'called';
    ticketRepository.requestRefresh();
    await tester.pumpAndSettle();

    expect(find.text('CALLED'), findsOneWidget);
    expect(
      find.text('Your ticket was called. Proceed to the vendor.'),
      findsOneWidget,
    );
  });

  testWidgets('restores the ticket details surface without a vendor hero', (
    tester,
  ) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: TicketDetailsPage(
          ticket: QueueTicket.fromJson({
            'id': 'active-1',
            'lookupCode': 'A0C18AF',
            'ticketNumber': 'AH002',
            'tenantName': 'City Clinic',
            'tenantSlug': 'city-clinic',
            'locationName': 'Main location',
            'locationSlug': 'main',
            'status': 'waiting',
          }),
          directoryRepository: DirectoryRepository(_TicketCoverDirectoryApi()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ticket-details-page')), findsOneWidget);
    expect(find.byKey(const Key('ticket-details-surface')), findsOneWidget);
    final surface = tester.widget<Container>(
      find.byKey(const Key('ticket-details-surface')),
    );
    expect((surface.decoration! as BoxDecoration).borderRadius, isNull);
    expect(find.byKey(const Key('ticket-details-profile-cover')), findsNothing);
    expect(find.byKey(const Key('profile-cover-surface-fade')), findsNothing);
  });
}

class FakeDirectoryRepository extends DirectoryRepository {
  FakeDirectoryRepository() : super(FakeDirectoryApi());
}

class FakeDirectoryApi implements DirectoryApi {
  @override
  Future<Map<String, dynamic>> loadVendor(String tenantSlug) async => const {
    'slug': 'city-clinic',
    'name': 'City Clinic',
    'queueAvailable': true,
    'locations': [
      {
        'id': 'main',
        'slug': 'main',
        'name': 'Main location',
        'queueAvailable': true,
      },
    ],
  };

  @override
  Future<Map<String, dynamic>> loadVendors({
    String? search,
    int limit = 20,
  }) async => const {'vendors': []};
}

class _TicketCoverDirectoryApi implements DirectoryApi {
  @override
  Future<Map<String, dynamic>> loadVendor(String tenantSlug) async => {
    'slug': tenantSlug,
    'name': 'City Clinic',
    'category': 'Clinic',
    'queueAvailable': true,
    'businessProfileTheme': {
      'theme': {
        'backgroundImageUrl': 'https://cdn.example.com/city-clinic-cover.webp',
        'backgroundImageFit': 'cover',
      },
    },
    'locations': [
      {
        'id': 'main',
        'name': 'Main location',
        'slug': 'main',
        'queueAvailable': true,
      },
    ],
  };

  @override
  Future<Map<String, dynamic>> loadVendors({
    String? search,
    int limit = 20,
  }) async => const {'vendors': []};
}

class FakeAccountQueueApi implements AccountQueueApi {
  @override
  Future<Map<String, dynamic>> loadHistory({
    required int page,
    required int limit,
  }) async => const {'tickets': []};

  @override
  Future<Map<String, dynamic>> loadOverview() async => const {
    'tickets': [
      {
        'id': 'active-1',
        'lookupCode': 'A0C18AF',
        'ticketNumber': 'AH002',
        'tenantName': 'City Clinic',
        'tenantSlug': 'city-clinic',
        'locationName': 'Main location',
        'locationSlug': 'main',
        'status': 'waiting',
        'createdAt': '2026-09-02T03:42:00Z',
      },
    ],
  };
}

class _ChangingSandboxAccountQueueApi implements AccountQueueApi {
  String status = 'waiting';

  @override
  Future<Map<String, dynamic>> loadHistory({
    required int page,
    required int limit,
  }) async => {
    'tickets': status == 'waiting'
        ? const <Map<String, dynamic>>[]
        : [_ticket()],
  };

  @override
  Future<Map<String, dynamic>> loadOverview() async => {
    'tickets': status == 'waiting'
        ? [_ticket()]
        : const <Map<String, dynamic>>[],
  };

  Map<String, dynamic> _ticket() => {
    'id': 'developer-ticket-1',
    'lookupCode': 'QUEUE1-0019',
    'ticketNumber': 'QUEUE1-0019',
    'verificationCode': 'VERIFY-0019',
    'vendorName': 'Sandbox profile',
    'locationName': 'Main location',
    'status': status,
  };
}

class FakeQueueApi implements QueueApi {
  FakeQueueApi({required this.snapshot});

  Map<String, dynamic> snapshot;
  int loadCalls = 0;

  @override
  Future<Map<String, dynamic>> cancelTicket({
    required String tenantSlug,
    required String lookupCode,
    String? locationSlug,
  }) async => const {};

  @override
  Future<Map<String, dynamic>> loadQueueSnapshot({
    required String tenantSlug,
    String? locationSlug,
    String? lookupCode,
  }) async {
    loadCalls++;
    return snapshot;
  }
}
