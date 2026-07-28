import 'package:flutter/material.dart';

/// App theme configuration matching SillyTavern's dark aesthetic
class AppTheme {
  // SillyTavern-inspired color palette
  // KiraKira 色彩语言 · 深空星海
  static const Color primaryColor = Color(0xFF7C7BF0);   // 星蓝紫
  static const Color secondaryColor = Color(0xFF6C8FF0); // 次级蓝
  static const Color accentColor = Color(0xFF56D4C8);    // 青绿点睛

  // Dark theme colors · 深空层次
  static const Color darkBackground = Color(0xFF0D1128); // 深蓝紫底(非纯黑)
  static const Color darkSurface = Color(0xFF161B3A);    // 表面(提亮一级)
  static const Color darkCard = Color(0xFF1F264A);       // 卡片(再提亮,浮起)
  static const Color darkDivider = Color(0xFF2A3057);    // 低调分隔

  // Text colors · 护眼灰白(非纯白)
  static const Color textPrimary = Color(0xFFE8EAF5);
  static const Color textSecondary = Color(0xFF9095B8);
  static const Color textMuted = Color(0xFF6A6F94);

  // Chat bubble colors · 气泡
  static const Color userBubble = Color(0xFF5A58D4);     // 用户(星蓝紫深)
  static const Color assistantBubble = Color(0xFF1F264A);// 助手(融入卡片色)
  static const Color systemBubble = Color(0xFF2A3057);   // 系统(分隔色)
  
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        surface: darkSurface,
        onSurface: textPrimary,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
      ),
      scaffoldBackgroundColor: darkBackground,
      cardColor: darkCard,
      dividerColor: darkDivider,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: textPrimary,
        iconColor: textSecondary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        hintStyle: const TextStyle(color: textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: primaryColor,
        unselectedItemColor: textMuted,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        indicatorColor: primaryColor.withOpacity(0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: primaryColor, fontSize: 12);
          }
          return const TextStyle(color: textMuted, fontSize: 12);
        }),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          color: textPrimary,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: textSecondary,
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          color: textMuted,
          fontSize: 12,
        ),
      ),
    );
  }
  
  static ThemeData get lightTheme {
    // Light theme for users who prefer it
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        surface: Colors.white,
        onSurface: Colors.grey[900]!,
      ),
      scaffoldBackgroundColor: Colors.grey[50],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[900],
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}