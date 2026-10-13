import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/auth/auth_repository.dart';
import 'package:getprio_mobile/main.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'auth_repository_test.dart' show FakeAuthApi;

void main() {
  for (final key in ['sign-in-identifier', 'sign-in-password']) {
    testWidgets('$key stays visible after repeated taps with keyboard open', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ShadcnApp(
          home: SignInPage(
            authRepository: AuthRepository(
              api: FakeAuthApi(),
              tokenStore: MemoryTokenStore(),
            ),
            onAuthenticated: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final field = find.byKey(Key(key));
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      final editable = find.descendant(
        of: field,
        matching: find.byType(EditableText),
      );
      expect(tester.getRect(editable).top, greaterThanOrEqualTo(0));
      expect(tester.getRect(editable).bottom, lessThanOrEqualTo(544));
      for (var tap = 0; tap < 3; tap++) {
        await tester.tap(editable);
        await tester.pumpAndSettle();
        final rect = tester.getRect(editable);
        expect(rect.top, greaterThanOrEqualTo(0), reason: 'tap ${tap + 2}');
        expect(rect.bottom, lessThanOrEqualTo(544), reason: 'tap ${tap + 2}');
      }
      await tester.enterText(
        editable,
        key == 'sign-in-password' ? 'sample password' : 'customer@example.com',
      );
      await tester.tap(editable);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(editable);
      await tester.pumpAndSettle();
      expect(tester.getRect(editable).top, greaterThanOrEqualTo(0));
      expect(tester.getRect(editable).bottom, lessThanOrEqualTo(544));
      tester.view.viewInsets = const FakeViewPadding();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
