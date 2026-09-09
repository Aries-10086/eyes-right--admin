import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bilibili-inspired pink + clean light UI.
class AppTheme {
  static const pink = Color(0xFFFB7299);
  static const pinkDeep = Color(0xFFE85A84);
  static const pinkSoft = Color(0xFFFFF0F5);
  static const pinkWash = Color(0xFFFFD6E7);
  static const blue = Color(0xFF00A1D6);
  static const bg = Color(0xFFF4F4F4);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF18191C);
  static const textSecondary = Color(0xFF9499A0);
  static const textHint = Color(0xFFC9CCD0);
  static const border = Color(0xFFE3E5E7);
  static const stage = Color(0xFF1C1D1F);

  static ThemeData light() {
    final textTheme = GoogleFonts.notoSansScTextTheme().apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.light(
        primary: pink,
        onPrimary: Colors.white,
        secondary: blue,
        surface: surface,
        onSurface: textPrimary,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.notoSansSc(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: stage,
        contentTextStyle: GoogleFonts.notoSansSc(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: pink,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.notoSansSc(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
    );
  }
}
