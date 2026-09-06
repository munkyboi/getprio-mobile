import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/app_theme.dart';
import 'package:getprio_mobile/directory/directory_repository.dart';
import 'package:getprio_mobile/main.dart';
import 'package:getprio_mobile/queue/auth_queue_api.dart';
import 'package:getprio_mobile/social/vendor_social_repository.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  test('uses the requested semantic color tokens', () {
    expect(GetPrioTheme.primary, const Color(0xFFFD7E14));
    expect(GetPrioTheme.success, const Color(0xFF40C057));
    expect(GetPrioTheme.destructive, const Color(0xFFFA5252));
    expect(GetPrioTheme.info, const Color(0xFF4C6EF5));
    expect(GetPrioTheme.warning, const Color(0xFFD9480F));

    final theme = GetPrioTheme.light();
    expect(theme.colorScheme.primary, GetPrioTheme.primary);
    expect(theme.colorScheme.destructive, GetPrioTheme.destructive);
  });

  test('uses the centralized typography token scale', () {
    final theme = GetPrioTheme.light();
    final typography = theme.typography;
    final sizes = [
      typography.xSmall,
      typography.small,
      typography.base,
      typography.large,
      typography.xLarge,
      typography.x2Large,
      typography.x3Large,
      typography.x4Large,
      typography.x5Large,
      typography.x6Large,
      typography.x7Large,
      typography.x8Large,
      typography.x9Large,
      typography.h1,
      typography.h2,
      typography.h3,
      typography.h4,
      typography.p,
      typography.textMuted,
    ].map((style) => style.fontSize!).toList();

    expect(typography.xSmall.fontSize, GetPrioTypography.captionSize);
    expect(typography.small.fontSize, GetPrioTypography.labelSize);
    expect(typography.base.fontSize, GetPrioTypography.bodySize);
    expect(typography.p.fontSize, GetPrioTypography.bodyLargeSize);
    expect(typography.textMuted.fontSize, GetPrioTypography.bodySize);
    expect(typography.h1.fontSize, GetPrioTypography.displayLargeSize);
    expect(typography.h2.fontSize, GetPrioTypography.displaySize);
    expect(typography.h3.fontSize, GetPrioTypography.headingSize);
    expect(typography.h4.fontSize, GetPrioTypography.headingSmallSize);
    expect(
      sizes.every(
        (size) =>
            size >= GetPrioTypography.captionSize &&
            size <= GetPrioTypography.displayLargeSize,
      ),
      isTrue,
    );
    expect(typography.h1.fontFamily, GetPrioTypography.displayFontFamily);
    expect(typography.p.fontFamily, GetPrioTypography.uiFontFamily);
    expect(typography.h1.fontWeight, GetPrioTypography.displayWeight);
    expect(typography.h2.fontWeight, GetPrioTypography.displayWeight);
    expect(typography.h3.fontWeight, GetPrioTypography.displayWeight);
    expect(
      GetPrioTheme.titleStyle(theme).fontSize,
      GetPrioTypography.titleSize,
    );
    expect(
      GetPrioTheme.ticketStyle(theme).fontSize,
      GetPrioTypography.ticketSize,
    );
    expect(
      GetPrioTheme.ticketStyle(theme).fontWeight,
      GetPrioTypography.displayWeight,
    );
  });

  testWidgets('shows vendor profile media in the directory', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      ShadcnApp(
        home: ExplorePage(
          repository: DirectoryRepository(
            _ProfileDirectoryApi(),
            social: VendorSocialRepository(_DirectoryRatingsClient()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final media = find.byKey(
      const ValueKey('vendor-profile-media-profiled-vendor'),
    );
    expect(media, findsOneWidget);
    expect(
      find.descendant(of: media, matching: find.byType(Image)),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Profiled Vendor profile media'),
      findsOneWidget,
    );
    final rating = find.byKey(
      const ValueKey('vendor-directory-rating-profiled-vendor'),
    );
    expect(find.text('4.5'), findsOneWidget);
    expect(
      tester.getTopLeft(media).dy,
      tester.getTopLeft(find.text('Profiled Vendor')).dy,
    );
    expect(
      tester.getTopLeft(rating).dy,
      greaterThan(tester.getBottomLeft(media).dy),
    );
    semantics.dispose();
  });
}

class _ProfileDirectoryApi implements DirectoryApi {
  @override
  Future<Map<String, dynamic>> loadVendor(String tenantSlug) async => {};

  @override
  Future<Map<String, dynamic>> loadVendors({
    String? search,
    int limit = 20,
  }) async {
    return {
      'vendors': [
        {
          'slug': 'profiled-vendor',
          'name': 'Profiled Vendor',
          'category': 'Clinic',
          'queueAvailable': true,
          'businessProfileTheme': {
            'theme': {
              'logoUrl': 'https://cdn.example.test/profiled-vendor.png',
              'logoFit': 'contain',
            },
          },
          'locations': [
            {'id': 'main', 'name': 'Main location', 'queueAvailable': true},
          ],
        },
      ],
    };
  }
}

class _DirectoryRatingsClient implements AuthenticatedApiClient {
  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? additionalHeaders,
  }) async => {
    'rating': {'average': 4.5, 'count': 12},
    'pagination': {'totalItems': 12, 'totalPages': 12},
    'reviews': <Map<String, dynamic>>[],
  };
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
