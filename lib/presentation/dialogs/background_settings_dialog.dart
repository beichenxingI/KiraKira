// lib/presentation/dialogs/background_settings_dialog.dart
/// 聊天背景设置浮窗(外观三项迁移)
/// 内容完整迁自 background_settings_screen.dart,字段一个不少:
/// 角色头像背景(仅全局:启用/透明度/模糊) · 对话染色(引号/括号色)
/// 预览 · 渐变预设 · 纯色预设 · 自定义图片(选图/URL)
/// 气泡透明度调整 · 清除背景
library;

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:kirakira/data/models/chat_background.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/providers/background_providers.dart';
import 'package:kirakira/presentation/providers/settings_providers.dart';
import 'package:kirakira/presentation/providers/quote_color_providers.dart';
import 'package:kirakira/presentation/theme/app_theme.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/widgets/chat/chat_background_widget.dart';
import 'package:kirakira/presentation/widgets/common/kira_components.dart';
import 'package:kirakira/presentation/utils/kira_dialog.dart';
import 'core_dialog.dart';

Future<void> showBackgroundSettingsDialog(
  BuildContext context,
  WidgetRef ref, {
  String? characterId,
}) {
  return showKiraDialog(
    context: context,
    dialog: _BackgroundSettingsDialog(characterId: characterId),
  );
}

class _BackgroundSettingsDialog extends ConsumerStatefulWidget {
  final String? characterId;
  const _BackgroundSettingsDialog({this.characterId});

  @override
  ConsumerState<_BackgroundSettingsDialog> createState() =>
      _BackgroundSettingsDialogState();
}

