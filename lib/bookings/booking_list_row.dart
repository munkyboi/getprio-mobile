import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../app_theme.dart';
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
  Widget build(BuildContext context) => Button(
    style: const ButtonStyle.ghost(density: ButtonDensity.compact),
    onPressed: onPressed,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: GetPrioTheme.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(booking.vendorName).bold(),
                const SizedBox(height: 4),
                Text('${booking.locationName} · ${booking.serviceName}'),
                const SizedBox(height: 4),
                Text(
                  booking.startAt == null
                      ? 'Schedule unavailable'
                      : '${bookingDay(booking.startAt!)} · ${bookingClock(booking.startAt!)}',
                  style: Theme.of(context).typography.small,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    BookingStatusBadge(
                      status: booking.status,
                      label: 'Booking: ${booking.status.replaceAll('_', ' ')}',
                    ),
                    BookingStatusBadge(
                      status: booking.paymentStatus,
                      label:
                          'Payment: ${booking.paymentStatus.replaceAll('_', ' ')}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            LucideIcons.chevronRight,
            size: 18,
            color: GetPrioTheme.mutedInk,
          ),
        ],
      ),
    ),
  );
}
