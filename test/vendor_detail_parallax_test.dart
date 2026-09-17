import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:getprio_mobile/app_theme.dart';
import 'package:getprio_mobile/directory/directory_repository.dart';
import 'package:getprio_mobile/main.dart';
import 'package:getprio_mobile/queue/queue_models.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets('uses dark system-bar content on the customer shell', (
    tester,
  ) async {
    await tester.pumpWidget(const ShadcnApp(home: CustomerShell()));

    final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    );

    expect(overlay.value.statusBarIconBrightness, Brightness.dark);
  });

  testWidgets('fades the cover and slowly parallax-scrolls it with the logo', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ShadcnApp(
        home: VendorDetailPage(
          vendor: const VendorSummary(
            slug: 'city-clinic',
            name: 'City Clinic',
            queueAvailable: true,
          ),
          repository: DirectoryRepository(_ParallaxDirectoryApi()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fade = tester.widget<DecoratedBox>(
      find.byKey(const Key('profile-cover-surface-fade')),
    );
    final gradient =
        (fade.decoration as BoxDecoration).gradient! as LinearGradient;
    expect(gradient.colors.first, GetPrioTheme.paper);
    expect(gradient.colors.last.a, 0);
    expect(gradient.stops, const [0.0, 0.3]);

    final coverBefore = tester.getRect(
      find.byKey(const Key('vendor-profile-cover')),
    );
    final logoBefore = tester.getRect(find.byKey(const Key('vendor-logo')));
    final surfaceBefore = tester.getRect(
      find.byKey(const Key('vendor-detail-surface')),
    );

    await tester.drag(
      find.byKey(const Key('vendor-details-scroll')),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    final coverAfter = tester.getRect(
      find.byKey(const Key('vendor-profile-cover')),
    );
    final logoAfter = tester.getRect(find.byKey(const Key('vendor-logo')));
    final surfaceAfter = tester.getRect(
      find.byKey(const Key('vendor-detail-surface')),
    );

    expect(coverAfter.top, lessThan(coverBefore.top));
    expect(surfaceAfter.top, lessThan(surfaceBefore.top));
    expect(logoAfter.top, greaterThan(logoBefore.top));
    expect(
      coverBefore.top - coverAfter.top,
      lessThan(surfaceBefore.top - surfaceAfter.top),
    );
  });

  testWidgets('fades the profile logo out by half a viewport of scrolling', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ShadcnApp(
        home: VendorDetailPage(
          vendor: const VendorSummary(
            slug: 'city-clinic',
            name: 'City Clinic',
            queueAvailable: true,
          ),
          repository: DirectoryRepository(_ParallaxDirectoryApi()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final logoOpacity = find.byKey(const Key('vendor-profile-logo-opacity'));
    expect(tester.widget<Opacity>(logoOpacity).opacity, 1.0);

    final scrollController = tester
        .widget<ListView>(find.byKey(const Key('vendor-details-scroll')))
        .controller!;
    final viewportHeight = tester
        .widget<MediaQuery>(find.byType(MediaQuery).first)
        .data
        .size
        .height;
    scrollController.jumpTo(viewportHeight * 0.5 - 1);
    await tester.pump();
    expect(tester.widget<Opacity>(logoOpacity).opacity, greaterThan(0));

    scrollController.jumpTo(viewportHeight * 0.5);
    await tester.pump();
    expect(tester.widget<Opacity>(logoOpacity).opacity, closeTo(0, 0.001));
  });
}

class _ParallaxDirectoryApi implements DirectoryApi {
  @override
  Future<Map<String, dynamic>> loadVendor(String tenantSlug) async => {
    'slug': tenantSlug,
    'name': 'City Clinic',
    'category': 'Health and Wellness',
    'queueAvailable': true,
    'description':
        'A welcoming clinic with a complete range of everyday health services. '
        'Our team is here to help customers find the right care and support. '
        'Appointments, walk-ins, and queue information are available at the location.',
    'locations': List.generate(
      10,
      (index) => {
        'id': 'clinic-$index',
        'name': index == 0 ? 'Main Clinic' : 'Clinic $index',
        'queueAvailable': true,
        'addressLine1': '10 Health Street',
        'city': 'Cebu City',
        'openStatus': {'isOpen': true, 'summary': 'Mon-Fri 09:00-17:00'},
      },
    ),
  };

  @override
  Future<Map<String, dynamic>> loadVendors({
    String? search,
    int limit = 20,
  }) async => const {'vendors': []};
}
