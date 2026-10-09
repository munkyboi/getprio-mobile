import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../app_theme.dart';
import '../details/detail_pass.dart';
import '../navigation/swipe_back_page_route.dart';
import 'booking_repository.dart';
import 'image_viewer.dart';

DateTime? bookingTime(Object? value) => DateTime.tryParse('$value')?.toLocal();
String bookingClock(DateTime value) =>
    '${value.hour % 12 == 0 ? 12 : value.hour % 12}:${value.minute.toString().padLeft(2, '0')} ${value.hour < 12 ? 'am' : 'pm'}';
String bookingDay(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}

String bookingRange(Object? start, Object? end) {
  final first = bookingTime(start), last = bookingTime(end);
  if (first == null) return 'Schedule unavailable';
  if (last == null) return bookingClock(first);
  final sameDay =
      first.year == last.year &&
      first.month == last.month &&
      first.day == last.day;
  return '${bookingClock(first)} – ${sameDay ? '' : '${bookingDay(last)} · '}${bookingClock(last)}';
}

String bookingMoney(num cents, Object? currency) {
  final amount = (cents / 100).toStringAsFixed(2).split('.');
  final whole = amount.first.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  return '${currency == null || currency == 'PHP' ? '₱' : '$currency '}$whole.${amount.last}';
}

/// Uses booked snapshots for prices and times, rather than the current catalogue.
List<Map<String, dynamic>> bookingServiceItems(CustomerBooking booking) {
  final group = booking.data['groupFundedCampaign'];
  final grouped = group is Map ? group['bundleItems'] : null;
  final raw = grouped is List && grouped.isNotEmpty
      ? grouped
      : booking.data['bundleItems'];
  final items = raw is List
      ? raw.whereType<Map<String, dynamic>>().toList()
      : <Map<String, dynamic>>[];
  if (items.isNotEmpty) return items;
  final quantity = (booking.data['bookingQuantity'] as num?) ?? 1;
  return [
    {
      'serviceName': booking.serviceName,
      'serviceSlug': booking.data['serviceSlug'],
      'bookingQuantity': quantity,
      'scheduledStartAt': booking.data['scheduledStartAt'],
      'scheduledEndAt': booking.data['scheduledEndAt'],
      'priceAmountCents': booking.data['servicePriceAmountCents'] is num
          ? (booking.data['servicePriceAmountCents'] as num) * quantity
          : null,
      'currency': booking.data['serviceCurrency'],
    },
  ];
}

class BookingServiceCard extends StatelessWidget {
  const BookingServiceCard({super.key, required this.item, this.imageUrl = ''});
  final Map<String, dynamic> item;
  final String imageUrl;
  @override
  Widget build(BuildContext context) {
    final name = '${item['serviceName'] ?? 'Service'}';
    final price = item['priceAmountCents'];
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GetPrioTheme.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GetPrioTheme.line),
      ),
      child: Row(
        children: [
          if (imageUrl.isNotEmpty) ...[
            SizedBox(
              width: 64,
              height: 64,
              child: Button(
                style: const ButtonStyle.ghost(density: ButtonDensity.compact),
                onPressed: () => Navigator.of(context).push(
                  SwipeBackPageRoute<void>(
                    builder: (_) =>
                        BookingImageViewer(imageUrl: imageUrl, title: name),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    semanticLabel: 'View image of $name',
                    errorBuilder: (_, _, _) => const SizedBox(
                      width: 64,
                      height: 64,
                      child: Center(child: Icon(LucideIcons.image)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name).bold(),
                const SizedBox(height: 4),
                Text(
                  bookingRange(
                    item['scheduledStartAt'],
                    item['scheduledEndAt'],
                  ),
                  style: Theme.of(context).typography.small
                      .copyWith(color: GetPrioTheme.mutedInk),
                ),
                if (price is num) ...[
                  const SizedBox(height: 4),
                  Text(bookingMoney(price, item['currency'])).bold(),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          SecondaryBadge(child: Text('×${item['bookingQuantity'] ?? 1}')),
        ],
      ),
    );
  }
}

class BookingStatusBadge extends StatelessWidget {
  const BookingStatusBadge({
    super.key,
    required this.status,
    required this.label,
  });
  final String status, label;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'confirmed' || 'verified' => const Color(0xFF187C58),
      'canceled' || 'rejected' || 'expired' => const Color(0xFFB43C35),
      'rescheduled' => GetPrioTheme.info,
      'pending' || 'unpaid' => const Color(0xFF9A5E12),
      _ => GetPrioTheme.mutedInk,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).typography.small
            .copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class BookingSection extends StatelessWidget {
  const BookingSection({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: GetPrioTheme.card,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: GetPrioTheme.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class BookingProofSummary extends StatefulWidget {
  const BookingProofSummary({
    super.key,
    required this.booking,
    required this.repository,
  });
  final CustomerBooking booking;
  final BookingRepository repository;
  @override
  State<BookingProofSummary> createState() => _BookingProofSummaryState();
}

class _BookingProofSummaryState extends State<BookingProofSummary> {
  bool _busy = false;
  String? _error;
  Future<void> _view() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final url = await widget.repository.paymentProofUrl(widget.booking.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        SwipeBackPageRoute<void>(
          builder: (_) =>
              BookingImageViewer(imageUrl: url, title: 'Payment proof'),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not open payment proof. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final rejected =
        booking.paymentStatus == 'rejected' ||
        booking.data['paymentRejectedAt'] != null;
    final verified =
        booking.paymentStatus == 'verified' ||
        booking.data['paymentVerifiedAt'] != null;
    final color = rejected
        ? GetPrioTheme.warning
        : verified
        ? GetPrioTheme.success
        : GetPrioTheme.primary;
    final proof = booking.data['paymentProof'] as Map;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                rejected
                    ? LucideIcons.circleAlert
                    : verified
                    ? LucideIcons.circleCheck
                    : LucideIcons.clock,
                color: color,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  rejected
                      ? 'Payment rejected'
                      : verified
                      ? 'Payment verified'
                      : 'Awaiting vendor verification',
                ).bold(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Your receipt is private and available only to you and authorized vendor staff.',
        ),
        if ('${booking.data['paymentReference'] ?? ''}'.isNotEmpty)
          DetailPassField(
            label: 'Payment reference',
            value: '${booking.data['paymentReference']}',
          ),
        DetailPassField(
          label: 'Uploaded receipt',
          value: '${proof['fileName'] ?? 'Submitted'}',
        ),
        if ('${booking.data['paymentRejectionReason'] ?? ''}'.isNotEmpty)
          DetailPassField(
            label: 'Vendor review',
            value: '${booking.data['paymentRejectionReason']}',
          ),
        if (_error != null) ...[Text(_error!), const SizedBox(height: 8)],
        OutlineButton(
          key: const Key('booking-view-proof'),
          onPressed: _busy ? null : _view,
          child: Text(_busy ? 'Opening proof...' : 'View payment proof'),
        ),
      ],
    );
  }
}
