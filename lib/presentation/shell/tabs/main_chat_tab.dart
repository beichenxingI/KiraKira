import 'dart:async';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MainChatTab extends StatefulWidget {
  const MainChatTab({super.key});
  @override
  State<MainChatTab> createState() => _MainChatTabState();
}

class _MainChatTabState extends State<MainChatTab> {
  DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  String _greeting() {
    final h = _now.hour;
    if (h >= 6 && h < 12) return '\u65e9\u4e0a\u597d \ud83c\udf05';
    if (h >= 12 && h < 18) return '\u4e0b\u5348\u597d \ud83c\udf24';
    if (h >= 18 && h < 22) return '\u665a\u4e0a\u597d \ud83c\udf19';
    return '\u591c\u6df1\u4e86 \ud83c\udf03';
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('\u4eca\u5929\u662f yyyy\u5e74M\u6708d\u65e5 EEEE', 'zh_CN').format(_now);
    final timeStr = DateFormat('HH:mm:ss', 'zh_CN').format(_now);
    return Scaffold(
      backgroundColor: DesignTokens.darkBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(dateStr, style: TextStyle(color: Colors.white.withValues(alpha:0.5), fontSize: 14)),
            const SizedBox(height: 8),
            Text(timeStr, style: const TextStyle(color: Color(0xFFFCD34D), fontSize: 48, fontWeight: FontWeight.w200)),
            const SizedBox(height: 24),
            Text(_greeting(), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('\u4eca\u5929\u4e5f\u8981\u5f00\u5fc3\u54e6 \u2728', style: TextStyle(color: Colors.white.withValues(alpha:0.4), fontSize: 14)),
            const SizedBox(height: 300),
            Container(width:200, height:4, decoration: BoxDecoration(gradient: const LinearGradient(colors:[Color(0xFFFCD34D), Color(0xFFF59E0B)]), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height:8),
            Text('/* TODO: Live2D \u770b\u677f\u5a18\u63a5\u5165\u4f4d\u7f6e */', style: TextStyle(color: Colors.white.withValues(alpha:0.12), fontSize: DesignTokens.fontSizeCaption)),
          ],
        ),
      ),
    );
  }
}