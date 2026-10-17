import 'dart:async';

import 'package:bouncr/data/auth_repository.dart';
import 'package:bouncr/data/event_repository.dart';
import 'package:bouncr/data/ticket_repository.dart';
import 'package:bouncr/domain/app_user.dart';
import 'package:bouncr/domain/event.dart';
import 'package:bouncr/domain/result.dart';
import 'package:bouncr/domain/ticket.dart';

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

/// In-memory [TicketRepository] that mimics the Cloud Functions rules:
/// capacity, one ticket per user, one-time check-in.
class FakeTicketRepository implements TicketRepository {
  FakeTicketRepository({required this.events, required this.currentUid});

  final FakeEventRepository events;
  String Function() currentUid;
  final Map<String, Ticket> tickets = {};
  final _changes = StreamController<void>.broadcast();
  int validateCalls = 0;

  Stream<T> _live<T>(T Function() read) async* {
    yield read();
    yield* _changes.stream.map((_) => read());
  }

  @override
  Stream<Ticket?> watchMyTicket(String eventId, String uid) =>
      _live(() => tickets[Ticket.idFor(eventId, uid)]);

  @override
  Stream<List<Ticket>> watchMyTickets(String uid) =>
      _live(() => tickets.values.where((t) => t.ownerId == uid).toList());

  @override
  Future<Result<void>> issue(String eventId) async {
    final uid = currentUid();
    final id = Ticket.idFor(eventId, uid);
    final existing = tickets[id];
    if (existing != null && existing.status != TicketStatus.cancelled) {
      return const Result.success(null);
    }
    final event = events.all.firstWhere((e) => e.id == eventId);
    if (event.isSoldOut) return const Result.failure('Sorry, this event is sold out.');
    tickets[id] = Ticket(
      id: id,
      ownerId: uid,
      eventId: eventId,
      eventTitle: event.title,
      status: TicketStatus.valid,
      signature: 'sig-$id-abcdefghijklmnopqrstuvwxyz',
    );
    _changes.add(null);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> cancel(String eventId) async {
    final id = Ticket.idFor(eventId, currentUid());
    final t = tickets[id];
    if (t == null) return const Result.failure('You have no ticket for this event.');
    tickets[id] = _copy(t, TicketStatus.cancelled);
    _changes.add(null);
    return const Result.success(null);
  }

  @override
  Future<Result<ScanResult>> validate(String eventId, String code) async {
    validateCalls++;
    final t = tickets.values.where((t) => t.code == code).firstOrNull;
    if (t == null) return const Result.success(ScanResult(ScanOutcome.invalid));
    if (t.eventId != eventId) return const Result.success(ScanResult(ScanOutcome.wrongEvent));
    if (t.status == TicketStatus.used) {
      return const Result.success(ScanResult(ScanOutcome.alreadyUsed, attendeeName: 'Guest'));
    }
    if (t.status == TicketStatus.cancelled) {
      return const Result.success(ScanResult(ScanOutcome.cancelled));
    }
    tickets[t.id] = _copy(t, TicketStatus.used);
    _changes.add(null);
    return const Result.success(ScanResult(ScanOutcome.admitted, attendeeName: 'Guest'));
  }

  static Ticket _copy(Ticket t, TicketStatus status) => Ticket(
        id: t.id,
        ownerId: t.ownerId,
        eventId: t.eventId,
        eventTitle: t.eventTitle,
        status: status,
        signature: t.signature,
        usedAt: status == TicketStatus.used ? DateTime.now() : t.usedAt,
      );
}
