import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/widgets/snackbar_utils.dart';

/// 统一的"复制到剪贴板并提示"实现(DRY):三组件共用。
void _copyAndNotify(BuildContext context, String text, {String? message}) {
  if (text.isEmpty) return;
  Clipboard.setData(ClipboardData(text: text));
  showSuccessSnackBar(
    context,
    message ?? AppLocalizations.of(context).copiedToClipboard,
  );
}

/// A widget that displays text with long-press to copy functionality.
/// Shows a snackbar when text is copied to clipboard.
class CopyableText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool selectable;
  final String? copyMessage;

  const CopyableText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.selectable = false,
    this.copyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (selectable) {
      return SelectableText(
        text,
        style: style,
        maxLines: maxLines,
        onTap: () {},
      );
    }

    return GestureDetector(
      onLongPress: () => _copyAndNotify(context, text, message: copyMessage),
      child: Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }
}

/// A ListTile with copyable subtitle text.
/// Long-press on the tile to copy the subtitle text.
class CopyableListTile extends StatelessWidget {
  final Widget? leading;
  final Widget? title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final String? copyMessage;

  const CopyableListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.copyMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                color: theme.textTheme.bodySmall?.color ??
                    DesignTokens.darkTextSecondary,
              ),
            )
          : null,
      trailing: trailing,
      onTap: onTap,
      enabled: enabled,
      onLongPress: subtitle != null && subtitle!.isNotEmpty
          ? () => _copyAndNotify(context, subtitle!, message: copyMessage)
          : null,
    );
  }
}

/// A SwitchListTile with copyable title/subtitle.
class CopyableSwitchListTile extends StatelessWidget {
  final Widget? secondary;
  final Widget? title;
  final String? titleText;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? copyMessage;

  const CopyableSwitchListTile({
    super.key,
    this.secondary,
    this.title,
    this.titleText,
    this.subtitle,
    required this.value,
    this.onChanged,
    this.copyMessage,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        final textToCopy = subtitle ?? titleText ?? '';
        _copyAndNotify(context, textToCopy, message: copyMessage);
      },
      child: SwitchListTile(
        secondary: secondary,
        title: title ?? (titleText != null ? Text(titleText!) : null),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
