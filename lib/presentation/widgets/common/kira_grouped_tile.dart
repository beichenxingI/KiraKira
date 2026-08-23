// lib/presentation/widgets/common/kira_grouped_tile.dart
/// KiraGroupedTile · inset-grouped 组内行(A-T4b)
///
/// iOS 设置行规格:高 44 起,标题 17(fontSizeBodyLarge)主文字色,
/// 副标题 13(fontSizeSm)次级色;trailing 默认 chevron_forward。
/// 整行 KiraPressable(scale 0.97 + opacity 0.6,120ms)。
///
/// **只能在 KiraSection 内使用**,单独浮在页面上是违规(契约束)。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/widgets/common/kira_pressable.dart';

class KiraGroupedTile extends StatelessWidget {
  const KiraGroupedTile({
    super.key,
    this.icon,
    this.iconBg,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData? icon;

  /// 给则画 10 圆角彩块(iOS 设置彩块图标),其内放 [icon]
  final Color? iconBg;

  /// icon 颜色;默认:有 iconBg 时 = primary,无 iconBg 时 = 次级文字色
  final Color? iconColor;

  final String title;
  final String? subtitle;

  /// 默认:onTap 非空时画 Cupertino chevron;onTap 为空则无尾标(纯信息行)
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary = theme.textTheme.bodyLarge?.color;
    final textSecondary = theme.textTheme.bodyMedium?.color;

    Widget? leading;
    if (icon != null) {
      if (iconBg != null) {
        leading = Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(DesignTokens.radiusGroupedCard),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 17,
            color: iconColor ?? theme.colorScheme.primary,
          ),
        );
      } else {
        leading = Icon(
          icon,
          size: 22,
          color: iconColor ?? textSecondary,
        );
      }
    }

    final defaultTrailing = onTap != null
        ? Icon(
            CupertinoIcons.chevron_forward,
            size: 16,
            color: theme.textTheme.bodySmall?.color,
          )
        : null;

    return KiraPressable(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceMd,
            vertical: DesignTokens.spaceSm,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading,
                const SizedBox(width: DesignTokens.spaceSm + 4),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: DesignTokens.fontSizeBodyLarge,
                        color: textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeSm,
                          color: textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null || defaultTrailing != null) ...[
                const SizedBox(width: DesignTokens.spaceSm),
                trailing ?? defaultTrailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
