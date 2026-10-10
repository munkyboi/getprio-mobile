import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'form_validation.dart';

/// The shadcn obscured display with one editor for paste, autofill and deletion.
class GetPrioOtpInput extends StatefulWidget {
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
  State<GetPrioOtpInput> createState() => _GetPrioOtpInputState();
}

class _GetPrioOtpInputState extends State<GetPrioOtpInput> {
  String? _completed;

  void _changed(String code) {
    widget.onChanged?.call(code);
    if (code.length != 6) {
      _completed = null;
      return;
    }
    if (_completed == code) return;
    _completed = code;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !widget.enabled ||
          widget.controller.text != code ||
          _completed != code) {
        return;
      }
      FocusManager.instance.primaryFocus?.unfocus();
      widget.onCompleted?.call(code);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        if (widget.controller.text.length < 6) _completed = null;
        final field = KeyboardAwareInput(
          child: IntrinsicWidth(
            child: Stack(
              children: [
                ExcludeSemantics(
                  child: ExcludeFocus(
                    child: IgnorePointer(
                      child: InputOTP(
                        // InputOTP initialValue does not update existing digits.
                        key: ValueKey(widget.controller.text),
                        initialValue: List.generate(
                          6,
                          (index) => index < widget.controller.text.length
                              ? widget.controller.text.codeUnitAt(index)
                              : null,
                        ),
                        children: [
                          for (var i = 0; i < 7; i++)
                            if (i == 3)
                              InputOTPChild.separator
                            else
                              InputOTPChild.character(
                                allowDigit: true,
                                obscured: true,
                                readOnly: true,
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Opacity(
                    opacity: 0,
                    alwaysIncludeSemantics: true,
                    child: TextField(
                      key: widget.inputKey,
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      enabled: widget.enabled,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      onChanged: _changed,
                      onTap: widget.onTap,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.label,
              style: Theme.of(context).typography.small
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Semantics(
              label: '${widget.label}, 6 digits',
              child: widget.validation == null
                  ? field
                  : ValidatedField(
                      validation: widget.validation!,
                      controller: widget.controller,
                      child: field,
                    ),
            ),
          ],
        );
      },
    );
  }
}
