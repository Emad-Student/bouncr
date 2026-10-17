/// An event published by an organiser (`events/{id}` in Firestore).
class Event {
  const Event({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.location,
    required this.startsAt,
    required this.capacity,
    required this.ticketsIssued,
  });

  final String id;
  final String ownerId;
  final String title;
  final String description;
  final String location;
  final DateTime startsAt;
  final int capacity;

  /// Written only by Cloud Functions, inside a transaction.
  final int ticketsIssued;

  int get seatsLeft => (capacity - ticketsIssued).clamp(0, capacity);
  bool get isSoldOut => seatsLeft == 0;
  bool isOwnedBy(String? uid) => uid != null && uid == ownerId;
  bool hasStarted(DateTime now) => !startsAt.isAfter(now);
}

/// The fields an organiser can edit.
class EventDraft {
  const EventDraft({
    required this.title,
    required this.description,
    required this.location,
    required this.startsAt,
    required this.capacity,
  });

  final String title;
  final String description;
  final String location;
  final DateTime startsAt;
  final int capacity;
}
