import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/event_repository.dart';
import '../../domain/event.dart';
import '../auth/session_view_model.dart';
import '../navigation/routes.dart';
import '../widgets/formatting.dart';
import 'event_card.dart';

/// Details of one event, live from Firestore.
class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<EventRepository>();
    final uid = context.watch<SessionViewModel>().user?.uid;

    return StreamBuilder<Event?>(
      stream: repo.watchEvent(eventId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _Scaffold(child: Center(child: Text('Could not load this event.')));
        }
        if (!snapshot.hasData && snapshot.connectionState != ConnectionState.active) {
          return const _Scaffold(child: Center(child: CircularProgressIndicator()));
        }
        final event = snapshot.data;
        if (event == null) {
          return const _Scaffold(child: Center(child: Text('This event no longer exists.')));
        }
        return _EventDetail(event: event, isOwner: event.isOwnedBy(uid));
      },
    );
  }
}

class _Scaffold extends StatelessWidget {
  const _Scaffold({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(), body: child);
}

class _EventDetail extends StatelessWidget {
  const _EventDetail({required this.event, required this.isOwner});

  final Event event;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (isOwner)
            IconButton(
              key: const Key('edit_event'),
              tooltip: 'Edit event',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(Routes.editEvent(event.id)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(event.title, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            SeatsBadge(event: event),
            if (isOwner)
              StatusBadge(label: 'You organise this', color: scheme.primary, icon: Icons.star_rounded),
          ]),
          const SizedBox(height: 20),
          _InfoRow(icon: Icons.schedule, label: formatFullDate(event.startsAt)),
          _InfoRow(icon: Icons.place_outlined, label: event.location),
          _InfoRow(
            icon: Icons.event_seat_outlined,
            label: '${event.ticketsIssued} of ${event.capacity} seats taken',
          ),
          if (event.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('About', style: text.titleMedium),
            const SizedBox(height: 6),
            Text(event.description, style: text.bodyLarge),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
      ]),
    );
  }
}
