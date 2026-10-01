// lib/presentation/dialogs/global_worldbook_dialog.dart
/// Global worldbook dialog. Unlike the character worldbook editor, this one
/// manages multiple worldbooks: top tab bar for switching books +
/// create/import/export/rename/delete; current book entry list: search/filter
/// (all/enabled/constant/disabled)/sort + entry cards (enabled toggle/keyword
/// preview/content preview/edit/delete) + add entry. Entry editing reuses
/// worldbook_entry_edit_dialog.dart (same fields).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:kirakira/data/models/world_info.dart';
import 'package:kirakira/presentation/providers/world_info_providers.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import '../utils/export_delivery.dart';
import 'core_dialog.dart';
import 'worldbook_entry_edit_dialog.dart';

Future<void> showGlobalWorldbookDialog(BuildContext context, WidgetRef ref) {
  return showCoreDialog(
    context,
    builder: (_) => const _GlobalWorldbookDialog(),
  );
}

class _GlobalWorldbookDialog extends ConsumerStatefulWidget {
  const _GlobalWorldbookDialog();

  @override
  ConsumerState<_GlobalWorldbookDialog> createState() =>
      _GlobalWorldbookDialogState();
}

class _GlobalWorldbookDialogState
    extends ConsumerState<_GlobalWorldbookDialog> {
  String? _selectedBookId;
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  String _search = '';
  String _filter = 'all'; // all | enabled | constant | disabled
  String _sort = 'order'; // order | created

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
      result = result
          .where((e) =>
              e.keys.any((k) => k.toLowerCase().contains(q)) ||
              e.content.toLowerCase().contains(q) ||
              e.comment.toLowerCase().contains(q))
          .toList();
    }
    switch (_filter) {
      case 'enabled':
        result = result.where((e) => e.enabled).toList();
      case 'disabled':
        result = result.where((e) => !e.enabled).toList();
      case 'constant':
        result = result.where((e) => e.constant).toList();
    }
    result = [...result]..sort(
        (a, b) => a.insertionOrder.compareTo(b.insertionOrder));
    return result;
  }

  Future<void> _toggleEntry(WorldInfoEntry entry) async {
    final notifier = ref.read(worldInfoNotifierProvider.notifier);
    await notifier.updateEntry(entry.copyWith(enabled: !entry.enabled));
    ref.invalidate(globalWorldInfosProvider);
  }

  Future<void> _deleteEntry(WorldInfoEntry entry) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('删除条目'),
        content: Text(
            '确定要删除「${entry.keys.isNotEmpty ? entry.keys.join(', ') : entry.comment}」吗？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(worldInfoNotifierProvider.notifier).deleteEntry(entry.id);
    ref.invalidate(globalWorldInfosProvider);
    if (mounted) {
      coreToast(context, '条目已删除');
    }
  }

  // Worldbook management

  Future<void> _createBook() async {
    final name = await _showBookMetaSheet(initial: null);
    if (name == null || name['name']!.isEmpty) return;
    final notifier = ref.read(worldInfoNotifierProvider.notifier);
    final book = await notifier.createWorldInfo(
      name: name['name']!,
      description:
          name['description']!.isEmpty ? null : name['description'],
      isGlobal: true,
    );
    ref.invalidate(globalWorldInfosProvider);
    if (mounted) setState(() => _selectedBookId = book.id);
  }

  Future<void> _toggleBookEnabled(WorldInfo book) async {
    await ref
        .read(worldInfoNotifierProvider.notifier)
        .updateWorldInfo(book.copyWith(enabled: !book.enabled));
    ref.invalidate(globalWorldInfosProvider);
  }

  Future<void> _renameBook(WorldInfo book) async {
    final result = await _showBookMetaSheet(initial: book);
    if (result == null || result['name']!.isEmpty) return;
    await ref
        .read(worldInfoNotifierProvider.notifier)
        .updateWorldInfo(book.copyWith(
          name: result['name']!,
          description: result['description']!.isEmpty
              ? null
              : result['description'],
        ));
    ref.invalidate(globalWorldInfosProvider);
  }

  Future<void> _deleteBook(WorldInfo book) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('删除世界书'),
        content: Text('删除「${book.name}」及其全部条目？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref
        .read(worldInfoNotifierProvider.notifier)
        .deleteWorldInfo(book.id);
    ref.invalidate(globalWorldInfosProvider);
    if (mounted) {
      setState(() => _selectedBookId = null);
      coreToast(context, '世界书已删除');
    }
  }

  /// Create/rename (name + description) in a bottom sheet.
  Future<Map<String, String>?> _showBookMetaSheet({WorldInfo? initial}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CoreDialogPalette(isDark: isDark);
    final nameCtrl = TextEditingController(text: initial?.name ?? '');
    final descCtrl = TextEditingController(text: initial?.description ?? '');

    return showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusBottomSheet),
        ),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                initial == null ? '新建世界书' : '编辑世界书',
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeHeadline,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: nameCtrl,
                autofocus: true,
                placeholder: '名称',
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.fill,
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusGroupedCard),
                ),
                style: TextStyle(color: palette.textPrimary),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: descCtrl,
                placeholder: '描述（可选）',
                maxLines: 3,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.fill,
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusGroupedCard),
                ),
                style: TextStyle(color: palette.textPrimary),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) {
                      coreToast(sheetCtx, '名称不能为空');
                      return;
                    }
                    Navigator.pop(sheetCtx, {
                      'name': nameCtrl.text.trim(),
                      'description': descCtrl.text.trim(),
                    });
                  },
                  child: const Text('保存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Import entries into the current book. Accepts a JSON array or {entries: [...]} format.
  Future<void> _importEntries(WorldInfo book) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty) return;
      final content = await File(result.files.first.path!).readAsString();
      final data = jsonDecode(content);
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
      ref.invalidate(globalWorldInfosProvider);
      if (mounted) coreToast(context, '世界书导入成功');
    } catch (e) {
      if (mounted) coreToast(context, '导入失败: $e');
    }
  }

  /// Export all entries of the current book.
  Future<void> _exportEntries(WorldInfo book) async {
    if (book.entries.isEmpty) {
      coreToast(context, '暂无条目可导出');
      return;
    }
    final json = const JsonEncoder.withIndent('  ')
        .convert(book.entries.map((e) => e.toJson()).toList());
    final date = DateTime.now().toIso8601String().split('T')[0];
    final fileName =
        'worldbook_${book.name.replaceAll(RegExp(r'[^\w\s-]'), '_')}_$date.json';
    // Unified export delivery: share / save to file.
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
    final palette = CoreDialogPalette(isDark: isDark);
    final booksAsync = ref.watch(globalWorldInfosProvider);

    return CoreDialogShell(
      title: '全局世界书',
      icon: CupertinoIcons.book_fill,
      maxWidth: 720,
      maxHeightFactor: 0.9,
      disableScroll: true,
      bodyPadding: EdgeInsets.zero,
      body: booksAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('加载失败: $e',
                style:
                    const TextStyle(color: DesignTokens.statusError)),
          ),
        ),
        data: (books) {
          if (_selectedBookId == null ||
              !books.any((b) => b.id == _selectedBookId)) {
            _selectedBookId = books.isNotEmpty ? books.first.id : null;
          }
          final selectedBook = books
              .where((b) => b.id == _selectedBookId)
              .firstOrNull;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top: book tabs + create/import/export
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  children: [
                    SizedBox(
                      height: 36,
                      child: books.isEmpty
                          ? Center(
                              child: Text(
                                '暂无世界书，点击右侧 + 新建',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: palette.textSecondary),
                              ),
                            )
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: books.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 6),
                              itemBuilder: (_, i) {
                                final book = books[i];
                                final selected =
                                    book.id == _selectedBookId;
                                return _BookTab(
                                  palette: palette,
                                  book: book,
                                  selected: selected,
                                  onTap: () => setState(
                                      () => _selectedBookId = book.id),
                                  onToggle: () => _toggleBookEnabled(book),
                                  onRename: () => _renameBook(book),
                                  onDelete: () => _deleteBook(book),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            color: DesignTokens.primary,
                            borderRadius: BorderRadius.circular(8),
                            minSize: 0,
                            onPressed: _createBook,
                            child: const Text('+ 新建世界书',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            color: palette.fill,
                            borderRadius: BorderRadius.circular(8),
                            minSize: 0,
                            onPressed: selectedBook == null
                                ? null
                                : () => _importEntries(selectedBook),
                            child: Text('导入',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: palette.textPrimary)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            color: palette.fill,
                            borderRadius: BorderRadius.circular(8),
                            minSize: 0,
                            onPressed: selectedBook == null
                                ? null
                                : () => _exportEntries(selectedBook),
                            child: Text('导出',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: palette.textPrimary)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(
                  height: 0.5, thickness: 0.5, color: palette.divider),

              // Current book entry list
              Expanded(
                child: selectedBook == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.book,
                                  size: 40, color: palette.textTertiary),
                              const SizedBox(height: 8),
                              Text('暂无世界书',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: palette.textSecondary)),
                            ],
                          ),
                        ),
                      )
                    : _buildBookBody(context, palette, selectedBook),
              ),
            ],
          );
        },
      ),
      footer: CoreDialogFooter(
        child: CoreSecondaryButton(
          label: '关闭',
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  /// Toolbar + entry list for the current book.
  Widget _buildBookBody(
      BuildContext context, CoreDialogPalette palette, WorldInfo book) {
    final filtered = _filterEntries(book.entries);
    final enabledCount =
        book.entries.where((e) => e.enabled).length;

    return Column(
      children: [
        // Toolbar: search + filter + sort
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SizedBox(
            height: 36,
            child: CupertinoTextField(
              controller: _searchCtrl,
              placeholder: '搜索关键词 / 内容 / 备注...',
              padding: const EdgeInsets.symmetric(horizontal: 10),
              prefix: Icon(CupertinoIcons.search,
                  size: 16, color: palette.textTertiary),
              decoration: BoxDecoration(
                color: palette.fill,
                borderRadius: BorderRadius.circular(8),
              ),
              style: TextStyle(fontSize: 14, color: palette.textPrimary),
              onChanged: (value) {
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                  if (mounted) {
                    setState(() => _search = value);
                  }
                });
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _FilterChipWidget(
                palette: palette,
                label: '全部',
                selected: _filter == 'all',
                onTap: () => setState(() => _filter = 'all'),
              ),
              const SizedBox(width: 6),
              _FilterChipWidget(
                palette: palette,
                label: '已启用',
                selected: _filter == 'enabled',
                onTap: () => setState(() => _filter = 'enabled'),
              ),
              const SizedBox(width: 6),
              _FilterChipWidget(
                palette: palette,
                label: '常量',
                selected: _filter == 'constant',
                onTap: () => setState(() => _filter = 'constant'),
              ),
              const SizedBox(width: 6),
              _FilterChipWidget(
                palette: palette,
                label: '已禁用',
                selected: _filter == 'disabled',
                onTap: () => setState(() => _filter = 'disabled'),
              ),
              const Spacer(),
              _FilterChipWidget(
                palette: palette,
                label: _sort == 'order' ? '按顺序' : '按创建',
                selected: true,
                onTap: () => setState(() => _sort =
                    _sort == 'order' ? 'created' : 'order'),
              ),
              const SizedBox(width: 6),
              Text(
                '${book.entries.length} 条 · $enabledCount 启用',
                style: TextStyle(
                    fontSize: 11, color: palette.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Entry list
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    book.entries.isEmpty
                        ? '暂无条目，点击下方"+ 添加条目"创建'
                        : '无匹配条目',
                    style:
                        TextStyle(fontSize: 12, color: palette.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _EntryCard(
                    palette: palette,
                    entry: filtered[i],
                    onToggle: () => _toggleEntry(filtered[i]),
                    onEdit: () => showWorldBookEntryEditDialog(
                      context, ref,
                      entry: filtered[i],
                    ),
                    onDelete: () => _deleteEntry(filtered[i]),
                  ),
                ),
        ),
        // Add entry
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: CorePrimaryButton(
            label: '+ 添加条目',
            icon: CupertinoIcons.add,
            onPressed: () => showWorldBookEntryEditDialog(
              context, ref,
              worldInfoId: book.id,
            ),
          ),
        ),
      ],
    );
  }
}

/// Book tab (name + entry count + enable switch + delete button; long-press to rename).
class _BookTab extends StatelessWidget {
  const _BookTab({
    required this.palette,
    required this.book,
    required this.selected,
    required this.onTap,
    required this.onToggle,
    required this.onRename,
    required this.onDelete,
  });

  final CoreDialogPalette palette;
  final WorldInfo book;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onRename,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? DesignTokens.primary.withValues(alpha: 0.15)
              : palette.fill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? DesignTokens.primary : palette.outline,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 24,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: CupertinoSwitch(
                  value: book.enabled,
                  onChanged: (_) => onToggle(),
                  activeTrackColor: DesignTokens.primary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              book.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: book.enabled
                    ? (selected
                        ? DesignTokens.primary
                        : palette.textPrimary)
                    : palette.textTertiary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${book.entries.length}',
              style: TextStyle(
                  fontSize: 11, color: palette.textSecondary),
            ),
            const SizedBox(width: 2),
            GestureDetector(
              onTap: onDelete,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(CupertinoIcons.trash,
                    size: 14, color: DesignTokens.statusError),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Filter chip.
class _FilterChipWidget extends StatelessWidget {
  const _FilterChipWidget({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final CoreDialogPalette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? DesignTokens.primary.withValues(alpha: 0.15)
              : palette.fill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? DesignTokens.primary : palette.outline,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? DesignTokens.primary : palette.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Entry card (enabled toggle/keyword preview/content preview/edit/delete).
class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.palette,
    required this.entry,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final CoreDialogPalette palette;
  final WorldInfoEntry entry;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.fill.withValues(alpha: palette.isDark ? 0.55 : 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 40,
                child: CupertinoSwitch(
                  value: entry.enabled,
                  onChanged: (_) => onToggle(),
                  activeTrackColor: DesignTokens.primary,
                ),
              ),
              const SizedBox(width: 8),
              if (entry.constant)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: DesignTokens.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '常量',
                    style: TextStyle(
                        fontSize: 10, color: DesignTokens.accent),
                  ),
                ),
              Expanded(
                child: Text(
                  entry.keys.isNotEmpty ? entry.keys.join(' · ') : '（无关键词）',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(4),
                minSize: 0,
                onPressed: onEdit,
                child: Icon(CupertinoIcons.pencil,
                    size: 16, color: palette.textSecondary),
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(4),
                minSize: 0,
                onPressed: onDelete,
                child: const Icon(CupertinoIcons.trash,
                    size: 16, color: DesignTokens.statusError),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            entry.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}
