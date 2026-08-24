import 'dart:io';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kirakira/data/models/character.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/providers/character_grid_provider.dart';
import 'package:kirakira/presentation/providers/character_providers.dart';
import 'package:kirakira/presentation/router/app_router.dart';
import 'package:kirakira/presentation/widgets/common/character_avatar_image.dart';
import 'package:kirakira/presentation/widgets/common/kira_search_bar.dart';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:kirakira/presentation/screens/import/import_screen.dart' show importServiceProvider;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:kirakira/presentation/providers/world_info_providers.dart';
import 'package:kirakira/data/repositories/character_repository.dart';
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

  /// C-T6 内存分页:已加载批数(每批 = 每页数量设置)
  int _loadedPages = 1;
  final ScrollController _scrollController = ScrollController();
  // ── 多选状态（仅标准网格支持）──
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

  /// 批量删除：确认后循环删除，刷新列表
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

  /// 批量打包为 ZIP：选格式 → 循环导出 → 打包 → 分享
  Future<void> _exportSelectedAsZip(List<Character> all) async {
    final selected = all.where((c) => _selectedIds.contains(c.id)).toList();
    if (selected.isEmpty) return;

    // 选格式（默认 PNG）
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

    // 打包 loading —— 保存 navigator 引用，避免异步后 context 失效关不掉
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
        navigator.pop(); // 关的一定是这个 loading
      }
    }

    try {
      final importService = ref.read(importServiceProvider);
      final archive = Archive();
      final usedNames = <String>{};

      for (final c in selected) {
        // 读头像：avatarPath 存的是相对路径，导出前需转绝对路径（与 UI 显示一致）
        Uint8List? avatarData;
        final rawAvatarPath = c.assets?.avatarPath;
        if (rawAvatarPath != null) {
          final absPath = await PathUtils.toAbsolutePath(rawAvatarPath);
          final f = File(absPath);
          if (await f.exists()) avatarData = await f.readAsBytes();
        }

        // 文件名安全化 + 去重
        var safeName = c.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        if (safeName.isEmpty) safeName = c.id;
        var fileName = safeName;
        var dup = 1;
        final ext = format == 'json' ? 'json' : (format == 'charx' ? 'charx' : 'png');
        while (usedNames.contains('$fileName.$ext')) {
          fileName = '${safeName}_${dup++}';
        }
        usedNames.add('$fileName.$ext');

        // 按格式生成字节
        final List<int> bytes;
        switch (format) {
          case 'json':
            bytes = utf8.encode(importService.exportToJson(c));
            break;
          case 'charx':
            bytes = await importService.exportToCharX(c, avatarData);
            break;
          default:
            bytes = await importService.exportToPng(c, avatarData);
        }
        archive.addFile(ArchiveFile('$fileName.$ext', bytes.length, bytes));
      }

      final zipBytes = ZipEncoder().encode(archive)!;
      final ts = DateTime.now();
      final stamp = '${ts.year}${_two(ts.month)}${_two(ts.day)}_'
          '${_two(ts.hour)}${_two(ts.minute)}${_two(ts.second)}';
      final dir = await getTemporaryDirectory();
      final zipFile = File('${dir.path}/KiraKira_$stamp.zip');
      await zipFile.writeAsBytes(zipBytes);

      closeLoading(); // 先关 loading
      _exitSelection();

      await SharePlus.instance.share(
        ShareParams(files: [XFile(zipFile.path)], subject: 'KiraKira_$stamp'),
      );
    } catch (e, st) {
      debugPrint('❌ 批量导出ZIP失败: $e\n$st');
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    } finally {
      closeLoading(); // 无论成败，loading 一定被关掉，杜绝黑屏
    }
  }

  /// 导入 ZIP：选压缩包 → 解包 → 按扩展名逐个还原角色
  Future<void> _importFromZip() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.files.isEmpty) return;
    final zipFile = result.files.first;

    // 拿字节：优先 bytes，否则从 path 读（兼容 content:// 场景）
    Uint8List? zipBytes = zipFile.bytes;
    if (zipBytes == null && zipFile.path != null) {
      zipBytes = await File(zipFile.path!).readAsBytes();
    }
    if (zipBytes == null) return;

    if (!mounted) return;
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
        navigator.pop();
      }
    }

    int ok = 0, fail = 0;
    try {
      final importService = ref.read(importServiceProvider);
      final repo = ref.read(characterRepositoryProvider);
      final worldInfoRepo = ref.read(worldInfoRepositoryProvider);
      final archive = ZipDecoder().decodeBytes(zipBytes);
      final tmpDir = await getTemporaryDirectory();

      for (final entry in archive) {
        if (!entry.isFile) continue;
        final name = entry.name.split('/').last;
        final ext = name.split('.').last.toLowerCase();
        try {
          Character c;
          switch (ext) {
            case 'png':
              c = await importService.importFromPngBytes(
                  Uint8List.fromList(entry.content as List<int>));
              break;
            case 'json':
              c = await importService.importFromJson(
                  utf8.decode(entry.content as List<int>));
              break;
            case 'charx':
              final f = File(p.join(tmpDir.path,
                  '${DateTime.now().microsecondsSinceEpoch}_$name'));
              await f.writeAsBytes(entry.content as List<int>);
              c = await importService.importFromCharX(f.path);
              break;
            default:
              continue; // 非角色卡文件跳过
          }
          // 入库（正则随 extensions 一起进库）
          final created = await repo.createCharacter(c);
          // 提取内嵌世界书为独立 WorldInfo（复用单个导入逻辑）
          if (c.characterBook != null && c.characterBook!.entries.isNotEmpty) {
            await importEmbeddedLorebook(
                worldInfoRepo, created.id, c.characterBook!, created.name);
          }
          ok++;
        } catch (e) {
          fail++;
          debugPrint('❌ ZIP内 $name 导入失败: $e');
        }
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
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('导入失败: $e')));
      }
    } finally {
      closeLoading();
    }
  }
  static String _two(int n) => n.toString().padLeft(2, '0');

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScrollLoadMore);
  }

  /// 触底续批(C-T6):剩余 <600px 且还有未渲染角色时追加一批
  void _onScrollLoadMore() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels > pos.maxScrollExtent - 600) {
      final pageSize = ref.read(characterGridPageSizeProvider);
      final total =
          ref.read(characterListProvider).valueOrNull?.length ?? 0;
      if (_loadedPages * pageSize < total) {
        setState(() => _loadedPages++);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final charactersAsync = ref.watch(characterListProvider);
    final pageSize = ref.watch(characterGridPageSizeProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // 不透明底，避免透出 shell 的聊天壁纸
      body: RefreshIndicator(
        // iOS 风下拉刷新(替代 AppBar 刷新按钮,C-T1)
        onRefresh: () async {
          ref.read(characterListProvider.notifier).refresh();
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // ── 常态:Large Title;选择态:收缩小标题(同一 CustomScrollView)──
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
              )
            else
              SliverAppBar.large(
                title: Text(
                  l10n.characters,
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                actions: [
                  // iOS 风格 "+":导入/ZIP 导入/新建 合流进 CupertinoActionSheet
                  IconButton(
                    icon: const Icon(CupertinoIcons.add),
                    tooltip: l10n.createCharacter,
                    onPressed: () => _showAddActionSheet(context),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.checkmark_circle),
                    tooltip: '选择',
                    onPressed: () {
                      final all = ref.read(characterListProvider).valueOrNull ?? [];
                      if (all.isNotEmpty) {
                        setState(() => _selectionMode = true);
                      }
                    },
                  ),
                  // C-T6:每页数量档位(4/8/12/16)
                  IconButton(
                    icon: const Icon(CupertinoIcons.square_grid_2x2),
                    tooltip: '每页数量',
                    onPressed: () => _showPageSizeSheet(context),
                  ),
                  const SizedBox(width: DesignTokens.spaceSm),
                ],
              ),
            // ── 搜索框:跟随滚入(不做死 pinned,KISS;C-T8 分段控件另起吸顶)──
            SliverToBoxAdapter(
              child: KiraSearchBar(
                controller: _searchController,
                hintText: l10n.searchCharacters,
                onChanged: (value) => setState(() {
                  _searchQuery = value;
                  _loadedPages = 1; // 搜索词变化回到第一批(C-T6)
                }),
                onClear: () => setState(() {
                  _searchQuery = '';
                  _loadedPages = 1;
                }),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: DesignTokens.spaceSm)),
            // ── 内容区 ──
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

                // C-T6:内存切片——首屏 pageSize 个,触底续批
                final visible =
                    filtered.take(pageSize * _loadedPages).toList();

                return [
                  _CharacterGridView(
                    characters: visible,
                    selectionMode: _selectionMode,
                    selectedIds: _selectedIds,
                    onTap: (id) {
                      if (_selectionMode) {
                        _toggleSelect(id);
                      } else {
                        context.push('/characters/$id');
                      }
                    },
                    onLongPress: (id) {
                      if (!_selectionMode) _enterSelection(id);
                      else _toggleSelect(id);
                    },
                  ),
                ];
              },
              loading: () => const [_SkeletonGrid()],
              error: (error, stack) => [
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
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
            // 底部避让底栏(胶囊高 62 + 下边距 12 + 呼吸)
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }

  /// iOS 风格新增菜单(C-T1:FAB 三入口 → 右上 "+" ActionSheet)
  void _showAddActionSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetCtx) => CupertinoTheme(
        // MaterialApp 下兜底:深色下 CupertinoActionSheet 文字走暗色(C-表 #10)
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
                context.push(AppRoutes.characterCreate);
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

  /// C-T6:每页数量档位选择(4/8/12/16,持久化 character_grid_page_size)
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
                  setState(() => _loadedPages = 1); // 档位变了回到第一批
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

class _CharacterGridView extends StatelessWidget {
  final List<Character> characters;
  final bool selectionMode;
  final Set<String> selectedIds;
  final void Function(String id) onTap;
  final void Function(String id) onLongPress;

  const _CharacterGridView({
    required this.characters,
    required this.selectionMode,
    required this.selectedIds,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.spaceMd,
        DesignTokens.spaceSm,
        DesignTokens.spaceMd,
        0,
      ),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.72,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final c = characters[index];
            return _StaggeredEntrance(
              index: index,
              child: _CharacterGridCard(
                character: c,
                selectionMode: selectionMode,
                isSelected: selectedIds.contains(c.id),
                onTap: () => onTap(c.id),
                onLongPress: () => onLongPress(c.id),
              ),
            );
          },
          childCount: characters.length,
        ),
      ),
    );
  }
}

