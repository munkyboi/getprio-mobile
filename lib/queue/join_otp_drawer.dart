import 'dart:async';

import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../auth/auth_repository.dart';
import '../form_validation.dart';
import '../keyboard_avoidance.dart';
import '../navigation/app_drawer.dart';
import '../otp_input.dart';
import 'join_repository.dart';

/// Verification owns its code, cooldown and errors until it returns a join result.
class JoinOtpDrawer extends StatefulWidget {
  const JoinOtpDrawer({
    super.key,
    required this.repository,
    required this.challenge,
    required this.messageFor,
  });
  final JoinRepository repository;
  final JoinEmailVerification challenge;
  final String Function(Object) messageFor;
  @override
  State<JoinOtpDrawer> createState() => _JoinOtpDrawerState();
}

class _JoinOtpDrawerState extends State<JoinOtpDrawer>
    with FormValidationMixin {
  final _code = TextEditingController();
  late JoinEmailVerification _challenge;
  Timer? _timer;
  bool _busy = false, _finished = false;
  @override
  bool get formBusy => _busy;
  bool get _expired => _challenge.expiresAt?.isBefore(DateTime.now()) ?? false;
  int get _seconds => _challenge.resendAvailableAt == null
      ? 0
      : _challenge.resendAvailableAt!.difference(DateTime.now()).inSeconds + 1;
  @override
  void initState() {
    super.initState();
    _challenge = widget.challenge;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy ||
        _finished ||
        _expired ||
        !validateForm({_code: codeField(_code.text)})) {
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await widget.repository.verifyEmail(
        _challenge,
        _code.text,
      );
      if (mounted) {
        _finished = true;
        closeDrawer(context, result);
      }
    } catch (error) {
      if (mounted) {
        showFormError(
          error,
          widget.messageFor(error),
          field: error is ApiException && error.statusCode == 400
              ? _code
              : null,
        );
      }
    } finally {
      if (mounted && !_finished) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_busy || _seconds > 0 || _challenge.resendsRemaining <= 0) return;
    setState(() => _busy = true);
    try {
      final challenge = await widget.repository.resendEmail(_challenge);
      if (mounted) {
        setState(() {
          _challenge = challenge;
          _code.clear();
        });
        formValidation.setErrors({});
      }
    } catch (error) {
      if (mounted) {
        showFormError(
          error,
          widget.messageFor(error),
          field: error is ApiException && error.statusCode == 400
              ? _code
              : null,
        );
      }
    } finally {
      if (mounted && !_finished) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Container(
      key: const Key('queue-join-otp-drawer'),
      color: appDrawerBackground(context),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .8,
      ),
      child: KeyboardAwareScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppDrawerTitle('Verify your email'),
            const SizedBox(height: 16),
            Text(
              'Enter the 6-digit code sent to ${_challenge.email} to join this queue.',
            ),
            const SizedBox(height: 16),
            GetPrioOtpInput(
              inputKey: const Key('queue-join-otp'),
              controller: _code,
              enabled: !_busy && !_expired,
              validation: formValidation,
              onCompleted: (_) => unawaited(_verify()),
              trailing: OtpResendButton(
                key: const Key('queue-join-otp-resend'),
                secondsRemaining: _seconds,
                limitReached: _challenge.resendsRemaining <= 0,
                onPressed: _busy ? null : _resend,
              ),
            ),
            if (_expired)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('This code has expired. Request a new code.'),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlineButton(
                    onPressed: _busy ? null : () => closeDrawer(context),
                    alignment: Alignment.center,
                    child: const Text('Cancel', textAlign: TextAlign.center),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PrimaryButton(
                    key: const Key('queue-join-otp-verify'),
                    onPressed: _busy || _expired ? null : _verify,
                    alignment: Alignment.center,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _busy ? 'Please wait...' : 'Continue',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(LucideIcons.arrowRight, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
