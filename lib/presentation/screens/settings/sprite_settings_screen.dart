import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kirakira/data/models/sprite.dart';
import 'package:kirakira/presentation/providers/sprite_providers.dart';
import 'package:kirakira/presentation/theme/app_theme.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/widgets/chat/sprite_display.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';

/// Screen for managing sprite settings
class SpriteSettingsScreen extends ConsumerWidget {
  const SpriteSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(spriteSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('表情精灵图'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: '重置为默认值',
            onPressed: () {
              ref.read(spriteSettingsProvider.notifier).reset();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('设置已重置为默认值')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(DesignTokens.spaceMd),
        children: [
          // Enable/Disable toggle
          _buildSection(
            title: '通用',
            children: [
              SwitchListTile(
                title: const Text('启用精灵图'),
                subtitle: const Text('在聊天中显示角色表情图'),
                value: settings.enabled,
                onChanged: (value) {
                  ref.read(spriteSettingsProvider.notifier).setEnabled(value);
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Display settings
          _buildSection(
            title: '显示',
            children: [
              // Size slider
              ListTile(
                title: const Text('精灵图尺寸'),
                subtitle: Slider(
                  value: settings.size,
                  min: 50,
                  max: 400,
                  divisions: 35,
                  label: '${settings.size.round()}px',
                  onChanged: settings.enabled
                      ? (value) {
                          ref.read(spriteSettingsProvider.notifier).setSize(value);
                        }
                      : null,
                ),
                trailing: Text(
                  '${settings.size.round()}px',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),

              // Position dropdown
              ListTile(
                title: const Text('位置'),
                subtitle: const Text('精灵图显示位置'),
                trailing: DropdownButton<SpritePosition>(
                  value: settings.position,
                  onChanged: settings.enabled
                      ? (value) {
                          if (value != null) {
                            ref.read(spriteSettingsProvider.notifier).setPosition(value);
                          }
                        }
                      : null,
                  items: SpritePosition.values.map((pos) {
                    return DropdownMenuItem(
                      value: pos,
                      child: Text(_getPositionName(pos)),
                    );
                  }).toList(),
                ),
              ),

              // Opacity slider
              ListTile(
                title: const Text('透明度'),
                subtitle: Slider(
                  value: settings.opacity,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  label: '${(settings.opacity * 100).round()}%',
                  onChanged: settings.enabled
                      ? (value) {
                          ref.read(spriteSettingsProvider.notifier).setOpacity(value);
                        }
                      : null,
                ),
                trailing: Text(
                  '${(settings.opacity * 100).round()}%',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Animation settings
          _buildSection(
            title: '动画',
            children: [
              SwitchListTile(
                title: const Text('动画过渡'),
                subtitle: const Text('精灵图切换时平滑过渡'),
                value: settings.animateTransitions,
                onChanged: settings.enabled
                    ? (value) {
                        ref.read(spriteSettingsProvider.notifier).setAnimateTransitions(value);
                      }
                    : null,
              ),

              ListTile(
                title: const Text('过渡时长'),
                subtitle: Slider(
                  value: settings.transitionDurationMs.toDouble(),
                  min: 0,
                  max: 1000,
                  divisions: 10,
                  label: '${settings.transitionDurationMs}ms',
                  onChanged: settings.enabled && settings.animateTransitions
                      ? (value) {
                          ref.read(spriteSettingsProvider.notifier)
                              .setTransitionDuration(value.round());
                        }
                      : null,
                ),
                trailing: Text(
                  '${settings.transitionDurationMs}ms',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),

              SwitchListTile(
                title: const Text('流式生成时显示'),
                subtitle: const Text('AI 生成时显示精灵图'),
                value: settings.showDuringStreaming,
                onChanged: settings.enabled
                    ? (value) {
                        ref.read(spriteSettingsProvider.notifier).setShowDuringStreaming(value);
                      }
                    : null,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Emotion detection info
          _buildSection(
            title: '情感检测',
            children: [
              const ListTile(
                leading: Icon(Icons.info_outline, color: AppTheme.accentColor),
                title: Text('工作原理'),
                subtitle: Text(
                  'Sprites are automatically selected based on emotion keywords detected in messages. '
                  'Action text like *smiles* or *laughs* is prioritized.',
                ),
              ),
              const Divider(),
              ExpansionTile(
                title: const Text('支持的情感'),
                children: SpriteEmotion.values.map((emotion) {
                  return ListTile(
                    dense: true,
                    title: Text(emotion.displayName),
                    subtitle: Text(
                      emotion.keywords.take(5).join(', ') +
                          (emotion.keywords.length > 5 ? '...' : ''),
                      style: const TextStyle(
                        fontSize: DesignTokens.fontSizeXs,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(DesignTokens.spaceMd, DesignTokens.spaceMd, DesignTokens.spaceMd, DesignTokens.spaceSm),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: DesignTokens.fontSizeBodyMedium,
                fontWeight: FontWeight.bold,
                color: AppTheme.accentColor,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  String _getPositionName(SpritePosition position) {
    switch (position) {
      case SpritePosition.left:
        return 'Left';
      case SpritePosition.right:
        return 'Right';
      case SpritePosition.center:
        return 'Center';
      case SpritePosition.floatingLeft:
        return 'Floating Left';
      case SpritePosition.floatingRight:
        return 'Floating Right';
    }
  }
}

/// Screen for managing sprites for a specific character
class CharacterSpritesScreen extends ConsumerStatefulWidget {
  final String characterId;
  final String characterName;

  const CharacterSpritesScreen({
    super.key,
    required this.characterId,
    required this.characterName,
  });

  @override
  ConsumerState<CharacterSpritesScreen> createState() => _CharacterSpritesScreenState();
}

class _CharacterSpritesScreenState extends ConsumerState<CharacterSpritesScreen> {
  final ImagePicker _picker = ImagePicker();
  String? _selectedEmotion;

  @override
  Widget build(BuildContext context) {
    final packAsync = ref.watch(spritePackNotifierProvider(widget.characterId));

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.characterName} Sprites'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: '从文件夹导入',
            onPressed: _importFromFolder,
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete_all',
                child: ListTile(
                  leading: Icon(Icons.delete_sweep, color: Colors.red),
                  title: Text('删除所有精灵图'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'delete_all') {
                _confirmDeleteAll();
              }
            },
          ),
        ],
      ),
      body: packAsync.when(
        data: (pack) => _buildContent(pack),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Error: $error', style: const TextStyle(color: Colors.red)),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSprite,
        icon: const Icon(Icons.add_photo_alternate),
        label: const Text('添加精灵图'),
      ),
    );
  }

  Widget _buildContent(SpritePack pack) {
    return ListView(
      padding: const EdgeInsets.all(DesignTokens.spaceMd),
      children: [
        // Stats card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.spaceMd),
            child: Row(
              children: [
                const Icon(Icons.image, color: AppTheme.accentColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${pack.sprites.length} sprites',
                        style: const TextStyle(
                          fontSize: DesignTokens.fontSizeBodyLarge,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (pack.defaultEmotion != null)
                        Text(
                          'Default: ${pack.defaultEmotion}',
                          style: const TextStyle(
                            fontSize: DesignTokens.fontSizeXs,
                            color: AppTheme.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Sprites grid
        if (pack.hasSprites) ...[
          const Text(
            'Sprites',
            style: TextStyle(
              fontSize: DesignTokens.fontSizeBodyMedium,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SpriteGrid(
            characterId: widget.characterId,
            selectedEmotion: _selectedEmotion,
            onSelect: (sprite) {
              setState(() => _selectedEmotion = sprite.emotion);
              _showSpriteOptions(sprite);
            },
            onDelete: (sprite) => _confirmDeleteSprite(sprite),
          ),
        ] else ...[
          const SizedBox(height: 48),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.add_photo_alternate,
                  size: 64,
                  color: AppTheme.textMuted.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No sprites yet',
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeXl,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add expression images for this character',
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeBodyMedium,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 80), // Space for FAB
      ],
    );
  }

  Future<void> _addSprite() async {
    // First, select emotion
    final emotion = await _selectEmotion();
    if (emotion == null) return;

    // Then, pick image
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    // Add sprite
    await ref.read(spritePackNotifierProvider(widget.characterId).notifier)
        .addSprite(emotion, File(image.path));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加 $emotion 精灵图')),
      );
    }
  }

  Future<String?> _selectEmotion() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择情感'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: SpriteEmotion.values.length,
            itemBuilder: (context, index) {
              final emotion = SpriteEmotion.values[index];
              return ListTile(
                title: Text(emotion.displayName),
                subtitle: Text(
                  emotion.keywords.take(3).join(', '),
                  style: const TextStyle(fontSize: DesignTokens.fontSizeXs, color: AppTheme.textMuted),
                ),
                onTap: () => Navigator.pop(context, emotion.id),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showSpriteOptions(Sprite sprite) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DesignTokens.radiusLg)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: DesignTokens.spaceSm),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textMuted,
                borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
              ),
            ),
            const SizedBox(height: 16),
            
            // Preview
            SpritePreview(
              sprite: sprite,
              size: 120,
              showLabel: true,
            ),
            
            const SizedBox(height: 16),
            const Divider(),
            
            ListTile(
              leading: const Icon(Icons.star, color: AppTheme.accentColor),
              title: const Text('设为默认'),
              onTap: () {
                Navigator.pop(context);
                ref.read(spritePackNotifierProvider(widget.characterId).notifier)
                    .setDefaultEmotion(sprite.emotion);
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('更改情感'),
              onTap: () async {
                Navigator.pop(context);
                final newEmotion = await _selectEmotion();
                if (newEmotion != null && newEmotion != sprite.emotion) {
                  // Remove old and add new
                  await ref.read(spritePackNotifierProvider(widget.characterId).notifier)
                      .removeSprite(sprite.emotion);
                  await ref.read(spritePackNotifierProvider(widget.characterId).notifier)
                      .addSprite(newEmotion, File(sprite.imagePath));
                }
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteSprite(sprite);
              },
            ),
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteSprite(Sprite sprite) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除精灵图'),
        content: Text('删除 ${sprite.emotion} 精灵图？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(spritePackNotifierProvider(widget.characterId).notifier)
                  .removeSprite(sprite.emotion);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除所有精灵图'),
        content: const Text(
          'Are you sure you want to delete all sprites for this character? '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(spritePackNotifierProvider(widget.characterId).notifier)
                  .deleteAll();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  Future<void> _importFromFolder() async {
    // Show info dialog about import
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入精灵图'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import sprites from a folder. Files should be named with emotion keywords:',
            ),
            SizedBox(height: 12),
            Text('• happy.png, smile.jpg', style: TextStyle(fontSize: DesignTokens.fontSizeXs)),
            Text('• sad.png, cry.jpg', style: TextStyle(fontSize: DesignTokens.fontSizeXs)),
            Text('• angry.png, mad.jpg', style: TextStyle(fontSize: DesignTokens.fontSizeXs)),
            Text('• neutral.png, default.jpg', style: TextStyle(fontSize: DesignTokens.fontSizeXs)),
            SizedBox(height: 12),
            Text(
              'Supported formats: PNG, JPG, GIF, WebP',
              style: TextStyle(color: AppTheme.textMuted, fontSize: DesignTokens.fontSizeXs),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('选择文件夹'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Note: Folder picking requires file_picker package
    // For now, show a message that this feature requires additional setup
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('文件夹导入需要 file_picker 包'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}
