import 'dart:math' as math;

import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../app_theme.dart';

/// Shared screen header: title stays centered regardless of back/actions.
class ScrollAwareAppBar extends StatelessWidget {
  const ScrollAwareAppBar({
    super.key,
    this.title,
    this.leading = const [],
    this.trailing = const [],
  });
  final Widget? title;
  final List<Widget> leading, trailing;
  @override
  Widget build(BuildContext context) => AppBar(
    backgroundColor: GetPrioTheme.colors(context).paper,
    surfaceBlur: 0,
    surfaceOpacity: 0,
    child: SizedBox(
      height: 48,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (title != null)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal:
                    math.max(leading.length, trailing.length) * 48.0 + 8,
              ),
              child: DefaultTextStyle.merge(
                style: const TextStyle(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
                child: title!,
              ),
            ),
          if (leading.isNotEmpty)
            Positioned(
              left: 0,
              child: Row(mainAxisSize: MainAxisSize.min, children: leading),
            ),
          if (trailing.isNotEmpty)
            Positioned(
              right: 0,
              child: Row(mainAxisSize: MainAxisSize.min, children: trailing),
            ),
        ],
      ),
    ),
  );
}

/// Shared back action for app bars and vendor hero headers.
class GetPrioBackButton extends StatelessWidget {
  const GetPrioBackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = GetPrioTheme.colors(context);
    return Semantics(
      button: true,
      label: 'Back',
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: colors.dark ? colors.card : const Color(0xFFFFFFFF),
          shape: BoxShape.circle,
          border: colors.dark ? Border.all(color: colors.line) : null,
        ),
        child: IconButton.ghost(
          shape: ButtonShape.circle,
          onPressed: onPressed,
          icon: Icon(LucideIcons.arrowLeft, size: 22, color: colors.ink),
        ),
      ),
    );
  }
}
