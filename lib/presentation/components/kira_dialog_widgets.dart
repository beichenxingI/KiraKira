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

/// Dashed "add" button (circular, for in-list add actions)
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

/// Collapsible card content-area trigger: shows the current value; tapping opens the edit dialog
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

/// Tag chip (with delete button)
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

/// Pill save button (primary gradient, full width)
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

/// Gradient underline (transparent to purple to transparent)
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

/// Centered pill button row (cancel/confirm)
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

/// Circular icon button (for avatar editing, delete, etc.)
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

/// Produces a stable color from a string (hash modulo)
Color kiraHashColor(String text) {
  return KiraDialogTheme.tagColorFor(text);
}

/// Generic centered panel shadow (dialog content card)
BoxShadow kiraPanelShadow({double alpha = 0.07, Color? color}) {
  return BoxShadow(
    color: (color ?? Colors.black).withValues(alpha: alpha),
    blurRadius: 20,
    offset: const Offset(0, 8),
  );
}

/// Clamps numeric input to a range
int kiraClampInt(String? text, int min, int fallback) {
  if (text == null) return fallback;
  final v = int.tryParse(text.trim());
  if (v == null || v < min) return fallback;
  return v;
}

/// min-width helper (used internally by kira_dialog)
double kiraMinWidth(BuildContext context, double max) {
  return min(MediaQuery.of(context).size.width - 40, max);
}
