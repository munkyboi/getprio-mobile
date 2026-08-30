import 'auth_queue_api.dart';
import 'queue_models.dart';

export 'auth_queue_api.dart' show QueueApi;

class QueueRepository {
  QueueRepository(this.api);

  final QueueApi api;

  Future<QueueSnapshot> loadQueueSnapshot({
    required String tenantSlug,
    String? locationSlug,
    String? lookupCode,
  }) async {
    return QueueSnapshot.fromJson(
      await api.loadQueueSnapshot(
        tenantSlug: tenantSlug,
        locationSlug: locationSlug,
        lookupCode: lookupCode,
      ),
    );
  }

  Future<QueueTicket> cancelTicket({
    required String tenantSlug,
    required QueueTicket ticket,
    String? locationSlug,
  }) async {
    if (ticket.status != TicketStatus.waiting) {
      throw StateError('Only waiting tickets can be cancelled.');
    }
    final response = await api.cancelTicket(
      tenantSlug: tenantSlug,
      locationSlug: locationSlug,
      lookupCode: ticket.lookupCode,
    );
    final cancelled = response['ticket'];
    return cancelled is Map<String, dynamic>
        ? QueueTicket.fromJson(cancelled)
        : QueueTicket(
            id: ticket.id,
            lookupCode: ticket.lookupCode,
            ticketNumber: ticket.ticketNumber,
            customerName: ticket.customerName,
            status: TicketStatus.cancelled,
            vendorName: ticket.vendorName,
            locationName: ticket.locationName,
          );
  }
}
