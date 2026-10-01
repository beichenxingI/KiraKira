import 'package:flutter/material.dart';

/// Relative coordinates of the Big Dipper stars (0.0-1.0, relative to screen size).
/// Arranged in the shape of the dipper, echoing the "North Star" name.
/// First-pass coordinates; fine-tune here after checking on a real device.
///
/// Dipper layout: Tianshu, Tianxuan, Tianji, Tianquan (bowl) + Yuheng, Kaiyang, Yaoguang (handle)
class BigDipperLayout {
  static const List<Offset> starPositions = [
    Offset(0.22, 0.30), // 0 Tianshu (top of the bowl rim)
    Offset(0.20, 0.46), // 1 Tianxuan (bottom of the bowl rim)
    Offset(0.34, 0.52), // 2 Tianji (bowl base)
    Offset(0.44, 0.40), // 3 Tianquan (bowl-handle joint)
    Offset(0.58, 0.44), // 4 Yuheng (handle 1)
    Offset(0.70, 0.56), // 5 Kaiyang (handle 2)
    Offset(0.82, 0.68), // 6 Yaoguang (handle tip)
  ];

  /// Position of the central sun
  static const Offset sunPosition = Offset(0.5, 0.5);

  /// Star names (traditional names, optionally displayed)
  static const List<String> starNames = [
    '天枢', '天璇', '天玑', '天权', '玉衡', '开阳', '摇光',
  ];
}