import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_providers.dart';

/// 主页背景音乐路径，独立存储，和背景图/视频分开
const String _homeMusicKey = 'home_music_path';

final homeMusicProvider =
    StateNotifierProvider<HomeMusicNotifier, String?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return HomeMusicNotifier(prefs);
});

class HomeMusicNotifier extends StateNotifier<String?> {
  final SharedPreferences _prefs;
  HomeMusicNotifier(this._prefs) : super(null) {
    state = _prefs.getString(_homeMusicKey);
  }

  Future<void> setMusic(String? path) async {
    state = path;
    if (path == null) {
      await _prefs.remove(_homeMusicKey);
    } else {
      await _prefs.setString(_homeMusicKey, path);
    }
  }
}