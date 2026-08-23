// lib/presentation/widgets/common/kira_search_bar.dart
/// KiraSearchBar · 全局统一搜索栏(iOS 化:宪法 §五.5 + 手册 A-T5)
///
/// iOS 搜索框规格:高 36、圆角 10(非全胶囊)、前缀 CupertinoIcons.search、
/// 填充 dark=darkCard / light=lightFillTertiary、聚焦无描边(光标即反馈)、
/// 清除按钮 clear_circled_solid。
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

  /// 外层留白;传 EdgeInsets.zero 可裸贴(供 Block B/C 吸顶排版)
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fillColor =
        isDark ? DesignTokens.darkCard : DesignTokens.lightFillTertiary;
    final tertiary = theme.textTheme.bodySmall?.color;

    final field = SizedBox(
      height: 36, // iOS 搜索栏实测 36
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
            borderRadius: BorderRadius.circular(DesignTokens.radiusGroupedCard),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusGroupedCard),
            borderSide: BorderSide.none,
          ),
          // iOS 搜索聚焦无边框描边,光标即反馈
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusGroupedCard),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );

    return Padding(padding: padding, child: field);
  }
}

/// 清除按钮:仅在有输入时显示
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
