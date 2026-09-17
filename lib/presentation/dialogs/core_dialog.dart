// lib/presentation/dialogs/core_dialog.dart
/// 极客Core迁移 · 统一浮窗基建
///
/// 规范单一真相源:逐条提取自 ai_config_screen.dart 的 Dialog 实现
/// (对话模型配置浮窗 / 模型选择浮窗 / 方案切换浮窗),所有迁移浮窗
/// 严格复用本文件,不得自行发挥。
///
/// 规范要点:
/// - showDialog + barrierColor black 0.6 + Center + Material(transparent) + Container
/// - 容器: radius 20 / shadow black0.3·blur40·offset(0,20) / clip antiAlias
/// - 深色面 #1C1C1C,浅色面 #FFFFFF(跟随系统明暗,由 Theme 判定)
/// - 标题栏: padding16 + 底边框0.5 + 图标20 + 标题17/w600 + xmark_circle_fill 24
/// - 输入框: CupertinoTextField,填充 #2C2C2C/#F5F5F5,radius 8,字14
/// - 按钮: CupertinoButton radius 10;主按钮 DesignTokens.primary + 白字
/// - 结构: Column[标题栏 / Flexible(SingleChildScrollView) / 底部栏]
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/utils/kira_dialog.dart';

/// 从明暗模式解析出的浮窗配色(与 ai_config 浮窗逐值一致)。
class CoreDialogPalette {
  const CoreDialogPalette({required this.isDark});

  final bool isDark;

  /// 浮窗表面色
  Color get surface => isDark ? const Color(0xFF1C1C1C) : Colors.white;

  /// 控件填充色(输入框/次要按钮/分段)
  Color get fill => isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5);

  /// 主文字
  Color get textPrimary =>
      isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C);

  /// 次级文字
  Color get textSecondary =>
      isDark ? const Color(0xFF8C8C8C) : const Color(0xFF8E8E93);

  /// 三级文字
  Color get textTertiary =>
      isDark ? const Color(0xFF6C6C6C) : const Color(0xFFBDBDBD);

  /// 分割线
  Color get divider =>
      isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0);

  /// 输入框描边(chips 未选中态)
  Color get outline =>
      isDark ? const Color(0xFF3C3C3C) : const Color(0xFFE0E0E0);

  /// 关闭按钮
  Color get closeIcon =>
      isDark ? const Color(0xFF6C6C6C) : const Color(0xFFBDBDBD);
}

/// 按极客Core规范弹浮窗(统一遮罩 0.6)。
/// useRootNavigator 默认 true,与 showDialog 及 ai_config 基准一致:
/// 从 Shell 内页面(设置/API服务)打开也全屏覆盖,不被底栏遮挡。
///
/// 内部委派 [showKiraDialog](PiuPiu 风格入场/退场动画);所有调用本函数的
/// 迁移浮窗自动获得 scale+fade 动效。遮罩沿用 0.6(原 ai_config 基准)。
Future<void> showCoreDialog(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
}) {
  return showKiraDialog(
    context: context,
    dialog: builder(context),
    barrierDismissible: barrierDismissible,
    useRootNavigator: useRootNavigator,
    barrierColor: Colors.black.withValues(alpha: 0.6),
  );
}

/// 标准浮窗壳:标题栏 + 滚动内容 + 可选底部栏。
///
/// [maxWidth] 通用 550 / 编辑器类 800 / Logit偏置 600 / 世界书 720。
/// [maxHeightFactor] 默认 0.9(任务规范)。
class CoreDialogShell extends StatelessWidget {
  const CoreDialogShell({
    super.key,
    required this.title,
    required this.body,
    this.icon,
    this.footer,
    this.trailing,
    this.maxWidth = 550,
    this.maxHeightFactor = 0.9,
    this.horizontalMargin = 24,
    this.bodyPadding = const EdgeInsets.all(20),
    this.disableScroll = false,
  });

