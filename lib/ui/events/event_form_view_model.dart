import 'package:flutter/foundation.dart';

import '../../data/event_repository.dart';
import '../../domain/event.dart';
import '../../domain/event_validator.dart';
import '../../domain/result.dart';

/// State and logic of the create / edit event form.
class EventFormViewModel extends ChangeNotifier {
  EventFormViewModel(
    this._repository, {
    required this.uid,
    this.original,
    DateTime Function()? clock,
  })  : _clock = clock ?? DateTime.now,
        title = original?.title ?? '',
        description = original?.description ?? '',
        location = original?.location ?? '',
        startsAt = original?.startsAt,
        capacity = original?.capacity.toString() ?? '';

  final EventRepository _repository;
  final String uid;

  /// The event being edited, or `null` when creating a new one.
  final Event? original;
  final DateTime Function() _clock;

  String title;
  String description;
  String location;
  DateTime? startsAt;
  String capacity;

  String? titleError;
  String? descriptionError;
  String? locationError;
  String? startsAtError;
  String? capacityError;
  String? generalError;
  bool isSaving = false;
  bool _disposed = false;

  bool get isEditing => original != null;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void onTitleChanged(String v) {
    title = v;
    titleError = null;
    _changed();
  }

  void onDescriptionChanged(String v) {
    description = v;
    descriptionError = null;
    _changed();
  }

  void onLocationChanged(String v) {
    location = v;
    locationError = null;
    _changed();
  }

  void onStartsAtChanged(DateTime v) {
    startsAt = v;
    startsAtError = null;
    _changed();
  }

  void onCapacityChanged(String v) {
    capacity = v;
    capacityError = null;
    _changed();
  }

  bool _validate() {
    titleError = EventValidator.validateTitle(title);
    descriptionError = EventValidator.validateDescription(description);
    locationError = EventValidator.validateLocation(location);
    startsAtError = EventValidator.validateStartsAt(
      startsAt,
      now: _clock(),
      original: original?.startsAt,
    );
    capacityError = EventValidator.validateCapacity(
      capacity,
      ticketsIssued: original?.ticketsIssued ?? 0,
    );
    generalError = null;
    _changed();
    return [titleError, descriptionError, locationError, startsAtError, capacityError]
        .every((e) => e == null);
  }

  /// Saves the event. Returns its id on success, `null` otherwise.
  Future<String?> save() async {
    if (isSaving || !_validate()) return null;
    isSaving = true;
    _changed();

    final draft = EventDraft(
      title: title,
      description: description,
      location: location,
      startsAt: startsAt!,
      capacity: int.parse(capacity.trim()),
    );
    final Result<String> result = isEditing
        ? switch (await _repository.update(original!.id, draft)) {
            Success() => Result.success(original!.id),
            Failure(:final message) => Result.failure(message),
          }
        : await _repository.create(uid, draft);

    isSaving = false;
    switch (result) {
      case Success(:final value):
        _changed();
        return value;
      case Failure(:final message):
        generalError = message;
        _changed();
        return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
