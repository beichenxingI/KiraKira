import 'dart:io';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kirakira/core/logger/logger.dart';
import 'package:kirakira/core/logger/log_entry.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class LogViewScreen extends StatefulWidget {
  const LogViewScreen({super.key});

  @override
  State<LogViewScreen> createState() => _LogViewScreenState();
}

class _LogViewScreenState extends State<LogViewScreen> {
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
    if (mounted) setState(() { _entries = entries; _loading = false; });
  }

  Future<void> _clear() async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('清空日志'),
        content: const Text('确认清空所有日志？'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('取消')),
          CupertinoDialogAction(isDestructiveAction: true, onPressed: () => Navigator.pop(dialogCtx, true), child: const Text('清空')),
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('日志文件不存在')));
        return;
      }
      await SharePlus.instance.share(
        ShareParams(files: [XFile(src.path)]),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败: $e')));
    }
  }

  Color _color(String level) {
    switch (level) {
      case 'ERROR': return DesignTokens.statusError;
      case 'WARNING': return DesignTokens.statusWarning;
      case 'INFO': return DesignTokens.accent;
      default: return Theme.of(context).textTheme.bodySmall?.color ?? DesignTokens.darkTextTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text('日志查看器', style: theme.textTheme.displayLarge),
            actions: [
              IconButton(icon: const Icon(Icons.share), tooltip: '导出', onPressed: _export),
              IconButton(icon: const Icon(Icons.delete_outline), tooltip: '清空', onPressed: _clear),
              IconButton(icon: const Icon(Icons.refresh), tooltip: '刷新', onPressed: _load),
            ],
          ),
          if (_loading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_entries.isEmpty)
            SliverFillRemaining(
              child: Center(child: Text('暂无日志', style: theme.textTheme.bodyMedium)),
            )
          else
            SliverList.builder(
              itemCount: _entries.length,
              itemBuilder: (ctx, i) {
                final e = _entries[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: DesignTokens.spaceXs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: _color(e.level).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(DesignTokens.radiusXs)),
                            child: Text(e.level, style: TextStyle(color: _color(e.level), fontSize: DesignTokens.fontSizeCaption, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Text(e.tag, style: theme.textTheme.bodyMedium?.copyWith(fontSize: DesignTokens.fontSizeCaption)),
                          const Spacer(),
                          Text(_fmt(e.timestamp), style: theme.textTheme.bodySmall?.copyWith(fontSize: DesignTokens.fontSizeCaption)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(e.message, style: theme.textTheme.bodyLarge?.copyWith(fontSize: DesignTokens.fontSizeSm)),
                      const Divider(height: 12),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  String _fmt(DateTime t) => '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}:${t.second.toString().padLeft(2,'0')}';
}
