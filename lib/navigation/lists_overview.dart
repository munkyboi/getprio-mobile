import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../account/ticket_repository.dart';
import '../app_theme.dart';
import '../bookings/booking_repository.dart';
import '../bookings/booking_list_row.dart';
import '../bookings/booking_presentation.dart';
import '../queue/queue_models.dart';

class ListsOverview extends StatefulWidget {
  const ListsOverview({
    super.key,
    required this.active,
    this.ticketRepository,
    this.bookingRepository,
    this.onOpenTicket,
    this.onOpenBooking,
  });
  final bool active;
  final QueueTicketRepository? ticketRepository;
  final BookingRepository? bookingRepository;
  final Future<void> Function(QueueTicket)? onOpenTicket;
  final Future<void> Function(CustomerBooking)? onOpenBooking;
  @override
  State<ListsOverview> createState() => _ListsOverviewState();
}

class _ListsOverviewState extends State<ListsOverview>
    with WidgetsBindingObserver {
  List<QueueTicket> _tickets = [];
  List<CustomerBooking> _bookings = [];
  bool _loadingTickets = false, _loadingBookings = false;
  String? _ticketError, _bookingError;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.ticketRepository?.refreshVersion.addListener(_signal);
    if (widget.active) _signal();
  }

  @override
  void didUpdateWidget(ListsOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ticketRepository != widget.ticketRepository) {
      oldWidget.ticketRepository?.refreshVersion.removeListener(_signal);
      widget.ticketRepository?.refreshVersion.addListener(_signal);
    }
    if (widget.active &&
        (!oldWidget.active ||
            oldWidget.ticketRepository != widget.ticketRepository)) {
      _signal();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _signal();
  }

  @override
  void dispose() {
    widget.ticketRepository?.refreshVersion.removeListener(_signal);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _signal() {
    if (widget.active) {
      _loadTickets();
      _loadBookings();
    }
  }

  Future<void> _loadTickets() async {
    final repository = widget.ticketRepository;
    if (repository == null || _loadingTickets) return;
    setState(() {
      _loadingTickets = true;
      _ticketError = null;
    });
    try {
      final tickets = await repository.loadOverview();
      if (mounted) {
        setState(() => _tickets = tickets.where((t) => t.isActive).toList());
      }
    } catch (_) {
      if (mounted) {
        setState(() => _ticketError = 'Could not update queue tickets.');
      }
    } finally {
      if (mounted) setState(() => _loadingTickets = false);
    }
  }

  Future<void> _loadBookings() async {
    final repository = widget.bookingRepository;
    if (repository == null || _loadingBookings) return;
    setState(() {
      _loadingBookings = true;
      _bookingError = null;
    });
    try {
      final bookings = await repository.upcoming();
      if (mounted) setState(() => _bookings = bookings);
    } catch (_) {
      if (mounted) {
        setState(() => _bookingError = 'Could not update upcoming bookings.');
      }
    } finally {
      if (mounted) setState(() => _loadingBookings = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 28),
      const Text('Active queue tickets').h3(),
      const SizedBox(height: 8),
      if (_loadingTickets && _tickets.isEmpty)
        const Center(child: CircularProgressIndicator()),
      if (_ticketError != null) ...[
        Text(_ticketError!),
        LinkButton(
          onPressed: _loadingTickets ? null : _loadTickets,
          child: const Text('Retry tickets'),
        ),
      ],
      if (!_loadingTickets && _ticketError == null && _tickets.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('No active queue tickets.'),
        ),
      for (final ticket in _tickets)
        Button(
          key: ValueKey('lists-ticket-${ticket.id}'),
          style: const ButtonStyle.ghost(density: ButtonDensity.compact),
          onPressed: widget.onOpenTicket == null
              ? null
              : () async {
                  await widget.onOpenTicket!(ticket);
                  if (mounted) _loadTickets();
                },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: GetPrioTheme.line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ticket.vendorName ?? 'Queue ticket').bold(),
                      if (ticket.locationName != null)
                        Text(ticket.locationName!),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(ticket.ticketNumber ?? ticket.lookupCode).bold(),
                          BookingStatusBadge(
                            status: ticket.isConfirmed
                                ? 'confirmed'
                                : ticket.status.name,
                            label: ticket.displayStatusLabel,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: GetPrioTheme.mutedInk,
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 28),
      const Text('Upcoming bookings').h3(),
      const SizedBox(height: 8),
      if (_loadingBookings && _bookings.isEmpty)
        const Center(child: CircularProgressIndicator()),
      if (_bookingError != null) ...[
        Text(_bookingError!),
        LinkButton(
          onPressed: _loadingBookings ? null : _loadBookings,
          child: const Text('Retry bookings'),
        ),
      ],
      if (!_loadingBookings && _bookingError == null && _bookings.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('No upcoming bookings.'),
        ),
      for (final booking in _bookings)
        BookingListRow(
          key: ValueKey('lists-booking-${booking.id}'),
          booking: booking,
          onPressed: () async {
            if (widget.onOpenBooking == null) return;
            await widget.onOpenBooking!(booking);
            if (mounted) _loadBookings();
          },
        ),
    ],
  );
}
