import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:getprio_mobile/otp_input.dart';
import 'package:getprio_mobile/form_validation.dart';

void main() {
  testWidgets(
    'OTP accepts a full pasted/autofilled code and filters non-digits',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final completed = <String>[];
      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: SizedBox(
              width: 300,
              child: GetPrioOtpInput(
                controller: controller,
                onCompleted: completed.add,
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getCenter(find.byType(InputOTP)).dx,
        closeTo(tester.getCenter(find.byType(GetPrioOtpInput)).dx, 0.5),
      );
      await tester.enterText(
        find
            .descendant(
              of: find.byType(GetPrioOtpInput),
              matching: find.byType(EditableText),
            )
            .last,
        '123456',
      );
      await tester.pump();
      expect(controller.text, '123456');
      expect(completed, ['123456']);
      final display = tester.widget<InputOTP>(find.byType(InputOTP));
      expect(
        display.children.whereType<CharacterInputOTPChild>().every(
          (child) => child.obscured,
        ),
        isTrue,
      );
      final editorWidget = tester.widget<EditableText>(
        find
            .descendant(
              of: find.byType(GetPrioOtpInput),
              matching: find.byType(EditableText),
            )
            .last,
      );
      expect(editorWidget.obscureText, isTrue);
      expect(editorWidget.autofillHints, contains(AutofillHints.oneTimeCode));
      await tester.enterText(
        find
            .descendant(
              of: find.byType(GetPrioOtpInput),
              matching: find.byType(EditableText),
            )
            .last,
        'a12b345678',
      );
      await tester.pump();
      expect(controller.text, '123456');
      expect(completed, ['123456']); // Unchanged full code does not retry.
      controller.clear();
      await tester.pump();
      final editor = find
          .descendant(
            of: find.byType(GetPrioOtpInput),
            matching: find.byType(EditableText),
          )
          .last;
      await tester.enterText(editor, '65432');
      await tester.pump();
      expect(completed.length, 1);
      await tester.enterText(editor, '654321');
      await tester.pump();
      expect(completed, ['123456', '654321']);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'OTP supports editing, validation reset, disabled state and narrow widths',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = TextEditingController(text: '123456');
      final validation = FormValidation();
      addTearDown(controller.dispose);
      addTearDown(validation.dispose);
      Widget app(bool enabled) => ShadcnApp(
        home: Scaffold(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: GetPrioOtpInput(
              controller: controller,
              validation: validation,
              enabled: enabled,
            ),
          ),
        ),
      );
      await tester.pumpWidget(app(true));
      validation.setErrors({controller: 'Incorrect code'});
      await tester.pump();
      expect(find.text('Incorrect code'), findsOneWidget);
      await tester.enterText(
        find
            .descendant(
              of: find.byType(GetPrioOtpInput),
              matching: find.byType(EditableText),
            )
            .last,
        '12345',
      );
      await tester.pump();
      expect(controller.text, '12345');
      expect(find.text('Incorrect code'), findsNothing);
      await tester.pumpWidget(app(false));
      expect(
        tester
            .widget<TextField>(
              find
                  .descendant(
                    of: find.byType(GetPrioOtpInput),
                    matching: find.byType(TextField),
                  )
                  .last,
            )
            .enabled,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
