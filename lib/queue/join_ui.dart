import 'dart:async';

import 'package:flutter/services.dart';

import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../app_theme.dart';
import '../form_validation.dart';
import '../feedback_toast.dart';
import '../auth/auth_repository.dart';
import '../navigation/scroll_aware_app_bar.dart';
import 'join_repository.dart';
import 'payment_flow.dart';
import 'queue_models.dart';

class JoinPage extends StatefulWidget {
  const JoinPage({
    super.key,
    required this.repository,
    required this.allowedHosts,
    required this.customerName,
    this.directTenantSlug,
    this.directLocationSlug,
    this.onJoined,
    this.paymentBrowser,
    this.paymentApi,
    this.paymentLinkSource,
  });

  final JoinRepository? repository;
  final Set<String> allowedHosts;
  final String customerName;
  final String? directTenantSlug;
  final String? directLocationSlug;
  final ValueChanged<QueueTicket>? onJoined;
  final PaymentBrowser? paymentBrowser;
  final PaymentApi? paymentApi;
  final PaymentLinkSource? paymentLinkSource;

  @override
  State<JoinPage> createState() => _JoinPageState();
}

class _JoinPageState extends State<JoinPage>
    with FormValidationMixin<JoinPage> {
  final _drawerAnchorKey = GlobalKey();
  QrJoinPayload? _payload;
  QrTicketClaimPayload? _ticketPayload;
  JoinPreview? _preview;
  JoinedTicket? _joinedTicket;
  PaymentRequired? _payment;
  JoinEmailVerification? _emailChallenge;
  final _otpController = TextEditingController();
  Timer? _otpTimer;
  String? _error;
  bool _isBusy = false;
  bool _checkoutSheetOpen = false;
  DrawerOverlayCompleter<void>? _checkoutSheetCompleter;
  BuildContext? _checkoutSheetContext;

  bool get _isDirectJoin => widget.directTenantSlug != null;

  @override
  void initState() {
    super.initState();
    if (_isDirectJoin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_joinDirect());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DrawerOverlay(
      child: Builder(key: _drawerAnchorKey, builder: _buildContent),
    );
  }

  @override
  void dispose() {
    _otpTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Widget _buildEmailVerification(JoinEmailVerification challenge) {
    final resendAt = challenge.resendAvailableAt;
    final seconds = resendAt == null
        ? 0
        : resendAt.difference(DateTime.now()).inSeconds + 1;
    final expired = challenge.expiresAt?.isBefore(DateTime.now()) ?? false;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Verify your email').h3(),
              const SizedBox(height: 12),
              Text(
                'Enter the 6-digit code sent to ${challenge.email} to join this queue.',
              ),
              const SizedBox(height: 24),
              ValidatedField(
                validation: formValidation,
                controller: _otpController,
                child: TextField(
                  key: const Key('queue-join-otp'),
                  controller: _otpController,
                  enabled: !_isBusy && !expired,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  onChanged: (value) {
                    setState(() {});
                    if (value.length == 6) unawaited(_verifyEmail());
                  },
                ),
              ),
              if (expired)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('This code has expired. Request a new code.'),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!),
                ),
              const SizedBox(height: 20),
              GetPrioActionButton.primary(
                key: const Key('queue-join-otp-verify'),
                onPressed: _isBusy || expired || _otpController.text.length != 6
                    ? null
                    : _verifyEmail,
                child: Text(
                  _isBusy ? 'Please wait...' : 'Verify and join queue',
                ),
              ),
              const SizedBox(height: 12),
              GetPrioActionButton.outline(
                key: const Key('queue-join-otp-resend'),
                onPressed:
                    _isBusy || seconds > 0 || challenge.resendsRemaining <= 0
                    ? null
                    : _resendEmail,
                child: Text(
                  challenge.resendsRemaining <= 0
                      ? 'Resend limit reached'
                      : seconds > 0
                      ? 'Resend code in ${seconds}s'
                      : 'Resend code',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _verifyEmail() async {
    final challenge = _emailChallenge;
    if (_isBusy || challenge == null || _otpController.text.length != 6) return;
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final result = await widget.repository!.verifyEmail(
        challenge,
        _otpController.text,
      );
      if (mounted) {
        setState(() => _emailChallenge = null);
        _otpTimer?.cancel();
        _handleJoinResult(result);
      }
    } catch (error) {
      if (mounted) {
        showFormError(
          error,
          _messageFor(error),
          field: error is ApiException && error.statusCode == 400
              ? _otpController
              : null,
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _resendEmail() async {
    if (_isBusy || _emailChallenge == null) return;
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final challenge = await widget.repository!.resendEmail(_emailChallenge!);
      if (mounted) {
        _otpController.clear();
        setState(() => _emailChallenge = challenge);
        formValidation.setErrors({});
        showFeedbackToast(
          context,
          message: 'A new verification code has been sent.',
        );
      }
    } catch (error) {
      if (mounted) {
        showFormError(
          error,
          _messageFor(error),
          field: error is ApiException && error.statusCode == 400
              ? _otpController
              : null,
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Widget _buildContent(BuildContext context) {
    final challenge = _emailChallenge;
    if (challenge != null) return _buildEmailVerification(challenge);
    final preview = _preview;
    final joinedTicket = _joinedTicket;
    final payment = _payment;
    if (preview != null && joinedTicket == null) {
      return JoinPreviewContent(
        preview: preview,
        isBusy: _isBusy,
        onJoin: payment == null ? _join : _showCheckoutSheet,
        actionLabel: payment == null ? null : 'Resume checkout',
        errorMessage: _error,
      );
    }
    if (joinedTicket == null && _isDirectJoin) return _buildDirectState();
    if (joinedTicket == null) return _buildScannerState();
    return _buildConfirmation(joinedTicket);
  }

  Widget _buildDirectState() {
    final error = _error;
    if (_payment != null && error == null) return const SizedBox.shrink();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error == null) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 20),
                const Text('Checking queue availability...'),
              ] else ...[
                const Text('Could not join this queue').h3(),
                const SizedBox(height: 8),
                Text(error),
                const SizedBox(height: 24),
                GetPrioActionButton.primary(
                  key: const Key('direct-join-retry-button'),
                  onPressed: _isBusy ? null : _retryDirectJoin,
                  child: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScannerState() {
    final error = _error;
    if (error == null) {
      return QrScannerPage(
        allowedHosts: widget.allowedHosts,
        showAppBar: false,
        onBack: _closeJoinFlow,
        onPayload: (payload) => unawaited(_handleScannedPayload(payload)),
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: GetPrioTheme.paperAccent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(LucideIcons.scanLine, size: 32),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _ticketPayload == null
                    ? 'Could not open this queue'
                    : 'Could not add this ticket',
              ).h3(),
              const SizedBox(height: 8),
              Text(error),
              const SizedBox(height: 24),
              GetPrioActionButton.primary(
                key: const Key('join-rescan-button'),
                onPressed: _scanAgain,
                leading: const Icon(LucideIcons.scanQrCode),
                child: const Text('Scan another QR code'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmation(JoinedTicket joinedTicket) {
    final ticket = joinedTicket.ticket;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: GetPrioTheme.teal,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    LucideIcons.circleCheck,
                    color: Color(0xFFFFFFFF),
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('You are in the queue').h2(),
              const SizedBox(height: 8),
              Text(
                'Ticket ${ticket.ticketNumber ?? ticket.lookupCode} is confirmed.',
              ),
              const SizedBox(height: 24),
              GetPrioActionButton.outline(
                onPressed: _scanAgain,
                child: const Text('Scan another QR code'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleScannedPayload(QrScanPayload payload) async {
    if (!mounted) return;
    final repository = widget.repository;
    if (repository == null) {
      setState(() => _error = 'Queue API is not configured for this build.');
      return;
    }
    if (payload is QrTicketClaimPayload) {
      setState(() {
        _ticketPayload = payload;
        _payload = null;
        _preview = null;
        _error = null;
        _isBusy = true;
      });
      try {
        final ticket = await repository.claimTicket(payload);
        if (mounted) _handleJoinResult(JoinedTicket(ticket));
      } catch (error) {
        if (mounted) setState(() => _error = _messageFor(error));
      } finally {
        if (mounted) setState(() => _isBusy = false);
      }
      return;
    }
    if (payload is! QrJoinPayload) return;
    final joinPayload = payload;
    setState(() {
      _ticketPayload = null;
      _payload = joinPayload;
      _preview = null;
      _error = null;
      _isBusy = true;
    });
    try {
      final preview = await repository.resolve(joinPayload);
      if (mounted) setState(() => _preview = preview);
    } catch (error) {
      if (mounted) setState(() => _error = _messageFor(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _join() async {
    final repository = widget.repository;
    final payload = _payload;
    if (repository == null || payload == null) return;
    setState(() {
      _error = null;
      _isBusy = true;
    });
    try {
      final result = await repository.join(
        locationQrId: payload.locationQrId,
        customerName: widget.customerName,
      );
      if (!mounted) return;
      _handleJoinResult(result);
    } catch (error) {
      if (mounted) {
        final message = _messageFor(error);
        setState(() {
          if (error is JoinUnavailableException && _preview != null) {
            _preview = _preview!.asUnavailable(message);
            _error = null;
          } else {
            _error = message;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _joinDirect() async {
    final repository = widget.repository;
    final tenantSlug = widget.directTenantSlug;
    if (repository == null || tenantSlug == null || tenantSlug.isEmpty) {
      if (mounted) {
        setState(() => _error = 'Queue API is not configured for this build.');
      }
      return;
    }
    setState(() {
      _error = null;
      _isBusy = true;
    });
    try {
      final result = await repository.joinDirect(
        tenantSlug: tenantSlug,
        locationSlug: widget.directLocationSlug,
        customerName: widget.customerName,
      );
      if (mounted) _handleJoinResult(result);
    } catch (error) {
      if (mounted) setState(() => _error = _messageFor(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _handleJoinResult(JoinResult result) {
    switch (result) {
      case JoinEmailVerification challenge:
        setState(() => _emailChallenge = challenge);
        _otpTimer?.cancel();
        _otpTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() {});
        });
      case JoinedTicket(:final ticket):
        final onJoined = widget.onJoined;
        setState(() => _joinedTicket = JoinedTicket(ticket));
        onJoined?.call(ticket);
      case PaymentRequired payment:
        setState(() => _payment = payment);
        unawaited(_showCheckoutSheet());
    }
  }

  Future<void> _showCheckoutSheet() async {
    final payment = _payment;
    final overlayContext = _drawerAnchorKey.currentContext;
    if (payment == null ||
        _checkoutSheetOpen ||
        !mounted ||
        overlayContext == null ||
        !overlayContext.mounted) {
      return;
    }
    _checkoutSheetOpen = true;
    final preview = _preview;
    try {
      final completer = openDrawerOverlay<void>(
        context: overlayContext,
        position: OverlayPosition.bottom,
        expands: false,
        draggable: true,
        useSafeArea: false,
        borderRadius: CheckoutBottomSheet.borderRadius,
        transformBackdrop: false,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        builder: (sheetContext) {
          _checkoutSheetContext = sheetContext;
          return CheckoutBottomSheet(
            payment: payment,
            fee: payment.fee > 0 ? payment.fee : preview?.fee ?? 0,
            currency: payment.currency,
            paymentBrowser: widget.paymentBrowser ?? ExternalPaymentBrowser(),
            paymentApi: widget.paymentApi,
            allowedHosts: widget.allowedHosts,
            paymentLinkSource: widget.paymentLinkSource,
            onPaid: (ticket) =>
                _confirmPayment(payment.paymentAttemptId, ticket),
            onCancel: _isDirectJoin ? _closeJoinFlow : _scanAgain,
          );
        },
      );
      _checkoutSheetCompleter = completer;
      await completer.future;
    } finally {
      _checkoutSheetContext = null;
      _checkoutSheetCompleter = null;
      _checkoutSheetOpen = false;
    }
  }

  void _confirmPayment(String paymentAttemptId, QueueTicket ticket) {
    if (!mounted || _payment?.paymentAttemptId != paymentAttemptId) return;
    setState(() {
      _joinedTicket = JoinedTicket(ticket);
      _payment = null;
      _error = null;
    });

    final closeFuture = _closeCheckoutSheet();
    final onJoined = widget.onJoined;
    if (onJoined == null) {
      unawaited(closeFuture);
    } else {
      unawaited(
        closeFuture.then((_) {
          if (mounted) onJoined(ticket);
        }),
      );
    }
  }

  Future<void> _closeCheckoutSheet() async {
    final sheetContext = _checkoutSheetContext;
    final completer = _checkoutSheetCompleter;
    final animationStatus = completer?.animationController?.status;
    final isAlreadyClosing =
        animationStatus == AnimationStatus.reverse ||
        animationStatus == AnimationStatus.dismissed;
    if (sheetContext != null && sheetContext.mounted && !isAlreadyClosing) {
      await closeSheet(sheetContext);
    } else if (sheetContext == null &&
        completer != null &&
        !completer.isCompleted) {
      completer.remove();
    }
  }

  void _reset() {
    _payload = null;
    _ticketPayload = null;
    _preview = null;
    _joinedTicket = null;
    _payment = null;
    _error = null;
  }

  void _scanAgain() {
    if (!mounted) return;
    setState(_reset);
  }

  void _retryDirectJoin() {
    if (!mounted || _isBusy) return;
    setState(_reset);
    unawaited(_joinDirect());
  }

  void _closeJoinFlow() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  String _messageFor(Object error) {
    if (error is QrValidationException || error is JoinUnavailableException) {
      return error.toString();
    }
    if (error is ApiException) {
      if (error.statusCode == 401 || error.code == 'AUTH_REQUIRED') {
        return 'Your sign-in session expired. Please sign in again.';
      }
      if (error.message.isNotEmpty) return error.message;
    }
    if (error is FormatException && error.message.isNotEmpty) {
      return error.message;
    }
    return 'We could not load this queue. Check your connection and try again.';
  }
}

class CheckoutBottomSheet extends StatefulWidget {
  const CheckoutBottomSheet({
    super.key,
    required this.payment,
    required this.fee,
    required this.currency,
    required this.paymentBrowser,
    required this.paymentApi,
    required this.allowedHosts,
    required this.onPaid,
    required this.onCancel,
    this.paymentLinkSource,
  });

  static const borderRadius = BorderRadius.vertical(top: Radius.circular(28));

  final PaymentRequired payment;
  final num fee;
  final String currency;
  final PaymentBrowser paymentBrowser;
  final PaymentApi? paymentApi;
  final Set<String> allowedHosts;
  final ValueChanged<QueueTicket> onPaid;
  final VoidCallback onCancel;
  final PaymentLinkSource? paymentLinkSource;

  @override
  State<CheckoutBottomSheet> createState() => _CheckoutBottomSheetState();
}

class _CheckoutBottomSheetState extends State<CheckoutBottomSheet> {
  bool _isBusy = false;
  String? _error;
  StreamSubscription<Uri>? _paymentLinkSubscription;

  @override
  void initState() {
    super.initState();
    _paymentLinkSubscription = widget.paymentLinkSource?.linkStream.listen(
      _handlePaymentReturn,
    );
  }

  @override
  void dispose() {
    unawaited(_paymentLinkSubscription?.cancel());
    super.dispose();
  }

  void _handlePaymentReturn(Uri uri) {
    final payment = widget.payment;
    if (payment.paymentAttemptId.isEmpty) return;
    PaymentReturn callback;
    try {
      callback = PaymentReturn.parse(uri, allowedHosts: widget.allowedHosts);
    } on PaymentReturnException {
      return;
    }
    if (callback.reference != payment.paymentAttemptId) return;
    unawaited(_checkPayment());
  }

  Future<void> _openCheckout() async {
    setState(() {
      _isBusy = true;
      _error = null;
    });
    var opened = false;
    try {
      opened = await widget.paymentBrowser.open(widget.payment.checkoutUrl);
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    setState(() {
      _isBusy = false;
      if (!opened) {
        _error = 'Secure checkout could not be opened.';
      }
    });
  }

  Future<void> _checkPayment() async {
    final api = widget.paymentApi;
    final payment = widget.payment;
    final tenantSlug = payment.tenantSlug;
    final onPaid = widget.onPaid;
    if (api == null || tenantSlug == null) {
      setState(
        () => _error =
            'Payment status checking is not configured for this build.',
      );
      return;
    }
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final response = await api.sync(
        paymentAttemptId: payment.paymentAttemptId,
        tenantSlug: tenantSlug,
        locationSlug: payment.locationSlug,
      );
      final ticket = response['ticket'];
      if (ticket is Map<String, dynamic>) {
        onPaid(
          queueTicketFromJoinResponse(
            response,
            tenantSlug: payment.tenantSlug,
            locationSlug: payment.locationSlug,
          ),
        );
        return;
      }
      if (!mounted) return;
      setState(
        () => _error =
            'Payment is not confirmed yet. Complete checkout and try again.',
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'We could not check this payment. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _cancel() async {
    final onCancel = widget.onCancel;
    await closeSheet(context);
    onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlockSemantics(
      child: Semantics(
        key: const Key('checkout-bottom-sheet'),
        container: true,
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: 'Secure checkout',
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            color: GetPrioTheme.card,
            borderRadius: CheckoutBottomSheet.borderRadius,
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                24,
                GetPrioTheme.bottomSheetTopPadding,
                24,
                24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          'Secure checkout',
                          style: theme.typography.h2,
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Close checkout',
                        child: GhostButton(
                          key: const Key('checkout-close'),
                          onPressed: _isBusy ? null : () => closeSheet(context),
                          density: ButtonDensity.icon,
                          child: const Icon(LucideIcons.x),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your ticket is created only after the server confirms payment.',
                    style: theme.typography.p.copyWith(
                      color: GetPrioTheme.mutedInk,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: GetPrioTheme.paperAccent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.creditCard, size: 24),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Queue fee',
                                style: theme.typography.small.copyWith(
                                  color: GetPrioTheme.mutedInk,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.currency} ${(widget.fee / 100).toStringAsFixed(2)}',
                                style: theme.typography.h3,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  GetPrioActionButton.primary(
                    key: const Key('checkout-open'),
                    onPressed: _isBusy ? null : _openCheckout,
                    leading: const Icon(LucideIcons.externalLink, size: 18),
                    child: Text(
                      _isBusy ? 'Please wait...' : 'Open secure checkout',
                    ),
                  ),
                  const SizedBox(height: 10),
                  GetPrioActionButton.outline(
                    key: const Key('checkout-check-status'),
                    onPressed: _isBusy ? null : _checkPayment,
                    child: const Text('Check payment status'),
                  ),
                  const SizedBox(height: 10),
                  GetPrioActionButton.outline(
                    key: const Key('checkout-cancel'),
                    onPressed: _isBusy ? null : _cancel,
                    child: const Text('Cancel and scan again'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Semantics(
                      liveRegion: true,
                      child: DestructiveBadge(child: Text(_error!)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class JoinPreviewContent extends StatelessWidget {
  const JoinPreviewContent({
    super.key,
    required this.preview,
    required this.isBusy,
    required this.onJoin,
    this.actionLabel,
    this.errorMessage,
  });

  final JoinPreview preview;
  final bool isBusy;
  final VoidCallback onJoin;
  final String? actionLabel;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final profile = preview.vendorProfile;
    final location = _profileLocation(profile);
    final vendorName = profile?.name ?? preview.vendorName;
    final category = profile?.category;
    final description = profile?.description;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _JoinVendorProfileMedia(profile: profile, vendorName: vendorName),
              const SizedBox(height: 24),
              Text(vendorName).h2(),
              if (category != null) ...[
                const SizedBox(height: 4),
                Text(category, style: Theme.of(context).typography.textMuted),
              ],
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(LucideIcons.mapPin, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(location?.name ?? preview.locationName),
                        if (location?.address != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            location!.address!,
                            style: Theme.of(context).typography.textMuted,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (description != null) ...[
                const SizedBox(height: 16),
                Text(description, maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 24),
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Queue details').h3(),
                    const SizedBox(height: 8),
                    if (preview.joinable)
                      const SecondaryBadge(child: Text('QUEUE OPEN'))
                    else
                      const OutlineBadge(child: Text('UNAVAILABLE')),
                    const SizedBox(height: 12),
                    Text(
                      preview.paymentRequired
                          ? 'Fee: ${preview.currency} ${(preview.fee / 100).toStringAsFixed(2)}'
                          : 'Free queue',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preview.joinable
                          ? 'Queueing is available now.'
                          : preview.unavailableReason ??
                                'Queueing is unavailable.',
                    ),
                    if (preview.queueDetails != null) ...[
                      const SizedBox(height: 16),
                      _JoinQueueDetails(details: preview.queueDetails!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              GetPrioActionButton.primary(
                onPressed: preview.joinable && !isBusy ? onJoin : null,
                child: Text(
                  isBusy
                      ? 'Joining...'
                      : actionLabel != null
                      ? actionLabel!
                      : preview.paymentRequired
                      ? 'Continue to payment'
                      : 'Join queue',
                ),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 16),
                DestructiveBadge(child: Text(errorMessage!)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  JoinVendorLocation? _profileLocation(JoinVendorProfile? profile) {
    if (profile == null || profile.locations.isEmpty) return null;
    final locationSlug = preview.locationSlug;
    if (locationSlug != null) {
      for (final location in profile.locations) {
        if (location.slug == locationSlug) return location;
      }
      return null;
    }
    for (final location in profile.locations) {
      if (location.name == preview.locationName) return location;
    }
    return profile.locations.first;
  }
}

class _JoinQueueDetails extends StatelessWidget {
  const _JoinQueueDetails({required this.details});

  final JoinQueueDetails details;

  @override
  Widget build(BuildContext context) {
    final rows = <({String label, String value})>[];
    if (details.waitingCount != null) {
      rows.add((label: 'Waiting now', value: '${details.waitingCount}'));
    }
    if (details.currentTicketNumber != null) {
      rows.add((label: 'Now serving', value: details.currentTicketNumber!));
    }
    if (details.estimatedWaitMinutes != null) {
      rows.add((
        label: 'Estimated wait',
        value: '${details.estimatedWaitMinutes} min',
      ));
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          if (index > 0) const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(rows[index].label), Text(rows[index].value)],
          ),
        ],
      ],
    );
  }
}

class _JoinVendorProfileMedia extends StatelessWidget {
  const _JoinVendorProfileMedia({
    required this.profile,
    required this.vendorName,
  });

  final JoinVendorProfile? profile;
  final String vendorName;

  @override
  Widget build(BuildContext context) {
    const logoSize = 96.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        key: const Key('join-vendor-cover'),
        height: 210,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _cover(),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x33000000), Color(0x0D000000)],
                ),
              ),
            ),
            Center(
              child: Container(
                key: const Key('join-vendor-logo'),
                width: logoSize,
                height: logoSize,
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: GetPrioTheme.card,
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                    BorderSide(color: Color(0xF2FFFFFF), width: 4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x3D23180F),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipOval(child: _logo()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cover() {
    final imageUrl = profile?.coverImageUrl;
    if (imageUrl == null) {
      return Container(
        color: GetPrioTheme.paperAccent,
        padding: const EdgeInsets.all(24),
        child: const Image(
          image: AssetImage(
            'assets/illustrations/hero-queue-scene-transparent.png',
          ),
          fit: BoxFit.contain,
          semanticLabel: 'Vendor profile cover',
        ),
      );
    }
    return Image.network(
      imageUrl,
      fit: _joinProfileBoxFit(profile?.coverImageFit, BoxFit.cover),
      semanticLabel: '$vendorName profile cover',
      errorBuilder: (context, error, stackTrace) => Container(
        color: GetPrioTheme.paperAccent,
        child: const Icon(LucideIcons.store, size: 48),
      ),
    );
  }

  Widget _logo() {
    final logoUrl = profile?.logoUrl;
    if (logoUrl == null) {
      return const ColoredBox(
        color: GetPrioTheme.card,
        child: Icon(LucideIcons.store, size: 38),
      );
    }
    return Image.network(
      logoUrl,
      fit: _joinProfileBoxFit(profile?.logoFit, BoxFit.cover),
      semanticLabel: '$vendorName logo',
      errorBuilder: (context, error, stackTrace) => const ColoredBox(
        color: GetPrioTheme.card,
        child: Icon(LucideIcons.store, size: 38),
      ),
    );
  }
}

BoxFit _joinProfileBoxFit(JoinProfileImageFit? value, BoxFit fallback) {
  return switch (value) {
    JoinProfileImageFit.contain => BoxFit.contain,
    JoinProfileImageFit.cover => BoxFit.cover,
    _ => fallback,
  };
}

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({
    super.key,
    required this.allowedHosts,
    this.showAppBar = true,
    this.onPayload,
    this.onBack,
  });

  final Set<String> allowedHosts;
  final bool showAppBar;
  final ValueChanged<QrScanPayload>? onPayload;
  final VoidCallback? onBack;

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final _controller = MobileScannerController();
  String? _error;
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _handleDetect,
          errorBuilder: _buildCameraError,
          overlayBuilder: (context, constraints) => Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
        if (_error != null)
          Positioned.fill(child: _InvalidQrScanState(onRetry: _retry)),
      ],
    );
    if (!widget.showAppBar) return body;
    return ScrollNotificationObserver(
      child: Scaffold(
        headers: [
          ScrollAwareAppBar(
            title: const Text('Scan to join'),
            leading: [
              GhostButton(
                onPressed: _handleBack,
                density: ButtonDensity.icon,
                child: const Icon(LucideIcons.arrowLeft),
              ),
            ],
          ),
        ],
        child: body,
      ),
    );
  }

  void _handleBack() {
    final onBack = widget.onBack;
    if (onBack != null) {
      onBack();
    } else {
      Navigator.of(context).pop();
    }
  }

  Widget _buildCameraError(BuildContext context, MobileScannerException error) {
    return _ScannerCameraError(
      permissionDenied:
          error.errorCode == MobileScannerErrorCode.permissionDenied,
      onBack: _handleBack,
    );
  }

  void _handleDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (raw == null) return;
    try {
      final payload = QrScanPayload.parse(
        raw,
        allowedHosts: widget.allowedHosts,
      );
      _handled = true;
      try {
        _controller.stop();
      } catch (_) {
        // The camera may already have been torn down while the callback ran.
      }
      if (mounted) {
        final onPayload = widget.onPayload;
        if (onPayload != null) {
          onPayload(payload);
        } else {
          Navigator.of(context).pop(payload);
        }
      }
    } catch (error) {
      _handled = true;
      try {
        _controller.stop();
      } catch (_) {
        // The camera may already have been torn down while the callback ran.
      }
      if (mounted) {
        setState(
          () => _error = error is QrValidationException
              ? error.message
              : 'This QR code is not supported.',
        );
      }
    }
  }

  void _retry() {
    setState(() {
      _error = null;
      _handled = false;
    });
    _controller.start();
  }
}

class _InvalidQrScanState extends StatelessWidget {
  const _InvalidQrScanState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('invalid-qr-scan-screen'),
      color: Theme.of(context).colorScheme.background,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - 48).clamp(
                        0,
                        double.infinity,
                      ),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/illustrations/scan-invalid-qr-half-body-transparent-v3.png',
                              height: 280,
                              fit: BoxFit.contain,
                              excludeFromSemantics: true,
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Uh-oh!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'You seem to have scanned an invalid QR code.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: SizedBox(
                  width: double.infinity,
                  child: GetPrioActionButton.primary(
                    key: const Key('invalid-qr-retry-button'),
                    onPressed: onRetry,
                    child: const Text('Try again'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerCameraError extends StatelessWidget {
  const _ScannerCameraError({
    required this.permissionDenied,
    required this.onBack,
  });

  final bool permissionDenied;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      key: const Key('scanner-camera-error'),
      color: const Color(0xFF111111),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Semantics(
                liveRegion: true,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      LucideIcons.cameraOff,
                      color: Color(0xFFFFFFFF),
                      size: 44,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      permissionDenied
                          ? 'Camera access is off'
                          : 'Camera unavailable',
                      textAlign: TextAlign.center,
                      style: theme.typography.h3.copyWith(
                        color: const Color(0xFFFFFFFF),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      permissionDenied
                          ? 'Open Settings and allow camera access for GetPrio, then return and scan again.'
                          : 'We could not start the camera on this device. Go back and try again.',
                      textAlign: TextAlign.center,
                      style: theme.typography.p.copyWith(
                        color: const Color(0xFFD7D1CA),
                      ),
                    ),
                    const SizedBox(height: 24),
                    GetPrioActionButton.primary(
                      onPressed: onBack,
                      leading: const Icon(LucideIcons.arrowLeft),
                      child: const Text('Go back'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
