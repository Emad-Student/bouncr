import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/event_repository.dart';
import '../../domain/event.dart';

enum EventsFilter { all, myEvents }

/// Live list of events for the home screen, with a filter.
class EventsViewModel extends ChangeNotifier {
  EventsViewModel(this._repository, {required this.uid}) {
    _subscribe();
  }

  final EventRepository _repository;
  final String uid;

  EventsFilter _filter = EventsFilter.all;
  List<Event> _events = const [];
  bool _isLoading = true;
  String? _error;
  StreamSubscription<List<Event>>? _subscription;

  EventsFilter get filter => _filter;
  List<Event> get events => _events;
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

    final stream = switch (_filter) {
      EventsFilter.all => _repository.watchUpcoming(),
      EventsFilter.myEvents => _repository.watchOwnedBy(uid),
    };
    _subscription = stream.listen(
      (events) {
        _events = events;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object _) {
        _isLoading = false;
        _error = 'Could not load events. Check your connection.';
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
