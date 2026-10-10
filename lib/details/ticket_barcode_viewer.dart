import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:barcode_widget/barcode_widget.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../app_theme.dart';

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

Future<void> showTicketBarcode(BuildContext context, String code) =>
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close barcode',
      barrierColor: Colors.black.withValues(alpha: .35),
      pageBuilder: (_, _, _) => TicketBarcodeViewer(code: code),
    );

class TicketBarcodeViewer extends StatefulWidget {
  const TicketBarcodeViewer({super.key, required this.code, this.brightness});
  final String code;
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
    WidgetsBinding.instance.addObserver(this);
    if (WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _updateBrightness(true);
    }
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
    WidgetsBinding.instance.removeObserver(this);
    _updateBrightness(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: const SizedBox.expand(),
          ),
        ),
      ),
      SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              key: const Key('ticket-barcode-modal'),
              constraints: const BoxConstraints(maxWidth: 640),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Your ticket barcode',
                          style: TextStyle(
                            color: GetPrioTheme.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Semantics(
                        label: 'Close barcode',
                        button: true,
                        child: GestureDetector(
                          key: const Key('ticket-barcode-close'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.of(context).pop(),
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(LucideIcons.x, color: GetPrioTheme.ink),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  BarcodeWidget(
                    key: const Key('ticket-barcode-enlarged'),
                    data: widget.code,
                    barcode: Barcode.code128(),
                    height: 160,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    drawText: false,
                    color: GetPrioTheme.ink,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.code,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: GetPrioTheme.ink,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
