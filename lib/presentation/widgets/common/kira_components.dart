import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/widgets/common/kira_grouped_tile.dart';
import 'package:kirakira/presentation/widgets/common/kira_pressable.dart';

/// KiraKira shared design widgets, iOS-style Constitution v2
/// Zero shadows in dark mode, 0.5 separator hairlines, Cupertino controls, press = scale + darken.
/// Everything reads Theme and adapts automatically to dark/light.

/// Solid card: radius 12, zero shadows, a 0.5 separator hairline only in light mode.
class KiraCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const KiraCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardRadius = BorderRadius.circular(DesignTokens.radiusCard);

    return Container(
      margin: margin ?? DesignTokens.marginCard,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: cardRadius,
        // Constitution v2: no border at all in dark mode; 0.5 separator hairline in light mode
        border: isDark
            ? null
            : Border.all(color: theme.dividerColor, width: 0.5),
      ),
      // clipBehavior omitted (saves a saveLayer); KiraPressable already clips on demand
      child: onTap != null
          ? KiraPressable(
              onTap: onTap,
              borderRadius: cardRadius,
              child: Padding(
                padding: padding ?? DesignTokens.paddingCard,
                child: child,
              ),
            )
          : Padding(
              padding: padding ?? DesignTokens.paddingCard,
              child: child,
            ),
    );
  }
}

/// Inset-grouped section (A-T4b): one card per group.
/// Group header = 13pt secondary-color small text; the children stack vertically inside one radius-10 card,
/// with a 0.5px separator (indent 16) inserted between rows automatically.
///
/// Use [KiraSection.plain] (no separators) when the group must stay as one block, e.g. forms and slider groups.
class KiraSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final IconData? icon;
  /// An action can hang at the top-right of the group header (e.g. an "import preset" icon)
  final Widget? headerTrailing;
  final bool _plain;

  const KiraSection({
    super.key,
    required this.title,
    required this.children,
    this.icon,
    this.headerTrailing,
  }) : _plain = false;

  /// plain form: the group is a single block (slider group/form), so no separators are inserted
  KiraSection.plain({
    super.key,
    required this.title,
    required Widget child,
    this.icon,
    this.headerTrailing,
  })  : children = [child],
        _plain = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final labelColor = theme.textTheme.bodyMedium?.color;

    final cardRadius = BorderRadius.circular(DesignTokens.radiusMd);

    // Group items: plain form places the child directly; default form inserts a 0.5 separator between rows
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (!_plain && i > 0) {
        items.add(Divider(
          height: 0.5,
          thickness: 0.5,
          indent: DesignTokens.spaceMd,
          color: theme.dividerColor,
        ));
      }
      items.add(children[i]);
    }

    return Padding(
      padding: EdgeInsets.only(
          top: title.isEmpty ? DesignTokens.spaceSm : DesignTokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group header: 13pt, secondary color, w600, letterSpacing 0.5 (left offset = margin 16 + 12)
          // Empty title = pinned high-frequency group with no header (C-T4)
          if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                left: DesignTokens.spaceMd + 12,
                right: DesignTokens.spaceMd,
                bottom: DesignTokens.spaceSm,
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 14, color: labelColor),
                    const SizedBox(width: DesignTokens.spaceXs),
                  ],
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        fontSize: DesignTokens.fontSizeSm,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: labelColor,
                      ),
                    ),
                  ),
                  if (headerTrailing != null) headerTrailing!,
                ],
              ),
            ),
          // One card per group
          Container(
            margin: DesignTokens.paddingScreen,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: theme.cardColor, // darkSurface / lightSurface (white)
              borderRadius: cardRadius,
              border: isDark
                  ? null
                  : Border.all(color: theme.dividerColor, width: 0.5),
              boxShadow: isDark ? null : DesignTokens.shadowSoft,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: items,
            ),
          ),
        ],
      ),
    );
  }
}

/// Subtly gradient card: only allowed in home-page welcome/marketing slots (gradient cards are banned in the settings family).
/// Radius radiusCard (12), zero shadows; dark mode keeps only a single highlight edge at the top.
class KiraGradientCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;

  const KiraGradientCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = DesignTokens.radiusCard,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final base = theme.cardColor;
    // Subtle gradient: slightly lighter at the top-left "lit face", slightly darker at the bottom-right "shaded face", with a very small range
    final lighter = Color.lerp(base, Colors.white, isDark ? 0.06 : 0.5)!;
    final darker = Color.lerp(base, Colors.black, isDark ? 0.12 : 0.03)!;
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              padding: padding ?? DesignTokens.paddingCard,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [lighter, base, darker],
                  stops: const [0.0, 0.5, 1.0],
                ),
                border: isDark
                    ? null
                    : Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 0.5,
                      ),
              ),
              child: child,
            ),
            // Dark mode keeps only the top highlight edge (Constitution A-T4e)
            if (isDark)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 0.8,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// List item: icon + title + subtitle + trailing control.
/// Icon color is no longer forced to the primary color; primary is reserved for tappable primary-action buttons (A-T4d).
/// Prefer KiraGroupedTile inside grouped cards.
class KiraListTile extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const KiraListTile({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: icon != null
          ? Icon(icon, color: theme.textTheme.bodySmall?.color)
          : null,
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing,
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
      ),
    );
  }
}

class KiraSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const KiraSwitch({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isEnabled = onChanged != null;

    return GestureDetector(
      onTap: isEnabled ? () => onChanged!(!value) : null,
      child: AnimatedContainer(
        duration: DesignTokens.durationQuick,
        curve: Curves.ease,
        width: 52,
        height: 32,
        decoration: BoxDecoration(
          color: value
              ? (isEnabled
                  ? DesignTokens.primary
                  : DesignTokens.primary.withValues(alpha: 0.5))
              : const Color(0xFFE5E5EA),
          borderRadius: BorderRadius.circular(999),
          boxShadow: value && isEnabled
              ? [
                  BoxShadow(
                    color: DesignTokens.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: AnimatedAlign(
          duration: DesignTokens.durationSmooth,
          curve: DesignTokens.curveBackEase,
          alignment:
              value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class KiraSwitchTile extends StatelessWidget {
  final IconData? icon;
  final Color? iconBg;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const KiraSwitchTile({
    super.key,
    this.icon,
    this.iconBg,
    this.iconColor,
    required this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return KiraGroupedTile(
      icon: icon,
      iconBg: iconBg,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      trailing: KiraSwitch(value: value, onChanged: onChanged),
      onTap: onChanged == null ? null : () => onChanged!(!value),
    );
  }
}
