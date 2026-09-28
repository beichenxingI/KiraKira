import 'dart:io';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kirakira/data/models/persona.dart';
import 'package:kirakira/presentation/providers/persona_providers.dart';
import 'package:kirakira/presentation/providers/character_providers.dart';
import 'package:kirakira/presentation/providers/group_providers.dart';
import 'package:kirakira/presentation/providers/world_info_providers.dart';
import 'package:kirakira/presentation/theme/app_theme.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:kirakira/presentation/dialogs/core_dialog.dart';

/// Enhanced Persona Editor Screen with all new fields
class PersonaEditorScreen extends ConsumerStatefulWidget {
  final Persona? persona; // null for creating new persona

  const PersonaEditorScreen({super.key, this.persona});

  @override
  ConsumerState<PersonaEditorScreen> createState() => _PersonaEditorScreenState();
}

class _PersonaEditorScreenState extends ConsumerState<PersonaEditorScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _systemPromptController;
  late TextEditingController _postHistoryController;
  late TextEditingController _creatorNotesController;
  late TextEditingController _tagInputController;
  
  String? _avatarPath;
  bool _isFavorite = false;
  String? _lorebookId;
  List<String> _tags = [];
  List<PersonaConnection> _connections = [];
  PersonaDescriptionSettings _descriptionSettings = const PersonaDescriptionSettings();
  
  bool _isSaving = false;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Initialize controllers with existing data
    final persona = widget.persona;
    _nameController = TextEditingController(text: persona?.name ?? '');
    _descriptionController = TextEditingController(text: persona?.description ?? '');
    _systemPromptController = TextEditingController(text: persona?.systemPromptOverride ?? '');
    _postHistoryController = TextEditingController(text: persona?.postHistoryInstructions ?? '');
    _creatorNotesController = TextEditingController(text: persona?.creatorNotes ?? '');
    _tagInputController = TextEditingController();
    
    _avatarPath = persona?.avatarPath;
    _isFavorite = persona?.isFavorite ?? false;
    _lorebookId = persona?.lorebookId;
    _tags = List.from(persona?.tags ?? []);
    _connections = List.from(persona?.connections ?? []);
    _descriptionSettings = persona?.descriptionSettings ?? const PersonaDescriptionSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _systemPromptController.dispose();
    _postHistoryController.dispose();
    _creatorNotesController.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  bool get _isDesktop => Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  @override
  Widget build(BuildContext context) {
    // [问题5浮窗化] 全屏 Scaffold → CoreDialogShell 浮窗(maxWidth 800,
    // 编辑器类惯例),收藏/保存迁到标题栏 trailing,TabBar 迁入 body。
    return CoreDialogShell(
      title: widget.persona == null ? 'Create Persona' : 'Edit Persona',
      icon: CupertinoIcons.person_crop_circle,
      maxWidth: 800,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(_isFavorite ? Icons.star : Icons.star_border),
            tooltip: 'Favorite',
            onPressed: () => setState(() => _isFavorite = !_isFavorite),
          ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Save',
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      disableScroll: true,
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: '角色设定', icon: Icon(Icons.person)),
              Tab(text: '绑定角色卡', icon: Icon(Icons.link)),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBasicTab(),
                _buildConnectionsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar picker
          Center(child: _buildAvatarPicker()),
          const SizedBox(height: 24),
          
          // 名字
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '名字',
              hintText: '给这个人设起个名字',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.badge),
            ),
          ),
          const SizedBox(height: 16),

          // 角色设定
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: '角色设定',
              hintText: '描述"你"是谁——AI 会以此认识你',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.description),
            ),
            maxLines: 8,
          ),
          const SizedBox(height: 20),

          // 生效规则说明
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 18),
                    SizedBox(width: 6),
                    Text('人设生效规则',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '进入聊天时，按以下优先级决定使用哪个人设：\n'
                  '1. 你在聊天里手动选择的人设（最优先）\n'
                  '2. 当前角色卡在"绑定角色卡"里指定的人设\n'
                  '3. 都没有时，使用默认人设\n\n'
                  '你可以在"绑定角色卡"页把这个人设关联到一个或多个角色。',
                  style: TextStyle(fontSize: DesignTokens.fontSizeSm, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lorebook Selection
          _buildLorebookSelector(),
          const SizedBox(height: 16),
          
          // System Prompt Override
          TextField(
            controller: _systemPromptController,
            decoration: const InputDecoration(
              labelText: 'System Prompt Override',
              hintText: 'Override system prompt when using this persona',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.code),
              helperText: 'Replaces the default system prompt',
            ),
            maxLines: 5,
          ),
          const SizedBox(height: 16),
          
          // Post-History Instructions
          TextField(
            controller: _postHistoryController,
            decoration: const InputDecoration(
              labelText: 'Post-History Instructions',
              hintText: 'Instructions added after chat history',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.history),
              helperText: 'Inserted after chat messages',
            ),
            maxLines: 5,
          ),
          const SizedBox(height: 16),
          
          // Description Settings
          _buildDescriptionSettings(),
        ],
      ),
    );
  }

  Widget _buildConnectionsTab() {
    final charactersAsync = ref.watch(characterListProvider);
    final boundIds = _connections
        .where((c) => c.characterId != null)
        .map((c) => c.characterId!)
        .toSet();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '勾选角色卡，进入对应角色的聊天时将自动使用这个人设'
              '（除非你在聊天里手动选择了其他人设）。',
              style: TextStyle(fontSize: DesignTokens.fontSizeSm, height: 1.5),
            ),
          ),
        ),
        Expanded(
          child: charactersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载角色失败：$e')),
            data: (characters) {
              if (characters.isEmpty) {
                return const Center(child: Text('还没有角色卡'));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: characters.length,
                itemBuilder: (context, index) {
                  final ch = characters[index];
                  final bound = boundIds.contains(ch.id);
                  final avatarPath = ch.assets?.avatarPath;
                  final hasAvatar =
                      avatarPath != null && avatarPath.isNotEmpty;
                  return Card(
                    child: CheckboxListTile(
                      value: bound,
                      secondary: CircleAvatar(
                        backgroundImage:
                            hasAvatar ? FileImage(File(avatarPath)) : null,
                        child: !hasAvatar
                            ? Text(ch.name.isNotEmpty ? ch.name[0] : '?')
                            : null,
                      ),
                      title: Text(ch.name),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _connections
                                .add(PersonaConnection(characterId: ch.id));
                          } else {
                            _connections
                                .removeWhere((c) => c.characterId == ch.id);
                          }
                        });
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tags',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._tags.map((tag) => Chip(
              label: Text(tag),
              onDeleted: () => setState(() => _tags.remove(tag)),
              deleteIcon: const Icon(Icons.close, size: 18),
            )),
            ActionChip(
              label: const Text('Add Tag'),
              avatar: const Icon(Icons.add, size: 18),
              onPressed: _showAddTagDialog,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLorebookSelector() {
    final lorebooksAsync = ref.watch(allWorldInfosProvider);
    
    return lorebooksAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const Text('Error loading lorebooks'),
      data: (lorebooks) {
        return DropdownButtonFormField<String?>(
          value: _lorebookId,
          decoration: const InputDecoration(
            labelText: 'Persona Lorebook',
            hintText: 'Select a lorebook',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.book),
            helperText: 'Automatically activated when using this persona',
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('None'),
            ),
            ...lorebooks.map((lb) => DropdownMenuItem(
              value: lb.id,
              child: Text(lb.name),
            )),
          ],
          onChanged: (value) => setState(() => _lorebookId = value),
        );
      },
    );
  }

  Widget _buildDescriptionSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Description Placement',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PersonaDescriptionPosition>(
              value: _descriptionSettings.position,
              decoration: const InputDecoration(
                labelText: 'Position',
                border: OutlineInputBorder(),
                helperText: 'Where to insert persona description',
              ),
              items: PersonaDescriptionPosition.values.map((pos) {
                return DropdownMenuItem(
                  value: pos,
                  child: Text(_formatEnumName(pos.name)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _descriptionSettings = _descriptionSettings.copyWith(position: value);
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            if (_descriptionSettings.position == PersonaDescriptionPosition.atDepth)
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Depth',
                  border: OutlineInputBorder(),
                  helperText: 'Depth in chat history',
                ),
                keyboardType: TextInputType.number,
                controller: TextEditingController(
                  text: _descriptionSettings.depth.toString(),
                ),
                onChanged: (value) {
                  final depth = int.tryParse(value) ?? 4;
                  setState(() {
                    _descriptionSettings = _descriptionSettings.copyWith(depth: depth);
                  });
                },
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PersonaDescriptionRole>(
              value: _descriptionSettings.role,
              decoration: const InputDecoration(
                labelText: 'Message Role',
                border: OutlineInputBorder(),
                helperText: 'Role for the description message',
              ),
              items: PersonaDescriptionRole.values.map((role) {
                return DropdownMenuItem(
                  value: role,
                  child: Text(_formatEnumName(role.name)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _descriptionSettings = _descriptionSettings.copyWith(role: value);
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarPicker() {
    return Stack(
      children: [
        GestureDetector(
          onTap: _showAvatarOptions,
          child: CircleAvatar(
            radius: 60,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
            backgroundImage: _avatarPath != null ? FileImage(File(_avatarPath!)) : null,
            child: _avatarPath == null
                ? const Icon(Icons.person, size: 60, color: AppTheme.primaryColor)
                : null,
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _showAvatarOptions,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.darkCard, width: 2),
              ),
              child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  void _showAvatarOptions() {
    if (_isDesktop) {
      _pickImageFromFiles();
      return;
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            if (_avatarPath != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Avatar', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _avatarPath = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.first.path != null) {
        await _saveAvatarImage(result.files.first.path!);
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image != null) {
        await _saveAvatarImage(image.path);
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image != null) {
        await _saveAvatarImage(image.path);
      }
    } catch (e) {
      _showError('Failed to take photo: $e');
    }
  }

  Future<void> _saveAvatarImage(String sourcePath) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final avatarsDir = Directory(p.join(appDir.path, 'KiraKira', 'avatars', 'personas'));
      await avatarsDir.create(recursive: true);
      
      const uuid = Uuid();
      final extension = p.extension(sourcePath);
      final newFileName = '${uuid.v4()}$extension';
      final newPath = p.join(avatarsDir.path, newFileName);
      
      await File(sourcePath).copy(newPath);
      setState(() => _avatarPath = newPath);
    } catch (e) {
      _showError('Failed to save avatar: $e');
    }
  }

  void _showAddTagDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Tag'),
        content: TextField(
          controller: _tagInputController,
          decoration: const InputDecoration(
            hintText: 'Enter tag name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty && !_tags.contains(value.trim())) {
              setState(() => _tags.add(value.trim()));
              _tagInputController.clear();
            }
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = _tagInputController.text.trim();
              if (value.isNotEmpty && !_tags.contains(value)) {
                setState(() => _tags.add(value));
                _tagInputController.clear();
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddConnectionDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddConnectionDialog(
        onAdd: (connection) {
          setState(() => _connections.add(connection));
        },
      ),
    );
  }

  void _removeConnection(int index) {
    setState(() => _connections.removeAt(index));
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Please enter a name');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final persona = Persona(
        id: widget.persona?.id ?? now.millisecondsSinceEpoch.toString(),
        name: name,
        description: _descriptionController.text.trim(),
        avatarPath: _avatarPath,
        isDefault: widget.persona?.isDefault ?? false,
        createdAt: widget.persona?.createdAt ?? now,
        updatedAt: now,
        connections: _connections,
        descriptionSettings: _descriptionSettings,
        lorebookId: _lorebookId,
        systemPromptOverride: _systemPromptController.text.trim().isEmpty
            ? null
            : _systemPromptController.text.trim(),
        postHistoryInstructions: _postHistoryController.text.trim().isEmpty
            ? null
            : _postHistoryController.text.trim(),
        tags: _tags,
        creatorNotes: _creatorNotesController.text.trim(),
        isFavorite: _isFavorite,
      );

      if (widget.persona == null) {
        await ref.read(personaNotifierProvider.notifier).createPersona(
          name: persona.name,
          description: persona.description,
          avatarPath: persona.avatarPath,
        );
      } else {
        await ref.read(personaNotifierProvider.notifier).updatePersona(persona);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Failed to save: $e');
      setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  String _formatEnumName(String name) {
    return name.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(0)}',
    ).trim().split(' ').map((word) => 
      word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }
}

/// Dialog for adding a persona connection
class _AddConnectionDialog extends ConsumerStatefulWidget {
  final Function(PersonaConnection) onAdd;

  const _AddConnectionDialog({required this.onAdd});

  @override
  ConsumerState<_AddConnectionDialog> createState() => _AddConnectionDialogState();
}

class _AddConnectionDialogState extends ConsumerState<_AddConnectionDialog> {
  bool _isCharacter = true;
  String? _selectedId;
  PersonaLockType _lockType = PersonaLockType.none;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Connection'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Type selector
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Character'), icon: Icon(Icons.person)),
              ButtonSegment(value: false, label: Text('Group'), icon: Icon(Icons.group)),
            ],
            selected: {_isCharacter},
            onSelectionChanged: (Set<bool> selected) {
              setState(() {
                _isCharacter = selected.first;
                _selectedId = null;
              });
            },
          ),
          const SizedBox(height: 16),
          
          // Entity selector
          _isCharacter ? _buildCharacterSelector() : _buildGroupSelector(),
          const SizedBox(height: 16),
          
          // Lock type
          DropdownButtonFormField<PersonaLockType>(
            value: _lockType,
            decoration: const InputDecoration(
              labelText: 'Lock Type',
              border: OutlineInputBorder(),
            ),
            items: PersonaLockType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type.name),
              );
            }).toList(),
            onChanged: (value) => setState(() => _lockType = value ?? PersonaLockType.none),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedId == null ? null : () {
            widget.onAdd(
              PersonaConnection(
                characterId: _isCharacter ? _selectedId : null,
                groupId: _isCharacter ? null : _selectedId,
                lockType: _lockType,
              ),
            );
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }

  Widget _buildCharacterSelector() {
    final charactersAsync = ref.watch(characterListProvider);
    return charactersAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (_, __) => const Text('Error loading characters'),
      data: (characters) => DropdownButtonFormField<String>(
        value: _selectedId,
        decoration: const InputDecoration(
          labelText: 'Character',
          border: OutlineInputBorder(),
        ),
        items: characters.map((char) => DropdownMenuItem(
          value: char.id,
          child: Text(char.name),
        )).toList(),
        onChanged: (value) => setState(() => _selectedId = value),
      ),
    );
  }

  Widget _buildGroupSelector() {
    final groupsAsync = ref.watch(groupListProvider);
    return groupsAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (_, __) => const Text('Error loading groups'),
      data: (groups) => DropdownButtonFormField<String>(
        value: _selectedId,
        decoration: const InputDecoration(
          labelText: 'Group',
          border: OutlineInputBorder(),
        ),
        items: groups.map((group) => DropdownMenuItem(
          value: group.id,
          child: Text(group.name),
        )).toList(),
        onChanged: (value) => setState(() => _selectedId = value),
      ),
    );
  }
}