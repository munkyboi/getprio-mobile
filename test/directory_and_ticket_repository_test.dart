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

  test(
    'merges overview and history without duplicating the same ticket',
    () async {
      final repository = QueueTicketRepository(
        FakeAccountQueueApi(
          overview: {
            'tickets': [ticketJson('active-1', 'waiting')],
          },
          history: {
            'items': [ticketJson('active-1', 'waiting')],
          },
        ),
      );

      final tickets = await repository.loadAllTickets();

      expect(tickets, hasLength(1));
      expect(tickets.single.id, 'active-1');
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

  test(
    'vendor details parse profile media, contact, and open location data',
    () async {
      final repository = DirectoryRepository(
        FakeDirectoryApi(
          vendors: {
            'slug': 'city-clinic',
            'name': 'City Clinic',
            'description':
                '<p>Trusted care &amp; clear advice.<br>Open daily.</p>',
            'capabilities': {'queue': true},
            'businessProfileTheme': {
              'scope': 'tenant',
              'theme': {
                'logoUrl': 'https://cdn.example.com/logo.jpg',
                'logoFit': 'contain',
                'backgroundImageUrl': 'https://cdn.example.com/cover.jpg',
                'backgroundImageFit': 'cover',
              },
            },
            'locations': [
              {
                'name': 'Main Clinic',
                'capabilities': {'queue': true},
                'contactEmail': 'hello@cityclinic.example',
                'contactPhone': '+63 917 555 0100',
                'addressLine1': '10 Health Street',
                'city': 'Cebu City',
                'country': 'Philippines',
                'openStatus': {
                  'isOpen': true,
                  'summary': 'Mon-Fri 08:00-17:00',
                },
              },
              {
                'name': 'Closed Annex',
                'capabilities': {'queue': true},
                'openStatus': {'isOpen': false},
              },
            ],
          },
        ),
      );

      final vendor = await repository.loadVendor('city-clinic');

      expect(vendor.description, 'Trusted care & clear advice.\nOpen daily.');
      expect(vendor.logoUrl, 'https://cdn.example.com/logo.jpg');
      expect(vendor.logoFit, 'contain');
      expect(vendor.coverImageUrl, 'https://cdn.example.com/cover.jpg');
      expect(vendor.coverImageFit, 'cover');
      expect(vendor.contactEmail, 'hello@cityclinic.example');
      expect(vendor.contactPhone, '+63 917 555 0100');
      expect(vendor.locations.first.queueAvailable, isTrue);
      expect(vendor.locations.last.queueAvailable, isFalse);
      expect(
        vendor.locations.first.address,
        '10 Health Street, Cebu City, Philippines',
      );
      expect(vendor.locations.first.openStatus, 'Mon-Fri 08:00-17:00');
    },
  );
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
