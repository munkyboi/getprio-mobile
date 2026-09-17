import '../social/vendor_social_repository.dart';
import '../queue/auth_queue_api.dart';
import '../queue/queue_models.dart';

abstract interface class DirectoryApi {
  Future<Map<String, dynamic>> loadVendors({String? search, int limit = 20});

  Future<Map<String, dynamic>> loadVendor(String tenantSlug);
}

class DirectoryRepository {
  DirectoryRepository(this.api, {VendorSocialRepository? social})
    : social =
          social ??
          (api is RestDirectoryApi ? VendorSocialRepository(api.client) : null);

  final VendorSocialRepository? social;

  final DirectoryApi api;

  Future<List<VendorSummary>> loadVendors({
    String? search,
    int limit = 20,
  }) async {
    final response = await api.loadVendors(search: search, limit: limit);
    final rawVendors = response['vendors'] ?? response['items'];
    if (rawVendors is! List) return const [];
    return rawVendors
        .whereType<Map<String, dynamic>>()
        .map(VendorSummary.fromJson)
        .where((vendor) => vendor.queueAvailable)
        .toList(growable: false);
  }

  Future<VendorSummary> loadVendor(String tenantSlug) async {
    return VendorSummary.fromJson(await api.loadVendor(tenantSlug));
  }
}

class RestDirectoryApi implements DirectoryApi {
  RestDirectoryApi(this.client);

  final AuthenticatedApiClient client;

  @override
  Future<Map<String, dynamic>> loadVendors({String? search, int limit = 20}) {
    return client.get(
      '/api/public/vendors',
      queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'limit': '$limit',
      },
    );
  }

  @override
  Future<Map<String, dynamic>> loadVendor(String tenantSlug) {
    return client.get('/api/public/vendors/$tenantSlug').then((response) {
      final vendor = response['vendor'];
      return vendor is Map<String, dynamic> ? vendor : response;
    });
  }
}
