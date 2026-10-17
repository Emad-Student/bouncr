import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/event_repository.dart';
import '../../data/ticket_repository.dart';
import '../../domain/event.dart';
import '../../domain/ticket.dart';

enum EventsFilter { all, myTickets, myEvents }

/// Live list of events (or of my tickets) for the home screen.
class EventsViewModel extends ChangeNotifier {
  EventsViewModel(this._repository, this._tickets, {required this.uid}) {
    _subscribe();
  }

  final EventRepository _repository;
  final TicketRepository _tickets;
  final String uid;

  EventsFilter _filter = EventsFilter.all;
  List<Event> _events = const [];
  List<Ticket> _myTickets = const [];
  bool _isLoading = true;
  String? _error;
  StreamSubscription<Object>? _subscription;

  EventsFilter get filter => _filter;
  List<Event> get events => _events;

  /// Active tickets first, cancelled ones last.
  List<Ticket> get myTickets => _myTickets;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setFilter(EventsFilter filter) {
    if (filter == _filter) return;
    _filter = filter;
    _subscribe();
  }

  void retry() => _subscribe();

  void _subscribe() {
    _subscription?.cancel();
    _isLoading = true;
    _error = null;
    notifyListeners();

    void onError(Object _) {
      _isLoading = false;
      _error = 'Could not load. Check your connection.';
      notifyListeners();
    }

    if (_filter == EventsFilter.myTickets) {
      _subscription = _tickets.watchMyTickets(uid).listen((tickets) {
        _myTickets = [...tickets]..sort((a, b) =>
            (a.status == TicketStatus.cancelled ? 1 : 0)
                .compareTo(b.status == TicketStatus.cancelled ? 1 : 0));
        _isLoading = false;
        _error = null;
        notifyListeners();
      }, onError: onError);
      return;
    }

    final stream = switch (_filter) {
      EventsFilter.myEvents => _repository.watchOwnedBy(uid),
      _ => _repository.watchUpcoming(),
    };
    _subscription = stream.listen((events) {
      _events = events;
      _isLoading = false;
      _error = null;
      notifyListeners();
    }, onError: onError);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
