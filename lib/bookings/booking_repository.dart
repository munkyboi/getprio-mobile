import '../queue/auth_queue_api.dart';

class BookingService {
  const BookingService({
    required this.slug,
    required this.name,
    this.description = '',
    this.imageUrl = '',
    this.durationMinutes = 0,
    this.priceDisplay = '',
    this.priceAmountCents = 0,
    this.allowQuantity = false,
    this.quantityLabel = 'quantity',
  });
  final String slug, name, description, imageUrl, priceDisplay, quantityLabel;
  final int durationMinutes, priceAmountCents;
  final bool allowQuantity;
  factory BookingService.fromJson(Map<String, dynamic> json) => BookingService(
    slug: json['slug'] as String? ?? '',
    name: json['name'] as String? ?? 'Service',
    description: json['description'] as String? ?? '',
    imageUrl: (json['imageUrl'] as String? ?? '').trim(),
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
  Map<String, dynamic>? get linkedTicket =>
      data['linkedTicket'] is Map<String, dynamic>
      ? data['linkedTicket'] as Map<String, dynamic>
      : null;
  bool get arrivalPaymentBlocked =>
      requiresManualPayment &&
      paymentStatus != 'paid' &&
      data['paymentVerifiedAt'] == null;
  bool canCheckIn(DateTime now) =>
      data['customerSelfCheckInEnabled'] == true &&
      ['confirmed', 'rescheduled'].contains(status) &&
      data['expiredAt'] == null &&
      data['checkedInAt'] == null &&
      linkedTicket == null &&
      data['queueTicketId'] == null &&
      !arrivalPaymentBlocked &&
      startAt != null &&
      !now.isBefore(startAt!.subtract(const Duration(minutes: 15))) &&
      !now.isAfter(startAt!.add(const Duration(minutes: 15)));
  String checkInLabel(DateTime now) {
    if (linkedTicket != null) return 'Open queue ticket';
    if (!['confirmed', 'rescheduled'].contains(status) ||
        data['expiredAt'] != null) {
      return 'Check-in unavailable';
    }
    if (data['checkedInAt'] != null) return 'Checked in';
    final start = startAt;
    if (start == null) return 'Ask the vendor about check-in';
    final opening = start.subtract(const Duration(minutes: 15));
    if (now.isBefore(opening)) {
      final minutes = (opening.difference(now).inMilliseconds / 60000).ceil();
      return 'Check-in available in ${minutes >= 60 ? '${(minutes / 60).ceil()}h' : '${minutes}m'}';
    }
    if (canCheckIn(now)) return 'I’ve arrived';
    if (now.isAfter(start.add(const Duration(minutes: 15)))) {
      return 'Arrival window closed · Contact vendor';
    }
    return data['customerSelfCheckInEnabled'] == true && arrivalPaymentBlocked
        ? 'Waiting for payment verification'
        : 'Waiting for vendor check-in';
  }

  bool get requiresManualPayment =>
      data['serviceManualPaymentRequired'] == true;
  bool get hasPaymentProof => data['paymentProof'] is Map;
  bool get canSubmitProof =>
      requiresManualPayment &&
      isUpcoming &&
      data['bookingPaymentSource'] != 'group_funded' &&
      data['groupFundedBookingId'] == null &&
      data['checkedInAt'] == null &&
      data['linkedTicket'] == null &&
      data['queueTicketId'] == null &&
      !hasPaymentProof;
  String get nextStep {
    if (status == 'expired') return 'This booking request expired.';
    if (status == 'canceled') return 'This booking was canceled.';
    if (status == 'completed') return 'This booking has been completed.';
    if (paymentStatus == 'rejected') {
      return 'Payment proof was rejected. Review the vendor’s reason below.';
    }
    if (canSubmitProof) {
      return status == 'pending'
          ? 'Payment proof required. This request is awaiting vendor confirmation.'
          : 'Payment proof required. Payment is not yet verified.';
    }
    if (hasPaymentProof && paymentStatus == 'pending') {
      return 'Payment proof submitted. Awaiting vendor review; payment is not yet verified.';
    }
    if (status == 'pending') {
      return 'Request submitted. Awaiting vendor confirmation.';
    }
    if (data['checkedInAt'] != null || linkedTicket != null) {
      return 'You’re checked in. Follow your queue ticket for service updates.';
    }
    if (status == 'confirmed' || status == 'rescheduled') {
      if (data['customerSelfCheckInEnabled'] == true) {
        return 'Your booking is confirmed. At the location, tap I’ve arrived during the check-in window to get your queue ticket.';
      }
      return 'Your booking is confirmed. Keep this booking ready for vendor check-in.';
    }
    return 'Booking: $status · Payment: $paymentStatus';
  }

  bool get isUpcoming =>
      ['pending', 'confirmed', 'rescheduled'].contains(status);
}

abstract interface class BookingApi {
  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query});
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body);
}

