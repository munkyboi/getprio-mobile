import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/main.dart';
import 'package:getprio_mobile/queue/queue_models.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets('keeps the ticket heading close to the app bar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
            'status': 'waiting',
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final appBarBottom = tester.getBottomLeft(find.byType(AppBar));
    final headingTop = tester.getTopLeft(find.text('Your queue ticket'));

    expect(headingTop.dy, closeTo(appBarBottom.dy + 28, 0.001));
  });
}
