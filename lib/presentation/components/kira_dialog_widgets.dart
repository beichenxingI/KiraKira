import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import 'kira_dialog_theme.dart';

class KiraDashedButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const KiraDashedButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          child: Container(
            padding: const EdgeInsets.symmetric(
                vertical: DesignTokens.spaceMd, horizontal: DesignTokens.spaceSm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
              border: Border.all(
                color: color.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: DesignTokens.spaceSm),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: DesignTokens.fontSizeBodyMedium,
                      fontWeight: DesignTokens.weightSemibold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 虚线添加按钮（圆形，用于列表内"添加"操作）
class KiraDashedAddButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const KiraDashedAddButton({
    super.key,
    required this.label,
    this.icon = Icons.add,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: DesignTokens.spaceSm),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
            border: Border.all(
              color: color.withValues(alpha: 0.4),
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: DesignTokens.spaceXs),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: DesignTokens.fontSizeBodyMedium,
                  fontWeight: DesignTokens.weightSemibold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 折叠卡片内容区触发器：显示当前值，点击弹出编辑浮窗
class KiraEditTrigger extends StatelessWidget {
  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final bool isDark;
  final Color accentColor;
  final bool codeFont;

  const KiraEditTrigger({
    super.key,
    required this.value,
    required this.placeholder,
    required this.onTap,
    required this.isDark,
    this.accentColor = KiraDialogTheme.primary,
    this.codeFont = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.trim().isNotEmpty;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 200),
          padding: const EdgeInsets.symmetric(
              vertical: 14, horizontal: 15),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0xFFFFF9FB).withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.3),
            ),
          ),
          child: SingleChildScrollView(
            child: Text(
              hasValue ? value! : placeholder,
              style: TextStyle(
                fontSize: DesignTokens.fontSizeSm,
                height: 1.5,
                fontFamily: codeFont ? 'monospace' : null,
                color: hasValue
                    ? textColor
                    : textColor?.withValues(alpha: 0.55),
                fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 标签 Chip（含删除按钮）
class KiraTagChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onRemove;

  const KiraTagChip({
    super.key,
    required this.label,
    required this.color,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceMd, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: DesignTokens.fontSizeSm,
                fontWeight: DesignTokens.weightMedium,
              ),
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: Icon(
                Icons.close,
                size: 14,
                color: color.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 胶囊保存按钮（主色渐变，全宽）
class KiraSaveButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback? onPressed;

  const KiraSaveButton({
    super.key,
    required this.label,
    this.enabled = true,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF6C5CE7),
                  Color(0xFFA855F7),
                ],
              ),
              borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: DesignTokens.fontSizeBodyLarge,
                fontWeight: DesignTokens.weightSemibold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 渐变下划线（透明→紫→透明）
class KiraGradientUnderline extends StatelessWidget {
  const KiraGradientUnderline({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6C5CE7).withValues(alpha: 0.0),
            const Color(0xFF6C5CE7).withValues(alpha: 0.6),
            const Color(0xFF6C5CE7).withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

/// 居中胶囊按钮组（取消/确认）
class KiraDialogActions extends StatelessWidget {
  final String cancelText;
  final String confirmText;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final Color confirmColor;

  const KiraDialogActions({
    super.key,
    this.cancelText = '取消',
    this.confirmText = '确认',
    this.onCancel,
    this.onConfirm,
    this.confirmColor = KiraDialogTheme.primary,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryText = Theme.of(context).textTheme.bodyMedium?.color;
    return Row(
      children: [
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onCancel,
              borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                  border: Border.all(
                    color: KiraDialogTheme.primary.withValues(alpha: 0.12),
                  ),
                ),
                child: Text(
                  cancelText,
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.8)
                        : secondaryText?.withValues(alpha: 0.8),
                    fontSize: DesignTokens.fontSizeBodyMedium,
                    fontWeight: DesignTokens.weightMedium,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: DesignTokens.spaceMd),
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onConfirm,
              borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: confirmColor,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                ),
                child: Text(
                  confirmText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: DesignTokens.fontSizeBodyMedium,
                    fontWeight: DesignTokens.weightSemibold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 圆形图标按钮（用于头像编辑、删除等）
class KiraCircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color? borderColor;
  final double size;
  final VoidCallback? onTap;

  const KiraCircleIconButton({
    super.key,
    required this.icon,
    required this.color,
    this.borderColor,
    this.size = 32,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: borderColor != null
                ? Border.all(color: borderColor!, width: 3)
                : null,
          ),
          child: Icon(Icons.edit, size: size * 0.5, color: Colors.white),
        ),
      ),
    );
  }
}

/// 根据字符串生成稳定颜色（哈希取模）
Color kiraHashColor(String text) {
  return KiraDialogTheme.tagColorFor(text);
}

/// 通用居中面板阴影（浮窗内容卡）
BoxShadow kiraPanelShadow({double alpha = 0.07, Color? color}) {
  return BoxShadow(
    color: (color ?? Colors.black).withValues(alpha: alpha),
    blurRadius: 20,
    offset: const Offset(0, 8),
  );
}

/// 限制数字输入范围
int kiraClampInt(String? text, int min, int fallback) {
  if (text == null) return fallback;
  final v = int.tryParse(text.trim());
  if (v == null || v < min) return fallback;
  return v;
}

/// min helper（kira_dialog 内部使用）
double kiraMinWidth(BuildContext context, double max) {
  return min(MediaQuery.of(context).size.width - 40, max);
}
