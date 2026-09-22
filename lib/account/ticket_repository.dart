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

abstract interface class AccountTicketInvitationApi {
  Future<Map<String, dynamic>> loadInvitations();

  Future<Map<String, dynamic>> acceptInvitation(String ticketId);
}

class TicketInvitation {
  const TicketInvitation({
    required this.id,
    required this.ticketNumber,
    required this.queueName,
    required this.status,
    this.displayLabel,
    this.externalReference,
  });

  final String id;
  final String? ticketNumber;
  final String queueName;
  final String status;
  final String? displayLabel;
  final String? externalReference;

  factory TicketInvitation.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'];
    final profileMap = profile is Map<String, dynamic> ? profile : null;
    return TicketInvitation(
      id: '${json['id'] ?? ''}',
      ticketNumber: json['ticket_number']?.toString(),
      queueName: profileMap?['queue_name']?.toString() ?? 'Developer queue',
      status: json['status']?.toString() ?? 'waiting',
      displayLabel: json['display_label']?.toString(),
      externalReference: json['external_reference']?.toString(),
    );
  }
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

  Future<List<TicketInvitation>> loadInvitations() async {
    if (api is! AccountTicketInvitationApi) {
      return const [];
    }
    final invitationApi = api as AccountTicketInvitationApi;
    final response = await invitationApi.loadInvitations();
    final rawInvitations = response['invitations'];
    if (rawInvitations is! List) return const [];
    return rawInvitations
        .whereType<Map<String, dynamic>>()
        .map(TicketInvitation.fromJson)
        .toList(growable: false);
  }

  Future<QueueTicket?> acceptInvitation(String ticketId) async {
    if (api is! AccountTicketInvitationApi) return null;
    final invitationApi = api as AccountTicketInvitationApi;
    final response = await invitationApi.acceptInvitation(ticketId);
    final ticket = response['ticket'];
    return ticket is Map<String, dynamic> ? QueueTicket.fromJson(ticket) : null;
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

class RestAccountQueueApi
    implements AccountQueueApi, AccountTicketInvitationApi {
  RestAccountQueueApi(this.client, {this.useMobileTicketFeed = false});

  final AuthenticatedApiClient client;
  final bool useMobileTicketFeed;

  @override
  Future<Map<String, dynamic>> loadOverview() {
    if (useMobileTicketFeed) {
      return client.get(
        '/api/mobile/tickets',
        queryParameters: {'view': 'active'},
      );
    }
    return client.get('/api/account/overview');
  }

  @override
  Future<Map<String, dynamic>> loadHistory({
    required int page,
    required int limit,
  }) {
    if (useMobileTicketFeed) {
      return client.get(
        '/api/mobile/tickets',
        queryParameters: {'view': 'history'},
      );
    }
    return client.get(
      '/api/account/history',
      queryParameters: {'page': '$page', 'limit': '$limit'},
    );
  }

  @override
  Future<Map<String, dynamic>> loadInvitations() {
    return client.get('/api/mobile/ticket-invitations');
  }

  @override
  Future<Map<String, dynamic>> acceptInvitation(String ticketId) {
    return client.post(
      '/api/mobile/ticket-invitations/${Uri.encodeComponent(ticketId)}/accept',
      const {},
    );
  }
}
