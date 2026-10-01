import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import 'kira_dialog_theme.dart';

/// Collapsible card: controlled/uncontrolled dual modes
///
/// - Controlled mode: [isExpanded] is non-null and expansion state is managed
///   externally (mutually exclusive accordion); tapping reports through
///   [onExpansionChanged] and the parent decides the new state.
/// - Uncontrolled mode: [isExpanded] is null and the widget manages its own
///   state.
class KiraAccordionCard extends StatefulWidget {
  final String title;
  final String? preview;
  final IconData? icon;
  final Color? accentColor;
  final bool? isExpanded;
  final bool defaultExpanded;
  final ValueChanged<bool>? onExpansionChanged;
  final Widget? headerActions;
  final Widget? child;
  final bool nested;
  final EdgeInsetsGeometry? bodyPadding;

  const KiraAccordionCard({
    super.key,
    required this.title,
    this.preview,
    this.icon,
    this.accentColor,
    this.isExpanded,
    this.defaultExpanded = false,
    this.onExpansionChanged,
    this.headerActions,
    this.child,
    this.nested = false,
    this.bodyPadding,
  });

  @override
  State<KiraAccordionCard> createState() => _KiraAccordionCardState();
}

class _KiraAccordionCardState extends State<KiraAccordionCard>
    with SingleTickerProviderStateMixin {
  late bool _internalExpanded;
  late AnimationController _arrowCtrl;
  late Animation<double> _arrowAnim;

  bool get _isEffectiveExpanded =>
      widget.isExpanded ?? _internalExpanded;

  @override
  void initState() {
    super.initState();
    _internalExpanded = widget.isExpanded ?? widget.defaultExpanded;
    _arrowCtrl = AnimationController(
      vsync: this,
      duration: KiraDialogTheme.durationArrow,
      value: _isEffectiveExpanded ? 1.0 : 0.0,
    );
    _arrowAnim = CurvedAnimation(
      parent: _arrowCtrl,
      curve: KiraDialogTheme.spring,
    );
  }

  @override
  void didUpdateWidget(covariant KiraAccordionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Controlled mode: sync the arrow animation when external state changes
    if (widget.isExpanded != null &&
        widget.isExpanded != oldWidget.isExpanded) {
      final target = widget.isExpanded! ? 1.0 : 0.0;
      if ((target - _arrowCtrl.value).abs() > 0.01) {
        _arrowCtrl.animateTo(
          target,
          duration: KiraDialogTheme.durationArrow,
          curve: KiraDialogTheme.spring,
        );
      }
    }
  }

  @override
  void dispose() {
    _arrowCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    final newValue = !_isEffectiveExpanded;
    if (widget.isExpanded != null) {
      widget.onExpansionChanged?.call(newValue);
    } else {
      setState(() => _internalExpanded = newValue);
      widget.onExpansionChanged?.call(newValue);
      newValue
          ? _arrowCtrl.forward()
          : _arrowCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.accentColor ?? Theme.of(context).colorScheme.primary;
    final isOpen = _isEffectiveExpanded;
    final secondaryText = Theme.of(context).textTheme.bodyMedium?.color;
    final radius = widget.nested
        ? DesignTokens.radiusMd
        : DesignTokens.radiusCard + 2;

    return RepaintBoundary(
      child: Stack(
      children: [
      AnimatedContainer(
      duration: KiraDialogTheme.durationExpand,
      curve: KiraDialogTheme.standard,
      decoration: BoxDecoration(
        color: isOpen
            ? (widget.nested
                ? accent.withValues(alpha: isDark ? 0.08 : 0.04)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.7)))
            : (widget.nested
                ? Colors.transparent
                : (isDark
                    ? const Color(0xFF252640).withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.7))),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: KiraDialogTheme.glow.withValues(alpha: isOpen ? 0.35 : 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: _toggle,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(radius)),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                widget.nested ? 12 : 16,
                widget.nested ? 10 : 14,
                widget.nested ? 12 : 16,
                widget.nested ? 8 : 10,
              ),
              child: Row(
                children: [
                  if (widget.icon != null) ...[
                    Icon(
                      widget.icon,
                      size: 20,
                      color: accent.withValues(alpha: 0.8),
                    ),
                    SizedBox(width: widget.nested ? 8 : 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title row: title + preview (fade transition)
                        Row(
                          children: [
                            Flexible(
                              child: AnimatedDefaultTextStyle(
                                duration: KiraDialogTheme.durationFade,
                                style: TextStyle(
                                  fontSize: widget.nested
                                      ? DesignTokens.fontSizeSm
                                      : DesignTokens.fontSizeSm + 1,
                                  fontWeight: DesignTokens.weightSemibold,
                                  color: isOpen
                                      ? accent
                                      : (isDark
                                          ? Colors.white
                                              .withValues(alpha: 0.9)
                                          : Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.color),
                                ),
                                child: Text(
                                  widget.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            if (!isOpen && widget.preview != null)
                              Flexible(
                                child: AnimatedOpacity(
                                  duration: KiraDialogTheme.durationFade,
                                  opacity: 1.0,
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.only(left: 8),
                                    child: Text(
                                      widget.preview!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize:
                                            DesignTokens.fontSizeSm,
                                        color: secondaryText
                                            ?.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (widget.headerActions != null) widget.headerActions!,
                  // Arrow (spring rotation of 90 degrees)
                  RotationTransition(
                    turns: _arrowAnim.drive(
                      Tween(begin: 0.0, end: 0.25),
                    ),
                    child: Icon(
                      Icons.expand_more,
                      size: 18,
                      color: isOpen
                          ? accent
                          : (secondaryText?.withValues(alpha: 0.6) ??
                              Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Content area (AnimatedSize collapse/expand)
          AnimatedSize(
            duration: KiraDialogTheme.durationExpand,
            curve: KiraDialogTheme.standard,
            alignment: Alignment.topCenter,
            child: isOpen
                ? Padding(
                    padding: widget.bodyPadding ??
                        EdgeInsets.fromLTRB(
                          widget.nested ? 12 : 16,
                          0,
                          widget.nested ? 12 : 16,
                          widget.nested ? 12 : 16,
                        ),
                    child: widget.child,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
      ),
      // Colored vertical bar on the left while expanded
      if (isOpen && !widget.nested)
        Positioned(
          left: 0,
          top: 8,
          bottom: 8,
          child: Container(
            width: 3,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
      ),
    );
  }
}
