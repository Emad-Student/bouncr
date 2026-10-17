import 'package:flutter/foundation.dart';

import '../../data/ticket_repository.dart';
import '../../domain/result.dart';
import '../../domain/ticket.dart';

/// Door check-in for one event. The camera reports the same QR many times per
/// second, so a code is sent to the server once and then ignored for a while.
class ScannerViewModel extends ChangeNotifier {
  ScannerViewModel(this._repository, {required this.eventId, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final TicketRepository _repository;
  final String eventId;
  final DateTime Function() _clock;

  static const repeatWindow = Duration(seconds: 4);

  bool _checking = false;
  ScanResult? _last;
  String? _error;
  int admittedCount = 0;
  String? _lastCode;
  DateTime? _lastCodeAt;
  bool _disposed = false;

  bool get isChecking => _checking;
  ScanResult? get lastResult => _last;
  String? get error => _error;

  /// Called for every detected code (camera or manual entry).
  Future<void> onCode(String raw, {bool manual = false}) async {
    final code = raw.trim();
    if (code.isEmpty || _checking) return;
    final now = _clock();
    if (!manual &&
        code == _lastCode &&
        _lastCodeAt != null &&
        now.difference(_lastCodeAt!) < repeatWindow) {
      return;
    }
    _lastCode = code;
    _lastCodeAt = now;
    _checking = true;
    _error = null;
    _notify();

    final result = await _repository.validate(eventId, code);
    _checking = false;
    switch (result) {
      case Success(:final value):
        _last = value;
        if (value.isAdmitted) admittedCount++;
      case Failure(:final message):
        _last = null;
        _error = message;
    }
    _notify();
  }

  void clearResult() {
    _last = null;
    _error = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
