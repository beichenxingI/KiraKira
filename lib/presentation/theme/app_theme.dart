import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/theme/glass_theme_extension.dart';

/// App theme · iOS 化宪法 v2 双主题
///
/// 深色主战场:近黑带微蓝底、三级灰差、半透明白文字、零阴影。
/// 浅色:iOS grouped 灰底反衬白卡。
class AppTheme {
  // ===========================================================================
  // 品牌色(星海皮肤)
  // ===========================================================================
  static const Color primaryColor = DesignTokens.primary; // 星海紫(唯一交互强调)
  static const Color secondaryColor = DesignTokens.secondary; // 渐变辅助/图表第二序列
  static const Color accentColor = DesignTokens.accent; // 青(仅状态正向/数据高亮)

  // ===========================================================================
  // 深色组(token 直通)
  // ===========================================================================
  static const Color darkBackground = DesignTokens.darkBackground;
  static const Color darkSurface = DesignTokens.darkSurface;
  static const Color darkCard = DesignTokens.darkCard;

  // ===========================================================================
  // 文字色
  // ===========================================================================
  // 正式别名(新代码一律用这套)
  static const Color darkTextPrimary = DesignTokens.darkTextPrimary;
  static const Color darkTextSecondary = DesignTokens.darkTextSecondary;
  static const Color darkTextTertiary = DesignTokens.darkTextTertiary;
  static const Color darkTextDisabled = DesignTokens.darkTextDisabled;
  static const Color lightTextPrimary = DesignTokens.lightTextPrimary;
  static const Color lightTextSecondary = DesignTokens.lightTextSecondary;
  static const Color lightTextTertiary = DesignTokens.lightTextTertiary;
  static const Color lightTextDisabled = DesignTokens.lightTextDisabled;
  static const Color lightSurface = DesignTokens.lightSurface;
  static const Color lightCard = DesignTokens.lightCard;

  // ⚠️ 聊天域兼容层(screens/chat、widgets/chat 禁区在引用,不许进去改):
  // 保留旧别名名,值已指向 iOS 化新 token。新代码禁止使用,用上面的 darkTextXxx。
  static const Color textPrimary = DesignTokens.darkTextPrimary;
  static const Color textSecondary = DesignTokens.darkTextSecondary;
  static const Color textMuted = DesignTokens.darkTextTertiary;
  static const Color darkDivider = DesignTokens.darkSeparator;

  // ===========================================================================
  // 聊天气泡(token 指认;聊天域渲染层禁改)
  // ===========================================================================
  static const Color userBubble = DesignTokens.userBubble;
  static const Color assistantBubble = DesignTokens.assistantBubble;
  static const Color systemBubble = DesignTokens.systemBubble;

