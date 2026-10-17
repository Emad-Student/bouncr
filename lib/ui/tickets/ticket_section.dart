import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../domain/event.dart';
import '../../domain/ticket.dart';
import '../theme.dart';
import '../widgets/form_widgets.dart';
import '../widgets/formatting.dart';
import 'ticket_view_model.dart';

/// Attendee part of the event detail: RSVP button or the QR ticket.
class TicketSection extends StatelessWidget {
  const TicketSection({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TicketViewModel>();
    if (!vm.isLoaded) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final children = <Widget>[];
    if (vm.hasActiveTicket) {
      children.add(_TicketCard(ticket: vm.ticket!));
      if (vm.ticket!.status == TicketStatus.valid && !event.hasStarted(DateTime.now())) {
        children.add(const SizedBox(height: 8));
        children.add(TextButton.icon(
          key: const Key('cancel_ticket'),
          onPressed: vm.isBusy ? null : () => _confirmCancel(context, vm),
          icon: const Icon(Icons.event_busy),
          label: const Text('Cancel my ticket'),
          style: TextButton.styleFrom(foregroundColor: BouncrColors.invalid),
        ));
      }
    } else if (event.hasStarted(DateTime.now())) {
      children.add(const _Notice(icon: Icons.history, text: 'This event has already started.'));
    } else if (event.isSoldOut) {
      children.add(const _Notice(icon: Icons.block, text: 'Sold out – no seats left.'));
    } else {
      children.add(LoadingButton(
        key: const Key('get_ticket'),
        label: 'Get my ticket',
        icon: Icons.confirmation_number_outlined,
        isLoading: vm.isBusy,
        onPressed: vm.rsvp,
      ));
      children.add(const SizedBox(height: 6));
      children.add(Text(
        'Your ticket is issued and signed by the Bouncr server.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ));
    }
    if (vm.error != null) {
      children.add(const SizedBox(height: 12));
      children.add(ErrorBanner(vm.error!));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  Future<void> _confirmCancel(BuildContext context, TicketViewModel vm) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancel your ticket?'),
        content: const Text('Your seat will be given to someone else.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep it')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Cancel ticket')),
        ],
      ),
    );
    if (ok == true) await vm.cancel();
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final used = ticket.status == TicketStatus.used;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const Key('my_ticket'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(used ? Icons.verified : Icons.confirmation_number,
                color: used ? BouncrColors.valid : scheme.primary),
            const SizedBox(width: 8),
            Text(used ? 'Checked in' : 'Your ticket',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 16),
          Opacity(
            opacity: used ? 0.25 : 1,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: ticket.code,
                size: 220,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            used
                ? 'Used ${ticket.usedAt != null ? formatFullDate(ticket.usedAt!) : ''}'
                : 'Show this QR code at the door',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ]),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Icon(icon, color: scheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ]),
    );
  }
}
