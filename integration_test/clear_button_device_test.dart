import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/form_validation.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('clear button clears text on an iOS device', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: KeyboardAwareInput(
                child: TextField(
                  key: const ValueKey('device-clear-input'),
                  controller: controller,
                  focusNode: focusNode,
                  readOnly: true,
                  features: const [focusedClearInputFeature],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller.text = 'device value';
    focusNode.requestFocus();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const ValueKey('focused-clear-input-button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('focused-clear-input-button')));
    await tester.pumpAndSettle();
    expect(controller.text, isEmpty);
  });
}