/// 列表项进场:错峰 50ms 淡入上移(宪法 §五)
class _StaggeredEntrance extends StatelessWidget {
  final int index;
  final Widget child;

  const _StaggeredEntrance({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    const duration = DesignTokens.durationMd;
    // 错峰上限 12 项,避免长列表尾部等待过久
    final delay = index.clamp(0, 12) * 50;
    final total = duration + delay;
    final intervalBegin = delay / total;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(
        intervalBegin,
        1,
        curve: DesignTokens.curveDecelerate,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

// TODO(token·待批准): skeletonBase/skeletonHighlight 微光扫动,
// 提案见总纲 §4。未批准前用 darkCard 实底呼吸兜底。

/// 加载骨架:实底 + 400ms 呼吸(0.5↔1.0)
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
          childAspectRatio: 0.72,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
      ),
    );
  }
}

/// 呼吸骨架块:实底 + 透明度呼吸
class _BreathingBox extends StatefulWidget {
  final double borderRadius;
  final double? height;

  const _BreathingBox({required this.borderRadius, this.height});

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
        height: widget.height,
        decoration: BoxDecoration(
          color: isDark ? DesignTokens.darkCard : DesignTokens.lightSeparator,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 空态图标容器:胶囊圆角 + muted 色(宪法视觉降噪)
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
                onPressed: () => context.push(AppRoutes.characterCreate),
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
        // C-T7:卡片圆角随卡片级别,深色零阴影(A-T1 铁律),浅色 0.5 separator
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
                  Expanded(flex: 4, child: _buildAvatar()),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spaceSm,
                      vertical: DesignTokens.spaceXs,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          character.name,
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
    // 宪法 §五命门:列表卡→详情页容器变换 Hero(tag 契约:character-<id>)
    return Hero(
      tag: 'character-${character.id}',
      child: avatar,
    );
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
        return const Color(0xFFF5AEB2); // KiraKira 粉,替代死蓝占位
    }
  }
}