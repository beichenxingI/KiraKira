// lib/presentation/theme/design_tokens.dart
/// KiraKira 设计 Token 单一真相源(iOS 化宪法 v2 版)
///
/// 所有硬编码颜色、圆角、间距、字体、动画、阴影均从此文件引用。
/// 严禁在业务代码中直接使用字面量,统一引用 [DesignTokens]。
///
/// 色板 = 宪法 v2 §一「B 方案:iOS 骨架 + 星海皮肤」:
/// 近黑带微蓝底(0B0B12)、三级灰差分层、半透明白文字(非实色灰)、
/// 深色零阴影、单强调色星海紫 7C7BF0。
/// 字阶对齐 iOS Type Scale(HIG Typography)。
library;

import 'package:flutter/material.dart';

abstract class DesignTokens {
  DesignTokens._();

  // ===========================================================================
  // 圆角系统 · iOS 实测区间(宪法 v2 §三)
  // ===========================================================================
  static const double radiusXs = 4; // 小标签、输入框内部
  static const double radiusSm = 8; // 紧凑按钮、ListTile
  static const double radiusMd = 12; // 标准按钮、输入框基准
  static const double radiusLg = 16; // 大弹层内衬
  @Deprecated('旧主卡片值(20),iOS 化后勿再用,用 radiusCard(12)')
  static const double radiusXl = 20; // 旧主卡片值,勿再用
  static const double radiusFull = 30; // 胶囊、底栏、FAB

  // 语义化别名(推荐使用)
  static const double radiusCard = 12; // 独立卡(iOS 卡片惯例 10-12)
  static const double radiusGroupedCard = 10; // inset-grouped 分组卡(主力)
  static const double radiusInput = radiusMd; // 12 - 输入框
  static const double radiusButton = radiusMd; // 12 - 按钮
  static const double radiusDialog = 14; // AlertDialog(iOS alert ~14)
  static const double radiusBottomSheet = 14; // 底部Sheet 顶角(iOS 13+ 10-14)
  static const double radiusChip = radiusSm; // 8 - 标签/Chip

  // ===========================================================================
  // 间距系统 (8pt 基准网格)
  // ===========================================================================
  static const double spaceZero = 0;
  static const double spaceXxs = 2; // 极紧凑
  static const double spaceXs = 4; // 图标间距、内边距微调
  static const double spaceSm = 8; // 基础单位、紧凑布局
  static const double spaceMd = 16; // 标准卡片内边距、组件间距
  static const double spaceLg = 24; // 页面区块间距(inset-grouped 组间距)
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
  // 字阶 · 对齐 iOS Type Scale(宪法 v2 §二,HIG Typography)
  // ===========================================================================
  static const double fontSizeCaption = 11; // Caption 2
  static const double fontSizeXs = 12; // Caption 1
  static const double fontSizeSm = 13; // Footnote(列表副行/说明)
  static const double fontSizeBodyMedium = 15; // Subheadline
  static const double fontSizeHeadline = 17; // Headline 17/Semibold(列表行标题,配 weightSemibold)
  static const double fontSizeBodyLarge = 17; // Body 17(iOS 默认正文)
  static const double fontSizeXl = 20; // Title 3
  static const double fontSize2xl = 22; // Title 2
  static const double fontSize3xl = 28; // Title 1
  static const double fontSizeDisplayLarge = 34; // Large Title(SliverAppBar.large)

  // 字重
  static const FontWeight weightRegular = FontWeight.w400;
  static const FontWeight weightMedium = FontWeight.w500;
  static const FontWeight weightSemibold = FontWeight.w600;
  static const FontWeight weightBold = FontWeight.w700;

  // ===========================================================================
  // 动画系统 · iOS 手感(宪法 v2 §四)
  // ===========================================================================
  // 曲线
  static const Curve curveStandard =
      Curves.easeOutCubic; // 标准入场/过渡(减速自然)
  static const Curve curveEmphasized =
      Curves.easeInOutCubic; // 强调过渡(双向平滑)
  static const Curve curveDecelerate =
      Curves.fastEaseInToSlowEaseOut; // 减速入场
  static const Curve curveSpring =
      Curves.easeOutBack; // 温和回弹,iOS 性格;elasticOut 禁用
  static const Curve curveSlide =
      Curves.easeOut; // 页面滑动渐隐(iOS 转场)
  static const Curve curveFade =
      Curves.easeOut; // 渐隐过渡

  // 时长 (ms)
  static const int durationXs = 100; // 微反馈
  static const int durationSm = 200; // 快速过渡
  static const int durationMd = 300; // 标准
  static const int durationLg = 400; // 强调
  static const int durationXl = 500; // 复杂动画(仅特殊场景)
  static const int durationDialog = 250; // 对话框

