// lib/presentation/dialogs/sprite_settings_dialog.dart
/// Sprite settings dialog (appearance settings migration).
/// Mirrors SpriteSettingsScreen from sprite_settings_screen.dart with every
/// field preserved: general (enable), display (size / position / opacity),
/// animation (transition toggle / duration / show while streaming), emotion
/// detection (how it works / supported emotions), reset to defaults.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/models/sprite.dart';
import 'package:kirakira/presentation/providers/sprite_providers.dart';
import 'package:kirakira/presentation/theme/app_theme.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/widgets/common/kira_components.dart';
import 'package:kirakira/presentation/utils/kira_dialog.dart';
import 'core_dialog.dart';

Future<void> showSpriteSettingsDialog(BuildContext context, WidgetRef ref) {
  return showKiraDialog(
    context: context,
    dialog: const _SpriteSettingsDialog(),
  );
}

class _SpriteSettingsDialog extends ConsumerWidget {
  const _SpriteSettingsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(spriteSettingsProvider);

    return CoreDialogShell(
      title: '表情精灵图',
      icon: CupertinoIcons.sparkles,
      maxWidth: 550,
      trailing: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minSize: 0,
        onPressed: () {
          ref.read(spriteSettingsProvider.notifier).reset();
          coreToast(context, '设置已重置为默认值');
        },
        child: Icon(CupertinoIcons.arrow_counterclockwise,
            size: 20, color: Theme.of(context).textTheme.bodySmall?.color),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // General
          KiraSection(
            title: '通用',
            children: [
              KiraSwitchTile(
                title: '启用精灵图',
                subtitle: '在聊天中显示角色表情图',
                value: settings.enabled,
                onChanged: (value) => ref
                    .read(spriteSettingsProvider.notifier)
                    .setEnabled(value),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Display
          KiraSection(
            title: '显示',
            children: [
              ListTile(
                title: const Text('精灵图尺寸'),
                subtitle: Slider(
                  value: settings.size,
                  min: 50,
                  max: 400,
                  divisions: 35,
                  label: '${settings.size.round()}px',
                  onChanged: settings.enabled
                      ? (value) => ref
                          .read(spriteSettingsProvider.notifier)
                          .setSize(value)
                      : null,
                ),
                trailing: Text(
                  '${settings.size.round()}px',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              ListTile(
                title: const Text('位置'),
                subtitle: const Text('精灵图显示位置'),
                trailing: DropdownButton<SpritePosition>(
                  value: settings.position,
                  onChanged: settings.enabled
                      ? (value) {
                          if (value != null) {
                            ref
                                .read(spriteSettingsProvider.notifier)
                                .setPosition(value);
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
              ListTile(
                title: const Text('透明度'),
                subtitle: Slider(
                  value: settings.opacity,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  label: '${(settings.opacity * 100).round()}%',
                  onChanged: settings.enabled
                      ? (value) => ref
                          .read(spriteSettingsProvider.notifier)
                          .setOpacity(value)
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

          // Animation
          KiraSection(
            title: '动画',
            children: [
              KiraSwitchTile(
                title: '动画过渡',
                subtitle: '精灵图切换时平滑过渡',
                value: settings.animateTransitions,
                onChanged: settings.enabled
                    ? (value) => ref
                        .read(spriteSettingsProvider.notifier)
                        .setAnimateTransitions(value)
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
                      ? (value) => ref
                          .read(spriteSettingsProvider.notifier)
                          .setTransitionDuration(value.round())
                      : null,
                ),
                trailing: Text(
                  '${settings.transitionDurationMs}ms',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              KiraSwitchTile(
                title: '流式生成时显示',
                subtitle: 'AI 生成时显示精灵图',
                value: settings.showDuringStreaming,
                onChanged: settings.enabled
                    ? (value) => ref
                        .read(spriteSettingsProvider.notifier)
                        .setShowDuringStreaming(value)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Emotion detection
          KiraSection(
            title: '情感检测',
            children: [
              const ListTile(
                leading:
                    Icon(Icons.info_outline, color: AppTheme.accentColor),
                title: Text('工作原理'),
                subtitle: Text(
                  'Sprites are automatically selected based on emotion '
                  'keywords detected in messages. '
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