  final String title;
  final IconData? icon;
  final Widget body;
  final Widget? footer;
  final Widget? trailing;
  final double maxWidth;
  final double maxHeightFactor;
  final double horizontalMargin;
  final EdgeInsetsGeometry bodyPadding;
  final bool disableScroll;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CoreDialogPalette(isDark: isDark);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final width = screenWidth - horizontalMargin * 2 < maxWidth
        ? screenWidth - horizontalMargin * 2
        : maxWidth;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: width,
          constraints: BoxConstraints(maxHeight: screenHeight * maxHeightFactor),
          margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CoreDialogHeader(
                title: title,
                icon: icon,
                trailing: trailing,
              ),
              Flexible(
                child: disableScroll
                    ? body
                    : SingleChildScrollView(
                        padding: bodyPadding,
                        child: body,
                      ),
              ),
              if (footer != null) footer!,
            ],
          ),
        ),
      ),
    );
  }
}

/// 标题栏:图标 + 标题 + 右侧内容 + 关闭按钮(与 ai_config 规范一致)。
class CoreDialogHeader extends StatelessWidget {
  const CoreDialogHeader({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.trailing,
  });

  final String title;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CoreDialogPalette(isDark: isDark);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: palette.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: iconColor ?? DesignTokens.primary),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
          ),
          if (trailing != null) ...[
            trailing!,
            const SizedBox(width: 8),
          ],
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            onPressed: () => Navigator.pop(context),
            child: Icon(
              CupertinoIcons.xmark_circle_fill,
              size: 24,
              color: palette.closeIcon,
            ),
          ),
        ],
      ),
    );
  }
}

/// 底部操作栏:上边框 0.5 + 按钮行。
class CoreDialogFooter extends StatelessWidget {
  const CoreDialogFooter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CoreDialogPalette(isDark: isDark);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: palette.divider, width: 0.5),
        ),
      ),
      child: child,
    );
  }
}

/// 分区标题(13/w600 主文字色,与 `_buildSectionLabel` 一致)。
class CoreSectionLabel extends StatelessWidget {
  const CoreSectionLabel(this.label, {super.key, this.palette});

  final String label;
  final CoreDialogPalette? palette;

  @override
  Widget build(BuildContext context) {
    final p = palette ??
        CoreDialogPalette(
            isDark: Theme.of(context).brightness == Brightness.dark);
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: p.textPrimary,
      ),
    );
  }
}

/// 标准输入框(与 `_buildDialogTextField` 一致)。
class CoreTextField extends StatelessWidget {
  const CoreTextField({
    super.key,
    required this.controller,
    required this.palette,
    this.hint,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.suffix,
    this.readOnly = false,
    this.autofocus = false,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.style,
  });

  final TextEditingController controller;
  final CoreDialogPalette palette;
  final String? hint;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final Widget? suffix;
  final bool readOnly;
  final bool autofocus;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return CupertinoTextField(
      controller: controller,
      placeholder: hint,
      obscureText: obscureText,
      maxLines: maxLines,
      minLines: minLines,
      readOnly: readOnly,
      autofocus: autofocus,
      keyboardType: keyboardType,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.fill,
        borderRadius: BorderRadius.circular(8),
      ),
      style: style ??
          TextStyle(fontSize: 14, color: palette.textPrimary),
      suffix: suffix,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}

/// 开关行:标题 + 副标题 + CupertinoSwitch。
class CoreSwitchRow extends StatelessWidget {
  const CoreSwitchRow({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.onChanged,
    this.palette,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final CoreDialogPalette? palette;

  @override
  Widget build(BuildContext context) {
    final p = palette ??
        CoreDialogPalette(
            isDark: Theme.of(context).brightness == Brightness.dark);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 15, color: p.textPrimary),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 12, color: p.textSecondary),
                  ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: DesignTokens.primary,
          ),
        ],
      ),
    );
  }
}

