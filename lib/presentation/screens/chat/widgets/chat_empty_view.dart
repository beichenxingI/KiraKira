import 'package:flutter/material.dart';
class ChatEmptyView extends StatelessWidget {
  const ChatEmptyView({super.key});
  @override
  Widget build(BuildContext c) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.chat_bubble_outline, size: 64, color: Colors.white.withAlpha(50)), SizedBox(height: 16), Text('选择一个角色开始聊天', style: TextStyle(color: Colors.white.withAlpha(80)))]));
  }
}