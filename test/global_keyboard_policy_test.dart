import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/app_theme.dart';
import 'package:getprio_mobile/form_validation.dart';
import 'package:getprio_mobile/keyboard_avoidance.dart';
import 'package:getprio_mobile/otp_input.dart';
import 'package:getprio_mobile/navigation/app_drawer.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets(
    'bottom drawer reserves keyboard once and keeps lower field visible',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ShadcnApp(
          builder: (_, child) => GetPrioTheme.wrap(child!),
          home: DrawerOverlay(
            child: Builder(
              builder: (context) => Scaffold(
                child: PrimaryButton(
                  child: const Text('Open drawer'),
                  onPressed: () => openAppDrawer<void>(
                    context: context,
                    position: OverlayPosition.bottom,
                    builder: (context) => SizedBox(
                      height: 600,
                      child: KeyboardAwareScrollView(
                        child: Column(
                          children: [
                            const SizedBox(height: 900),
                            KeyboardAwareInput(
                              child: TextField(
                                key: const Key('drawer-input'),
                                scrollPadding: inputScrollPadding,
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open drawer'));
      await tester.pumpAndSettle();
      final field = find.byKey(const Key('drawer-input'));
      await tester.ensureVisible(field);
      await tester.tap(field);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      final rect = tester.getRect(field);
      expect(rect.bottom, lessThanOrEqualTo(544));
      expect(544 - rect.bottom, lessThanOrEqualTo(80));
      expect(
        tester
            .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
            .padding,
        EdgeInsets.zero,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final kind in ['text', 'password', 'textarea', 'otp']) {
    testWidgets(
      '$kind dismisses on a touch outside without clearing its value',
      (tester) async {
        final controller = TextEditingController(
          text: kind == 'otp' ? '123' : 'Keep this value',
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          ShadcnApp(
            builder: (_, child) => GetPrioTheme.wrap(child!),
            home: Scaffold(
              child: Column(
                children: [
                  const SizedBox(height: 100),
                  if (kind == 'otp')
                    GetPrioOtpInput(controller: controller)
                  else if (kind == 'textarea')
                    TextArea(controller: controller)
                  else
                    TextField(
                      controller: controller,
                      obscureText: kind == 'password',
                    ),
                  const Expanded(child: SizedBox.expand()),
                ],
              ),
            ),
          ),
        );
        final editor = find.byWidgetPredicate(
          (widget) => widget is EditableText && !widget.readOnly,
        );
        await tester.tap(editor);
        await tester.pumpAndSettle();
        expect(tester.widget<EditableText>(editor).focusNode.hasFocus, isTrue);
        await tester.tapAt(const Offset(10, 50));
        await tester.pumpAndSettle();
        expect(tester.widget<EditableText>(editor).focusNode.hasFocus, isFalse);
        expect(controller.text, kind == 'otp' ? '123' : 'Keep this value');
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final resized in [true, false]) {
    testWidgets(
      '${resized ? 'screen' : 'overlay'} reveals input near keyboard without oversized spacer',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          ShadcnApp(
            builder: (_, child) => GetPrioTheme.wrap(child!),
            home: Scaffold(
              resizeToAvoidBottomInset: resized,
              child: KeyboardAwareScrollView(
                reserveKeyboardSpace: !resized,
                child: Column(
                  children: [
                    const SizedBox(height: 900),
                    KeyboardAwareInput(
                      child: TextField(
                        key: const Key('target'),
                        controller: controller,
                        scrollPadding: inputScrollPadding,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.ensureVisible(find.byKey(const Key('target')));
        await tester.tap(find.byKey(const Key('target')));
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        final editor = find.byWidgetPredicate(
          (widget) => widget is EditableText && !widget.readOnly,
        );
        final rect = tester.getRect(editor);
        expect(rect.bottom, lessThanOrEqualTo(544));
        expect(544 - rect.bottom, lessThanOrEqualTo(70));
        final position = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        final offset = position.pixels;
        for (var i = 0; i < 3; i++) {
          await tester.tap(editor);
          await tester.pumpAndSettle();
          expect(position.pixels, closeTo(offset, 1));
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
