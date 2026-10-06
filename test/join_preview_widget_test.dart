import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/app_theme.dart';
import 'package:getprio_mobile/auth/auth_repository.dart';
import 'package:getprio_mobile/queue/join_repository.dart';
import 'package:getprio_mobile/queue/join_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets('refreshes scanned queue events and recovers after disconnect', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _LiveJoinApi();
    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: JoinPage(
            repository: JoinRepository(api),
            allowedHosts: const {'app.getprio.test'},
            customerName: 'Customer',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.widget<MobileScanner>(find.byType(MobileScanner)).onDetect!(
      const BarcodeCapture(
        barcodes: [
          Barcode(
            rawValue: 'https://app.getprio.test/join/bosslot/main?source=qr&id=123e4567-e89b-42d3-a456-426614174000',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(api.scope, ['bosslot', 'main']);
    expect(find.text('4'), findsOneWidget);
    api.waiting = 6;
    api.events.add(null);
    await tester.pumpAndSettle();
    expect(find.text('6'), findsOneWidget);
    expect(find.text('30 mins'), findsOneWidget);
    api.fail = true;
    api.events.add(null);
    await tester.pumpAndSettle();
    expect(find.text('6'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await api.events.close();
    api.fail = false;
    api.waiting = 7;
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(find.text('7'), findsOneWidget);
    final reads = api.reads;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 30));
    expect(api.reads, reads);
    api.waiting = 8;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('8'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    final finalReads = api.reads;
    await tester.pump(const Duration(seconds: 30));
    expect(api.reads, finalReads);
  });

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
            preview: JoinPreview(
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
                lastCalledAt: DateTime(2026, 9, 7, 10, 15),
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
    expect(find.text('Current queue'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('WAITING IN LINE'), findsOneWidget);
    expect(
      find.text('Currently serving 12', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('20 mins'), findsOneWidget);
    expect(find.text('ESTIMATED WAIT'), findsOneWidget);
    expect(
      find.text('Last called ticket 10:15 AM', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Fee: PHP 20.00'), findsOneWidget);
    final surface = tester.widget<Container>(
      find.byKey(const Key('join-preview-surface')),
    );
    expect(
      (surface.decoration as BoxDecoration).borderRadius,
      const BorderRadius.vertical(top: Radius.circular(32)),
    );
    final cover = tester.getRect(find.byKey(const Key('join-vendor-cover')));
    expect(cover.width, 390);
    expect(
      tester.getCenter(find.byKey(const Key('join-vendor-logo'))).dy,
      closeTo(cover.top + (cover.height - 44) / 2, 0.01),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('join-preview-surface'))).dy,
      cover.bottom - 44,
    );
    final actionBefore = tester.getRect(find.text('Continue to payment'));
    expect(actionBefore.bottom, lessThan(844));
    await tester.drag(
      find.byKey(const Key('join-preview-scroll')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Continue to payment')), actionBefore);
    expect(
      tester.getRect(find.text('Fee: PHP 20.00')).bottom,
      lessThan(
        tester
            .getTopLeft(find.byKey(const Key('join-preview-bottom-action')))
            .dy,
      ),
    );

    await tester.tap(find.text('Continue to payment'));
    await tester.pump();
    expect(joinCount, 1);
  });

  testWidgets(
    'uses a half-height cover with vendor parallax and expandable description',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final description = List.generate(
        40,
        (index) => 'Service detail $index',
      ).join('\n');
      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: JoinPreviewContent(
              preview: JoinPreview(
                locationQrId: 'qr',
                vendorName: 'Clinic',
                locationName: 'Main',
                joinable: true,
                vendorProfile: JoinVendorProfile(
                  slug: 'clinic',
                  name: 'Clinic',
                  description: description,
                ),
              ),
              isBusy: false,
              onJoin: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final cover = find.byKey(const Key('join-vendor-cover'));
      final logo = find.byKey(const Key('join-vendor-logo'));
      final viewportHeight = MediaQuery.sizeOf(
        tester.element(find.byType(JoinPreviewContent)),
      ).height;
      final fadeDistance = viewportHeight * 0.5;
      expect(
        tester.getSize(cover).height,
        (viewportHeight * 0.5).clamp(360.0, 480.0) / 2,
      );
      final fade = tester.widget<DecoratedBox>(
        find.byKey(const Key('join-profile-cover-surface-fade')),
      );
      final gradient =
          (fade.decoration as BoxDecoration).gradient! as LinearGradient;
      expect(gradient.colors, [GetPrioTheme.paper, const Color(0x00FBF7F1)]);
      expect(gradient.stops, [0.0, 0.3]);
      expect(tester.widget<Text>(find.text(description)).maxLines, 3);
      await tester.tap(find.text('Read more'));
      await tester.pump();
      expect(tester.widget<Text>(find.text(description)).maxLines, isNull);
      final coverBefore = tester.getTopLeft(cover);
      final logoBefore = tester.getTopLeft(logo);
      final actionBefore = tester.getRect(find.text('Join queue'));
      final controller = tester
          .widget<ListView>(find.byKey(const Key('join-preview-scroll')))
          .controller!;
      controller.jumpTo(100);
      await tester.pump();
      expect(tester.getTopLeft(cover).dy, closeTo(coverBefore.dy - 28, 0.01));
      expect(tester.getTopLeft(logo).dy, closeTo(logoBefore.dy + 70, 0.01));
      final opacity = find.byKey(const Key('join-profile-logo-opacity'));
      expect(
        tester.widget<Opacity>(opacity).opacity,
        closeTo(1 - 100 / fadeDistance, 0.001),
      );
      controller.jumpTo(fadeDistance);
      await tester.pump();
      expect(tester.widget<Opacity>(opacity).opacity, 0);
      expect(tester.getRect(find.text('Join queue')), actionBefore);
    },
  );

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

class _LiveJoinApi extends _JoinErrorApi implements LiveJoinApi {
  _LiveJoinApi() : super(StateError('Unexpected join'));
  final events = StreamController<void>.broadcast();
  int waiting = 4;
  int reads = 0;
  bool fail = false;
  List<String>? scope;

  @override
  Stream<void> watchQueue(String vendorSlug, String locationSlug) {
    scope = [vendorSlug, locationSlug];
    return events.stream;
  }

  @override
  Future<Map<String, dynamic>> resolve(String locationQrId) async {
    reads++;
    if (fail) throw StateError('Offline');
    return {
      ...await super.resolve(locationQrId),
      'vendorSlug': 'bosslot',
      'locationSlug': 'main',
      'snapshot': {
        'stats': {'waitingCount': waiting, 'estimatedWaitMinutes': waiting * 5},
      },
    };
  }
}
