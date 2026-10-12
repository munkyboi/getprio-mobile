import 'dart:math' as math;

import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../app_theme.dart';

/// Page scope for headers that observe the primary content scroll.
class ScrollAwareScaffold extends StatelessWidget {
  const ScrollAwareScaffold({
    super.key,
    required this.child,
    this.headers = const [],
    this.resizeToAvoidBottomInset,
  });
  final Widget child;
  final List<Widget> headers;
  final bool? resizeToAvoidBottomInset;
  @override
  Widget build(BuildContext context) => ScrollNotificationObserver(
    child: Scaffold(
      headers: headers,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      child: child,
    ),
  );
}

/// Transparent header with a centered title sliding out over 100px of scroll.
class ScrollAwareAppBar extends StatefulWidget {
  const ScrollAwareAppBar({
    super.key,
    this.title,
    this.leading = const [],
    this.trailing = const [],
  });
  final Widget? title;
  final List<Widget> leading, trailing;
  @override
  State<ScrollAwareAppBar> createState() => _ScrollAwareAppBarState();
}

class _ScrollAwareAppBarState extends State<ScrollAwareAppBar> {
  ScrollNotificationObserverState? _observer;
  double _progress = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final observer = ScrollNotificationObserver.maybeOf(context);
    if (identical(observer, _observer)) return;
    _observer?.removeListener(_onScroll);
    _observer = observer;
    _observer?.addListener(_onScroll);
  }

  void _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 ||
        notification.metrics.axis != Axis.vertical ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    final progress =
        ((notification.metrics.pixels - notification.metrics.minScrollExtent) /
                100)
            .clamp(0.0, 1.0);
    if (progress != _progress) setState(() => _progress = progress);
  }

  @override
  void dispose() {
    _observer?.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppBar(
    backgroundColor: Colors.transparent,
    surfaceBlur: 0,
    surfaceOpacity: 0,
    child: SizedBox(
      height: 48,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.title != null)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal:
                    math.max(widget.leading.length, widget.trailing.length) *
                        48.0 +
                    8,
              ),
              child: ClipRect(
                child: ExcludeSemantics(
                  excluding: _progress >= 1,
                  child: FractionalTranslation(
                    key: const Key('app-bar-scrolling-title'),
                    translation: Offset(0, -_progress),
                    child: DefaultTextStyle.merge(
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                      child: widget.title!,
                    ),
                  ),
                ),
              ),
            ),
          if (widget.leading.isNotEmpty)
            Positioned(
              left: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: widget.leading,
              ),
            ),
          if (widget.trailing.isNotEmpty)
            Positioned(
              right: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: widget.trailing,
              ),
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
