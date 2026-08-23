import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/theme/glass_theme_extension.dart';

/// App theme configuration matching SillyTavern's dark aesthetic
class AppTheme {
  // SillyTavern-inspired color palette
  // KiraKira 色彩语言 · 深空星海
  static const Color primaryColor = DesignTokens.primary;   // 星蓝紫(唯一交互强调)
  static const Color secondaryColor = DesignTokens.secondary; // 次级蓝(渐变辅助/图表第二序列)
  static const Color accentColor = DesignTokens.accent;    // 青绿点睛(状态正向/数据高亮)

  // Dark theme colors · 深空层次
  static const Color darkBackground = DesignTokens.darkBackground;
  static const Color darkSurface = DesignTokens.darkSurface;
  static const Color darkCard = DesignTokens.darkCard;
  static const Color darkDivider = DesignTokens.darkDivider;

  // Text colors · 护眼灰白(非纯白)
  static const Color textPrimary = DesignTokens.textPrimary;
  static const Color textSecondary = DesignTokens.textSecondary;
  static const Color textMuted = DesignTokens.textMuted;

  // Chat bubble colors · 气泡
  static const Color userBubble = DesignTokens.userBubble;
  static const Color assistantBubble = DesignTokens.assistantBubble;
  static const Color systemBubble = DesignTokens.systemBubble;
  
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      extensions: [const GlassThemeExtension()],
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
        // 宪法:深色靠明度分层,不堆阴影
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
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
          borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
          borderSide: const BorderSide(color: darkDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
          borderSide: const BorderSide(color: darkDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        hintStyle: const TextStyle(color: textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceLg, vertical: DesignTokens.spaceSm),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
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
        indicatorColor: primaryColor.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: primaryColor, fontSize: DesignTokens.fontSizeXs);
          }
          return const TextStyle(color: textMuted, fontSize: DesignTokens.fontSizeXs);
        }),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: DesignTokens.fontSize3xl,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: DesignTokens.fontSize2xl,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: DesignTokens.fontSizeXl,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: DesignTokens.fontSizeBodyLarge,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          color: textPrimary,
          fontSize: DesignTokens.fontSizeBodyLarge,
        ),
        bodyMedium: TextStyle(
          color: textSecondary,
          fontSize: DesignTokens.fontSizeBodyMedium,
        ),
        bodySmall: TextStyle(
          color: textMuted,
          fontSize: DesignTokens.fontSizeXs,
        ),
      ),
    );
  }
  
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      extensions: [const GlassThemeExtension()],
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        surface: DesignTokens.lightSurface,
        onSurface: const Color(0xFF1A1A2E),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurfaceVariant: const Color(0xFF5A5A7A),
      ),
      scaffoldBackgroundColor: DesignTokens.lightBackground,
      cardColor: DesignTokens.lightCard,
      dividerColor: DesignTokens.lightDivider,
      appBarTheme: const AppBarTheme(
        backgroundColor: DesignTokens.lightSurface,
        foregroundColor: Color(0xFF1A1A2E),
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: DesignTokens.lightCard,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: Color(0xFF1A1A2E),
        iconColor: Color(0xFF5A5A7A),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DesignTokens.lightCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
          borderSide: const BorderSide(color: DesignTokens.lightDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
          borderSide: const BorderSide(color: DesignTokens.lightDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        hintStyle: const TextStyle(color: Color(0xFF9090AA)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceLg, vertical: DesignTokens.spaceSm),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFFF5F5FF),
        selectedItemColor: primaryColor,
        unselectedItemColor: Color(0xFF9090AA),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: DesignTokens.lightSurface,
        indicatorColor: primaryColor.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: primaryColor, fontSize: DesignTokens.fontSizeXs);
          }
          return const TextStyle(color: Color(0xFF9090AA), fontSize: DesignTokens.fontSizeXs);
        }),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: Color(0xFF1A1A2E),
          fontSize: DesignTokens.fontSize3xl,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: Color(0xFF1A1A2E),
          fontSize: DesignTokens.fontSize2xl,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: Color(0xFF1A1A2E),
          fontSize: DesignTokens.fontSizeXl,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: Color(0xFF1A1A2E),
          fontSize: DesignTokens.fontSizeBodyLarge,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          color: Color(0xFF1A1A2E),
          fontSize: DesignTokens.fontSizeBodyLarge,
        ),
        bodyMedium: TextStyle(
          color: Color(0xFF5A5A7A),
          fontSize: DesignTokens.fontSizeBodyMedium,
        ),
        bodySmall: TextStyle(
          color: Color(0xFF9090AA),
          fontSize: DesignTokens.fontSizeXs,
        ),
      ),
    );
  }
}