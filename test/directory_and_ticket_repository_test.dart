import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/account/ticket_repository.dart';
import 'package:getprio_mobile/directory/directory_repository.dart';
import 'package:getprio_mobile/queue/queue_models.dart';

void main() {
  test(
    'loads account tickets from the shared overview and history shapes',
    () async {
      final repository = QueueTicketRepository(
        FakeAccountQueueApi(
          overview: {
            'tickets': [ticketJson('active-1', 'waiting')],
          },
          history: {
            'items': [ticketJson('history-1', 'served')],
          },
        ),
      );

      expect((await repository.loadOverview()).single.id, 'active-1');
      expect(
        (await repository.loadHistory()).single.status,
        TicketStatus.served,
      );
    },
  );

  test('directory hides vendors without queue capability', () async {
    final repository = DirectoryRepository(
      FakeDirectoryApi(
        vendors: {
          'vendors': [
            {
              'slug': 'queue-vendor',
              'name': 'Queue Vendor',
              'capabilities': {'queue': true},
            },
            {
              'slug': 'booking-vendor',
              'name': 'Booking Vendor',
              'capabilities': {'queue': false},
            },
          ],
        },
      ),
    );

    final vendors = await repository.loadVendors();

    expect(vendors.map((vendor) => vendor.slug), ['queue-vendor']);
  });
}

Map<String, dynamic> ticketJson(String id, String status) {
  return {
    'id': id,
    'lookupCode': id,
    'ticketNumber': 1,
    'customerName': 'Customer',
    'status': status,
  };
}

class FakeAccountQueueApi implements AccountQueueApi {
  FakeAccountQueueApi({required this.overview, required this.history});

  final Map<String, dynamic> overview;
  final Map<String, dynamic> history;

  @override
  Future<Map<String, dynamic>> loadHistory({
    required int page,
    required int limit,
  }) async => history;

  @override
  Future<Map<String, dynamic>> loadOverview() async => overview;
}

class FakeDirectoryApi implements DirectoryApi {
  FakeDirectoryApi({required this.vendors});

  final Map<String, dynamic> vendors;

  @override
  Future<Map<String, dynamic>> loadVendor(String tenantSlug) async => vendors;

  @override
  Future<Map<String, dynamic>> loadVendors({
    String? search,
    int limit = 20,
  }) async => vendors;
}
