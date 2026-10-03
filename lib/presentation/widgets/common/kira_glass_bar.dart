// lib/presentation/widgets/common/kira_glass_bar.dart
/// KiraGlassBar, the shell for bottom bars / floating toolbars (A-T6)
///
/// Perf: BackdropFilter (sigma 22/20) was removed — the per-frame blur over scrolling
/// content was a measured frame-drop source (dialog / popup pop, list scroll).
/// The shell is now a solid semi-transparent color (0.92) on every tab.
///
/// [enabledBlur] is kept for API compatibility but is now a no-op: both values render
/// the same solid shell (the old chat-tab blur workaround is no longer needed).
library;

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

  /// Deprecated no-op: kept so existing callers compile unchanged.
  final bool enabledBlur;

  /// Clip radius; pass radiusFull (30) for the bottom-bar capsule
  final BorderRadius? radius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? DesignTokens.darkSurface : Colors.white;
    // Solid shell: slightly higher alpha than the old blurred base so content behind
    // barely bleeds through (keeps the translucent look without per-frame blur cost).
    final color = base.withValues(alpha: 0.92);

    final content = Container(color: color, child: child);
    final r = radius;
    return r != null ? ClipRRect(borderRadius: r, child: content) : content;
  }
}
