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
  RestAccountQueueApi(this.client, {this.sandbox = false});

  final AuthenticatedApiClient client;
  final bool sandbox;

  @override
  Future<Map<String, dynamic>> loadOverview() {
    if (sandbox) return _loadSandboxTickets(view: 'active');
    return client.get('/api/account/overview');
  }

  @override
  Future<Map<String, dynamic>> loadHistory({
    required int page,
    required int limit,
  }) {
    if (sandbox) {
      return _loadSandboxTickets(view: 'history', limit: limit);
    }
    return client.get(
      '/api/account/history',
      queryParameters: {'page': '$page', 'limit': '$limit'},
    );
  }

  Future<Map<String, dynamic>> _loadSandboxTickets({
    required String view,
    int limit = 20,
  }) async {
    final response = await client.get(
      '/api/mobile/tickets',
      queryParameters: {'view': view, 'limit': '$limit'},
    );
    final rawTickets = response['tickets'];
    if (rawTickets is! List) return const {'tickets': <dynamic>[]};
    return {
      'tickets': rawTickets
          .whereType<Map<String, dynamic>>()
          .map(_sandboxTicketToQueueTicketJson)
          .toList(growable: false),
    };
  }

  Map<String, dynamic> _sandboxTicketToQueueTicketJson(
    Map<String, dynamic> ticket,
  ) {
    final profile = ticket['profile'];
    final profileJson = profile is Map<String, dynamic>
        ? profile
        : const <String, dynamic>{};
    return {
      'id': ticket['id'],
      'lookupCode': ticket['external_reference'] ?? ticket['id'],
      'ticketNumber': ticket['ticket_number'],
      'verificationCode': ticket['verification_code'],
      'customerName': 'Sandbox test user',
      'status': ticket['status'],
      'statusReason': ticket['status_reason'],
      'vendorName': profileJson['queue_name'] ?? ticket['display_label'],
      'locationName': profileJson['location_name'],
      'locationSlug': profileJson['location_slug'],
      'joinedAt': ticket['issued_at'],
      'updatedAt': ticket['updated_at'],
    };
  }
}
