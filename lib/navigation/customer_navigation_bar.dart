import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../app_theme.dart';

enum CustomerDestination { home, explore, tickets, account }

class CustomerNavigationBar extends StatelessWidget {
  const CustomerNavigationBar({
    super.key,
    required this.selectedDestination,
    required this.onDestinationSelected,
    required this.onJoinQueue,
  });

  final CustomerDestination selectedDestination;
  final ValueChanged<CustomerDestination> onDestinationSelected;
  final VoidCallback onJoinQueue;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      key: const Key('customer-main-menu'),
      backgroundColor: GetPrioTheme.paper,
      alignment: NavigationBarAlignment.spaceBetween,
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
      spacing: 0,
      selectedKey: ValueKey(selectedDestination),
      onSelected: (key) {
        if (key is ValueKey<CustomerDestination>) {
          onDestinationSelected(key.value);
        }
      },
      children: [
        _destinationItem(
          destination: CustomerDestination.home,
          label: 'Home',
          icon: LucideIcons.house,
        ),
        _destinationItem(
          destination: CustomerDestination.explore,
          label: 'Explore',
          icon: LucideIcons.compass,
        ),
        _joinQueueAction(context),
        _destinationItem(
          destination: CustomerDestination.tickets,
          label: 'Tickets',
          icon: LucideIcons.ticket,
        ),
        _destinationItem(
          destination: CustomerDestination.account,
          label: 'Account',
          icon: LucideIcons.circleUserRound,
        ),
      ],
    );
  }

  NavigationItem _destinationItem({
    required CustomerDestination destination,
    required String label,
    required IconData icon,
  }) {
    final selected = selectedDestination == destination;
    final color = selected ? GetPrioTheme.orange : GetPrioTheme.ink;
    return NavigationItem(
      key: ValueKey(destination),
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      style: const ButtonStyle.ghost(density: ButtonDensity.icon),
      selectedStyle: const ButtonStyle.ghost(density: ButtonDensity.icon),
      child: Icon(icon, color: color),
    );
  }

  Widget _joinQueueAction(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -28),
      child: NavigationButton(
        key: const Key('join-queue-menu-action'),
        onPressed: onJoinQueue,
        style: const ButtonStyle.ghost(density: ButtonDensity.icon),
        child: Semantics(
          button: true,
          label: 'Join Queue',
          excludeSemantics: true,
          child: Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
              boxShadow: const [GetPrioTheme.primaryActionShadow],
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.scanQrCode,
                    color: GetPrioTheme.onPrimary,
                    size: 26,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Join Queue',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: GetPrioTheme.onPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
