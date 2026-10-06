import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/directory/expandable_vendor_description.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets('expands descriptions that exceed three lines, even short text', (
    tester,
  ) async {
    const description = 'First line\nSecond line\nThird line\nFourth line';
    await tester.pumpWidget(
      const ShadcnApp(
        home: Scaffold(
          child: SizedBox(
            width: 300,
            child: ExpandableVendorDescription(description: description),
          ),
        ),
      ),
    );
    expect(tester.widget<Text>(find.text(description)).maxLines, 3);
    await tester.tap(find.text('Read more'));
    await tester.pump();
    expect(tester.widget<Text>(find.text(description)).maxLines, isNull);
    await tester.tap(find.text('Show less'));
    await tester.pump();
    expect(tester.widget<Text>(find.text(description)).maxLines, 3);
  });

  testWidgets('only offers expansion when text wraps beyond three lines', (
    tester,
  ) async {
    const description =
        'Friendly local service with helpful staff and convenient opening hours.';
    Future<void> showAtWidth(double width) async {
      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: Center(
              child: SizedBox(
                width: width,
                child: const ExpandableVendorDescription(
                  description: description,
                ),
              ),
            ),
          ),
        ),
      );
    }

    await showAtWidth(500);
    expect(find.text('Read more'), findsNothing);
    await showAtWidth(110);
    expect(find.text('Read more'), findsOneWidget);
  });
}
