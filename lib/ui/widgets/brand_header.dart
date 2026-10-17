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
        Image.asset('assets/icon/icon.png', width: 84, height: 84,
            semanticLabel: 'Bouncr logo'),
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
