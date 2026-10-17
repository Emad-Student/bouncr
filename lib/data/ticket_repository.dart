import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../domain/firestore_error_messages.dart';
import '../domain/result.dart';
import '../domain/ticket.dart';

abstract interface class TicketRepository {
  /// The caller's ticket for [eventId], live. `null` until one is issued.
  Stream<Ticket?> watchMyTicket(String eventId, String uid);

  /// All tickets of [uid], live.
  Stream<List<Ticket>> watchMyTickets(String uid);

  /// RSVP: asks the server to issue a signed ticket.
  Future<Result<void>> issue(String eventId);

  Future<Result<void>> cancel(String eventId);

  /// Door check-in, organiser only.
  Future<Result<ScanResult>> validate(String eventId, String code);
}

/// Reads tickets from Firestore; every write goes through Cloud Functions.
class FirebaseTicketRepository implements TicketRepository {
  FirebaseTicketRepository(this._db, this._functions);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _tickets =>
      _db.collection('tickets');

  @override
  Stream<Ticket?> watchMyTicket(String eventId, String uid) {
    return _tickets
        .doc(Ticket.idFor(eventId, uid))
        .snapshots()
        .map((d) => d.exists ? _fromDoc(d) : null);
  }

  @override
  Stream<List<Ticket>> watchMyTickets(String uid) {
    return _tickets
        .where('ownerId', isEqualTo: uid)
        .snapshots()
        .map((s) => s.docs.map(_fromDoc).toList());
  }

  @override
  Future<Result<void>> issue(String eventId) =>
      _call('issueTicket', {'eventId': eventId}, (_) {});

  @override
  Future<Result<void>> cancel(String eventId) =>
      _call('cancelTicket', {'eventId': eventId}, (_) {});

  @override
  Future<Result<ScanResult>> validate(String eventId, String code) {
    return _call('validateTicket', {'eventId': eventId, 'code': code}, (data) {
      final usedAt = data['usedAt'] as String?;
      return ScanResult(
        ScanResult.parseOutcome(data['result'] as String?),
        attendeeName: data['attendeeName'] as String?,
        usedAt: usedAt == null ? null : DateTime.tryParse(usedAt),
      );
    });
  }

  Future<Result<T>> _call<T>(
    String name,
    Map<String, Object> data,
    T Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final result = await _functions
          .httpsCallable(name,
              options: HttpsCallableOptions(timeout: const Duration(seconds: 20)))
          .call<Map<String, dynamic>>(data);
      return Result.success(parse(Map<String, dynamic>.from(result.data)));
    } on FirebaseFunctionsException catch (e) {
      // Messages written in the functions are meant for users; fall back to
      // a generic one for infrastructure errors.
      final serverMessage = e.message;
      final friendly = switch (e.code) {
        'resource-exhausted' ||
        'failed-precondition' ||
        'permission-denied' ||
        'not-found' ||
        'unauthenticated' =>
          serverMessage ?? firestoreErrorMessage(e.code),
        _ => 'The ticket service is unreachable. Please try again',
      };
      return Result.failure(friendly);
    } catch (_) {
      return const Result.failure('The ticket service is unreachable. Please try again');
    }
  }

  static Ticket _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Ticket(
      id: doc.id,
      ownerId: d['ownerId'] as String,
      eventId: d['eventId'] as String,
      eventTitle: d['eventTitle'] as String? ?? '',
      status: Ticket.parseStatus(d['status'] as String?),
      signature: d['signature'] as String? ?? '',
      usedAt: (d['usedAt'] as Timestamp?)?.toDate(),
    );
  }
}
