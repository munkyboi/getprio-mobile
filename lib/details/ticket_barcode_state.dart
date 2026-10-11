import 'dart:async';

import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../queue/queue_models.dart';

class TicketBarcodeToken {
  const TicketBarcodeToken({
    required this.code,
    required this.expiresAt,
    required this.serverNow,
  });
  final String code;
  final DateTime expiresAt;
  final DateTime serverNow;
}

typedef TicketBarcodeLoader = Future<TicketBarcodeToken> Function(
  String ticketId,
);

/// One server token/deadline shared by the ticket card and enlarged viewer.
class TicketBarcodeState extends ChangeNotifier with WidgetsBindingObserver {
  TicketBarcodeState({
    required QueueTicket ticket,
    required this.load,
    this.sandbox = false,
    DateTime Function()? now,
    DateTime Function()? wallNow,
    // Keep the public named argument independent of the private state field.
    // ignore: prefer_initializing_formals
  }) : _ticket = ticket {
    final origin = DateTime.now().toUtc();
    final elapsed = Stopwatch()..start();
    _now = now ?? () => origin.add(elapsed.elapsed);
    _wallNow = wallNow ?? now ?? () => DateTime.now().toUtc();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    if (rotating && _foreground) unawaited(refresh());
  }

  final TicketBarcodeLoader load;
  final bool sandbox;
  late final DateTime Function() _now;
  late final DateTime Function() _wallNow;
  DateTime? _wallDeadline;
  DateTime? _lastWall;
  bool _clockInvalid = false;
  late bool _foreground;
  QueueTicket _ticket;
  Timer? _timer;
  TicketBarcodeToken? _token;
  DateTime? _deadline;
  bool _loading = false;
  bool _disposed = false;
  int _generation = 0;
  DateTime? _retryAt;
  bool get loading => _loading;
  bool get rotating =>
      !sandbox &&
      _ticket.isActive &&
      _ticket.customerConfirmedAt == null &&
      _ticket.serviceStartedAt == null &&
      _ticket.serviceEndedAt == null &&
      !_ticket.isServiceCompleted &&
      !_ticket.isServiceInterrupted;
  DateTime _readWall() {
    final wall = _wallNow();
    if (_lastWall != null && wall.isBefore(_lastWall!)) _clockInvalid = true;
    _lastWall = wall;
    return wall;
  }

  Duration get remaining {
    final wall = _readWall();
    if (_clockInvalid || _deadline == null || _wallDeadline == null) {
      return Duration.zero;
    }
    // The shorter clock wins: wall time covers OS sleep if the monotonic clock
    // pauses; monotonic time prevents a wall-clock change extending validity.
    final monotonic = _deadline!.difference(_now());
    final wallRemaining = _wallDeadline!.difference(wall);
    return monotonic < wallRemaining ? monotonic : wallRemaining;
  }

  String? get code => rotating
      ? (_foreground && remaining > Duration.zero ? _token?.code : null)
      : (_ticket.verificationCode ?? _ticket.lookupCode);

  void updateTicket(QueueTicket ticket) {
    final wasRotating = rotating;
    final changedId = ticket.id != _ticket.id;
    _ticket = ticket;
    if (changedId || wasRotating != rotating) {
      _generation++;
      _loading = false;
      _token = null;
      _deadline = null;
      _retryAt = null;
      if (rotating && _foreground) unawaited(refresh());
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    if (_disposed || _loading || !rotating || !_foreground) return;
    final generation = _generation;
    final requestedAt = _now();
    final requestedWall = _readWall();
    if (_clockInvalid) {
      _token = null;
      _deadline = null;
      _wallDeadline = null;
    }
    _clockInvalid = false;
    _loading = true;
    notifyListeners();
    try {
      final token = await load(_ticket.id).timeout(const Duration(seconds: 15));
      if (_disposed || generation != _generation || !rotating || !_foreground) {
        return;
      }
      // Server-relative lifetime avoids device clock skew. Subtract the full
      // round trip conservatively; the server still enforces exact expiration.
      final ttl = token.expiresAt.difference(token.serverNow);
      final receivedAt = _now();
      final receivedWall = _readWall();
      final monotonicLatency = receivedAt.difference(requestedAt);
      final wallLatency = receivedWall.difference(requestedWall);
      final latency = monotonicLatency > wallLatency
          ? monotonicLatency
          : wallLatency;
      final usable = ttl - latency;
      if (_clockInvalid ||
          token.code.isEmpty ||
          ttl > const Duration(minutes: 2) ||
          usable <= Duration.zero) {
        throw StateError('Invalid barcode lifetime');
      }
      _token = token;
      _deadline = receivedAt.add(usable);
      _wallDeadline = receivedWall.add(usable);
      _retryAt = null;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      if (remaining <= Duration.zero) {
        _token = null;
        _deadline = null;
      }
      _retryAt = _now().add(const Duration(seconds: 10));
    } finally {
      if (!_disposed && generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  void _tick() {
    if (!rotating || !_foreground || _disposed) return;
    if (remaining <= Duration.zero &&
        !_loading &&
        (_retryAt == null || !_now().isBefore(_retryAt!))) {
      unawaited(refresh());
    }
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _generation++;
    _loading = false;
    _token = null;
    _deadline = null;
    _retryAt = null;
    if (_foreground && rotating) unawaited(refresh());
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
