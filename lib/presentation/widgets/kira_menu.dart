import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kirakira/presentation/models/kira_menu_item.dart';
import 'package:kirakira/presentation/theme/app_theme.dart';
import 'package:kirakira/presentation/widgets/kira_dialog.dart';

Future<String?> showKiraMenu({
  required BuildContext context,
  required String title,
  required List<KiraMenuItem> items,
}) {
  final completer = Completer<String?>();

  showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    useRootNavigator: true,
    builder: (ctx) => _KiraMenuDialog(
      title: title,
      items: items,
      onSelected: (id) {
        if (!completer.isCompleted) {
          completer.complete(id);
        }
      },
    ),
  ).then((_) {
    if (!completer.isCompleted) {
      completer.complete(null);
    }
  });

  return completer.future;
}

class _KiraMenuDialog extends StatefulWidget {
  final String title;
  final List<KiraMenuItem> items;
  final ValueChanged<String> onSelected;

  const _KiraMenuDialog({
    required this.title,
    required this.items,
    required this.onSelected,
  });

  @override
  State<_KiraMenuDialog> createState() => _KiraMenuDialogState();
}

class _KiraMenuDialogState extends State<_KiraMenuDialog> {
  final List<KiraMenuItem> _stack = [];

  List<KiraMenuItem> get _currentItems => _stack.isEmpty ? widget.items : _stack.last.children;

  String get _breadcrumb {
    if (_stack.isEmpty) return widget.title;
    final path = _stack.map((e) => e.label).join(' > ');
    return '${widget.title} > $path';
  }

  bool get _isRoot => _stack.isEmpty;

  void _push(KiraMenuItem item) {
    setState(() => _stack.add(item));
  }

  void _pop() {
    if (_stack.isNotEmpty) {
      setState(() => _stack.removeLast());
    } else {
      Navigator.of(context).pop();
    }
  }

  void _select(KiraMenuItem item) {
    if (kDebugMode) {
      debugPrint('[B_PLAN] _select called, id=${item.id}');
    }
    widget.onSelected(item.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _stack.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _stack.isNotEmpty) {
          setState(() => _stack.removeLast());
        }
      },
      child: KiraDialog(
        title: _breadcrumb,
        showBackButton: !_isRoot,
        onBack: _pop,
        child: _buildItemList(_currentItems),
      ),
    );
  }

  Widget _buildItemList(List<KiraMenuItem> items) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: items.map((item) => _buildItem(item)).toList(),
    );
  }

  Widget _buildItem(KiraMenuItem item) {
    final isDisabled = !item.enabled;
    final color = isDisabled
        ? AppTheme.textMuted
        : item.isDestructive
            ? Colors.redAccent
            : AppTheme.textPrimary;

    return InkWell(
      onTap: isDisabled
          ? null
          : () {
              if (item.hasChildren) {
                _push(item);
              } else {
                _select(item);
              }
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            if (item.icon != null) ...[
              Icon(item.icon, size: 20, color: color.withOpacity(isDisabled ? 0.5 : 0.8)),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: isDisabled ? FontWeight.normal : FontWeight.w500,
                ),
              ),
            ),
            if (item.hasChildren)
              Icon(Icons.chevron_right, size: 18, color: color.withOpacity(0.4)),
          ],
        ),
      ),
    );
  }
}
