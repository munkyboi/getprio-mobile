import 'dart:async';

import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../app_theme.dart';
import 'ticket_barcode_state.dart';

abstract interface class BarcodeBrightness {
  Future<double> get current;
  Future<bool> get hasOverride;
  Future<void> set(double value);
  Future<void> reset();
}

class DeviceBarcodeBrightness implements BarcodeBrightness {
  @override
  Future<double> get current => ScreenBrightness.instance.application;
  @override
  Future<bool> get hasOverride =>
      ScreenBrightness.instance.hasApplicationScreenBrightnessChanged;
  @override
  Future<void> set(double value) =>
      ScreenBrightness.instance.setApplicationScreenBrightness(value);
  @override
  Future<void> reset() =>
      ScreenBrightness.instance.resetApplicationScreenBrightness();
}

Future<void> showTicketBarcode(
  BuildContext context,
  String code, {
  TicketBarcodeState? state,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Close QR code',
  barrierColor: Colors.black.withValues(alpha: .35),
  pageBuilder: (_, _, _) => TicketBarcodeViewer(code: code, state: state),
);

class TicketBarcodeViewer extends StatefulWidget {
  const TicketBarcodeViewer({
    super.key,
    required this.code,
    this.state,
    this.brightness,
  });
  final String code;
  final TicketBarcodeState? state;
  final BarcodeBrightness? brightness;
  @override
  State<TicketBarcodeViewer> createState() => _TicketBarcodeViewerState();
}

class _TicketBarcodeViewerState extends State<TicketBarcodeViewer>
    with WidgetsBindingObserver {
  late final BarcodeBrightness _brightness;
  Future<void> _pending = Future<void>.value();
  double? _previous;
  bool _hadOverride = false;
  bool _boosted = false;

  @override
  void initState() {
    super.initState();
    _brightness = widget.brightness ?? DeviceBarcodeBrightness();
    widget.state?.addListener(_closeAfterConfirmation);
    _closeAfterConfirmation();
    WidgetsBinding.instance.addObserver(this);
    if (WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _updateBrightness(true);
    }
  }

  bool _closingAfterConfirmation = false;

  void _closeAfterConfirmation() {
    if (!mounted ||
        _closingAfterConfirmation ||
        widget.state?.arrivalConfirmed != true) {
      return;
    }
    _closingAfterConfirmation = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route == null) return;
      if (route.isCurrent) {
        Navigator.of(context).pop();
      } else {
        route.navigator?.removeRoute(route);
      }
    });
  }

  // Serialize changes so closing/backgrounding during a native read cannot
  // leave a late maximum-brightness request active after the viewer closes.
  void _updateBrightness(bool visible) {
    _pending = _pending.then((_) async {
      try {
        if (visible) {
          _previous ??= await _brightness.current;
          if (!_boosted) {
            _hadOverride = await _brightness.hasOverride;
            _boosted = true;
          }
          await _brightness.set(1);
        } else if (_boosted) {
          if (_hadOverride) {
            await _brightness.set(_previous!);
          } else {
            await _brightness.reset();
          }
          _boosted = false;
        }
      } catch (_) {
        // The barcode remains usable if brightness control is unavailable.
      }
    });
    unawaited(_pending);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _updateBrightness(state == AppLifecycleState.resumed);

  @override
  void dispose() {
    widget.state?.removeListener(_closeAfterConfirmation);
    WidgetsBinding.instance.removeObserver(this);
    _updateBrightness(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: GetPrioTheme.light(),
    child: ColoredBox(
      key: const Key('ticket-barcode-modal'),
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Ticket QR code',
                      style: TextStyle(
                        color: GetPrioTheme.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Semantics(
                    label: 'Close QR code',
                    button: true,
                    child: GestureDetector(
                      key: const Key('ticket-barcode-close'),
                      onTap: () => Navigator.of(context).pop(),
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Icon(LucideIcons.x, color: GetPrioTheme.ink),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: widget.state != null
                        ? TicketBarcodeContent(
                            state: widget.state!,
                            enlarged: true,
                          )
                        : BrandedTicketQr(code: widget.code, enlarged: true),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Text(
                'Show this QR code to the vendor.',
                style: TextStyle(color: GetPrioTheme.ink),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Shared render path; no independent token or timer in the enlarged modal.
class TicketBarcodeContent extends StatelessWidget {
  const TicketBarcodeContent({
    super.key,
    required this.state,
    this.enlarged = false,
    this.onTap,
  });
  final TicketBarcodeState state;
  final bool enlarged;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) {
      final code = state.code;
      final seconds = state.remaining.inSeconds.clamp(0, 120);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (code != null && code.isNotEmpty) ...[
            Semantics(
              label: 'Enlarge ticket barcode',
              button: !enlarged,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Container(
                  key: enlarged ? null : const Key('ticket-details-barcode'),
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  child: BrandedTicketQr(code: code, enlarged: enlarged),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              code,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: GetPrioTheme.ink,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            if (state.rotating) ...[
              const SizedBox(height: 8),
              Text(
                'Refreshes in ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                key: const Key('ticket-barcode-countdown'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: GetPrioTheme.ink),
              ),
            ],
          ] else ...[
            Text(
              state.loading
                  ? 'Refreshing barcode…'
                  : 'Barcode unavailable. Refresh to show a valid barcode.',
              key: const Key('ticket-barcode-unavailable'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: GetPrioTheme.ink),
            ),
            if (!state.loading)
              Center(
                child: TextButton(
                  key: const Key('ticket-barcode-retry'),
                  onPressed: () => unawaited(state.refresh()),
                  child: const Text(
                    'Retry',
                    style: TextStyle(color: GetPrioTheme.ink),
                  ),
                ),
              ),
          ],
        ],
      );
    },
  );
}

/// Shared brand treatment; quiet space and finder patterns remain unobstructed.
class BrandedTicketQr extends StatelessWidget {
  const BrandedTicketQr({super.key, required this.code, this.enlarged = false});
  final String code;
  final bool enlarged;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.maxWidth.clamp(0.0, enlarged ? 560.0 : 180.0);
      return Center(
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PrettyQrView.data(
                key: enlarged ? const Key('ticket-barcode-enlarged') : null,
                data: code,
                errorCorrectLevel: QrErrorCorrectLevel.H,
                decoration: const PrettyQrDecoration(
                  shape: PrettyQrSmoothSymbol(color: Colors.black),
                  background: Colors.white,
                  quietZone: PrettyQrQuietZone.standard,
                ),
              ),
              IgnorePointer(
                child: Container(
                  key: const Key('ticket-qr-brand'),
                  width: size * .14,
                  height: size * .14,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: SvgPicture.asset(
                    'assets/branding/logo.svg',
                    semanticsLabel: 'GetPrio',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
