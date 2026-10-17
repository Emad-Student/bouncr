import 'package:flutter/material.dart';

/// Bouncr brand: a night-club violet with a neon green "you're in" accent.
class BouncrColors {
  BouncrColors._();

  static const Color brand = Color(0xFF6D28D9);
  static const Color valid = Color(0xFF16A34A);
  static const Color invalid = Color(0xFFDC2626);
  static const Color warning = Color(0xFFD97706);
}

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: BouncrColors.brand,
    brightness: brightness,
  );
  final radius = BorderRadius.circular(14);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: radius),
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
  );
}
