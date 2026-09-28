import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/models/world_info.dart';
import '../components/kira_dialog_theme.dart';
import '../components/kira_dialog_widgets.dart';
import '../components/kira_toast.dart';
import '../providers/world_info_providers.dart';
import '../theme/design_tokens.dart';
import '../utils/export_delivery.dart';
import 'worldbook_entry_edit_dialog.dart';

/// 世界书完整编辑浮窗（一个角色对应一本世界书，直接编辑）
///
/// 三段布局：header固定（名称+统计+关闭）+ body可滚动（工具栏+条目列表）+ footer固定（导入导出+新增）
Future<void> showWorldBookEditorDialog(
  BuildContext context,
  WidgetRef ref, {
  required String characterId,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) =>
        _WorldBookEditorDialog(characterId: characterId),
  );
}

class _WorldBookEditorDialog extends ConsumerStatefulWidget {
  final String characterId;
  const _WorldBookEditorDialog({required this.characterId});
  @override
  ConsumerState<_WorldBookEditorDialog> createState() =>
      _WorldBookEditorDialogState();
}

class _WorldBookEditorDialogState
    extends ConsumerState<_WorldBookEditorDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  String _search = '';
  String _filter = 'all'; // all | enabled | constant | disabled
  bool _nameDirty = false;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<WorldInfoEntry> _filterEntries(List<WorldInfoEntry> entries) {
    var result = entries;
    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      result = result.where((e) =>
          e.keys.any((k) => k.toLowerCase().contains(q)) ||
          e.content.toLowerCase().contains(q) ||
          e.comment.toLowerCase().contains(q)).toList();
    }
    switch (_filter) {
      case 'enabled':
        result = result.where((e) => e.enabled).toList();
      case 'disabled':
        result = result.where((e) => !e.enabled).toList();
      case 'constant':
        result = result.where((e) => e.constant).toList();
    }
    // 统一按 insertionOrder 排序（创建时间排序功能暂未实现，保持现有行为）
    result = [...result]..sort((a, b) => a.insertionOrder.compareTo(b.insertionOrder));
    return result;
  }

  Future<void> _toggleEntry(WorldInfoEntry entry) async {
    final notifier = ref.read(worldInfoNotifierProvider.notifier);
    await notifier.updateEntry(entry.copyWith(enabled: !entry.enabled));
    ref.invalidate(characterWorldInfosProvider);
  }

  Future<void> _deleteEntry(WorldInfoEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      useRootNavigator: true,
      builder: (ctx) => _EditorConfirm(
        title: '删除条目',
        message: '确定要删除「${entry.keys.isNotEmpty ? entry.keys.join(', ') : entry.comment}」吗？',
        confirmText: '删除',
      ),
    );
    if (confirm != true) return;
    await ref.read(worldInfoNotifierProvider.notifier).deleteEntry(entry.id);
    ref.invalidate(characterWorldInfosProvider);
    if (mounted) {
      KiraToast.show(context, '条目已删除', type: KiraToastType.success);
    }
  }

  Future<void> _saveBookName(String name) async {
    final books = ref.read(characterWorldInfosProvider(widget.characterId)).valueOrNull ?? [];
    if (books.isEmpty || !_nameDirty) return;
    final notifier = ref.read(worldInfoNotifierProvider.notifier);
    await notifier.updateWorldInfo(books.first.copyWith(name: name));
    ref.invalidate(characterWorldInfosProvider);
    if (mounted) {
      KiraToast.show(context, '世界书名称已保存', type: KiraToastType.success);
    }
  }

  // ── 导入/导出 ──

  Future<void> _importWorldBook() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return;
    final content = await File(result.files.first.path!).readAsString();
    final data = jsonDecode(content);
    final books =
        ref.read(characterWorldInfosProvider(widget.characterId)).valueOrNull ??
            [];
    if (books.isEmpty) {
      KiraToast.show(context, '请先保存角色以创建世界书',
          type: KiraToastType.warning);
      return;
    }
    final book = books.first;
    final notifier = ref.read(worldInfoNotifierProvider.notifier);
    if (data is List) {
      for (final item in data) {
        final m = item as Map<String, dynamic>;
        await notifier.addEntry(
          worldInfoId: book.id,
          keys: (m['keys'] as List<dynamic>?)?.cast<String>() ?? [],
          content: m['content'] as String? ?? '',
          comment: m['comment'] as String?,
        );
      }
    } else if (data is Map && data['entries'] is List) {
      for (final item in data['entries'] as List) {
        final m = item as Map<String, dynamic>;
        await notifier.addEntry(
          worldInfoId: book.id,
          keys: (m['keys'] as List<dynamic>?)?.cast<String>() ?? [],
          content: m['content'] as String? ?? '',
          comment: m['comment'] as String?,
        );
      }
    }
    ref.invalidate(characterWorldInfosProvider);
    if (mounted) {
      KiraToast.show(context, '世界书导入成功', type: KiraToastType.success);
    }
  }

  Future<void> _exportWorldBook() async {
    final books =
        ref.read(characterWorldInfosProvider(widget.characterId)).valueOrNull ??
            [];
    final entries = <WorldInfoEntry>[
      for (final w in books) ...w.entries
    ];
    if (entries.isEmpty) {
      KiraToast.show(context, '暂无条目可导出', type: KiraToastType.warning);
      return;
    }
    final json = const JsonEncoder.withIndent('  ')
        .convert(entries.map((e) => e.toJson()).toList());
    final date = DateTime.now().toIso8601String().split('T')[0];
    final fileName = 'worldbook_$date.json';
    // [问题1] 统一导出交付:分享 / 保存到文件
    await deliverExportFile(
      context: context,
      fileName: fileName,
      bytes: utf8.encode(json),
      subject: fileName,
      ext: 'json',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final titleColor = Theme.of(context).textTheme.bodyLarge?.color;
    final labelColor = Theme.of(context).textTheme.bodyMedium?.color;
    final worldInfos =
        ref.watch(characterWorldInfosProvider(widget.characterId));

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: screenW - 32 < 720 ? screenW - 32 : 720,
          height: screenH * 0.92,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1B2E) : const Color(0xFFF4F3FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF7B5EA7).withValues(alpha: 0.25),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // ── Header ──
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: const Color(0xFF7B5EA7).withValues(alpha: 0.15),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          worldInfos.when(
                            data: (list) => TextFormField(
                              initialValue: list.isNotEmpty ? list.first.name : '世界书',
                              enabled: list.isNotEmpty,
                              onChanged: (_) => _nameDirty = true,
                              onFieldSubmitted: _saveBookName,
                              cursorColor: KiraDialogTheme.primary,
                              style: TextStyle(
                                  fontSize: DesignTokens.fontSizeHeadline,
                                  fontWeight: DesignTokens.weightBold,
                                  color: titleColor),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            loading: () => Text('世界书',
                                style: TextStyle(
                                    fontSize: DesignTokens.fontSizeHeadline,
                                    fontWeight: DesignTokens.weightBold,
                                    color: titleColor)),
                            error: (_, __) => Text('世界书',
                                style: TextStyle(
                                    fontSize: DesignTokens.fontSizeHeadline,
                                    color: titleColor)),
                          ),
                          const SizedBox(height: 2),
                          worldInfos.when(
                            data: (list) {
                              final entries = <WorldInfoEntry>[
                                for (final w in list) ...w.entries
                              ];
                              final enabledCount =
                                  entries.where((e) => e.enabled).length;
                              return Text(
                                  '${entries.length} 条 · $enabledCount 条启用',
                                  style: TextStyle(
                                      fontSize: DesignTokens.fontSizeXs,
                                      color: labelColor?.withValues(alpha: 0.6)));
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close,
                          size: 20, color: labelColor?.withValues(alpha: 0.6)),
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: true).pop(),
                    ),
                  ],
                ),
              ),
              // ── Body ──
              Expanded(
                child: Column(
                  children: [
                    // 工具栏
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        children: [
                          TextField(
                            controller: _searchCtrl,
                            onChanged: (value) {
                              _searchDebounce?.cancel();
                              _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                                if (mounted) {
                                  setState(() => _search = value);
                                }
                              });
                            },
                            cursorColor: KiraDialogTheme.primary,
                            style: TextStyle(
                                fontSize: DesignTokens.fontSizeSm,
                                color: titleColor),
                            decoration: InputDecoration(
                              hintText: '搜索关键词 / 内容 / 备注...',
                              prefixIcon: Icon(Icons.search,
                                  size: 18,
                                  color: labelColor?.withValues(alpha: 0.5)),
                              isDense: true,
                              filled: true,
                              fillColor: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.03),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                    DesignTokens.radiusMd),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _FilterChip(
                                label: '全部',
                                selected: _filter == 'all',
                                onTap: () => setState(() => _filter = 'all'),
                              ),
                              const SizedBox(width: 6),
                              _FilterChip(
                                label: '已启用',
                                selected: _filter == 'enabled',
                                onTap: () =>
                                    setState(() => _filter = 'enabled'),
                              ),
                              const SizedBox(width: 6),
                              _FilterChip(
                                label: '常量',
                                selected: _filter == 'constant',
                                onTap: () =>
                                    setState(() => _filter = 'constant'),
                              ),
                              const SizedBox(width: 6),
                              _FilterChip(
                                label: '已禁用',
                                selected: _filter == 'disabled',
                                onTap: () =>
                                    setState(() => _filter = 'disabled'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 条目列表
                    Expanded(
                      child: worldInfos.when(
                        data: (list) {
                          final entries = <WorldInfoEntry>[
                            for (final w in list) ...w.entries
                          ];
                          final filtered = _filterEntries(entries);
                          if (filtered.isEmpty) {
                            return Center(
                              child: Text(
                                entries.isEmpty ? '暂无条目，点击下方"+ 添加条目"创建' : '无匹配条目',
                                style: TextStyle(
                                    fontSize: DesignTokens.fontSizeSm,
                                    color: labelColor?.withValues(alpha: 0.5)),
                              ),
                            );
                          }
                          return ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) => _WorldBookEntryCard(
                              entry: filtered[i],
                              isDark: isDark,
                              onToggle: () => _toggleEntry(filtered[i]),
                              onEdit: () => showWorldBookEntryEditDialog(
                                  context, ref, entry: filtered[i]),
                              onDelete: () => _deleteEntry(filtered[i]),
                            ),
                          );
                        },
                        loading: () => const Center(
                            child: CircularProgressIndicator(
                                color: KiraDialogTheme.primary)),
                        error: (e, _) => Center(
                            child: Text('加载失败: $e',
                                style: const TextStyle(color: Colors.red))),
                      ),
                    ),
                  ],
                ),
              ),
              // ── Footer ──
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: const Color(0xFF7B5EA7).withValues(alpha: 0.15),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: KiraDashedButton(
                        label: '导入',
                        icon: Icons.file_download_outlined,
                        color: KiraDialogTheme.importColor,
                        onTap: () => _importWorldBook(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: KiraDashedButton(
                        label: '导出',
                        icon: Icons.file_upload_outlined,
                        color: KiraDialogTheme.exportColor,
                        onTap: () => _exportWorldBook(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                          onTap: () async {
                            final books = ref.read(characterWorldInfosProvider(widget.characterId)).valueOrNull;
                            if (books == null || books.isEmpty) {
                              KiraToast.show(context, '请先保存角色以创建世界书', type: KiraToastType.warning);
                              return;
                            }
                            await showWorldBookEntryEditDialog(context, ref, worldInfoId: books.first.id);
                          },
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF6C5CE7), Color(0xFFA855F7)]),
                              borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, size: 18, color: Colors.white),
                                SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '添加条目',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: DesignTokens.fontSizeBodyMedium,
                                      fontWeight: DesignTokens.weightSemibold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 筛选 Chip
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? KiraDialogTheme.primary.withValues(alpha: 0.2)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
          border: Border.all(
            color: selected
                ? KiraDialogTheme.primary
                : const Color(0xFF7B5EA7).withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: DesignTokens.fontSizeXs,
            fontWeight: selected
                ? DesignTokens.weightSemibold
                : DesignTokens.weightMedium,
            color: selected
                ? KiraDialogTheme.primary
                : Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ),
    );
  }
}

