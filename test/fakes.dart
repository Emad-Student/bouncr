import 'dart:async';

import 'package:bouncr/data/auth_repository.dart';
import 'package:bouncr/data/event_repository.dart';
import 'package:bouncr/domain/app_user.dart';
import 'package:bouncr/domain/event.dart';
import 'package:bouncr/domain/result.dart';

/// In-memory [AuthRepository] so the UI can be tested without Firebase.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AppUser? signedIn}) : _user = signedIn;

  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _user;
  int calls = 0;
  String? failWith;

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> userChanges() => _controller.stream;

  void _set(AppUser? user) {
    _user = user;
    _controller.add(user);
  }

  @override
  Future<Result<void>> signIn({required String email, required String password}) async {
    calls++;
    if (failWith != null) return Result.failure(failWith!);
    _set(AppUser(uid: 'u1', email: email));
    return const Result.success(null);
  }

  @override
  Future<Result<void>> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    calls++;
    if (failWith != null) return Result.failure(failWith!);
    _set(AppUser(uid: 'u1', email: email, displayName: displayName));
    return const Result.success(null);
  }

  @override
  Future<void> signOut() async => _set(null);
}

/// In-memory [EventRepository] that behaves like Firestore streams.
class FakeEventRepository implements EventRepository {
  FakeEventRepository([List<Event> initial = const []]) : _events = [...initial];

  final List<Event> _events;
  final _changes = StreamController<void>.broadcast();
  int _nextId = 1;
  String? failWith;

  List<Event> get all => List.unmodifiable(_events);

  Stream<T> _live<T>(T Function() read) async* {
    yield read();
    yield* _changes.stream.map((_) => read());
  }

  @override
  Stream<List<Event>> watchUpcoming() => _live(() => _events
      .where((e) => e.startsAt.isAfter(DateTime.now()))
      .toList()
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt)));

  @override
  Stream<List<Event>> watchOwnedBy(String ownerId) =>
      _live(() => _events.where((e) => e.ownerId == ownerId).toList());

  @override
  Stream<Event?> watchEvent(String id) =>
      _live(() => _events.where((e) => e.id == id).firstOrNull);

  @override
  Future<Result<String>> create(String ownerId, EventDraft d) async {
    if (failWith != null) return Result.failure(failWith!);
    final id = 'e${_nextId++}';
    _events.add(Event(
      id: id,
      ownerId: ownerId,
      title: d.title.trim(),
      description: d.description.trim(),
      location: d.location.trim(),
      startsAt: d.startsAt,
      capacity: d.capacity,
      ticketsIssued: 0,
    ));
    _changes.add(null);
    return Result.success(id);
  }

  @override
  Future<Result<void>> update(String id, EventDraft d) async {
    if (failWith != null) return Result.failure(failWith!);
    final i = _events.indexWhere((e) => e.id == id);
    final old = _events[i];
    _events[i] = Event(
      id: id,
      ownerId: old.ownerId,
      title: d.title.trim(),
      description: d.description.trim(),
      location: d.location.trim(),
      startsAt: d.startsAt,
      capacity: d.capacity,
      ticketsIssued: old.ticketsIssued,
    );
    _changes.add(null);
    return const Result.success(null);
  }
}

Event sampleEvent({
  String id = 'e100',
  String ownerId = 'someone-else',
  String title = 'AI Club Workshop',
  int capacity = 40,
  int ticketsIssued = 12,
  DateTime? startsAt,
}) {
  return Event(
    id: id,
    ownerId: ownerId,
    title: title,
    description: 'Hands-on intro to LLM apps.',
    location: 'Room 204',
    startsAt: startsAt ?? DateTime.now().add(const Duration(days: 3)),
    capacity: capacity,
    ticketsIssued: ticketsIssued,
  );
}
