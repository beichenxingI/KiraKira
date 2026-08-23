// lib/presentation/widgets/common/kira_search_bar.dart
/// KiraSearchBar · 全局统一胶囊搜索栏(宪法 §六.4)
///
/// 顶部吸附、filled 胶囊、圆角 radiusFull。各列表页共用一套,
/// 不再各自造搜索框。
library;

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
  });

  final TextEditingController? controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark
        ? DesignTokens.darkCard
        : theme.colorScheme.surfaceContainerHighest;

    return Padding(
      padding: DesignTokens.paddingScreen,
      child: SizedBox(
        height: 44, // 工程尺寸:iOS 触控最小高,不进 token
        child: TextField(
          controller: controller,
          autofocus: autofocus,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: DesignTokens.fontSizeBodyMedium,
          ),
          cursorColor: theme.colorScheme.primary,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: fillColor,
            hintText: hintText,
            hintStyle: const TextStyle(
              color: DesignTokens.textSecondary,
              fontSize: DesignTokens.fontSizeBodyMedium,
            ),
            prefixIcon: const Icon(Icons.search, size: 20),
            prefixIconColor: DesignTokens.textSecondary,
            suffixIcon: _ClearButton(
              controller: controller,
              onClear: onClear,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceMd,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
              borderSide: BorderSide(color: theme.colorScheme.primary),
            ),
          ),
        ),
      ),
    );
  }
}

/// 清除按钮:仅在有输入时显示
class _ClearButton extends StatefulWidget {
  const _ClearButton({this.controller, this.onClear});

  final TextEditingController? controller;
  final VoidCallback? onClear;

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
    return IconButton(
      icon: const Icon(Icons.clear, size: 18),
      color: DesignTokens.textSecondary,
      onPressed: () {
        widget.controller?.clear();
        widget.onClear?.call();
      },
    );
  }
}
