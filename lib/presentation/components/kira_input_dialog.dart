import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/design_tokens.dart';
import 'kira_dialog_theme.dart';
import 'kira_dialog_widgets.dart';

/// Centralized text-editing dialog: globally reused single/multi-line editor
///
/// - Auto-focuses when shown
/// - Single-line: Enter confirms / multi-line: Ctrl+Enter confirms / Esc cancels
/// - maxLength truncates live with a character counter at the bottom right
/// - Empty-value validation (when allowEmpty=false)
Future<String?> showKiraInputDialog(
  BuildContext context, {
  required String title,
  String? initialValue,
  String? placeholder,
  int? maxLength,
  bool multiline = false,
  int maxLines = 10,
  String? errorMessage,
  bool allowEmpty = false,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => _KiraInputDialog(
      title: title,
      initialValue: initialValue,
      placeholder: placeholder,
      maxLength: maxLength,
      multiline: multiline,
      maxLines: maxLines,
      errorMessage: errorMessage,
      allowEmpty: allowEmpty,
    ),
  );
}

class _KiraInputDialog extends StatefulWidget {
  final String title;
  final String? initialValue;
  final String? placeholder;
  final int? maxLength;
  final bool multiline;
  final int maxLines;
  final String? errorMessage;
  final bool allowEmpty;

  const _KiraInputDialog({
    required this.title,
    this.initialValue,
    this.placeholder,
    this.maxLength,
    this.multiline = false,
    this.maxLines = 10,
    this.errorMessage,
    this.allowEmpty = false,
  });

  @override
  State<_KiraInputDialog> createState() => _KiraInputDialogState();
}

class _KiraInputDialogState extends State<_KiraInputDialog> {
  late TextEditingController _ctrl;
  final FocusNode _focus = FocusNode();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_submitting) return;
    final v = widget.allowEmpty ? _ctrl.text : _ctrl.text.trim();
    if (!widget.allowEmpty && v.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.errorMessage ?? '内容不能为空'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    Navigator.of(context, rootNavigator: true).pop(v);
  }

  void _cancel() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenH = MediaQuery.of(context).size.height;
    final titleColor = Theme.of(context).textTheme.bodyLarge?.color;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _cancel,
        if (!widget.multiline) ...{
          const SingleActivator(LogicalKeyboardKey.enter): _confirm,
          const SingleActivator(LogicalKeyboardKey.numpadEnter): _confirm,
        },
        if (widget.multiline) ...{
          const SingleActivator(LogicalKeyboardKey.enter, control: true):
              _confirm,
          const SingleActivator(LogicalKeyboardKey.numpadEnter, control: true):
              _confirm,
        },
      },
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 400,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            constraints: BoxConstraints(
              maxHeight: screenH * 0.85,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1A1B2E)
                  : const Color(0xFFF4F3FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF7B5EA7).withValues(alpha: 0.25),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: DesignTokens.fontSizeHeadline,
                      fontWeight: DesignTokens.weightBold,
                      color: titleColor,
                    ),
                  ),
                ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      autofocus: true,
                      maxLines: widget.multiline ? widget.maxLines : 1,
                      minLines: widget.multiline ? 3 : 1,
                      maxLength: widget.maxLength,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      cursorColor: KiraDialogTheme.primary,
                      style: TextStyle(
                        fontSize: DesignTokens.fontSizeBodyMedium,
                        color: titleColor,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.placeholder,
                        hintStyle: TextStyle(
                          color: titleColor?.withValues(alpha: 0.4),
                        ),
                        counterText: '',
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(DesignTokens.radiusMd),
                          borderSide: BorderSide(
                            color: const Color(0xFF7B5EA7)
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(DesignTokens.radiusMd),
                          borderSide: BorderSide(
                            color: const Color(0xFF7B5EA7)
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(DesignTokens.radiusMd),
                          borderSide: const BorderSide(
                            color: KiraDialogTheme.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.maxLength != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _ctrl,
                        builder: (_, v, __) => Text(
                          '${v.text.length}/${widget.maxLength}',
                          style: TextStyle(
                            fontSize: DesignTokens.fontSizeXs,
                            color: titleColor?.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: KiraDialogActions(
                    onCancel: _cancel,
                    onConfirm: _confirm,
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
