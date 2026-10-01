import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

abstract class KiraDialogTheme {
  KiraDialogTheme._();

  // Primary (Kira purple)
  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryLight = Color(0xFFA855F7);

  // Container surfaces (deep indigo / pale lavender white)
  static const Color surfaceDark = Color(0xFF1A1B2E);
  static const Color surfaceLight = Color(0xFFF4F3FF);
  static const Color glow = Color(0xFF7B5EA7);

  // Section theme colors (neon cyber palette)
  static const Color tag = Color(0xFFFF6B9D);
  static const Color description = Color(0xFFC77DFF);
  static const Color opening = Color(0xFF4CC9F0);
  static const Color alternate = Color(0xFF06D6A0);
  static const Color dialogue = Color(0xFFFF6B6B);
  static const Color worldbook = Color(0xFFFFB347);
  static const Color regex = Color(0xFFFF9F43);

  // Action colors
  static const Color importColor = Color(0xFF00BCD4);
  static const Color exportColor = Color(0xFF9C27B0);

  // Status colors
  static const Color success = Color(0xFF06D6A0);
  static const Color warning = Color(0xFFFFB347);
  static const Color error = Color(0xFFFF6B6B);
  static const Color info = Color(0xFF4CC9F0);

  // Animation
  static const Curve spring = DesignTokens.curveSpring;
  static const Curve standard = DesignTokens.curveEmphasized;
  static const Curve fade = DesignTokens.curveFade;

  static const Duration durationArrow = Duration(milliseconds: 300);
  static const Duration durationExpand = Duration(milliseconds: 400);
  static const Duration durationFade = Duration(milliseconds: 200);
  static const Duration durationToast = Duration(milliseconds: 200);

  static List<Color> get tagColors => [
        tag,
        description,
        opening,
        alternate,
        dialogue,
        worldbook,
        regex,
      ];

  static Color tagColorFor(String tag) {
    return tagColors[tag.hashCode.abs() % tagColors.length];
  }
}
