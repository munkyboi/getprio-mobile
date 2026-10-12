import '../keyboard_avoidance.dart';

import 'dart:async';

import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../auth/auth_repository.dart';
import '../form_validation.dart';
import '../navigation/app_drawer.dart';
import '../otp_input.dart';
import 'booking_repository.dart';

/// Owns verification and retries against the immutable OTP-bound booking payload.
class BookingOtpDrawer extends StatefulWidget {
  const BookingOtpDrawer({
    super.key,
    required this.repository,
    required this.base,
    required this.challenge,
    required this.payload,
  });
  final BookingRepository repository;
  final String base;
  final Map<String, dynamic> challenge, payload;
  @override
  State<BookingOtpDrawer> createState() => _BookingOtpDrawerState();
}

class _BookingOtpDrawerState extends State<BookingOtpDrawer>
    with FormValidationMixin {
  final _code = TextEditingController();
  late Map<String, dynamic> _challenge;
  String? _token, _error;
  bool _busy = false, _finished = false;
  Timer? _timer;
  @override
  bool get formBusy => _busy;
  int get _resendSeconds =>
      (DateTime.tryParse('${_challenge['resendAvailableAt']}')
              ?.difference(DateTime.now())
              .inSeconds ??
          -1) +
      1;
  bool get _expired =>
      DateTime.tryParse('${_challenge['expiresAt']}')
          ?.isBefore(DateTime.now()) ??
      false;
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

  Future<void> _submit() async {
    if (_busy ||
        _finished ||
        _expired ||
        !validateForm({_code: codeField(_code.text)})) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_token == null) {
        final verified = await widget.repository.api.post(
          '${widget.base}/booking-otp/verify',
          {'otpId': _challenge['otpId'], 'code': _code.text},
        );
        _token = verified['bookingVerificationToken'] as String?;
        if (_token == null) throw StateError('Missing verification token');
      }
      final response = await widget.repository.api.post(
        '/api/account/bookings',
        {...widget.payload, 'bookingVerificationToken': _token},
      );
      if (mounted) {
        _finished = true;
        closeDrawer(
          context,
          CustomerBooking(response['booking'] as Map<String, dynamic>),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Could not submit your booking. Please try again.',
        );
      }
    } finally {
      if (mounted && !_finished) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_busy || _resendSeconds > 0) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await widget.repository.api.post(
        '${widget.base}/booking-otp/${Uri.encodeComponent('${_challenge['otpId']}')}/resend',
        {},
      );
      if (mounted) {
        setState(() {
          _challenge = response;
          _token = null;
          _code.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Could not resend the code.',
        );
      }
    } finally {
      if (mounted && !_finished) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('booking-otp-drawer'),
    color: appDrawerBackground(context),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .8,
      ),
      child: KeyboardAwareScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppDrawerTitle('Verify email'),
            const SizedBox(height: 16),
            Text(
              'Enter the code sent to ${_challenge['deliveryTarget'] ?? widget.payload['customerEmail']}.',
            ),
            const SizedBox(height: 16),
            GetPrioOtpInput(
              controller: _code,
              onCompleted: (_) => unawaited(_submit()),
              enabled: !_busy && !_expired,
              validation: formValidation,
              trailing: Semantics(
                label: _resendSeconds > 0
                    ? 'Resend code in $_resendSeconds seconds'
                    : 'Resend code',
                child: GhostButton(
                  key: const Key('booking-otp-resend'),
                  onPressed: _busy || _resendSeconds > 0 ? null : _resend,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.history, size: 18),
                      const SizedBox(width: 4),
                      Text(_resendSeconds > 0 ? '${_resendSeconds}s' : 'Resend'),
                    ],
                  ),
                ),
              ),
            ),
            if (_expired)
              const Text('This code has expired. Request a new code.'),
            if (_error != null) ...[const SizedBox(height: 12), Text(_error!)],
            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: OutlineButton(
                    key: const Key('booking-otp-details'),
                    alignment: Alignment.center,
                    onPressed: _busy ? null : () => closeDrawer(context),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.undo2, size: 18),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Booking details',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PrimaryButton(
                    key: const Key('booking-otp-submit'),
                    alignment: Alignment.center,
                    onPressed: _busy || _expired ? null : _submit,
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
