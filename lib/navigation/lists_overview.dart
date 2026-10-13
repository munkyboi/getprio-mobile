import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../account/ticket_repository.dart';
import '../bookings/booking_repository.dart';
import '../bookings/booking_list_row.dart';
import '../queue/ticket_list_row.dart';
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
  bool _ticketsRefreshPending = false;
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
    if (repository == null) return;
    if (_loadingTickets) {
      _ticketsRefreshPending = true;
      return;
    }
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
      if (mounted) {
        setState(() => _loadingTickets = false);
        if (_ticketsRefreshPending) {
          _ticketsRefreshPending = false;
          if (widget.active) _loadTickets();
        }
      }
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
      for (final (index, ticket) in _tickets.indexed) ...[
        TicketListRow(
          key: ValueKey('lists-ticket-${ticket.id}'),
          ticket: ticket,
          onPressed: widget.onOpenTicket == null
              ? null
              : () async {
                  await widget.onOpenTicket!(ticket);
                  if (mounted) _loadTickets();
                },
        ),
        if (index < _tickets.length - 1) const Divider(),
      ],
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
