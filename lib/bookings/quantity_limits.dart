import 'booking_repository.dart';

/// Vendor bounds are preserved on the service; this range also honors the
/// supported 24-hour duration ceiling for a new booking.
class BookingQuantityBounds {
  const BookingQuantityBounds(this.min, this.max);
  final int min, max;
  bool get isValid => min >= 1 && min <= max;
  bool get isFixed => isValid && min == max;
  int clamp(int value) => value.clamp(min, max);
}

BookingQuantityBounds quantityBounds(BookingService service) {
  if (!service.allowQuantity) return const BookingQuantityBounds(1, 1);
  final durationMax = service.durationMinutes > 0
      ? 1440 ~/ service.durationMinutes
      : 24;
  return BookingQuantityBounds(
    service.quantityMin,
    service.quantityMax < durationMax ? service.quantityMax : durationMax,
  );
}

BookingQuantityBounds? sharedQuantityBounds(
  List<BookingService> selected,
  String mode,
) {
  if (mode != 'parallel' ||
      selected.length < 2 ||
      !selected.every(
        (service) =>
            service.allowQuantity &&
            service.durationMinutes == selected.first.durationMinutes,
      )) {
    return null;
  }
  var min = 1, max = 24;
  for (final service in selected) {
    final bounds = quantityBounds(service);
    if (!bounds.isValid) return null;
    if (bounds.min > min) min = bounds.min;
    if (bounds.max < max) max = bounds.max;
  }
  return min <= max ? BookingQuantityBounds(min, max) : null;
}

/// Only selected compatible services share bounds. Catalog quantities always
/// retain their own range; non-unit services remain quantity one.
Map<String, int> reconcileBookingQuantities(
  List<BookingService> catalog,
  Set<String> selected,
  String mode,
  Map<String, int> quantities,
) {
  final next = <String, int>{};
  for (final service in catalog) {
    final bounds = quantityBounds(service);
    next[service.slug] = bounds.isValid
        ? bounds.clamp(quantities[service.slug] ?? bounds.min)
        : bounds.min;
  }
  final selectedServices = catalog
      .where((s) => selected.contains(s.slug))
      .toList();
  final shared = sharedQuantityBounds(selectedServices, mode);
  if (shared != null) {
    var largest = shared.min;
    for (final service in selectedServices) {
      if (next[service.slug]! > largest) largest = next[service.slug]!;
    }
    final value = shared.clamp(largest);
    for (final service in selectedServices) {
      next[service.slug] = value;
    }
  }
  return next;
}
