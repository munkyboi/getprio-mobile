import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'app_theme.dart';

/// Shows short-lived feedback for an action the customer explicitly started.
///
/// Initial load failures should remain inline so navigation does not produce
/// unexpected notifications. Use this for refreshes and submitted actions.
void showFeedbackToast(
  BuildContext context, {
  required String message,
  bool isError = false,
}) {
  final theme = Theme.of(context);
  showToast(
    context: context,
    location: ToastLocation.topCenter,
    showDuration: const Duration(seconds: 3),
    builder: (context, _) {
      final background = isError
          ? theme.colorScheme.destructive
          : GetPrioTheme.success;
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isError ? LucideIcons.triangleAlert : LucideIcons.check,
                  color: GetPrioTheme.onPrimary,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    message,
                    style: theme.typography.small.copyWith(
                      color: GetPrioTheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
