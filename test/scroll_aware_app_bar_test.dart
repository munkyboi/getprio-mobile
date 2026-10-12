import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/navigation/scroll_aware_app_bar.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('transparent app bar title slides over 100px (dark $dark)', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        ShadcnApp(
          theme: ThemeData(
            colorScheme: dark ? ColorSchemes.darkZinc : ColorSchemes.lightZinc,
          ),
          home: ScrollNotificationObserver(
            child: Scaffold(
              headers: [
                ScrollAwareAppBar(
                  title: const Text('Ticket details'),
                  leading: [GetPrioBackButton(onPressed: () {})],
                ),
              ],
              child: ListView(
                controller: controller,
                children: [
                  for (var index = 0; index < 20; index++)
                    const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final title = find.text('Ticket details');
      final back = find.byType(GetPrioBackButton);
      final original = tester.getRect(title);
      final backRect = tester.getRect(back);
      expect(
        tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
        Colors.transparent,
      );
      controller.jumpTo(50);
      await tester.pump();
      expect(
        tester.getTopLeft(title).dy,
        closeTo(original.top - original.height / 2, .1),
      );
      expect(tester.getRect(back), backRect);
      controller.jumpTo(100);
      await tester.pump();
      expect(tester.getBottomLeft(title).dy, closeTo(original.top, .1));
      controller.jumpTo(200);
      await tester.pump();
      expect(tester.getBottomLeft(title).dy, closeTo(original.top, .1));
      controller.jumpTo(0);
      await tester.pump();
      expect(tester.getRect(title), original);
      expect(tester.getRect(back), backRect);
      expect(tester.takeException(), isNull);
    });
  }
}
