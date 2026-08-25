// lib/presentation/router/radial_reveal_route.dart
/// 圆形炸开转场(阶段五条目2):从点击点为圆心,整页一体被圆形 clip 揭开;
/// 返回时反向收缩回命中点。纯 Flutter SDK(ClipPath+CustomClipper),零三方包。
library;

import 'package:flutter/material.dart';

/// go_router 兼容壳:extra 传 Offset 时由 pageBuilder 返回本 Page
class RadialRevealPage<T> extends Page<T> {
  final Widget child;
  final Offset tapPosition;

  const RadialRevealPage({
    required LocalKey key,
    required this.child,
    required this.tapPosition,
  }) : super(key: key);

  @override
  Route<T> createRoute(BuildContext context) {
    return PageBasedRadialRevealRoute<T>(page: this);
  }
}

class PageBasedRadialRevealRoute<T> extends PageRoute<T> {
  final RadialRevealPage<T> page;

  PageBasedRadialRevealRoute({required this.page})
      : super(settings: page);

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  // 收缩返回时圆外需露出前页
  @override
  bool get opaque => false;

  @override
  Duration get transitionDuration =>
      const Duration(milliseconds: 420); // easeOutCubic 炸开

  @override
  Duration get reverseTransitionDuration =>
      const Duration(milliseconds: 320); // easeInCubic 收缩

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: page.child,
    );
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return AnimatedBuilder(
      animation: curved,
      child: child, // 整页已构建好,动画期间不重 build(性能)
      builder: (context, revealed) {
        return ClipPath(
          clipper: CircleRevealClipper(
            center: page.tapPosition,
            progress: curved.value,
          ),
          child: revealed,
        );
      },
    );
  }
}

/// 圆形揭开裁剪:path = 以命中点为圆心、半径随 t 扩到覆盖最远角的圆
class CircleRevealClipper extends CustomClipper<Path> {
  final Offset center;
  final double progress; // 0→1

  const CircleRevealClipper({required this.center, required this.progress});

  @override
  Path getClip(Size size) {
    if (progress >= 1.0) {
      // 已全开:返回矩形省一次 oval 光栅化
      return Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    }
    // 命中点到四角的最大距离,保证任何点击位置都能盖满全屏
    final maxR = _maxDistanceToCorners(size);
    final radius = maxR * Curves.easeInOut.transform(progress.clamp(0, 1));
    return Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  double _maxDistanceToCorners(Size size) {
    var maxD = 0.0;
    for (final corner in [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ]) {
      final d = (corner - center).distance;
      if (d > maxD) maxD = d;
    }
    return maxD;
  }

  @override
  bool shouldReclip(CircleRevealClipper old) =>
      old.progress != progress || old.center != center;
}

// ponytail: 半径曲线在 clipper 内再叠一层 easeInOut,让炸开中段更饱满;
// 若真机掉帧,把 buildTransitions 换成 FadeTransition+ScaleTransition(0.92→1)
// 一体降级,只动这一处。
