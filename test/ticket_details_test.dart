import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/details/ticket_barcode_viewer.dart';
import 'package:getprio_mobile/account/ticket_repository.dart';
import 'package:getprio_mobile/details/ticket_barcode_state.dart';
import 'package:getprio_mobile/auth/auth_models.dart';
import 'package:getprio_mobile/directory/directory_repository.dart';
import 'package:getprio_mobile/main.dart';
import 'package:getprio_mobile/queue/queue_models.dart';
import 'package:getprio_mobile/queue/queue_repository.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets('keeps confirmed ticket when refreshed snapshot omits it', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final ticket = QueueTicket.fromJson({
      'id': 'stable',
      'lookupCode': 'STABLE',
      'status': 'waiting',
      'tenantSlug': 'city-clinic',
    });
    final directory = _RetainedVendorRepository();
    final api = FakeQueueApi(
      snapshot: {
        'focusTicket': {
          'id': 'stable',
          'lookupCode': 'STABLE',
          'status': 'called',
          'customerConfirmedAt': '2026-10-12T00:00:00Z',
          'serviceStartedAt': '2026-10-12T00:01:00Z',
        },
      },
    );
    await tester.pumpWidget(
      ShadcnApp(
        home: TicketDetailsPage(
          ticket: ticket,
          queueRepository: QueueRepository(api),
          directoryRepository: directory,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ticket-qr-fab')), findsNothing);
    api.snapshot = {};
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ticket-qr-fab')), findsNothing);
    expect(directory.calls, 1);
    api.failure = true;
    await tester
        .widget<RefreshTrigger>(find.byKey(const Key('ticket-details-refresh')))
        .onRefresh!();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ticket-qr-fab')), findsNothing);
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ticket-qr-fab')), findsNothing);
  });

  testWidgets('idle ticket pauses and successful manual refresh resumes', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final ticket = QueueTicket.fromJson({
      'id': 'idle',
      'lookupCode': 'IDLE',
      'status': 'served',
      'tenantSlug': 'city-clinic',
    });
    final api = FakeQueueApi(snapshot: {});
    await tester.pumpWidget(
      ShadcnApp(
        home: TicketDetailsPage(
          ticket: ticket,
          queueRepository: QueueRepository(api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 5));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detail-auto-update-paused')), findsOneWidget);
    final calls = api.loadCalls;
    await tester.pump(const Duration(minutes: 1));
    expect(api.loadCalls, calls);
    api.failure = true;
    await tester.tap(find.text('Refresh and resume'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detail-auto-update-paused')), findsOneWidget);
    api.failure = false;
    await tester.tap(find.text('Refresh and resume'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detail-auto-update-paused')), findsNothing);
    final resumed = api.loadCalls;
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(api.loadCalls, resumed + 1);
    await tester.pumpWidget(const SizedBox());
  });

  test('actual wait formats whole hours and remaining minutes', () {
    for (final entry in {
      0: '0mins',
      1: '1min',
      59: '59mins',
      60: '1hr',
      80: '1hr 20mins',
      120: '2hrs',
      151: '2hrs 31mins',
    }.entries) {
      final joined = DateTime.utc(2026, 10, 11);
      final ticket = QueueTicket(
        id: 'history',
        lookupCode: 'HISTORY',
        ticketNumber: 'H001',
        customerName: 'Customer',
        status: TicketStatus.served,
        joinedAt: joined,
        serviceStartedAt: joined.add(Duration(minutes: entry.key)),
      );
      expect(ticket.actualWaitingTimeLabel, entry.value);
    }
  });

  testWidgets('served history shows actual wait without live stats or QR', (
    tester,
  ) async {
    final ticket = QueueTicket.fromJson({
      'id': 'history-1',
      'lookupCode': 'HISTORY',
      'ticketNumber': 'H001',
      'customerName': 'Test Customer',
      'vendorName': 'City Clinic',
      'locationName': 'Main location',
      'tenantSlug': 'city-clinic',
      'status': 'served',
      'serviceOutcome': 'completed',
      'joinedAt': '2026-10-11T01:00:00Z',
      'serviceStartedAt': '2026-10-11T02:20:00Z',
      'serviceEndedAt': '2026-10-11T03:00:00Z',
    });
    await tester.pumpWidget(
      ShadcnApp(
        home: TicketDetailsPage(
          ticket: ticket,
          queueRepository: QueueRepository(
            FakeQueueApi(
              snapshot: {
                'stats': {
                  'servedToday': 99,
                  'waitingCount': 6,
                  'estimatedWaitMinutes': 999,
                },
                'current': {'ticketNumber': 'LIVE001'},
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('This ticket has already been served.'), findsOneWidget);
    expect(find.text('Completed today'), findsNothing);
    expect(find.text('Currently serving LIVE001'), findsNothing);
    expect(find.text('Waiting now'), findsNothing);
    expect(find.text('Estimated wait'), findsNothing);
    expect(find.text('Total waiting time'), findsOneWidget);
    expect(find.text('1hr 20mins'), findsOneWidget);
    expect(find.byKey(const Key('ticket-qr-fab')), findsNothing);
    final joinedValue = find
        .byWidgetPredicate(
          (w) => w is Text && (w.data?.startsWith('2026-10-11,') ?? false),
        )
        .first;
    final waitValue = find.text('1hr 20mins');
    expect(tester.widget<Text>(joinedValue).textAlign, TextAlign.left);
    expect(tester.widget<Text>(joinedValue).style?.fontWeight, FontWeight.w600);
    expect(
      tester.getTopLeft(joinedValue).dx,
      closeTo(tester.getTopLeft(waitValue).dx, 1),
    );
    expect(tester.widget<Text>(waitValue).textAlign, TextAlign.left);
    expect(tester.widget<Text>(waitValue).style?.fontWeight, FontWeight.w600);
    expect(
      tester
          .widget<ListView>(find.byKey(const Key('ticket-details-page')))
          .padding,
      const EdgeInsets.fromLTRB(16, 12, 16, 20),
    );
    expect(
      tester.getTopLeft(find.text('H001')).dx,
      lessThan(tester.getTopLeft(find.text('Test Customer')).dx),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('ticket-heading-divider'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('ticket-customer-grid'))).dy,
      ),
    );

    expect(find.text('Your queue ticket'), findsNothing);
    final heading = find.byKey(const Key('ticket-vendor-heading'));
    expect(
      find.descendant(of: heading, matching: find.text('City Clinic')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: heading, matching: find.text('COMPLETED')),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text('Main location')).dy,
      greaterThan(tester.getTopLeft(heading).dy),
    );
    expect(
      tester.getTopLeft(find.text('Test Customer')).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('ticket-cutout-1'))).dy,
      ),
    );
    await tester.pumpWidget(const SizedBox());
  });

  test('actual wait never substitutes completion or confirmation for service start', () {
    for (final start in [null, '2026-10-11T00:59:00Z']) {
      final ticket = QueueTicket.fromJson({
        'status': 'served',
        'joinedAt': '2026-10-11T01:00:00Z',
        'customerConfirmedAt': '2026-10-11T01:10:00Z',
        'serviceStartedAt': start,
        'serviceEndedAt': '2026-10-11T03:00:00Z',
      });
      expect(ticket.actualWaitingTime, isNull);
    }
  });

  for (final status in ['cancelled', 'unserved', 'skipped', 'expired']) {
    testWidgets('$status history hides QR action', (tester) async {
      await tester.pumpWidget(
        ShadcnApp(
          home: TicketDetailsPage(
            ticket: QueueTicket.fromJson({
              'lookupCode': 'HISTORY',
              'status': status,
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ticket-qr-fab')), findsNothing);
      expect(find.text('Total waiting time'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('arrival confirmation closes QR dialog and hides its button', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final ticket = QueueTicket.fromJson({
      'id': 'active-1',
      'lookupCode': 'REFERENCE',
      'status': 'called',
      'tenantSlug': 'city-clinic',
    });
    final queueApi = FakeQueueApi(
      snapshot: {
        'focusTicket': {
          'id': 'active-1',
          'lookupCode': 'REFERENCE',
          'status': 'called',
        },
      },
    );
    await tester.pumpWidget(
      ShadcnApp(
        home: TicketDetailsPage(
          ticket: ticket,
          ticketRepository: QueueTicketRepository(FakeAccountQueueApi()),
          queueRepository: QueueRepository(queueApi),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('ticket-qr-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ticket-qr-fab')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<BrandedTicketQr>(find.byType(BrandedTicketQr)).code,
      'QB0123456789ABCDEF0123456789ABCDEF',
    );
    queueApi.snapshot = {
      'focusTicket': {
        'id': 'active-1',
        'lookupCode': 'REFERENCE',
        'status': 'called',
        'customerConfirmedAt': '2026-10-11T00:00:00Z',
      },
    };
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ticket-barcode-modal')), findsNothing);
    expect(find.byKey(const Key('ticket-qr-fab')), findsNothing);
    expect(find.byKey(const Key('ticket-barcode-countdown')), findsNothing);
    expect(find.byType(BrandedTicketQr), findsNothing);
  });

  testWidgets('QR issuance exists only while floating-button dialog is open', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final api = FakeAccountQueueApi();
    await tester.pumpWidget(
      ShadcnApp(
        home: TicketDetailsPage(
          ticket: QueueTicket.fromJson({
            'id': 'active-1',
            'lookupCode': 'REF',
            'status': 'waiting',
          }),
          ticketRepository: QueueTicketRepository(api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 3));
    expect(api.barcodeCalls, 0);
    expect(
      find.byKey(const Key('ticket-details-barcode-section')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('ticket-cutout-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ticket-qr-fab')));
    await tester.pumpAndSettle();
    expect(api.barcodeCalls, 1);
    await tester.tap(find.byKey(const Key('ticket-barcode-close')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 3));
    expect(api.barcodeCalls, 1);
    await tester.tap(find.byKey(const Key('ticket-qr-fab')));
    await tester.pumpAndSettle();
    expect(api.barcodeCalls, 2);
    await tester.tap(find.byKey(const Key('ticket-barcode-close')));
    await tester.pumpAndSettle();
  });

  testWidgets('polls service transitions without showing the called alert', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final api = FakeQueueApi(
      snapshot: {
        'focusTicket': {
          'id': 'service-1',
          'lookupCode': 'SERVICE1',
          'status': 'called',
          'serviceStartedAt': '2026-10-09T04:01:00Z',
        },
      },
    );
    await tester.pumpWidget(
      ShadcnApp(
        home: TicketDetailsPage(
          ticket: QueueTicket.fromJson({
            'id': 'service-1',
            'lookupCode': 'SERVICE1',
            'status': 'called',
            'tenantSlug': 'clinic',
          }),
          queueRepository: QueueRepository(api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('IN SERVICE'), findsOneWidget);
    expect(find.byKey(const Key('ticket-called-alert')), findsNothing);
    expect(find.text('Your service is in progress.'), findsOneWidget);
    api.snapshot = {
      'focusTicket': {
        'id': 'service-1',
        'lookupCode': 'SERVICE1',
        'status': 'unserved',
        'serviceStartedAt': '2026-10-09T04:01:00Z',
        'serviceEndedAt': '2026-10-09T04:10:00Z',
        'serviceOutcome': 'interrupted',
      },
    };
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    await tester.pump();
    expect(api.loadCalls, 2);
    await tester.pumpAndSettle();
    expect(find.text('INTERRUPTED'), findsOneWidget);
    expect(
      find.text(
        'Your service was interrupted. Contact the vendor about the next step.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('ticket-details-cancel')), findsNothing);
    await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
  });

  for (final completionSource in ['snapshot', 'account']) {
    testWidgets('thanks the customer after completion from $completionSource', (
      tester,
    ) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final waiting = <String, dynamic>{
        'id': 'active-1',
        'lookupCode': 'A0C18AF',
        'ticketNumber': 'AH002',
        'tenantSlug': 'city-clinic',
        'status': 'waiting',
      };
      final completed = <String, dynamic>{
        ...waiting,
        'status': 'served',
        'serviceOutcome': 'completed',
      };
      final accountApi = FakeAccountQueueApi();
      final queueApi = FakeQueueApi(
        snapshot: {
          'focusTicket': waiting,
          'stats': {'waitingCount': 5, 'servedToday': 8},
        },
      );
      await tester.pumpWidget(
        ShadcnApp(
          home: TicketDetailsPage(
            ticket: QueueTicket.fromJson(waiting),
            showJoinConfirmation: true,
            ticketRepository: QueueTicketRepository(accountApi),
            queueRepository: QueueRepository(queueApi),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('You are in the queue. Keep this ticket ready.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('ticket-join-success-notice')),
        findsOneWidget,
      );
      if (completionSource == 'snapshot') {
        queueApi.snapshot = {'focusTicket': completed};
      } else {
        // The live snapshot intentionally still contains the waiting ticket.
        accountApi.completedTicket = completed;
      }
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Thank you for your business! We hope to see you again soon.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('You are in the queue. Keep this ticket ready.'),
        findsNothing,
      );
      expect(find.text('Completed today'), findsNothing);
      expect(find.text('Waiting now'), findsNothing);
      expect(find.byKey(const Key('ticket-qr-fab')), findsNothing);
      expect(find.text('COMPLETED'), findsOneWidget);
      expect(find.text('You are in the queue'), findsNothing);
      expect(find.byKey(const Key('ticket-join-success-notice')), findsNothing);
      await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
    });
  }

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
    expect(find.byKey(const Key('ticket-qr-fab')), findsOneWidget);
    expect(
      find.byKey(const Key('ticket-details-barcode-section')),
      findsNothing,
    );
    await tester.ensureVisible(find.byKey(const Key('ticket-qr-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ticket-qr-fab')));
    await tester.pumpAndSettle();
    final enlarged = tester.widget<BrandedTicketQr>(
      find.byType(BrandedTicketQr),
    );
    expect(enlarged.code, 'QB0123456789ABCDEF0123456789ABCDEF');
    await tester.tap(find.byKey(const Key('ticket-barcode-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ticket-barcode-modal')), findsNothing);

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

    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('ticket-details-cancel'))),
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
    expect(find.text('3'), findsOneWidget);
    expect(find.text('15 mins'), findsOneWidget);
    expect(find.text('Currently serving AH004'), findsOneWidget);
  });

  testWidgets(
    'called alert is above the single ticket card and contains no queue metrics',
    (tester) async {
      await tester.pumpWidget(
        ShadcnApp(
          home: TicketDetailsPage(
            ticket: QueueTicket.fromJson({
              'id': 'called',
              'lookupCode': 'CALLED',
              'ticketNumber': 'A01',
              'tenantName': 'Clinic',
              'status': 'called',
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final alert = find.byKey(const Key('ticket-called-alert'));
      expect(
        find.descendant(of: alert, matching: find.byType(Text)),
        findsOneWidget,
      );
      expect(
        find.text('Your ticket was called. Proceed to the vendor.'),
        findsOneWidget,
      );
      expect(
        tester.getBottomLeft(alert).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('ticket-details-card'))).dy,
        ),
      );
      expect(find.byKey(const Key('ticket-details-card')), findsOneWidget);
      expect(find.byKey(const Key('ticket-qr-fab')), findsOneWidget);
      expect(find.byKey(const Key('ticket-barcode-unavailable')), findsNothing);
    },
  );
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
    expect(find.byKey(const Key('ticket-qr-fab')), findsNothing);
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
          sandbox: true,
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
    expect(find.byType(BrandedTicketQr), findsNothing);

    api.status = 'called';
    ticketRepository.requestRefresh();
    await tester.pumpAndSettle();

    expect(find.text('CALLED'), findsOneWidget);
    expect(
      find.text('Your ticket was called. Proceed to the vendor.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'shows a single selected ticket with the vendor cover and centered logo',
    (tester) async {
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
            directoryRepository: DirectoryRepository(
              _TicketCoverDirectoryApi(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ticket-details-page')), findsOneWidget);
      expect(find.byKey(const Key('ticket-details-card')), findsOneWidget);
      expect(find.byKey(const Key('detail-pass-hero')), findsOneWidget);
      expect(find.byKey(const Key('vendor-profile-cover')), findsOneWidget);
      expect(find.byKey(const Key('vendor-logo')), findsOneWidget);
      expect(
        find.byKey(const Key('profile-cover-surface-fade')),
        findsOneWidget,
      );
    },
  );
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

class FakeAccountQueueApi implements AccountQueueApi, TicketBarcodeApi {
  int barcodeCalls = 0;
  Map<String, dynamic>? completedTicket;
  @override
  Future<TicketBarcodeToken> loadTicketBarcode(String ticketId) async {
    barcodeCalls++;
    final now = DateTime.now().toUtc();
    return TicketBarcodeToken(
      code: 'QB0123456789ABCDEF0123456789ABCDEF',
      expiresAt: now.add(const Duration(minutes: 2)),
      serverNow: now,
    );
  }

  @override
  Future<Map<String, dynamic>> loadHistory({
    required int page,
    required int limit,
  }) async => {
    'tickets': [?completedTicket],
  };

  @override
  Future<Map<String, dynamic>> loadOverview() async => completedTicket != null
      ? const {'tickets': []}
      : const {
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
  bool failure = false;

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
    if (failure) throw StateError('429');
    return snapshot;
  }
}

class _RetainedVendorRepository extends DirectoryRepository {
  _RetainedVendorRepository() : super(_TicketCoverDirectoryApi());
  int calls = 0;
  @override
  Future<VendorSummary> loadVendor(String slug) async {
    calls++;
    if (calls > 1) throw StateError('rate limited');
    return super.loadVendor(slug);
  }
}
