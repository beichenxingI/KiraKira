import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';

class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback? onStop;
  final bool isStreaming;
  final String? hintText;
  final ValueChanged<String>? onSubmitted;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    this.onStop,
    this.isStreaming = false,
    this.hintText,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            maxLines: 5,
            minLines: 1,
            textInputAction: TextInputAction.send,
            onSubmitted: onSubmitted ?? (_) => onSend(),
            decoration: InputDecoration(
              hintText: hintText ?? '输入消息...',
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (isStreaming)
          IconButton.filled(
            onPressed: onStop,
            icon: const Icon(Icons.stop_circle),
            style: IconButton.styleFrom(
              backgroundColor: Colors.red,
            ),
          )
        else
          IconButton.filled(
            onPressed: onSend,
            icon: const Icon(Icons.send),
          ),
      ],
    );
  }
}