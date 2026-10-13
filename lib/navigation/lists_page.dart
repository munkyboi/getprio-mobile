import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../app_theme.dart';
import 'tab_page_header.dart';
import 'lists_overview.dart';
import '../account/ticket_repository.dart';
import '../bookings/booking_repository.dart';
import '../queue/queue_models.dart';

class ListsPage extends StatelessWidget {
  const ListsPage({
    super.key,
    required this.onTickets,
    required this.onBookings,
    this.active = true,
    this.ticketRepository,
    this.bookingRepository,
    this.onOpenTicket,
    this.onOpenBooking,
  });
  final VoidCallback onTickets, onBookings;
  final bool active;
  final QueueTicketRepository? ticketRepository;
  final BookingRepository? bookingRepository;
  final Future<void> Function(QueueTicket)? onOpenTicket;
  final Future<void> Function(CustomerBooking)? onOpenBooking;
  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('lists-page'),
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
    children: [
      const TabPageHeader(
        page: 'lists',
        title: 'Lists',
        description: 'Your tickets and scheduled visits, all in one place.',
      ),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _ListCard(
                label: 'Tickets',
                subtitle: 'Queue tickets',
                icon: LucideIcons.ticket,
                color: GetPrioTheme.primary,
                onPressed: onTickets,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _ListCard(
                label: 'Bookings',
                subtitle: 'Scheduled visits',
                icon: LucideIcons.calendarDays,
                color: GetPrioTheme.colors(context).teal,
                onPressed: onBookings,
              ),
            ),
          ],
        ),
      ),
      ListsOverview(
        active: active,
        ticketRepository: ticketRepository,
        bookingRepository: bookingRepository,
        onOpenTicket: onOpenTicket,
        onOpenBooking: onOpenBooking,
      ),
    ],
  );
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onPressed,
  });
  final String label, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Button(
    key: ValueKey('lists-${label.toLowerCase()}'),
    style: const ButtonStyle.ghost(density: ButtonDensity.compact),
    onPressed: onPressed,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GetPrioTheme.colors(context).card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: GetPrioTheme.colors(context).line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label).bold()),
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: GetPrioTheme.colors(context).mutedInk,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).typography.small
                .copyWith(color: GetPrioTheme.colors(context).mutedInk),
          ),
          const Spacer(),
          const SizedBox(height: 26),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: .08),
                border: Border.all(
                  color: color.withValues(alpha: .16),
                  width: 5,
                ),
              ),
              child: Icon(icon, size: 26, color: color),
            ),
          ),
        ],
      ),
    ),
  );
}
