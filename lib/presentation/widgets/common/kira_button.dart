// lib/presentation/widgets/common/kira_button.dart
/// KiraButton, the app-wide unified button (Constitution §6.5)
///
/// Three variants: Filled / Outlined / Text. Filled = purple background, the only interactive emphasis;
/// Outlined = purple border, Text = no background. Replaces the scattered Material ElevatedButton /
/// OutlinedButton / TextButton usages.
library;

import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';

enum KiraButtonVariant { filled, outlined, text }

class KiraButton extends StatefulWidget {
  const KiraButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.variant = KiraButtonVariant.filled,
    this.isLoading = false,
    this.icon,
  });

  /// Convenience constructor: with icon
  const KiraButton.icon({
    super.key,
    required this.onPressed,
    required IconData this.icon,
    required Widget label,
    this.variant = KiraButtonVariant.filled,
    this.isLoading = false,
  }) : child = label;

  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;
  final KiraButtonVariant variant;
  final bool isLoading;

  @override
  State<KiraButton> createState() => _KiraButtonState();
}

class _KiraButtonState extends State<KiraButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primary = colorScheme.primary;

    // Text style: 14/w500
    const textStyle = TextStyle(
      fontSize: DesignTokens.fontSizeBodyMedium,
      fontWeight: DesignTokens.weightMedium,
    );

    const padding = EdgeInsets.symmetric(
      horizontal: DesignTokens.spaceMd,
      vertical: DesignTokens.spaceSm,
    );

    final Widget effectiveChild = widget.isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : (widget.icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 18),
                  const SizedBox(width: DesignTokens.spaceSm),
                  Flexible(child: widget.child),
                ],
              )
            : widget.child);

    final ButtonStyle style = switch (widget.variant) {
      KiraButtonVariant.filled => ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? primary.withValues(alpha: 0.38)
                : primary,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? colorScheme.onPrimary.withValues(alpha: 0.38)
                : colorScheme.onPrimary,
          ),
          textStyle: const WidgetStatePropertyAll(textStyle),
          padding: const WidgetStatePropertyAll(padding),
          minimumSize: const WidgetStatePropertyAll(Size(64, 44)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
            ),
          ),
        ),
      KiraButtonVariant.outlined => ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? primary.withValues(alpha: 0.38)
                : primary,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.disabled)
                  ? primary.withValues(alpha: 0.38)
                  : primary,
              width: 1.5,
            ),
          ),
          textStyle: const WidgetStatePropertyAll(textStyle),
          padding: const WidgetStatePropertyAll(padding),
          minimumSize: const WidgetStatePropertyAll(Size(64, 44)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
            ),
          ),
        ),
      KiraButtonVariant.text => ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? primary.withValues(alpha: 0.38)
                : primary,
          ),
          textStyle: const WidgetStatePropertyAll(textStyle),
          padding: const WidgetStatePropertyAll(padding),
          minimumSize: const WidgetStatePropertyAll(Size(64, 44)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
            ),
          ),
        ),
    };

    final button = switch (widget.variant) {
      KiraButtonVariant.filled => ElevatedButton(
          onPressed: _enabled ? widget.onPressed : null,
          style: style,
          child: effectiveChild,
        ),
      KiraButtonVariant.outlined => OutlinedButton(
          onPressed: _enabled ? widget.onPressed : null,
          style: style,
          child: effectiveChild,
        ),
      KiraButtonVariant.text => TextButton(
          onPressed: _enabled ? widget.onPressed : null,
          style: style,
          child: effectiveChild,
        ),
    };

    // Constitution §5 micro-feedback: press scales to 0.97, durationXs 100ms
    return GestureDetector(
      onTapDown: _enabled ? (_) => _setPressed(true) : null,
      onTapUp: _enabled ? (_) => _setPressed(false) : null,
      onTapCancel: _enabled ? () => _setPressed(false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: DesignTokens.durationXs),
        child: button,
      ),
    );
  }
}
