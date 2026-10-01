import 'dart:io';
import 'dart:math' as Math;
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/models/character.dart';
import '../../data/models/regex_script.dart';
import '../../data/models/world_info.dart';
import '../components/kira_accordion_card.dart';
import '../components/kira_dialog_theme.dart';
import '../components/kira_dialog_widgets.dart';
import '../components/kira_input_dialog.dart';
import '../components/kira_toast.dart';
import '../providers/character_providers.dart';
import '../providers/chat_providers.dart' show activeChatProvider;
import '../../data/repositories/character_repository.dart';
import '../../domain/services/import_service.dart' show assembleCharacterBookFromRepo;
import '../providers/regex_providers.dart';
import '../providers/world_info_providers.dart';
import '../theme/design_tokens.dart';
import '../utils/export_delivery.dart';
import '../widgets/common/character_avatar_image.dart';
import 'character_regex_dialog.dart';
import 'regex_rule_edit_dialog.dart';
import 'worldbook_editor_dialog.dart';
import 'worldbook_entry_edit_dialog.dart';

void showCharacterEditDialog(
  BuildContext context,
  WidgetRef ref, {
  Character? character,
}) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.75),
    transitionDuration: const Duration(milliseconds: 240),
    transitionBuilder: (context, animation, _, child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: animation.drive(
            Tween(begin: 0.92, end: 1.0)
                .chain(CurveTween(curve: Curves.easeOutBack)),
          ),
          child: child,
        ),
      );
    },
    pageBuilder: (_, __, ___) => _CharacterEditDialog(character: character),
  );
}

class _CharacterEditDialog extends ConsumerStatefulWidget {
  final Character? character;
  const _CharacterEditDialog({this.character});
  @override
  ConsumerState<_CharacterEditDialog> createState() =>
      _CharacterEditDialogState();
}

class _CharacterEditDialogState extends ConsumerState<_CharacterEditDialog> {
  late final TextEditingController _nameCtrl;
  String _description = '';
  String _personality = '';
  String _scenario = '';
  String _firstMessage = '';
  String _exampleMessages = '';
  String _systemPrompt = '';
  String _creatorNotes = '';
  List<String> _tags = [];
  List<String> _alternateGreetings = [];
  String? _avatarPath;
  Uint8List? _decodedAvatarBytes;

  String? _openSection;
  int? _expandedAlternateIndex;
  bool _isDirty = false;
  bool _isSaving = false;

  bool get _isEdit => widget.character != null;
  String? get _characterId => widget.character?.id;

