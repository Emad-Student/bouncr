import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../widgets/form_widgets.dart';
import '../widgets/formatting.dart';
import 'event_form_view_model.dart';

/// Create / edit event. Only reachable for the owner when editing; the
/// Firestore rules enforce ownership on the server as well.
class EventFormScreen extends StatelessWidget {
  const EventFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EventFormViewModel>();

    return Scaffold(
      appBar: AppBar(title: Text(vm.isEditing ? 'Edit event' : 'New event')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            TextFormField(
              key: const Key('event_title'),
              initialValue: vm.title,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              maxLength: 80,
              onChanged: vm.onTitleChanged,
              decoration: InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. AI Club Workshop',
                prefixIcon: const Icon(Icons.title),
                errorText: vm.titleError,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('event_description'),
              initialValue: vm.description,
              textCapitalization: TextCapitalization.sentences,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              onChanged: vm.onDescriptionChanged,
              decoration: InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
                errorText: vm.descriptionError,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('event_location'),
              initialValue: vm.location,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              maxLength: 80,
              onChanged: vm.onLocationChanged,
              decoration: InputDecoration(
                labelText: 'Location',
                hintText: 'e.g. Room 204, Building A',
                prefixIcon: const Icon(Icons.place_outlined),
                errorText: vm.locationError,
              ),
            ),
            const SizedBox(height: 8),
            _DateTimeField(vm: vm),
            const SizedBox(height: 20),
            TextFormField(
              key: const Key('event_capacity'),
              initialValue: vm.capacity,
              keyboardType: TextInputType.number,
              onChanged: vm.onCapacityChanged,
              decoration: InputDecoration(
                labelText: 'Capacity (seats)',
                prefixIcon: const Icon(Icons.event_seat_outlined),
                errorText: vm.capacityError,
                helperText: vm.isEditing && vm.original!.ticketsIssued > 0
                    ? '${vm.original!.ticketsIssued} tickets already issued'
                    : null,
              ),
            ),
            if (vm.generalError != null) ...[
              const SizedBox(height: 16),
              ErrorBanner(vm.generalError!),
            ],
            const SizedBox(height: 28),
            LoadingButton(
              key: const Key('event_save'),
              label: vm.isEditing ? 'Save changes' : 'Publish event',
              isLoading: vm.isSaving,
              onPressed: () async {
                final id = await vm.save();
                if (id != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(vm.isEditing ? 'Event updated' : 'Event published'),
                  ));
                  context.pop(id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({required this.vm});

  final EventFormViewModel vm;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final initial = vm.startsAt ?? now.add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(vm.startsAt ?? const _Evening().value),
    );
    if (time == null) return;
    vm.onStartsAtChanged(
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('event_date'),
      borderRadius: BorderRadius.circular(14),
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date & time',
          prefixIcon: const Icon(Icons.calendar_month_outlined),
          errorText: vm.startsAtError,
        ),
        child: Text(vm.startsAt == null ? 'Tap to choose' : formatFullDate(vm.startsAt!)),
      ),
    );
  }
}

/// Default time suggestion: 18:00 today.
class _Evening {
  const _Evening();
  DateTime get value {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day, 18);
  }
}
