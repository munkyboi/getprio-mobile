import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Historical content remains scrollable without an overscroll refresh action.
Widget withPullToRefresh({
  Key? key,
  required bool enabled,
  required Future<void> Function() onRefresh,
  required Widget child,
}) => enabled
    ? RefreshTrigger(key: key, onRefresh: onRefresh, child: child)
    : child;
