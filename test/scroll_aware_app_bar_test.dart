import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/app_theme.dart';
import 'package:getprio_mobile/navigation/scroll_aware_app_bar.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets('app bar keeps a stable surface background while scrolling', (
    tester,
  ) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: ScrollNotificationObserver(
          child: Scaffold(
            headers: const [ScrollAwareAppBar(title: Text('Ticket details'))],
            child: ListView(
              key: const Key('scroll-aware-content'),
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

    AppBar appBar() => tester.widget<AppBar>(find.byType(AppBar));

    expect(appBar().backgroundColor, GetPrioTheme.paper);

    await tester.drag(
      find.byKey(const Key('scroll-aware-content')),
      const Offset(0, -160),
    );
    await tester.pumpAndSettle();

    expect(appBar().backgroundColor, GetPrioTheme.paper);
  });
}
