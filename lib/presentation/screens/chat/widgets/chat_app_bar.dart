import 'package:flutter/material.dart';
class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onAuthorNotes;
  final VoidCallback? onWorldInfo;
  final VoidCallback? onExportChat;
  final VoidCallback? onResponseLength;
  final VoidCallback? onClearChat;
  const ChatAppBar({super.key,this.onAuthorNotes,this.onWorldInfo,this.onExportChat,this.onResponseLength,this.onClearChat});
  @override Widget build(BuildContext c){return AppBar(title:const Text('Chat'),actions:[PopupMenuButton<String>(icon:const Icon(Icons.more_vert),onSelected:(v){switch(v){case'author_notes':onAuthorNotes?.call();case'world_info':onWorldInfo?.call();case'export_chat':onExportChat?.call();case'response_length':onResponseLength?.call();case'clear_chat':onClearChat?.call();}},itemBuilder:(ct)=>[const PopupMenuItem(value:'author_notes',child:Text('作者注释')),const PopupMenuItem(value:'world_info',child:Text('世界书')),const PopupMenuDivider(),const PopupMenuItem(value:'response_length',child:Text('回复字数')),const PopupMenuItem(value:'clear_chat',child:Text('清空聊天')),const PopupMenuItem(value:'export_chat',child:Text('导出聊天')),])]);} @override Size get preferredSize=>const Size.fromHeight(kToolbarHeight);}