import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/account/ticket_repository.dart';
import 'package:getprio_mobile/main.dart';
import 'package:getprio_mobile/app_theme.dart';
import 'package:getprio_mobile/push/push_coordinator.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'push_coordinator_test.dart' show FakeMessaging, FakePushRegistrationApi;

class _ServiceApi implements AccountQueueApi {
  Map<String, dynamic> ticket = {
    'id': 'service-1',
    'lookupCode': 'SERVICE1',
    'ticketNumber': '101',
    'status': 'called',
    'tenantName': 'Clinic',
    'tenantSlug': 'clinic',
    'customerConfirmedAt': '2026-10-10T04:00:00Z',
  };
  int calls = 0;

  @override
  Future<Map<String, dynamic>> loadOverview() async {
    calls++;
    return {
      'tickets': ticket['status'] == 'called' ? [ticket] : [],
    };
  }

  @override
  Future<Map<String, dynamic>> loadHistory({
    required int page,
    required int limit,
  }) async => {
    'items': ticket['status'] == 'called' ? [] : [ticket],
  };
}

void main() {
  for (final outcome in ['completed', 'interrupted']) {
    testWidgets(
      'service $outcome push refetches previews, details and history',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final api = _ServiceApi();
        final repository = QueueTicketRepository(api);
        final signal = ValueNotifier<PushSignal?>(null);
        addTearDown(signal.dispose);
        final messaging = FakeMessaging(
          permission: PushPermission.authorized,
          token: 'token',
        );
        final coordinator = PushCoordinator(
          messaging: messaging,
          api: FakePushRegistrationApi(),
          installationStore: MemoryInstallationStore('device'),
          platform: 'ios',
          appVersion: '1.0.0',
          locale: 'en-PH',
          onSignal: (next) async => signal.value = next,
        );
        addTearDown(coordinator.dispose);
        await coordinator.initialize();
        await tester.pumpWidget(
          ShadcnApp(
            theme: GetPrioTheme.light(),
            home: CustomerShell(
              ticketRepository: repository,
              pushSignal: signal,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('CONFIRMED'), findsOneWidget);

        Future<void> push(String event, String id) async {
          messaging.emitSignal({
            'eventType': 'customer_queue_service_$event',
            'notificationId': id, 'route': 'ticket', 'ticketRef': 'SERVICE1',
            // Untrusted status data must never replace the REST response.
            'status': 'served', 'serviceOutcome': 'completed',
          });
          await tester.pump();
          await coordinator.flush();
          await tester.pumpAndSettle();
        }

        final initialCalls = api.calls;
        await push('started', 'stale-notification');
        expect(api.calls, greaterThan(initialCalls));
        expect(find.text('CONFIRMED'), findsOneWidget);
        expect(find.text('IN SERVICE'), findsNothing);

        api.ticket = {
          ...api.ticket,
          'serviceStartedAt': '2026-10-10T04:01:00Z',
        };
        await push('started', 'start');
        expect(find.text('IN SERVICE'), findsOneWidget);
        await tester.tap(find.text('Lists').last);
        await tester.pumpAndSettle();
        expect(find.text('IN SERVICE'), findsOneWidget);
        final listsCalls = api.calls;
        await push('started', 'lists-refresh');
        expect(api.calls, greaterThan(listsCalls));
        expect(find.text('IN SERVICE'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('lists-tickets')));
        await tester.pumpAndSettle();
        expect(find.text('IN SERVICE'), findsOneWidget);
        final ticketCalls = api.calls;
        await push('started', 'tickets-refresh');
        expect(api.calls, greaterThan(ticketCalls));
        expect(find.text('IN SERVICE'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('active-ticket-service-1')));
        await tester.pumpAndSettle();
        expect(find.text('IN SERVICE'), findsOneWidget);

        api.ticket = {
          ...api.ticket,
          'status': outcome == 'completed' ? 'served' : 'unserved',
          'serviceEndedAt': '2026-10-10T04:10:00Z',
          'serviceOutcome': outcome,
        };
        await push(outcome, 'end');
        expect(find.text(outcome.toUpperCase()), findsOneWidget);
        expect(find.byKey(const Key('ticket-called-alert')), findsNothing);
        await tester.tap(find.bySemanticsLabel('Back').last);
        await tester.pumpAndSettle();
        expect(find.text('No active tickets'), findsOneWidget);
        await tester.tap(find.text('History'));
        await tester.pumpAndSettle();
        expect(find.text(outcome.toUpperCase()), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
