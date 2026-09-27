// lib/presentation/utils/kira_dialog.dart
/// 统一浮窗显示函数(弱回弹缩放动画)
///
/// 入场:scale 0.92→1.0 弱回弹 cubic(0.34,1.56,0.64,1) + opacity 0→1(前60%),
/// 280ms;退场:scale 1.0→0.95 + opacity 1→0 easeIn,280ms 快速收起。
/// 用 showGeneralDialog 自定义 transitionBuilder 实现,退场经 status 分支
/// 取反向进度,保证入/退场曲线独立、无 CurvedAnimation 监听泄漏。
library;

import 'package:flutter/material.dart';

/// 弹一个 带缩放回弹动画的浮窗。
///
/// [dialog] 为浮窗根 Widget(通常已是 Center+Material+Container 结构)。
/// 默认 useRootNavigator=true,与 showDialog 一致,从 Shell 内页面打开
/// 也全屏覆盖、不被底栏遮挡。
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
      // animation:forward 0→1(入场),reverse 1→0(退场)
      if (animation.status == AnimationStatus.reverse) {
        // ── 退场:快速收起 ──
        // 反向进度 0→1,套 easeIn(慢起快收 → 收尾干脆)
        final p = 1.0 - animation.value;
        final ep = Curves.easeIn.transform(p);
        return Opacity(
          opacity: 1.0 - ep,
          child: Transform.scale(scale: 1.0 - 0.05 * ep, child: child),
        );
      }
      // ── 入场:弱回弹 + 淡入 ──
      // scale 经 cubic(0.34,1.56,0.64,1),末端轻微过冲到 >1 再回 1
      const enterCurve = Cubic(0.34, 1.56, 0.64, 1);
      final scaleV = enterCurve.transform(animation.value);
      // opacity 前 60% 完成淡入,避免回弹阶段还在半透明
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
