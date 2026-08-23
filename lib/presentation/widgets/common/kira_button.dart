// lib/presentation/widgets/common/kira_button.dart
/// KiraButton · 全 App 统一按钮(宪法 §六.5)
///
/// Filled / Outlined / Text 三变体。Filled=紫底唯一交互强调,
/// Outlined=紫边,Text=无背景。替换 Material 原生 ElevatedButton/
/// OutlinedButton/TextButton 的散件。
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

  /// 便捷构造:含图标
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

    // 文字样式:14/w500
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

    // 宪法 §五微反馈:按压缩放 0.97,durationXs 100ms
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
