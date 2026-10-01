// lib/presentation/widgets/common/glass_widgets.dart
/// Glass system widgets, based on DesignTokens + GlassThemeExtension
///
/// Replaces the legacy `GlassContainer`, uses DesignTokens throughout, and adapts to dark/light themes.
/// The legacy widget is kept and marked `@Deprecated`; new code should use GlassCard/GlassPanel from this file.
library;

import 'package:flutter/material.dart';

import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/theme/glass_theme_extension.dart';

/// Glass card: the most commonly used glass container, adapts to dark/light themes
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.borderRadius,
    this.showBorder = true,
    this.showShadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final bool showBorder;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final decoration = theme.glass.card(
      isDark: isDark,
      borderRadius: borderRadius,
      showBorder: showBorder,
      showShadow: showShadow,
    );

    Widget content = DecoratedBox(
      decoration: decoration,
      child:
          padding == null ? child : Padding(padding: padding!, child: child),
    );

    final radius = borderRadius ??
        BorderRadius.circular(DesignTokens.radiusCard);

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: content,
        ),
      );
    }

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    return content;
  }
}

/// Glass top bar: AppBar and navigation bar background
class GlassAppBarWidget extends StatelessWidget
    implements PreferredSizeWidget {
  const GlassAppBarWidget({
    super.key,
    required this.child,
    this.height = kToolbarHeight,
    this.padding,
  });

  final Widget child;
  final double height;
  final EdgeInsetsGeometry? padding;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final decoration = theme.glass.appBar(isDark: isDark);

    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: decoration,
        child:
            padding == null ? child : Padding(padding: padding!, child: child),
      ),
    );
  }
}

/// Glass panel: large overlays, bottom sheets, and dialog containers
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.showBorder = true,
    this.showShadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final bool showBorder;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final radius =
        borderRadius ?? BorderRadius.circular(DesignTokens.radiusXl);
    final decoration = theme.glass.panel(isDark: isDark).copyWith(
          borderRadius: radius,
        );

    Widget content = ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: decoration,
        child: padding == null
            ? child
            : Padding(padding: padding!, child: child),
      ),
    );

    if (showShadow) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow:
              isDark ? DesignTokens.shadowGlass : DesignTokens.shadowLevel3,
        ),
        child: content,
      );
    }

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    return content;
  }
}

/// Glass input container: search field and input bar background
class GlassInputContainer extends StatelessWidget {
  const GlassInputContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final radius =
        borderRadius ?? BorderRadius.circular(DesignTokens.radiusInput);
    final decoration = theme.glass.input(isDark: isDark).copyWith(
          borderRadius: radius,
        );

    Widget content = DecoratedBox(
      decoration: decoration,
      child: padding == null
          ? child
          : Padding(padding: padding!, child: child),
    );

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    return content;
  }
}
