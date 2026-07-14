import 'package:flutter/material.dart';
class ChatMessageList extends StatelessWidget {
  final ScrollController scrollController;
  final int itemCount;
  final Widget Function(BuildContext,int) itemBuilder;
  const ChatMessageList({super.key,required this.scrollController,required this.itemCount,required this.itemBuilder});
  @override Widget build(BuildContext c){return ListView.builder(reverse:true,controller:scrollController,itemCount:itemCount,itemBuilder:itemBuilder);}
}