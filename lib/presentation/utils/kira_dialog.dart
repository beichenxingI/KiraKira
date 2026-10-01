// lib/presentation/utils/kira_dialog.dart
/// Unified dialog display helper (soft-bounce scale animation)
///
/// Entry: scale 0.92 to 1.0 with soft bounce cubic(0.34,1.56,0.64,1) plus
/// opacity 0 to 1 over the first 60%, 280ms; exit: scale 1.0 to 0.95 plus
/// opacity 1 to 0 easeIn, 280ms quick collapse.
/// Implemented with a custom showGeneralDialog transitionBuilder; the exit
/// branch derives reverse progress from animation status, keeping the
/// entry/exit curves independent with no CurvedAnimation listener leaks.
library;

import 'package:flutter/material.dart';

/// Shows a dialog with a scale-bounce animation.
///
/// [dialog] is the dialog root widget (usually already a
/// Center+Material+Container structure).
/// Defaults to useRootNavigator=true, matching showDialog, so opening it
/// from a page inside the Shell still covers the full screen and is not
/// hidden by the bottom bar.
Future<T?> showKiraDialog<T>({
  required BuildContext context,
  required Widget dialog,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
  Color barrierColor = Colors.black54,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierDismissible ? 'Dismiss' : '',
    barrierColor: barrierColor,
    useRootNavigator: useRootNavigator,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, __, ___) => dialog,
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      // animation: forward 0 to 1 (entry), reverse 1 to 0 (exit)
      if (animation.status == AnimationStatus.reverse) {
        // Exit: quick collapse
        // Reverse progress 0 to 1 with easeIn applied (slow start, fast
        // close so the ending is crisp)
        final p = 1.0 - animation.value;
        final ep = Curves.easeIn.transform(p);
        return Opacity(
          opacity: 1.0 - ep,
          child: Transform.scale(scale: 1.0 - 0.05 * ep, child: child),
        );
      }
      // Entry: soft bounce + fade in
      // scale passes through cubic(0.34,1.56,0.64,1), slightly overshooting
      // past 1 near the end before settling back
      const enterCurve = Cubic(0.34, 1.56, 0.64, 1);
      final scaleV = enterCurve.transform(animation.value);
      // fade-in completes within the first 60% so the widget is not still
      // translucent during the bounce
      final opacityV = (animation.value / 0.6).clamp(0.0, 1.0);
      return Opacity(
        opacity: opacityV,
        child: Transform.scale(
          scale: 0.92 + (1.0 - 0.92) * scaleV,
          child: child,
        ),
      );
    },
  );
}
