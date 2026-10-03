import 'dart:async';
import 'dart:io';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kirakira/data/models/character.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/providers/character_grid_provider.dart';
import 'package:kirakira/presentation/providers/character_providers.dart';
import 'package:kirakira/presentation/router/app_router.dart';
import 'package:kirakira/presentation/widgets/common/character_avatar_image.dart';
import 'package:kirakira/presentation/widgets/common/kira_search_bar.dart';
import 'package:kirakira/presentation/dialogs/character_preview_dialog.dart';
import 'package:kirakira/presentation/dialogs/character_edit_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kirakira/presentation/utils/export_delivery.dart';
import 'package:kirakira/presentation/screens/import/import_screen.dart'
    show importServiceProvider;
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:kirakira/presentation/providers/world_info_providers.dart';
import 'package:kirakira/data/repositories/character_repository.dart';
import 'package:kirakira/data/repositories/regex_script_repository.dart';
import 'package:kirakira/domain/services/import_service.dart';
import 'package:kirakira/core/utils/path_utils.dart';

/// Character list screen
class CharacterListScreen extends ConsumerStatefulWidget {
  const CharacterListScreen({super.key});

  @override
  ConsumerState<CharacterListScreen> createState() => _CharacterListScreenState();
}

class _CharacterListScreenState extends ConsumerState<CharacterListScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  /// Top segmented control: 0 = My Characters, 1 = Character Market
  /// (not persisted; resets to default on page entry)
  int _tab = 0;

  // Multi-select state (standard grid only)
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  void _enterSelection(String id) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(id);
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  /// Batch delete: confirm, then delete each selected character and refresh the list
  Future<void> _deleteSelected(List<Character> all) async {
    final l10n = AppLocalizations.of(context);
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text('确定删除选中的 $count 个角色？此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final notifier = ref.read(characterListProvider.notifier);
    for (final id in _selectedIds.toList()) {
      await notifier.deleteCharacter(id);
    }
    _exitSelection();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已删除 $count 个角色')),
    );
  }
}
  /// Batch export as ZIP: choose format, export each character, package, then share
  Future<void> _exportSelectedAsZip(List<Character> all) async {
    final selected = all.where((c) => _selectedIds.contains(c.id)).toList();
    if (selected.isEmpty) return;

    // Choose format (default PNG)
    final format = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusBottomSheet),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(title: const Text('导出为PNG图片卡'), onTap: () => Navigator.pop(ctx, 'png')),
            ListTile(title: const Text('导出为JSON'), onTap: () => Navigator.pop(ctx, 'json')),
            ListTile(title: const Text('导出为CharX'), onTap: () => Navigator.pop(ctx, 'charx')),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (format == null) return;

    // Show packaging loading dialog; capture the navigator reference so it can
    // still be closed after async gaps invalidate the context
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    bool loadingShown = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    void closeLoading() {
      if (loadingShown) {
        loadingShown = false;
        navigator.pop(); // Always closes this loading dialog
      }
    }

    try {
      final importService = ref.read(importServiceProvider);
      // Active-track worldbook: assembled from the world_infos table before export
      // (replaces the import snapshot)
      final worldInfoRepo = ref.read(worldInfoRepositoryProvider);
      final regexRepo = ref.read(regexScriptRepositoryProvider);
      final archive = Archive();
      final usedNames = <String>{};

for (final c in selected) {
  final repo = ref.read(characterRepositoryProvider);
  final latestChar = await repo.getCharacter(c.id);
  final exportChar = latestChar ?? c;

  Uint8List? avatarData;
  final rawAvatarPath = exportChar.assets?.avatarPath;
  if (rawAvatarPath != null) {
    final absPath = await PathUtils.toAbsolutePath(rawAvatarPath);
    final f = File(absPath);
    if (await f.exists()) avatarData = await f.readAsBytes();
  }

  var safeName = exportChar.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  if (safeName.isEmpty) safeName = exportChar.id;
  var fileName = safeName;
  var dup = 1;
  final ext = format == 'json' ? 'json' : (format == 'charx' ? 'charx' : 'png');
  while (usedNames.contains('$fileName.$ext')) {
    fileName = '${safeName}_${dup++}';
  }
  usedNames.add('$fileName.$ext');

  final List<int> bytes;
  switch (format) {
    case 'json':
      bytes = utf8.encode(await importService.exportToJson(exportChar, worldInfoRepo: worldInfoRepo, regexRepo: regexRepo));
      break;
    case 'charx':
      bytes = await importService.exportToCharX(exportChar, avatarData, worldInfoRepo: worldInfoRepo, regexRepo: regexRepo);
      break;
    default:
      bytes = await importService.exportToPng(exportChar, avatarData, worldInfoRepo: worldInfoRepo, regexRepo: regexRepo);
  }
  archive.addFile(ArchiveFile('$fileName.$ext', bytes.length, bytes));
}

      final zipBytes = ZipEncoder().encode(archive)!;
      final ts = DateTime.now();
      final stamp = '${ts.year}${_two(ts.month)}${_two(ts.day)}_'
          '${_two(ts.hour)}${_two(ts.minute)}${_two(ts.second)}';

      closeLoading(); // Close loading first
      _exitSelection();

      // Unified export delivery: share or save to file
      await deliverExportFile(
        context: context,
        fileName: 'KiraKira_$stamp.zip',
        bytes: Uint8List.fromList(zipBytes),
        subject: 'KiraKira_$stamp',
        ext: 'zip',
      );
    } catch (e, st) {
      debugPrint('❌ 批量导出ZIP失败: $e\n$st');
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    } finally {
      closeLoading(); // Always closed on exit, success or failure, to avoid a stuck screen
    }
  }

  // Progress stream driving the import dialog (broadcast so the dialog builder
  // can attach at any time; one import at a time in practice).
  final StreamController<String> _zipImportProgress = StreamController<String>.broadcast();

  /// Import ZIP: stream-extract in a background isolate, then run the standard
  /// import pipeline per extracted file with progress.
  ///
  /// Two phases (fixes OOM + ANR on multi-GB ZIPs):
  ///   1. compute(): ZipDecoder().decodeBuffer(InputFileStream) parses the
  ///      archive as zero-copy file-stream references; each entry inflates
  ///      alone, is written to temp, and released. Peak memory = largest
  ///      single entry, never the whole archive. UI thread never blocks.
  ///   2. Main isolate: each extracted file goes through the full existing
  ///      pipeline (importFromPng/CharX/Json -> createCharacter -> regex ->
  ///      embedded lorebook) — repositories/Riverpod require the root isolate —
  ///      with per-file progress, then the temp file is deleted immediately.
  Future<void> _importFromZip() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        withData: false, // never let the picker load the whole ZIP into memory
      );
      if (result == null || result.files.isEmpty) return;
      final platformFile = result.files.first;

      if (!mounted) return;
      final navigator = Navigator.of(context, rootNavigator: true);
      final messenger = ScaffoldMessenger.of(context);
      bool loadingShown = true;
      // Idempotent close: exit paths can race (success / error / dispose) and a
      // stuck dialog would block the page (same guarantee as before).
      void closeLoading() {
        if (loadingShown) {
          loadingShown = false;
          navigator.pop();
        }
      }

      _zipImportProgress.add('准备中...');

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) => PopScope(
          canPop: false,
          child: Center(
            child: AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('正在导入角色卡...'),
                  const SizedBox(height: 8),
                  StreamBuilder<String>(
                    stream: _zipImportProgress.stream,
                    builder: (context, snapshot) => Text(
                      snapshot.data ?? '准备中...',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      int ok = 0, fail = 0;
      try {
        // Resolve a real file path for the streaming reader (content:// URIs can
        // come back pathless on some platforms; materialize bytes as fallback).
        var zipPath = platformFile.path;
        if (zipPath == null) {
          final bytes = platformFile.bytes;
          if (bytes == null) {
            throw Exception('无法读取文件路径');
          }
          final cache = await getTemporaryDirectory();
          zipPath = p.join(cache.path,
              'zip_pick_${DateTime.now().millisecondsSinceEpoch}.zip');
          await File(zipPath).writeAsBytes(bytes, flush: true);
        }

        final cache = await getTemporaryDirectory();
        final extractDir = Directory(p.join(cache.path,
            'zip_import_${DateTime.now().millisecondsSinceEpoch}'));
        try {
          // Phase 1: background isolate — streaming structure parse + per-entry
          // extract. Returns temp file paths only (sendable across isolates).
          _zipImportProgress.add('正在解压...');
          final extract = await compute(
            _extractZipToTemp,
            _ZipExtractParams(zipPath: zipPath, tempDirPath: extractDir.path),
          );
          if (extract.error != null) {
            throw Exception(extract.error);
          }
          if (extract.files.isEmpty) {
            messenger.showSnackBar(
                const SnackBar(content: Text('ZIP 中没有可导入的角色卡文件')));
            return;
          }

          // Phase 2: full import pipeline on the root isolate (DB writes +
          // Riverpod stay here by design), one file at a time with progress;
          // temp file deleted immediately after each file.
          final importService = ref.read(importServiceProvider);
          final repo = ref.read(characterRepositoryProvider);
          final worldInfoRepo = ref.read(worldInfoRepositoryProvider);
          for (var i = 0; i < extract.files.length; i++) {
            final path = extract.files[i];
            final name = p.basename(path);
            _zipImportProgress.add('正在导入 ${i + 1}/${extract.files.length}: $name');
            try {
              final ext = p.extension(path).toLowerCase().replaceFirst('.', '');
              Character c;
              switch (ext) {
                case 'png':
                  c = await importService.importFromPng(path);
                  break;
                case 'json':
                  c = await importService
                      .importFromJson(await File(path).readAsString());
                  break;
                case 'charx':
                  c = await importService.importFromCharX(path);
                  break;
                default:
                  continue;
              }
              // Persist to database (regex scripts stored with the extensions)
              final created = await repo.createCharacter(c);
              try {
                final rawList = c.extensions['regex_scripts'];
                if (rawList is List && rawList.isNotEmpty) {
                  await ref
                      .read(regexScriptRepositoryProvider)
                      .importCharacterScriptsFromRaw(created.id, rawList);
                }
              } catch (e) {
                debugPrint('[Phase2] ZIP导入正则写表失败(extensions 保留): $e');
              }
              // Extract the embedded worldbook as a standalone WorldInfo
              if (c.characterBook != null && c.characterBook!.entries.isNotEmpty) {
                await importEmbeddedLorebook(
                    worldInfoRepo, created.id, c.characterBook!, created.name);
              }
              ok++;
            } catch (e) {
              fail++;
              debugPrint('❌ ZIP内 $name 导入失败: $e');
            } finally {
              // Per-file cleanup: nothing accumulates across an import.
              try {
                await File(path).delete();
              } catch (_) {}
            }
          }
        } finally {
          // Whole-directory cleanup (covers entries skipped on early exit too).
          try {
            if (await extractDir.exists()) {
              await extractDir.delete(recursive: true);
            }
          } catch (_) {}
        }

        closeLoading();
        ref.read(characterListProvider.notifier).refresh();
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text('导入完成：成功 $ok 个${fail > 0 ? '，失败 $fail 个' : ''}')),
          );
        }
      } catch (e, st) {
        debugPrint('❌ 导入ZIP失败: $e\n$st');
        closeLoading();
        if (mounted) {
          messenger.showSnackBar(SnackBar(content: Text('导入失败: $e')));
        }
      } finally {
        closeLoading();
      }
    } catch (e, st) {
      debugPrint('❌ 导入ZIP失败: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导入失败: $e')));
      }
    }
  }
  static String _two(int n) => n.toString().padLeft(2, '0');

  // Pagination via PageView: PageController replaces _loadedPages/_scrollController
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    _zipImportProgress.close();
    super.dispose();
  }

  /// Reset to page 1 when the page size changes
  void _resetPage() {
    _currentPage = 0;
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final charactersAsync = ref.watch(characterListProvider);
    final pageSize = ref.watch(characterGridPageSizeProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Opaque so the shell's chat wallpaper doesn't show through
      body: RefreshIndicator(
        // iOS-style pull-to-refresh (replaces the AppBar refresh button)
        onRefresh: () async {
          ref.read(characterListProvider.notifier).refresh();
        },
        child: CustomScrollView(
          slivers: [
            // Normal state: no Large Title; selection mode shows a compact title in the same CustomScrollView
            if (_selectionMode)
              SliverAppBar(
                pinned: true,
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _exitSelection,
                ),
                title: Text('已选 ${_selectedIds.length} 个'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.archive_outlined),
                    tooltip: '打包为ZIP',
                    onPressed: () {
                      final all = ref.read(characterListProvider).valueOrNull ?? [];
                      _exportSelectedAsZip(all);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: l10n.delete,
                    onPressed: () {
                      final all = ref.read(characterListProvider).valueOrNull ?? [];
                      _deleteSelected(all);
                    },
                  ),
                ],
              ),
            // Search bar pinned to top via SafeArea (hidden in selection mode)
            if (!_selectionMode && _tab == 0)
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: KiraSearchBar(
                    controller: _searchController,
                    hintText: l10n.searchCharacters,
                    onChanged: (value) => setState(() {
                      _searchQuery = value;
                      _resetPage(); // Return to page 1 when the search query changes
                    }),
                    onClear: () => setState(() {
                      _searchQuery = '';
                      _resetPage();
                    }),
                  ),
                ),
              ),
            // Segmented control: page-level navigation, pinned to top; hidden in selection
            // mode; trailing hosts the former AppBar action buttons
            if (!_selectionMode)
              SliverPersistentHeader(
                pinned: true,
                delegate: _SegmentedHeaderDelegate(
                  tab: _tab,
                  onChanged: (v) => setState(() => _tab = v),
                  trailing: _tab == 0
                      ? [
                          IconButton(
                            icon: const Icon(CupertinoIcons.add, size: 22),
                            tooltip: l10n.createCharacter,
                            onPressed: () => _showAddActionSheet(context),
                          ),
                          IconButton(
                            icon: const Icon(CupertinoIcons.checkmark_circle, size: 22),
                            tooltip: '选择',
                            onPressed: () {
                              final all = ref.read(characterListProvider).valueOrNull ?? [];
                              if (all.isNotEmpty) {
                                setState(() => _selectionMode = true);
                              }
                            },
                          ),
                          // Page-size options (4/8/12/16)
                          IconButton(
                            icon: const Icon(CupertinoIcons.square_grid_2x2, size: 22),
                            tooltip: '每页数量',
                            onPressed: () => _showPageSizeSheet(context),
                          ),
                          const SizedBox(width: DesignTokens.spaceXs),
                        ]
                      : [
                          IconButton(
                            icon: const Icon(CupertinoIcons.add, size: 22),
                            tooltip: l10n.createCharacter,
                            onPressed: () => _showAddActionSheet(context),
                          ),
                          const SizedBox(width: DesignTokens.spaceXs),
                        ],
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: DesignTokens.spaceSm)),
            // Content area: tab 0 = My Characters grid; tab 1 = Character Market
            if (_tab == 1)
              SliverFillRemaining(
                child: _CharacterMarketView(
                  onSwitchToMyCharacters: () => setState(() => _tab = 0),
                ),
              )
            else
            ...charactersAsync.when(
              data: (characters) {
                final filtered = _searchQuery.isEmpty
                    ? characters
                    : characters.where((c) =>
                        c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                        c.description.toLowerCase().contains(_searchQuery.toLowerCase())
                      ).toList();

                if (filtered.isEmpty) {
                  return const [
                    SliverFillRemaining(child: _EmptyState()),
                  ];
                }

                // Split into pages by pageSize; swipe horizontally in PageView to flip
                final pageCount =
                    (filtered.length + pageSize - 1) ~/ pageSize;
                if (_currentPage > pageCount - 1) {
                  _currentPage = pageCount - 1; // Clamp after the list shrinks (persisted on next setState)
                }

                return [
                  // Page indicator "2/4" below the search bar
                  if (pageCount > 1)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: DesignTokens.spaceXs),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.chevron_left,
                              size: 12,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_currentPage + 1}/$pageCount',
                              style: TextStyle(
                                fontSize: DesignTokens.fontSizeSm,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              CupertinoIcons.chevron_right,
                              size: 12,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color,
                            ),
                          ],
                        ),
                      ),
                    ),
                  SliverFillRemaining(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: pageCount,
                      onPageChanged: (i) =>
                          setState(() => _currentPage = i),
                      itemBuilder: (context, pageIndex) {
                        final start = pageIndex * pageSize;
                        final pageItems =
                            filtered.skip(start).take(pageSize).toList();
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            DesignTokens.spaceMd,
                            DesignTokens.spaceSm,
                            DesignTokens.spaceMd,
                            0,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.80, // Shorter card aspect ratio
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: pageItems.length,
                          itemBuilder: (context, index) {
                            final c = pageItems[index];
                            return RepaintBoundary(
                              // Perf: isolate each card's repaint from its siblings, so
                              // selection toggles / entrance animations repaint one card only.
                              child: _StaggeredEntrance(
                                itemId: c.id,
                                child: _CharacterGridCard(
                                  character: c,
                                  selectionMode: _selectionMode,
                                  isSelected: _selectedIds.contains(c.id),
                                  onTap: () {
                                    if (_selectionMode) {
                                      _toggleSelect(c.id);
                                    } else {
                                      // Tapping a card opens a lightweight preview dialog
                                      showCharacterPreviewDialog(context, ref, c);
                                    }
                                  },
                                  onLongPress: () {
                                    if (!_selectionMode) {
                                      _enterSelection(c.id);
                                    } else {
                                      _toggleSelect(c.id);
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ];
              },
              loading: () => const [
                SliverFillRemaining(child: _SkeletonGrid()),
              ],
              error: (error, stack) => [
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: DesignTokens.statusError),
                        const SizedBox(height: 16),
                        Text('${l10n.error}: $error'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref.read(characterListProvider.notifier).refresh(),
                          child: Text(l10n.retry),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Bottom clearance for the tab bar (capsule height 62 + 12 margin + breathing room)
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }

  /// iOS-style add menu (the three former FAB entries moved to the top-right "+" ActionSheet)
  void _showAddActionSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetCtx) => CupertinoTheme(
        // Fallback under MaterialApp: forces dark text on CupertinoActionSheet in dark mode
        data: CupertinoThemeData(
          brightness: isDark ? Brightness.dark : Brightness.light,
        ),
        child: CupertinoActionSheet(
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetCtx);
                context.push(AppRoutes.import_);
              },
              child: Text(l10n.importCharacter),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetCtx);
                _importFromZip();
              },
              child: const Text('从ZIP批量导入'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetCtx);
                showCharacterEditDialog(context, ref);
              },
              child: Text(l10n.createCharacter),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetCtx),
            child: Text(l10n.cancel),
          ),
        ),
      ),
    );
  }

  /// Page-size selector (4/8/12/16, persisted as character_grid_page_size)
  void _showPageSizeSheet(BuildContext context) {
    final current = ref.read(characterGridPageSizeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetCtx) => CupertinoTheme(
        data: CupertinoThemeData(
          brightness: isDark ? Brightness.dark : Brightness.light,
        ),
        child: CupertinoActionSheet(
          title: const Text('每页显示'),
          actions: [
            for (final n in CharacterGridPageSizeNotifier.kChoices)
              CupertinoActionSheetAction(
                onPressed: () {
    ref.read(characterGridPageSizeProvider.notifier).set(n);
    _resetPage(); // Return to page 1 when the page size changes
                  Navigator.pop(sheetCtx);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$n 个'),
                    if (n == current) ...[
                      const SizedBox(width: 6),
                      const Icon(CupertinoIcons.checkmark, size: 16),
                    ],
                  ],
                ),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetCtx),
            child: Text(AppLocalizations.of(context).cancel),
          ),
        ),
      ),
    );
  }

}

