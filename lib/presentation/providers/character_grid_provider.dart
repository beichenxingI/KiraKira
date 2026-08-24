// lib/presentation/providers/character_grid_provider.dart
/// 角色页"每页数量"设置(C-T6):内存分页渲染档位 4/8/12/16。
/// 持久化 SharedPreferences,模板照抄 advanced_mode_provider.dart。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final characterGridPageSizeProvider =
    StateNotifierProvider<CharacterGridPageSizeNotifier, int>((ref) {
  return CharacterGridPageSizeNotifier();
});

class CharacterGridPageSizeNotifier extends StateNotifier<int> {
  CharacterGridPageSizeNotifier() : super(12) {
    _load();
  }

  static const String _key = 'character_grid_page_size';

  /// 可选档位(2 列 × 2/4/6/8 行)
  static const List<int> kChoices = [4, 8, 12, 16];

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_key) ?? 12;
    state = kChoices.contains(v) ? v : 12;
  }

  Future<void> set(int value) async {
    if (!kChoices.contains(value)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, value);
    state = value;
  }
}
