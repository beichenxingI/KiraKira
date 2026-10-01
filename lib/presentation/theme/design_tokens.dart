// lib/presentation/theme/design_tokens.dart
/// KiraKira design token single source of truth.
///
/// All hardcoded colors, radii, spacing, fonts, animations and shadows are
/// referenced from this file. Never use literals in business code; always
/// reference [DesignTokens].
///
/// Palette: neutral dark grays with a coral-pink accent.
/// Dark theme uses three-level gray hierarchy, white text with opacity
/// layering, and zero shadows.
/// Type scale follows the iOS Type Scale (HIG Typography).
library;

import 'package:flutter/material.dart';

abstract class DesignTokens {
  DesignTokens._();

  // Corner radius system · measured iOS ranges
  static const double radiusXs = 6; // small tags, input internals
  static const double radiusSm = 10; // compact buttons, ListTile
  static const double radiusMd = 12; // standard buttons, input baseline
  static const double radiusLg = 16; // large sheet inset
  static const double radiusXl = 24; // large cards, info cards
  static const double radiusFull = 30; // capsules, bottom bar, FAB

  // Semantic aliases (preferred)
  static const double radiusCard = 12; // standalone card (iOS convention 10-12)
  static const double radiusGroupedCard = 10; // inset-grouped card (primary)
  static const double radiusInput = radiusMd; // 12 - input
  static const double radiusButton = radiusMd; // 12 - button
  static const double radiusDialog = 14; // AlertDialog (iOS alert ~14)
  static const double radiusBottomSheet = 14; // bottom sheet top corners (iOS 13+ 10-14)
  static const double radiusChip = radiusSm; // 8 - label/chip

  // Spacing system (8pt base grid)
  static const double spaceZero = 0;
  static const double spaceXxs = 2; // extra compact
  static const double spaceXs = 4; // icon gaps, fine padding tweaks
  static const double spaceSm = 8; // base unit, compact layout
  static const double spaceMd = 16; // standard card padding, component gaps
  static const double spaceLg = 24; // page section gaps (inset-grouped)
  static const double spaceXl = 32; // large section gaps
  static const double space2xl = 48; // page-level whitespace
  static const double space3xl = 64; // extra large whitespace

  // Semantic EdgeInsets presets
  static const EdgeInsets paddingCard = EdgeInsets.all(spaceMd); // 16
  static const EdgeInsets paddingCardLg = EdgeInsets.all(spaceLg); // 24
  static const EdgeInsets paddingScreen =
      EdgeInsets.symmetric(horizontal: spaceMd); // 16
  static const EdgeInsets paddingScreenLg =
      EdgeInsets.symmetric(horizontal: spaceLg); // 24
  static const EdgeInsets paddingSection =
      EdgeInsets.only(top: spaceLg, bottom: spaceSm); // 24/8
  static const EdgeInsets marginCard =
      EdgeInsets.symmetric(horizontal: spaceMd, vertical: spaceXs); // 16/4
  static const EdgeInsets marginCardLg =
      EdgeInsets.symmetric(horizontal: spaceMd, vertical: spaceSm); // 16/8

  // Type scale · aligned with the iOS Type Scale (HIG Typography)
  static const double fontSizeCaption = 11; // Caption 2
  static const double fontSizeXs = 12; // Caption 1
  static const double fontSizeSm = 13; // Footnote (list subrow/description)
  static const double fontSizeBodyMedium = 15; // Subheadline
  static const double fontSizeHeadline = 17; // Headline 17/Semibold (list row title, pair with weightSemibold)
  static const double fontSizeBodyLarge = 17; // Body 17 (iOS default body)
  static const double fontSizeXl = 20; // Title 3
  static const double fontSize2xl = 22; // Title 2
  static const double fontSize3xl = 28; // Title 1
  static const double fontSizeDisplayLarge = 34; // Large Title (SliverAppBar.large)

  // Font weights
  static const FontWeight weightRegular = FontWeight.w400;
  static const FontWeight weightMedium = FontWeight.w500;
  static const FontWeight weightSemibold = FontWeight.w600;
  static const FontWeight weightBold = FontWeight.w700;

  // Animation system · iOS feel
  // Curves
  static const Curve curveStandard =
      Curves.easeOutCubic; // standard entry/transition (natural deceleration)
  static const Curve curveEmphasized =
      Curves.easeInOutCubic; // emphasized transition (smooth both ways)
  static const Curve curveDecelerate =
      Curves.fastEaseInToSlowEaseOut; // decelerating entry
  static const Curve curveSpring =
      Curves.easeOutBack; // gentle rebound, iOS character; elasticOut is banned
  static const Curve curveSlide =
      Curves.easeOut; // page slide fade (iOS transition)
  static const Curve curveFade =
      Curves.easeOut; // fading transition
  static const Curve curveBackEase =
      Cubic(0.34, 1.56, 0.64, 1.0); // springy rebound (switch toggles)

  // Durations (ms)
  static const int durationXs = 100; // micro feedback
  static const int durationSm = 200; // fast transition
  static const int durationMd = 300; // standard
  static const int durationLg = 400; // emphasized
  static const int durationXl = 500; // complex animation (special cases only)
  static const int durationDialog = 250; // dialogs