class _StaggeredEntrance extends StatefulWidget {
  final String itemId; // stable identity (character id), not the list index
  final Widget child;

  const _StaggeredEntrance({required this.itemId, required this.child});

  @override
  State<_StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<_StaggeredEntrance> {
  // Perf: track which items already played their entrance animation (per app run).
  // GridView.builder re-mounts items on every scroll-in; without this cache each mount
  // replayed opacity+translate, which stuttered the scroll. The set is bounded by the
  // character count (small strings), so it never needs eviction.
  static final Set<String> _animatedIds = {};
  late final bool _shouldAnimate;

  @override
  void initState() {
    super.initState();
    // Set.add returns false when the id was already present -> animate only on first appearance.
    _shouldAnimate = _animatedIds.add(widget.itemId);
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldAnimate) {
      // Already animated this run: render the final state directly (zero animation cost).
      return widget.child;
    }
    // First appearance: play the entrance once (uniform duration, no per-index stagger delay).
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - t)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

// TODO(token): shimmer sweep using skeletonBase/skeletonHighlight awaits approval
// (see master plan §4); until then the solid darkCard breathing animation is the fallback.

/// Loading skeleton: solid fill with a 400ms breathing pulse (0.5 to 1.0)
class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.spaceMd,
        DesignTokens.spaceMd,
        DesignTokens.spaceMd,
        0,
      ),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (_, __) => const _BreathingBox(
            borderRadius: DesignTokens.radiusCard,
          ),
          childCount: 6,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.80, // Same card aspect ratio as the real grid
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
      ),
    );
  }
}

