import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/auth/auth_repository.dart';
import 'package:getprio_mobile/queue/join_repository.dart';
import 'package:getprio_mobile/queue/join_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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
              queueDetails: JoinQueueDetails(
                waitingCount: 4,
                currentTicketNumber: '12',
                estimatedWaitMinutes: 20,
              ),
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
    expect(find.text('Waiting now'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Now serving'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Estimated wait'), findsOneWidget);
    expect(find.text('20 min'), findsOneWidget);
    expect(find.text('Fee: PHP 20.00'), findsOneWidget);
    final coverClip = tester.widget<ClipRRect>(
      find.ancestor(
        of: find.byKey(const Key('join-vendor-cover')),
        matching: find.byType(ClipRRect),
      ),
    );
    expect(coverClip.borderRadius, BorderRadius.circular(16));

    await tester.ensureVisible(find.text('Continue to payment'));
    await tester.tap(find.text('Continue to payment'));
    await tester.pump();
    expect(joinCount, 1);
  });

  testWidgets('shows the API error when joining fails', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _JoinErrorApi(
      const ApiException(
        502,
        'QUEUE_SERVICE_ERROR',
        'Queue service is unavailable.',
      ),
    );

    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: JoinPage(
            repository: JoinRepository(api),
            allowedHosts: const {'app.getprio.test'},
            customerName: 'Preferred name',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scanner = tester.widget<MobileScanner>(find.byType(MobileScanner));
    scanner.onDetect!(
      const BarcodeCapture(
        barcodes: [
          Barcode(
            rawValue: 'https://app.getprio.test/join/bosslot/main?source=qr&id=123e4567-e89b-42d3-a456-426614174000',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Join queue'));
    await tester.tap(find.text('Join queue'));
    await tester.pumpAndSettle();

    expect(find.text('Queue service is unavailable.'), findsOneWidget);
    expect(
      find.text(
        'We could not load this queue. Check your connection and try again.',
      ),
      findsNothing,
    );
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

class _JoinErrorApi implements JoinApi {
  _JoinErrorApi(this.error);

  final Object error;

  @override
  Future<Map<String, dynamic>> resolve(String locationQrId) async {
    return {
      'locationQrId': locationQrId,
      'vendorName': 'BOSS LOT',
      'locationName': 'Main location',
      'joinable': true,
    };
  }

  @override
  Future<Map<String, dynamic>> join({
    required String locationQrId,
    required String joinAttemptId,
    required String customerName,
  }) async {
    throw error;
  }
}
