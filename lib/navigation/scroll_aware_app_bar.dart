import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../app_theme.dart';

/// The shared app bar with a stable paper surface background.
class ScrollAwareAppBar extends StatelessWidget {
  const ScrollAwareAppBar({
    super.key,
    this.title,
    this.leading = const [],
    this.trailing = const [],
  });

  final Widget? title;
  final List<Widget> leading;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: title,
      leading: leading,
      trailing: trailing,
      backgroundColor: GetPrioTheme.paper,
      surfaceBlur: 0,
      surfaceOpacity: 0,
    );
  }
}
