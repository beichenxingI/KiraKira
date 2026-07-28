import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kirakira/data/models/character.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/providers/character_providers.dart';
import 'package:kirakira/presentation/providers/chat_providers.dart';
import 'package:kirakira/presentation/router/app_router.dart';
import 'package:kirakira/presentation/theme/app_theme.dart';
import 'package:kirakira/presentation/widgets/common/character_avatar_image.dart';
import 'character_view_mode.dart';
import '../../widgets/common/greeting_picker.dart';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:kirakira/presentation/screens/import/import_screen.dart' show importServiceProvider;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

/// Character list screen
class CharacterListScreen extends ConsumerStatefulWidget {
  const CharacterListScreen({super.key});

  @override
  ConsumerState<CharacterListScreen> createState() => _CharacterListScreenState();
}

class _CharacterListScreenState extends ConsumerState<CharacterListScreen> {
  String _searchQuery = '';
  CharacterViewMode _viewMode = CharacterViewMode.grid;

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
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
        // 读头像
        Uint8List? avatarData;
        final avatarPath = c.assets?.avatarPath;
        if (avatarPath != null) {
          final f = File(avatarPath);
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
      final archive = ZipDecoder().decodeBytes(zipBytes);
      final tmpDir = await getTemporaryDirectory();

      for (final entry in archive) {
        if (!entry.isFile) continue;
        final name = entry.name.split('/').last;
        final ext = name.split('.').last.toLowerCase();
        try {
          switch (ext) {
            case 'png':
              await importService.importFromPngBytes(
                  Uint8List.fromList(entry.content as List<int>));
              break;
            case 'json':
              await importService.importFromJson(
                  utf8.decode(entry.content as List<int>));
              break;
            case 'charx':
              // charx 走文件路径：先落临时文件
              final f = File(p.join(tmpDir.path,
                  '${DateTime.now().microsecondsSinceEpoch}_$name'));
              await f.writeAsBytes(entry.content as List<int>);
              await importService.importFromCharX(f.path);
              break;
            default:
              continue; // 非角色卡文件跳过
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final charactersAsync = ref.watch(characterListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e), // 不透明底，避免透出 shell 的聊天壁纸
      appBar: _selectionMode
          ? AppBar(
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
          : AppBar(
              title: Text(l10n.characters),
              actions: [
                // TODO(UI大修): 视图切换按钮已隐藏，当前锁定标准网格（唯一支持多选）
                // 大修时按需恢复或彻底移除，连同 CharacterViewMode、_getViewModeIcon 一并清理
                // IconButton(
                //   icon: _getViewModeIcon(),
                //   onPressed: () => setState(() => _viewMode = _viewMode.next),
                //   tooltip: _viewMode.getDisplayName(l10n),
                // ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: l10n.retry,
                  onPressed: () => ref.read(characterListProvider.notifier).refresh(),
                ),
              ],
            ),
      body: Column(
        children: [
          _SearchBar(
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          Expanded(
            child: charactersAsync.when(
              data: (characters) {
                final filtered = _searchQuery.isEmpty
                    ? characters
                    : characters.where((c) => 
                        c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                        c.description.toLowerCase().contains(_searchQuery.toLowerCase())
                      ).toList();

                if (filtered.isEmpty) {
                  return const _EmptyState();
                }

                switch (_viewMode) {
                  case CharacterViewMode.list:
                    return _CharacterListView(characters: filtered);
                  case CharacterViewMode.grid:
                    return _CharacterGridView(
                      characters: filtered,
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
                    );
                  case CharacterViewMode.compactGrid:
                    return _CharacterCompactGridView(characters: filtered);
                }
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
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
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton(
          onPressed: () => _showFabMenu(context),
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }

  void _showFabMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.file_download_outlined, color: AppTheme.primaryColor),
              title: Text(l10n.importCharacter),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.pop(ctx);
                context.push(AppRoutes.import_);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.folder_zip_outlined, color: AppTheme.primaryColor),
              title: const Text('从ZIP批量导入'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.pop(ctx);
                _importFromZip();
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.add, color: AppTheme.primaryColor),
              title: Text(l10n.createCharacter),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.pop(ctx);
                context.push(AppRoutes.characterCreate);
              },
            ),
          ],
        ),
      ),
    );
  }

  Icon _getViewModeIcon() {
    switch (_viewMode) {
      case CharacterViewMode.list:
        return const Icon(Icons.list);
      case CharacterViewMode.grid:
        return const Icon(Icons.grid_view);
      case CharacterViewMode.compactGrid:
        return const Icon(Icons.view_compact);
    }
  }
}

class _SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: l10n.searchCharacters,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Show filter options
            },
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
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      cacheExtent: 1200,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: characters.length,
      itemBuilder: (context, index) {
        final c = characters[index];
        return _CharacterGridCard(
          character: c,
          selectionMode: selectionMode,
          isSelected: selectedIds.contains(c.id),
          onTap: () => onTap(c.id),
          onLongPress: () => onLongPress(c.id),
        );
      },
    );
  }
}

// TODO(UI大修): 此视图已弃用，当前锁定标准网格（_CharacterGridView，唯一支持多选）。
// 大修时应删除此类及 _CharacterCompactGridCard，连同 CharacterViewMode 枚举、切换逻辑一并清理。
class _CharacterListView extends StatelessWidget {
  final List<Character> characters;

