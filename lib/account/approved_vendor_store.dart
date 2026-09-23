import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApprovedVendor {
  const ApprovedVendor({required this.key, required this.name});

  final String key;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is ApprovedVendor && other.key == key && other.name == name;

  @override
  int get hashCode => Object.hash(key, name);

  factory ApprovedVendor.fromJson(Map<String, dynamic> json) {
    final key = json['key'];
    final name = json['name'];
    if (key is! String ||
        key.trim().isEmpty ||
        name is! String ||
        name.trim().isEmpty) {
      throw const FormatException('Approved vendor is incomplete.');
    }
    return ApprovedVendor(key: key.trim(), name: name.trim());
  }

  Map<String, String> toJson() => {'key': key, 'name': name};

  static ApprovedVendor fromTicket({
    required String? tenantSlug,
    required String? vendorName,
  }) {
    final name = vendorName?.trim();
    final visibleName = name == null || name.isEmpty ? 'Queue vendor' : name;
    final slug = tenantSlug?.trim().toLowerCase();
    final key = slug == null || slug.isEmpty
        ? 'name:${visibleName.toLowerCase()}'
        : 'slug:$slug';
    return ApprovedVendor(key: key, name: visibleName);
  }
}

abstract interface class ApprovedVendorStore {
  Future<List<ApprovedVendor>> load(String accountId);

  Future<void> add(String accountId, ApprovedVendor vendor);

  Future<void> remove(String accountId, String vendorKey);
}

class SecureApprovedVendorStore implements ApprovedVendorStore {
  SecureApprovedVendorStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _keyPrefix = 'getprio.approved_vendors.';
  final FlutterSecureStorage _storage;

  String _storageKey(String accountId) =>
      '$_keyPrefix${Uri.encodeComponent(accountId)}';

  @override
  Future<List<ApprovedVendor>> load(String accountId) async {
    final raw = await _storage.read(key: _storageKey(accountId));
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ApprovedVendor.fromJson)
          .toList(growable: false);
    } on FormatException {
      return const [];
    } on Object {
      return const [];
    }
  }

  @override
  Future<void> add(String accountId, ApprovedVendor vendor) async {
    final vendors = [...await load(accountId)];
    final existingIndex = vendors.indexWhere((item) => item.key == vendor.key);
    if (existingIndex >= 0) {
      vendors[existingIndex] = vendor;
    } else {
      vendors.add(vendor);
    }
    await _write(accountId, vendors);
  }

  @override
  Future<void> remove(String accountId, String vendorKey) async {
    final vendors = (await load(accountId))
        .where((vendor) => vendor.key != vendorKey)
        .toList(growable: false);
    await _write(accountId, vendors);
  }

  Future<void> _write(String accountId, List<ApprovedVendor> vendors) async {
    if (vendors.isEmpty) {
      await _storage.delete(key: _storageKey(accountId));
      return;
    }
    await _storage.write(
      key: _storageKey(accountId),
      value: jsonEncode(vendors.map((vendor) => vendor.toJson()).toList()),
    );
  }
}