abstract interface class BookingProofApi {
  Future<Map<String, dynamic>> uploadProof(
    String path, {
    required List<int> bytes,
    required String contentType,
    required String fileName,
  });
}

class RestBookingApi implements BookingApi, BookingProofApi {
  RestBookingApi(this.client);
  final AuthenticatedApiClient client;
  @override
  Future<Map<String, dynamic>> uploadProof(
    String path, {
    required List<int> bytes,
    required String contentType,
    required String fileName,
  }) => client.uploadBytes(
    path,
    bytes: bytes,
    contentType: contentType,
    queryParameters: {'fileName': fileName},
  );
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
  Future<String> paymentProofUrl(String id) async {
    final response = await api.get(
      '/api/account/bookings/${Uri.encodeComponent(id)}/payment-proof',
    );
    final access = response['access'];
    final url = access is Map ? access['url'] : null;
    final uri = url is String ? Uri.tryParse(url) : null;
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw StateError('Payment proof is unavailable.');
    }
    return url as String;
  }

  Future<CustomerBooking> checkIn(CustomerBooking booking, DateTime now) async {
    if (!booking.canCheckIn(now)) {
      throw StateError('Customer check-in is unavailable for this booking.');
    }
    final response = await api.post(
      '/api/account/bookings/${Uri.encodeComponent(booking.id)}/arrival',
      {},
    );
    return CustomerBooking(response['booking'] as Map<String, dynamic>);
  }

  Future<CustomerBooking> submitPaymentProof(
    CustomerBooking booking, {
    required String reference,
    required List<int> bytes,
    required String contentType,
    required String fileName,
  }) async {
    if (!booking.canSubmitProof) {
      throw StateError('This booking cannot accept payment proof.');
    }
    if (reference.trim().isEmpty) {
      throw ArgumentError('Payment reference is required.');
    }
    if (!['image/jpeg', 'image/png', 'image/webp'].contains(contentType) ||
        bytes.isEmpty ||
        bytes.length > 8 * 1024 * 1024) {
      throw ArgumentError('Choose a JPEG, PNG, or WebP receipt up to 8 MB.');
    }
    final uploader = api;
    if (uploader is! BookingProofApi) {
      throw StateError('Payment upload is unavailable.');
    }
    final path =
        '/api/account/bookings/${Uri.encodeComponent(booking.id)}/payment-proof';
    final upload = await (uploader as BookingProofApi).uploadProof(
      '$path/uploads/direct',
      bytes: bytes,
      contentType: contentType,
      fileName: fileName,
    );
    final proof = upload['proof'] as Map<String, dynamic>;
    final response = await api.post(path, {
      'paymentReference': reference.trim(),
      for (final key in ['objectKey', 'fileName', 'contentType', 'sizeBytes'])
        key: proof[key],
    });
    return CustomerBooking(response['booking'] as Map<String, dynamic>);
  }

  Future<CustomerBooking> detail(String id) async => CustomerBooking(
    (await api.get(
          '/api/account/bookings/${Uri.encodeComponent(id)}',
        ))['booking']
        as Map<String, dynamic>,
  );
}
