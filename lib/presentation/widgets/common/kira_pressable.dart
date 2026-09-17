// lib/presentation/widgets/common/kira_pressable.dart
/// KiraPressable · iOS 按压手感统一组件(宪法 §四.1)
///
/// 行为锁定:按下 → scale 0.97(可关)+ opacity 0.6,200ms easeOut;
/// 松手即回。**全 App 数值统一,任何 Block 不得修改默认值**——
/// 需要新档位请加命名参数,不动默认。
///
/// 不包 Material/InkWell,彻底无水波纹(ThemeData 已全局 NoSplash 兜底,
/// 正解仍是替换 InkWell)。
library;

import 'package:flutter/material.dart';

class KiraPressable extends StatefulWidget {
  const KiraPressable({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    this.scaleEnabled = true, // 导航项/小按钮传 false
    this.pressScale = 0.97, // 特殊档位(如底栏中球 0.93)
  });

  final Widget child;
  final VoidCallback? onTap;

  /// 供高亮裁切;列表行给 null 即可(不透明高亮交给自身背景)
  final BorderRadius? borderRadius;

  /// 关闭后按压只有 opacity 反馈(导航项/底栏等大面积元素避免缩放廉价感)
  final bool scaleEnabled;

  /// 按压缩放档位;默认 0.97 锁定,任何块不得改默认值,用本参数调档
  final double pressScale;

  @override
  State<KiraPressable> createState() => _KiraPressableState();
}

class _KiraPressableState extends State<KiraPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null) return; // 不可点时无按压反馈
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
