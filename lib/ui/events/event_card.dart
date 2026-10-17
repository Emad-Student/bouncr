import 'package:flutter/material.dart';

import '../../domain/event.dart';
import '../theme.dart';
import '../widgets/formatting.dart';

class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.isMine,
    required this.onTap,
    this.trailingBadge,
  });

  final Event event;
  final bool isMine;
  final VoidCallback onTap;

  /// Optional extra badge, e.g. "Your ticket".
  final Widget? trailingBadge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _DateBadge(date: event.startsAt),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.schedule, size: 15, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(formatEventDate(event.startsAt),
                          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ]),
                    const SizedBox(height: 2),
                    Row(children: [
                      Icon(Icons.place_outlined, size: 15, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(event.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      SeatsBadge(event: event),
                      if (isMine) const _Badge(label: 'Organiser', icon: Icons.star_rounded),
                      ?trailingBadge,
                    ]),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.date});

  final DateTime date;
  static const _months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final local = date.toLocal();
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Text(_months[local.month - 1],
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer)),
        Text('${local.day}',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: scheme.onPrimaryContainer)),
      ]),
    );
  }
}

/// "12 seats left" / "Sold out" pill.
class SeatsBadge extends StatelessWidget {
  const SeatsBadge({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    if (event.isSoldOut) {
      return const _Badge(label: 'Sold out', color: BouncrColors.invalid);
    }
    final left = event.seatsLeft;
    final low = left <= (event.capacity * 0.1).ceil();
    return _Badge(
      label: '$left ${left == 1 ? 'seat' : 'seats'} left',
      color: low ? BouncrColors.warning : BouncrColors.valid,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: c), const SizedBox(width: 3)],
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c)),
      ]),
    );
  }
}

/// Public badge used by other screens (e.g. ticket status).
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => _Badge(label: label, color: color, icon: icon);
}
