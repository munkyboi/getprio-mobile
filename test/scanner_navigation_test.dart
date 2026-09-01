import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/auth/auth_models.dart';
import 'package:getprio_mobile/main.dart';
import 'package:getprio_mobile/queue/join_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets(
    'scanner back closes the join flow and returns to the launching tab',
    (tester) async {
      await _pumpScannerFlow(tester);

      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('explore-page')), findsOneWidget);

      await _openScanner(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(QrScannerPage),
          matching: find.byIcon(LucideIcons.arrowLeft),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(QrScannerPage), findsNothing);
      expect(find.byType(JoinPage), findsNothing);
      expect(find.byKey(const Key('explore-page')), findsOneWidget);
    },
  );

  testWidgets('successful scan keeps the join flow open for payload handling', (
    tester,
  ) async {
    await _pumpScannerFlow(tester);

    await _openScanner(tester);

    final scanner = tester.widget<MobileScanner>(find.byType(MobileScanner));
    scanner.onDetect!(
      const BarcodeCapture(
        barcodes: [
          Barcode(
            rawValue: 'https://app.getprio.test/join/acme/main?source=qr&id=123e4567-e89b-42d3-a456-426614174000',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(QrScannerPage), findsNothing);
    expect(find.byType(JoinPage), findsOneWidget);
    expect(find.text('Join a queue'), findsNothing);
    expect(
      find.text('Queue API is not configured for this build.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('join-rescan-button')), findsOneWidget);
  });

  testWidgets('explains how to recover when camera permission is denied', (
    tester,
  ) async {
    await _pumpScannerFlow(tester);
    await _openScanner(tester);

    final scannerFinder = find.byType(MobileScanner);
    final scanner = tester.widget<MobileScanner>(scannerFinder);
    expect(scanner.errorBuilder, isNotNull);

    final scannerContext = tester.element(scannerFinder);
    final errorState = scanner.errorBuilder!(
      scannerContext,
      const MobileScannerException(
        errorCode: MobileScannerErrorCode.permissionDenied,
      ),
    );
    final errorOverlay = OverlayEntry(
      builder: (context) => SizedBox.expand(child: errorState),
    );
    Overlay.of(scannerContext).insert(errorOverlay);
    await tester.pump();

    expect(find.byKey(const Key('scanner-camera-error')), findsOneWidget);
    expect(find.text('Camera access is off'), findsOneWidget);
    expect(find.textContaining('Settings'), findsOneWidget);
    expect(find.text('Go back'), findsOneWidget);

    await tester.tap(find.text('Go back'));
    if (errorOverlay.mounted) errorOverlay.remove();
    await tester.pumpAndSettle();

    expect(find.byType(QrScannerPage), findsNothing);
    expect(find.byType(JoinPage), findsNothing);
    expect(find.byKey(const Key('home-page')), findsOneWidget);
  });
}

Future<void> _pumpScannerFlow(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(375, 667));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ShadcnApp(
      home: const MediaQuery(
        data: MediaQueryData(size: Size(375, 667)),
        child: CustomerShell(
          user: AuthUser(
            id: 'user-1',
            email: 'customer@example.com',
            profileName: 'Customer',
          ),
          allowedHosts: {'app.getprio.test'},
        ),
      ),
    ),
  );
}

Future<void> _openScanner(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('join-queue-menu-action')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  expect(find.byType(QrScannerPage), findsOneWidget);
}
