enum TicketStatus { valid, used, cancelled }

/// A ticket issued by the `issueTicket` Cloud Function (`tickets/{eventId}_{uid}`).
/// The app can only read tickets; Security Rules forbid writing them.
class Ticket {
  const Ticket({
    required this.id,
    required this.ownerId,
    required this.eventId,
    required this.eventTitle,
    required this.status,
    required this.signature,
    this.usedAt,
  });

  /// Must match `CODE_VERSION` in functions/src/ticket_code.ts.
  static const codeVersion = 'BNCR1';

  final String id;
  final String ownerId;
  final String eventId;
  final String eventTitle;
  final TicketStatus status;

  /// HMAC created on the server with a secret the app never sees.
  final String signature;
  final DateTime? usedAt;

  /// What the QR code contains, e.g. `BNCR1.<eventId>_<uid>.<signature>`.
  String get code => '$codeVersion.$id.$signature';

  static String idFor(String eventId, String uid) => '${eventId}_$uid';

  static TicketStatus parseStatus(String? s) => switch (s) {
        'used' => TicketStatus.used,
        'cancelled' => TicketStatus.cancelled,
        _ => TicketStatus.valid,
      };
}

/// Outcome of scanning a ticket at the door (`validateTicket`).
enum ScanOutcome { admitted, alreadyUsed, cancelled, wrongEvent, invalid }

class ScanResult {
  const ScanResult(this.outcome, {this.attendeeName, this.usedAt});

  final ScanOutcome outcome;
  final String? attendeeName;
  final DateTime? usedAt;

  bool get isAdmitted => outcome == ScanOutcome.admitted;

  static ScanOutcome parseOutcome(String? s) => switch (s) {
        'admitted' => ScanOutcome.admitted,
        'already_used' => ScanOutcome.alreadyUsed,
        'cancelled' => ScanOutcome.cancelled,
        'wrong_event' => ScanOutcome.wrongEvent,
        _ => ScanOutcome.invalid,
      };
}
