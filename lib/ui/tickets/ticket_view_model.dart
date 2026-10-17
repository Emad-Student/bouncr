import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/ticket_repository.dart';
import '../../domain/result.dart';
import '../../domain/ticket.dart';

/// The attendee's ticket for one event: live ticket + RSVP / cancel actions.
class TicketViewModel extends ChangeNotifier {
  TicketViewModel(this._repository, {required this.eventId, required this.uid}) {
    _subscription = _repository.watchMyTicket(eventId, uid).listen(
      (ticket) {
        _ticket = ticket;
        _loaded = true;
        _notify();
      },
      onError: (Object _) {
        _loaded = true;
        _error = 'Could not load your ticket.';
        _notify();
      },
    );
  }

  final TicketRepository _repository;
  final String eventId;
  final String uid;
  late final StreamSubscription<Ticket?> _subscription;

  Ticket? _ticket;
  bool _loaded = false;
  bool _busy = false;
  String? _error;
  bool _disposed = false;

  Ticket? get ticket => _ticket;
  bool get isLoaded => _loaded;
  bool get isBusy => _busy;
  String? get error => _error;

  /// A cancelled ticket can be re-issued, so it counts as "no ticket".
  bool get hasActiveTicket =>
      _ticket != null && _ticket!.status != TicketStatus.cancelled;

  Future<void> rsvp() => _run(() => _repository.issue(eventId));

  Future<void> cancel() => _run(() => _repository.cancel(eventId));

  Future<void> _run(Future<Result<void>> Function() action) async {
    if (_busy) return;
    _busy = true;
    _error = null;
    _notify();
    final result = await action();
    _busy = false;
    if (result case Failure(:final message)) _error = message;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription.cancel();
    super.dispose();
  }
}
