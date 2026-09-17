import 'package:flutter/foundation.dart';

import '../queue/auth_queue_api.dart';
import '../queue/queue_models.dart';

class VendorReview {
  VendorReview.fromJson(Map<String, dynamic> json)
    : id = '${json['id']}',
      stars = (json['stars'] as num).toInt(),
      comment = json['comment'] as String? ?? '',
      customerName = json['customer_display_name'] as String? ?? 'Customer',
      createdAt = DateTime.parse(json['created_at'] as String);
  final String id;
  final int stars;
  final String comment;
  final String customerName;
  final DateTime createdAt;
}

class VendorReviewsPage {
  VendorReviewsPage.fromJson(Map<String, dynamic> json)
    : reviews = (json['reviews'] as List)
          .map((item) => VendorReview.fromJson(item as Map<String, dynamic>))
          .toList(),
      average = (json['rating']['average'] as num).toDouble(),
      count = (json['rating']['count'] as num).toInt(),
      total = (json['pagination']['totalItems'] as num).toInt(),
      totalPages = (json['pagination']['totalPages'] as num).toInt();
  final List<VendorReview> reviews;
  final double average;
  final int count;
  final int total;
  final int totalPages;
}

class VendorSocialRepository extends ChangeNotifier {
  VendorSocialRepository(this.client);
  final AuthenticatedApiClient client;
  List<VendorSummary>? favorites;
  Future<void>? _loading;
  int _generation = 0;
  void clearSession() {
    _generation++;
    favorites = null;
    _loading = null;
    _pending.clear();
    promptedTickets.clear();
  }

  final Set<String> _pending = {};
  final Set<String> promptedTickets = {};
  bool contains(String slug) =>
      favorites?.any((vendor) => vendor.slug == slug) ?? false;
  bool isPending(String slug) => _pending.contains(slug);
  Future<void> loadFavorites() {
    final generation = _generation;
    return _loading ??= _loadFavorites(generation).whenComplete(() {
      if (generation == _generation) _loading = null;
    });
  }

  Future<void> _loadFavorites(int generation) async {
    final data = await client.get('/api/account/favorites');
    if (generation != _generation) return;
    favorites = (data['vendors'] as List)
        .map((item) => VendorSummary.fromJson(item as Map<String, dynamic>))
        .toList();
    notifyListeners();
  }

  Future<void> setFavorite(VendorSummary vendor, bool favorite) async {
    final generation = _generation;
    if (!_pending.add(vendor.slug)) return;
    notifyListeners();
    try {
      final path = '/api/account/favorites/${Uri.encodeComponent(vendor.slug)}';
      if (favorite) {
        await client.put(path, {});
      } else {
        await client.delete(path);
      }
      if (generation != _generation) return;
      // Update from the successful mutation so all open surfaces stay in sync.
      favorites = [...?favorites]
        ..removeWhere((item) => item.slug == vendor.slug);
      if (favorite) favorites!.insert(0, vendor);
    } finally {
      if (generation == _generation) {
        _pending.remove(vendor.slug);
        notifyListeners();
      }
    }
  }

  Future<VendorReviewsPage> reviews(
    String slug, {
    int page = 1,
    int pageSize = 5,
  }) async => VendorReviewsPage.fromJson(
    await client.get(
      '/api/public/vendors/${Uri.encodeComponent(slug)}/ratings',
      queryParameters: {'page': '$page', 'pageSize': '$pageSize'},
    ),
  );
  Future<Map<String, dynamic>> ticketRating(String lookup) =>
      client.get('/api/account/tickets/${Uri.encodeComponent(lookup)}/rating');
  Future<void> rate(String lookup, int stars, String comment) async {
    await client.post(
      '/api/account/tickets/${Uri.encodeComponent(lookup)}/rating',
      {'stars': stars, 'comment': comment},
    );
    notifyListeners();
  }
}
