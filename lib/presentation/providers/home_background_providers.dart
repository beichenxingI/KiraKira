import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/chat_background.dart';
import 'settings_providers.dart';

/// 主页背景独立存储 key，和聊天背景（global_chat_background）完全分开
const String _homeBackgroundKey = 'home_screen_background';

final homeBackgroundProvider =
    StateNotifierProvider<HomeBackgroundNotifier, ChatBackground>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return HomeBackgroundNotifier(prefs);
});

class HomeBackgroundNotifier extends StateNotifier<ChatBackground> {
  final SharedPreferences _prefs;

  HomeBackgroundNotifier(this._prefs) : super(ChatBackground.none) {
    _load();
  }

  void _load() {
    final s = _prefs.getString(_homeBackgroundKey);
    if (s != null) {
      try {
        state = ChatBackground.fromJsonString(s);
      } catch (_) {
        state = ChatBackground.none;
      }
    }
  }

  Future<void> _save() async {
    if (state.type == BackgroundType.none) {
      await _prefs.remove(_homeBackgroundKey);
    } else {
      await _prefs.setString(_homeBackgroundKey, state.toJsonString());
    }
  }

  Future<void> setBackground(ChatBackground bg) async {
    state = bg;
    await _save();
  }

  Future<void> clearBackground() async {
    state = ChatBackground.none;
    await _save();
  }
}