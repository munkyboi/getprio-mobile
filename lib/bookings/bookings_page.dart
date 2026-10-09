import 'dart:async';

import '../details/detail_pass.dart';
import '../directory/directory_repository.dart';
import '../queue/queue_models.dart';

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
    this.directoryRepository,
    this.pollInterval = const Duration(seconds: 15),
  });
  final BookingRepository repository;
  final CustomerBooking booking;
  final DirectoryRepository? directoryRepository;
  final Duration pollInterval;
  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage>
    with WidgetsBindingObserver {
  late CustomerBooking _item;
  VendorSummary? _vendor;
  Timer? _poll;
  bool _fetching = false, _foreground = true, _vendorRequested = false;
  String? _syncError;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _item = widget.booking;
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _poll = Timer.periodic(widget.pollInterval, (_) {
      if (_foreground && (ModalRoute.of(context)?.isCurrent ?? true)) {
        _refresh();
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && (ModalRoute.of(context)?.isCurrent ?? true)) _refresh();
  }

  Future<void> _loadVendor(CustomerBooking item) async {
    if (_vendorRequested) return;
    final slug = '${item.data['tenantSlug'] ?? ''}';
    if (slug.isEmpty) return;
    final api = widget.repository.api;
    final repository =
        widget.directoryRepository ??
        (api is RestBookingApi
            ? DirectoryRepository(RestDirectoryApi(api.client))
            : null);
    if (repository == null) return;
    _vendorRequested = true;
    try {
      final vendor = await repository.loadVendor(slug);
      if (mounted) setState(() => _vendor = vendor);
    } catch (_) {
      _vendorRequested = false;
    }
  }

  Future<void> _refresh() async {
    if (_fetching || !mounted) return;
    final request = ++_request;
    setState(() => _fetching = true);
    try {
      final item = await widget.repository.detail(widget.booking.id);
      if (!mounted || request != _request) return;
      setState(() {
        _item = item;
        _syncError = null;
      });
      unawaited(_loadVendor(item));
    } catch (_) {
      if (mounted && request == _request) {
        setState(
          () => _syncError = 'Could not update booking status. Showing the last available details.',
        );
      }
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  void _proofSubmitted(CustomerBooking updated) {
    // Discard any fetch started before proof submission so it cannot restore the unpaid form.
    _request++;
    setState(() {
      _item = updated;
      _syncError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final vendor =
        _vendor ??
        VendorSummary(
          slug: '${item.data['tenantSlug'] ?? 'booking'}',
          name: item.vendorName,
          queueAvailable: false,
        );
    final services = (item.data['bundleItems'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    return Scaffold(
      headers: const [DetailPassAppBar(title: 'Booking details')],
      child: SafeArea(
        top: false,
        child: ListView(
          key: const Key('booking-details-page'),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
          children: [
            DetailPassCard(
              key: const Key('booking-details-card'),
              vendor: vendor,
              children: [
                const Text('Your booking').h3(),
                const SizedBox(height: 12),
                Text(
                  item.reference.isEmpty ? 'Booking request' : item.reference,
                ).h2(),
                const SizedBox(height: 12),
                Text(item.vendorName).bold(),
                Text(item.locationName),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SecondaryBadge(
                      child: Text(
                        'Booking: ${bookingStatusLabel(item.status)}',
                      ),
                    ),
                    OutlineBadge(
                      child: Text(
                        'Payment: ${bookingStatusLabel(item.paymentStatus)}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: GetPrioTheme.paperAccent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(item.nextStep),
                ),
                const DetailPassDivider(),
                DetailPassField(
                  label: 'Scheduled visit',
                  value: bookingDateLabel(item.startAt),
                ),
                if ('${item.data['customerName'] ?? ''}'.isNotEmpty)
                  DetailPassField(
                    label: 'Customer',
                    value: '${item.data['customerName']}',
                  ),
                const SizedBox(height: 12),
                const Text('Services').h3(),
                if (services.isEmpty)
                  DetailPassField(label: 'Service', value: item.serviceName)
                else
                  for (final service in services)
                    DetailPassField(
                      label: '${service['serviceName'] ?? 'Service'}',
                      value: 'Quantity: ${service['bookingQuantity'] ?? 1}',
                    ),
                if ('${item.data['notes'] ?? ''}'.isNotEmpty)
                  DetailPassField(
                    label: 'Notes',
                    value: '${item.data['notes']}',
                  ),
                if (item.status == 'pending' &&
                    item.data['pendingExpiresAt'] != null)
                  DetailPassField(
                    label: 'Pending deadline',
                    value: bookingDateLabel(
                      DateTime.tryParse('${item.data['pendingExpiresAt']}')
                          ?.toLocal(),
                    ),
                  ),
                if ('${item.data['paymentRejectionReason'] ?? ''}'.isNotEmpty)
                  DetailPassField(
                    label: 'Payment review',
                    value: '${item.data['paymentRejectionReason']}',
                  ),
                if ('${item.data['expirationReason'] ?? ''}'.isNotEmpty)
                  DetailPassField(
                    label: 'Expiration reason',
                    value: '${item.data['expirationReason']}',
                  ),
                if (item.canSubmitProof) ...[
                  const DetailPassDivider(),
                  BookingPayment(
                    key: ValueKey(item.id),
                    repository: widget.repository,
                    booking: item,
                    onSubmitted: _proofSubmitted,
                  ),
                ],
                if (item.hasPaymentProof) ...[
                  const DetailPassDivider(),
                  DetailPassField(
                    label: 'Payment reference',
                    value: '${item.data['paymentReference'] ?? ''}',
                  ),
                  DetailPassField(
                    label: 'Receipt',
                    value:
                        '${(item.data['paymentProof'] as Map)['fileName'] ?? 'Submitted'}',
                  ),
                ],
                const DetailPassDivider(),
                const Text(
                  'A queue ticket is created after the vendor checks you in.',
                ),
                const SizedBox(height: 16),
                if (_syncError != null) ...[
                  Text(_syncError!),
                  const SizedBox(height: 8),
                  OutlineButton(
                    onPressed: _fetching ? null : _refresh,
                    child: const Text('Try again'),
                  ),
                ],
                OutlineButton(
                  onPressed: _fetching ? null : _refresh,
                  child: Text(_fetching ? 'Updating...' : 'Refresh status'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
