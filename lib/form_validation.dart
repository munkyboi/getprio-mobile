import 'dart:async';

import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'app_theme.dart';
import 'auth/auth_repository.dart';
import 'auth/password_utils.dart';
import 'feedback_toast.dart';

const inputScrollPadding = EdgeInsets.all(24);

const focusedClearInputFeature = InputFeature.clear(
  visibility: InputFeatureVisibility.and([
    InputFeatureVisibility.textNotEmpty,
    InputFeatureVisibility.focused,
  ]),
  icon: Icon(LucideIcons.x, key: ValueKey('focused-clear-input-button')),
);

/// Keeps an input visible when the keyboard changes the available viewport.
///
/// Moves only the focused editor by the amount needed to reveal it, with a
/// 24px margin. Keyboard space belongs to the viewport, never to each field.
/// A settling retry handles native keyboard animations and late drawer layout.
class KeyboardAwareInput extends StatefulWidget {
  const KeyboardAwareInput({super.key, required this.child});

  final Widget child;

  @override
  State<KeyboardAwareInput> createState() => _KeyboardAwareInputState();
}

class _KeyboardAwareInputState extends State<KeyboardAwareInput>
    with WidgetsBindingObserver {
  static const _safeGap = 24.0;
  Timer? _settlingTimer;
  bool _visibilityScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_handleFocusChange);
  }

  @override
  void didChangeMetrics() => _handleFocusChange();

  void _handleFocusChange() {
    _settlingTimer?.cancel();
    _queueVisibilityCheck();
    // iOS may finish its keyboard/overlay layout after the focus frame.
    // Request a frame explicitly: post-frame callbacks alone do not do that.
    _settlingTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _queueVisibilityCheck();
    });
  }

  void _queueVisibilityCheck() {
    if (_visibilityScheduled || !mounted) return;
    _visibilityScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityScheduled = false;
      if (!mounted) return;
      final focusedContext = FocusManager.instance.primaryFocus?.context;
      if (focusedContext != null && _ownsFocusedInput(focusedContext)) {
        _ensureVisible(focusedContext);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  bool _ownsFocusedInput(BuildContext? focusedContext) {
    if (focusedContext == null) return false;
    var ownsFocusedInput = false;
    focusedContext.visitAncestorElements((element) {
      if (element == context) {
        ownsFocusedInput = true;
        return false;
      }
      return true;
    });
    return ownsFocusedInput;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MediaQuery.maybeOf(context);
    _handleFocusChange();
  }

  void _ensureVisible(BuildContext focusedContext) {
    if (!mounted ||
        !focusedContext.mounted ||
        FocusManager.instance.primaryFocus?.context != focusedContext ||
        !_ownsFocusedInput(focusedContext)) {
      return;
    }
    final renderObject = focusedContext.findRenderObject();
    final scrollable = Scrollable.maybeOf(context);
    if (renderObject is! RenderBox ||
        !renderObject.hasSize ||
        scrollable == null) {
      return;
    }

    final fieldTop = renderObject.localToGlobal(Offset.zero).dy;
    final fieldBottom = fieldTop + renderObject.size.height;
    final viewportObject = scrollable.context.findRenderObject();
    final viewportTop = viewportObject is RenderBox && viewportObject.hasSize
        ? viewportObject.localToGlobal(Offset.zero).dy
        : 0.0;
    final viewportBottom = viewportObject is RenderBox && viewportObject.hasSize
        ? viewportTop + viewportObject.size.height
        : double.infinity;
    final viewData = MediaQueryData.fromView(View.of(focusedContext));
    final mediaInset =
        MediaQuery.maybeOf(focusedContext)?.viewInsets.bottom ?? 0;
    final keyboardInset = viewData.viewInsets.bottom > mediaInset
        ? viewData.viewInsets.bottom
        : mediaInset;
    final keyboardTop = viewData.size.height - keyboardInset;
    final visibleTop = viewportTop + _safeGap;
    final visibleBottom =
        (viewportBottom < keyboardTop ? viewportBottom : keyboardTop) -
        _safeGap;
    // A tall textarea cannot fit in the remaining viewport. Let EditableText
    // reveal its caret rather than alternating between its top and bottom.
    if (renderObject.size.height > visibleBottom - visibleTop) return;
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
    position.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _settlingTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    FocusManager.instance.removeListener(_handleFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class FormValidation extends ChangeNotifier {
  final _keys = <TextEditingController, GlobalKey>{};
  GlobalKey keyFor(TextEditingController field) =>
      _keys.putIfAbsent(field, GlobalKey.new);
  void clear(TextEditingController field) {
    _errors.remove(field);
    notifyListeners();
  }

  final _errors = <TextEditingController, (String, String)>{};

  String? errorFor(TextEditingController field) {
    final error = _errors[field];
    return error != null && error.$1 == field.text ? error.$2 : null;
  }

  void setErrors(Map<TextEditingController, String?> errors) {
    _errors.clear();
    for (final entry in errors.entries) {
      if (entry.value != null) {
        _errors[entry.key] = (entry.key.text, entry.value!);
      }
    }
    notifyListeners();
  }
}

mixin FormValidationMixin<T extends StatefulWidget> on State<T> {
  final formValidation = FormValidation();
  bool get formBusy => false;

  bool validateForm(Map<TextEditingController, String?> errors) {
    formValidation.setErrors(errors);
    if (errors.values.every((error) => error == null)) return true;
    final first = errors.entries.firstWhere((entry) => entry.value != null).key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fieldContext = formValidation.keyFor(first).currentContext;
      if (mounted && fieldContext != null && fieldContext.mounted) {
        Scrollable.ensureVisible(
          fieldContext,
          duration: const Duration(milliseconds: 200),
          alignment: .15,
        );
      }
    });
    showFeedbackToast(
      context,
      message: 'Please check the highlighted fields.',
      isError: true,
    );
    return false;
  }

  void showFormError(
    Object error,
    String fallback, {
    TextEditingController? field,
  }) {
    final message = error is ApiException && error.message.isNotEmpty
        ? error.message
        : fallback;
    if (field != null) formValidation.setErrors({field: message});
    showFeedbackToast(
      context,
      message: field == null ? message : 'Please check the highlighted field.',
      isError: true,
    );
  }

  @override
  void dispose() {
    formValidation.dispose();
    super.dispose();
  }
}

class ValidatedField extends StatelessWidget {
  const ValidatedField({
    super.key,
    required this.validation,
    required this.controller,
    required this.child,
  });
  final FormValidation validation;
  final TextEditingController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([validation, controller]),
    builder: (context, _) {
      final error = validation.errorFor(controller);
      return Column(
        key: validation.keyFor(controller),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: error == null
                  ? null
                  : Border.all(color: GetPrioTheme.destructive, width: 2),
            ),
            child: child,
          ),
          if (error != null) ...[
            const SizedBox(height: 4),
            Semantics(
              liveRegion: true,
              child: Text(
                error,
                style: Theme.of(context).typography.small
                    .copyWith(color: GetPrioTheme.destructive),
              ),
            ),
          ],
        ],
      );
    },
  );
}

String? requiredField(String value, String label) =>
    value.trim().isEmpty ? '$label is required.' : null;
String? emailField(String value) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())
    ? null
    : 'Enter a valid email address.';
String? codeField(String value) => RegExp(r'^\d{6}$').hasMatch(value.trim())
    ? null
    : 'Enter the 6-digit verification code.';
String? newPasswordField(String value) =>
    evaluatePasswordStrength(value).isValid
    ? null
    : 'Use 6–32 characters, at least 1 uppercase letter, 2 numbers, and 1 special character.';
