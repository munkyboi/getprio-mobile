import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Shared drawer presentation: zoomed backdrop and no gap below the grabber.
DrawerOverlayCompleter<T?> openAppDrawer<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  required OverlayPosition position,
  bool expands = false,
  bool draggable = true,
  bool barrierDismissible = true,
  bool useSafeArea = true,
  BorderRadiusGeometry? borderRadius,
  BoxConstraints? constraints,
}) {
  final theme = ComponentTheme.maybeOf<DrawerTheme>(context);
  return openRawDrawer<T>(
    anchor: ContextAnchor(context),
    barrierDismissible: barrierDismissible,
    position: position,
    useSafeArea: useSafeArea,
    transformBackdrop: true,
    constraints: constraints,
    builder: (context, extraSize, size, padding, stackIndex) => DrawerWrapper(
      position: position,
      expands: expands,
      draggable: draggable,
      extraSize: extraSize,
      size: size,
      padding: padding,
      stackIndex: stackIndex,
      borderRadius: borderRadius,
      showDragHandle: theme?.showDragHandle ?? true,
      dragHandleSize: theme?.dragHandleSize,
      surfaceOpacity: theme?.surfaceOpacity,
      surfaceBlur: theme?.surfaceBlur,
      barrierColor: theme?.barrierColor,
      gapAfterDragger: 0,
      child: Builder(builder: builder),
    ),
  );
}
