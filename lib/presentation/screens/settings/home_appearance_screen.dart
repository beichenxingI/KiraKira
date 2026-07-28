import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:kirakira/data/models/chat_background.dart';
import 'package:kirakira/presentation/providers/home_background_providers.dart';
import 'package:kirakira/presentation/providers/home_music_providers.dart';

/// 主页外观设置：背景图/视频 + 背景音乐
///
/// 从旧主界面右上角迁移而来。主界面回归纯展示，配置沉入设置。
class HomeAppearanceScreen extends ConsumerWidget {
  const HomeAppearanceScreen({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeBg = ref.watch(homeBackgroundProvider);
    final musicPath = ref.watch(homeMusicProvider);
    final hasBg = homeBg.type != BackgroundType.none;

    return Scaffold(
      appBar: AppBar(title: const Text('主页外观')),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          _sectionHeader(context, '背景'),
          ListTile(
            leading: Icon(hasBg ? Icons.image_rounded : Icons.wallpaper_rounded),
            title: const Text('自定义背景'),
            subtitle: Text(
              hasBg
                  ? (homeBg.type == BackgroundType.video ? '已设置：视频' : '已设置：图片')
                  : '默认：随时间变化的海景',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickBackground(ref),
          ),
          if (hasBg)
            ListTile(
              leading: const Icon(Icons.clear_rounded),
              title: const Text('恢复默认背景'),
              subtitle: const Text('清除自定义，回到四时海景'),
              onTap: () =>
                  ref.read(homeBackgroundProvider.notifier).clearBackground(),
            ),

          const Divider(height: 32),
          _sectionHeader(context, '背景音乐'),
          ListTile(
            leading: Icon(
              musicPath != null
                  ? Icons.music_note_rounded
                  : Icons.music_off_rounded,
            ),
            title: const Text('选择音乐'),
            subtitle: Text(musicPath != null ? '已设置' : '未设置'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickMusic(ref),
          ),
          if (musicPath != null)
            ListTile(
              leading: const Icon(Icons.clear_rounded),
              title: const Text('移除音乐'),
              onTap: () =>
                  ref.read(homeMusicProvider.notifier).setMusic(null),
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}