/// Breathing skeleton block: solid fill with opacity pulsing
class _BreathingBox extends StatefulWidget {
  final double borderRadius;

  const _BreathingBox({required this.borderRadius});

  @override
  State<_BreathingBox> createState() => _BreathingBoxState();
}

class _BreathingBoxState extends State<_BreathingBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: DesignTokens.durationLg),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FadeTransition(
      opacity: Tween(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: DesignTokens.curveEmphasized),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? DesignTokens.darkCard : DesignTokens.lightSeparator,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Empty-state icon container: pill radius in a muted color (visual noise reduction)
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? DesignTokens.darkCard
                  : DesignTokens.lightSurface,
              borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
            ),
            child: const Icon(
              Icons.people_outline,
              size: 40,
              color: DesignTokens.darkTextTertiary,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          Text(
            l10n.noCharactersYet,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: DesignTokens.fontSizeBodyLarge,
                  fontWeight: DesignTokens.weightMedium,
                ),
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          Text(
            l10n.importCharacter,
            style: const TextStyle(
              fontSize: DesignTokens.fontSizeXs,
              color: DesignTokens.darkTextSecondary,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => showCharacterEditDialog(context, ref),
                icon: const Icon(Icons.add),
                label: Text(l10n.createCharacter),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.import_),
                icon: const Icon(Icons.file_download),
                label: Text(l10n.import),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CharacterGridCard extends ConsumerWidget {
  final Character character;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _CharacterGridCard({
    required this.character,
    this.selectionMode = false,
    this.isSelected = false,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      clipBehavior: Clip.antiAlias,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        // Card radius follows the card level; zero shadow in dark mode, 0.5 separator in light mode
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        side: isSelected
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2.5)
            : BorderSide(
                color: isDark
                    ? Colors.transparent
                    : Theme.of(context).dividerColor.withValues(alpha: 0.5),
                width: 0.5,
              ),
      ),
      child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Avatar area flex cut from 4 to 3 so the shorter card feels more focused
                  Expanded(flex: 3, child: _buildAvatar()),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spaceSm,
                      vertical: DesignTokens.spaceXs,
                    ),
                    child: Column(
                      // Center name/author (iOS photo-grid look)
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          character.name,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: DesignTokens.fontSizeBodyMedium,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (character.creator.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: DesignTokens.spaceXxs),
                            child: Text(
                              'by ${character.creator}',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: DesignTokens.fontSizeCaption,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color
                                        ?.withValues(alpha: 0.6),
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              // Pinned indicator (top-left pin icon)
              if (character.isPinned)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      CupertinoIcons.pin_fill,
                      size: 16,
                      color: Color(0xFFFFA726),
                    ),
                  ),
                ),
              if (selectionMode)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.white70,
                    size: 26,
                  ),
                ),
            ],
          ),
        ),
    );
  }

  Widget _buildAvatar() {
    final avatar = RepaintBoundary(
      child: character.assets?.avatarPath != null
          ? CharacterAvatarImage(
              imagePath: character.assets!.avatarPath!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _defaultAvatar(),
            )
          : _defaultAvatar(),
    );
    // Hero animation removed: cover and content reveal together with the circular
    // expansion transition instead of flying separately
    return avatar;
  }

  Widget _defaultAvatar() {
    final icon = _getCharacterIcon(character);
    final color = _getCharacterColor(character);
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: 60,
          color: Colors.white,
        ),
      ),
    );
  }

  IconData _getCharacterIcon(Character character) {
    // Check if it's a built-in character by ID
    switch (character.id) {
      case 'builtin_coding_assistant':
        return Icons.code;
      case 'builtin_image_gen_assistant':
        return Icons.image;
      case 'builtin_xiaohongshu_copywriter':
        return Icons.edit_note;
      default:
        return Icons.person;
    }
  }

  Color _getCharacterColor(Character character) {
    // Check if it's a built-in character by ID
    switch (character.id) {
      case 'builtin_coding_assistant':
        return const Color(0xFF2196F3); // Blue for coding
      case 'builtin_image_gen_assistant':
        return const Color(0xFFE91E63); // Pink for image generation
      case 'builtin_xiaohongshu_copywriter':
        return const Color(0xFFFF5722); // Orange/Red for social media
      default:
        return const Color(0xFFF5AEB2); // KiraKira pink instead of the dead-blue placeholder
    }
  }
}
// Sticky top segmented control

