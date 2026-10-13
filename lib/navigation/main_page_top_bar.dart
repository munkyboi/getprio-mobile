import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../account/ticket_repository.dart';
import '../app_theme.dart';
import '../queue/queue_models.dart';

class MainPageTopBarScope extends InheritedWidget {
  const MainPageTopBarScope({
    super.key,
    required super.child,
    this.tickets,
    required this.unreadCount,
    required this.onNotifications,
    this.onTicket,
    this.activePage,
  });
  final String? activePage;
  final QueueTicketRepository? tickets;
  final ValueListenable<int> unreadCount;
  final VoidCallback onNotifications;
  final ValueChanged<QueueTicket>? onTicket;
  static MainPageTopBarScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MainPageTopBarScope>();
  @override
  bool updateShouldNotify(MainPageTopBarScope oldWidget) =>
      activePage != oldWidget.activePage ||
      tickets != oldWidget.tickets ||
      unreadCount != oldWidget.unreadCount ||
      onNotifications != oldWidget.onNotifications ||
      onTicket != oldWidget.onTicket;
}

String ticketQuickstats(QueueTicket ticket) {
  final number = ticket.ticketNumber ?? ticket.lookupCode;
  if (ticket.status != TicketStatus.waiting) {
    return '$number · ${ticket.displayStatusLabel}';
  }
  return [
    number,
    if (ticket.position != null) '#${ticket.position}',
    if (ticket.estimatedWaitMinutes != null)
      'in ${ticket.estimatedWaitMinutes}mins',
  ].join(' ');
}

/// Part of each page's scrolling content, with no background or fixed header.
class MainPageTopBar extends StatelessWidget {
  const MainPageTopBar({super.key, required this.scope, this.active = true});
  final bool active;
  final MainPageTopBarScope scope;
  @override
  Widget build(BuildContext context) {
    Widget stats(List<QueueTicket> tickets) {
      final active = tickets
          .where(
            (t) =>
                t.isActive && !t.isServiceCompleted && !t.isServiceInterrupted,
          )
          .toList();
      return _CyclingTicketStats(
        tickets: active,
        onTicket: scope.onTicket,
        active: this.active,
      );
    }

    return SizedBox(
      key: const Key('main-page-top-bar'),
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: scope.tickets == null
                  ? stats([])
                  : ValueListenableBuilder<List<QueueTicket>>(
                      valueListenable: scope.tickets!.overviewTickets,
                      builder: (_, tickets, _) => stats(tickets),
                    ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<int>(
            valueListenable: scope.unreadCount,
            builder: (_, count, _) => Semantics(
              label: 'Notifications, $count unread',
              button: true,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IconButton.ghost(
                        key: const Key('main-notification-center'),
                        icon: const Icon(LucideIcons.bell, size: 22),
                        onPressed: scope.onNotifications,
                      ),
                    ),
                    if (count > 0)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IgnorePointer(
                          child: Container(
                            key: const Key('main-notification-unread-badge'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: GetPrioTheme.destructive,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              count > 99 ? '99+' : '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
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
}

class _CyclingTicketStats extends StatefulWidget {
  const _CyclingTicketStats({
    required this.tickets,
    required this.onTicket,
    required this.active,
  });
  final List<QueueTicket> tickets;
  final ValueChanged<QueueTicket>? onTicket;
  final bool active;
  @override
  State<_CyclingTicketStats> createState() => _CyclingTicketStatsState();
}

class _CyclingTicketStatsState extends State<_CyclingTicketStats>
    with WidgetsBindingObserver {
  Timer? _timer;
  int _index = 0;
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void _start() {
    _timer?.cancel();
    _timer = null;
    if (!widget.active || !_foreground || widget.tickets.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? true)) {
        setState(() => _index = (_index + 1) % widget.tickets.length);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _CyclingTicketStats oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = oldWidget.tickets.isEmpty
        ? null
        : oldWidget.tickets[_index % oldWidget.tickets.length].id;
    final next = widget.tickets.indexWhere((ticket) => ticket.id == current);
    _index = next < 0 ? 0 : next;
    if (oldWidget.active != widget.active ||
        oldWidget.tickets.length != widget.tickets.length) {
      _start();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.tickets.isEmpty ? null : widget.tickets[_index];
    return ClipRect(
      child: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 280),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.centerLeft,
          children: [...previous, ?current],
        ),
        transitionBuilder: (child, animation) => AnimatedBuilder(
          animation: animation,
          builder: (_, _) => Transform.translate(
            offset: Offset(
              0,
              44 *
                  (animation.status == AnimationStatus.reverse
                      ? animation.value - 1
                      : 1 - animation.value),
            ),
            child: Opacity(opacity: animation.value, child: child),
          ),
        ),
        child: ticket == null
            ? const Text('No active tickets', key: ValueKey('empty-quickstats'))
            : LinkButton(
                density: ButtonDensity.compact,
                key: ValueKey('main-ticket-quickstats-${ticket.id}'),
                onPressed: widget.onTicket == null
                    ? null
                    : () => widget.onTicket!(ticket),
                child: Text(
                  ticketQuickstats(ticket),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ).bold(),
              ),
      ),
    );
  }
}
