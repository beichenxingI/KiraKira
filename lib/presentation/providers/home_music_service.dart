import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'home_music_providers.dart';

/// Global home music service.
///
/// The player lives outside any page, with a lifetime following the app. Any
/// screen can play and control it. The app auto-pauses in the background (without
/// disturbing the user) and resumes when returning to the foreground if it was playing.
///
/// Listens to homeMusicProvider path changes: plays when set, stops when cleared.
final homeMusicServiceProvider = Provider<HomeMusicService>((ref) {
  final service = HomeMusicService();
  ref.listen<String?>(homeMusicProvider, (prev, next) {
    service.loadAndPlay(next);
  }, fireImmediately: true);
  ref.onDispose(service.dispose);
  return service;
});

class HomeMusicService with WidgetsBindingObserver {
  final AudioPlayer _player = AudioPlayer();
  String? _loadedPath;

  /// Whether the app was playing before going to the background (decides whether to resume on return)
  bool _wasPlayingBeforePause = false;

  HomeMusicService() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Load and loop-play; stops when path is null
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
      // File unavailable, etc.; silently ignore without crashing
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Resumed: only resume if it was playing before going to the background (avoids restarting after a manual stop)
      if (_wasPlayingBeforePause && _loadedPath != null) {
        _player.play();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      // Backgrounded: remember playing state and pause; do not disturb the user in the background
      _wasPlayingBeforePause = _player.playing;
      _player.pause();
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _player.dispose();
  }
}