/// Pinned header delegate for the segmented control (SliverPersistentHeader)
class _SegmentedHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _SegmentedHeaderDelegate({
    required this.tab,
    required this.onChanged,
    this.trailing = const [],
  });

  final int tab;
  final ValueChanged<int> onChanged;
  /// Large Title removed; former actions (+, select, page size) sit at the right end of the segmented row
  final List<Widget> trailing;

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceMd,
        vertical: 6,
      ),
      child: Row(
        children: [
          Flexible(
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: tab,
              // Track background per spec: dark = darkCard, light = lightFillTertiary;
              // thumbColor is left unset so the Cupertino SDK applies native light/dark semantics
              backgroundColor: isDark
                  ? DesignTokens.darkCard
                  : DesignTokens.lightFillTertiary,
              children: const {
                0: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  child: Text('我的角色'),
                ),
                1: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  child: Text('角色市场'),
                ),
              },
              onValueChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
          ...trailing,
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SegmentedHeaderDelegate oldDelegate) =>
      oldDelegate.tab != tab || oldDelegate.trailing != trailing;
}

// Character market disabled as of 2026-09.
//
// Reasons:
// 1. ACC international site: unstable (high blob URL import failure rate)
// 2. Chub.ai: NSFW content carries legal risk under domestic regulations
// 3. Official site: no suitable hosting solution yet
//
// Code retained for a possible future restore. Users can still import
// character cards through the local import feature.