/// 滑块行:标题 + 当前值 + Slider(track 4,与极客Core `_MiniSlider` 一致)。
class CoreSliderRow extends StatelessWidget {
  const CoreSliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = CoreDialogPalette(isDark: isDark);
    final theme = Theme.of(context);
    final color = DesignTokens.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 15, color: p.textPrimary),
              ),
            ),
            Text(
              display,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor: color,
            inactiveTrackColor:
                theme.textTheme.bodySmall?.color?.withValues(alpha: 0.18),
            thumbColor: color,
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// 通用点击行:标题 + 副标题/右侧值 + chevron。
class CoreTile extends StatelessWidget {
  const CoreTile({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = CoreDialogPalette(isDark: isDark);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 15, color: p.textPrimary),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style:
                            TextStyle(fontSize: 12, color: p.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                trailing!,
                const SizedBox(width: 6),
              ],
              Icon(
                CupertinoIcons.chevron_forward,
                size: 14,
                color: p.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 主操作按钮(DesignTokens.primary + 白字)。
class CorePrimaryButton extends StatelessWidget {
  const CorePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    Widget button = CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: DesignTokens.primary,
      borderRadius: BorderRadius.circular(10),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: const TextStyle(fontSize: 15, color: Colors.white),
          ),
        ],
      ),
    );
    if (!expanded) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

/// 次要操作按钮(填充灰底,与 `_buildDialogActionButton` 一致)。
class CoreSecondaryButton extends StatelessWidget {
  const CoreSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconColor,
    this.expanded = true,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? iconColor;
  final bool expanded;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = CoreDialogPalette(isDark: isDark);
    Widget button = CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: p.fill,
      borderRadius: BorderRadius.circular(10),
      onPressed: isLoading ? null : onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(DesignTokens.primary),
              ),
            )
          else if (icon != null) ...[
            Icon(icon, size: 18, color: iconColor ?? DesignTokens.primary),
            const SizedBox(width: 8),
          ],
          if (isLoading) const SizedBox(width: 8) else const SizedBox(width: 0),
          Text(
            label,
            style: TextStyle(fontSize: 15, color: p.textPrimary),
          ),
        ],
      ),
    );
    if (!expanded) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

/// 危险按钮(红色,删除/清空确认用)。
class CoreDangerButton extends StatelessWidget {
  const CoreDangerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    Widget button = CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: const Color(0xFFF44336),
      borderRadius: BorderRadius.circular(10),
      onPressed: onPressed,
      child: Text(label,
          style: const TextStyle(fontSize: 15, color: Colors.white)),
    );
    if (!expanded) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

/// 分组信息行:图标 + 标题 + 多行说明(原各设置页 `_InfoRow` 的浮窗形态)。
class CoreInfoRow extends StatelessWidget {
  const CoreInfoRow({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
    this.palette,
  });

  final IconData icon;
  final String title;
  final String text;
  final CoreDialogPalette? palette;

  @override
  Widget build(BuildContext context) {
    final p = palette ??
        CoreDialogPalette(
            isDark: Theme.of(context).brightness == Brightness.dark);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: p.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14, color: p.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(fontSize: 12, color: p.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 统计信息行:左标签 + 右值(原 `_StatRow` 浮窗形态)。
class CoreStatRow extends StatelessWidget {
  const CoreStatRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = CoreDialogPalette(isDark: isDark);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: p.textSecondary),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: p.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 浮窗内分组卡:标题 + 子内容(浅灰填充圆角容器)。
class CoreGroupBox extends StatelessWidget {
  const CoreGroupBox({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = CoreDialogPalette(isDark: isDark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: p.textPrimary,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: p.fill.withValues(alpha: isDark ? 0.55 : 1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: child,
        ),
      ],
    );
  }
}

/// 浮窗内 SnackBar 提示(浮窗上下文里 ScaffoldMessenger 仍指向根页,可用)。
void coreToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
  );
}