  const _CharacterListView({required this.characters});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: characters.length,
      itemBuilder: (context, index) {
        return _CharacterListTile(character: characters[index]);
      },
    );
  }
}

// TODO(UI大修): 此视图已弃用，当前锁定标准网格（_CharacterGridView，唯一支持多选）。
// 大修时应删除此类及 _CharacterCompactGridCard，连同 CharacterViewMode 枚举、切换逻辑一并清理。
class _CharacterCompactGridView extends StatelessWidget {
  final List<Character> characters;

  const _CharacterCompactGridView({required this.characters});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.82,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: characters.length,
      itemBuilder: (context, index) {
        return _CharacterCompactGridCard(character: characters[index]);
      },
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
          Icon(
            Icons.people_outline,
            size: 80,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noCharactersYet,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.importCharacter,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted,
                ),
          ),
          const SizedBox(height: 24),
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  spreadRadius: -2,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        clipBehavior: Clip.antiAlias,
        color: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isSelected
              ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2.5)
              : BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Theme.of(context).dividerColor.withValues(alpha: 0.5),
                  width: 0.8,
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
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          character.name,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (character.creator.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'by ${character.creator}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: 11,
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
      ),
    );
  }

  Widget _buildAvatar() {
    return RepaintBoundary(
      child: character.assets?.avatarPath != null
          ? CharacterAvatarImage(
              imagePath: character.assets!.avatarPath!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _defaultAvatar(),
            )
          : _defaultAvatar(),
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

class _CharacterCompactGridCard extends ConsumerWidget {
  final Character character;

  const _CharacterCompactGridCard({required this.character});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/characters/${character.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 4,
              child: _buildCompactAvatar(),
            ),
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      character.name,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactAvatar() {
    if (character.assets?.avatarPath != null) {
      return CharacterAvatarImage(
        imagePath: character.assets!.avatarPath!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _defaultCompactAvatar(),
      );
    }
    return _defaultCompactAvatar();
  }

  Widget _defaultCompactAvatar() {
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
          size: 40,
          color: Colors.white,
        ),
      ),
    );
  }

  IconData _getCharacterIcon(Character character) {
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
    switch (character.id) {
      case 'builtin_coding_assistant':
        return const Color(0xFF2196F3);
      case 'builtin_image_gen_assistant':
        return const Color(0xFFE91E63);
      case 'builtin_xiaohongshu_copywriter':
        return const Color(0xFFFF5722);
      default:
        return AppTheme.darkDivider;
    }
  }
}

class _CharacterListTile extends ConsumerWidget {
  final Character character;

  const _CharacterListTile({required this.character});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _buildListAvatar(),
        title: Text(character.name),
        subtitle: Text(
          character.description.isNotEmpty
              ? character.description
              : l10n.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'chat',
              child: ListTile(
                leading: const Icon(Icons.chat),
                title: Text(l10n.startChat),
                contentPadding: EdgeInsets.zero,
              ),
              onTap: () => _startChat(context, ref),
            ),
            PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: const Icon(Icons.edit),
                title: Text(l10n.edit),
                contentPadding: EdgeInsets.zero,
              ),
              onTap: () => context.push('/characters/${character.id}'),
            ),
            PopupMenuItem(
              value: 'export',
              child: ListTile(
                leading: const Icon(Icons.file_upload),
                title: Text(l10n.exportChat),
                contentPadding: EdgeInsets.zero,
              ),
              onTap: () {
                // TODO: Export character
              },
            ),
            PopupMenuItem(
              value: 'delete',
              onTap: () => _confirmDelete(context, ref),
              child: ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        onTap: () => context.push('/characters/${character.id}'),
      ),
    );
  }

  Future<void> _startChat(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    
    try {
      String? selectedGreeting;
      if (character.alternateGreetings.any((g) => g.trim().isNotEmpty)) {
        selectedGreeting = await showGreetingPicker(context, character);
        if (selectedGreeting == null || !context.mounted) return;
      }
      final chatId = await ref
          .read(activeChatProvider.notifier)
          .createChat(character.id, selectedGreeting: selectedGreeting);
      if (chatId != null && context.mounted) {
        context.push('/chat/$chatId');
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.error)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteCharacter),
        content: Text(l10n.deleteCharacterConfirmation(character.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(characterListProvider.notifier).deleteCharacter(character.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.characterDeleted)),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  Widget _buildListAvatar() {
    if (character.assets?.avatarPath != null) {
      return CharacterAvatarCircle(
        imagePath: character.assets!.avatarPath!,
        radius: 28,
      );
    }

    final icon = _getCharacterIcon(character);
    final color = _getCharacterColor(character);

    return CircleAvatar(
      radius: 28,
      backgroundColor: color,
      child: Icon(
        icon,
        color: Colors.white,
        size: 28,
      ),
    );
  }

  IconData _getCharacterIcon(Character character) {
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
    switch (character.id) {
      case 'builtin_coding_assistant':
        return const Color(0xFF2196F3);
      case 'builtin_image_gen_assistant':
        return const Color(0xFFE91E63);
      case 'builtin_xiaohongshu_copywriter':
        return const Color(0xFFFF5722);
      default:
        return AppTheme.primaryColor;
    }
  }
}