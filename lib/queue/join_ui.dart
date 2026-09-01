import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../app_theme.dart';
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
  QrJoinPayload? _payload;
  JoinPreview? _preview;
  JoinedTicket? _joinedTicket;
  PaymentRequired? _payment;
  String? _error;
  bool _isBusy = false;

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
    final preview = _preview;
    final joinedTicket = _joinedTicket;
    final payment = _payment;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (joinedTicket == null && payment == null && preview == null)
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
                      color: joinedTicket != null
                          ? GetPrioTheme.teal
                          : GetPrioTheme.paperAccent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      joinedTicket != null
                          ? LucideIcons.circleCheck
                          : payment != null
                          ? LucideIcons.creditCard
                          : LucideIcons.scanQrCode,
                      color: joinedTicket != null
                          ? const Color(0xFFFFFFFF)
                          : GetPrioTheme.ink,
                      size: 40,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                joinedTicket != null
                    ? 'You are in the queue'
                    : payment != null
                    ? 'Payment required'
                    : preview == null
                    ? 'Join a queue'
                    : '${preview.vendorName} · ${preview.locationName}',
              ).h2(),
              const SizedBox(height: 8),
              Text(_description(preview, joinedTicket, payment)),
              if (preview != null &&
                  joinedTicket == null &&
                  payment == null) ...[
                const SizedBox(height: 20),
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Queue details').h3(),
                      const SizedBox(height: 8),
                      if (preview.joinable)
                        const SecondaryBadge(child: Text('QUEUE OPEN'))
                      else
                        const DestructiveBadge(child: Text('UNAVAILABLE')),
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
              ],
              const SizedBox(height: 24),
              if (joinedTicket != null)
                GetPrioActionButton.outline(
                  onPressed: () => setState(_reset),
                  child: const Text('Scan another QR code'),
                )
              else if (payment != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GetPrioActionButton.primary(
                      onPressed: _openPayment,
                      leading: const Icon(LucideIcons.externalLink),
                      child: const Text('Open secure checkout'),
                    ),
                    const SizedBox(height: 8),
                    GetPrioActionButton.outline(
                      onPressed: _checkPayment,
                      child: const Text('Check payment status'),
                    ),
                    const SizedBox(height: 8),
                    GetPrioActionButton.outline(
                      onPressed: () => setState(_reset),
                      child: const Text('Cancel and scan again'),
                    ),
                  ],
                )
              else if (preview != null)
                GetPrioActionButton.primary(
                  onPressed: preview.joinable && !_isBusy ? _join : null,
                  child: Text(
                    _isBusy
                        ? 'Joining...'
                        : preview.paymentRequired
                        ? 'Continue to payment'
                        : 'Join queue',
                  ),
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
              if (payment != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Complete checkout, then check payment status. A ticket is created only after the server confirms payment.',
                  textAlign: TextAlign.center,
                ),
              ],
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

  String _description(
    JoinPreview? preview,
    JoinedTicket? joinedTicket,
    PaymentRequired? payment,
  ) {
    if (joinedTicket != null) {
      final ticket = joinedTicket.ticket;
      return 'Ticket ${ticket.ticketNumber ?? ticket.lookupCode} is confirmed.';
    }
    if (payment != null) {
      return 'The queue requires payment before a ticket can be created.';
    }
    if (preview != null) {
      return preview.joinable
          ? 'Review the queue details before joining.'
          : 'This queue cannot accept new tickets right now.';
    }
    return 'Scan the QR code displayed by a vendor. The app will identify the location and show the available queue.';
  }

  Future<void> _scan() async {
    final payload = await Navigator.of(context).push<QrJoinPayload>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            QrScannerPage(allowedHosts: widget.allowedHosts),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    if (!mounted || payload == null) return;
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
          setState(
            () => _payment = PaymentRequired(
              paymentAttemptId: paymentAttemptId,
              checkoutUrl: checkoutUrl,
              tenantSlug: tenantSlug,
              locationSlug: locationSlug,
            ),
          );
      }
    } catch (error) {
      if (mounted) setState(() => _error = _messageFor(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _openPayment() async {
    final payment = _payment;
    if (payment == null) return;
    final opened = await (widget.paymentBrowser ?? ExternalPaymentBrowser())
        .open(payment.checkoutUrl);
    if (!opened && mounted) {
      setState(() => _error = 'Secure checkout could not be opened.');
    }
  }

  Future<void> _checkPayment() async {
    final payment = _payment;
    final api = widget.paymentApi;
    if (payment == null || api == null || payment.tenantSlug == null) {
      if (mounted) {
        setState(
          () => _error =
              'Payment status checking is not configured for this build.',
        );
      }
      return;
    }
    setState(() {
      _error = null;
      _isBusy = true;
    });
    try {
      final response = await api.sync(
        paymentAttemptId: payment.paymentAttemptId,
        tenantSlug: payment.tenantSlug!,
        locationSlug: payment.locationSlug,
      );
      final ticket = response['ticket'];
      if (ticket is Map<String, dynamic> && mounted) {
        setState(() {
          _joinedTicket = JoinedTicket(QueueTicket.fromJson(ticket));
          _payment = null;
        });
      } else if (mounted) {
        setState(
          () => _error =
              'Payment is not confirmed yet. Complete checkout and try again.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = _messageFor(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
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