class _BackgroundSettingsDialogState
    extends ConsumerState<_BackgroundSettingsDialog> {
  late ChatBackground _currentBackground;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentBackground();
  }

  void _loadCurrentBackground() {
    if (widget.characterId != null) {
      final charBg =
          ref.read(characterBackgroundProvider(widget.characterId!));
      _currentBackground = charBg ?? ChatBackground.none;
    } else {
      _currentBackground = ref.read(globalBackgroundProvider);
    }
  }

  Future<void> _saveBackground(ChatBackground background) async {
    setState(() => _currentBackground = background);

    if (widget.characterId != null) {
      await ref
          .read(characterBackgroundProvider(widget.characterId!).notifier)
          .setBackground(background);
    } else {
      await ref.read(globalBackgroundProvider.notifier).setBackground(background);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isCharacterSpecific = widget.characterId != null;

    return CoreDialogShell(
      title: isCharacterSpecific ? l10n.characterBackground : l10n.chatBackground,
      icon: CupertinoIcons.photo,
      maxWidth: 550,
      trailing: _currentBackground.type != BackgroundType.none
          ? CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minSize: 0,
              onPressed: () => _saveBackground(ChatBackground.none),
              child: Icon(CupertinoIcons.delete,
                  size: 20, color: DesignTokens.statusError),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 角色头像背景设置(仅全局)
          if (!isCharacterSpecific) ...[
            _buildCharacterAvatarSetting(),
            const SizedBox(height: 16),
            _buildQuoteColorCard(),
            const SizedBox(height: 16),
          ],

          // 预览
          _buildPreviewSection(),
          const SizedBox(height: 16),

          // 渐变预设
          _buildSectionHeader(l10n.gradientPresets),
          const SizedBox(height: 8),
          _buildGradientPresets(),
          const SizedBox(height: 16),

          // 纯色预设
          _buildSectionHeader(l10n.solidColors),
          const SizedBox(height: 8),
          _buildColorPresets(),
          const SizedBox(height: 16),

          // 自定义图片
          _buildSectionHeader(l10n.customImage),
          const SizedBox(height: 8),
          _buildImageSection(),
          const SizedBox(height: 16),

          // 调整(仅当有背景时)
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
    final useCharacterAvatar = ref.watch(
        appSettingsProvider.select((s) => s.useCharacterAvatarAsBackground));
    final enableBlur =
        ref.watch(appSettingsProvider.select((s) => s.enableBackgroundBlur));
    final backgroundOpacity =
        ref.watch(appSettingsProvider.select((s) => s.backgroundOpacity));

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
                    '图片背景设置',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            KiraSwitchTile(
              title: '使用角色卡图片作为背景',
              subtitle: '如果角色卡有头像图片，将自动作为聊天背景',
              value: useCharacterAvatar,
              onChanged: (value) => ref
                  .read(appSettingsProvider.notifier)
                  .updateUseCharacterAvatarAsBackground(value),
            ),
            const Divider(height: 24),
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
              onChanged: (value) => ref
                  .read(appSettingsProvider.notifier)
                  .updateBackgroundOpacity(value),
            ),
            Text(
              '应用于所有图片背景（自定义图片 + 角色卡图片）',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.textMuted),
            ),
            const Divider(height: 24),
            KiraSwitchTile(
              title: '启用背景模糊效果',
              subtitle: '应用模糊效果到所有图片背景',
              value: enableBlur,
              onChanged: (value) => ref
                  .read(appSettingsProvider.notifier)
                  .updateEnableBackgroundBlur(value),
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
                  style: TextStyle(
                      fontSize: DesignTokens.fontSizeBodyLarge,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('引号、括号内文字的高亮颜色',
              style: TextStyle(
                  fontSize: DesignTokens.fontSizeXs,
                  color: AppTheme.textMuted)),
          const SizedBox(height: 12),
          _quoteColorRow(
            '引号 " " 「」 『』 【】 《》',
            state.primaryA,
            (c) =>
                ref.read(quoteColorStateProvider.notifier).setPrimaryA(c),
          ),
          const SizedBox(height: 8),
          _quoteColorRow(
            '括号 （ ） ( )',
            state.primaryB,
            (c) =>
                ref.read(quoteColorStateProvider.notifier).setPrimaryB(c),
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

  Widget _quoteColorRow(
      String label, Color current, void Function(Color) onPick) {
    return Row(
      children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: DesignTokens.fontSizeBodyMedium))),
        GestureDetector(
          onTap: () => _showQuoteColorPicker(current, onPick),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: current,
              borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
              border: Border.all(color: Colors.white24),
            ),
          ),
        ),
      ],
    );
  }

  void _showQuoteColorPicker(Color current, void Function(Color) onPick) {
    const palette = [
      0xFFFFA726, 0xFFFF7043, 0xFFEF5350, 0xFFEC407A,
      0xFFAB47BC, 0xFF7E57C2, 0xFF5C6BC0, 0xFF29B6F6,
      0xFF26C6DA, 0xFF26A69A, 0xFF66BB6A, 0xFF9CCC65,
      0xFFFFEE58, 0xFFBDBDBD, 0xFFFFFFFF, 0xFF90A4AE,
    ];
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
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
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
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
                      const Icon(Icons.wallpaper,
                          size: 48, color: AppTheme.textMuted),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context).noBackgroundSelected,
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: DesignTokens.spaceSm),
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard
                          .withValues(alpha: _currentBackground.bubbleOpacity),
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusMd),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: DesignTokens.spaceSm),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor
                            .withValues(alpha: _currentBackground.bubbleOpacity),
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusMd),
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
                  _currentBackground.gradientColors?.join(',') ==
                      bg.gradientColors?.join(','),
              onTap: () => _saveBackground(bg),
            )),
      ],
    );
  }

  Widget _buildColorPresets() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: BackgroundPresets.solidColors
          .map((bg) => BackgroundPreview(
                background: bg,
                selected: _currentBackground.type == BackgroundType.color &&
                    _currentBackground.color == bg.color,
                onTap: () => _saveBackground(bg),
              ))
          .toList(),
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
                ? AppLocalizations.of(context)
                    .localImage(p.basename(_currentBackground.imagePath!))
                : _currentBackground.imageUrl != null
                    ? AppLocalizations.of(context)
                        .urlLabel(_currentBackground.imageUrl!)
                    : AppLocalizations.of(context).noImage,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.textMuted),
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
            Row(
              children: [
                const Icon(Icons.chat_bubble_outline, size: 20),
                const SizedBox(width: 12),
                Text(AppLocalizations.of(context).bubbleOpacity),
                const SizedBox(width: 4),
                Tooltip(
                  message: AppLocalizations.of(context).bubbleOpacityHelp,
                  triggerMode: TooltipTriggerMode.tap,
                  child: const Icon(Icons.info_outline,
                      size: 16, color: AppTheme.textMuted),
                ),
                const Spacer(),
                Text(
                    '${(_currentBackground.bubbleOpacity * 100).round()}%'),
              ],
            ),
            Slider(
              value: _currentBackground.bubbleOpacity,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              onChanged: (value) {
                _saveBackground(
                    _currentBackground.copyWith(bubbleOpacity: value));
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
          final appDir = await getApplicationDocumentsDirectory();
          final bgDir =
              Directory(p.join(appDir.path, 'KiraKira', 'backgrounds'));
          await bgDir.create(recursive: true);
          final fileName =
              '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
          final destPath = p.join(bgDir.path, fileName);
          await File(file.path!).copy(destPath);
          final enableBlur = ref.read(
              appSettingsProvider.select((s) => s.enableBackgroundBlur));
          final opacity = ref
              .read(appSettingsProvider.select((s) => s.backgroundOpacity));
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
          SnackBar(
              content: Text(
                  AppLocalizations.of(context).failedToLoadImage(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showUrlDialog() {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
                l10n.imageUrl,
                style: const TextStyle(
                  fontSize: DesignTokens.fontSizeHeadline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: controller,
                autofocus: true,
                placeholder: 'https://example.com/image.jpg',
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(sheetCtx)
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusGroupedCard),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final url = controller.text.trim();
                    if (url.isNotEmpty) {
                      final enableBlur = ref.read(appSettingsProvider
                          .select((s) => s.enableBackgroundBlur));
                      final opacity = ref.read(appSettingsProvider
                          .select((s) => s.backgroundOpacity));
                      _saveBackground(ChatBackground.imageUrl(
                        url,
                        opacity: opacity,
                        blur: enableBlur,
                        blurAmount: 10.0,
                        bubbleOpacity: _currentBackground.bubbleOpacity,
                      ));
                      Navigator.pop(sheetCtx);
                    }
                  },
                  child: Text(l10n.save),
                ),
              ),
            ],
          ),
        ),
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
              errorBuilder: (_, __, ___) =>
                  Container(color: Colors.grey[800]),
            ),
          );
        }
        if (background.imageUrl != null) {
          return Opacity(
            opacity: background.opacity,
            child: Image.network(
              background.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: Colors.grey[800]),
            ),
          );
        }
        return Container(color: Colors.grey[800]);
    }
  }

  Color _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return Colors.transparent;
    String hex = hexColor.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}
