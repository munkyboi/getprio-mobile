import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/form_validation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets('clear action removes text from an input', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    String? changedValue;
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: KeyboardAwareInput(
            child: TextField(
              key: const ValueKey('focused-clear-input-button-field'),
              controller: controller,
              focusNode: focusNode,
              onChanged: (value) => changedValue = value,
              features: const [focusedClearInputFeature],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final clearButton = find.byKey(
      const ValueKey('focused-clear-input-button'),
    );
    expect(clearButton, findsNothing);
    controller.text = 'typed value';
    await tester.pumpAndSettle();
    expect(clearButton, findsNothing);
    focusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isTrue);
    expect(clearButton, findsOneWidget);
    expect(
      find.descendant(of: find.byType(TextField), matching: clearButton),
      findsOneWidget,
    );
    await tester.tap(clearButton);
    expect(controller.text, isEmpty);
    expect(changedValue, isEmpty);
    await tester.pumpAndSettle();
    expect(clearButton, findsNothing);
  });

  testWidgets('password input uses a visibility toggle instead of clear', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'secret');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: TextField(
            controller: controller,
            obscureText: true,
            features: const [InputFeature.passwordToggle()],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.eye), findsOneWidget);
    expect(find.byIcon(LucideIcons.x), findsNothing);

    await tester.tap(find.byIcon(LucideIcons.eye));
    await tester.pumpAndSettle();
    expect(find.byIcon(LucideIcons.eyeOff), findsOneWidget);
    expect(controller.text, 'secret');
  });

  testWidgets('focused input is scrolled into view', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 900),
                KeyboardAwareInput(
                  child: TextField(
                    key: const Key('keyboard-aware-field'),
                    focusNode: focusNode,
                  ),
                ),
                const SizedBox(height: 500),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scrollable.position.pixels, 0);

    focusNode.requestFocus();
    await tester.pump();
    await tester.pump();

    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(0));

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    await tester.pumpAndSettle();
    final keyboardMediaQuery = tester.widget<MediaQuery>(
      find
          .byWidgetPredicate(
            (widget) =>
                widget is MediaQuery && widget.data.viewInsets.bottom > 0,
          )
          .first,
    );
    final keyboardTop =
        keyboardMediaQuery.data.size.height -
        keyboardMediaQuery.data.viewInsets.bottom;
    expect(
      tester.getRect(find.byKey(const Key('keyboard-aware-field'))).bottom,
      lessThanOrEqualTo(keyboardTop - 24),
    );
  });

  testWidgets('focused input can clear the keyboard boundary at content end', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      tester.view.resetViewInsets();
    });
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          resizeToAvoidBottomInset: true,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 700),
                KeyboardAwareInput(
                  child: TextField(
                    key: const Key('keyboard-end-field'),
                    focusNode: focusNode,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    focusNode.requestFocus();
    tester.view.viewInsets = const FakeViewPadding(bottom: 360);
    await tester.pump();
    await tester.pumpAndSettle();

    final keyboardTop = 844 - 360;
    expect(
      tester.getRect(find.byKey(const Key('keyboard-end-field'))).bottom,
      lessThanOrEqualTo(keyboardTop - 24),
    );
  });
}
