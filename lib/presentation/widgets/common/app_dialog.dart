import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';

/// Unified dialog entry point, replacing the native showDialog.
/// Provides a scale + fade entrance animation that runs on the GPU compositing layer, with negligible performance cost.
/// Call signature matches showDialog exactly, so it can be dropped in as a replacement.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierDismissible
        ? MaterialLocalizations.of(context).modalBarrierDismissLabel
        : null,
    barrierColor: barrierColor ?? Colors.black54,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, animation, secondaryAnimation) {
      // Actual content is wrapped by transitionBuilder; pass builder straight through here
      return builder(ctx);
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      // easeOutCubic gives the entrance a smooth fast-then-slow feel
      final curved = CurvedAnimation(
        parent: animation,
        curve: DesignTokens.curveStandard,
        reverseCurve: DesignTokens.curveStandard,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          // Scales from 0.92 to 1.0 for a subtle pop-in effect
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}