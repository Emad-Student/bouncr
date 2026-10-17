/// Pure validation for the create / edit event form.
///
/// The limits mirror `firestore.rules`, so the app rejects bad input before
/// the server would.
class EventValidator {
  EventValidator._();

  static const int maxTitle = 80;
  static const int maxDescription = 1000;
  static const int maxLocation = 80;
  static const int maxCapacity = 5000;

  static String? validateTitle(String title) {
    final v = title.trim();
    if (v.isEmpty) return 'Title is required';
    if (v.length < 3) return 'Title is too short';
    if (v.length > maxTitle) return 'Title must be at most $maxTitle characters';
    return null;
  }

  static String? validateDescription(String description) {
    if (description.trim().length > maxDescription) {
      return 'Description must be at most $maxDescription characters';
    }
    return null;
  }

  static String? validateLocation(String location) {
    final v = location.trim();
    if (v.isEmpty) return 'Location is required';
    if (v.length < 2) return 'Location is too short';
    if (v.length > maxLocation) {
      return 'Location must be at most $maxLocation characters';
    }
    return null;
  }

  /// [original] is the start time of the event being edited, if any:
  /// an unchanged date of an existing event is always accepted.
  static String? validateStartsAt(
    DateTime? startsAt, {
    required DateTime now,
    DateTime? original,
  }) {
    if (startsAt == null) return 'Pick a date and time';
    if (original != null && startsAt == original) return null;
    if (!startsAt.isAfter(now)) return 'The event must start in the future';
    return null;
  }

  /// [ticketsIssued] is 0 for a new event.
  static String? validateCapacity(String capacity, {int ticketsIssued = 0}) {
    final v = capacity.trim();
    if (v.isEmpty) return 'Capacity is required';
    final n = int.tryParse(v);
    if (n == null) return 'Enter a whole number';
    if (n < 1) return 'Capacity must be at least 1';
    if (n > maxCapacity) return 'Capacity must be at most $maxCapacity';
    if (n < ticketsIssued) {
      return '$ticketsIssued tickets are already issued – capacity cannot be lower';
    }
    return null;
  }
}
