import 'package:flutter/foundation.dart';

import '../queue/auth_queue_api.dart';
import '../queue/queue_models.dart';

abstract interface class AccountQueueApi {
  Future<Map<String, dynamic>> loadOverview();

  Future<Map<String, dynamic>> loadHistory({
    required int page,
    required int limit,
  });
}

class QueueTicketRepository {
  QueueTicketRepository(this.api);

  final AccountQueueApi api;
  final refreshVersion = ValueNotifier<int>(0);
  final servedTicket = ValueNotifier<QueueTicket?>(null);
  final Set<String> _observedActive = {};

  void _observeTickets(List<QueueTicket> tickets) {
    for (final ticket in tickets) {
      if (ticket.isActive) _observedActive.add(ticket.lookupCode);
      if (ticket.status == TicketStatus.served &&
          _observedActive.remove(ticket.lookupCode)) {
        servedTicket.value = ticket;
      }
    }
  }

  List<QueueTicket> _latestTickets = const [];

  bool get hasActiveTickets => _latestTickets.any((ticket) => ticket.isActive);

  void requestRefresh() => refreshVersion.value++;
  void clearSession() {
    _latestTickets = const [];
    _observedActive.clear();
    servedTicket.value = null;
  }

  Future<List<QueueTicket>> loadOverview() async {
    final tickets = _ticketsFrom(await api.loadOverview());
    _observeTickets(tickets);
    _latestTickets = tickets;
    return tickets;
  }

  Future<List<QueueTicket>> loadHistory({int page = 1, int limit = 20}) async {
    final tickets = _ticketsFrom(
      await api.loadHistory(page: page, limit: limit),
    );
    _observeTickets(tickets);
    return tickets;
  }

  Future<List<QueueTicket>> loadAllTickets({
    int historyPage = 1,
    int historyLimit = 20,
  }) async {
    final overview = await loadOverview();
    final history = await loadHistory(page: historyPage, limit: historyLimit);
    final ticketsByKey = <String, QueueTicket>{};

    for (final ticket in [...overview, ...history]) {
      final key = ticket.id.trim().isNotEmpty
          ? 'id:${ticket.id}'
          : 'lookup:${ticket.lookupCode}';
      ticketsByKey.putIfAbsent(key, () => ticket);
    }

    final tickets = ticketsByKey.values.toList(growable: false);
    _observeTickets(tickets);
    _latestTickets = tickets;
    return tickets;
  }

  List<QueueTicket> _ticketsFrom(Map<String, dynamic> response) {
    final rawTickets = response['tickets'] ?? response['items'];
    if (rawTickets is! List) return const [];
    return rawTickets
        .whereType<Map<String, dynamic>>()
        .map(QueueTicket.fromJson)
        .toList(growable: false);
  }
}

class RestAccountQueueApi implements AccountQueueApi {
  RestAccountQueueApi(this.client);

  final AuthenticatedApiClient client;

  @override
  Future<Map<String, dynamic>> loadOverview() {
    return client.get('/api/account/overview');
  }

  @override
  Future<Map<String, dynamic>> loadHistory({
    required int page,
    required int limit,
  }) {
    return client.get(
      '/api/account/history',
      queryParameters: {'page': '$page', 'limit': '$limit'},
    );
  }
}
