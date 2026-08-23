// lib/presentation/theme/glass_theme_extension.dart
/// Glass 主题扩展 · 基于 DesignTokens 的统一玻璃装饰
///
/// 注册到 ThemeData.extensions，使用方式：
/// `Theme.of(context).extension<GlassThemeExtension>()!.card(...)`
/// 或便捷扩展：`Theme.of(context).glass.card(...)`
library;

import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Glass 变体主题扩展
class GlassThemeExtension extends ThemeExtension<GlassThemeExtension> {
  const GlassThemeExtension();

  @override
  GlassThemeExtension copyWith() => const GlassThemeExtension();

  @override
  GlassThemeExtension lerp(
          ThemeExtension<GlassThemeExtension>? other, double t) =>
      this;

  /// Glass 卡片装饰
  BoxDecoration card({
    bool isDark = true,
    double? blur,
    double? opacity,
    BorderRadius? borderRadius,
    bool showBorder = true,
    bool showShadow = true,
  }) {
    final radius =
        borderRadius ?? BorderRadius.circular(DesignTokens.radiusCard);
    final effectiveOpacity = opacity ?? (isDark ? 0.62 : 0.55);
    final tint = isDark ? DesignTokens.darkCard : DesignTokens.lightCard;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : DesignTokens.lightSeparator.withValues(alpha: 0.5);

    return BoxDecoration(
      color:
          tint.withValues(alpha: (effectiveOpacity + 0.22).clamp(0.0, 0.92)),
      borderRadius: radius,
      border: showBorder ? Border.all(color: borderColor, width: 0.8) : null,
      // 注意：不使用 BackdropFilter（WebView 平台视图渲染失败）
      boxShadow: showShadow
          ? (isDark ? DesignTokens.shadowGlass : DesignTokens.shadowLevel2)
          : null,
    );
  }

  /// Glass 顶栏装饰
  BoxDecoration appBar({bool isDark = true}) => card(
        isDark: isDark,
        blur: isDark ? 22 : 20,
        opacity: isDark ? 0.60 : 0.55,
        borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
      );

  /// Glass 输入框装饰
  BoxDecoration input({bool isDark = true}) => card(
        isDark: isDark,
        blur: isDark ? 22 : 20,
        opacity: isDark ? 0.60 : 0.55,
        borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
      );

  /// Glass 面板装饰
  BoxDecoration panel({bool isDark = true}) => card(
        isDark: isDark,
        blur: isDark ? 24 : 20,
        opacity: isDark ? 0.62 : 0.55,
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
      );
}

/// 便捷获取扩展
extension GlassThemeExtensionGetter on ThemeData {
  GlassThemeExtension get glass =>
      extension<GlassThemeExtension>() ?? const GlassThemeExtension();
}
