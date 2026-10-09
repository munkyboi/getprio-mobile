import 'package:flutter_test/flutter_test.dart';
import 'package:pinput/pinput.dart';
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
      await tester.enterText(find.byType(Pinput), '123456');
      await tester.pump();
      expect(controller.text, '123456');
      expect(completed, ['123456']);
      await tester.enterText(find.byType(Pinput), 'a12b345678');
      await tester.pump();
      expect(controller.text, '123456');
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
      await tester.enterText(find.byType(Pinput), '12345');
      await tester.pump();
      expect(controller.text, '12345');
      expect(find.text('Incorrect code'), findsNothing);
      await tester.pumpWidget(app(false));
      expect(tester.widget<Pinput>(find.byType(Pinput)).enabled, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
