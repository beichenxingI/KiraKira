// lib/presentation/theme/design_tokens.dart
/// KiraKira 设计 Token 单一真相源
///
/// 所有硬编码颜色、圆角、间距、字体、动画、阴影均从此文件引用。
/// 严禁在业务代码中直接使用字面量，统一引用 [DesignTokens]。
///
/// 色值来源：`app_theme.dart` 的 SillyTavern 星海色系（已确认一致）。
/// 动画规范：圆润 iOS 风格，自然曲线 + 200-350ms 时长。
library;

import 'package:flutter/material.dart';

abstract class DesignTokens {
  DesignTokens._();

  // ===========================================================================
  // 圆角系统 (5 级) · 圆润 iOS 风
  // ===========================================================================
  static const double radiusXs = 4; // 小标签、输入框内部
  static const double radiusSm = 8; // 紧凑按钮、ListTile
  static const double radiusMd = 12; // 标准卡片、输入框、按钮、对话框
  static const double radiusLg = 16; // 渐变卡片、大型对话框
  static const double radiusXl = 20; // 主卡片、底部Sheet
  static const double radiusFull = 30; // 胶囊、底栏、FAB

  // 语义化别名（推荐使用）
  static const double radiusCard = radiusXl; // 20 - 主卡片
  static const double radiusInput = radiusMd; // 12 - 输入框
  static const double radiusButton = radiusMd; // 12 - 按钮
  static const double radiusDialog = radiusLg; // 16 - 对话框
  static const double radiusBottomSheet = radiusXl; // 20 - 底部Sheet
  static const double radiusChip = radiusSm; // 8 - 标签/Chip

  // ===========================================================================
  // 间距系统 (8pt 基准网格)
  // ===========================================================================
  static const double spaceZero = 0;
  static const double spaceXxs = 2; // 极紧凑
  static const double spaceXs = 4; // 图标间距、内边距微调
  static const double spaceSm = 8; // 基础单位、紧凑布局
  static const double spaceMd = 16; // 标准卡片内边距、组件间距
  static const double spaceLg = 24; // 页面区块间距
  static const double spaceXl = 32; // 大区块间距
  static const double space2xl = 48; // 页面级留白
  static const double space3xl = 64; // 超大留白

  // 语义化 EdgeInsets 预设
  static const EdgeInsets paddingCard = EdgeInsets.all(spaceMd); // 16
  static const EdgeInsets paddingCardLg = EdgeInsets.all(spaceLg); // 24
  static const EdgeInsets paddingScreen =
      EdgeInsets.symmetric(horizontal: spaceMd); // 16
  static const EdgeInsets paddingScreenLg =
      EdgeInsets.symmetric(horizontal: spaceLg); // 24
  static const EdgeInsets paddingSection =
      EdgeInsets.only(top: spaceLg, bottom: spaceSm); // 24/8
  static const EdgeInsets marginCard =
      EdgeInsets.symmetric(horizontal: spaceMd, vertical: spaceXs); // 16/4
  static const EdgeInsets marginCardLg =
      EdgeInsets.symmetric(horizontal: spaceMd, vertical: spaceSm); // 16/8

  // ===========================================================================
  // 字体系统 (7 级阶梯) · 系统默认/SF Pro 风格
  // ===========================================================================
  static const double fontSizeCaption = 10; // 辅助说明
  static const double fontSizeXs = 12; // 次要文本、Chip
  static const double fontSizeSm = 13; // 表格、紧凑文本
  static const double fontSizeBodyMedium = 14; // 正文（标准）
  static const double fontSizeBodyLarge = 16; // 正文（大）/标题
  static const double fontSizeLg = 18; // 副标题
  static const double fontSizeXl = 20; // 标题
  static const double fontSize2xl = 24; // 大标题
  static const double fontSize3xl = 28; // 屏幕标题

  // 字重
  static const FontWeight weightRegular = FontWeight.w400;
  static const FontWeight weightMedium = FontWeight.w500;
  static const FontWeight weightSemibold = FontWeight.w600;
  static const FontWeight weightBold = FontWeight.w700;

  // ===========================================================================
  // 动画系统 · 圆润自然曲线（iOS 风）
  // ===========================================================================
  // 曲线
  static const Curve curveStandard =
      Curves.easeOutCubic; // 标准入场/过渡（减速自然）
  static const Curve curveEmphasized =
      Curves.easeInOutCubic; // 强调过渡（双向平滑）
  static const Curve curveDecelerate =
      Curves.fastEaseInToSlowEaseOut; // 减速入场
  static const Curve curveSpring =
      Curves.elasticOut; // 弹性出场（对话框/按钮反馈）
  static const Curve curveSlide =
      Curves.easeOut; // 页面滑动渐隐（iOS 转场）
  static const Curve curveFade =
      Curves.easeOut; // 渐隐过渡

  // 时长 (ms) · 200-350ms 区间，避免拖沓
  static const int durationXs = 100; // 微反馈（涟漪、高亮）
  static const int durationSm = 200; // 快速过渡（淡入、Chip）
  static const int durationMd = 300; // 标准（按钮、卡片）
  static const int durationLg = 400; // 强调（页面切换、展开）
  static const int durationXl = 500; // 复杂动画（仅特殊场景）
  static const int durationDialog = 250; // 对话框（iOS 标准对话时长）

  // ===========================================================================
  // 阴影系统 (3 级) · 柔和细腻
  // ===========================================================================
  static List<BoxShadow> get shadowLevel1 => [
        // 低浮起：卡片、ListTile
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get shadowLevel2 => [
        // 中浮起：悬浮卡片、下拉菜单
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.10),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 32,
          spreadRadius: -8,
          offset: const Offset(0, 12),
        ),
      ];

  static List<BoxShadow> get shadowLevel3 => [
        // 模态对话框、底部Sheet
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.16),
          blurRadius: 48,
          spreadRadius: -12,
          offset: const Offset(0, 16),
        ),
      ];

  // Glass 专用阴影（深色模式）
  static List<BoxShadow> get shadowGlass => [
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

  // ===========================================================================
  // 颜色系统 · 与 app_theme.dart 的 AppTheme 静态色值保持一致
  // 单一真相源由 AppTheme 持有原色，DesignTokens 提供语义别名引用
  // ===========================================================================
  // 深色主题
  static const Color darkBackground = Color(0xFF0D1128);
  static const Color darkSurface = Color(0xFF161B3A);
  static const Color darkCard = Color(0xFF1F264A);
  static const Color darkDivider = Color(0xFF2A3057);

  // 浅色主题
  static const Color lightBackground = Color(0xFFEEEEF8);
  static const Color lightSurface = Color(0xFFF5F5FF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightDivider = Color(0xFFDDDDEE);

  // 文字
  static const Color textPrimary = Color(0xFFE8EAF5);
  static const Color textSecondary = Color(0xFF9095B8);
  static const Color textMuted = Color(0xFF6A6F94);

  // 品牌色
  static const Color primary = Color(0xFF7C7BF0);
  static const Color secondary = Color(0xFF6C8FF0);
  static const Color accent = Color(0xFF56D4C8);

  // 聊天气泡
  static const Color userBubble = Color(0xFF5A58D4);
  static const Color assistantBubble = Color(0xFF1F264A);
  static const Color systemBubble = Color(0xFF2A3057);

  // ===========================================================================
  // 断点 (响应式)
  // ===========================================================================
  static const double breakpointSm = 600; // 手机
  static const double breakpointMd = 900; // 平板
  static const double breakpointLg = 1200; // 桌面
  static const double breakpointXl = 1800; // 大屏
}
