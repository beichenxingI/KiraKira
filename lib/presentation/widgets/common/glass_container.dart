import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 毛玻璃配色方案
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

  /// 页面兜底背景色
  final Color pageBackground;

  /// 主要玻璃底色，传入的颜色本身保持不透明，透明度由组件统一控制
  final Color glassTint;

  /// 内层控件或浮层底色
  final Color elevatedTint;

  /// 强调色：发送按钮、激活状态等
  final Color accent;

  final Color primaryText;
  final Color secondaryText;
}

/// 两套无紫色配色
abstract final class GlassPalettes {
  /// 偏蓝：科技感更强，适合 AI 聊天界面
  static const GlassPalette blue = GlassPalette(
    pageBackground: Color(0xFF070B14),
    glassTint: Color(0xFF0A0E1A),
    elevatedTint: Color(0xFF111A2A),
    accent: Color(0xFF79C7FF),
    primaryText: Color(0xFFF5F7FA),
    secondaryText: Color(0xFFA7B0BE),
  );

  /// 偏灰：更克制、更接近  高级感深色界面
  static const GlassPalette graphite = GlassPalette(
    pageBackground: Color(0xFF101216),
    glassTint: Color(0xFF14161C),
    elevatedTint: Color(0xFF20242C),
    accent: Color(0xFFA8D8FF),
    primaryText: Color(0xFFF5F5F7),
    secondaryText: Color(0xFFA8AAB2),
  );
}

/// 在这里切换整套配色
const GlassPalette activeGlassPalette = GlassPalettes.blue;
// const GlassPalette activeGlassPalette = GlassPalettes.graphite;

/// 全局毛玻璃设计参数
abstract final class GlassDesign {
  /// 主玻璃透明度：严格保持在 0.55–0.65
  static const double appBarOpacity = 0.60;
  static const double panelOpacity = 0.62;
  static const double inputOpacity = 0.60;

  /// 模糊强度
  static const double appBarBlur = 22;
  static const double panelBlur = 24;
  static const double inputBlur = 22;

  /// 圆角
  static const double appBarRadius = 22;
  static const double panelRadius = 24;
  static const double cardRadius = 20;
  static const double capsuleRadius = 30;

  /// 极淡玻璃高光边
  static Color get highlightBorder =>
      Colors.white.withValues(alpha: 0.08);

  /// 内部控件浅色底
  static Color get controlFill =>
      Colors.white.withValues(alpha: 0.055);

  /// 内部控件按下或激活状态
  static Color get activeControlFill =>
      Colors.white.withValues(alpha: 0.10);

  /// 柔和、大范围、低透明度阴影
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

/// 深色磨砂玻璃容器：半透明底 + 高斯模糊 + 极淡白边 + 柔和阴影。
/// 顶栏/输入栏/面板/卡片统一复用，保证"通透但看得清"。
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
          // 不依赖 BackdropFilter（WebView 平台视图上会渲染失败变全透明）
          // 用高不透明度半透明纯色底：可靠可读，仍保留通透质感
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