  @override
  void initState() {
    super.initState();
    final c = widget.character;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _description = c?.description ?? '';
    _personality = c?.personality ?? '';
    _scenario = c?.scenario ?? '';
    _firstMessage = c?.firstMessage ?? '';
    _exampleMessages = c?.exampleMessages ?? '';
    _systemPrompt = c?.systemPrompt ?? '';
    _creatorNotes = c?.creatorNotes ?? '';
    _tags = List.from(c?.tags ?? []);
    _alternateGreetings = List.from(c?.alternateGreetings ?? []);
    _avatarPath = c?.assets?.avatarPath ?? c?.assets?.avatarUrl;
    // Pre-decode avatar: base64 data URIs are decoded once in initState to avoid decoding multi-MB images on every build
    if (_avatarPath?.startsWith('data:image') == true) {
      try {
        _decodedAvatarBytes = base64Decode(_avatarPath!.split(',').last);
      } catch (_) {
        _decodedAvatarBytes = null;
      }
    }
    _nameCtrl.addListener(_markDirty);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  void _onSectionToggle(String key, bool isExpanded) {
    setState(() => _openSection = isExpanded ? key : null);
  }

  Future<void> _closeWithDirtyCheck() async {
    if (_isDirty) {
      final confirm = await showDialog<bool>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.5),
        builder: (ctx) => const _StyledConfirm(
          title: '未保存的更改',
          message: '您有未保存的修改，确定要退出吗？您的更改将会丢失。',
          cancelText: '继续编辑',
          confirmText: '直接退出',
          danger: true,
        ),
      );
      if (confirm != true) return;
    }
    if (mounted) Navigator.pop(context);
  }

  Widget _buildAvatarImage(String? path) {
    if (path == null || path.trim().isEmpty) {
      return Container(
        color: const Color(0xFF252640),
        child: Center(child: Icon(Icons.person, size: 44,
            color: const Color(0xFF6C5CE7).withValues(alpha: 0.6))),
      );
    }
    // base64 data URI
    if (path.startsWith('data:image')) {
      try {
        final b64 = path.split(',').last;
        final bytes = _decodedAvatarBytes ?? base64Decode(b64);
        return Image.memory(bytes,
            fit: BoxFit.cover, width: 86, height: 86,
            cacheWidth: (86 * MediaQuery.of(context).devicePixelRatio).round(),
            errorBuilder: (_, __, ___) => _avatarPlaceholder());
      } catch (_) {
        return _avatarPlaceholder();
      }
    }
    // network URL
    if (path.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: path,
        fit: BoxFit.cover,
        width: 86, height: 86,
        placeholder: (_, __) => Container(color: const Color(0xFF252640)),
        errorWidget: (_, __, ___) => _avatarPlaceholder(),
      );
    }
    // local file — CharacterAvatarImage handles path resolution
    return CharacterAvatarImage(
      imagePath: path,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _avatarPlaceholder(),
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      color: const Color(0xFF252640),
      child: Center(child: Icon(Icons.person, size: 44,
          color: const Color(0xFF6C5CE7).withValues(alpha: 0.6))),
    );
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (xfile == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final avatarDir = Directory('${dir.path}/avatars');
    if (!avatarDir.existsSync()) avatarDir.createSync(recursive: true);
    final name = 'avatar_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final dest = '${avatarDir.path}/$name';
    await File(xfile.path).copy(dest);
    setState(() {
      _avatarPath = dest;
      _isDirty = true;
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      KiraToast.show(context, '请输入角色名', type: KiraToastType.warning);
      return;
    }
    if (_isEdit) {
      final scripts = ref.read(characterRegexScriptsProvider(_characterId!));
      final invalidIdx =
          scripts.indexWhere((s) => s.findRegex.trim().isEmpty);
      if (invalidIdx >= 0) {
        setState(() => _openSection = 'regex');
        KiraToast.show(context, '第${invalidIdx + 1}条正则规则未填写完整',
            type: KiraToastType.warning);
        return;
      }
    }
    setState(() => _isSaving = true);
    
    try {
      final notifier = ref.read(characterListProvider.notifier);
      final now = DateTime.now();
      final assets = (_avatarPath != null)
          ? CharacterAssets(avatarPath: _avatarPath)
          : widget.character?.assets;
      
      if (_isEdit) {
        // Re-read the latest character from the DB before saving to avoid overwriting extensions changes made during the session (regex, pinning, etc.)
        final repo = ref.read(characterRepositoryProvider);
        final latest = await repo.getCharacter(_characterId!);
        final base = latest ?? widget.character!;

        // Rebuild characterBook from the world_infos table (temporary sync; drop once the migration is complete)
        final wbRepo = ref.read(worldInfoRepositoryProvider);
        final liveBook = await assembleCharacterBookFromRepo(wbRepo, _characterId!);
        debugPrint('[Phase1.2] 重建 characterBook: ${liveBook?.entries.length ?? 0} 条');

        await notifier.updateCharacter(base.copyWith(
          name: name,
          description: _description,
          personality: _personality,
          scenario: _scenario,
          firstMessage: _firstMessage,
          exampleMessages: _exampleMessages,
          systemPrompt: _systemPrompt,
          creatorNotes: _creatorNotes,
          tags: _tags,
          alternateGreetings: _alternateGreetings,
          assets: assets,
          modifiedAt: now,
          // Explicitly preserve all fields not edited in the editor
          postHistoryInstructions: base.postHistoryInstructions,
          creator: base.creator,
          version: base.version,
          characterBook: liveBook ?? base.characterBook, // assembled from the tables
          extensions: base.extensions, // regex lives in its own table now; extensions untouched
          isFavorite: base.isFavorite,
          createdAt: base.createdAt,
        ));
        
        // Temporary debug: verify the database update
        if (mounted) {
          debugPrint('═══ [数据库验证] 开始 ═══');
          final verifyChar = await repo.getCharacter(_characterId!);
          if (verifyChar != null) {
            final descMatch = verifyChar.description == _description;
            debugPrint('[数据库验证] description 匹配: ${descMatch ? "✅" : "❌"}');
            if (!descMatch) {
              debugPrint('[数据库验证] 保存长度: ${_description.length}, 读回长度: ${verifyChar.description.length}');
            }
          }
          debugPrint('═══ [数据库验证] 结束 ═══\n');
          
          // Force-refresh the character list cache
          debugPrint('[角色编辑] 强制刷新 characterListProvider');
          ref.invalidate(characterListProvider);
          await Future.delayed(const Duration(milliseconds: 100));
          debugPrint('[角色编辑] characterListProvider 已失效并重建');
        }
      } else {
        await notifier.addCharacter(Character(
          id: '',
          name: name,
          description: _description,
          personality: _personality,
          scenario: _scenario,
          firstMessage: _firstMessage,
          alternateGreetings: _alternateGreetings,
          exampleMessages: _exampleMessages,
          systemPrompt: _systemPrompt,
          creatorNotes: _creatorNotes,
          tags: _tags,
          assets: assets,
          createdAt: now,
          modifiedAt: now,
        ));
      }
      
      if (mounted) {
        KiraToast.show(context, _isEdit ? '已保存' : '已创建',
            type: KiraToastType.success);
        
        // After a successful save, refresh the snapshot if the current chat page holds this character's snapshot
        if (_isEdit) {
          debugPrint('═══ [角色编辑] 开始刷新快照 ═══');
          debugPrint('[角色编辑] _characterId = $_characterId');
          
          final activeChat = ref.read(activeChatProvider);
          debugPrint('[角色编辑] activeChat.character?.id = ${activeChat.character?.id}');
          
          if (activeChat.character?.id == _characterId) {
            debugPrint('[角色编辑] ✅ ID 匹配，开始重读数据库');
            
            final updatedChar = await ref
                .read(characterRepositoryProvider)
                .getCharacter(_characterId!);
            
            if (updatedChar == null) {
              debugPrint('[角色编辑] ❌ 数据库读取失败（返回 null）');
            } else {
              debugPrint('[角色编辑] ✅ 数据库读取成功');
              debugPrint('[角色编辑] 新 description 长度: ${updatedChar.description.length}');
            }
            
            if (!mounted) {
              debugPrint('[角色编辑] ❌ 对话框已销毁，跳过刷新');
              return;
            }
            
            if (updatedChar != null) {
              debugPrint('[角色编辑] ✅ 调用 updateCharacterSnapshot');
              ref
                  .read(activeChatProvider.notifier)
                  .updateCharacterSnapshot(updatedChar);
              debugPrint('[角色编辑] ✅ 快照刷新完成');
              
              // Verify by reading the snapshot back
              final verifyChat = ref.read(activeChatProvider);
              debugPrint('[角色编辑] 验证 - 刷新后 description 长度: ${verifyChat.character?.description.length}');
            }
          } else {
            debugPrint('[角色编辑] ❌ ID 不匹配，跳过刷新');
          }
          
          debugPrint('═══ [角色编辑] 刷新流程结束 ═══\n');
        }
        
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        KiraToast.show(context, '保存失败: $e', type: KiraToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = screenH * 0.9 - viewInsets;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeWithDirtyCheck();
      },
      child: Center(
        child: Container(
          width: min(screenW - 40, 600),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                      const Color(0xFF7B5EA7).withValues(alpha: 0.08),
                      const Color(0xFF1A1B2E),
                    ]
                  : [
                      const Color(0xFF6C5CE7).withValues(alpha: 0.06),
                      const Color(0xFFF4F3FF),
                    ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF7B5EA7).withValues(alpha: 0.25),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                blurRadius: 48,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                _buildHeader(isDark),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                        DesignTokens.spaceMd, DesignTokens.spaceSm,
                        DesignTokens.spaceMd, DesignTokens.spaceMd),
                    child: Column(
                      children: [
                        _buildTagsCard(isDark),
                        const SizedBox(height: DesignTokens.spaceSm),
                        _buildTextCard(
                          key: 'description',
                          title: '角色描述',
                          icon: Icons.description,
                          color: KiraDialogTheme.description,
                          value: _description,
                          placeholder: '点击输入角色描述...',
                          maxLength: null,
                          onChanged: (v) => setState(() {
                            _description = v;
                            _isDirty = true;
                          }),
                        ),
                        const SizedBox(height: DesignTokens.spaceSm),
                        _buildTextCard(
                          key: 'opening',
                          title: '主开场白',
                          icon: Icons.chat_bubble_outline,
                          color: KiraDialogTheme.opening,
                          value: _firstMessage,
                          placeholder: '点击输入开场白...',
                          maxLength: null,
                          onChanged: (v) => setState(() {
                            _firstMessage = v;
                            _isDirty = true;
                          }),
                        ),
                        const SizedBox(height: DesignTokens.spaceSm),
                        _buildAlternateCard(isDark),
                        const SizedBox(height: DesignTokens.spaceSm),
                        _buildTextCard(
                          key: 'dialogue',
                          title: '对话示例',
                          icon: Icons.forum_outlined,
                          color: KiraDialogTheme.dialogue,
                          value: _exampleMessages,
                          placeholder: '点击输入对话示例...',
                          maxLength: null,
                          onChanged: (v) {
                            setState(() {
                              _exampleMessages = v;
                              _isDirty = true;
                            });
                          },
                          storeKey: 'exampleMessages',
                        ),
                        const SizedBox(height: DesignTokens.spaceSm),
                        _buildMoreCard(isDark),
                        if (_isEdit) ...[
                          const SizedBox(height: DesignTokens.spaceSm),
                          _buildWorldBookCard(isDark),
                          const SizedBox(height: DesignTokens.spaceSm),
                          _buildRegexCard(isDark),
                        ],
                      ],
                    ),
                  ),
                ),
                _buildFooter(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              DesignTokens.spaceMd, DesignTokens.spaceMd, DesignTokens.spaceMd, DesignTokens.spaceSm),
          child: Column(
            children: [
              // Avatar
              GestureDetector(
                onTap: _pickAvatar,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF6C5CE7),
                        Color(0xFF4CC9F0),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: SizedBox(
                    width: 86,
                    height: 86,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? const Color(0xFF1A1B2E)
                            : const Color(0xFFF4F3FF),
                      ),
                      child: Stack(
                        children: [
                          ClipOval(child: _buildAvatarImage(_avatarPath)),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C5CE7),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF1A1B2E)
                                    : const Color(0xFFF4F3FF),
                                width: 3,
                              ),
                            ),
                            child: const Icon(Icons.edit,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),
                ),
              ),
              const SizedBox(height: DesignTokens.spaceSm),
              // Edit button (absolutely positioned at the avatar's bottom-right corner)
              // Character name + gradient underline
              Column(
                children: [
                  SizedBox(
                    width: 240,
                    child: TextField(
                      controller: _nameCtrl,
                      textAlign: TextAlign.center,
                      cursorColor: KiraDialogTheme.primary,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: DesignTokens.weightBold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      decoration: InputDecoration(
                        hintText: '角色名',
                        hintStyle: TextStyle(
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color
                              ?.withValues(alpha: 0.4),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(
                      width: 240, child: KiraGradientUnderline()),
                ],
              ),
            ],
          ),
        ),
        // Close button
        Positioned(
          top: DesignTokens.spaceSm,
          right: DesignTokens.spaceSm,
          child: IconButton(
            icon: Icon(CupertinoIcons.xmark,
                size: 20,
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withValues(alpha: 0.6)),
            onPressed: _closeWithDirtyCheck,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          DesignTokens.spaceLg, DesignTokens.spaceSm, DesignTokens.spaceLg, DesignTokens.spaceLg),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: KiraDialogTheme.primary.withValues(alpha: 0.12),
          ),
        ),
      ),
      child: KiraSaveButton(
        label: _isSaving ? '保存中...' : (_isEdit ? '保存更改' : '创建角色'),
        enabled: !_isSaving,
        onPressed: _save,
      ),
    );
  }

  // Tags card
  Widget _buildTagsCard(bool isDark) {
    return KiraAccordionCard(
      title: '标签',
      preview: _tags.isEmpty ? '无标签' : _tags.join(', '),
      icon: Icons.style_outlined,
      accentColor: KiraDialogTheme.tag,
      isExpanded: _openSection == 'tags',
      onExpansionChanged: (v) => _onSectionToggle('tags', v),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (int i = 0; i < _tags.length; i++)
            KiraTagChip(
              label: _tags[i],
              color: KiraDialogTheme.tagColorFor(_tags[i]),
              onRemove: () => setState(() {
                _tags.removeAt(i);
                _isDirty = true;
              }),
            ),
          GestureDetector(
            onTap: () async {
              final v = await showKiraInputDialog(context,
                  title: '添加标签', placeholder: '请输入标签名称');
              if (v == null || v.trim().isEmpty) return;
              final t = v.trim();
              if (_tags.contains(t)) {
                KiraToast.show(context, '这个标签已经存在',
                    type: KiraToastType.warning);
                return;
              }
              setState(() {
                _tags.add(t);
                _isDirty = true;
              });
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(
                  color: KiraDialogTheme.primary.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 16, color: KiraDialogTheme.primary),
                  SizedBox(width: 4),
                  Text('添加标签',
                      style: TextStyle(
                        color: KiraDialogTheme.primary,
                        fontSize: DesignTokens.fontSizeSm,
                        fontWeight: DesignTokens.weightMedium,
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Text editing card (description / greeting / dialogue examples)
  Widget _buildTextCard({
    required String key,
    required String title,
    required IconData icon,
    required Color color,
    required String value,
    required String placeholder,
    int? maxLength,
    required ValueChanged<String> onChanged,
    String? storeKey,
  }) {
    return KiraAccordionCard(
      title: title,
      preview: value.isEmpty ? '无内容' : value,
      icon: icon,
      accentColor: color,
      isExpanded: _openSection == key,
      onExpansionChanged: (v) => _onSectionToggle(key, v),
      child: KiraEditTrigger(
        value: value,
        placeholder: placeholder,
        onTap: () async {
          final v = await showKiraInputDialog(
            context,
            title: '编辑$title',
            initialValue: value,
            multiline: true,
            maxLength: maxLength,
            placeholder: placeholder,
          );
          if (v != null) onChanged(v);
        },
        isDark: Theme.of(context).brightness == Brightness.dark,
        accentColor: color,
      ),
    );
  }

  // Alternate greetings card (nested, collapsible)
  Widget _buildAlternateCard(bool isDark) {
    return KiraAccordionCard(
      title: '备选开场白',
      preview: '${_alternateGreetings.length} 条备选开场白',
      icon: Icons.format_list_numbered,
      accentColor: KiraDialogTheme.alternate,
      isExpanded: _openSection == 'alternate',
      onExpansionChanged: (v) => _onSectionToggle('alternate', v),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < _alternateGreetings.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: KiraAccordionCard(
                title: '备选 ${i + 1}',
                preview: _alternateGreetings[i].isEmpty
                    ? '（空）'
                    : _alternateGreetings[i],
                accentColor: KiraDialogTheme.tagColorFor(i.toString()),
                nested: true,
                isExpanded: _expandedAlternateIndex == i,
                onExpansionChanged: (v) => setState(() =>
                    _expandedAlternateIndex = v ? i : null),
                headerActions: IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 18,
                      color: Colors.red.withValues(alpha: 0.6)),
                  onPressed: () => setState(() {
                    _alternateGreetings.removeAt(i);
                    if (_expandedAlternateIndex == i) {
                      _expandedAlternateIndex = null;
                    } else if (_expandedAlternateIndex != null &&
                        _expandedAlternateIndex! > i)
                      _expandedAlternateIndex =
                          _expandedAlternateIndex! - 1;
                    _isDirty = true;
                  }),
                ),
                child: KiraEditTrigger(
                  value: _alternateGreetings[i],
                  placeholder: '点击输入备选开场白...',
                  onTap: () async {
                    final v = await showKiraInputDialog(
                      context,
                      title: '编辑备选开场白 #${i + 1}',
                      initialValue: _alternateGreetings[i],
                      multiline: true,
                      maxLength: null,
                      placeholder: '请输入备选开场白...',
                    );
                    if (v != null) {
                      setState(() {
                        _alternateGreetings[i] = v;
                        _isDirty = true;
                      });
                    }
                  },
                  isDark: isDark,
                  accentColor: KiraDialogTheme.tagColorFor(i.toString()),
                ),
              ),
            ),
          KiraDashedAddButton(
            label: '添加备选开场白',
            color: KiraDialogTheme.alternate,
            onTap: () => setState(() {
              _alternateGreetings.add('');
              _expandedAlternateIndex = _alternateGreetings.length - 1;
              _isDirty = true;
            }),
          ),
        ],
      ),
    );
  }

  // More settings card (personality / scenario / system prompt / creator notes)
  Widget _buildMoreCard(bool isDark) {
    final List<({String key, String title, IconData icon, String value,
      String placeholder, int? maxLength, String storeKey})> fields = [
      (key: 'personality', title: '性格', icon: Icons.psychology_outlined,
        value: _personality, placeholder: '点击输入性格...',
        maxLength: null, storeKey: 'personality'),
      (key: 'scenario', title: '场景', icon: Icons.place_outlined,
        value: _scenario, placeholder: '点击输入场景...',
        maxLength: null, storeKey: 'scenario'),
      (key: 'systemPrompt', title: '系统提示词', icon: Icons.terminal,
        value: _systemPrompt, placeholder: '点击输入系统提示词...',
        maxLength: null, storeKey: 'systemPrompt'),
      (key: 'creatorNotes', title: '创作者注释', icon: Icons.edit_note,
        value: _creatorNotes, placeholder: '点击输入创作者注释...',
        maxLength: null, storeKey: 'creatorNotes'),
    ];
    return KiraAccordionCard(
      title: '更多设定',
      preview: '性格 / 场景 / 系统提示词 / 创作者注释',
      icon: Icons.tune,
      accentColor: Colors.grey,
      isExpanded: _openSection == 'more',
      onExpansionChanged: (v) => _onSectionToggle('more', v),
      child: Column(
        children: [
          for (final f in fields) ...[
            _MoreField(
              title: f.title,
              icon: f.icon,
              value: f.value,
              placeholder: f.placeholder,
              onTap: () async {
                final v = await showKiraInputDialog(
                  context,
                  title: '编辑${f.title}',
                  initialValue: f.value,
                  multiline: true,
                  maxLength: f.maxLength,
                  placeholder: f.placeholder,
                );
                if (v != null) {
                  setState(() {
                    switch (f.storeKey) {
                      case 'personality':
                        _personality = v;
                      case 'scenario':
                        _scenario = v;
                      case 'systemPrompt':
                        _systemPrompt = v;
                      case 'creatorNotes':
                        _creatorNotes = v;
                    }
                    _isDirty = true;
                  });
                }
              },
            ),
            if (f != fields.last)
              const SizedBox(height: DesignTokens.spaceSm),
          ],
        ],
      ),
    );
  }

  // Worldbook card
  Widget _buildWorldBookCard(bool isDark) {
    final worldInfos = ref.watch(characterWorldInfosProvider(_characterId!));
    return KiraAccordionCard(
      title: '世界书',
      preview: worldInfos.when(
        data: (list) =>
            list.isEmpty ? '无世界书' : '${list.length} 本 / ${list.fold(0, (s, w) => s + w.entries.length)} 条',
        loading: () => '加载中...',
        error: (_, __) => '加载失败',
      ),
      icon: Icons.menu_book_outlined,
      accentColor: KiraDialogTheme.worldbook,
      isExpanded: _openSection == 'worldbook',
      onExpansionChanged: (v) => _onSectionToggle('worldbook', v),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            KiraDashedButton(
              label: '导入世界书',
              icon: Icons.file_download_outlined,
              color: KiraDialogTheme.importColor,
              onTap: () => _importWorldBook(),
            ),
            const SizedBox(width: DesignTokens.spaceSm),
            KiraDashedButton(
              label: '导出世界书',
              icon: Icons.file_upload_outlined,
              color: KiraDialogTheme.exportColor,
              onTap: () => _exportWorldBook(),
            ),
          ]),
          const SizedBox(height: DesignTokens.spaceSm),
          worldInfos.when(
            data: (list) {
              final entries = <WorldInfoEntry>[
                for (final w in list) ...w.entries
              ];
              if (list.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('还没有世界书条目',
                        style: TextStyle(
                            fontSize: DesignTokens.fontSizeSm,
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withValues(alpha: 0.5))),
                    const SizedBox(height: 8),
                    KiraDashedAddButton(
                      label: '添加第一条',
                      color: KiraDialogTheme.worldbook,
                      onTap: () async {
                        // ensure a world book exists first
                        final notifier =
                            ref.read(worldInfoNotifierProvider.notifier);
                        final wb = await notifier.createWorldInfo(
                            name: '世界书', characterId: _characterId);
                        if (context.mounted) {
                          showWorldBookEntryEditDialog(context, ref,
                              worldInfoId: wb.id);
                        }
                      },
                    ),
                  ],
                );
              }
              if (entries.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('世界书暂无条目',
                        style: TextStyle(
                            fontSize: DesignTokens.fontSizeSm,
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withValues(alpha: 0.5))),
                    const SizedBox(height: 8),
                    KiraDashedAddButton(
                      label: '添加条目',
                      color: KiraDialogTheme.worldbook,
                      onTap: () => showWorldBookEntryEditDialog(context, ref,
                          worldInfoId: list.first.id),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  for (final e in entries.take(10))
                    _WorldBookEntryRow(
                      entry: e,
                      isDark: isDark,
                      onTap: () => showWorldBookEntryEditDialog(
                          context, ref, entry: e),
                      onDelete: () => _deleteWorldBookEntry(e),
                    ),
                  if (entries.length > 10)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('共 ${entries.length} 条，点击管理查看全部',
                          style: TextStyle(
                              fontSize: DesignTokens.fontSizeXs,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withValues(alpha: 0.4))),
                    ),
                  KiraDashedAddButton(
                    label: '添加条目',
                    color: KiraDialogTheme.worldbook,
                    onTap: () => showWorldBookEntryEditDialog(context, ref,
                        worldInfoId: list.first.id),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => showWorldBookEditorDialog(
                          context, ref,
                          characterId: _characterId!),
                      child: const Text('打开编辑器 →',
                          style: TextStyle(
                              fontSize: DesignTokens.fontSizeSm,
                              color: KiraDialogTheme.worldbook)),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(8),
              child: Center(child: CupertinoActivityIndicator()),
            ),
            error: (e, _) => Text('加载失败: $e',
                style: const TextStyle(
                    fontSize: DesignTokens.fontSizeSm, color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Regex card
  Widget _buildRegexCard(bool isDark) {
    final scripts = ref.watch(characterRegexScriptsProvider(_characterId!));
    return KiraAccordionCard(
      title: '角色正则',
      preview: scripts.isEmpty ? '无规则' : '${scripts.where((s) => !s.disabled).length}/${scripts.length} 条启用',
      icon: Icons.text_fields,
      accentColor: KiraDialogTheme.regex,
      isExpanded: _openSection == 'regex',
      onExpansionChanged: (v) => _onSectionToggle('regex', v),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            KiraDashedButton(
              label: '导入正则',
              icon: Icons.file_download_outlined,
              color: KiraDialogTheme.importColor,
              onTap: () => _importRegex(),
            ),
            const SizedBox(width: DesignTokens.spaceSm),
            KiraDashedButton(
              label: '导出正则',
              icon: Icons.file_upload_outlined,
              color: KiraDialogTheme.exportColor,
              onTap: () => _exportRegex(),
            ),
          ]),
          const SizedBox(height: DesignTokens.spaceSm),
          if (scripts.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('还没有正则规则',
                    style: TextStyle(
                        fontSize: DesignTokens.fontSizeSm,
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withValues(alpha: 0.5))),
                const SizedBox(height: 8),
                KiraDashedAddButton(
                  label: '添加第一条规则',
                  color: KiraDialogTheme.regex,
                  onTap: () {
                    final notifier = ref.read(
                        characterRegexScriptsProvider(_characterId!).notifier);
                    final blank = RegexScript(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      scriptName: '新规则',
                      findRegex: '',
                      replaceString: '',
                      trimStrings: [],
                      placement: [],
                      scriptType: RegexScriptType.character,
                      markdownOnly: false,
                      promptOnly: false,
                      runOnEdit: false,
                      substituteRegex: SubstituteRegex.none,
                      order: 0,
                      characterId: _characterId,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );
                    notifier.addScript(blank).then((_) {
                      final updated = ref.read(
                          characterRegexScriptsProvider(_characterId!));
                      if (updated.isNotEmpty && context.mounted) {
                        showRegexRuleEditDialog(context, ref,
                            script: updated.last);
                      }
                    });
                  },
                ),
              ],
            )
          else
            Column(
              children: [
                for (final s in scripts.take(10))
                  _RegexRuleRow(
                    script: s,
                    isDark: isDark,
                    onTap: () => showRegexRuleEditDialog(context, ref, script: s),
                    onDelete: () => _deleteRegexScript(s),
                  ),
                if (scripts.length > 10)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('共 ${scripts.length} 条，点击管理查看全部',
                        style: TextStyle(
                            fontSize: DesignTokens.fontSizeXs,
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withValues(alpha: 0.4))),
                  ),
                KiraDashedAddButton(
                  label: '添加规则',
                  color: KiraDialogTheme.regex,
                  onTap: () {
                    final notifier = ref.read(
                        characterRegexScriptsProvider(_characterId!).notifier);
                    final blank = RegexScript(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      scriptName: '新规则',
                      findRegex: '',
                      replaceString: '',
                      trimStrings: [],
                      placement: [],
                      scriptType: RegexScriptType.character,
                      markdownOnly: false,
                      promptOnly: false,
                      runOnEdit: false,
                      substituteRegex: SubstituteRegex.none,
                      order: scripts.length,
                      characterId: _characterId,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );
                    notifier.addScript(blank).then((_) {
                      final updated = ref.read(
                          characterRegexScriptsProvider(_characterId!));
                      if (updated.isNotEmpty && context.mounted) {
                        showRegexRuleEditDialog(context, ref,
                            script: updated.last);
                      }
                    });
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => showCharacterRegexDialog(
                        context, ref,
                        characterId: _characterId!),
                    child: const Text('打开编辑器 →',
                        style: TextStyle(
                            fontSize: DesignTokens.fontSizeSm,
                            color: KiraDialogTheme.regex)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // Delete action (removes after confirmation)

  Future<void> _deleteWorldBookEntry(WorldInfoEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      useRootNavigator: true,
      builder: (ctx) => const _StyledConfirm(
        title: '删除条目',
        message: '确定要删除这个知识条目吗？此操作不可恢复。',
        confirmText: '删除',
        danger: true,
      ),
    );
    if (confirm != true) return;
    await ref.read(worldInfoNotifierProvider.notifier).deleteEntry(entry.id);
    ref.invalidate(characterWorldInfosProvider);
    if (mounted) {
      KiraToast.show(context, '条目已删除', type: KiraToastType.success);
    }
  }

  Future<void> _deleteRegexScript(RegexScript script) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      useRootNavigator: true,
      builder: (ctx) => _StyledConfirm(
        title: '删除正则规则',
        message: '确定要删除「${script.scriptName}」吗？此操作不可恢复。',
        confirmText: '删除',
        danger: true,
      ),
    );
    if (confirm != true) return;
    await ref
        .read(characterRegexScriptsProvider(_characterId!).notifier)
        .removeScript(script.id);
    if (mounted) {
      KiraToast.show(context, '规则已删除', type: KiraToastType.success);
    }
  }

  // Import/export (with overwrite/merge choice)

  Future<void> _importWorldBook() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return;
    final content = await File(result.files.first.path!).readAsString();
    final data = jsonDecode(content);
    List<Map<String, dynamic>> parsedEntries;
    if (data is List) {
      parsedEntries = data.cast<Map<String, dynamic>>();
    } else if (data is Map && data['entries'] is List) {
      parsedEntries =
          (data['entries'] as List).cast<Map<String, dynamic>>();
    } else {
      KiraToast.show(context, 'JSON 格式不识别', type: KiraToastType.error);
      return;
    }
    if (parsedEntries.isEmpty) return;

    final existing = ref
            .read(characterWorldInfosProvider(_characterId!))
            .valueOrNull ??
        [];
    final existingEntries = <WorldInfoEntry>[
      for (final w in existing) ...w.entries
    ];

    // Empty target: import directly
    if (existingEntries.isEmpty) {
      await _doWorldBookImport(parsedEntries, overwrite: false);
      return;
    }

    // Existing data: show the choice dialog
    final overwrite = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      useRootNavigator: true,
      builder: (_) => _ImportModeDialog(
        existingCount: existingEntries.length,
        newCount: parsedEntries.length,
      ),
    );
    if (overwrite == null) return;
    await _doWorldBookImport(parsedEntries, overwrite: overwrite);
  }

  Future<void> _doWorldBookImport(
      List<Map<String, dynamic>> parsedEntries,
      {required bool overwrite}) async {
    final notifier = ref.read(worldInfoNotifierProvider.notifier);
    final existing = ref
            .read(characterWorldInfosProvider(_characterId!))
            .valueOrNull ??
        [];

    if (overwrite) {
      for (final w in existing) {
        await notifier.deleteWorldInfo(w.id);
      }
    }

    // Find or create the target worldbook
    final books = ref
            .read(characterWorldInfosProvider(_characterId!))
            .valueOrNull ??
        [];
    WorldInfo target;
    if (books.isEmpty) {
      target = await notifier.createWorldInfo(
          name: '世界书', characterId: _characterId);
    } else {
      target = books.first;
    }

    final existingKeys = overwrite
        ? <String>{}
        : target.entries
                .map((e) => e.keys.join(','))
                .toSet();

    var imported = 0;
    var skipped = 0;
    for (final em in parsedEntries) {
      final keys = (em['keys'] as List<dynamic>?)?.cast<String>() ?? [];
      if (!overwrite && existingKeys.contains(keys.join(','))) {
        skipped++;
        continue;
      }
      await notifier.addEntry(
        worldInfoId: target.id,
        keys: keys,
        content: em['content'] as String? ?? '',
        comment: em['comment'] as String?,
      );
      imported++;
    }
    ref.invalidate(characterWorldInfosProvider);
    if (mounted) {
      final msg = overwrite
          ? '已覆盖导入 $imported 条'
          : imported == parsedEntries.length
              ? '导入成功，共 $imported 条'
              : '导入完成：新增 $imported 条，跳过重复 $skipped 条';
      KiraToast.show(context, msg, type: KiraToastType.success);
    }
  }

  Future<void> _exportWorldBook() async {
    final list = ref
            .read(characterWorldInfosProvider(_characterId!))
            .valueOrNull ??
        [];
    if (list.isEmpty) {
      KiraToast.show(context, '暂无世界书可导出', type: KiraToastType.warning);
      return;
    }
    final entries = <Map<String, dynamic>>[
      for (final w in list)
        for (final e in w.entries) e.toJson(),
    ];
    final json =
        const JsonEncoder.withIndent('  ').convert(entries);
    final date = DateTime.now().toIso8601String().split('T')[0];
    final fileName =
        'worldbook_${widget.character?.name ?? 'character'}_$date.json';
    // Unified export delivery: share / save to file
    await deliverExportFile(
      context: context,
      fileName: fileName,
      bytes: utf8.encode(json),
      subject: fileName,
      ext: 'json',
    );
  }

  Future<void> _importRegex() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return;
    final content = await File(result.files.first.path!).readAsString();
    final data = jsonDecode(content);
    if (data is! List) {
      KiraToast.show(context, 'JSON 格式不识别', type: KiraToastType.error);
      return;
    }
    final parsedScripts = <RegexScript>[];
    for (final item in data) {
      try {
        parsedScripts.add(RegexScript.fromJson(item as Map<String, dynamic>));
      } catch (_) {}
    }
    if (parsedScripts.isEmpty) return;

    final existing =
        ref.read(characterRegexScriptsProvider(_characterId!));

    // Empty target: import directly
    if (existing.isEmpty) {
      final notifier = ref.read(
          characterRegexScriptsProvider(_characterId!).notifier);
      for (final s in parsedScripts) {
        await notifier.addScript(s);
      }
      if (mounted) {
        KiraToast.show(context, '正则导入成功，共 ${parsedScripts.length} 条',
            type: KiraToastType.success);
      }
      return;
    }

    // Existing data: show the choice dialog
    final overwrite = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      useRootNavigator: true,
      builder: (_) => _ImportModeDialog(
        existingCount: existing.length,
        newCount: parsedScripts.length,
      ),
    );
    if (overwrite == null) return;

    final notifier =
        ref.read(characterRegexScriptsProvider(_characterId!).notifier);

    if (overwrite) {
      for (final s in existing) {
        await notifier.removeScript(s.id);
      }
      for (final s in parsedScripts) {
        await notifier.addScript(s);
      }
      if (mounted) {
        KiraToast.show(context, '已覆盖导入 ${parsedScripts.length} 条',
            type: KiraToastType.success);
      }
    } else {
      final existingNames = existing.map((s) => s.scriptName).toSet();
      var imported = 0;
      var skipped = 0;
      for (final s in parsedScripts) {
        if (existingNames.contains(s.scriptName)) {
          skipped++;
          continue;
        }
        await notifier.addScript(s);
        imported++;
      }
      if (mounted) {
        final msg = imported == parsedScripts.length
            ? '导入成功，共 $imported 条'
            : '导入完成：新增 $imported 条，跳过重复 $skipped 条';
        KiraToast.show(context, msg, type: KiraToastType.success);
      }
    }
  }

  Future<void> _exportRegex() async {
    final scripts = ref.read(characterRegexScriptsProvider(_characterId!));
    if (scripts.isEmpty) {
      KiraToast.show(context, '暂无正则可导出', type: KiraToastType.warning);
      return;
    }
    final json = const JsonEncoder.withIndent('  ').convert(
        scripts.map((s) => s.toJson()).toList());
    final date = DateTime.now().toIso8601String().split('T')[0];
    final fileName = 'regex_${widget.character?.name ?? 'character'}_$date.json';
    // Unified export delivery: share / save to file
    await deliverExportFile(
      context: context,
      fileName: fileName,
      bytes: utf8.encode(json),
      subject: fileName,
      ext: 'json',
    );
  }
}

