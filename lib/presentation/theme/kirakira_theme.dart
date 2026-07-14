import 'dart:ui';
import 'package:flutter/material.dart';

class KiraKiraTheme {
  static const Color primaryWarm = Color(0xFFFCD34D);
  static const Color secondaryWarm = Color(0xFFF59E0B);
  static const Color bgStart = Color(0xFF1a1a2e);
  static const Color bgEnd = Color(0xFF16213e);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true, brightness: Brightness.dark,
      scaffoldBackgroundColor: bgStart,
      colorScheme: ColorScheme.dark(
        primary: primaryWarm, secondary: secondaryWarm, surface: bgEnd,
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), elevation: 0,
      ),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, centerTitle: true),
      iconTheme: const IconThemeData(color: primaryWarm),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
        backgroundColor: primaryWarm, foregroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      )),
    );
  }
}