import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/account/ticket_repository.dart';
import 'package:getprio_mobile/main.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets(
    'Home swipes active tickets, navigates dots, and handles removal',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _TicketsApi();
      final repository = QueueTicketRepository(api);
      String? opened;
      await tester.pumpWidget(
        ShadcnApp(
          home: HomePage(
            ticketRepository: repository,
            onOpenTicketDetails: (ticket) => opened = ticket.id,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final carousel = find.byKey(const Key('home-active-ticket-carousel'));
      expect(carousel, findsOneWidget);
      expect(find.byKey(const Key('home-ticket-indicator-1')), findsOneWidget);
      await tester.drag(carousel, const Offset(-320, 0));
      await tester.pumpAndSettle();
      expect(find.text('#102').hitTestable(), findsOneWidget);
      await tester.tap(find.text('#102'));
      expect(opened, '2');
      await tester.tap(find.byKey(const Key('home-ticket-indicator-0')));
      await tester.pumpAndSettle();
      expect(find.text('#101').hitTestable(), findsOneWidget);
      api.count = 1;
      repository.requestRefresh();
      await tester.pumpAndSettle();
      expect(carousel, findsNothing);
      expect(find.byKey(const Key('home-ticket-indicator-0')), findsNothing);
      expect(find.text('#101'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _TicketsApi implements AccountQueueApi {
  int count = 2;
  @override
  Future<Map<String, dynamic>> loadOverview() async => {
    'tickets': List.generate(
      count,
      (index) => {
        'id': '${index + 1}',
        'lookupCode': 'code-$index',
        'ticketNumber': '${101 + index}',
        'status': 'waiting',
        'position': 6,
        'vendorName': 'Vendor ${index + 1}',
        'joinedAt': DateTime(2026, 9, 7, 14, 42).toIso8601String(),
        if (index == 1)
          'locationName': 'A longer location name for the second active ticket',
      },
    ),
  };
  @override
  Future<Map<String, dynamic>> loadHistory({
    required int page,
    required int limit,
  }) async => {'tickets': []};
}
