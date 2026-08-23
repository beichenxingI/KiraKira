// lib/presentation/widgets/common/kira_glass_bar.dart
/// KiraGlassBar · 底栏/浮动工具条毛玻璃壳(A-T6)
///
/// iOS Material Thin 语感:ClipRRect + BackdropFilter(σ22/20)+
/// 半透明底色(dark darkSurface 0.72 / light white 0.72)。
///
/// ⚠️ WebView 平台视图与 BackdropFilter 冲突(聊天 tab 会渲染失败),
/// 因此聊天 tab 必须传 [enabledBlur] = false —— 退化为 0.92 半透明
/// 纯色壳,无 blur,视觉仍通透。
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

  /// 聊天 tab(WebView 平台视图)传 false;其余 tab 默认 true
  final bool enabledBlur;

  /// 裁切圆角;底栏胶囊传 radiusFull(30)
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
