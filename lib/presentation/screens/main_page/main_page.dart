import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kirakira/widgets/live2d_webview.dart';
class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}
class _MainPageState extends State<MainPage> {
  DateTime _now = DateTime.now();
  Timer? _timer;
  @override
  void initState() { super.initState(); _timer = Timer.periodic(const Duration(seconds: 30), (_) => mounted ? setState(() => _now = DateTime.now()) : null); }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm', 'zh_CN').format(_now);
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: Stack(children: [
        Positioned.fill(top: 0, child: const Live2DWebView()),
        Positioned(top: 48, left: 24, child: Text(timeStr, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w200))),
        Positioned(bottom: 120, left: 0, right: 0, child: Center(child: Text('\u4eca\u5929\u4e5f\u8981\u5f00\u5fc3\u54e6 \u2728', style: TextStyle(color: Colors.white.withAlpha(60), fontSize: 14)))),
      ]),
    );
  }
}