/// Character market (two sites: Kira official + ACC international)
class _CharacterMarketView extends ConsumerStatefulWidget {
  final VoidCallback onSwitchToMyCharacters;

  const _CharacterMarketView({required this.onSwitchToMyCharacters});

  @override
  ConsumerState<_CharacterMarketView> createState() =>
      _CharacterMarketViewState();
}

class _CharacterMarketViewState extends ConsumerState<_CharacterMarketView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);  // International site closed; only Kira official remains
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Site switch tabs
        Container(
          decoration: BoxDecoration(
            color: isDark ? DesignTokens.darkSurface : theme.cardColor,
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? DesignTokens.darkSeparator
                    : DesignTokens.lightSeparator,
              ),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorColor: DesignTokens.primary,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: DesignTokens.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            labelStyle: const TextStyle(
              fontSize: DesignTokens.fontSizeBodyMedium,
              fontWeight: DesignTokens.weightSemibold,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: DesignTokens.fontSizeBodyMedium,
              fontWeight: DesignTokens.weightRegular,
            ),
            tabs: const [
              Tab(
                icon: Icon(Icons.home_outlined, size: 18),
                text: 'Kira官方',
              ),
              // ACC international site closed (unstable + legal risk)
              // Tab(
              //   icon: Icon(Icons.public, size: 18),
              //   text: 'ACC国际',
              // ),
            ],
          ),
        ),
        // Site content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _KiraMarketTab(),
              // ACC international site closed
              // _AccMarketTab(
              //   onSwitchToMyCharacters: widget.onSwitchToMyCharacters,
              // ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Kira official site (placeholder for now; self-hosted/community resources planned)
