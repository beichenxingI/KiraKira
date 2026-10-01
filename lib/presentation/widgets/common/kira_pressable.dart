// lib/presentation/widgets/common/kira_pressable.dart
/// KiraPressable, the unified iOS press-feedback component (Constitution §4.1)
///
/// Locked behavior: press scales to 0.97 (can be disabled) plus opacity 0.6, 200ms easeOut;
/// release returns immediately. Values are unified app-wide and the defaults must not be changed;
/// to add a new level, add a named parameter instead of touching the default.
///
/// Wraps no Material/InkWell, so there is no ripple at all (ThemeData already falls back to NoSplash globally;
/// the proper fix is still to replace InkWell).
library;

import 'package:flutter/material.dart';

class KiraPressable extends StatefulWidget {
  const KiraPressable({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    this.scaleEnabled = true, // pass false for nav items / small buttons
    this.pressScale = 0.97, // special level (e.g. bottom-bar center ball 0.93)
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Used for highlight clipping; list rows can pass null (an opaque highlight is left to their own background)
  final BorderRadius? borderRadius;

  /// When off, pressing only gives opacity feedback (avoids the cheap scaling feel on large elements like nav items / bottom bar)
  final bool scaleEnabled;

  /// Press scale level; the 0.97 default is locked and must not be changed, tune levels through this parameter
  final double pressScale;

  @override
  State<KiraPressable> createState() => _KiraPressableState();
}

class _KiraPressableState extends State<KiraPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null) return; // no press feedback when not tappable
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: (_pressed && widget.scaleEnabled) ? widget.pressScale : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: !enabled
              ? 1.0
              : _pressed
                  ? 0.6
                  : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: widget.borderRadius != null
              ? ClipRRect(borderRadius: widget.borderRadius!, child: widget.child)
              : widget.child,
        ),
      ),
    );
  }
}
