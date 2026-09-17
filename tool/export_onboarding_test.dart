// Run with: flutter test tool/export_onboarding_test.dart --run-skipped
// Renders the production widgets, with a real sans-serif font instead of Ahem.
import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/app_theme.dart';
import 'package:getprio_mobile/onboarding/onboarding_page.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets('export production onboarding slides', (tester) async {
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = true);
    final fontPath =
        Platform.environment['GETPRIO_SCREENSHOT_FONT'] ??
        '/System/Library/Fonts/SFNS.ttf';
    final font = File(fontPath).readAsBytesSync();
    final loader = FontLoader(GetPrioTypography.uiFontFamily)
      ..addFont(Future.value(ByteData.sublistView(font)));
    await tester.runAsync(() async {
      await loader.load();
      final packaged = FontLoader('packages/shadcn_flutter/Inter')
        ..addFont(Future.value(ByteData.sublistView(font)));
      await packaged.load();
      final manifest = jsonDecode(
        await rootBundle.loadString('FontManifest.json'),
      ) as List<dynamic>;
      for (final family in manifest) {
        final fontLoader = FontLoader(family['family'] as String);
        for (final entry in family['fonts'] as List<dynamic>) {
          fontLoader.addFont(rootBundle.load(entry['asset'] as String));
        }
        await fontLoader.load();
      }
    });
    final destination = Directory(
      Platform.environment['GETPRIO_SCREENSHOT_DIR'] ??
          '/Users/carloabella/Projects/getprio/_materials/onboarding-slides',
    );
    destination.createSync(recursive: true);
    final boundaryKey = GlobalKey();
    for (final device in [
      (name: 'iphone-6.9', size: const Size(440, 956), ratio: 3.0),
      (name: 'ipad-13', size: const Size(1032, 1376), ratio: 2.0),
    ]) {
      tester.view.physicalSize = device.size * device.ratio;
      tester.view.devicePixelRatio = device.ratio;
      for (var slide = 0; slide < 3; slide++) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: ShadcnApp(
              theme: GetPrioTheme.light(),
              debugShowCheckedModeBanner: false,
              home: GetPrioTheme.wrap(
                OnboardingPage(initialPage: slide, onComplete: () async {}),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final context = tester.element(find.byType(OnboardingPage));
          for (final name in [
            'reception-front.jpg',
            'reception-middle.jpg',
            'reception-back.jpg',
          ]) {
            await precacheImage(AssetImage('assets/onboarding/$name'), context);
          }
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: device.ratio);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final label = [
            'join-a-queue',
            'track-your-ticket',
            'queue-alerts',
          ][slide];
          await File(
            '${destination.path}/${device.name}-0${slide + 1}-$label.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
    debugDisableShadows = true;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }, skip: true);
}
