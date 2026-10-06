import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/auth/auth_models.dart';
import 'package:getprio_mobile/main.dart';
import 'package:getprio_mobile/queue/join_repository.dart';
import 'package:getprio_mobile/queue/join_ui.dart';
import 'package:getprio_mobile/queue/queue_repository.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets('scanner back closes the join flow and returns to Home', (
    tester,
  ) async {
    await _pumpScannerFlow(tester);

    await _openScanner(tester);

    final joinFlowShell = find.byKey(const Key('join-flow-shell'));
    final gesture = await tester.startGesture(const Offset(5, 320));
    await gesture.moveBy(const Offset(120, 0));
    await tester.pump();
    expect(tester.getTopLeft(joinFlowShell).dx, greaterThan(0));
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.dragFrom(const Offset(5, 320), const Offset(300, 0));
    await tester.pumpAndSettle();

    expect(find.byType(QrScannerPage), findsNothing);
    expect(find.byType(JoinPage), findsNothing);
    expect(find.byKey(const Key('home-page')), findsOneWidget);
  });

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

  testWidgets('invalid scan shows artwork and fixed retry, then scans again', (
    tester,
  ) async {
    await _pumpScannerFlow(tester);
    await _openScanner(tester);
    final scanner = tester.widget<MobileScanner>(find.byType(MobileScanner));
    scanner.onDetect!(
      const BarcodeCapture(barcodes: [Barcode(rawValue: 'invalid-qr')]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scan to join'), findsOneWidget);
    expect(find.text('Uh-oh!'), findsOneWidget);
    expect(
      find.text('You seem to have scanned an invalid QR code.'),
      findsOneWidget,
    );
    expect(
      find.image(
        const AssetImage(
          'assets/illustrations/scan-invalid-qr-half-body-transparent-v3.png',
        ),
      ),
      findsOneWidget,
    );
    final retry = find.byKey(const Key('invalid-qr-retry-button'));
    expect(retry.hitTestable(), findsOneWidget);
    final retryPosition = tester.getTopLeft(retry);
    await tester.drag(find.text('Uh-oh!'), const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(retry), retryPosition);
    expect(tester.takeException(), isNull);

    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invalid-qr-scan-screen')), findsNothing);
    expect(find.byType(MobileScanner), findsOneWidget);
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
    expect(
      find.text('Queue API is not configured for this build.'),
      findsOneWidget,
    );
  });

  testWidgets('live vendor QR is shown as invalid without throwing', (
    tester,
  ) async {
    await _pumpScannerFlow(tester);
    await _openScanner(tester);
    final scanner = tester.widget<MobileScanner>(find.byType(MobileScanner));
    scanner.onDetect!(
      const BarcodeCapture(
        barcodes: [
          Barcode(rawValue: 'https://getprio.online/t/live-vendor-ticket'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('invalid-qr-scan-screen')), findsOneWidget);
    expect(
      find.text('You seem to have scanned an invalid QR code.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('successful join opens ticket details with a queue notice', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ShadcnApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(375, 667)),
          child: CustomerShell(
            user: const AuthUser(
              id: 'user-1',
              email: 'customer@example.com',
              profileName: 'Customer',
            ),
            allowedHosts: const {'app.getprio.test'},
            joinRepository: JoinRepository(_SuccessfulJoinApi()),
            queueRepository: QueueRepository(_JoinedTicketQueueApi()),
          ),
        ),
      ),
    );

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

    await tester.ensureVisible(find.text('Join queue'));
    await tester.tap(find.text('Join queue'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('join-flow-shell')), findsNothing);
    expect(find.byKey(const Key('ticket-details-page')), findsOneWidget);
    expect(find.byKey(const Key('ticket-join-success-notice')), findsOneWidget);
    expect(find.text('You are in the queue'), findsOneWidget);
    expect(find.text('AH005'), findsWidgets);
    expect(find.byKey(const Key('ticket-details-card')), findsOneWidget);
    expect(find.byKey(const Key('ticket-details-barcode')), findsOneWidget);
    expect(find.byKey(const Key('ticket-details-cancel')), findsOneWidget);
    await tester.fling(
      find.byKey(const Key('ticket-details-page')),
      const Offset(0, -500),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.text('4'), findsOneWidget);
    expect(find.text('20 min'), findsNWidgets(2));
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

class _SuccessfulJoinApi implements JoinApi {
  @override
  Future<Map<String, dynamic>> resolve(String locationQrId) async => {
    'locationQrId': locationQrId,
    'vendorName': 'Acme Clinic',
    'vendorSlug': 'acme',
    'locationName': 'Main clinic',
    'locationSlug': 'main',
    'joinable': true,
  };

  @override
  Future<Map<String, dynamic>> join({
    required String locationQrId,
    required String joinAttemptId,
    required String customerName,
  }) async => {
    'ticket': {
      'id': 'joined-1',
      'lookupCode': 'JOINED1',
      'ticketNumber': 'AH005',
      'status': 'waiting',
    },
    'snapshot': {
      'tenant': {'name': 'Acme Clinic', 'slug': 'acme'},
      'location': {'name': 'Main clinic', 'slug': 'main'},
      'focusTicket': {
        'id': 'joined-1',
        'lookupCode': 'JOINED1',
        'ticketNumber': 'AH005',
        'status': 'waiting',
        'position': 4,
        'estimatedWaitMinutes': 20,
        'joinedAt': '2026-09-02T05:05:00Z',
      },
    },
  };
}

class _JoinedTicketQueueApi implements QueueApi {
  @override
  Future<Map<String, dynamic>> cancelTicket({
    required String tenantSlug,
    required String lookupCode,
    String? locationSlug,
  }) async => const {};

  @override
  Future<Map<String, dynamic>> loadQueueSnapshot({
    required String tenantSlug,
    String? locationSlug,
    String? lookupCode,
  }) async => const {
    'stats': {'waitingCount': 4, 'estimatedWaitMinutes': 20},
  };
}