// Helper widgets

class _MoreField extends StatelessWidget {
  final String title;
  final IconData icon;
  final String value;
  final String placeholder;
  final VoidCallback onTap;
  const _MoreField({
    required this.title,
    required this.icon,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        child: Ink(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
            border: Border.all(
              color: Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text(title,
                    style: TextStyle(
                      fontSize: DesignTokens.fontSizeSm,
                      fontWeight: DesignTokens.weightMedium,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    )),
                const Spacer(),
                Flexible(
                  flex: 2,
                  child: Text(
                    value.isEmpty ? placeholder : value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeSm,
                  color: value.isEmpty
                      ? Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withValues(alpha: 0.4)
                      : Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withValues(alpha: 0.7),
                  fontStyle: value.isEmpty
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
              ),
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }
}

class _StyledConfirm extends StatelessWidget {
  final String title;
  final String message;
  final String cancelText;
  final String confirmText;
  final bool danger;
  const _StyledConfirm({
    required this.title,
    required this.message,
    this.cancelText = '取消',
    this.confirmText = '确认',
    this.danger = false,
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
          color: isDark ? const Color(0xFF2A2F2C) : const Color(0xFFFFFCFE),
          borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
          border: Border.all(
            color: KiraDialogTheme.primary.withValues(alpha: 0.16),
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
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  )),
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
                        ?.withValues(alpha: 0.7),
                  )),
              const SizedBox(height: DesignTokens.spaceLg),
              KiraDialogActions(
                cancelText: cancelText,
                confirmText: confirmText,
                confirmColor: danger ? Colors.red : KiraDialogTheme.primary,
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

/// Worldbook entry row (tap to edit + delete button)
class _WorldBookEntryRow extends StatelessWidget {
  final WorldInfoEntry entry;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _WorldBookEntryRow({
    required this.entry,
    required this.isDark,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final title = entry.keys.isNotEmpty ? entry.keys.join(', ') : '（无关键词）';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
              border: Border.all(
                color: const Color(0xFF7B5EA7).withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.bookmark_outline,
                    size: 16, color: KiraDialogTheme.worldbook),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: DesignTokens.fontSizeSm,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
                if (!entry.enabled)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Text('已停用',
                        style: TextStyle(
                            fontSize: DesignTokens.fontSizeXs,
                            color: Colors.grey)),
                  ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onDelete,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline,
                        size: 18, color: Colors.red.withValues(alpha: 0.6)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Regex rule row (tap to edit + delete button)
class _RegexRuleRow extends StatelessWidget {
  final RegexScript script;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RegexRuleRow({
    required this.script,
    required this.isDark,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
              border: Border.all(
                color: const Color(0xFF7B5EA7).withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.text_fields,
                    size: 16, color: KiraDialogTheme.regex),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    script.scriptName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: DesignTokens.fontSizeSm,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
                if (script.disabled)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Text('已停用',
                        style: TextStyle(
                            fontSize: DesignTokens.fontSizeXs,
                            color: Colors.grey)),
                  ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onDelete,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline,
                        size: 18, color: Colors.red.withValues(alpha: 0.6)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


/// Import mode selection dialog (overwrite / merge / cancel)
/// Returns true = overwrite, false = merge, null = cancel
class _ImportModeDialog extends StatelessWidget {
  final int existingCount;
  final int newCount;
  const _ImportModeDialog({
    required this.existingCount,
    required this.newCount,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = Theme.of(context).textTheme.bodyLarge?.color;
    final labelColor = Theme.of(context).textTheme.bodyMedium?.color;
    return Center(
      child: Container(
        width: 360,
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
              Text('检测到已有数据',
                  style: TextStyle(
                      fontSize: DesignTokens.fontSizeHeadline,
                      fontWeight: DesignTokens.weightBold,
                      color: titleColor)),
              const SizedBox(height: 8),
              Text('已有 $existingCount 条，即将导入 $newCount 条',
                  style: TextStyle(
                      fontSize: DesignTokens.fontSizeSm,
                      color: labelColor?.withValues(alpha: 0.7))),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _ImportChoice(
                      label: '覆盖导入',
                      desc: '清空现有再导入',
                      color: Colors.red,
                      onTap: () => Navigator.pop(context, true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ImportChoice(
                      label: '合并导入',
                      desc: '保留现有追加新的',
                      color: KiraDialogTheme.primary,
                      onTap: () => Navigator.pop(context, false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: Text('取消',
                      style: TextStyle(
                          color: labelColor?.withValues(alpha: 0.6))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportChoice extends StatelessWidget {
  final String label;
  final String desc;
  final Color color;
  final VoidCallback onTap;
  const _ImportChoice({
    required this.label,
    required this.desc,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: DesignTokens.fontSizeBodyMedium,
                      fontWeight: DesignTokens.weightSemibold,
                      color: color)),
              const SizedBox(height: 2),
              Text(desc,
                  style: TextStyle(
                      fontSize: DesignTokens.fontSizeXs,
                      color: color.withValues(alpha: 0.7))),
            ],
          ),
        ),
      ),
    );
  }
}
