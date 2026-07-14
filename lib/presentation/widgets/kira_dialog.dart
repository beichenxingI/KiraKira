import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/app_theme.dart';

class KiraDialog extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback? onBack;
  final VoidCallback? onClose;
  final bool showBackButton;

  const KiraDialog({
    super.key,
    required this.title,
    required this.child,
    this.onBack,
    this.onClose,
    this.showBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 560),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTitleBar(context),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 8),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.darkDivider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          if (showBackButton)
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: onBack ?? () => Navigator.of(context).pop(),
              tooltip: '返回',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            )
          else
            const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: showBackButton ? 0 : 8),
              child: Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: AppTheme.textMuted),
            onPressed: onClose ?? () => Navigator.of(context).pop(),
            tooltip: '关闭',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}
