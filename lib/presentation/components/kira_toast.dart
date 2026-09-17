import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import 'kira_dialog_theme.dart';

enum KiraToastType { success, warning, error, info }

/// 灵动岛 Toast：屏幕顶部居中滑入，自动消失，多条自动替换
class KiraToast {
  KiraToast._();

  static OverlayEntry? _current;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    KiraToastType type = KiraToastType.info,
  }) {
    _dismiss();
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (_) => _KiraToastWidget(
        message: message,
        type: type,
        onDismiss: _dismiss,
      ),
    );
    _current = entry;
    overlay.insert(entry);

    final duration = switch (type) {
      KiraToastType.success || KiraToastType.info =>
        const Duration(seconds: 2),
      KiraToastType.warning => const Duration(seconds: 3),
      KiraToastType.error => const Duration(seconds: 4),
    };
    _timer = Timer(duration, _dismiss);
  }

  static void _dismiss() {
    _timer?.cancel();
    _timer = null;
    _current?.remove();
    _current = null;
  }
}

class _KiraToastWidget extends StatefulWidget {
  final String message;
  final KiraToastType type;
  final VoidCallback onDismiss;

  const _KiraToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_KiraToastWidget> createState() => _KiraToastWidgetState();
}

class _KiraToastWidgetState extends State<_KiraToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: KiraDialogTheme.durationToast,
    );
    _slideAnim = Tween(begin: const Offset(0, -1), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: KiraDialogTheme.spring),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _iconColor => switch (widget.type) {
        KiraToastType.success => KiraDialogTheme.success,
        KiraToastType.warning => KiraDialogTheme.warning,
        KiraToastType.error => KiraDialogTheme.error,
        KiraToastType.info => KiraDialogTheme.info,
      };

  IconData get _icon => switch (widget.type) {
        KiraToastType.success => Icons.check_circle,
        KiraToastType.warning => Icons.warning_amber_rounded,
        KiraToastType.error => Icons.error,
        KiraToastType.info => Icons.info,
      };

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topPadding + 12,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_icon, size: 20, color: _iconColor),
                    const SizedBox(width: DesignTokens.spaceSm),
                    Container(
                      width: 1,
                      height: 16,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    const SizedBox(width: DesignTokens.spaceSm),
                    Flexible(
                      child: Material(
                        color: Colors.transparent,
                        child: Text(
                          widget.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: DesignTokens.fontSizeSm,
                            fontWeight: DesignTokens.weightMedium,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
