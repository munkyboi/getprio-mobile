import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/directory/directory_repository.dart';
import 'package:getprio_mobile/main.dart';
import 'package:getprio_mobile/queue/queue_models.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  test('parses structured weekly store hours for a vendor location', () {
    final vendor = VendorSummary.fromJson(_vendorJson());
    final hours = vendor.locations.single.hours;

    expect(hours, hasLength(7));
    expect(hours.first.weekday, 0);
    expect(hours.first.opensAt, '09:00');
    expect(hours.first.closesAt, '17:00');
    expect(hours.last.isClosed, isTrue);
  });

  testWidgets('opens pretty store hours from a location action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ShadcnApp(
        home: VendorDetailPage(
          vendor: const VendorSummary(
            slug: 'city-clinic',
            name: 'City Clinic',
            queueAvailable: true,
          ),
          repository: DirectoryRepository(_StoreHoursDirectoryApi()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('STORE OPEN'), findsOneWidget);
    expect(find.text('QUEUE OPEN'), findsNothing);
    expect(find.text('Sun 09:00-17:00, Mon 09:00-17:00'), findsNothing);
    expect(
      find.byKey(const Key('store-hours-button-main-clinic')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('store-hours-button-main-clinic')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vendor-store-hours-sheet')), findsOneWidget);
    expect(find.text('Store hours'), findsOneWidget);
    expect(find.text('Main Clinic'), findsNWidgets(2));
    expect(find.text('Sunday'), findsOneWidget);
    expect(find.text('Monday'), findsOneWidget);
    expect(find.text('9:00 AM – 5:00 PM'), findsNWidgets(5));
    expect(find.text('Open 24 hours'), findsOneWidget);
    expect(find.text('Closed'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Close store hours'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vendor-store-hours-sheet')), findsNothing);
  });

  testWidgets('adds bottom breathing room below the final location content', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ShadcnApp(
        home: VendorDetailPage(
          vendor: const VendorSummary(
            slug: 'city-clinic',
            name: 'City Clinic',
            queueAvailable: true,
          ),
          repository: DirectoryRepository(_StoreHoursDirectoryApi()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final surface = tester.getRect(
      find.byKey(const Key('vendor-detail-surface')),
    );
    final finalContent = tester.getRect(
      find.byKey(const Key('vendor-join-instructions')),
    );
    expect(surface.bottom - finalContent.bottom, closeTo(48, 0.5));
  });
}

Map<String, dynamic> _vendorJson() {
  return {
    'slug': 'city-clinic',
    'name': 'City Clinic',
    'queueAvailable': true,
    'locations': [
      {
        'id': 'main-clinic',
        'slug': 'main-clinic',
        'name': 'Main Clinic',
        'queueAvailable': true,
        'address': 'Cebu City, Philippines',
        'openStatus': {
          'isOpen': true,
          'summary': 'Sun 09:00-17:00, Mon 09:00-17:00',
        },
        'hours': [
          {'weekday': 0, 'opensAt': '09:00', 'closesAt': '17:00'},
          {'weekday': 1, 'opensAt': '09:00', 'closesAt': '17:00'},
          {'weekday': 2, 'opensAt': '00:00', 'closesAt': '00:00'},
          {'weekday': 3, 'opensAt': '09:00', 'closesAt': '17:00'},
          {'weekday': 4, 'opensAt': '09:00', 'closesAt': '17:00'},
          {'weekday': 5, 'opensAt': '09:00', 'closesAt': '17:00'},
          {
            'weekday': 6,
            'opensAt': '09:00',
            'closesAt': '17:00',
            'isClosed': true,
          },
        ],
      },
    ],
  };
}

class _StoreHoursDirectoryApi implements DirectoryApi {
  @override
  Future<Map<String, dynamic>> loadVendor(String tenantSlug) async =>
      _vendorJson();

  @override
  Future<Map<String, dynamic>> loadVendors({
    String? search,
    int limit = 20,
  }) async => const {'vendors': []};
}
