import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/bookings/booking_repository.dart';
import 'package:getprio_mobile/bookings/booking_presentation.dart';
import 'package:getprio_mobile/bookings/quantity_limits.dart';

BookingService service(
  String slug, {
  int min = 1,
  int max = 24,
  int duration = 60,
  bool enabled = true,
}) => BookingService.fromJson({
  'slug': slug,
  'allowBookingQuantity': enabled,
  'bookingQuantityMin': min,
  'bookingQuantityMax': max,
  'durationMinutes': duration,
  'bookingQuantityLabel': 'Hours',
  'priceAmountCents': 10000,
  'priceDisplay': '₱100',
});

void main() {
  test('missing bounds default to 1/24; vendor values retained with effective ceiling', () {
    final defaults = BookingService.fromJson({
      'allowBookingQuantity': true,
      'durationMinutes': 60,
    });
    expect(quantityBounds(defaults).min, 1);
    expect(quantityBounds(defaults).max, 24);
    final bounded = service('court', min: 2, max: 20, duration: 200);
    expect(bounded.quantityMax, 20);
    expect(quantityBounds(bounded).max, 7);
    expect(quantityBounds(bounded).clamp(99), 7);
    expect(quantityBounds(bounded).clamp(0), 2);
    expect(quantityBounds(service('fixed', min: 4, max: 4)).isFixed, isTrue);
    expect(
      quantityBounds(service('bad', min: 8, duration: 200)).isValid,
      isFalse,
    );
  });

  test('non-unit service always quantity1 and original duration/price', () {
    final plain = service('plain', min: 8, max: 10, enabled: false);
    expect(
      reconcileBookingQuantities([plain], {'plain'}, 'parallel', {'plain': 10}),
      {'plain': 1},
    );
    expect(quantityBounds(plain).min, 1);
    expect(quantityBounds(plain).max, 1);
    expect(plain.priceForQuantity(1), '₱100');
    expect(plain.durationMinutes, 60);
  });

  test(
    'selected compatible Together units use intersection and maximum adoption',
    () {
      final a = service('a', min: 2, max: 8), b = service('b', min: 4, max: 6);
      final catalog = service('catalog', min: 10, max: 12);
      final all = [a, b, catalog];
      final shared = sharedQuantityBounds([a, b], 'parallel')!;
      expect([shared.min, shared.max], [4, 6]);
      expect(
        reconcileBookingQuantities(
          all,
          {'a', 'b'},
          'parallel',
          {'a': 3, 'b': 5, 'catalog': 11},
        ),
        {'a': 5, 'b': 5, 'catalog': 11},
      );
      expect(
        reconcileBookingQuantities(
          all,
          {'a', 'b'},
          'parallel',
          {'a': 8, 'b': 4},
        ),
        {'a': 6, 'b': 6, 'catalog': 10},
      );
      expect(catalog.priceForQuantity(1), '₱100');
      expect(catalog.durationMinutes, 60);
    },
  );

  test('sequential, mixed duration, non-unit, one selected and disjoint ranges independent', () {
    final a = service('a', min: 2, max: 3), b = service('b', min: 5, max: 8);
    expect(sharedQuantityBounds([a, b], 'parallel'), isNull);
    expect(
      reconcileBookingQuantities([a, b], {'a', 'b'}, 'parallel', {
        'a': 2,
        'b': 7,
      }),
      {'a': 2, 'b': 7},
    );
    expect(
      sharedQuantityBounds([a, service('short', duration: 30)], 'parallel'),
      isNull,
    );
    expect(
      sharedQuantityBounds([a, service('plain', enabled: false)], 'parallel'),
      isNull,
    );
    expect(sharedQuantityBounds([a], 'parallel'), isNull);
    expect(sharedQuantityBounds([a, service('same')], 'sequential'), isNull);
  });

  test('changed limits reclamp saved draft before request without altering vendor bounds', () {
    final updated = [
      service('a', min: 3, max: 4),
      service('b', min: 2, max: 8, duration: 120),
    ];
    expect(
      reconcileBookingQuantities(
        updated,
        {'a', 'b'},
        'parallel',
        {'a': 1, 'b': 20, 'removed': 9},
      ),
      {'a': 3, 'b': 8},
    );
    expect(updated.first.quantityMin, 3);
    expect(updated.first.quantityMax, 4);
    expect(updated.first.priceForQuantity(3), '₱300.00');
  });

  test('existing booking snapshots remain frozen regardless of changed catalog bounds', () {
    final booking = CustomerBooking({
      'bookingQuantity': 10,
      'serviceDurationMinutes': 600,
      'servicePriceAmountCents': 10000,
      'scheduledStartAt': '2026-10-13T08:00:00Z',
      'scheduledEndAt': '2026-10-13T18:00:00Z',
    });
    reconcileBookingQuantities(
      [service('a', min: 1, max: 2)],
      {'a'},
      'parallel',
      {'a': 10},
    );
    expect(booking.data['bookingQuantity'], 10);
    expect(booking.data['serviceDurationMinutes'], 600);
    final displayed = bookingServiceItems(booking).single;
    expect(displayed['bookingQuantity'], 10);
    expect(displayed['priceAmountCents'], 100000);
    expect(displayed['scheduledEndAt'], '2026-10-13T18:00:00Z');
  });
}
