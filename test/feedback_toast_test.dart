import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/feedback_toast.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets('shows feedback toast at the top of the screen', (tester) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: Builder(
          builder: (context) {
            return GestureDetector(
              onTap: () => showFeedbackToast(context, message: 'Saved.'),
              child: const Text('Show toast'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Show toast'));
    await tester.pump(const Duration(milliseconds: 500));

    final toast = find.text('Saved.');
    expect(toast, findsOneWidget);
    final logicalHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(tester.getCenter(toast).dy, lessThan(logicalHeight / 2));

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