/// 条目卡片（enabled 竖线 + 常量标签 + 编辑/删除）
class _WorldBookEntryCard extends StatelessWidget {
  final WorldInfoEntry entry;
  final bool isDark;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _WorldBookEntryCard({
    required this.entry,
    required this.isDark,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = Theme.of(context).textTheme.bodyMedium?.color;
    final displayKeys = entry.keys.take(3).toList();
    final extraCount = entry.keys.length - displayKeys.length;
    final lineColor = entry.constant
        ? KiraDialogTheme.worldbook
        : (entry.enabled ? KiraDialogTheme.success : Colors.grey);

    return Opacity(
      opacity: entry.enabled ? 1.0 : 0.5,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF252640).withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                border: Border.all(
                  color: const Color(0xFF7B5EA7).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  // enabled 开关
                  GestureDetector(
                    onTap: onToggle,
                    child: Icon(
                      entry.enabled
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                      size: 24,
                      color: entry.enabled
                          ? KiraDialogTheme.success
                          : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayKeys.isNotEmpty
                                    ? displayKeys.join(', ')
                                    : (entry.comment.isNotEmpty
                                        ? entry.comment
                                        : '（无关键词）'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: DesignTokens.fontSizeSm,
                                    fontWeight: DesignTokens.weightSemibold,
                                    color: labelColor),
                              ),
                            ),
                            if (extraCount > 0) ...[
                              const SizedBox(width: 4),
                              Text('+$extraCount',
                                  style: const TextStyle(
                                      fontSize: DesignTokens.fontSizeXs,
                                      color: KiraDialogTheme.primary)),
                            ],
                            if (entry.constant) ...[
                              const SizedBox(width: 6),
                              const _StatusTag(label: '常量', color: KiraDialogTheme.worldbook),
                            ],
                            if (entry.secondaryKeys.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              const _StatusTag(label: '二次匹配', color: KiraDialogTheme.opening),
                            ],
                          ],
                        ),
                        if (entry.content.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            entry.content,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: DesignTokens.fontSizeXs,
                                color: labelColor?.withValues(alpha: 0.5)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit_outlined,
                        size: 18, color: labelColor?.withValues(alpha: 0.7)),
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        size: 18, color: Colors.red.withValues(alpha: 0.6)),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ),
            // 左侧状态竖线
            Positioned(
              left: 0,
              top: 8,
              bottom: 8,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: lineColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 状态标签
class _StatusTag extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusTag({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10, fontWeight: DesignTokens.weightMedium, color: color),
      ),
    );
  }
}

/// 编辑器内确认浮窗
class _EditorConfirm extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  const _EditorConfirm({
    required this.title,
    required this.message,
    this.confirmText = '确认',
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        width: 320,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1B2E) : const Color(0xFFF4F3FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF7B5EA7).withValues(alpha: 0.25),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: DesignTokens.fontSizeHeadline,
                      fontWeight: DesignTokens.weightBold,
                      color: Theme.of(context).textTheme.bodyLarge?.color)),
              const SizedBox(height: DesignTokens.spaceSm),
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: DesignTokens.fontSizeSm,
                      height: 1.5,
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withValues(alpha: 0.7))),
              const SizedBox(height: DesignTokens.spaceLg),
              KiraDialogActions(
                confirmText: confirmText,
                confirmColor: Colors.red,
                onCancel: () => Navigator.pop(context, false),
                onConfirm: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
