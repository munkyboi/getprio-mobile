import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/app_theme.dart';
import 'package:getprio_mobile/onboarding/onboarding_gate.dart';
import 'package:getprio_mobile/onboarding/onboarding_page.dart';
import 'package:getprio_mobile/onboarding/onboarding_store.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/memory_onboarding_store.dart';

Widget gate(MemoryOnboardingStore store) => ShadcnApp(
  theme: GetPrioTheme.light(),
  home: GetPrioTheme.wrap(
    OnboardingGate(
      store: store,
      loading: const Text('Loading'),
      child: const Text('Sign in destination'),
    ),
  ),
);

void main() {
  testWidgets('fresh installation completes once and bypasses on next launch', (
    tester,
  ) async {
    final store = MemoryOnboardingStore();
    await tester.pumpWidget(gate(store));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('onboarding-title-0')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('onboarding-dot-mark-0'))),
      const Size(23, 5),
    );
    expect(
      tester.getSize(find.byKey(const Key('onboarding-dot-mark-1'))),
      const Size(5, 5),
    );
    expect(
      find.image(const AssetImage('assets/onboarding/reception-front.jpg')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('onboarding-title-1')), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('onboarding-pages')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(store.completed, isTrue);
    expect(store.writes, 1);
    expect(find.text('Sign in destination'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(gate(store));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsNothing);
    expect(find.text('Sign in destination'), findsOneWidget);
    // A new installation has no completion marker.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(gate(MemoryOnboardingStore()));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsOneWidget);
  });

  testWidgets('failed save retains final slide and permits retry', (
    tester,
  ) async {
    final store = MemoryOnboardingStore()..failWrite = true;
    await tester.pumpWidget(gate(store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-dot-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not save your progress. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Sign in destination'), findsNothing);
    store.failWrite = false;
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('Sign in destination'), findsOneWidget);
  });

  testWidgets('storage read failure can recover without skipping onboarding', (
    tester,
  ) async {
    final store = MemoryOnboardingStore()..failRead = true;
    await tester.pumpWidget(gate(store));
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    store.failRead = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsOneWidget);
  });

  for (final size in [
    const Size(320, 568),
    const Size(440, 956),
    const Size(1032, 1376),
    const Size(800, 400),
  ]) {
    testWidgets('all slides fit $size with enlarged text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ShadcnApp(
          theme: GetPrioTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: const TextScaler.linear(1.5),
            ),
            child: GetPrioTheme.wrap(OnboardingPage(onComplete: () async {})),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(Key('onboarding-dot-$i')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.getRect(find.byKey(const Key('onboarding-next'))).bottom,
          lessThanOrEqualTo(size.height),
        );
      }
    });
  }

  testWidgets('native store reads and writes installation marker channel', (
    tester,
  ) async {
    final methods = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      InstallationOnboardingStore.channel,
      (call) async {
        methods.add(call.method);
        return call.method == 'isComplete' ? false : null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        InstallationOnboardingStore.channel,
        null,
      ),
    );
    const store = InstallationOnboardingStore();
    expect(await store.isComplete(), isFalse);
    await store.complete();
    expect(methods, ['isComplete', 'complete']);
  });
}
