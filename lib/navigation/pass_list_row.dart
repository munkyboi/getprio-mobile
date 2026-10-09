import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../app_theme.dart';

/// Shared plain row layout for ticket and booking lists.
class PassListRow extends StatelessWidget {
  const PassListRow({
    super.key,
    required this.icon,
    required this.children,
    required this.statuses,
    required this.onPressed,
    this.divider = false,
  });
  final IconData icon;
  final List<Widget> children, statuses;
  final VoidCallback onPressed;
  final bool divider;
  @override
  Widget build(BuildContext context) => Button(
    style: const ButtonStyle.ghost(density: ButtonDensity.compact),
    onPressed: onPressed,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: divider
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(color: GetPrioTheme.colors(context).line),
              ),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: GetPrioTheme.colors(context).paperAccent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ...statuses,
                const SizedBox(height: 8),
                Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: GetPrioTheme.colors(context).mutedInk,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