  // ===========================================================================
  // 阴影系统
  // ⚠️ 宪法 v2:深色模式一律零阴影(层次靠三级灰差+separator);
  //    shadowLevel1/2/3 仅浅色模式 modal/sheet 允许使用,所有卡片禁用。
  // ===========================================================================
  static List<BoxShadow> get shadowLevel1 => [
        // 仅浅色小浮起
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get shadowLevel2 => [
        // 仅浅色 modal/sheet 允许
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
        // 仅浅色大型模态极端场景;深色禁用
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

  // Glass 专用阴影(深色模式)· 保留至 Block B 底栏参考后评估删除
  @Deprecated('A 阶段过渡保留:B-T2 毛玻璃底栏落地后评估删除;深色模式禁止新引用')
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
  // 颜色系统 · 宪法 v2 §一(B 方案:iOS 骨架 + 星海皮肤)
  // iOS 原型 + 2-3% 蓝紫微调;深色文字 = 纯白 + 透明度分层(禁止实色灰)
  // ===========================================================================
  // 深色主题(主战场)
  static const Color darkBackground = Color(0xFF0B0B12); // 页面最底层(grouped 列表背景)
  static const Color darkSurface = Color(0xFF17171E); // inset-grouped 分组卡/导航栏底
  static const Color darkCard = Color(0xFF26262F); // 三级:输入框填充、控件容器、按压高亮
  static const Color darkSeparator = Color(0x99545458); // 半透明分隔线(iOS 原型)
  static const Color darkSeparatorOpaque = Color(0xFF3A3A44); // 不透明分隔线(极少用)

  // 浅色主题
  static const Color lightBackground = Color(0xFFF2F2F7); // systemGroupedBackground
  static const Color lightSurface = Color(0xFFFFFFFF); // secondarySystemGroupedBackground
  static const Color lightCard = Color(0xFFFFFFFF); // 分组卡=纯白,层级靠灰底反衬
  static const Color lightFillTertiary = Color(0x1F767680); // tertiarySystemFill(输入框/控件填充)
  static const Color lightSeparator = Color(0x493C3C43); // separator

  // 深色文字 · 白 + 透明度(铁律:禁止实色灰)
  static const Color darkTextPrimary = Color(0xFFFFFFFF); // label
  static const Color darkTextSecondary = Color(0x99EBEBF5); // secondaryLabel 白60%
  static const Color darkTextTertiary = Color(0x4DEBEBF5); // tertiaryLabel 白30%
  static const Color darkTextDisabled = Color(0x29EBEBF5); // quaternaryLabel 白16%

  // 浅色文字 · 黑 + 透明度
  static const Color lightTextPrimary = Color(0xFF000000); // label
  static const Color lightTextSecondary = Color(0x993C3C43); // secondaryLabel 黑60%
  static const Color lightTextTertiary = Color(0x4D3C3C43); // tertiaryLabel 黑30%
  static const Color lightTextDisabled = Color(0x2E3C3C43); // quaternaryLabel 黑18%

  // 品牌色(星海皮肤)
  static const Color primary = Color(0xFF7C7BF0); // 星海紫 · 唯一交互强调色
  static const Color secondary = Color(0xFF6C8FF0); // 图表第二序列/渐变辅助
  static const Color accent = Color(0xFF56D4C8); // 青 · 仅状态正向/数据高亮

  // 状态色(iOS system 绿/橙/红;主名=深色值,Light 为浅色模式变体)
  static const Color statusSuccess = Color(0xFF30D158); // iOS systemGreen 深
  static const Color statusSuccessLight = Color(0xFF34C759); // iOS systemGreen 浅
  static const Color statusWarning = Color(0xFFFF9F0A); // iOS systemOrange 深
  static const Color statusWarningLight = Color(0xFFFF9500); // iOS systemOrange 浅
  static const Color statusError = Color(0xFFFF453A); // iOS systemRed 深
  static const Color statusErrorLight = Color(0xFFFF3B30); // iOS systemRed 浅

  // 聊天气泡(token 指认;聊天域渲染层禁改)
  static const Color userBubble = Color(0xFF5A58D4);
  static const Color assistantBubble = darkSurface; // #17171E
  static const Color systemBubble = darkCard; // #26262F

  // ===========================================================================
  // 断点 (响应式)
  // ===========================================================================
  static const double breakpointSm = 600; // 手机
  static const double breakpointMd = 900; // 平板
  static const double breakpointLg = 1200; // 桌面
  static const double breakpointXl = 1800; // 大屏
}
