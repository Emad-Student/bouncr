import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/event.dart';
import '../domain/firestore_error_messages.dart';
import '../domain/result.dart';

abstract interface class EventRepository {
  /// Upcoming events (start time in the future), soonest first, live.
  Stream<List<Event>> watchUpcoming();

  /// Events created by [ownerId], soonest first, live (past ones included).
  Stream<List<Event>> watchOwnedBy(String ownerId);

  /// A single event, live. Emits `null` if it does not exist.
  Stream<Event?> watchEvent(String id);

  /// Creates an event owned by [ownerId] and returns its id.
  Future<Result<String>> create(String ownerId, EventDraft draft);

  Future<Result<void>> update(String id, EventDraft draft);
}

class FirestoreEventRepository implements EventRepository {
  FirestoreEventRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _events =>
      _db.collection('events');

  @override
  Stream<List<Event>> watchUpcoming() {
    return _events
        .where('startsAt', isGreaterThan: Timestamp.now())
        .orderBy('startsAt')
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map(_fromDoc).toList());
  }

  @override
  Stream<List<Event>> watchOwnedBy(String ownerId) {
    // Sorted on the client to avoid needing a composite index.
    return _events
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((s) => s.docs.map(_fromDoc).toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt)));
  }

  @override
  Stream<Event?> watchEvent(String id) {
    return _events
        .doc(id)
        .snapshots()
        .map((d) => d.exists ? _fromDoc(d) : null);
  }

  @override
  Future<Result<String>> create(String ownerId, EventDraft draft) async {
    try {
      final ref = await _events.add({
        'ownerId': ownerId,
        ..._draftFields(draft),
        'ticketsIssued': 0,
      });
      return Result.success(ref.id);
    } on FirebaseException catch (e) {
      return Result.failure(firestoreErrorMessage(e.code));
    }
  }

  @override
  Future<Result<void>> update(String id, EventDraft draft) async {
    try {
      await _events.doc(id).update(_draftFields(draft));
      return const Result.success(null);
    } on FirebaseException catch (e) {
      return Result.failure(firestoreErrorMessage(e.code));
    }
  }

  static Map<String, Object> _draftFields(EventDraft d) => {
        'title': d.title.trim(),
        'description': d.description.trim(),
        'location': d.location.trim(),
        'startsAt': Timestamp.fromDate(d.startsAt),
        'capacity': d.capacity,
      };

  static Event _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Event(
      id: doc.id,
      ownerId: d['ownerId'] as String,
      title: d['title'] as String,
      description: (d['description'] as String?) ?? '',
      location: d['location'] as String,
      startsAt: (d['startsAt'] as Timestamp).toDate(),
      capacity: (d['capacity'] as num).toInt(),
      ticketsIssued: (d['ticketsIssued'] as num?)?.toInt() ?? 0,
    );
  }
}
