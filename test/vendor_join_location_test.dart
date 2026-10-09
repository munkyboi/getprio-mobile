import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/directory/directory_repository.dart';
import 'package:getprio_mobile/main.dart';
import 'package:getprio_mobile/queue/queue_models.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  for (final count in [1, 2]) {
    testWidgets('$count locations: selects from loaded vendor details', (
      tester,
    ) async {
      VendorLocation? selected;
      await tester.pumpWidget(
        ShadcnApp(
          home: VendorDetailPage(
            vendor: const VendorSummary(
              slug: 'clinic',
              name: 'Clinic',
              queueAvailable: true,
            ),
            repository: DirectoryRepository(_Locations(count)),
            onJoinLocation: (value) => selected = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('vendor-location-chevron-0')),
        count == 1 ? findsNothing : findsOneWidget,
      );
      if (count > 1) {
        await Scrollable.ensureVisible(
          tester.element(find.byKey(const ValueKey('vendor-location-1'))),
          alignment: .25,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('vendor-location-1')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const Key('vendor-join-queue-button')));
      await tester.pumpAndSettle();
      expect(find.text('Select a location'), findsNothing);
      expect(selected?.slug, count > 1 ? 'branch-1' : 'branch-0');
      expect(tester.takeException(), isNull);
    });
  }
}

class _Locations implements DirectoryApi {
  _Locations(this.count);
  final int count;
  @override
  Future<Map<String, dynamic>> loadVendors({
    String? search,
    int limit = 20,
  }) async => {};
  @override
  Future<Map<String, dynamic>> loadVendor(String tenantSlug) async => {
    'slug': tenantSlug,
    'name': 'Clinic',
    'queueAvailable': true,
    'locations': List.generate(
      count,
      (i) => {
        'id': '$i',
        'slug': 'branch-$i',
        'name': 'Branch $i',
        'queueAvailable': true,
      },
    ),
  };
}
