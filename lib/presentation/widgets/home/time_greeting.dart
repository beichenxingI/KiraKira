import 'package:flutter/material.dart';

/// 跟随时间段变化的问候语，放在主页时间旁
class TimeGreeting extends StatelessWidget {
  final TextStyle? style;
  const TimeGreeting({super.key, this.style});

  static String greetingFor(int hour) {
    if (hour >= 5 && hour < 9) return '早安，新的一天开始了 ☀️';
    if (hour >= 9 && hour < 12) return '上午好，今天也要加油 ✨';
    if (hour >= 12 && hour < 14) return '午后时光，记得吃饭哦 🍵';
    if (hour >= 14 && hour < 18) return '下午好，喝杯水休息一下 🌿';
    if (hour >= 18 && hour < 20) return '傍晚了，辛苦一天啦 🌆';
    if (hour >= 20 && hour < 23) return '晚上好，放松一下吧 🌙';
    return '夜深了，早点休息哦 🌛';
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    return Text(
      greetingFor(hour),
      style: style ??
          TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.6),
          ),
    );
  }
}