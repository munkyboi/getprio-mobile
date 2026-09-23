import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:getprio_mobile/keyboard_avoidance.dart';

void main() {
  testWidgets('keeps a focused field above the onscreen keyboard', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      tester.view.resetViewInsets();
    });
    await tester.pumpWidget(
      ShadcnApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            viewInsets: EdgeInsets.only(bottom: 300),
          ),
          child: Scaffold(
            child: SizedBox(
              height: 600,
              child: KeyboardAwareScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 900),
                    KeyboardAwareField(
                      builder: (context, focusNode) => TextField(
                        key: const Key('keyboard-aware-field'),
                        focusNode: focusNode,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final field = find.byKey(const Key('keyboard-aware-field'));
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pump();
    await tester.pumpAndSettle();

    final fieldRect = tester.getRect(
      find.byKey(const Key('keyboard-aware-field')),
    );
    expect(fieldRect.bottom, lessThanOrEqualTo(844 - 300 - 24));
  });
}
