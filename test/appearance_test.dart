import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/appearance.dart';
import 'package:getprio_mobile/app_theme.dart';
import 'package:getprio_mobile/auth/auth_repository.dart';
import 'package:getprio_mobile/bookings/booking_list_row.dart';
import 'package:getprio_mobile/bookings/booking_repository.dart';
import 'package:getprio_mobile/main.dart';
import 'package:getprio_mobile/navigation/pass_list_row.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/memory_onboarding_store.dart';

class MemoryAppearanceStore implements AppearanceStore {
  String? value;
  bool fail = false;
  Completer<String?>? readGate;
  @override
  Future<String?> read() async =>
      readGate == null ? value : await readGate!.future;
  @override
  Future<void> write(String mode) async {
    if (fail) throw StateError('offline');
    value = mode;
  }
}

class UnusedAuthApi implements AuthApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  test('restores modes, rejects invalid values and preserves selection on save failure', () async {
    final store = MemoryAppearanceStore();
    final controller = AppearanceController(store: store);
    addTearDown(controller.dispose);
    await controller.load();
    expect(controller.mode, ThemeMode.system);
    for (final mode in [ThemeMode.light, ThemeMode.dark, ThemeMode.system]) {
      await controller.select(mode);
      expect(store.value, mode.name);
      final restored = AppearanceController(store: store);
      await restored.load();
      expect(restored.mode, mode);
      restored.dispose();
    }
    store.value = 'invalid';
    await controller.load();
    expect(controller.mode, ThemeMode.system);
    store.fail = true;
    await controller.select(ThemeMode.dark);
    expect(controller.mode, ThemeMode.system);
    expect(controller.error, isNotNull);
    store.fail = false;
    await controller.select(ThemeMode.dark);
    expect(controller.mode, ThemeMode.dark);
    expect(controller.error, isNull);
  });

  test('late preference read cannot overwrite a new selection', () async {
    final store = MemoryAppearanceStore()..readGate = Completer<String?>();
    final controller = AppearanceController(store: store);
    addTearDown(controller.dispose);
    final loading = controller.load();
    await controller.select(ThemeMode.system);
    store.readGate!.complete('dark');
    await loading;
    expect(controller.mode, ThemeMode.system);
    expect(store.value, 'system');
  });

  testWidgets(
    'app follows platform brightness and explicit modes without resetting navigation',
    (tester) async {
      final controller = AppearanceController(store: MemoryAppearanceStore());
      addTearDown(controller.dispose);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(
        GetPrioApp(
          appearanceController: controller,
          onboardingStore: MemoryOnboardingStore(completed: true),
          authRepository: AuthRepository(
            api: UnusedAuthApi(),
            tokenStore: MemoryTokenStore(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Color background() =>
          Theme.of(tester.element(find.text('Email or username')))
              .colorScheme
              .background;
      expect(background(), GetPrioPalette(true).paper);
      expect(
        (tester
                    .widget<Image>(
                      find.byWidgetPredicate(
                        (w) =>
                            w is Image &&
                            w.semanticLabel ==
                                'GetPrio customers waiting and checking in',
                      ),
                    )
                    .image
                as AssetImage)
            .assetName,
        'assets/branding/login-biometric-scene-dark.png',
      );
      await tester.enterText(find.byType(TextField).first, 'saved@example.com');
      await controller.select(ThemeMode.light);
      await tester.pumpAndSettle();
      expect(background(), GetPrioTheme.paper);
      expect(
        (tester
                    .widget<Image>(
                      find.byWidgetPredicate(
                        (w) =>
                            w is Image &&
                            w.semanticLabel ==
                                'GetPrio customers waiting and checking in',
                      ),
                    )
                    .image
                as AssetImage)
            .assetName,
        'assets/branding/login-biometric-scene.png',
      );
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await controller.select(ThemeMode.dark);
      await tester.pumpAndSettle();
      expect(background(), GetPrioPalette(true).paper);
      await controller.select(ThemeMode.system);
      await tester.pumpAndSettle();
      expect(background(), GetPrioTheme.paper);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(background(), GetPrioPalette(true).paper);
      expect(find.text('Email or username'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'saved@example.com',
      );
    },
  );

  testWidgets(
    'Profile opens appearance sheet, selects modes and keeps sheet open',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = MemoryAppearanceStore();
      final controller = AppearanceController(store: store);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        AppearanceHost(
          controller: controller,
          builder: (mode) => ShadcnApp(
            theme: GetPrioTheme.light(),
            darkTheme: GetPrioTheme.dark(),
            themeMode: mode,
            home: const AccountPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('profile-appearance')),
        200,
      );
      await tester.tap(find.byKey(const Key('profile-appearance')));
      await tester.pumpAndSettle();
      for (final mode in [ThemeMode.dark, ThemeMode.light, ThemeMode.system]) {
        await tester.tap(find.byKey(ValueKey('appearance-${mode.name}')));
        await tester.pumpAndSettle();
        expect(controller.mode, mode);
        expect(store.value, mode.name);
        if (mode != ThemeMode.system) {
          expect(
            Theme.of(tester.element(find.byKey(const Key('appearance-sheet'))))
                .colorScheme
                .brightness,
            mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
          );
        }
        expect(find.byKey(const Key('appearance-sheet')), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('appearance-sheet')), findsNothing);
      expect(find.byKey(const Key('account-page')), findsOneWidget);
    },
  );

  testWidgets(
    'booking row shares ticket layout and its whitespace and edges are tappable in dark mode',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var taps = 0;
      await tester.pumpWidget(
        ShadcnApp(
          theme: GetPrioTheme.light(),
          darkTheme: GetPrioTheme.dark(),
          themeMode: ThemeMode.dark,
          home: Scaffold(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  BookingListRow(
                    booking: CustomerBooking({
                      'id': '1',
                      'reference': 'BKG-12345678',
                      'tenantName':
                          'A long vendor name that wraps on small phones',
                      'locationName': 'Main location',
                      'serviceName': 'Haircut',
                      'status': 'confirmed',
                      'paymentStatus': 'unpaid',
                      'scheduledStartAt': '2026-10-10T12:00:00Z',
                    }),
                    onPressed: () => taps++,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final row = find.byType(PassListRow);
      final bounds = tester.getRect(row);
      await tester.tapAt(Offset(bounds.left + 2, bounds.center.dy));
      await tester.pumpAndSettle();
      await tester.tapAt(Offset(bounds.right - 2, bounds.bottom - 2));
      await tester.pump();
      expect(taps, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
