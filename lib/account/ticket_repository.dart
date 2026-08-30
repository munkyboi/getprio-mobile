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

  void requestRefresh() => refreshVersion.value++;

  Future<List<QueueTicket>> loadOverview() async {
    return _ticketsFrom(await api.loadOverview());
  }

  Future<List<QueueTicket>> loadHistory({int page = 1, int limit = 20}) async {
    return _ticketsFrom(await api.loadHistory(page: page, limit: limit));
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
