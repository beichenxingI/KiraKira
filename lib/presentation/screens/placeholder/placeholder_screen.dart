import 'package:flutter/material.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, this.title});
  final String? title;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF1a1a2e),
    appBar: AppBar(title: Text(title ?? ''), backgroundColor: Colors.transparent),
    body: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.construction_rounded, size: 64, color: Color(0xFFa78bfa)),
      SizedBox(height: 16),
      Text('\u529f\u80fd\u5f00\u53d1\u4e2d\uff0c\u656c\u8bf7\u671f\u5f85', style: TextStyle(color: Colors.white54, fontSize: 16)),
    ])),
  );
}