// lib/presentation/widgets/common/kira_grouped_tile.dart
/// KiraGroupedTile, a row inside an inset-grouped section (A-T4b)
///
/// iOS settings row spec: height from 44, title 17 (fontSizeBodyLarge) in primary text color,
/// subtitle 13 (fontSizeSm) in secondary color; trailing defaults to chevron_forward.
/// The whole row uses KiraPressable (scale 0.97 + opacity 0.6, 120ms).
///
/// Only valid inside a KiraSection; floating it standalone on a page violates the contract.
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

  /// When set, draws a radius-10 colored block (iOS settings icon tile) holding [icon]
  final Color? iconBg;

  /// Icon color; default: primary when iconBg is set, secondary text color when it is not
  final Color? iconColor;

  final String title;
  final String? subtitle;

  /// Default: draws a Cupertino chevron when onTap is non-null; no trailing marker when onTap is null (information-only row)
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary = theme.textTheme.bodyLarge?.color;
    final textSecondary = theme.textTheme.bodyMedium?.color;

    Widget? leading;
    if (icon != null) {
      if (iconBg != null && iconBg != Colors.transparent) {
        leading = Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: iconColor ?? theme.colorScheme.primary,
          ),
        );
      } else {
        leading = SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            icon,
            size: 26,
            color: iconColor ?? theme.colorScheme.primary,
          ),
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
      pressScale: 0.98,
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