class _KiraMarketTab extends StatelessWidget {
  const _KiraMarketTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.storefront,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            Text(
              'Kira官方市场',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: DesignTokens.spaceXs),
            Text(
              '正在建设中',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            Container(
              padding: DesignTokens.paddingCard,
              decoration: BoxDecoration(
                color: DesignTokens.primary.withValues(alpha: 0.08),
                borderRadius:
                    BorderRadius.circular(DesignTokens.radiusMd),
                border: Border.all(
                  color: DesignTokens.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: DesignTokens.primary),
                      SizedBox(width: DesignTokens.spaceXs),
                      Text(
                        '即将推出',
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeSm,
                          fontWeight: DesignTokens.weightSemibold,
                          color: DesignTokens.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DesignTokens.spaceSm),
                  Text(
                    '• 精选高质量角色卡\n'
                    '• 社区审核，内容可控\n'
                    '• 国内直连，无需VPN\n'
                    '• 支持社区投稿',
                    style: TextStyle(
                      fontSize: DesignTokens.fontSizeSm,
                      height: 1.6,
                      color: isDark
                          ? DesignTokens.darkTextSecondary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            Text(
              'ACC国际站 因技术不稳定与法律风险已关闭入口，代码暂未删除。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ZIP streaming extraction (background isolate via compute)
// ---------------------------------------------------------------------------

/// Parameters for the background extraction isolate (sendable: plain Strings).
class _ZipExtractParams {
  final String zipPath;
  final String tempDirPath;
  const _ZipExtractParams({required this.zipPath, required this.tempDirPath});
}

/// Extraction outcome (sendable: List<String> + String?).
class _ZipExtractResult {
  final List<String> files;
  final String? error;
  const _ZipExtractResult(this.files, {this.error});
}

/// Stream-extract character-card entries from a ZIP into [params.tempDirPath].
///
/// Runs off the UI isolate. Memory model (archive 3.6.1):
///   - decodeBuffer(InputFileStream): the ZIP structure is parsed as zero-copy
///     file-stream references (InputFileStream.readBytes returns a clone view,
///     FileBuffer pages through a 1 MB window) — the archive is NOT loaded.
///   - entry.content inflates only the single accessed entry;
///     entry.clear() releases it right after the write.
/// Peak memory = largest single entry, regardless of archive size (1 GB+ OK).
/// No size cap by product requirement; a central-directory advisory log is kept
/// for zip-bomb visibility only.
Future<_ZipExtractResult> _extractZipToTemp(_ZipExtractParams params) async {
  try {
    final zipFile = File(params.zipPath);
    if (!await zipFile.exists()) {
      return const _ZipExtractResult([], error: 'ZIP 文件不存在');
    }
    final outDir = Directory(params.tempDirPath);
    await outDir.create(recursive: true);

    final input = InputFileStream(params.zipPath);
    try {
      final archive = ZipDecoder().decodeBuffer(input);

      // Zip-bomb advisory only (no hard limit): sizes come from the central
      // directory — no inflation happens in this loop.
      var claimed = 0;
      for (final f in archive.files) {
        claimed += f.size;
      }
      if (claimed > 10 * 1024 * 1024 * 1024) {
        debugPrint('[ZIP] 中心目录声称解压后 '
            '${(claimed / 1024 / 1024 / 1024).toStringAsFixed(1)} GB '
            '(无上限,流式按需解压)');
      }

      final extracted = <String>[];
      for (final entry in archive) {
        if (!entry.isFile) continue;
        final name = entry.name.split('/').last;
        final ext = name.split('.').last.toLowerCase();
        // Same card types as the original import switch; everything else skipped.
        if (ext != 'png' && ext != 'json' && ext != 'charx') continue;
        // Unique flattened name (timestamp + index): no path separators (zip-slip
        // impossible on a bare basename) and no cross-entry collisions.
        final outPath = p.join(outDir.path,
            '${DateTime.now().microsecondsSinceEpoch}_${extracted.length}_$name');
        final sink = await File(outPath).create(recursive: true);
        final fp = await sink.open(mode: FileMode.write);
        try {
          await fp.writeFrom(entry.content as List<int>);
        } finally {
          await fp.close();
        }
        entry.clear(); // release this entry's bytes before the next one
        extracted.add(outPath);
      }
      return _ZipExtractResult(extracted);
    } finally {
      await input.close();
    }
  } catch (e, st) {
    debugPrint('❌ [ZIP] 解压失败: $e\n$st');
    return _ZipExtractResult(const [], error: '$e');
  }
}
