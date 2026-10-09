import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../navigation/pass_list_row.dart';
import 'booking_repository.dart';
import 'booking_presentation.dart';

class BookingListRow extends StatelessWidget {
  const BookingListRow({
    super.key,
    required this.booking,
    required this.onPressed,
  });
  final CustomerBooking booking;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => PassListRow(
    icon: LucideIcons.calendarDays,
    divider: true,
    onPressed: onPressed,
    statuses: [
      BookingStatusBadge(
        status: booking.status,
        label: booking.status.replaceAll('_', ' '),
      ),
      const SizedBox(height: 6),
      BookingStatusBadge(
        status: booking.paymentStatus,
        label: 'Payment: ${booking.paymentStatus.replaceAll('_', ' ')}',
      ),
    ],
    children: [
      Text(booking.vendorName).h4(),
      const SizedBox(height: 4),
      Text(booking.reference.isEmpty ? 'Booking request' : booking.reference),
      if (booking.locationName.isNotEmpty) Text(booking.locationName),
      Text(booking.serviceName, style: Theme.of(context).typography.small),
      const SizedBox(height: 4),
      Text(
        booking.startAt == null
            ? 'Schedule unavailable'
            : '${bookingDay(booking.startAt!)} · ${bookingClock(booking.startAt!)}',
      ),
    ],
  );
}
