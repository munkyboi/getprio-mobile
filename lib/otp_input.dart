import 'package:flutter/services.dart';
import 'package:flutter/material.dart'
    show Material, MaterialType, DefaultMaterialLocalizations;
import 'package:pinput/pinput.dart';
import 'package:flutter/cupertino.dart' show DefaultCupertinoLocalizations;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'app_theme.dart';
import 'form_validation.dart';

/// One editable value, rendered as six boxes, preserves paste and OTP autofill.
class GetPrioOtpInput extends StatelessWidget {
  const GetPrioOtpInput({
    super.key,
    required this.controller,
    this.inputKey,
    this.focusNode,
    this.label = 'Verification code',
    this.enabled = true,
    this.validation,
    this.onChanged,
    this.onCompleted,
    this.onTap,
  });

  final TextEditingController controller;
  final Key? inputKey;
  final FocusNode? focusNode;
  final String label;
  final bool enabled;
  final FormValidation? validation;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, ?validation]),
      builder: (context, _) {
        final error = validation?.errorFor(controller);
        final field = KeyboardAwareInput(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const gap = 8.0;
              final width = ((constraints.maxWidth - gap * 5) / 6).clamp(
                24.0,
                52.0,
              );
              final base = PinTheme(
                width: width,
                height: 56,
                textStyle: Theme.of(context).typography.h3
                    .copyWith(color: GetPrioTheme.colors(context).ink),
                decoration: BoxDecoration(
                  color: GetPrioTheme.colors(context).card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GetPrioTheme.colors(context).line),
                ),
              );
              PinTheme themed(Color border, Color background) => base.copyWith(
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border, width: 2),
                ),
              );
              return Semantics(
                label: '$label, 6 digits',
                child: Localizations.override(
                  context: context,
                  delegates: const [
                    DefaultMaterialLocalizations.delegate,
                    DefaultCupertinoLocalizations.delegate,
                  ],
                  child: Material(
                    type: MaterialType.transparency,
                    child: Pinput(
                      key: inputKey,
                      length: 6,
                      controller: controller,
                      focusNode: focusNode,
                      enabled: enabled,
                      defaultPinTheme: base,
                      focusedPinTheme: themed(
                        GetPrioTheme.primary,
                        GetPrioTheme.colors(context).card,
                      ),
                      submittedPinTheme: themed(
                        GetPrioTheme.colors(context).teal,
                        GetPrioTheme.colors(context).paper,
                      ),
                      errorPinTheme: themed(
                        GetPrioTheme.destructive,
                        GetPrioTheme.colors(context).card,
                      ),
                      disabledPinTheme: themed(
                        GetPrioTheme.colors(context).line,
                        GetPrioTheme.colors(context).paper,
                      ),
                      forceErrorState: error != null,
                      separatorBuilder: (_) => const SizedBox(width: gap),
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      closeKeyboardWhenCompleted: false,
                      isCursorAnimationEnabled: false,
                      enableSuggestions: false,
                      onChanged: onChanged,
                      onCompleted: onCompleted,
                      onTap: onTap,
                    ),
                  ),
                ),
              );
            },
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              style: Theme.of(context).typography.small
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (validation == null)
              field
            else
              ValidatedField(
                validation: validation!,
                controller: controller,
                child: field,
              ),
          ],
        );
      },
    );
  }
}
