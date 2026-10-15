import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:getprio_mobile/account/ticket_repository.dart';
import 'package:getprio_mobile/auth/auth_repository.dart';
import 'package:getprio_mobile/auth/auth_models.dart';
import 'package:getprio_mobile/main.dart';
import 'package:getprio_mobile/queue/auth_queue_api.dart';
import 'package:getprio_mobile/queue/queue_models.dart';
import 'package:getprio_mobile/queue/queue_repository.dart';

/// Supply a private --dart-define-from-file handoff; never production credentials.
/// This test only signs in and reads approved disposable customer-owned tickets.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const origin = String.fromEnvironment('LOCAL_TEST_API_BASE_URL');
  const identifier = String.fromEnvironment('LOCAL_TEST_IDENTIFIER');
  const password = String.fromEnvironment('LOCAL_TEST_PASSWORD');
  const ids = String.fromEnvironment('LOCAL_TEST_TICKET_IDS');

  testWidgets('Zero32 renders customer-owned lifecycle from the local API', (
    tester,
  ) async {
    final uri = Uri.parse(origin);
    // Keep acceptance on the explicitly approved USB link-local preview only.
    expect(uri.scheme, 'http');
    expect(uri.host, startsWith('169.254.'));
    expect(uri.port, 5007);
    expect(identifier, isNotEmpty);
    expect(password.isNotEmpty, isTrue);
    final allowedIds = ids.split(',').where((id) => id.isNotEmpty).toSet();
    expect(allowedIds, isNotEmpty);

    final auth = AuthRepository(
      api: RestAuthApi(baseUrl: origin),
      tokenStore: MemoryTokenStore(),
    );
    final session = await auth.signIn(
      identifier: identifier,
      password: password,
    );
    expect(session, isA<AuthenticatedSession>());
    final client = AuthenticatedApiClient(
      baseUrl: origin,
      authRepository: auth,
    );
    final repository = QueueTicketRepository(RestAccountQueueApi(client));
    final tickets = await repository.loadAllTickets();
    final owned = tickets
        .where((ticket) => allowedIds.contains(ticket.id))
        .toList();
    expect(owned.map((ticket) => ticket.id).toSet(), allowedIds);

    final list = await client.get(
      '/api/mobile/tickets',
      queryParameters: {'limit': '100'},
    );
    final rawList = (list['tickets'] as List).whereType<Map<String, dynamic>>();
    for (final ticket in owned) {
      expect(
        rawList.any(
          (raw) => '${raw['id']}' == ticket.id && raw['queue_lifecycle'] is Map,
        ),
        isTrue,
      );
      final detail = await client.get(
        '/api/mobile/tickets/${Uri.encodeComponent(ticket.id)}',
      );
      final raw = detail['ticket'] as Map<String, dynamic>;
      expect('${raw['id']}', ticket.id);
      final lifecycle = CustomerQueueLifecycle.fromJson(raw['queue_lifecycle']);
      expect(lifecycle?.state, ticket.queueLifecycle?.state);
      expect(lifecycle, isNotNull);
      expect((raw['queue_lifecycle'] as Map)['resourceWait'], isNull);

      await tester.pumpWidget(
        ShadcnApp(
          home: TicketDetailsPage(
            key: ValueKey(ticket.id),
            ticket: ticket,
            ticketRepository: repository,
            queueRepository: QueueRepository(RestQueueApi(client)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final label = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data?.toLowerCase() ==
                ticket.displayStatusLabel.toLowerCase(),
      );
      expect(label, findsWidgets);
      await tester.ensureVisible(label.first);
      await tester.pumpAndSettle();
      expect(
        tester
            .getRect(label.first)
            .overlaps(
              Offset.zero &
                  tester.view.physicalSize / tester.view.devicePixelRatio,
            ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Waiting for resources'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    }
  }, skip: origin.isEmpty);
}
