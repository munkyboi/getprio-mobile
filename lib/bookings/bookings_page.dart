import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../app_theme.dart';
import '../navigation/scroll_aware_app_bar.dart';
import '../navigation/swipe_back_page_route.dart';
import 'booking_repository.dart';
import 'booking_payment.dart';

String bookingDateLabel(DateTime? date) => date == null
    ? 'Schedule unavailable'
    : '${date.day}/${date.month}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
String bookingStatusLabel(String status) => status.replaceAll('_', ' ');

class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key, this.repository});
  final BookingRepository? repository;
  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage>
    with WidgetsBindingObserver {
  final _items = <CustomerBooking>[];
  bool _loading = false, _history = false, _hasMore = false;
  String? _error;
  int _page = 0, _request = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load({bool more = false}) async {
    final repository = widget.repository;
    if (repository == null || (more && _loading)) return;
    final request = ++_request;
    final page = more ? _page + 1 : 1;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await repository.list(page: page);
      if (!mounted || request != _request) return;
      final next = (response['bookings'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(CustomerBooking.new)
          .toList();
      final pagination = response['pagination'] as Map<String, dynamic>?;
      setState(() {
        if (!more) _items.clear();
        final ids = _items.map((item) => item.id).toSet();
        _items.addAll(next.where((item) => ids.add(item.id)));
        _page = page;
        _hasMore = pagination != null
            ? page < ((pagination['totalPages'] as num?)?.toInt() ?? page)
            : next.length == 20;
      });
    } catch (_) {
      if (mounted && request == _request) {
        setState(() => _error = 'Could not load bookings. Please try again.');
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => ScrollNotificationObserver(
    child: Scaffold(
      headers: [
        ScrollAwareAppBar(
          title: const Text('Bookings'),
          leading: [
            IconButton.ghost(
              icon: const Icon(LucideIcons.arrowLeft),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
      child: SafeArea(
        top: false,
        child: RefreshTrigger(
          onRefresh: _load,
          child: ListView(
            key: const Key('bookings-page'),
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Button(
                      style: _history
                          ? const ButtonStyle.outline()
                          : const ButtonStyle.primary(),
                      onPressed: () => setState(() => _history = false),
                      child: const Text('Upcoming'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Button(
                      style: _history
                          ? const ButtonStyle.primary()
                          : const ButtonStyle.outline(),
                      onPressed: () => setState(() => _history = true),
                      child: const Text('History'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (widget.repository == null)
                const Text('Bookings are unavailable in this build.')
              else ...[
                if (_loading && _items.isEmpty)
                  const Center(child: CircularProgressIndicator()),
                if (_error != null) ...[
                  Text(_error!),
                  const SizedBox(height: 12),
                  GetPrioActionButton.outline(
                    onPressed: () => _load(),
                    child: const Text('Try again'),
                  ),
                ],
                if (!_loading &&
                    _error == null &&
                    _items.where((item) => item.isUpcoming != _history).isEmpty)
                  Card(
                    child: Text(
                      _history ? 'No past bookings yet.' : 'No upcoming bookings. Choose a vendor to plan a visit.',
                    ),
                  ),
                for (final item in _items.where(
                  (item) => item.isUpcoming != _history,
                ))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Button(
                      style: const ButtonStyle.ghost(),
                      onPressed: () async {
                        await Navigator.of(context).push(
                          SwipeBackPageRoute<void>(
                            builder: (_) => BookingDetailPage(
                              repository: widget.repository!,
                              booking: item,
                            ),
                          ),
                        );
                        if (mounted) await _load();
                      },
                      child: Card(
                        child: SizedBox(
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(item.vendorName).bold()),
                                  const Icon(
                                    LucideIcons.chevronRight,
                                    size: 18,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${item.locationName} · ${item.serviceName}',
                              ),
                              const SizedBox(height: 8),
                              Text(bookingDateLabel(item.startAt)),
                              const SizedBox(height: 8),
                              Text(
                                'Booking: ${bookingStatusLabel(item.status)}',
                              ),
                              Text(
                                'Payment: ${bookingStatusLabel(item.paymentStatus)}',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_hasMore)
                  GetPrioActionButton.outline(
                    onPressed: _loading ? null : () => _load(more: true),
                    child: Text(_loading ? 'Loading...' : 'Load more'),
                  ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class BookingDetailPage extends StatefulWidget {
  const BookingDetailPage({
    super.key,
    required this.repository,
    required this.booking,
  });
  final BookingRepository repository;
  final CustomerBooking booking;
  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
  late Future<CustomerBooking> _detail;
  @override
  void initState() {
    super.initState();
    _detail = widget.repository.detail(widget.booking.id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    headers: [
      AppBar(
        title: const Text('Booking details'),
        leading: [
          IconButton.ghost(
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    ],
    child: SafeArea(
      top: false,
      child: FutureBuilder<CustomerBooking>(
        future: _detail,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: GetPrioActionButton.outline(
                onPressed: () => setState(
                  () => _detail = widget.repository.detail(widget.booking.id),
                ),
                child: const Text('Try again'),
              ),
            );
          }
          final item = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(item.reference).h2(),
              const SizedBox(height: 12),
              Text(item.vendorName).bold(),
              Text(item.locationName),
              const SizedBox(height: 20),
              Text(bookingDateLabel(item.startAt)),
              const SizedBox(height: 12),
              Text('Booking: ${bookingStatusLabel(item.status)}'),
              Text('Payment: ${bookingStatusLabel(item.paymentStatus)}'),
              const SizedBox(height: 12),
              Text(item.nextStep).bold(),
              if (item.canSubmitProof) ...[
                const SizedBox(height: 20),
                BookingPayment(
                  key: ValueKey(item.id),
                  repository: widget.repository,
                  booking: item,
                  onSubmitted: (updated) => setState(() {
                    _detail = Future.value(updated);
                  }),
                ),
              ],
              if (item.hasPaymentProof) ...[
                const SizedBox(height: 12),
                Text(
                  'Payment reference: ${item.data['paymentReference'] ?? ''}',
                ),
                Text(
                  'Receipt: ${(item.data['paymentProof'] as Map)['fileName'] ?? 'Submitted'}',
                ),
              ],
              const SizedBox(height: 12),
              OutlineButton(
                onPressed: () => setState(() {
                  _detail = widget.repository.detail(widget.booking.id);
                }),
                child: const Text('Refresh status'),
              ),
              const SizedBox(height: 20),
              const Text('Services').h3(),
              for (final service
                  in (item.data['bundleItems'] as List? ?? [])
                      .whereType<Map<String, dynamic>>())
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${service['serviceName']} × ${service['bookingQuantity'] ?? 1}',
                  ),
                ),
              if ((item.data['bundleItems'] as List? ?? []).isEmpty)
                Text(item.serviceName),
              if (item.data['pendingExpiresAt'] != null) ...[
                const SizedBox(height: 20),
                Text(
                  'Pending deadline: ${bookingDateLabel(DateTime.tryParse('${item.data['pendingExpiresAt']}')?.toLocal())}',
                ),
              ],
              if ('${item.data['paymentRejectionReason'] ?? ''}'
                  .isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('${item.data['paymentRejectionReason']}'),
              ],
              if ('${item.data['expirationReason'] ?? ''}'.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('${item.data['expirationReason']}'),
              ],
              const SizedBox(height: 20),
              const Text(
                'A queue ticket is created after the vendor checks you in.',
              ),
            ],
          );
        },
      ),
    ),
  );
}
