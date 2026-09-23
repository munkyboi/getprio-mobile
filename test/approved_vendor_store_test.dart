import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/account/approved_vendor_store.dart';

void main() {
  test('identifies a vendor by tenant slug and falls back to its name', () {
    expect(
      ApprovedVendor.fromTicket(
        tenantSlug: 'Dr-Troy-Choi',
        vendorName: 'Dr Troy Choi',
      ),
      const ApprovedVendor(key: 'slug:dr-troy-choi', name: 'Dr Troy Choi'),
    );
    expect(
      ApprovedVendor.fromTicket(tenantSlug: null, vendorName: 'Acme Clinic'),
      const ApprovedVendor(key: 'name:acme clinic', name: 'Acme Clinic'),
    );
  });

  test(
    'keeps approvals isolated by account and replaces duplicate vendors',
    () async {
      final store = MemoryApprovedVendorStore();
      const vendor = ApprovedVendor(key: 'slug:acme', name: 'Acme Clinic');

      await store.add('customer-1', vendor);
      await store.add(
        'customer-1',
        const ApprovedVendor(key: 'slug:acme', name: 'Acme Clinic Updated'),
      );
      await store.add(
        'customer-2',
        const ApprovedVendor(key: 'slug:other', name: 'Other Clinic'),
      );

      expect((await store.load('customer-1')).map((item) => item.name), [
        'Acme Clinic Updated',
      ]);
      expect((await store.load('customer-2')).map((item) => item.name), [
        'Other Clinic',
      ]);

      await store.remove('customer-1', vendor.key);
      expect(await store.load('customer-1'), isEmpty);
    },
  );
}

class MemoryApprovedVendorStore implements ApprovedVendorStore {
  final Map<String, List<ApprovedVendor>> values = {};

  @override
  Future<List<ApprovedVendor>> load(String accountId) async => [
    ...values[accountId] ?? const <ApprovedVendor>[],
  ];

  @override
  Future<void> add(String accountId, ApprovedVendor vendor) async {
    final current = [...await load(accountId)];
    current.removeWhere((item) => item.key == vendor.key);
    current.add(vendor);
    values[accountId] = current;
  }

  @override
  Future<void> remove(String accountId, String vendorKey) async {
    values[accountId] = (await load(accountId))
        .where((item) => item.key != vendorKey)
        .toList(growable: false);
  }
}
