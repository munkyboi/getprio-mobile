import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/account/delete_account_dialog.dart';
import 'package:getprio_mobile/account/security_repository.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets('requires verification, submits once, and shows the receipt', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      ShadcnApp(
        home: Builder(
          builder: (context) => PrimaryButton(
            onPressed: () => showOverlay<void>(
              context,
              const DialogConfiguration(barrierDismissible: false),
              builder: (_) => DeleteAccountDialog(
                requiresPassword: () async => true,
                deleteAccount: (password) async {
                  calls++;
                  expect(password, 'current');
                  return AccountDeletionReceipt(
                    requestId: 'request-1',
                    dueAt: DateTime(2026, 10, 7),
                  );
                },
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-account-confirm')));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(
      find.text('Enter your current password to continue.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('delete-account-password')),
      'current',
    );
    await tester.tap(find.byKey(const Key('delete-account-confirm')));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.byKey(const Key('delete-account-accepted')), findsOneWidget);
    expect(find.textContaining('request-1'), findsOneWidget);
  });

  testWidgets('provider reauthentication has no password field', (
    tester,
  ) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: DeleteAccountDialog(
          requiresPassword: () async => false,
          deleteAccount: (_) async => AccountDeletionReceipt(
            requestId: 'request-2',
            dueAt: DateTime(2026, 10, 7),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('delete-account-password')), findsNothing);
    expect(
      find.textContaining('original Google, Facebook, or Apple account'),
      findsOneWidget,
    );
  });
}
