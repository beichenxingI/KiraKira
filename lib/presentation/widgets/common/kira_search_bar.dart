// lib/presentation/widgets/common/kira_search_bar.dart
/// KiraSearchBar, the app-wide unified search bar (iOS-style: Constitution §5.5 + handbook A-T5)
///
/// iOS search field spec: height 36, radius 10 (not a full capsule), prefix CupertinoIcons.search,
/// fill dark=darkCard / light=lightFillTertiary, no stroke when focused (the cursor is the feedback),
/// clear button clear_circled_solid.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';

class KiraSearchBar extends StatelessWidget {
  const KiraSearchBar({
    super.key,
    this.controller,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.autofocus = false,
    this.padding = DesignTokens.paddingScreen,
  });

  final TextEditingController? controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool autofocus;

  /// Outer spacing; pass EdgeInsets.zero to sit flush (for sticky layouts in blocks B/C)
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark
        ? DesignTokens.darkCard
        : Colors.black.withValues(alpha: 0.04);
    final tertiary = theme.textTheme.bodySmall?.color;

    final field = SizedBox(
      height: 36, // measured 36 for the iOS search bar
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontSize: DesignTokens.fontSizeBodyLarge,
          color: theme.textTheme.bodyLarge?.color,
        ),
        cursorColor: theme.colorScheme.primary,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: fillColor,
          hintText: hintText,
          hintStyle: TextStyle(
            color: tertiary,
            fontSize: DesignTokens.fontSizeBodyLarge,
          ),
          prefixIcon: Icon(CupertinoIcons.search, size: 18, color: tertiary),
          suffixIcon: _ClearButton(
            controller: controller,
            onClear: onClear,
            color: tertiary,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceSm,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
            borderSide: BorderSide.none,
          ),
          // iOS search has no focused border stroke; the cursor is the feedback
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );

    return Padding(padding: padding, child: field);
  }
}

/// Clear button: shown only when there is input
class _ClearButton extends StatefulWidget {
  const _ClearButton({this.controller, this.onClear, this.color});

  final TextEditingController? controller;
  final VoidCallback? onClear;
  final Color? color;

  @override
  State<_ClearButton> createState() => _ClearButtonState();
}

class _ClearButtonState extends State<_ClearButton> {
  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller?.text.isNotEmpty ?? false;
    if (!hasText) return const SizedBox.shrink();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        widget.controller?.clear();
        widget.onClear?.call();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceSm),
        child: Icon(
          CupertinoIcons.clear_circled_solid,
          size: 17,
          color: widget.color,
        ),
      ),
    );
  }
}
