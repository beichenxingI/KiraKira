import 'dart:io';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kirakira/data/models/character.dart';
import 'package:kirakira/data/repositories/character_repository.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/providers/character_providers.dart';
import 'package:kirakira/presentation/providers/chat_providers.dart';
import 'package:kirakira/presentation/theme/app_theme.dart';
import 'package:kirakira/presentation/widgets/common/character_avatar_image.dart';
import '../../widgets/common/greeting_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kirakira/presentation/screens/import/import_screen.dart' show importServiceProvider;
import 'package:kirakira/data/models/world_info.dart';
import 'package:kirakira/presentation/providers/world_info_providers.dart';
import 'package:kirakira/presentation/screens/world_info/world_info_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:kirakira/core/utils/path_utils.dart';

/// Provider for loading a single character by ID
final characterDetailProvider = FutureProvider.family<Character?, String>((ref, id) async {
  final repo = ref.watch(characterRepositoryProvider);
  return repo.getCharacter(id);
});

/// Character detail screen
class CharacterDetailScreen extends ConsumerWidget {
  final String characterId;

  const CharacterDetailScreen({
    super.key,
    required this.characterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final characterAsync = ref.watch(characterDetailProvider(characterId));
    
    return characterAsync.when(
      data: (character) {
        if (character == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.characterNotFound)),
            body: Center(
              child: Text(l10n.characterNotFoundMessage),
            ),
          );
        }
        return _CharacterDetailContent(character: character);
      },
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: Text(l10n.error)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('${l10n.error}: $error'),
            ],
          ),
        ),
      ),
    );
  }
}

class _CharacterDetailContent extends ConsumerStatefulWidget {
  final Character character;

  const _CharacterDetailContent({required this.character});

  @override
  ConsumerState<_CharacterDetailContent> createState() => _CharacterDetailContentState();
}

class _CharacterDetailContentState extends ConsumerState<_CharacterDetailContent> {
  bool _isCreatingChat = false;

  late Character _character;

  @override
  void initState() {
    super.initState();
    _character = widget.character;
  }

  // 统一的字段保存：传入"基于新值生成的 character"
  Future<void> _saveCharacter(Character updated) async {
    final saved = await ref.read(characterRepositoryProvider).updateCharacter(updated);
    if (mounted) setState(() => _character = saved);
    // 让详情页缓存失效，退出重进时重新从库读取
    ref.invalidate(characterDetailProvider(widget.character.id));
    // 列表页也刷新（名字/头像可能变了）
    ref.invalidate(characterListProvider);
  }

