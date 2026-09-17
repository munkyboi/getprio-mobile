import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'app_theme.dart';
import 'auth/auth_repository.dart';
import 'auth/password_utils.dart';
import 'feedback_toast.dart';

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
