import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

double keyboardInsetOf(BuildContext context) {
  final mediaQueryInset = MediaQuery.viewInsetsOf(context).bottom;
  if (mediaQueryInset > 0) return mediaQueryInset;
  return MediaQueryData.fromView(View.of(context)).viewInsets.bottom;
}

/// A scroll view that reserves space for the onscreen keyboard.
///
/// This is especially important for forms rendered in overlays and modal
/// bottom sheets, where the overlay itself may not resize when the keyboard
/// appears.
class KeyboardAwareScrollView extends StatefulWidget {
  const KeyboardAwareScrollView({
    super.key,
    required this.child,
    this.padding,
    this.controller,
    this.physics,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.onDrag,
    this.reverse = false,
    this.primary,
    this.scrollDirection = Axis.vertical,
    this.clipBehavior = Clip.hardEdge,
  });

  final Widget child;
  final EdgeInsets? padding;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final bool reverse;
  final bool? primary;
  final Axis scrollDirection;
  final Clip clipBehavior;

  @override
  State<KeyboardAwareScrollView> createState() =>
      _KeyboardAwareScrollViewState();
}

class _KeyboardAwareScrollViewState extends State<KeyboardAwareScrollView>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final basePadding = widget.padding ?? EdgeInsets.zero;
    final keyboardInset = keyboardInsetOf(context);
    final effectivePadding = widget.scrollDirection == Axis.vertical
        ? basePadding.copyWith(bottom: basePadding.bottom + keyboardInset)
        : basePadding;

    return SingleChildScrollView(
      controller: widget.controller,
      padding: effectivePadding,
      physics: widget.physics,
      keyboardDismissBehavior: widget.keyboardDismissBehavior,
      reverse: widget.reverse,
      primary: widget.primary,
      scrollDirection: widget.scrollDirection,
      clipBehavior: widget.clipBehavior,
      child: widget.child,
    );
  }
}

/// Keeps a focused descendant visible above the onscreen keyboard.
///
/// The field is deliberately independent from the concrete text-field
/// widget, so it can be used with the app's shared fields as well as the
/// specialised OTP and review fields.
class KeyboardAwareField extends StatefulWidget {
  const KeyboardAwareField({super.key, required this.builder, this.focusNode});

  final Widget Function(BuildContext context, FocusNode focusNode) builder;
  final FocusNode? focusNode;

  @override
  State<KeyboardAwareField> createState() => _KeyboardAwareFieldState();
}

class _KeyboardAwareFieldState extends State<KeyboardAwareField> {
  final _fieldKey = GlobalKey();
  late final FocusNode _focusNode;
  late final bool _ownsFocusNode;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = (widget.focusNode ?? FocusNode())
      ..addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (_ownsFocusNode) _focusNode.dispose();
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final keyboardInset = keyboardInsetOf(context);
    if (keyboardInset > 0 && _focusNode.hasFocus) {
      _scheduleEnsureVisible();
    }
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) _scheduleEnsureVisible();
  }

  void _scheduleEnsureVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureVisible();
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(milliseconds: 250), () {
        if (mounted) _ensureVisible();
      });
    });
  }

  void _ensureVisible() {
    final fieldContext = _fieldKey.currentContext;
    if (fieldContext == null || !fieldContext.mounted) return;
    final fieldRenderObject = fieldContext.findRenderObject();
    final scrollable = Scrollable.maybeOf(fieldContext);
    if (fieldRenderObject is! RenderBox ||
        !fieldRenderObject.hasSize ||
        scrollable == null ||
        !scrollable.position.hasPixels) {
      return;
    }

    final fieldTop = fieldRenderObject.localToGlobal(Offset.zero).dy;
    final fieldBottom = fieldTop + fieldRenderObject.size.height;
    final mediaQuery = MediaQuery.of(fieldContext);
    final keyboardTop = mediaQuery.size.height - keyboardInsetOf(fieldContext);
    final viewportRenderObject = scrollable.context.findRenderObject();
    final viewportTop = viewportRenderObject is RenderBox
        ? viewportRenderObject.localToGlobal(Offset.zero).dy
        : 0.0;
    final viewportBottom = viewportRenderObject is RenderBox
        ? viewportTop + viewportRenderObject.size.height
        : mediaQuery.size.height;
    const safeGap = 24.0;
    final visibleTop = viewportTop + safeGap;
    final visibleBottom = math.min(
      viewportBottom - safeGap,
      keyboardTop - safeGap,
    );
    final scrollDelta = fieldBottom > visibleBottom
        ? fieldBottom - visibleBottom
        : fieldTop < visibleTop
        ? fieldTop - visibleTop
        : 0.0;
    if (scrollDelta == 0) return;

    final position = scrollable.position;
    final target = (position.pixels + scrollDelta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target == position.pixels) return;
    position.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _fieldKey,
      child: widget.builder(context, _focusNode),
    );
  }
}
