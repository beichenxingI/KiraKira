// lib/presentation/dialogs/log_viewer_dialog.dart
/// 日志查看器浮窗(极客Core迁移 P1)
/// 内容完整迁自 log_view_screen.dart:导出/清空/刷新 + 日志列表
/// (级别徽标/标签/时间/内容,500条上限)。
library;

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kirakira/core/logger/log_entry.dart';
import 'package:kirakira/core/logger/logger.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'core_dialog.dart';

Future<void> showLogViewerDialog(BuildContext context) {
  return showCoreDialog(
    context,
    builder: (_) => const _LogViewerDialog(),
  );
}

class _LogViewerDialog extends StatefulWidget {
  const _LogViewerDialog();

  @override
  State<_LogViewerDialog> createState() => _LogViewerDialogState();
}

class _LogViewerDialogState extends State<_LogViewerDialog> {
  List<LogEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await KiraLogger().read(limit: 500);
    if (mounted) {
      setState(() {
        _entries = entries;
        _loading = false;
      });
    }
  }

  Future<void> _clear() async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('清空日志'),
        content: const Text('确认清空所有日志？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await KiraLogger().clear();
      _load();
    }
  }

  Future<void> _export() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final src = File('${dir.path}/logs/kirakira.log');
      if (!await src.exists()) {
        if (mounted) coreToast(context, '日志文件不存在');
        return;
      }
      await SharePlus.instance.share(
        ShareParams(files: [XFile(src.path)]),
      );
    } catch (e) {
      if (mounted) coreToast(context, '导出失败: $e');
    }
  }

  Color _color(String level, CoreDialogPalette palette) {
    switch (level) {
      case 'ERROR':
        return DesignTokens.statusError;
      case 'WARNING':
        return DesignTokens.statusWarning;
      case 'INFO':
        return DesignTokens.accent;
      default:
        return palette.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CoreDialogPalette(isDark: isDark);

    return CoreDialogShell(
      title: '日志查看器',
      icon: CupertinoIcons.doc_text,
      maxWidth: 600,
      bodyPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minSize: 0,
            onPressed: _export,
            child: Icon(Icons.share,
                size: 20, color: palette.textSecondary),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minSize: 0,
            onPressed: _clear,
            child: Icon(CupertinoIcons.delete,
                size: 20, color: DesignTokens.statusError),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minSize: 0,
            onPressed: _load,
            child: Icon(Icons.refresh,
                size: 20, color: palette.textSecondary),
          ),
        ],
      ),
      body: _loading
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          : _entries.isEmpty
              ? SizedBox(
                  height: 200,
                  child: Center(
                    child: Text('暂无日志',
                        style:
                            TextStyle(fontSize: 14, color: palette.textSecondary)),
                  ),
                )
              : Column(
                  children: _entries.map((e) {
                    final levelColor = _color(e.level, palette);
                    return Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: levelColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(
                                      DesignTokens.radiusXs),
                                ),
                                child: Text(
                                  e.level,
                                  style: TextStyle(
                                    color: levelColor,
                                    fontSize: DesignTokens.fontSizeCaption,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  e.tag,
                                  style: TextStyle(
                                    fontSize: DesignTokens.fontSizeCaption,
                                    color: palette.textPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                _fmt(e.timestamp),
                                style: TextStyle(
                                  fontSize: DesignTokens.fontSizeCaption,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            e.message,
                            style: TextStyle(
                              fontSize: DesignTokens.fontSizeSm,
                              color: palette.textPrimary,
                            ),
                          ),
                          Divider(
                              height: 12,
                              color: palette.divider.withValues(alpha: 0.5)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
    );
  }

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
}
