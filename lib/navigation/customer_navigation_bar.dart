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
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      spacing: 0,
      selectedKey: ValueKey(selectedDestination),
      onSelected: (key) {
        if (key is ValueKey<CustomerDestination>) {
          onDestinationSelected(key.value);
        }
      },
      children: [
        _destinationItem(
          context: context,
          destination: CustomerDestination.home,
          label: 'Home',
          icon: LucideIcons.house,
        ),
        _destinationItem(
          context: context,
          destination: CustomerDestination.explore,
          label: 'Explore',
          icon: LucideIcons.compass,
          enabled: false,
        ),
        _joinQueueAction(context),
        _destinationItem(
          context: context,
          destination: CustomerDestination.tickets,
          label: 'Tickets',
          icon: LucideIcons.ticket,
        ),
        _destinationItem(
          context: context,
          destination: CustomerDestination.account,
          label: 'Profile',
          icon: LucideIcons.circleUserRound,
        ),
      ],
    );
  }

  NavigationItem _destinationItem({
    required BuildContext context,
    required CustomerDestination destination,
    required String label,
    required IconData icon,
    bool enabled = true,
  }) {
    final selected = selectedDestination == destination;
    final color = selected
        ? GetPrioTheme.orange
        : enabled
        ? GetPrioTheme.ink
        : GetPrioTheme.disabled;
    return NavigationItem(
      key: ValueKey(destination),
      enabled: enabled,
      label: Text(
        label,
        style: Theme.of(context).typography.xSmall
            .copyWith(color: color, fontWeight: FontWeight.w500),
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
        spacing: 4,
        label: Text(
          'Join Queue',
          key: const Key('join-queue-menu-label'),
          maxLines: 1,
          overflow: TextOverflow.visible,
          textAlign: TextAlign.center,
          style: Theme.of(context).typography.xSmall.copyWith(
            color: GetPrioTheme.orange,
            fontWeight: FontWeight.w500,
          ),
        ),
        child: Semantics(
          button: true,
          label: 'Join Queue',
          excludeSemantics: true,
          child: Container(
            key: const Key('join-queue-menu-circle'),
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
              boxShadow: const [GetPrioTheme.primaryActionShadow],
            ),
            child: const Icon(
              LucideIcons.scanQrCode,
              color: GetPrioTheme.onPrimary,
              size: 34,
            ),
          ),
        ),
      ),
    );
  }
}
