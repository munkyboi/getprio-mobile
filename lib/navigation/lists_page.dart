import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../app_theme.dart';

class ListsPage extends StatelessWidget {
  const ListsPage({
    super.key,
    required this.onTickets,
    required this.onBookings,
  });
  final VoidCallback onTickets, onBookings;
  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('lists-page'),
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
    children: [
      const Text('Lists').h1(),
      const SizedBox(height: 8),
      const Text('Your tickets and scheduled visits, all in one place.'),
      const SizedBox(height: 24),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              color: GetPrioTheme.teal,
              onPressed: onBookings,
            ),
          ),
        ],
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
    style: const ButtonStyle.ghost(),
    onPressed: onPressed,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GetPrioTheme.card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: GetPrioTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label).bold()),
              const Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: GetPrioTheme.mutedInk,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).typography.small
                .copyWith(color: GetPrioTheme.mutedInk),
          ),
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
