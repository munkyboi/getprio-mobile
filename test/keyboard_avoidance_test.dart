import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:getprio_mobile/keyboard_avoidance.dart';

void main() {
  testWidgets('unresized overlay reserves keyboard space for scrolling', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ShadcnApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(390, 844),
            viewInsets: EdgeInsets.only(bottom: 300),
          ),
          child: KeyboardAwareScrollView(
            padding: EdgeInsets.all(24),
            child: SizedBox(height: 900),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scroll = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    expect(scroll.padding, const EdgeInsets.fromLTRB(24, 24, 24, 324));
  });

  testWidgets(
    'resized screen keeps focus visible without duplicate keyboard padding',
    (tester) async {
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
              resizeToAvoidBottomInset: true,
              child: SizedBox(
                height: 600,
                child: KeyboardAwareScrollView(
                  reserveKeyboardSpace: false,
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

      final scroll = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(scroll.padding, const EdgeInsets.all(24));
      final field = find.byKey(const Key('keyboard-aware-field'));
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pump();
      await tester.pumpAndSettle();

      final fieldRect = tester.getRect(
        find.byKey(const Key('keyboard-aware-field')),
      );
      expect(fieldRect.bottom, lessThanOrEqualTo(844 - 300 - 24));
    },
  );
}
