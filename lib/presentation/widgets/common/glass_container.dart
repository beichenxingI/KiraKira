import 'package:flutter/material.dart';

/// Frosted-glass color palette
@immutable
class GlassPalette {
  const GlassPalette({
    required this.pageBackground,
    required this.glassTint,
    required this.elevatedTint,
    required this.accent,
    required this.primaryText,
    required this.secondaryText,
  });

  /// Page fallback background color
  final Color pageBackground;

  /// Primary glass tint; the passed color itself stays opaque and opacity is controlled uniformly by the component
  final Color glassTint;

  /// Background tint for inner controls or floating layers
  final Color elevatedTint;

  /// Accent color: send button, active states, and similar
  final Color accent;

  final Color primaryText;
  final Color secondaryText;
}

/// Two purple-free palettes
abstract final class GlassPalettes {
  /// Blue-leaning: more high-tech feel, suited to the AI chat interface
  static const GlassPalette blue = GlassPalette(
    pageBackground: Color(0xFF070B14),
    glassTint: Color(0xFF0A0E1A),
    elevatedTint: Color(0xFF111A2A),
    accent: Color(0xFF79C7FF),
    primaryText: Color(0xFFF5F7FA),
    secondaryText: Color(0xFFA7B0BE),
  );

  /// Gray-leaning: more restrained, closer to a premium dark interface
  static const GlassPalette graphite = GlassPalette(
    pageBackground: Color(0xFF101216),
    glassTint: Color(0xFF14161C),
    elevatedTint: Color(0xFF20242C),
    accent: Color(0xFFA8D8FF),
    primaryText: Color(0xFFF5F5F7),
    secondaryText: Color(0xFFA8AAB2),
  );
}

/// Switch the whole palette here
const GlassPalette activeGlassPalette = GlassPalettes.blue;
// const GlassPalette activeGlassPalette = GlassPalettes.graphite;

/// Global frosted-glass design parameters
abstract final class GlassDesign {
  /// Main glass opacity: strictly kept within 0.55-0.65
  static const double appBarOpacity = 0.60;
  static const double panelOpacity = 0.62;
  static const double inputOpacity = 0.60;

  /// Blur strength
  static const double appBarBlur = 22;
  static const double panelBlur = 24;
  static const double inputBlur = 22;

  /// Corner radii
  static const double appBarRadius = 22;
  static const double panelRadius = 24;
  static const double cardRadius = 20;
  static const double capsuleRadius = 30;

  /// Very faint glass highlight edge
  static Color get highlightBorder =>
      Colors.white.withValues(alpha: 0.08);

  /// Light fill under inner controls
  static Color get controlFill =>
      Colors.white.withValues(alpha: 0.055);

  /// Inner control fill when pressed or active
  static Color get activeControlFill =>
      Colors.white.withValues(alpha: 0.10);

  /// Soft, wide, low-opacity shadow
  static List<BoxShadow> get softShadow => <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.24),
          blurRadius: 32,
          spreadRadius: -8,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 12,
          spreadRadius: -4,
          offset: const Offset(0, 4),
        ),
      ];
}

/// Dark frosted-glass container: translucent base + Gaussian blur + faint white edge + soft shadow.
/// Reused uniformly across top bars, input bars, panels, and cards to stay "transparent yet legible".
///
/// Only remaining references are in the chat domain (webview_chat_stage.dart),
/// so this file is kept rather than deleted. The ad-hoc colors in GlassPalettes/GlassDesign (0xFF070B14 etc.)
/// belong to chat domain visuals and will move back to DesignTokens when that domain is refactored. New code must use
/// GlassCard/GlassPanel/GlassInputContainer from glass_widgets.dart.
@Deprecated('Use GlassCard/GlassPanel from glass_widgets.dart instead. '
    '旧组件仅过渡期兼容，新代码请用 DesignTokens 版组件。')
// ignore: deprecated_member_use
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.blur = GlassDesign.panelBlur,
    this.opacity = GlassDesign.panelOpacity,
    this.borderRadius,
    this.padding,
    this.margin,
    this.tint = const Color(0xFF0A0E1A),
    this.showBorder = true,
    this.showShadow = true,
  });

  final Widget child;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color tint;
  final bool showBorder;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        borderRadius ?? BorderRadius.circular(GlassDesign.cardRadius);

    Widget content = ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          // No BackdropFilter dependency (it fails to render over WebView platform views and turns fully transparent)
          // High-opacity translucent solid color instead: reliably readable while keeping the see-through look
          color: tint.withValues(alpha: (opacity + 0.22).clamp(0.0, 0.92)),
          borderRadius: radius,
          border: showBorder
              ? Border.all(color: GlassDesign.highlightBorder)
              : null,
        ),
        child: padding == null ? child : Padding(padding: padding!, child: child),
      ),
    );

    if (showShadow) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: GlassDesign.softShadow,
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
