import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/details/ticket_barcode_state.dart';
import 'package:getprio_mobile/queue/queue_models.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

QueueTicket ticket({
  String status = 'waiting',
  String? confirmed,
  String? started,
  String? ended,
  String? outcome,
}) => QueueTicket.fromJson({
  'id': '1',
  'lookupCode': 'REFERENCE',
  'status': status,
  'customerConfirmedAt': confirmed,
  'serviceStartedAt': started,
  'serviceEndedAt': ended,
  'serviceOutcome': outcome,
});
TicketBarcodeToken token(DateTime now, String code) => TicketBarcodeToken(
  code: code,
  serverNow: now,
  expiresAt: now.add(const Duration(minutes: 2)),
);

void main() {
  testWidgets(
    'expires closed, rotates once, and prevents overlapping retries',
    (tester) async {
      var now = DateTime.utc(2026);
      var calls = 0;
      final pending = Completer<TicketBarcodeToken>();
      final state = TicketBarcodeState(
        ticket: ticket(),
        now: () => now,
        load: (_) {
          calls++;
          return calls == 1
              ? Future.value(token(now, 'FIRST'))
              : pending.future;
        },
      );
      await tester.pump();
      expect(state.code, 'FIRST');
      now = now.add(const Duration(seconds: 119));
      await tester.pump(const Duration(seconds: 1));
      expect(state.code, 'FIRST');
      expect(calls, 1);
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(state.code, isNull);
      expect(state.loading, isTrue);
      await state.refresh();
      expect(calls, 2);
      pending.complete(token(now, 'SECOND'));
      await tester.pump();
      expect(state.code, 'SECOND');
      expect(state.remaining, const Duration(minutes: 2));
      state.dispose();
    },
  );

  testWidgets(
    'offline expiry never falls back to fixed code and retry recovers',
    (tester) async {
      var now = DateTime.utc(2026);
      var fail = false;
      final state = TicketBarcodeState(
        ticket: ticket(),
        now: () => now,
        load: (_) async {
          if (fail) throw StateError('offline');
          return token(now, 'VALID');
        },
      );
      await tester.pump();
      fail = true;
      now = now.add(const Duration(minutes: 2));
      await tester.pump(const Duration(seconds: 1));
      expect(state.code, isNull);
      fail = false;
      await state.refresh();
      expect(state.code, 'VALID');
      state.dispose();
    },
  );

  testWidgets(
    'confirmation invalidates a pending response and stops rotation',
    (tester) async {
      final pending = Completer<TicketBarcodeToken>();
      var calls = 0;
      final state = TicketBarcodeState(
        ticket: ticket(status: 'called'),
        load: (_) {
          calls++;
          return pending.future;
        },
      );
      state.updateTicket(
        ticket(status: 'called', confirmed: '2026-01-01T00:00:00Z'),
      );
      pending.complete(token(DateTime.utc(2026), 'LATE'));
      await tester.pump();
      await tester.pump(const Duration(minutes: 3));
      expect(state.rotating, isFalse);
      expect(state.code, 'REFERENCE');
      expect(calls, 1);
      state.dispose();
    },
  );

  testWidgets(
    'terminal, confirmed, service and Sandbox tickets never issue tokens',
    (tester) async {
      for (final entry in [
        ticket(status: 'served'),
        ticket(status: 'cancelled'),
        ticket(confirmed: '2026-01-01T00:00:00Z'),
        ticket(started: '2026-01-01T00:00:00Z'),
        ticket(ended: '2026-01-01T00:00:00Z'),
        ticket(outcome: 'interrupted'),
      ]) {
        var calls = 0;
        final state = TicketBarcodeState(
          ticket: entry,
          load: (_) async {
            calls++;
            return token(DateTime.now(), 'UNUSED');
          },
        );
        await tester.pump();
        expect(state.rotating, isFalse);
        expect(calls, 0);
        state.dispose();
      }
      final state = TicketBarcodeState(
        ticket: ticket(),
        sandbox: true,
        load: (_) => throw StateError('must not load'),
      );
      expect(state.rotating, isFalse);
      state.dispose();
    },
  );

  testWidgets(
    'pause hides token and resume refetches; invalid lifetimes fail closed',
    (tester) async {
      var now = DateTime.utc(2026);
      var calls = 0;
      final state = TicketBarcodeState(
        ticket: ticket(),
        now: () => now,
        load: (_) async {
          calls++;
          return token(now, 'TOKEN$calls');
        },
      );
      await tester.pump();
      state.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(state.code, isNull);
      now = now.add(const Duration(minutes: 3));
      await tester.pump(const Duration(seconds: 1));
      expect(calls, 1);
      state.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(calls, 2);
      expect(state.code, 'TOKEN2');
      final invalid = TicketBarcodeState(
        ticket: ticket(),
        load: (_) async => TicketBarcodeToken(
          code: 'BAD',
          serverNow: now,
          expiresAt: now.add(const Duration(minutes: 3)),
        ),
      );
      await tester.pump();
      expect(invalid.code, isNull);
      invalid.dispose();
      state.dispose();
    },
  );
  testWidgets('OS sleep expires shared state even if monotonic time pauses', (
    tester,
  ) async {
    var monotonic = DateTime.utc(2026);
    var wall = monotonic;
    final pending = Completer<TicketBarcodeToken>();
    var calls = 0;
    final state = TicketBarcodeState(
      ticket: ticket(),
      now: () => monotonic,
      wallNow: () => wall,
      load: (_) =>
          ++calls == 1 ? Future.value(token(wall, 'FIRST')) : pending.future,
    );
    await tester.pump();
    wall = wall.add(const Duration(minutes: 3));
    expect(state.code, isNull);
    await tester.pump(const Duration(seconds: 1));
    expect(state.loading, isTrue);
    expect(state.code, isNull);
    pending.complete(token(wall, 'NEW'));
    await tester.pump();
    expect(state.code, 'NEW');
    state.dispose();
  });

  testWidgets('request latency uses wall time during paused monotonic sleep', (
    tester,
  ) async {
    final monotonic = DateTime.utc(2026);
    var wall = monotonic;
    final pending = Completer<TicketBarcodeToken>();
    final state = TicketBarcodeState(
      ticket: ticket(),
      now: () => monotonic,
      wallNow: () => wall,
      load: (_) => pending.future,
    );
    wall = wall.add(const Duration(seconds: 30));
    pending.complete(token(monotonic, 'TOKEN'));
    await tester.pump();
    expect(state.remaining, const Duration(seconds: 90));
    wall = wall.add(const Duration(seconds: 90));
    expect(state.code, isNull);
    state.dispose();
  });

  testWidgets('backward wall clock hides credential until new issuance', (
    tester,
  ) async {
    final monotonic = DateTime.utc(2026);
    var wall = monotonic;
    final pending = Completer<TicketBarcodeToken>();
    var calls = 0;
    final state = TicketBarcodeState(
      ticket: ticket(),
      now: () => monotonic,
      wallNow: () => wall,
      load: (_) =>
          ++calls == 1 ? Future.value(token(wall, 'OLD')) : pending.future,
    );
    await tester.pump();
    wall = wall.subtract(const Duration(seconds: 30));
    expect(state.code, isNull);
    await tester.pump(const Duration(seconds: 1));
    expect(state.code, isNull);
    pending.complete(token(wall, 'NEW'));
    await tester.pump();
    expect(state.code, 'NEW');
    state.dispose();
  });

  testWidgets('backward clock during issuance rejects late credential', (
    tester,
  ) async {
    final monotonic = DateTime.utc(2026);
    var wall = monotonic;
    final pending = Completer<TicketBarcodeToken>();
    final state = TicketBarcodeState(
      ticket: ticket(),
      now: () => monotonic,
      wallNow: () => wall,
      load: (_) => pending.future,
    );
    wall = wall.subtract(const Duration(seconds: 30));
    pending.complete(token(monotonic, 'OLD'));
    await tester.pump();
    expect(state.code, isNull);
    state.dispose();
  });
}
