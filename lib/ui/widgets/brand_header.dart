import 'package:flutter/material.dart';

/// Logo mark + app name used on the auth screens.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(Icons.qr_code_2_rounded, size: 46, color: scheme.onPrimary),
        ),
        const SizedBox(height: 16),
        Text('Bouncr',
            style: text.headlineLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
