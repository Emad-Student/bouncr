import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/event_repository.dart';
import '../../data/ticket_repository.dart';
import '../../domain/event.dart';
import '../auth/session_view_model.dart';
import '../navigation/routes.dart';
import '../widgets/formatting.dart';
import '../tickets/scanner_sheet.dart';
import '../tickets/ticket_section.dart';
import '../tickets/ticket_view_model.dart';
import 'event_card.dart';

/// Details of one event, live from Firestore, with the ticket part:
/// attendees get / show their ticket, the organiser scans tickets.
class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  // Created once so rebuilds do not re-subscribe to Firestore.
  late final Stream<Event?> _event =
      context.read<EventRepository>().watchEvent(widget.eventId);
  late final String _uid = context.read<SessionViewModel>().user?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => TicketViewModel(
        context.read<TicketRepository>(),
        eventId: widget.eventId,
        uid: _uid,
      ),
      child: StreamBuilder<Event?>(
        stream: _event,
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
          return _EventDetail(event: event, isOwner: event.isOwnedBy(_uid));
        },
      ),
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
          const SizedBox(height: 16),
          if (isOwner)
            FilledButton.icon(
              key: const Key('scan_tickets'),
              onPressed: () => showScannerSheet(context, event),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan tickets at the door'),
            )
          else
            TicketSection(event: event),
          if (event.description.isNotEmpty) ...[
            const SizedBox(height: 8),
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
