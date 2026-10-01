// lib/presentation/theme/glass_theme_extension.dart
/// Glass theme extension: unified glass decoration backed by DesignTokens.
///
/// Register in ThemeData.extensions, then use either:
/// `Theme.of(context).extension<GlassThemeExtension>()!.card(...)`
/// or the convenience extension: `Theme.of(context).glass.card(...)`
library;

import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Glass variant theme extension
class GlassThemeExtension extends ThemeExtension<GlassThemeExtension> {
  const GlassThemeExtension();

  @override
  GlassThemeExtension copyWith() => const GlassThemeExtension();

  @override
  GlassThemeExtension lerp(
          ThemeExtension<GlassThemeExtension>? other, double t) =>
      this;

  /// Glass card decoration
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
      // No BackdropFilter here: it breaks WebView platform view rendering
      boxShadow: showShadow
          ? (isDark ? DesignTokens.shadowGlass : DesignTokens.shadowLevel2)
          : null,
    );
  }

  /// Glass app bar decoration
  BoxDecoration appBar({bool isDark = true}) => card(
        isDark: isDark,
        blur: isDark ? 22 : 20,
        opacity: isDark ? 0.60 : 0.55,
        borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
      );

  /// Glass input decoration
  BoxDecoration input({bool isDark = true}) => card(
        isDark: isDark,
        blur: isDark ? 22 : 20,
        opacity: isDark ? 0.60 : 0.55,
        borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
      );

  /// Glass panel decoration
  BoxDecoration panel({bool isDark = true}) => card(
        isDark: isDark,
        blur: isDark ? 24 : 20,
        opacity: isDark ? 0.62 : 0.55,
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
      );
}

/// Convenience getter extension
extension GlassThemeExtensionGetter on ThemeData {
  GlassThemeExtension get glass =>
      extension<GlassThemeExtension>() ?? const GlassThemeExtension();
}
