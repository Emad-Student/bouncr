import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/session_view_model.dart';
import '../navigation/routes.dart';
import '../../domain/ticket.dart';
import '../theme.dart';
import 'event_card.dart';
import 'events_view_model.dart';

/// Home screen: live list of upcoming events.
class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EventsViewModel>();
    final session = context.watch<SessionViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bouncr', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            key: const Key('account_button'),
            tooltip: 'Account',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => _showAccount(context, session),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new_event'),
        onPressed: () => context.push(Routes.newEvent),
        icon: const Icon(Icons.add),
        label: const Text('New event'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<EventsFilter>(
                segments: const [
                  ButtonSegment(
                      value: EventsFilter.all,
                      label: Text('All'),
                      icon: Icon(Icons.event)),
                  ButtonSegment(
                      value: EventsFilter.myTickets,
                      label: Text('Tickets'),
                      icon: Icon(Icons.confirmation_number_outlined)),
                  ButtonSegment(
                      value: EventsFilter.myEvents,
                      label: Text('Mine'),
                      icon: Icon(Icons.star_outline)),
                ],
                selected: {vm.filter},
                showSelectedIcon: false,
                onSelectionChanged: (s) => vm.setFilter(s.first),
              ),
            ),
          ),
          Expanded(child: _EventsBody(vm: vm, uid: session.user?.uid)),
        ],
      ),
    );
  }

  void _showAccount(BuildContext context, SessionViewModel session) {
    final user = session.user;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CircleAvatar(
                radius: 32,
                child: Text(
                  (user?.name.isNotEmpty ?? false) ? user!.name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 26),
                ),
              ),
              const SizedBox(height: 12),
              Text(user?.name ?? '',
                  textAlign: TextAlign.center,
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Logged in as ${user?.email ?? ''}',
                  key: const Key('home_logged_in_as'), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                key: const Key('home_logout'),
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  session.signOut();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventsBody extends StatelessWidget {
  const _EventsBody({required this.vm, required this.uid});

  final EventsViewModel vm;
  final String? uid;

  @override
  Widget build(BuildContext context) {
    if (vm.isLoading) return const Center(child: CircularProgressIndicator());
    if (vm.error != null) {
      return _Message(
        icon: Icons.cloud_off,
        title: vm.error!,
        action: TextButton(onPressed: vm.retry, child: const Text('Try again')),
      );
    }
    if (vm.filter == EventsFilter.myTickets) return _TicketsList(vm: vm);
    if (vm.events.isEmpty) {
      return _Message(
        icon: Icons.celebration_outlined,
        title: vm.filter == EventsFilter.myEvents
            ? 'You have not created any events yet'
            : 'No upcoming events yet',
        subtitle: 'Tap "New event" to organise one.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      itemCount: vm.events.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final event = vm.events[i];
        return EventCard(
          key: ValueKey(event.id),
          event: event,
          isMine: event.isOwnedBy(uid),
          onTap: () => context.push(Routes.event(event.id)),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, this.subtitle, this.action});

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: scheme.primary),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
          ?action,
        ]),
      ),
    );
  }
}

class _TicketsList extends StatelessWidget {
  const _TicketsList({required this.vm});

  final EventsViewModel vm;

  @override
  Widget build(BuildContext context) {
    if (vm.myTickets.isEmpty) {
      return const _Message(
        icon: Icons.confirmation_number_outlined,
        title: 'No tickets yet',
        subtitle: 'Open an event and tap "Get my ticket".',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      itemCount: vm.myTickets.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final t = vm.myTickets[i];
        final (label, color, icon) = switch (t.status) {
          TicketStatus.valid => ('Valid', BouncrColors.valid, Icons.qr_code_2),
          TicketStatus.used => ('Checked in', BouncrColors.brand, Icons.verified),
          TicketStatus.cancelled => ('Cancelled', BouncrColors.invalid, Icons.block),
        };
        return Card(
          key: ValueKey(t.id),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color),
            ),
            title: Text(t.eventTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(label: label, color: color),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.event(t.eventId)),
          ),
        );
      },
    );
  }
}
