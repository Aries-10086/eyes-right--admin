import 'package:flutter/material.dart';

/// Soft teal look aligned with Mac client vibe (not purple defaults).
class AppTheme {
  static const bg = Color(0xFFF3F7F6);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF14302C);
  static const textSecondary = Color(0xFF5B736E);
  static const accent = Color(0xFF14B8A6);
  static const border = Color(0xFFD7E5E1);

  static ThemeData light() {
    final base = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
      surface: surface,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: base.copyWith(
        primary: accent,
        surface: surface,
      ),
      scaffoldBackgroundColor: bg,
      fontFamily: '.SF Pro Text',
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}
