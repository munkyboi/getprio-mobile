import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/app_theme.dart';
import 'package:getprio_mobile/directory/directory_repository.dart';
import 'package:getprio_mobile/main.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  test('uses a calmer display scale and weight', () {
    final typography = GetPrioTheme.light().typography;

    expect(typography.h1.fontSize, 32);
    expect(typography.h2.fontSize, 28);
    expect(typography.h3.fontSize, 20);
    expect(typography.h4.fontSize, 17);
    expect(typography.h1.fontWeight, FontWeight.w700);
    expect(typography.h2.fontWeight, FontWeight.w700);
    expect(typography.h3.fontWeight, FontWeight.w700);
    expect(GetPrioTheme.titleStyle(GetPrioTheme.light()).fontSize, 24);
    expect(GetPrioTheme.ticketStyle(GetPrioTheme.light()).fontSize, 28);
    expect(
      GetPrioTheme.ticketStyle(GetPrioTheme.light()).fontWeight,
      FontWeight.w700,
    );
  });

  testWidgets('shows vendor profile media in the directory', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      ShadcnApp(
        home: ExplorePage(
          repository: DirectoryRepository(_ProfileDirectoryApi()),
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