  // ===========================================================================
  // textTheme 构建(全档,两份由方法生成)
  // ===========================================================================
  static TextTheme _textTheme({
    required Color primary,
    required Color secondary,
    required Color tertiary,
  }) {
    return TextTheme(
      // Large Title 34/Bold(SliverAppBar.large 大标题)
      displayLarge: TextStyle(
        color: primary,
        fontSize: DesignTokens.fontSizeDisplayLarge,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.4,
      ),
      displayMedium: const TextStyle(
        fontSize: DesignTokens.fontSize3xl,
        fontWeight: FontWeight.bold,
      ).copyWith(color: primary),
      displaySmall: const TextStyle(
        fontSize: DesignTokens.fontSize2xl,
        fontWeight: FontWeight.bold,
      ).copyWith(color: primary),
      headlineLarge: const TextStyle(
        fontSize: DesignTokens.fontSize3xl,
        fontWeight: FontWeight.bold,
      ).copyWith(color: primary), // Title 1 28
      headlineMedium: const TextStyle(
        fontSize: DesignTokens.fontSize2xl,
        fontWeight: FontWeight.bold,
      ).copyWith(color: primary), // Title 2 22
      headlineSmall: const TextStyle(
        fontSize: DesignTokens.fontSizeXl,
        fontWeight: FontWeight.w600,
      ).copyWith(color: primary), // Title 3 20
      titleLarge: const TextStyle(
        fontSize: DesignTokens.fontSizeXl,
        fontWeight: FontWeight.w600,
      ).copyWith(color: primary), // Title 3
      titleMedium: const TextStyle(
        fontSize: DesignTokens.fontSizeHeadline,
        fontWeight: FontWeight.w600,
      ).copyWith(color: primary), // Headline 17(列表行标题)
      titleSmall: TextStyle(
        color: secondary,
        fontSize: DesignTokens.fontSizeSm,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ), // inset-grouped 组头小字
      bodyLarge: TextStyle(
        color: primary,
        fontSize: DesignTokens.fontSizeBodyLarge,
      ), // Body 17
      bodyMedium: TextStyle(
        color: secondary,
        fontSize: DesignTokens.fontSizeBodyMedium,
      ), // Subheadline 15(次级说明)
      bodySmall: TextStyle(
        color: tertiary,
        fontSize: DesignTokens.fontSizeXs,
      ), // Caption 1 12
      labelLarge: const TextStyle(
        fontSize: DesignTokens.fontSizeHeadline,
        fontWeight: FontWeight.w600,
      ).copyWith(color: primary), // 按钮文字
      labelMedium: TextStyle(
        color: secondary,
        fontSize: DesignTokens.fontSizeSm,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: TextStyle(
        color: tertiary,
        fontSize: DesignTokens.fontSizeCaption,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  // ===========================================================================
  // 深色主题(主战场)
  // ===========================================================================
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      extensions: [const GlassThemeExtension()],
      // 全局去水波纹:按压手感由 KiraPressable 提供(宪法 §四.1)
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        surface: darkSurface,
        surfaceContainerHighest: darkCard, // 三级:输入框/控件填充
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        outlineVariant: DesignTokens.darkSeparator,
      ),
      scaffoldBackgroundColor: darkBackground,
      cardColor: darkSurface, // inset-grouped 分组卡底色(二级)
      dividerColor: DesignTokens.darkSeparator,
      dividerTheme: const DividerThemeData(
        color: DesignTokens.darkSeparator,
        thickness: 0.5,
        space: 0.5,
      ),
      // AppBar:背景=页面底色、无滚动染色、左对齐、收缩态 17/w600
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: darkTextPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: DesignTokens.fontSizeHeadline,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0, // 深色零阴影(宪法铁律)
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusDialog),
        ),
        titleTextStyle: const TextStyle(
          color: darkTextPrimary,
          fontSize: DesignTokens.fontSizeHeadline,
          fontWeight: FontWeight.w600,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: darkTextPrimary,
        iconColor: darkTextSecondary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
          borderSide:
              const BorderSide(color: DesignTokens.darkSeparator, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
          borderSide:
              const BorderSide(color: DesignTokens.darkSeparator, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        hintStyle: const TextStyle(color: darkTextTertiary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceLg, vertical: DesignTokens.spaceSm),
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
        unselectedItemColor: darkTextTertiary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        indicatorColor: primaryColor.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
                color: primaryColor, fontSize: DesignTokens.fontSizeXs);
          }
          return const TextStyle(
              color: darkTextTertiary, fontSize: DesignTokens.fontSizeXs);
        }),
      ),
      // 让 CupertinoSwitch 等默认吃星海紫(宪法 §五.5)
      cupertinoOverrideTheme: const CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: primaryColor,
      ),
      textTheme: _textTheme(
        primary: DesignTokens.darkTextPrimary,
        secondary: DesignTokens.darkTextSecondary,
        tertiary: DesignTokens.darkTextTertiary,
      ),
    );
  }

  // ===========================================================================
  // 浅色主题
  // ===========================================================================
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      extensions: [const GlassThemeExtension()],
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        surface: lightSurface,
        surfaceContainerHighest: DesignTokens.lightFillTertiary,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        outlineVariant: DesignTokens.lightSeparator,
      ),
      scaffoldBackgroundColor: DesignTokens.lightBackground,
      cardColor: DesignTokens.lightCard,
      dividerColor: DesignTokens.lightSeparator,
      dividerTheme: const DividerThemeData(
        color: DesignTokens.lightSeparator,
        thickness: 0.5,
        space: 0.5,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: DesignTokens.lightBackground,
        foregroundColor: lightTextPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: lightTextPrimary,
          fontSize: DesignTokens.fontSizeHeadline,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: DesignTokens.lightCard,
        elevation: 0, // 浅色卡片靠灰底反衬,不再 elevation 2
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightSurface,
        elevation: 6, // 浅色仅 modal/sheet 允许阴影(宪法 §五.4)
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusDialog),
        ),
        titleTextStyle: const TextStyle(
          color: lightTextPrimary,
          fontSize: DesignTokens.fontSizeHeadline,
          fontWeight: FontWeight.w600,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: lightTextPrimary,
        iconColor: lightTextSecondary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DesignTokens.lightFillTertiary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        hintStyle: const TextStyle(color: lightTextTertiary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceLg, vertical: DesignTokens.spaceSm),
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
        backgroundColor: DesignTokens.lightSurface,
        selectedItemColor: primaryColor,
        unselectedItemColor: lightTextTertiary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: DesignTokens.lightSurface,
        indicatorColor: primaryColor.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
                color: primaryColor, fontSize: DesignTokens.fontSizeXs);
          }
          return const TextStyle(
              color: lightTextTertiary, fontSize: DesignTokens.fontSizeXs);
        }),
      ),
      cupertinoOverrideTheme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: primaryColor,
      ),
      textTheme: _textTheme(
        primary: DesignTokens.lightTextPrimary,
        secondary: DesignTokens.lightTextSecondary,
        tertiary: DesignTokens.lightTextTertiary,
      ),
    );
  }
}
