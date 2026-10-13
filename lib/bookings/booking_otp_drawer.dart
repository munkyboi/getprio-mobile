import '../network/drawer_request.dart';
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
    this.isPayloadCurrent,
  });
  final BookingRepository repository;
  final String base;
  final Map<String, dynamic> challenge, payload;
  final bool Function()? isPayloadCurrent;
  @override
  State<BookingOtpDrawer> createState() => _BookingOtpDrawerState();
}

class _BookingOtpDrawerState extends State<BookingOtpDrawer>
    with FormValidationMixin {
  final _code = TextEditingController();
  late Map<String, dynamic> _challenge;
  String? _token, _error;
  bool _busy = false, _finished = false, _uncertain = false;
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

  Future<T> _bounded<T>(Future<T> request, void Function(T) onLate) =>
      awaitDrawerRequest(
        request,
        onTimeout: () {
          if (mounted) setState(() => _uncertain = true);
        },
        onLateSuccess: (value) {
          if (mounted && !_finished) {
            setState(() => _uncertain = false);
            onLate(value);
          }
        },
        onLateFailure: (error) {
          if (mounted && !_finished) {
            setState(
              () => _uncertain =
                  !(error is ApiException &&
                      error.statusCode >= 400 &&
                      error.statusCode < 500),
            );
          }
        },
      );

  void _finish(Map<String, dynamic> response) {
    if (!mounted || _finished) return;
    final booking = CustomerBooking(
      response['booking'] as Map<String, dynamic>,
    );
    _finished = true;
    closeDrawer(context, booking);
  }

  Future<void> _submit() async {
    if (_busy ||
        _uncertain ||
        _finished ||
        _expired ||
        !validateForm({_code: codeField(_code.text)})) {
      return;
    }
    if (widget.isPayloadCurrent?.call() == false) {
      setState(
        () => _error = 'Services changed. Return to Booking details and choose an available time again.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_token == null) {
        final verified = await _bounded(
          widget.repository.api.post('${widget.base}/booking-otp/verify', {
            'otpId': _challenge['otpId'],
            'code': _code.text,
          }),
          (late) {
            _token = late['bookingVerificationToken'] as String?;
            setState(() => _error = 'Email verified. Continue when ready.');
          },
        );
        _token = verified['bookingVerificationToken'] as String?;
        if (_token == null) throw StateError('Missing verification token');
      }
      if (!mounted) return;
      if (widget.isPayloadCurrent?.call() == false) {
        setState(
          () => _error = 'Services changed. Return to Booking details and choose an available time again.',
        );
        return;
      }
      final response = await _bounded(
        widget.repository.api.post('/api/account/bookings', {
          ...widget.payload,
          'bookingVerificationToken': _token,
        }),
        _finish,
      );
      _finish(response);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is TimeoutException
              ? 'This request is still processing. You can return to Booking details; check Bookings before trying again.'
              : e is ApiException
              ? e.message
              : 'Could not submit your booking. Please try again.',
        );
      }
    } finally {
      if (mounted && !_finished) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_busy || _uncertain || _resendSeconds > 0) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await _bounded(
        widget.repository.api.post(
          '${widget.base}/booking-otp/${Uri.encodeComponent('${_challenge['otpId']}')}/resend',
          {},
        ),
        (late) {
          setState(() {
            _challenge = late;
            _token = null;
            _code.clear();
          });
        },
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
          () => _error = e is TimeoutException
              ? 'Resend is still processing. You can return to Booking details.'
              : e is ApiException
              ? e.message
              : 'Could not resend the code.',
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
                enabled: !_busy && !_uncertain && !_expired,
                validation: formValidation,
                trailing: OtpResendButton(
                  key: const Key('booking-otp-resend'),
                  secondsRemaining: _resendSeconds,
                  onPressed: _busy || _uncertain ? null : _resend,
                ),
              ),
              if (_expired)
                const Text('This code has expired. Request a new code.'),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!),
              ],
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
                      onPressed: _busy || _uncertain || _expired
                          ? null
                          : _submit,
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
    ),
  );
}
