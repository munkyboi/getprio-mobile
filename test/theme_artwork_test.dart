import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:getprio_mobile/app_theme.dart';
import 'package:getprio_mobile/directory/vendor_profile_hero.dart';
import 'package:getprio_mobile/main.dart';
import 'package:getprio_mobile/queue/queue_models.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets('Home empty ticket illustration follows the effective theme', (
    tester,
  ) async {
    for (final dark in [true, false]) {
      await tester.pumpWidget(
        ShadcnApp(
          theme: dark ? GetPrioTheme.dark() : GetPrioTheme.light(),
          home: const HomePage(),
        ),
      );
      await tester.pumpAndSettle();
      final illustration = tester.widget<Image>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.semanticLabel ==
                  'Illustration of an empty queue dashboard',
        ),
      );
      expect(
        (illustration.image as AssetImage).assetName,
        'assets/illustrations/dashboard-empty${dark ? '-dark' : ''}.png',
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('vendor cover and logo placeholders follow theme changes', (
    tester,
  ) async {
    for (final dark in [true, false]) {
      await tester.pumpWidget(
        ShadcnApp(
          theme: dark ? GetPrioTheme.dark() : GetPrioTheme.light(),
          home: const Column(
            children: [
              VendorProfileCover(
                vendor: VendorSummary(
                  slug: 'clinic',
                  name: 'Clinic',
                  queueAvailable: false,
                ),
                height: 250,
              ),
              VendorProfileLogo(
                vendor: VendorSummary(
                  slug: 'clinic',
                  name: 'Clinic',
                  queueAvailable: false,
                ),
                size: 104,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final cover = tester.widget<Image>(find.byType(Image));
      expect(
        (cover.image as AssetImage).assetName,
        dark
            ? 'assets/illustrations/hero-queue-scene-dark-transparent.png'
            : 'assets/illustrations/hero-queue-scene-transparent.png',
      );
      final logo = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(
        (logo.bytesLoader as SvgAssetLoader).assetName,
        dark ? 'assets/branding/logo-dark.svg' : 'assets/branding/logo.svg',
      );
      expect(tester.takeException(), isNull);
    }
  });
}
