import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../navigation/pass_list_row.dart';
import 'queue_models.dart';

/// The same ticket presentation in Lists overview and Tickets history.
class TicketListRow extends StatelessWidget {
  const TicketListRow({
    super.key,
    required this.ticket,
    required this.onPressed,
  });
  final QueueTicket ticket;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => PassListRow(
    icon: LucideIcons.ticket,
    onPressed: onPressed,
    statuses: [TicketStatusBadge(ticket: ticket)],
    children: [
      Text(ticket.vendorName ?? 'Queue ticket').h4(),
      const SizedBox(height: 4),
      Text('Ticket #${ticket.ticketNumber ?? ticket.lookupCode}'),
      if (ticket.locationName != null) Text(ticket.locationName!),
      if (ticket.joinedAt != null) ...[
        const SizedBox(height: 4),
        Text(_dateLabel(ticket.joinedAt!)),
      ],
    ],
  );
  static String _dateLabel(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}

class TicketStatusBadge extends StatelessWidget {
  const TicketStatusBadge({super.key, required this.ticket});

  final QueueTicket ticket;

  @override
  Widget build(BuildContext context) {
    final status = ticket.status;
    final label = ticket.displayStatusLabel.toUpperCase();
    if (ticket.isInService) return PrimaryBadge(child: Text(label));
    if (ticket.isServiceInterrupted) {
      return DestructiveBadge(child: Text(label));
    }
    if (ticket.isServiceCompleted) return SecondaryBadge(child: Text(label));
    return switch (status) {
      TicketStatus.waiting => SecondaryBadge(child: Text(label)),
      TicketStatus.pendingCarryOver => SecondaryBadge(child: Text(label)),
      TicketStatus.called => PrimaryBadge(child: Text(label)),
      TicketStatus.served => SecondaryBadge(child: Text(label)),
      TicketStatus.skipped => DestructiveBadge(child: Text(label)),
      TicketStatus.cancelled => DestructiveBadge(child: Text(label)),
      TicketStatus.unserved => DestructiveBadge(child: Text(label)),
      TicketStatus.expired => DestructiveBadge(child: Text(label)),
      TicketStatus.unknown => OutlineBadge(child: Text(label)),
    };
  }
}
