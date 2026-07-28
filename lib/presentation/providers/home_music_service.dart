import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'home_music_providers.dart';

/// 全局主页音乐服务
///
/// 播放器脱离任何页面，生命周期跟随 App。任何界面都能听、都能控制。
/// App 切到后台自动暂停（不打扰用户），回到前台且原本在播时恢复。
///
/// 监听 homeMusicProvider 的路径变化：设了就播，清了就停。
final homeMusicServiceProvider = Provider<HomeMusicService>((ref) {
  final service = HomeMusicService();
  // 监听路径变化，驱动播放
  ref.listen<String?>(homeMusicProvider, (prev, next) {
    service.loadAndPlay(next);
  }, fireImmediately: true);
  ref.onDispose(service.dispose);
  return service;
});

class HomeMusicService with WidgetsBindingObserver {
  final AudioPlayer _player = AudioPlayer();
  String? _loadedPath;

  /// App 进后台前是否正在播放（用于回前台时决定要不要恢复）
  bool _wasPlayingBeforePause = false;

  HomeMusicService() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// 加载并循环播放；path 为 null 则停止
  Future<void> loadAndPlay(String? path) async {
    if (path == _loadedPath) return;
    _loadedPath = path;
    if (path == null) {
      await _player.stop();
      return;
    }
    try {
      await _player.setFilePath(path);
      await _player.setLoopMode(LoopMode.one);
      await _player.play();
    } catch (_) {
      // 文件失效等，静默忽略，不崩
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 回前台：仅当进后台前在播才恢复（避免用户手动停了又被唤起）
      if (_wasPlayingBeforePause && _loadedPath != null) {
        _player.play();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      // 进后台：记住播放状态并暂停，不在后台打扰用户
      _wasPlayingBeforePause = _player.playing;
      _player.pause();
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _player.dispose();
  }
}