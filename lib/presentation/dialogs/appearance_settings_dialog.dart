// lib/presentation/dialogs/appearance_settings_dialog.dart
/// Home appearance settings dialog (appearance settings migration).
/// Mirrors home_appearance_screen.dart with every field preserved: background
/// (custom / reset to default) and background music (select / remove).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:kirakira/data/models/chat_background.dart';
import 'package:kirakira/presentation/providers/home_background_providers.dart';
import 'package:kirakira/presentation/providers/home_music_providers.dart';
import 'package:kirakira/presentation/widgets/common/common.dart';
import 'package:kirakira/presentation/utils/kira_dialog.dart';
import 'core_dialog.dart';

Future<void> showAppearanceSettingsDialog(BuildContext context, WidgetRef ref) {
  return showKiraDialog(
    context: context,
    dialog: const _AppearanceSettingsDialog(),
  );
}

class _AppearanceSettingsDialog extends ConsumerWidget {
  const _AppearanceSettingsDialog();

  Future<void> _pickBackground(WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.media,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final path = file.path;
    if (path == null) return;
    final ext = (file.extension ?? '').toLowerCase();
    final isVideo = ['mp4', 'mov', 'webm', 'mkv', 'avi'].contains(ext);
    final notifier = ref.read(homeBackgroundProvider.notifier);
    if (isVideo) {
      await notifier.setBackground(ChatBackground.videoPath(path));
    } else {
      await notifier.setBackground(ChatBackground.imagePath(path));
    }
  }

  Future<void> _pickMusic(WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    await ref.read(homeMusicProvider.notifier).setMusic(path);
  }

  /// Clearing the custom background is destructive, so it requires
  /// CupertinoAlertDialog confirmation (matches the original page).
  Future<void> _confirmClearBackground(
      BuildContext context, WidgetRef ref) async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('恢复默认背景'),
        content: const Text('将清除自定义背景，回到四时海景？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('恢复默认'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(homeBackgroundProvider.notifier).clearBackground();
  }

  Future<void> _confirmRemoveMusic(BuildContext context, WidgetRef ref) async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('移除音乐'),
        content: const Text('将移除当前设置的背景音乐？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(homeMusicProvider.notifier).setMusic(null);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeBg = ref.watch(homeBackgroundProvider);
    final musicPath = ref.watch(homeMusicProvider);
    final hasBg = homeBg.type != BackgroundType.none;

    return CoreDialogShell(
      title: '主页外观',
      icon: CupertinoIcons.house,
      maxWidth: 550,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Background
          KiraSection(
            title: '背景',
            children: [
              KiraGroupedTile(
                icon: hasBg
                    ? CupertinoIcons.photo_fill
                    : CupertinoIcons.photo,
                title: '自定义背景',
                subtitle: hasBg
                    ? (homeBg.type == BackgroundType.video
                        ? '已设置：视频'
                        : '已设置：图片')
                    : '默认：随时间变化的海景',
                onTap: () => _pickBackground(ref),
              ),
              if (hasBg)
                KiraGroupedTile(
                  icon: CupertinoIcons.arrow_counterclockwise,
                  title: '恢复默认背景',
                  subtitle: '清除自定义，回到四时海景',
                  onTap: () => _confirmClearBackground(context, ref),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Background music
          KiraSection(
            title: '背景音乐',
            children: [
              KiraGroupedTile(
                icon: musicPath != null
                    ? CupertinoIcons.music_note
                    : CupertinoIcons.music_note_2,
                title: '选择音乐',
                subtitle: musicPath != null ? '已设置' : '未设置',
                onTap: () => _pickMusic(ref),
              ),
              if (musicPath != null)
                KiraGroupedTile(
                  icon: CupertinoIcons.xmark_circle,
                  title: '移除音乐',
                  onTap: () => _confirmRemoveMusic(context, ref),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
