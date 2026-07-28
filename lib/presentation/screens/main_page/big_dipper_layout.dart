import 'package:flutter/material.dart';

/// 北斗七星的相对坐标（0.0~1.0，相对屏幕宽高）
/// 呼应"北辰星"之名，按北斗勺子形状排列。
/// 第一版坐标，真机看了可微调这里即可。
///
/// 勺子布局：天枢·天璇·天玑·天权（斗身四星）+ 玉衡·开阳·摇光（斗柄三星）
class BigDipperLayout {
  static const List<Offset> starPositions = [
    Offset(0.22, 0.30), // 0 天枢 (勺口上)
    Offset(0.20, 0.46), // 1 天璇 (勺口下)
    Offset(0.34, 0.52), // 2 天玑 (勺底)
    Offset(0.44, 0.40), // 3 天权 (勺柄连接)
    Offset(0.58, 0.44), // 4 玉衡 (柄1)
    Offset(0.70, 0.56), // 5 开阳 (柄2)
    Offset(0.82, 0.68), // 6 摇光 (柄尾)
  ];

  /// 中央太阳位置
  static const Offset sunPosition = Offset(0.5, 0.5);

  /// 七星名称（斗宿古名，可选显示）
  static const List<String> starNames = [
    '天枢', '天璇', '天玑', '天权', '玉衡', '开阳', '摇光',
  ];
}