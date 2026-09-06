import 'package:flutter/material.dart';

/// [P6-5.1] 通用弹窗组件:桥接 callGenericPopup(text, type, inputValue)。
/// type 枚举对齐 ST popup.js:TEXT=1 CONFIRM=2 INPUT=3 DISPLAY=4 CROP=5。
/// 返回值对齐 POPUP_RESULT:CONFIRM → 1/0(null=取消);INPUT → 字符串(null=取消);
/// TEXT/DISPLAY → 1。
class ThPopupDialog extends StatefulWidget {
  const ThPopupDialog({
    super.key,
    required this.text,
    required this.type,
    this.inputValue = '',
  });

  final String text;
  final int type;
  final String inputValue;

  @override
  State<ThPopupDialog> createState() => _ThPopupDialogState();
}

class _ThPopupDialogState extends State<ThPopupDialog> {
  late final TextEditingController _controller;

  // POPUP_TYPE
  static const int _text = 1;
  static const int _confirm = 2;
  static const int _input = 3;
  static const int _display = 4;

  bool get _hasInput => widget.type == _input;
  bool get _hasCancel => widget.type == _confirm || widget.type == _input;
  bool get _hasOk => widget.type != _display;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.inputValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish(dynamic result) => Navigator.of(context).pop(result);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: widget.type == _confirm ? const Text('确认') : null,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(widget.text),
            if (_hasInput) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                onSubmitted: (_) => _finish(_controller.text),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_hasCancel)
          TextButton(
            onPressed: () => _finish(null),
            child: const Text('取消'),
          ),
        if (_hasOk)
          FilledButton(
            onPressed: () => _finish(
                _hasInput ? _controller.text : 1),
            child: Text(switch (widget.type) {
              _input => '确定',
              _confirm => '确定',
              _ => '关闭',
            }),
          ),
      ],
    );
  }
}
