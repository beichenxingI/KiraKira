import 'dart:io';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../data/models/chat_background.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../providers/background_providers.dart';
import '../../providers/settings_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/chat/chat_background_widget.dart';
import '../../providers/quote_color_providers.dart';

/// Screen for managing chat backgrounds
class BackgroundSettingsScreen extends ConsumerStatefulWidget {
  final String? characterId; // If set, editing character-specific background

  const BackgroundSettingsScreen({super.key, this.characterId});

  @override
  ConsumerState<BackgroundSettingsScreen> createState() => _BackgroundSettingsScreenState();
}

class _BackgroundSettingsScreenState extends ConsumerState<BackgroundSettingsScreen> {
  late ChatBackground _currentBackground;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentBackground();
  }

  void _loadCurrentBackground() {
    if (widget.characterId != null) {
      final charBg = ref.read(characterBackgroundProvider(widget.characterId!));
      _currentBackground = charBg ?? ChatBackground.none;
    } else {
      _currentBackground = ref.read(globalBackgroundProvider);
    }
  }

  Future<void> _saveBackground(ChatBackground background) async {
    setState(() => _currentBackground = background);
    
    if (widget.characterId != null) {
      await ref.read(characterBackgroundProvider(widget.characterId!).notifier)
          .setBackground(background);
    } else {
      await ref.read(globalBackgroundProvider.notifier).setBackground(background);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isCharacterSpecific = widget.characterId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isCharacterSpecific ? l10n.characterBackground : l10n.chatBackground),
        actions: [
          if (_currentBackground.type != BackgroundType.none)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.clearBackground,
              onPressed: () => _saveBackground(ChatBackground.none),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(DesignTokens.spaceMd),
        children: [
          // Character Avatar Background Setting (only for global settings)
          if (!isCharacterSpecific) ...[
            _buildCharacterAvatarSetting(),
            const SizedBox(height: 24),
          _buildQuoteColorCard(),
          ],
          
          // Preview
          _buildPreviewSection(),
          const SizedBox(height: 24),

          // Preset gradients
          _buildSectionHeader(l10n.gradientPresets),
          const SizedBox(height: 8),
          _buildGradientPresets(),
          const SizedBox(height: 24),

          // Solid colors
          _buildSectionHeader(l10n.solidColors),
          const SizedBox(height: 8),
          _buildColorPresets(),
          const SizedBox(height: 24),

          // Custom image
          _buildSectionHeader(l10n.customImage),
          const SizedBox(height: 8),
          _buildImageSection(),
          const SizedBox(height: 24),

          // Adjustments
          if (_currentBackground.type != BackgroundType.none) ...[
            _buildSectionHeader(l10n.adjustments),
            const SizedBox(height: 8),
            _buildAdjustments(),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: AppTheme.accentColor,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildCharacterAvatarSetting() {
    final useCharacterAvatar = ref.watch(appSettingsProvider.select((s) => s.useCharacterAvatarAsBackground));
    final enableBlur = ref.watch(appSettingsProvider.select((s) => s.enableBackgroundBlur));
    final backgroundOpacity = ref.watch(appSettingsProvider.select((s) => s.backgroundOpacity));
    final l10n = AppLocalizations.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.wallpaper, color: AppTheme.accentColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '图片背景设置', // Image Background Settings
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Use character avatar toggle
            SwitchListTile(
              title: const Text('使用角色卡图片作为背景'),
              subtitle: const Text('如果角色卡有头像图片，将自动作为聊天背景'),
              value: useCharacterAvatar,
              onChanged: (value) {
                ref.read(appSettingsProvider.notifier).updateUseCharacterAvatarAsBackground(value);
              },
              contentPadding: EdgeInsets.zero,
            ),
            
            const Divider(height: 24),
            
            // Background opacity slider
            Row(
              children: [
                const Icon(Icons.opacity, size: 20),
                const SizedBox(width: 12),
                const Text('背景透明度'),
                const Spacer(),
                Text('${(backgroundOpacity * 100).round()}%'),
              ],
            ),
            const SizedBox(height: 8),
            Slider(
              value: backgroundOpacity,
              min: 0.1,
              max: 1.0,
              divisions: 18,
              onChanged: (value) {
                ref.read(appSettingsProvider.notifier).updateBackgroundOpacity(value);
              },
            ),
            Text(
              '应用于所有图片背景（自定义图片 + 角色卡图片）',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textMuted,
              ),
            ),
            
            const Divider(height: 24),
            
            // Background blur toggle
            SwitchListTile(
              title: const Text('启用背景模糊效果'),
              subtitle: const Text('应用模糊效果到所有图片背景'),
              value: enableBlur,
              onChanged: (value) {
                ref.read(appSettingsProvider.notifier).updateEnableBackgroundBlur(value);
              },
              contentPadding: EdgeInsets.zero,
            ),
            
            const SizedBox(height: 8),
            Text(
              '💡 优先级：角色专属背景 > 全局背景 > 角色卡图片 > 默认颜色',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 对话染色设置 ──
  Widget _buildQuoteColorCard() {
    final state = ref.watch(quoteColorStateProvider);
    return Container(
      margin: const EdgeInsets.only(top: DesignTokens.spaceMd),
      padding: const EdgeInsets.all(DesignTokens.spaceMd),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.format_quote, color: AppTheme.accentColor),
              SizedBox(width: 8),
              Text('对话染色',
                  style: TextStyle(fontSize: DesignTokens.fontSizeBodyLarge, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('引号、括号内文字的高亮颜色',
              style: TextStyle(fontSize: DesignTokens.fontSizeXs, color: AppTheme.textMuted)),
          const SizedBox(height: 12),
          // 引号主色
          _quoteColorRow(
            '引号 " " 「」 『』 【】 《》',
            state.primaryA,
            (c) => ref.read(quoteColorStateProvider.notifier).setPrimaryA(c),
          ),
          const SizedBox(height: 8),
          // 括号主色
          _quoteColorRow(
            '括号 （ ） ( )',
            state.primaryB,
            (c) => ref.read(quoteColorStateProvider.notifier).setPrimaryB(c),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () =>
                  ref.read(quoteColorStateProvider.notifier).resetAll(),
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('恢复默认'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quoteColorRow(String label, Color current, void Function(Color) onPick) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: DesignTokens.fontSizeBodyMedium))),
        GestureDetector(
          onTap: () => _showQuoteColorPicker(current, onPick),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: current,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
          ),
        ),
      ],
    );
  }

  void _showQuoteColorPicker(Color current, void Function(Color) onPick) {
    // 预设色板：暖色/冷色各若干，覆盖常用染色需求
    const palette = [
      0xFFFFA726, 0xFFFF7043, 0xFFEF5350, 0xFFEC407A, // 暖
      0xFFAB47BC, 0xFF7E57C2, 0xFF5C6BC0, 0xFF29B6F6, // 紫蓝
      0xFF26C6DA, 0xFF26A69A, 0xFF66BB6A, 0xFF9CCC65, // 青绿
      0xFFFFEE58, 0xFFBDBDBD, 0xFFFFFFFF, 0xFF90A4AE, // 黄灰白
    ];
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('选择颜色'),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: palette.map((v) {
            final c = Color(v);
            final selected = c.value == current.value;
            return GestureDetector(
              onTap: () {
                onPick(c);
                Navigator.pop(ctx);
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? Colors.white : Colors.white24,
                    width: selected ? 3 : 1,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
  Widget _buildPreviewSection() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 200,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_currentBackground.type != BackgroundType.none)
              _BackgroundPreviewFull(background: _currentBackground)
            else
              Container(
                color: AppTheme.darkBackground,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wallpaper, size: 48, color: AppTheme.textMuted),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context).noBackgroundSelected,
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            // Sample chat bubbles overlay
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: DesignTokens.spaceSm),
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard.withValues(alpha: _currentBackground.bubbleOpacity),
                      borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                    ),
                    child: Text(
                      AppLocalizations.of(context).sampleMessage1,
                      style: const TextStyle(color: AppTheme.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: DesignTokens.spaceSm),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withValues(alpha: _currentBackground.bubbleOpacity),
                        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                      ),
                      child: Text(
                        AppLocalizations.of(context).sampleMessage2,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientPresets() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        BackgroundPreview(
          background: ChatBackground.none,
          selected: _currentBackground.type == BackgroundType.none,
          onTap: () => _saveBackground(ChatBackground.none),
        ),
        ...BackgroundPresets.gradients.map((bg) => BackgroundPreview(
          background: bg,
          selected: _currentBackground.type == BackgroundType.gradient &&
              _currentBackground.gradientColors?.join(',') == bg.gradientColors?.join(','),
          onTap: () => _saveBackground(bg),
        )),
      ],
    );
  }

  Widget _buildColorPresets() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: BackgroundPresets.solidColors.map((bg) => BackgroundPreview(
        background: bg,
        selected: _currentBackground.type == BackgroundType.color &&
            _currentBackground.color == bg.color,
        onTap: () => _saveBackground(bg),
      )).toList(),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.image),
                label: Text(AppLocalizations.of(context).chooseImage),
                onPressed: _isLoading ? null : _pickImage,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.link),
                label: Text(AppLocalizations.of(context).fromUrl),
                onPressed: _isLoading ? null : _showUrlDialog,
              ),
            ),
          ],
        ),
        if (_currentBackground.type == BackgroundType.image) ...[
          const SizedBox(height: 12),
          Text(
            _currentBackground.imagePath != null
                ? AppLocalizations.of(context).localImage(p.basename(_currentBackground.imagePath!))
                : _currentBackground.imageUrl != null
                    ? AppLocalizations.of(context).urlLabel(_currentBackground.imageUrl!)
                    : AppLocalizations.of(context).noImage,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildAdjustments() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceMd),
        child: Column(
          children: [
            
            // Bubble opacity slider
            Row(
              children: [
                const Icon(Icons.chat_bubble_outline, size: 20),
                const SizedBox(width: 12),
                Text(AppLocalizations.of(context).bubbleOpacity),
                const SizedBox(width: 4),
                Tooltip(
                  message: AppLocalizations.of(context).bubbleOpacityHelp,
                  triggerMode: TooltipTriggerMode.tap,
                  child: const Icon(Icons.info_outline, size: 16, color: AppTheme.textMuted),
                ),
                const Spacer(),
                Text('${(_currentBackground.bubbleOpacity * 100).round()}%'),
              ],
            ),
            Slider(
              value: _currentBackground.bubbleOpacity,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              onChanged: (value) {
                _saveBackground(_currentBackground.copyWith(bubbleOpacity: value));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    setState(() => _isLoading = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          // Copy to app directory
          final appDir = await getApplicationDocumentsDirectory();
          final bgDir = Directory(p.join(appDir.path, 'KiraKira', 'backgrounds'));
          await bgDir.create(recursive: true);

          final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
          final destPath = p.join(bgDir.path, fileName);
          await File(file.path!).copy(destPath);

          // Get global settings
          final enableBlur = ref.read(appSettingsProvider.select((s) => s.enableBackgroundBlur));
          final opacity = ref.read(appSettingsProvider.select((s) => s.backgroundOpacity));
          
          await _saveBackground(ChatBackground.imagePath(
            destPath,
            opacity: opacity,
            blur: enableBlur,
            blurAmount: 10.0,
            bubbleOpacity: _currentBackground.bubbleOpacity,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).failedToLoadImage(e.toString()))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showUrlDialog() {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.imageUrl),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: l10n.enterImageUrl,
            hintText: 'https://example.com/image.jpg',
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                // Get global settings
                final enableBlur = ref.read(appSettingsProvider.select((s) => s.enableBackgroundBlur));
                final opacity = ref.read(appSettingsProvider.select((s) => s.backgroundOpacity));
                
                _saveBackground(ChatBackground.imageUrl(
                  url,
                  opacity: opacity,
                  blur: enableBlur,
                  blurAmount: 10.0,
                  bubbleOpacity: _currentBackground.bubbleOpacity,
                ));
                Navigator.pop(context);
              }
            },
            child: Text(l10n.apply),
          ),
        ],
      ),
    );
  }
}

class _BackgroundPreviewFull extends StatelessWidget {
  final ChatBackground background;

  const _BackgroundPreviewFull({required this.background});

  @override
  Widget build(BuildContext context) {
    switch (background.type) {
      case BackgroundType.none:
        return Container(color: AppTheme.darkBackground);

      case BackgroundType.color:
        return Container(color: _parseColor(background.color));

      case BackgroundType.gradient:
        final colors = background.gradientColors ?? ['#000000', '#333333'];
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors.map(_parseColor).toList(),
            ),
          ),
        );

      case BackgroundType.video:
        return Container();
      case BackgroundType.image:
        if (background.imagePath != null) {
          return Opacity(
            opacity: background.opacity,
            child: Image.file(
              File(background.imagePath!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.grey[800]),
            ),
          );
        }
        if (background.imageUrl != null) {
          return Opacity(
            opacity: background.opacity,
            child: Image.network(
              background.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.grey[800]),
            ),
          );
        }
        return Container(color: Colors.grey[800]);
    }
  }

  Color _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) {
      return Colors.transparent;
    }

    String hex = hexColor.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }
}