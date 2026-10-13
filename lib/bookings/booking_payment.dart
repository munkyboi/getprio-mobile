import 'dart:async';

import '../uploads/compressed_image.dart';

import '../navigation/app_drawer.dart';
import '../keyboard_avoidance.dart';

import 'package:image_picker/image_picker.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../auth/auth_repository.dart';
import 'booking_repository.dart';
import 'image_viewer.dart';
import '../navigation/swipe_back_page_route.dart';

Future<CustomerBooking?> openBookingPaymentDrawer({
  required BuildContext context,
  required BookingRepository repository,
  required CustomerBooking booking,
  ValueChanged<BuildContext>? onOpened,
}) => openAppDrawer<CustomerBooking>(
  context: context,
  position: OverlayPosition.bottom,
  useSafeArea: false,
  draggable: false,
  barrierDismissible: false,
  builder: (drawerContext) {
    onOpened?.call(drawerContext);
    return Container(
      key: const Key('booking-manual-payment-drawer'),
      color: appDrawerBackground(drawerContext),
      child: SizedBox(
        height: MediaQuery.sizeOf(drawerContext).height * .85,
        child: BookingPayment(
          repository: repository,
          booking: booking,
          fixedFooter: true,
          onCancel: () => closeDrawer(drawerContext),
          onSubmitted: (updated) => closeDrawer(drawerContext, updated),
        ),
      ),
    );
  },
).future;

/// Evidence goes through the authenticated API and stays pending vendor review.
class BookingPayment extends StatefulWidget {
  const BookingPayment({
    super.key,
    required this.repository,
    required this.booking,
    required this.onSubmitted,
    this.pickReceipt,
    this.fixedFooter = false,
    this.onCancel,
  });
  final BookingRepository repository;
  final CustomerBooking booking;
  final ValueChanged<CustomerBooking> onSubmitted;
  final Future<XFile?> Function()? pickReceipt;
  final bool fixedFooter;
  final VoidCallback? onCancel;
  @override
  State<BookingPayment> createState() => _BookingPaymentState();
}

class _BookingPaymentState extends State<BookingPayment> {
  final _reference = TextEditingController();
  XFile? _receipt;
  List<int>? _bytes;
  String? _contentType, _uploadFileName, _error;
  bool _busy = false;
  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file =
          await (widget.pickReceipt?.call() ??
              ImagePicker().pickImage(
                source: ImageSource.gallery,
                maxWidth: 2400,
                maxHeight: 2400,
                imageQuality: 95,
              ));
      if (file == null || !mounted) return;
      final extension = file.name.split('.').last.toLowerCase();
      final type =
          file.mimeType ??
          switch (extension) {
            'jpg' || 'jpeg' => 'image/jpeg',
            'png' => 'image/png',
            'webp' => 'image/webp',
            _ => '',
          };
      if (!['image/jpeg', 'image/png', 'image/webp'].contains(type)) {
        throw ArgumentError('Choose a JPEG, PNG, or WebP receipt.');
      }
      final size = await file.length();
      if (size <= 0 || size > 8 * 1024 * 1024) {
        throw ArgumentError('Choose a receipt up to 8 MB.');
      }
      final prepared = await prepareUploadImage(
        await file.readAsBytes(),
        fileName: file.name,
        contentType: type,
      );
      if (mounted) {
        setState(() {
          _receipt = file;
          _bytes = prepared.bytes;
          _contentType = prepared.contentType;
          _uploadFileName = prepared.fileName;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ArgumentError
              ? '${e.message}'
              : 'Could not open receipt. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || _bytes == null || _reference.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await widget.repository.submitPaymentProof(
        widget.booking,
        reference: _reference.text,
        bytes: _bytes!,
        contentType: _contentType!,
        fileName: _uploadFileName!,
      );
      if (mounted) widget.onSubmitted(updated);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is TimeoutException
              ? 'This is taking too long. Refresh the booking status before retrying; your receipt is kept here.'
              : e is ApiException
              ? e.message
              : 'Could not submit payment proof. Your receipt is kept here; retry or refresh the booking status.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final destination = widget.booking.data['manualPaymentDestination'];
    final details = destination is Map ? destination : null;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppDrawerTitle('Manual Payment'),
        const SizedBox(height: 12),
        const Text(
          'Pay the vendor, then submit your payment reference and receipt. Payment proof must be reviewed by the vendor before confirmation.',
        ),
        const SizedBox(height: 12),
        if (details == null)
          const Text(
            'Vendor payment details are unavailable. Contact the vendor before sending payment.',
          )
        else ...[
          Text('Pay through ${details['methodLabel'] ?? 'the vendor'}').bold(),
          for (final key in [
            'bankName',
            'accountDisplayName',
            'accountIdentifierDisplay',
          ])
            if ('${details[key] ?? ''}'.isNotEmpty)
              SelectableText('${details[key]}'),
          Text(
            'Total payable: ${details['currency'] ?? 'PHP'} ${((details['amountCents'] as num? ?? 0) / 100).toStringAsFixed(2)}',
          ).bold(),
          if ('${details['qrImageUrl'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 12),
            Semantics(
              label: 'View larger payment QR',
              button: true,
              child: GestureDetector(
                key: const Key('booking-payment-qr'),
                onTap: () => Navigator.of(context).push(
                  SwipeBackPageRoute<void>(
                    builder: (_) => BookingImageViewer(
                      imageUrl: '${details['qrImageUrl']}',
                      title: 'Payment QR',
                    ),
                  ),
                ),
                child: Image.network(
                  '${details['qrImageUrl']}',
                  height: 240,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Text(
                    'Could not load payment QR. Refresh or contact the vendor before paying.',
                  ),
                ),
              ),
            ),
            const Text('Tap the QR to enlarge. Pinch to zoom.'),
          ],
        ],
        const SizedBox(height: 16),
        const Text('Payment reference').bold(),
        const SizedBox(height: 8),
        TextField(
          key: const Key('booking-payment-reference'),
          controller: _reference,
          enabled: !_busy,
          placeholder: const Text('Bank or wallet reference number'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        OutlineButton(
          onPressed: _busy ? null : _pick,
          child: Text(
            _receipt == null
                ? 'Choose payment receipt'
                : 'Change payment receipt',
          ),
        ),
        if (_receipt != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_receipt!.name),
          ),
        const SizedBox(height: 8),
        const Text(
          'JPEG, PNG or WebP, up to 8 MB. Larger images are compressed to 200 KB before upload. Your receipt stays private to you and authorized vendor staff.',
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_error!),
          ),
        if (!widget.fixedFooter) ...[
          const SizedBox(height: 16),
          _submitAction(),
        ],
      ],
    );
    if (!widget.fixedFooter) return content;
    return PopScope(
      canPop: !_busy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: KeyboardAwareScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: content,
            ),
          ),
          Container(
            key: const Key('booking-payment-footer'),
            color: appDrawerBackground(context),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _submitAction(),
                    if (widget.onCancel != null)
                      TextButton(
                        onPressed: _busy ? null : widget.onCancel,
                        child: const Text('Cancel'),
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

  Widget _submitAction() => PrimaryButton(
    onPressed: _busy || _bytes == null || _reference.text.trim().isEmpty
        ? null
        : _submit,
    child: Text(_busy ? 'Please wait...' : 'Submit payment proof'),
  );
}
