import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:barcode_widget/barcode_widget.dart';
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
      tester
          .widget<BarcodeWidget>(
            find.byKey(const Key('ticket-barcode-enlarged')),
          )
          .data,
      'TOKEN1'.codeUnits,
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
    expect(find.byType(BarcodeWidget), findsNothing);
    expect(find.byKey(const Key('ticket-barcode-retry')), findsNWidgets(2));
    await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
    state.dispose();
  });

  testWidgets(
    'large dark-on-white barcode blurs backdrop and restores on close',
    (tester) async {
      final brightness = TestBrightness();
      await openViewer(tester, brightness);
      expect(brightness.changes, [1]);
      final barcode = tester.widget<BarcodeWidget>(
        find.byKey(const Key('ticket-barcode-enlarged')),
      );
      expect(String.fromCharCodes(barcode.data), 'VERIFY123');
      expect(barcode.height, 160);
      expect(barcode.color, GetPrioTheme.ink);
      expect(barcode.backgroundColor, Colors.white);
      expect(
        tester.widget<BackdropFilter>(find.byType(BackdropFilter)).filter,
        isA<ImageFilter>(),
      );
      await tester.tap(find.byKey(const Key('ticket-barcode-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ticket-barcode-modal')), findsNothing);
      expect(brightness.resets, 1);
    },
  );

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
    await tester.tapAt(const Offset(5, 5));
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
    expect(find.text('VERIFY123'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('ticket-barcode-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ticket-barcode-modal')), findsNothing);
  });
}
