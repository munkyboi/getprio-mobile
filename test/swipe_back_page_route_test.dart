import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/navigation/swipe_back_page_route.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets('swiping right from the leading edge returns to the prior page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ShadcnApp(
        home: Builder(
          builder: (context) => Scaffold(
            child: Center(
              child: PrimaryButton(
                key: const Key('open-details'),
                onPressed: () => Navigator.of(context).push<void>(
                  SwipeBackPageRoute<void>(
                    builder: (context) => const Scaffold(
                      child: Center(child: Text('Details page')),
                    ),
                  ),
                ),
                child: const Text('Open details'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-details')));
    await tester.pumpAndSettle();
    expect(find.text('Details page'), findsOneWidget);

    await tester.dragFrom(const Offset(180, 320), const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(find.text('Details page'), findsOneWidget);

    await tester.dragFrom(const Offset(5, 320), const Offset(300, 0));
    await tester.pumpAndSettle();

    expect(find.text('Details page'), findsNothing);
    expect(find.text('Open details'), findsOneWidget);
  });
}
