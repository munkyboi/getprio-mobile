import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/queue/join_repository.dart';
import 'package:getprio_mobile/queue/join_ui.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets('shows the scanned vendor profile and an enabled join action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var joinCount = 0;

    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: JoinPreviewContent(
            preview: const JoinPreview(
              locationQrId: '123e4567-e89b-42d3-a456-426614174000',
              vendorName: 'BOSS LOT',
              vendorSlug: 'bosslot',
              locationName: 'Main location',
              locationSlug: 'main',
              joinable: true,
              fee: 2000,
              vendorProfile: JoinVendorProfile(
                slug: 'bosslot',
                name: 'Boss Lot Wellness',
                category: 'Health and Wellness',
                description: 'Fast, friendly service.',
                locations: [
                  JoinVendorLocation(
                    name: 'Main location',
                    slug: 'other-main',
                    address: 'Wrong branch address',
                  ),
                  JoinVendorLocation(
                    name: 'Main location',
                    slug: 'main',
                    address: 'Quezon City, Philippines',
                  ),
                ],
              ),
            ),
            isBusy: false,
            onJoin: () => joinCount += 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('join-vendor-cover')), findsOneWidget);
    expect(find.byKey(const Key('join-vendor-logo')), findsOneWidget);
    expect(find.text('Boss Lot Wellness'), findsOneWidget);
    expect(find.text('Health and Wellness'), findsOneWidget);
    expect(find.text('Main location'), findsOneWidget);
    expect(find.text('Quezon City, Philippines'), findsOneWidget);
    expect(find.text('Wrong branch address'), findsNothing);
    expect(find.text('QUEUE OPEN'), findsOneWidget);
    expect(find.text('Fee: PHP 20.00'), findsOneWidget);
    final coverClip = tester.widget<ClipRRect>(
      find.ancestor(
        of: find.byKey(const Key('join-vendor-cover')),
        matching: find.byType(ClipRRect),
      ),
    );
    expect(coverClip.borderRadius, BorderRadius.circular(16));

    await tester.tap(find.text('Continue to payment'));
    await tester.pump();
    expect(joinCount, 1);
  });

  testWidgets(
    'does not substitute another branch when the scanned slug is missing',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: JoinPreviewContent(
              preview: const JoinPreview(
                locationQrId: '123e4567-e89b-42d3-a456-426614174000',
                vendorName: 'BOSS LOT',
                vendorSlug: 'bosslot',
                locationName: 'Scanned location',
                locationSlug: 'scanned-location',
                joinable: true,
                vendorProfile: JoinVendorProfile(
                  slug: 'bosslot',
                  name: 'Boss Lot Wellness',
                  locations: [
                    JoinVendorLocation(
                      name: 'Scanned location',
                      slug: 'different-location',
                      address: 'Wrong branch address',
                    ),
                  ],
                ),
              ),
              isBusy: false,
              onJoin: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Scanned location'), findsOneWidget);
      expect(find.text('Wrong branch address'), findsNothing);
    },
  );

  testWidgets('shows an authoritative unavailable state and disables joining', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var joinCount = 0;
    final preview = const JoinPreview(
      locationQrId: '123e4567-e89b-42d3-a456-426614174000',
      vendorName: 'BOSS LOT',
      locationName: 'Main location',
      joinable: true,
    ).asUnavailable('The queue was just paused.');

    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: JoinPreviewContent(
            preview: preview,
            isBusy: false,
            onJoin: () => joinCount += 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('UNAVAILABLE'), findsOneWidget);
    expect(find.byType(OutlineBadge), findsOneWidget);
    expect(find.text('The queue was just paused.'), findsOneWidget);
    await tester.ensureVisible(find.text('Join queue'));
    await tester.tap(find.text('Join queue'));
    await tester.pump();
    expect(joinCount, 0);
  });
}
