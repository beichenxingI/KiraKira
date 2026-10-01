// lib/presentation/widgets/common/kira_glass_bar.dart
/// KiraGlassBar, the frosted-glass shell for bottom bars / floating toolbars (A-T6)
///
/// iOS "Material Thin" feel: ClipRRect + BackdropFilter (sigma 22/20) +
/// translucent base color (dark darkSurface 0.72 / light white 0.72).
///
/// WebView platform views conflict with BackdropFilter (rendering fails on the chat tab),
/// so the chat tab must pass [enabledBlur] = false, degrading to a 0.92 opaque
/// solid shell with no blur that still looks translucent.
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';

class KiraGlassBar extends StatelessWidget {
  const KiraGlassBar({
    super.key,
    required this.child,
    this.enabledBlur = true,
    this.radius,
  });

  final Widget child;

  /// Pass false for the chat tab (WebView platform view); other tabs default to true
  final bool enabledBlur;

  /// Clip radius; pass radiusFull (30) for the bottom-bar capsule
  final BorderRadius? radius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sigma = isDark ? 22.0 : 20.0;
    final base = isDark ? DesignTokens.darkSurface : Colors.white;
    final color = base.withValues(alpha: enabledBlur ? 0.72 : 0.92);

    Widget content = Container(color: color, child: child);
    if (enabledBlur) {
      content = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: content,
      );
    }
    final r = radius;
    return r != null ? ClipRRect(borderRadius: r, child: content) : content;
  }
}
