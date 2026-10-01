// lib/presentation/dialogs/core_dialog.dart
/// Shared dialog foundation.
///
/// Single source of truth for the dialog spec, extracted from the
/// ai_config_screen.dart dialog implementations (chat model config dialog /
/// model selection dialog / profile switch dialog); all migrated dialogs
/// reuse this file instead of defining their own styling.
///
/// Spec highlights:
/// - showDialog + barrierColor black 0.6 + Center + Material(transparent) + Container
/// - Container: radius 20 / shadow black0.3, blur 40, offset(0,20) / clip antiAlias
/// - Dark surface #1C1C1C, light surface #FFFFFF (follows system brightness, resolved from Theme)
/// - Title bar: padding 16 + bottom border 0.5 + icon 20 + title 17/w600 + xmark_circle_fill 24
/// - Text field: CupertinoTextField, fill #2C2C2C/#F5F5F5, radius 8, font 14
/// - Buttons: CupertinoButton radius 10; primary button uses DesignTokens.primary with white text
/// - Structure: Column[title bar / Flexible(SingleChildScrollView) / bottom bar]
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/utils/kira_dialog.dart';

/// Dialog colors resolved from light/dark mode (value-for-value identical to the ai_config dialog).
class CoreDialogPalette {
  const CoreDialogPalette({required this.isDark});

  final bool isDark;

  /// Dialog surface color
  Color get surface => isDark ? const Color(0xFF1C1C1C) : Colors.white;

  /// Control fill color (text fields / secondary buttons / segments)
  Color get fill => isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5);

  /// Primary text
  Color get textPrimary =>
      isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C);

  /// Secondary text
  Color get textSecondary =>
      isDark ? const Color(0xFF8C8C8C) : const Color(0xFF8E8E93);

  /// Tertiary text
  Color get textTertiary =>
      isDark ? const Color(0xFF6C6C6C) : const Color(0xFFBDBDBD);

  /// Divider
  Color get divider =>
      isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0);

  /// Input border (chips unselected state)
  Color get outline =>
      isDark ? const Color(0xFF3C3C3C) : const Color(0xFFE0E0E0);

  /// Close button
  Color get closeIcon =>
      isDark ? const Color(0xFF6C6C6C) : const Color(0xFFBDBDBD);
}

/// Shows a dialog per the Core spec (uniform 0.6 barrier).
/// [useRootNavigator] defaults to true, matching showDialog and the ai_config baseline:
/// dialogs opened from Shell pages (settings/API services) still cover the full
/// screen and are not hidden behind the bottom bar.
///
/// Delegates internally to [showKiraDialog] (soft-bounce scale animation), so every
/// dialog built on this function automatically gets the scale+fade animation.
/// Barrier stays at 0.6 (original ai_config baseline).
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

/// Standard dialog shell: title bar + scrollable content + optional bottom bar.
///
/// [maxWidth] 550 general / 800 editors / 600 logit bias / 720 worldbook.
/// [maxHeightFactor] defaults to 0.9.
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

/// Title bar: icon + title + trailing content + close button (matches the ai_config spec).
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

/// Bottom action bar: 0.5 top border + button row.
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

/// Section label (13/w600 primary text color, matches `_buildSectionLabel`).
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

/// Standard text field (matches `_buildDialogTextField`).
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

/// Switch row: title + subtitle + CupertinoSwitch.
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

/// Slider row: title + current value + Slider (track 4, matches Core's `_MiniSlider`).
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
    const color = DesignTokens.primary;
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
              style: const TextStyle(
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

/// Generic tap row: title + subtitle/trailing value + chevron.
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

/// Primary action button (DesignTokens.primary + white text).
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
    final Widget button = CupertinoButton(
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

/// Secondary action button (grey fill, matches `_buildDialogActionButton`).
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
    final Widget button = CupertinoButton(
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

/// Danger button (red, used for delete/clear confirmations).
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
    final Widget button = CupertinoButton(
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

/// Grouped info row: icon + title + multiline description (dialog form of the settings screens' `_InfoRow`).
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

/// Stat info row: left label + right value (dialog form of `_StatRow`).
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

/// In-dialog group card: title + child content (light-grey rounded fill container).
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

/// In-dialog SnackBar (ScaffoldMessenger still resolves to the root page in dialog context, so it works).
void coreToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
  );
}
