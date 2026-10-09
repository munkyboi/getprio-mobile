import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:getprio_mobile/bookings/booking_presentation.dart';
import 'package:getprio_mobile/bookings/booking_repository.dart';
import 'package:getprio_mobile/bookings/bookings_page.dart';

Map<String, dynamic> sampleBooking() => {
  'id': 'booking',
  'reference': 'BKG-SAMPLE',
  'tenantName': 'Pickle Bois',
  'locationName': 'Main location',
  'status': 'confirmed',
  'paymentStatus': 'verified',
  'serviceCurrency': 'PHP',
  'customerName': 'Lucas',
  'customerPhone': '09990000000',
  'bundleItems': [
    for (var i = 1; i <= 3; i++)
      {
        'serviceName': 'Court $i',
        'bookingQuantity': 3,
        'priceAmountCents': 135000,
        'currency': 'PHP',
        'scheduledStartAt': '2026-10-09T17:30:00+08:00',
        'scheduledEndAt': '2026-10-09T20:30:00+08:00',
      },
  ],
  'paymentReference': 'BANK-123',
  'paymentProof': {'fileName': 'receipt.png'},
};

class PresentationApi implements BookingApi {
  int proofRequests = 0;
  bool failProof = true;
  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    if (path.endsWith('/payment-proof')) {
      proofRequests++;
      if (failProof) throw StateError('offline');
      return {
        'access': {'url': 'https://example.com/private-receipt.png'},
      };
    }
    return {'booking': sampleBooking()};
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async => {};
}

void main() {
  test('single-service fallback multiplies price once by quantity', () {
    final items = bookingServiceItems(
      CustomerBooking({
        'serviceName': 'Court',
        'servicePriceAmountCents': 45000,
        'bookingQuantity': 3,
        'scheduledStartAt': '2026-10-09T17:30:00+08:00',
      }),
    );
    expect(items.single['priceAmountCents'], 135000);
    expect(bookingMoney(405000, 'PHP'), '₱4,050.00');
  });
  test('bundle snapshots take precedence over current service price', () {
    final items = bookingServiceItems(
      CustomerBooking({...sampleBooking(), 'servicePriceAmountCents': 1}),
    );
    expect(items.length, 3);
    expect(items.first['priceAmountCents'], 135000);
  });
  testWidgets(
    'phone layout shows bundled total, quantities, customer and private proof retry',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = PresentationApi();
      await tester.pumpWidget(
        ShadcnApp(
          home: BookingDetailPage(
            repository: BookingRepository(api),
            booking: CustomerBooking(sampleBooking()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Total fee ₱4,050.00'), findsOneWidget);
      expect(find.text('×3'), findsNWidgets(3));
      expect(find.text('₱1,350.00'), findsNWidgets(3));
      expect(find.text('Lucas'), findsOneWidget);
      expect(find.text('09990000000'), findsOneWidget);
      expect(api.proofRequests, 0);
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const Key('booking-view-proof'))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('booking-view-proof')));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not open payment proof. Please try again.'),
        findsOneWidget,
      );
      api.failProof = false;
      await tester.tap(find.byKey(const Key('booking-view-proof')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('booking-image-viewer')), findsOneWidget);
      expect(api.proofRequests, 2);
      await tester.tap(find.byKey(const Key('booking-image-close')));
      await tester.pumpAndSettle();
      expect(find.text('BANK-123'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
