import 'package:flutter/material.dart';

/// 统一弹窗入口，替代原生 showDialog。
/// 提供「缩放 + 淡入」的入场动画，走 GPU 合成层，性能开销极低。
/// 调用方式与 showDialog 完全一致，可直接机械替换。
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
      // 实际内容由 transitionBuilder 包裹，这里直接交给 builder
      return builder(ctx);
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      // 用 easeOutCubic 让入场有「先快后缓」的顺滑感
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          // 从 0.92 放大到 1.0，轻微的「弹入」质感
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}