  static const Duration durationQuick =
      Duration(milliseconds: 200); // fast interaction feedback
  static const Duration durationSmooth =
      Duration(milliseconds: 300); // smooth transition

  // Shadow system
  // Dark mode is always shadow-free (hierarchy comes from the three-level
  // gray palette + separators); shadowLevel1/2/3 are permitted only for
  // light-mode modal/sheet and are banned on all cards.
  static const List<BoxShadow> shadowSoft = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> shadowAccent = [
    BoxShadow(
      color: Color(0x80FFA58F),
      blurRadius: 15,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> shadowAccentLight = [
    BoxShadow(
      color: Color(0x47FFA58F),
      blurRadius: 22,
      offset: Offset(0, 12),
    ),
  ];

  static List<BoxShadow> get shadowLevel1 => [
        // light mode only, subtle lift
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get shadowLevel2 => [
        // light mode modal/sheet only
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.10),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 32,
          spreadRadius: -8,
          offset: const Offset(0, 12),
        ),
      ];

  static List<BoxShadow> get shadowLevel3 => [
        // light mode large-modal edge cases only; banned in dark mode
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.16),
          blurRadius: 48,
          spreadRadius: -12,
          offset: const Offset(0, 16),
        ),
      ];

  // Glass-specific shadow (dark mode) · keep until the bottom bar reference
  // lands, then evaluate for removal
  @Deprecated('A 阶段过渡保留:B-T2 毛玻璃底栏落地后评估删除;深色模式禁止新引用')
  static List<BoxShadow> get shadowGlass => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.24),
          blurRadius: 32,
          spreadRadius: -8,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 12,
          spreadRadius: -4,
          offset: const Offset(0, 4),
        ),
      ];

  // Color system (iOS skeleton + brand skin)
  // Based on the iOS prototype with 2-3% blue-violet adjustment; dark text is
  // pure white with opacity layering (solid grays are not allowed).
  // Dark theme - fully neutral gray, no blue-violet cast
  static const Color darkBackground = Color(0xFF0A0A0A); // near-black
  static const Color darkSurface = Color(0xFF1C1C1C); // inset-grouped card/nav bar base
  static const Color darkCard = Color(0xFF1C1C1C); // same as surface
  static const Color darkSeparator = Color(0xFF2C2C2C); // separator gray
  static const Color darkSeparatorOpaque = Color(0xFF38383A); // opaque separator (rarely used)

  // Light theme
  static const Color lightBackground = Color(0xFFF7F8FA); // systemGroupedBackground
  static const Color lightSurface = Color(0xFFFFFFFF); // secondarySystemGroupedBackground
  static const Color lightCard = Color(0xFFFFFFFF); // grouped card = pure white, hierarchy from gray background
  static const Color lightFillTertiary = Color(0x1F767680); // tertiarySystemFill (input/control fill)
  static const Color lightSeparator = Color(0x493C3C43); // separator

  // Dark text - high contrast neutral white
  static const Color darkTextPrimary = Color(0xFFF0F0F0); // label
  static const Color darkTextSecondary = Color(0xFF8C8C8C); // secondaryLabel
  static const Color darkTextTertiary = Color(0x4DFFFFFF); // tertiaryLabel white 30%
  static const Color darkTextDisabled = Color(0x29FFFFFF); // quaternaryLabel white 16%

  // Light text · black + opacity
  static const Color lightTextPrimary = Color(0xFF4A4A4A); // label
  static const Color lightTextSecondary = Color(0xFF8E8E93); // secondaryLabel
  static const Color lightTextTertiary = Color(0x4D3C3C43); // tertiaryLabel black 30%
  static const Color lightTextDisabled = Color(0x2E3C3C43); // quaternaryLabel black 18%

  // Brand colors
  static const Color primary = Color(0xFFFFA58F); // coral pink · sole interactive accent
  static const Color primaryLight = Color(0xFFFFC4B0); // secondary tint
  static const Color secondary = Color(0xFF6C8FF0); // charts second series / gradient support
  static const Color accent = Color(0xFF56D4C8); // teal · positive state / data highlight only

  // Status colors (iOS system green/orange/red; base name = dark value,
  // *Light = light-mode variant)
  static const Color statusSuccess = Color(0xFF30D158); // iOS systemGreen dark
  static const Color statusSuccessLight = Color(0xFF34C759); // iOS systemGreen light
  static const Color statusWarning = Color(0xFFFF9F0A); // iOS systemOrange dark
  static const Color statusWarningLight = Color(0xFFFF9500); // iOS systemOrange light
  static const Color statusError = Color(0xFFFF453A); // iOS systemRed dark
  static const Color statusErrorLight = Color(0xFFFF3B30); // iOS systemRed light

  // Chat bubbles (tokens assigned here; chat rendering layer must not change them)
  static const Color userBubble = Color(0xFF5A58D4);
  static const Color assistantBubble = darkSurface; // #1C1C1C
  static const Color systemBubble = darkCard; // #1C1C1C

  // Breakpoints (responsive)
  static const double breakpointSm = 600; // phone
  static const double breakpointMd = 900; // tablet
  static const double breakpointLg = 1200; // desktop
  static const double breakpointXl = 1800; // large screen
}
