import '../queue/auth_queue_api.dart';

class BookingService {
  const BookingService({
    required this.slug,
    required this.name,
    this.description = '',
    this.durationMinutes = 0,
    this.priceDisplay = '',
    this.priceAmountCents = 0,
    this.allowQuantity = false,
    this.quantityLabel = 'quantity',
  });
  final String slug, name, description, priceDisplay, quantityLabel;
  final int durationMinutes, priceAmountCents;
  final bool allowQuantity;
  factory BookingService.fromJson(Map<String, dynamic> json) => BookingService(
    slug: json['slug'] as String? ?? '',
    name: json['name'] as String? ?? 'Service',
    description: json['description'] as String? ?? '',
    durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
    priceDisplay: json['priceDisplay'] as String? ?? '',
    priceAmountCents: (json['priceAmountCents'] as num?)?.toInt() ?? 0,
    allowQuantity: json['allowBookingQuantity'] == true,
    quantityLabel: json['bookingQuantityLabel'] as String? ?? 'quantity',
  );
}

class CustomerBooking {
  CustomerBooking(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'] as String? ?? '';
  String get reference => data['reference'] as String? ?? '';
  String get vendorName => data['tenantName'] as String? ?? 'Vendor';
  String get locationName => data['locationName'] as String? ?? '';
  String get serviceName => data['serviceName'] as String? ?? 'Service';
  String get status => data['status'] as String? ?? 'unknown';
  String get paymentStatus => data['paymentStatus'] as String? ?? 'unknown';
  DateTime? get startAt =>
      DateTime.tryParse('${data['scheduledStartAt']}')?.toLocal();
  bool get isUpcoming =>
      ['pending', 'confirmed', 'rescheduled'].contains(status);
}

abstract interface class BookingApi {
  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query});
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body);
}

class RestBookingApi implements BookingApi {
  RestBookingApi(this.client);
  final AuthenticatedApiClient client;
  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) =>
      client.get(path, queryParameters: query);
  @override
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) =>
      client.post(path, body);
}

class BookingRepository {
  BookingRepository(this.api);
  final BookingApi api;
  Future<List<BookingService>> services(String vendor, String location) async {
    final response = await api.get(
      '/api/public/vendors/${Uri.encodeComponent(vendor)}/locations/${Uri.encodeComponent(location)}/services',
    );
    return (response['services'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(BookingService.fromJson)
        .where((service) => service.slug.isNotEmpty)
        .toList();
  }

  Future<Map<String, dynamic>> list({int page = 1}) => api.get(
    '/api/account/bookings',
    query: {'page': '$page', 'pageSize': '20'},
  );
  Future<CustomerBooking> detail(String id) async => CustomerBooking(
    (await api.get(
          '/api/account/bookings/${Uri.encodeComponent(id)}',
        ))['booking']
        as Map<String, dynamic>,
  );
}