  Future<void> _startChat() async {
    if (_isCreatingChat) return;
    
    setState(() => _isCreatingChat = true);
    
    try {
      String? selectedGreeting;
      // 有备用开场白时，先让用户选
      if (widget.character.alternateGreetings.any((g) => g.trim().isNotEmpty)) {
        selectedGreeting = await showGreetingPicker(context, widget.character);
        // 用户取消则中止创建
        if (selectedGreeting == null || !mounted) {
          setState(() => _isCreatingChat = false);
          return;
        }
      }
      final chatId = await ref
          .read(activeChatProvider.notifier)
          .createChat(widget.character.id, selectedGreeting: selectedGreeting);
      
      if (chatId != null && mounted) {
        context.push('/chat/$chatId');
      } else if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToCreateChat)),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingChat = false);
      }
    }
  }

  Future<void> _handleMenuAction(String action, Character character) async {
    switch (action) {
      case 'delete':
        await _confirmDelete(character);
        break;
      case 'duplicate':
        await _duplicateCharacter(character);
        break;
      case 'export':
        await _exportCharacter(character, 'png');
        break;
      case 'export_json':
        await _exportCharacter(character, 'json');
        break;
      case 'export_charx':
        await _exportCharacter(character, 'charx');
        break;
    }
  }
  /// 导出角色卡：生成字节 → 写临时文件 → 系统分享面板
  /// asCharx=false 走 PNG（内嵌 chara 数据，兼容 SillyTavern）；true 走 CharX 压缩包
  Future<void> _exportCharacter(Character character, String format) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final importService = ref.read(importServiceProvider);

      // 读取头像字节：avatarPath 存的是相对路径，需转绝对路径（与 UI 显示一致），
      // 否则 File(相对路径).exists() 恒为 false，导致导出丢封面
      Uint8List? avatarData;
      final rawAvatarPath = character.assets?.avatarPath;
      if (rawAvatarPath != null) {
        final absPath = await PathUtils.toAbsolutePath(rawAvatarPath);
        final f = File(absPath);
        if (await f.exists()) {
          avatarData = await f.readAsBytes();
        }
      }

      // 文件名安全化：去掉可能破坏路径的字符
      final safeName = character.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final dir = await getTemporaryDirectory();

      // 按格式生成对应字节并落地
      late final File file;
      switch (format) {
        case 'json':
          final jsonStr = importService.exportToJson(character);
          file = File('${dir.path}/$safeName.json');
          await file.writeAsString(jsonStr);
          break;
        case 'charx':
          final bytes = await importService.exportToCharX(character, avatarData);
          file = File('${dir.path}/$safeName.charx');
          await file.writeAsBytes(bytes);
          break;
        case 'png':
        default:
          final bytes = await importService.exportToPng(character, avatarData);
          file = File('${dir.path}/$safeName.png');
          await file.writeAsBytes(bytes);
          break;
      }

      // 弹系统分享面板，用户自己选存哪/发给谁
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: character.name),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${l10n.error}: $e')),
      );
    }
  }
  /// 底部操作面板：导出/复制/删除。统一的操作菜单样式，替代默认下拉菜单。
  void _showActionSheet(Character character) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              title: Text(l10n.exportAsPng),
              onTap: () {
                Navigator.pop(sheetContext);
                _handleMenuAction('export', character);
              },
            ),
            ListTile(
              title: Text(l10n.exportAsJson),
              onTap: () {
                Navigator.pop(sheetContext);
                _handleMenuAction('export_json', character);
              },
            ),
            ListTile(
              title: Text(l10n.exportAsCharx),
              onTap: () {
                Navigator.pop(sheetContext);
                _handleMenuAction('export_charx', character);
              },
            ),
            ListTile(
              title: Text(l10n.duplicate),
              onTap: () {
                Navigator.pop(sheetContext);
                _handleMenuAction('duplicate', character);
              },
            ),
            ListTile(
              title: Text(
                l10n.delete,
                style: const TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _handleMenuAction('delete', character);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }


  Future<void> _confirmDelete(Character character) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteCharacter),
        content: Text(l10n.deleteCharacterConfirmationSimple(character.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        // Use characterListProvider.notifier to ensure list gets refreshed
        await ref.read(characterListProvider.notifier).deleteCharacter(character.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.characterDeleted)),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.failedToDelete(e.toString()))),
          );
        }
      }
    }
  }

  Future<void> _duplicateCharacter(Character character) async {
    final l10n = AppLocalizations.of(context);
    try {
      final repo = ref.read(characterRepositoryProvider);
      final newCharacter = character.copyWith(
        id: '',
        name: '${character.name} (copy)',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      );
      await repo.createCharacter(newCharacter);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.characterDuplicated(character.name))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToDuplicate(e.toString()))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final character = _character;
    
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                character.name,
                style: const TextStyle(
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                ),
              ),
              background: GestureDetector(
                onTap: _showCoverOptions,
                // 条目2:Hero 拆除——封面随圆形炸开转场与整页一体揭开
                child: _buildAvatarBackground(character),
              ),
            ),
            actions: [

              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => _showActionSheet(character),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: DesignTokens.paddingCard,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tags
                  if (character.tags.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: character.tags.map((tag) => Chip(
                        label: Text(tag),
                        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      )).toList(),
                    ),
                  if (character.tags.isNotEmpty) const SizedBox(height: 16),

                  // Creator info
                  Row(
                    children: [
                      if (character.creator.isNotEmpty) ...[
                        Icon(Icons.person_outline, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                        const SizedBox(width: 4),
                        Text(
                          l10n.byCreator(character.creator),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      if (character.version.isNotEmpty) ...[
                        Icon(Icons.update, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                        const SizedBox(width: 4),
                        Text(
                          l10n.versionLabel(character.version),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                   // Description section
                  _SectionCard(
                    title: l10n.description,
                    content: character.description,
                    icon: Icons.description,
                    onSave: (v) => _saveCharacter(_character.copyWith(description: v)),
                  ),
                  const SizedBox(height: 10),

                  // Personality section
                  _SectionCard(
                    title: l10n.personality,
                    content: character.personality,
                    icon: Icons.psychology,
                    onSave: (v) => _saveCharacter(_character.copyWith(personality: v)),
                  ),
                  const SizedBox(height: 10),

                  // Scenario section
                  _SectionCard(
                    title: l10n.scenario,
                    content: character.scenario,
                    icon: Icons.movie,
                    onSave: (v) => _saveCharacter(_character.copyWith(scenario: v)),
                  ),
                  const SizedBox(height: 10),

                  // First message section
                  _SectionCard(
                    title: l10n.firstMessage,
                    content: character.firstMessage,
                    icon: Icons.chat_bubble,
                    onSave: (v) => _saveCharacter(_character.copyWith(firstMessage: v)),
                  ),
                  const SizedBox(height: 10),

                  // Alternate greetings section
                  _AlternateGreetingsCard(
                    greetings: character.alternateGreetings,
                    onSaveGreeting: (index, value) {
                      final updated = List<String>.from(_character.alternateGreetings);
                      updated[index] = value;
                      return _saveCharacter(_character.copyWith(alternateGreetings: updated));
                    },
                    onAddGreeting: (value) {
                      final updated = List<String>.from(_character.alternateGreetings)..add(value);
                      return _saveCharacter(_character.copyWith(alternateGreetings: updated));
                    },
                  ),
                  const SizedBox(height: 10),

                  // Example messages section
                  _SectionCard(
                    title: l10n.exampleMessages,
                    content: character.exampleMessages,
                    icon: Icons.format_quote,
                    onSave: (v) => _saveCharacter(_character.copyWith(exampleMessages: v)),
                  ),
                  const SizedBox(height: 10),

                  // System prompt section
                  _SectionCard(
                    title: l10n.systemPrompt,
                    content: character.systemPrompt,
                    icon: Icons.settings_suggest,
                    onSave: (v) => _saveCharacter(_character.copyWith(systemPrompt: v)),
                  ),
                  const SizedBox(height: 10),

                  // Post-history instructions section
                  _SectionCard(
                    title: l10n.postHistoryInstructions,
                    content: character.postHistoryInstructions,
                    icon: Icons.rule,
                    onSave: (v) => _saveCharacter(_character.copyWith(postHistoryInstructions: v)),
                  ),
                  const SizedBox(height: 10),

                  // Creator notes section
                  _SectionCard(
                    title: l10n.creatorNotes,
                    content: character.creatorNotes,
                    icon: Icons.note,
                    onSave: (v) => _saveCharacter(_character.copyWith(creatorNotes: v)),
                  ),
                  const SizedBox(height: 10),
                  
                  // Embedded Lorebook section
                  _CharacterBookCard(characterId: character.id),
                  const SizedBox(height: 16),
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: Icon(Icons.find_replace, color: Theme.of(context).colorScheme.secondary),
                        title: const Text('角色正则脚本'),
                        subtitle: const Text('Regex Scripts · 仅对此角色生效'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/characters/${character.id}/regex'),
                      ),
                    ),
                  
                  const SizedBox(height: 80), // Space for FAB
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isCreatingChat ? null : _startChat,
        icon: _isCreatingChat
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.chat),
        label: Text(_isCreatingChat ? l10n.creating : l10n.startChat),
      ),
    );
  }

  Widget _buildAvatarBackground(Character character) {
    final coverImage = character.assets?.avatarPath;
    if (coverImage != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          CharacterAvatarImage(
            imagePath: coverImage,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _defaultBackground(),
          ),
          // Gradient overlay for better text readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.7),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return _defaultBackground();
  }
  void _showCoverOptions() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () {
                Navigator.pop(ctx);
                _pickCoverFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('从文件选择'),
              onTap: () {
                Navigator.pop(ctx);
                _pickCoverFromFiles();
              },
            ),
            if (_character.assets?.avatarPath != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('移除封面', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _saveCharacter(_character.copyWith(
                    assets: (_character.assets ?? const CharacterAssets())
                        .copyWith(coverPath: null),
                  ));
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCoverFromGallery() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image != null) await _saveCoverImage(image.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.failedToPickImage(e.toString()))),
        );
      }
    }
  }

  Future<void> _pickCoverFromFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.first.path != null) {
        await _saveCoverImage(result.files.first.path!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.failedToPickImage(e.toString()))),
        );
      }
    }
  }

  Future<void> _saveCoverImage(String sourcePath) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory(p.join(appDir.path, 'KiraKira', 'covers'));
      await coversDir.create(recursive: true);

      final newFileName = '${const Uuid().v4()}${p.extension(sourcePath)}';
      final newPath = p.join(coversDir.path, newFileName);
      await File(sourcePath).copy(newPath);

      await _saveCharacter(_character.copyWith(
        assets: (_character.assets ?? const CharacterAssets())
            .copyWith(avatarPath: newPath),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.failedToSaveAvatar(e.toString()))),
        );
      }
    }
  }

  Widget _defaultBackground() {
    return Container(
      color: Theme.of(context).cardColor,
      child: Center(
        child: Icon(
          Icons.person,
          size: 120,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _SectionCard extends StatefulWidget {
  final String title;
  final String content;
  final IconData icon;
  final int maxLines;
  final Future<void> Function(String newContent)? onSave; // 新增：保存回调，null 则不可编辑

  const _SectionCard({
    required this.title,
    required this.content,
    required this.icon,
    this.maxLines = 10,
    this.onSave,
  });

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  bool _expanded = false;
  bool _editing = false;
  bool _saving = false;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.content);
  }

  @override
  void didUpdateWidget(_SectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部内容变了且当前不在编辑，同步进输入框
    if (!_editing && oldWidget.content != widget.content) {
      _controller.text = widget.content;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.content));
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${l10n.copiedToClipboard}: ${widget.title}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _startEdit() {
    _controller.text = widget.content;
    setState(() => _editing = true);
  }

  void _cancelEdit() {
    _controller.text = widget.content; // 恢复原值
    setState(() => _editing = false);
  }

  Future<void> _saveEdit() async {
    if (widget.onSave == null) return;
    setState(() => _saving = true);
    try {
      await widget.onSave!(_controller.text.trim());
      if (mounted) setState(() => _editing = false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final lines = widget.content.split('\n');
    final shouldShowExpand = lines.length > widget.maxLines || widget.content.length > 500;
    final displayContent = _expanded || !shouldShowExpand
        ? widget.content
        : '${widget.content.substring(0, widget.content.length.clamp(0, 500))}...';

    return GestureDetector(
      onLongPress: _editing ? null : _copyToClipboard,
      child: Card(
        // iOS 质感：大圆角 + 柔和阴影
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusCard)),
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
            // 实色（跟随主题），消除半透明合成开销
            color: theme.cardColor,
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
            // 宪法:卡片阴影仅 shadowLevel1
            boxShadow: DesignTokens.shadowLevel1,
          ),
          child: Padding(
            padding: DesignTokens.paddingCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(widget.icon, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                      ),
                    ),
                    if (!_editing) ...[
                      if (widget.content.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: _copyToClipboard,
                          tooltip: l10n.copiedToClipboard,
                        ),
                      if (widget.onSave != null)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: _startEdit,
                          tooltip: '编辑',
                        ),
                      if (shouldShowExpand)
                        IconButton(
                          icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                          onPressed: () => setState(() => _expanded = !_expanded),
                          tooltip: _expanded ? l10n.showLess : l10n.showMore,
                        ),
                    ],
                  ],
                ),
                const SizedBox(height: DesignTokens.spaceSm),
                if (_editing) ...[
                  TextField(
                    controller: _controller,
                    maxLines: null, // 自动撑高，占满整块宽度，不受弹窗限制
                    minLines: 4,
                    autofocus: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                      ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spaceMd,
                      vertical: DesignTokens.spaceSm,
                    ),
                    ),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: DesignTokens.spaceSm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _saving ? null : _cancelEdit,
                        child: const Text('取消'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _saving ? null : _saveEdit,
                        child: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('保存'),
                      ),
                    ],
                  ),
                ] else if (widget.content.isEmpty)
                  InkWell(
                    onTap: widget.onSave != null ? _startEdit : null,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Icon(Icons.add, size: 16, color: mutedColor),
                        const SizedBox(width: 6),
                        Text(
                          '点击添加${widget.title}',
                          style: theme.textTheme.bodyMedium?.copyWith(color: mutedColor),
                        ),
                      ]),
                    ),
                  )
                else
                  Text(
                    displayContent,
                    style: theme.textTheme.bodyMedium,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AlternateGreetingsCard extends StatefulWidget {
  final List<String> greetings;
  final Future<void> Function(int index, String value)? onSaveGreeting;
  final Future<void> Function(String value)? onAddGreeting;

  const _AlternateGreetingsCard({
    required this.greetings,
    this.onSaveGreeting,
    this.onAddGreeting,
  });

  @override
  State<_AlternateGreetingsCard> createState() => _AlternateGreetingsCardState();
}

class _AlternateGreetingsCardState extends State<_AlternateGreetingsCard> {
  void _copyGreeting(BuildContext context, String greeting, int index) {
    Clipboard.setData(ClipboardData(text: greeting));
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${l10n.copiedToClipboard}: ${l10n.greetingNumber(index + 1)}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _copyAllGreetings(BuildContext context) {
    final allText = widget.greetings.asMap().entries
        .map((e) => '--- Greeting ${e.key + 1} ---\n${e.value}')
        .join('\n\n');
    Clipboard.setData(ClipboardData(text: allText));
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${l10n.copiedToClipboard}: ${l10n.alternateGreetingsCount(widget.greetings.length)}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _addGreeting(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _GreetingEditSheet(
        title: '新增备用开场白',
        initialText: '',
        onSubmit: (text) async {
          if (widget.onAddGreeting != null) await widget.onAddGreeting!(text);
        },
      ),
    );
  }
  void _editGreeting(BuildContext context, int index, String current) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _GreetingEditSheet(
        title: l10n.greetingNumber(index + 1),
        initialText: current,
        onSubmit: (text) async {
          if (widget.onSaveGreeting != null) {
            await widget.onSaveGreeting!(index, text);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusCard)),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
          color: theme.cardColor,
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
              padding: DesignTokens.paddingCard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.waving_hand, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.alternateGreetingsCount(widget.greetings.length),
                      style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_all, size: 18),
                    onPressed: () => _copyAllGreetings(context),
                    tooltip: l10n.copiedToClipboard,
                  ),
                  if (widget.onAddGreeting != null)
                    IconButton(
                      icon: const Icon(Icons.add, size: 20),
                      onPressed: () => _addGreeting(context),
                      tooltip: '新增',
                    ),
                ],
              ),
              const SizedBox(height: DesignTokens.spaceSm),
              ...widget.greetings.asMap().entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
                    child: GestureDetector(
                      onLongPress: () => _copyGreeting(context, entry.value, entry.key),
                      child: Container(
            padding: DesignTokens.paddingCard,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    l10n.greetingNumber(entry.key + 1),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                          color: mutedColor,
                                        ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 14),
                                  onPressed: () => _copyGreeting(context, entry.value, entry.key),
                                  tooltip: l10n.copiedToClipboard,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                if (widget.onSaveGreeting != null) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 14),
                                    onPressed: () => _editGreeting(context, entry.key, entry.value),
                                    tooltip: '编辑',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.value.length > 200
                                  ? '${entry.value.substring(0, 200)}...'
                                  : entry.value,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _CharacterBookCard extends ConsumerWidget {
  final String characterId;

  const _CharacterBookCard({required this.characterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final worldInfosAsync = ref.watch(characterWorldInfosProvider(characterId));

    return worldInfosAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: DesignTokens.paddingCard,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (worldInfos) {
        final theme2 = Theme.of(context);
        // A2修复:优先展示第一本【有条目】的书,自动空壳(0条)不再遮蔽真书
        WorldInfo? worldInfo;
        for (final w in worldInfos) {
          if (w.entries.isNotEmpty) {
            worldInfo = w;
            break;
          }
        }
        worldInfo ??= worldInfos.isEmpty ? null : worldInfos.first;
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusCard)),
          elevation: 0,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
              color: theme2.cardColor,
              border: Border.all(color: theme2.dividerColor.withValues(alpha: 0.5)),
            ),
            child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMd, vertical: DesignTokens.spaceSm),
              leading: Icon(Icons.auto_stories, color: theme2.colorScheme.primary),
              title: Text(
                worldInfo?.name ?? '世界书',
                style: theme2.textTheme.titleMedium?.copyWith(
                  color: theme2.colorScheme.primary,
                ),
              ),
              subtitle: worldInfo == null
                  ? Text('暂无世界书，点击创建', style: TextStyle(color: mutedColor))
                  : Text(
                      '${worldInfo.entries.where((e) => e.enabled).length} / ${worldInfo.entries.length} 条已启用',
                      style: TextStyle(color: mutedColor),
                    ),
              trailing: Icon(Icons.chevron_right, color: mutedColor),
              onTap: worldInfo == null
                  // A3-T4: 列表页已删,无书时不再跳转(创建走编辑器 WorldBook tab)
                  ? null
                  : () {
                      final wi = worldInfo;
                      if (wi == null) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WorldInfoEntriesScreen(worldInfo: wi),
                        ),
                      );
                    },
            ),
          ),
        );
      },
    );
  }
}
/// 备用开场白编辑/新增的底部弹窗内容(独立 StatefulWidget，
/// 自己持有 controller 并在 dispose 清理，避免依赖在 teardown 时未清导致的
/// _dependents.isEmpty 断言红屏)。
class _GreetingEditSheet extends StatefulWidget {
  final String title;
  final String initialText;
  final Future<void> Function(String value) onSubmit;

  const _GreetingEditSheet({
    required this.title,
    required this.initialText,
    required this.onSubmit,
  });

  @override
  State<_GreetingEditSheet> createState() => _GreetingEditSheetState();
}

class _GreetingEditSheetState extends State<_GreetingEditSheet> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.onSubmit(text);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceSm),
            Flexible(
              child: SingleChildScrollView(
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  minLines: 4,
                  autofocus: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceMd,
                    vertical: DesignTokens.spaceSm,
                  ),
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}