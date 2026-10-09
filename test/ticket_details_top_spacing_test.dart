import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/main.dart';
import 'package:getprio_mobile/queue/queue_models.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets(
    'centers the title and places the vendor hero beneath the app bar',
    (tester) async {
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
      final heroTop = tester.getTopLeft(
        find.byKey(const Key('detail-pass-hero')),
      );
      final titleCenter = tester.getCenter(find.text('Ticket details'));
      final heroCenter = tester.getCenter(
        find.byKey(const Key('vendor-profile-cover')),
      );
      final logoCenter = tester.getCenter(find.byKey(const Key('vendor-logo')));
      expect(titleCenter.dx, closeTo(195, 1));
      expect(logoCenter, heroCenter);

      expect(heroTop.dy, closeTo(appBarBottom.dy + 13, 1));
    },
  );
}
