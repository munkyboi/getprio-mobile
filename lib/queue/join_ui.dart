import 'dart:async';

import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../app_theme.dart';
import '../navigation/swipe_back_page_route.dart';
import 'join_repository.dart';
import 'payment_flow.dart';
import 'queue_models.dart';

class JoinPage extends StatefulWidget {
  const JoinPage({
    super.key,
    required this.repository,
    required this.allowedHosts,
    required this.customerName,
    this.scanOnOpen = false,
    this.paymentBrowser,
    this.paymentApi,
  });

  final JoinRepository? repository;
  final Set<String> allowedHosts;
  final String customerName;
  final bool scanOnOpen;
  final PaymentBrowser? paymentBrowser;
  final PaymentApi? paymentApi;

  @override
  State<JoinPage> createState() => _JoinPageState();
}

class _JoinPageState extends State<JoinPage> {
  final _drawerAnchorKey = GlobalKey();
  QrJoinPayload? _payload;
  JoinPreview? _preview;
  JoinedTicket? _joinedTicket;
  PaymentRequired? _payment;
  String? _error;
  bool _isBusy = false;
  bool _checkoutSheetOpen = false;
  DrawerOverlayCompleter<void>? _checkoutSheetCompleter;
  BuildContext? _checkoutSheetContext;

  @override
  void initState() {
    super.initState();
    if (widget.scanOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scan();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DrawerOverlay(
      child: Builder(key: _drawerAnchorKey, builder: _buildContent),
    );
  }

  Widget _buildContent(BuildContext context) {
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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (joinedTicket == null)
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: GetPrioTheme.paperAccent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Image(
                    image: AssetImage(
                      'assets/illustrations/hero-queue-scene-transparent.png',
                    ),
                    fit: BoxFit.contain,
                    semanticLabel: 'Illustration of joining a vendor queue',
                  ),
                )
              else
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
              Text(
                joinedTicket != null ? 'You are in the queue' : 'Join a queue',
              ).h2(),
              const SizedBox(height: 8),
              Text(_description(joinedTicket)),
              const SizedBox(height: 24),
              if (joinedTicket != null)
                GetPrioActionButton.outline(
                  onPressed: () => setState(_reset),
                  child: const Text('Scan another QR code'),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GetPrioActionButton.primary(
                      key: const Key('join-scan-button'),
                      onPressed: _scan,
                      leading: const Icon(LucideIcons.scanQrCode),
                      child: const Text('Scan QR code'),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Camera access is used only while scanning a vendor QR code.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                DestructiveBadge(child: Text(_error!)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _description(JoinedTicket? joinedTicket) {
    if (joinedTicket != null) {
      final ticket = joinedTicket.ticket;
      return 'Ticket ${ticket.ticketNumber ?? ticket.lookupCode} is confirmed.';
    }
    return 'Scan the QR code displayed by a vendor. The app will identify the location and show the available queue.';
  }

  Future<void> _scan() async {
    final payload = await Navigator.of(context).push<QrJoinPayload>(
      SwipeBackPageRoute<QrJoinPayload>(
        builder: (context) => QrScannerPage(allowedHosts: widget.allowedHosts),
      ),
    );
    if (!mounted) return;
    if (payload == null) {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) navigator.pop();
      return;
    }
    final repository = widget.repository;
    if (repository == null) {
      setState(() => _error = 'Queue API is not configured for this build.');
      return;
    }
    setState(() {
      _payload = payload;
      _preview = null;
      _error = null;
      _isBusy = true;
    });
    try {
      final preview = await repository.resolve(payload);
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
      switch (result) {
        case JoinedTicket(:final ticket):
          setState(() => _joinedTicket = JoinedTicket(ticket));
        case PaymentRequired(
          :final paymentAttemptId,
          :final checkoutUrl,
          :final tenantSlug,
          :final locationSlug,
        ):
          final payment = PaymentRequired(
            paymentAttemptId: paymentAttemptId,
            checkoutUrl: checkoutUrl,
            tenantSlug: tenantSlug,
            locationSlug: locationSlug,
          );
          setState(() => _payment = payment);
          unawaited(_showCheckoutSheet());
      }
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
            fee: preview?.fee ?? 0,
            currency: preview?.currency ?? 'PHP',
            paymentBrowser: widget.paymentBrowser ?? ExternalPaymentBrowser(),
            paymentApi: widget.paymentApi,
            onPaid: (ticket) =>
                _confirmPayment(payment.paymentAttemptId, ticket),
            onCancel: () {
              if (mounted) setState(_reset);
            },
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

    final sheetContext = _checkoutSheetContext;
    final completer = _checkoutSheetCompleter;
    final animationStatus = completer?.animationController?.status;
    final isAlreadyClosing =
        animationStatus == AnimationStatus.reverse ||
        animationStatus == AnimationStatus.dismissed;
    if (sheetContext != null && sheetContext.mounted && !isAlreadyClosing) {
      unawaited(closeSheet(sheetContext));
    } else if (sheetContext == null &&
        completer != null &&
        !completer.isCompleted) {
      completer.remove();
    }
  }

  void _reset() {
    _payload = null;
    _preview = null;
    _joinedTicket = null;
    _payment = null;
    _error = null;
  }

  String _messageFor(Object error) {
    if (error is QrValidationException || error is JoinUnavailableException) {
      return error.toString();
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
    required this.onPaid,
    required this.onCancel,
  });

  static const borderRadius = BorderRadius.vertical(top: Radius.circular(28));

  final PaymentRequired payment;
  final num fee;
  final String currency;
  final PaymentBrowser paymentBrowser;
  final PaymentApi? paymentApi;
  final ValueChanged<QueueTicket> onPaid;
  final VoidCallback onCancel;

  @override
  State<CheckoutBottomSheet> createState() => _CheckoutBottomSheetState();
}

class _CheckoutBottomSheetState extends State<CheckoutBottomSheet> {
  bool _isBusy = false;
  String? _error;

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
        onPaid(QueueTicket.fromJson(ticket));
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
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          'Secure checkout',
                          style: theme.typography.h2.copyWith(fontSize: 28),
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
  const QrScannerPage({super.key, required this.allowedHosts});

  final Set<String> allowedHosts;

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
    return Scaffold(
      headers: [
        AppBar(
          title: const Text('Scan QR code'),
          leading: [
            GhostButton(
              onPressed: () => Navigator.of(context).pop(),
              density: ButtonDensity.icon,
              child: const Icon(LucideIcons.arrowLeft),
            ),
          ],
        ),
      ],
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _handleDetect),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          if (_error != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Card(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DestructiveBadge(child: Text(_error!)),
                      const SizedBox(height: 12),
                      GetPrioActionButton.primary(
                        onPressed: _retry,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
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
      final payload = QrJoinPayload.parse(
        raw,
        allowedHosts: widget.allowedHosts,
      );
      _handled = true;
      _controller.stop();
      if (mounted) Navigator.of(context).pop(payload);
    } on QrValidationException catch (error) {
      _controller.stop();
      if (mounted) setState(() => _error = error.message);
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
