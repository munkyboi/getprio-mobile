import '../navigation/list_filter_tabs.dart';
import 'booking_list_row.dart';

import 'dart:async';

import '../auth/auth_repository.dart';

import '../details/detail_pass.dart';
import '../directory/directory_repository.dart';
import '../queue/queue_models.dart';

import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../app_theme.dart';
import '../navigation/scroll_aware_app_bar.dart';
import '../navigation/swipe_back_page_route.dart';
import 'booking_repository.dart';
import 'booking_payment.dart';
import 'booking_presentation.dart';

String bookingDateLabel(DateTime? date) => date == null
    ? 'Schedule unavailable'
    : '${date.day}/${date.month}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
String bookingStatusLabel(String status) => status.replaceAll('_', ' ');

class BookingsPage extends StatefulWidget {
  const BookingsPage({
    super.key,
    this.repository,
    this.onOpenTicket,
    this.onCheckedIn,
  });
  final Future<void> Function(CustomerBooking)? onOpenTicket;
  final VoidCallback? onCheckedIn;
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
              ListFilterTabs(
                key: const Key('booking-tabs'),
                labels: const ['Upcoming', 'History'],
                index: _history ? 1 : 0,
                onChanged: (index) => setState(() => _history = index == 1),
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
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      _history ? 'No past bookings yet.' : 'No upcoming bookings. Choose a vendor to plan a visit.',
                    ),
                  ),
                for (final item in _items.where(
                  (item) => item.isUpcoming != _history,
                ))
                  BookingListRow(
                    booking: item,
                    onPressed: () async {
                      await Navigator.of(context).push(
                        SwipeBackPageRoute<void>(
                          builder: (_) => BookingDetailPage(
                            repository: widget.repository!,
                            booking: item,
                            onOpenTicket: widget.onOpenTicket,
                            onCheckedIn: widget.onCheckedIn,
                          ),
                        ),
                      );
                      if (mounted) await _load();
                    },
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
    this.onOpenTicket,
    this.onCheckedIn,
    this.now,
    this.pollInterval = const Duration(seconds: 15),
  });
  final BookingRepository repository;
  final CustomerBooking booking;
  final DirectoryRepository? directoryRepository;
  final Duration pollInterval;
  final Future<void> Function(CustomerBooking)? onOpenTicket;
  final VoidCallback? onCheckedIn;
  final DateTime Function()? now;
  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage>
    with WidgetsBindingObserver {
  late CustomerBooking _item;
  VendorSummary? _vendor;
  Timer? _poll, _clock;
  bool _arriving = false, _openingTicket = false;
  String? _arrivalError;
  DateTime get _now => widget.now?.call() ?? DateTime.now();
  final Map<String, String> _serviceImages = {};
  bool _imagesRequested = false;
  bool _fetching = false, _foreground = true, _vendorRequested = false;
  String? _syncError;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _item = widget.booking;
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_foreground && (ModalRoute.of(context)?.isCurrent ?? true)) {
        setState(() {});
      }
    });
    _poll = Timer.periodic(widget.pollInterval, (_) {
      if (_foreground && (ModalRoute.of(context)?.isCurrent ?? true)) {
        _refresh();
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _clock?.cancel();
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

  Future<void> _loadServiceImages(CustomerBooking item) async {
    if (_imagesRequested) return;
    final vendor = '${item.data['tenantSlug'] ?? ''}';
    final location = '${item.data['locationSlug'] ?? ''}';
    if (vendor.isEmpty || location.isEmpty) return;
    _imagesRequested = true;
    try {
      final services = await widget.repository.services(vendor, location);
      if (mounted) {
        setState(() {
          for (final service in services) {
            _serviceImages[service.slug] = service.imageUrl;
          }
        });
      }
    } catch (_) {
      _imagesRequested = false;
    }
  }

  Future<void> _refresh() async {
    if (_fetching || _arriving || !mounted) return;
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
      unawaited(_loadServiceImages(item));
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

  Future<void> _checkIn() async {
    if (_arriving || !_item.canCheckIn(_now)) return;
    _request++;
    setState(() {
      _arriving = true;
      _arrivalError = null;
    });
    try {
      final updated = await widget.repository.checkIn(_item, _now);
      if (!mounted) return;
      _proofSubmitted(updated);
      widget.onCheckedIn?.call();
    } catch (error) {
      if (mounted) {
        setState(
          () => _arrivalError = error is ApiException
              ? error.message
              : 'Could not record arrival. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _arriving = false);
    }
    // Reconcile a lost response or a concurrent staff check-in before retrying.
    if (_arrivalError != null && mounted) await _refresh();
  }

  Future<void> _openTicket() async {
    if (_openingTicket ||
        _item.linkedTicket == null ||
        widget.onOpenTicket == null) {
      return;
    }
    setState(() => _openingTicket = true);
    try {
      await widget.onOpenTicket!(_item);
      if (mounted) await _refresh();
    } catch (_) {
      if (mounted) {
        setState(
          () => _arrivalError =
              'Could not open your queue ticket. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _openingTicket = false);
    }
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
    final services = bookingServiceItems(item);
    final starts =
        services
            .map((s) => bookingTime(s['scheduledStartAt']))
            .whereType<DateTime>()
            .toList()
          ..sort();
    final ends =
        services
            .map((s) => bookingTime(s['scheduledEndAt']))
            .whereType<DateTime>()
            .toList()
          ..sort();
    final start = starts.isEmpty ? item.startAt : starts.first;
    final end = ends.isEmpty
        ? bookingTime(item.data['scheduledEndAt'])
        : ends.last;
    final minutes = start != null && end != null
        ? end.difference(start).inMinutes
        : 0;
    final duration = minutes <= 0
        ? 'Schedule set'
        : minutes < 60
        ? '$minutes min'
        : '${(minutes / 60).toStringAsFixed(minutes % 60 == 0 ? 0 : 1)} hrs';
    final group = item.data['groupFundedCampaign'];
    final amounts = services
        .map((s) => s['priceAmountCents'])
        .whereType<num>()
        .toList();
    final total = group is Map && group['targetAmountCents'] is num
        ? (group['targetAmountCents'] as num) +
              ((group['roundingAdjustmentCents'] as num?) ?? 0)
        : amounts.length == services.length
        ? amounts.fold<num>(0, (a, b) => a + b)
        : null;
    final currency = group is Map
        ? group['currency']
        : item.data['serviceCurrency'] ?? services.first['currency'];
    return Scaffold(
      headers: const [DetailPassAppBar(title: 'Booking details')],
      child: SafeArea(
        top: false,
        child: ListView(
          key: const Key('booking-details-page'),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  key: const Key('booking-details-alert'),
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: GetPrioTheme.info.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: GetPrioTheme.info.withValues(alpha: .2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            LucideIcons.info,
                            size: 20,
                            color: GetPrioTheme.info,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item.canCheckIn(_now)
                                  ? 'When you are at the location, tap I’ve arrived to get your queue ticket. Your booked time is the earliest the vendor can call it.'
                                  : item.nextStep,
                            ),
                          ),
                        ],
                      ),
                      if (item.linkedTicket != null) ...[
                        const SizedBox(height: 8),
                        LinkButton(
                          key: const Key('booking-queue-link'),
                          onPressed:
                              _openingTicket || widget.onOpenTicket == null
                              ? null
                              : _openTicket,
                          child: Text(
                            _openingTicket
                                ? 'Opening ticket...'
                                : 'Open queue ticket ${item.linkedTicket!['ticketNumber'] ?? ''}',
                          ),
                        ),
                      ],
                      if (_arrivalError != null) ...[
                        const SizedBox(height: 8),
                        Text(_arrivalError!),
                      ],
                    ],
                  ),
                ),
                DetailPassCard(
                  key: const Key('booking-details-card'),
                  vendor: vendor,
                  children: [
                    Text(
                      item.reference.isEmpty
                          ? 'Booking request'
                          : item.reference,
                      style: Theme.of(context).typography.h2,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        BookingStatusBadge(
                          status: item.status,
                          label: 'Booking: ${bookingStatusLabel(item.status)}',
                        ),
                        BookingStatusBadge(
                          status: item.paymentStatus,
                          label:
                              'Payment: ${bookingStatusLabel(item.paymentStatus)}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          LucideIcons.mapPin,
                          size: 20,
                          color: GetPrioTheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.vendorName).bold(),
                              if (item.locationName.isNotEmpty)
                                Text(item.locationName),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: GetPrioTheme.colors(context).paperAccent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(LucideIcons.calendarDays, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  start == null
                                      ? 'Schedule unavailable'
                                      : bookingDay(start),
                                ).bold(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            bookingRange(
                              start?.toIso8601String(),
                              end?.toIso8601String(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 20,
                            runSpacing: 8,
                            children: [
                              Text(
                                '$duration · ${services.length} ${services.length == 1 ? 'service' : 'services'}',
                              ),
                              if (total != null)
                                Text(
                                  'Total fee ${bookingMoney(total, currency)}',
                                ).bold(),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (item.linkedTicket == null) ...[
                      PrimaryButton(
                        key: const Key('booking-check-in'),
                        onPressed: _arriving || !item.canCheckIn(_now)
                            ? null
                            : _checkIn,
                        child: Text(
                          _arriving
                              ? 'Recording arrival...'
                              : item.checkInLabel(_now),
                        ),
                      ),
                    ],
                    const DetailPassDivider(),
                    const Text('Booked services').h3(),
                    for (final service in services)
                      BookingServiceCard(
                        item: service,
                        imageUrl:
                            '${service['imageUrl'] ?? _serviceImages[service['serviceSlug']] ?? ''}',
                      ),
                    if ('${item.data['customerName'] ?? ''}'.isNotEmpty ||
                        '${item.data['customerPhone'] ?? ''}'.isNotEmpty) ...[
                      const DetailPassDivider(),
                      const Text('Your visit').h3(),
                      if ('${item.data['customerName'] ?? ''}'.isNotEmpty)
                        DetailPassField(
                          label: 'Customer',
                          value: '${item.data['customerName']}',
                        ),
                      if ('${item.data['customerPhone'] ?? ''}'.isNotEmpty)
                        DetailPassField(
                          label: 'Mobile number',
                          value: '${item.data['customerPhone']}',
                        ),
                    ],
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
                          bookingTime(item.data['pendingExpiresAt']),
                        ),
                      ),
                    if ('${item.data['expirationReason'] ?? ''}'.isNotEmpty)
                      DetailPassField(
                        label: 'Expiration reason',
                        value: '${item.data['expirationReason']}',
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                BookingSection(
                  key: const Key('booking-payment-section'),
                  children: [
                    const Text('Your payment').h3(),
                    const SizedBox(height: 14),
                    if (item.canSubmitProof)
                      BookingPayment(
                        key: ValueKey(item.id),
                        repository: widget.repository,
                        booking: item,
                        onSubmitted: _proofSubmitted,
                      )
                    else if (item.hasPaymentProof)
                      BookingProofSummary(
                        key: ValueKey(item.id),
                        booking: item,
                        repository: widget.repository,
                      )
                    else ...[
                      Text('Payment: ${bookingStatusLabel(item.paymentStatus)}')
                          .bold(),
                      const SizedBox(height: 8),
                      Text(
                        item.data['bookingPaymentSource'] == 'group_funded'
                            ? 'Payment is managed through your group-funded campaign.'
                            : item.requiresManualPayment
                            ? 'No payment receipt was submitted for this booking.'
                            : 'No manual payment proof is required for this booking.',
                      ),
                      if ('${item.data['paymentRejectionReason'] ?? ''}'
                          .isNotEmpty)
                        DetailPassField(
                          label: 'Vendor review',
                          value: '${item.data['paymentRejectionReason']}',
                        ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                if (_syncError != null) ...[
                  Text(_syncError!),
                  const SizedBox(height: 8),
                  OutlineButton(
                    onPressed: _fetching ? null : _refresh,
                    child: const Text('Try again'),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlineButton(
                  onPressed: _fetching ? null : _refresh,
                  child: Text(_fetching ? 'Updating...' : 'Refresh status'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Status updates automatically while this screen is open.',
                  style: Theme.of(context).typography.small
                      .copyWith(color: GetPrioTheme.colors(context).mutedInk),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
