import 'dart:async';

import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/app_theme.dart';
import 'package:getprio_mobile/details/ticket_barcode_viewer.dart';
import 'package:getprio_mobile/details/ticket_barcode_state.dart';
import 'package:getprio_mobile/queue/queue_models.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class TestBrightness implements BarcodeBrightness {
  final changes = <double>[];
  int resets = 0;
  bool existingOverride = false;
  bool fail = false;
  Completer<double>? gate;
  @override
  Future<double> get current async {
    if (fail) throw StateError('unavailable');
    return gate == null ? .35 : await gate!.future;
  }

  @override
  Future<bool> get hasOverride async => existingOverride;
  @override
  Future<void> set(double value) async => changes.add(value);
  @override
  Future<void> reset() async => resets++;
}

Future<void> openViewer(WidgetTester tester, TestBrightness brightness) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpWidget(
    ShadcnApp(
      theme: GetPrioTheme.light(),
      darkTheme: GetPrioTheme.dark(),
      themeMode: ThemeMode.dark,
      home: Builder(
        builder: (context) => GestureDetector(
          onTap: () => showGeneralDialog<void>(
            context: context,
            barrierDismissible: true,
            barrierLabel: 'Close barcode',
            pageBuilder: (_, _, _) =>
                TicketBarcodeViewer(code: 'VERIFY123', brightness: brightness),
          ),
          child: const Center(child: Text('Open')),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('card and enlarged viewer rotate and expire together', (
    tester,
  ) async {
    var now = DateTime.utc(2026);
    var calls = 0;
    var fail = false;
    final state = TicketBarcodeState(
      ticket: QueueTicket.fromJson({
        'id': '1',
        'lookupCode': 'REFERENCE',
        'status': 'waiting',
      }),
      now: () => now,
      load: (_) async {
        calls++;
        if (fail) throw StateError('offline');
        return TicketBarcodeToken(
          code: 'TOKEN$calls',
          serverNow: now,
          expiresAt: now.add(const Duration(minutes: 2)),
        );
      },
    );
    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: Column(
            children: [
              TicketBarcodeContent(state: state),
              Expanded(
                child: TicketBarcodeViewer(
                  code: 'UNUSED',
                  state: state,
                  brightness: TestBrightness(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<BrandedTicketQr>(find.byType(BrandedTicketQr).last).code,
      'TOKEN1',
    );
    expect(find.text('TOKEN1'), findsNWidgets(2));
    now = now.add(const Duration(minutes: 2));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('TOKEN2'), findsNWidgets(2));
    expect(find.text('TOKEN1'), findsNothing);
    fail = true;
    now = now.add(const Duration(minutes: 2));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(PrettyQrView), findsNothing);
    expect(find.byKey(const Key('ticket-barcode-retry')), findsNWidgets(2));
    await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
    state.dispose();
  });

  testWidgets('rotating QR stays square with quiet space on narrow phones', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.utc(2026);
    final state = TicketBarcodeState(
      ticket: QueueTicket.fromJson({
        'id': '1',
        'lookupCode': 'REF',
        'status': 'waiting',
      }),
      now: () => now,
      load: (_) async => TicketBarcodeToken(
        code: 'QB0123456789ABCDEF0123456789ABCDEF',
        serverNow: now,
        expiresAt: now.add(const Duration(minutes: 2)),
      ),
    );
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await tester.pumpWidget(
        ShadcnApp(
          theme: GetPrioTheme.light(),
          darkTheme: GetPrioTheme.dark(),
          themeMode: mode,
          home: Scaffold(
            child: Column(
              children: [
                TicketBarcodeContent(state: state),
                Expanded(
                  child: TicketBarcodeViewer(
                    code: '',
                    state: state,
                    brightness: TestBrightness(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PrettyQrView), findsNWidgets(2));
      expect(find.byKey(const Key('ticket-qr-brand')), findsNWidgets(2));
      for (final widget in tester.widgetList<BrandedTicketQr>(
        find.byType(BrandedTicketQr),
      )) {
        expect(widget.code, 'QB0123456789ABCDEF0123456789ABCDEF');
      }
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
    state.dispose();
  });

  testWidgets('large light QR dialog restores brightness on close', (
    tester,
  ) async {
    final brightness = TestBrightness();
    await openViewer(tester, brightness);
    expect(brightness.changes, [1]);
    expect(
      tester.widget<BrandedTicketQr>(find.byType(BrandedTicketQr)).code,
      'VERIFY123',
    );
    expect(find.byType(PrettyQrView), findsOneWidget);
    expect(find.byKey(const Key('ticket-qr-brand')), findsOneWidget);
    expect(
      tester
          .widget<ColoredBox>(find.byKey(const Key('ticket-barcode-modal')))
          .color,
      Colors.white,
    );
    await tester.tap(find.byKey(const Key('ticket-barcode-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ticket-barcode-modal')), findsNothing);
    expect(brightness.resets, 1);
  });

  testWidgets('background restores existing override and resume boosts again', (
    tester,
  ) async {
    final brightness = TestBrightness()..existingOverride = true;
    await openViewer(tester, brightness);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(brightness.changes, [1, .35]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(brightness.changes, [1, .35, 1]);
    await tester.tap(find.byKey(const Key('ticket-barcode-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ticket-barcode-modal')), findsNothing);
    expect(brightness.changes, [1, .35, 1, .35]);
    expect(brightness.resets, 0);
  });

  testWidgets(
    'closing during brightness read still restores after late boost',
    (tester) async {
      final brightness = TestBrightness()..gate = Completer<double>();
      await openViewer(tester, brightness);
      await tester.tap(find.byKey(const Key('ticket-barcode-close')));
      await tester.pumpAndSettle();
      brightness.gate!.complete(.35);
      await tester.pumpAndSettle();
      expect(brightness.changes, [1]);
      expect(brightness.resets, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('brightness failure keeps modal readable and dismissible', (
    tester,
  ) async {
    final brightness = TestBrightness()..fail = true;
    await openViewer(tester, brightness);
    expect(
      tester.widget<BrandedTicketQr>(find.byType(BrandedTicketQr)).code,
      'VERIFY123',
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('ticket-barcode-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ticket-barcode-modal')), findsNothing);
  });
}
