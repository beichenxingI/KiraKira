import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_providers.dart';

/// 北斗七星：七个位置分别钉了哪个角色 id（null = 空的暗星）
const String _bigDipperKey = 'big_dipper_slots';

final bigDipperProvider =
    StateNotifierProvider<BigDipperNotifier, List<String?>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return BigDipperNotifier(prefs);
});

class BigDipperNotifier extends StateNotifier<List<String?>> {
  final SharedPreferences _prefs;

  // 七个位置，初始全空
  BigDipperNotifier(this._prefs) : super(List.filled(7, null)) {
    _load();
  }

  void _load() {
    final raw = _prefs.getStringList(_bigDipperKey);
    if (raw != null && raw.length == 7) {
      // 存储时用空字符串代表 null
      state = raw.map((e) => e.isEmpty ? null : e).toList();
    }
  }

  Future<void> _save() async {
    await _prefs.setStringList(
      _bigDipperKey,
      state.map((e) => e ?? '').toList(),
    );
  }

  /// 把角色钉到第 index 个位置
  Future<void> setSlot(int index, String? characterId) async {
    if (index < 0 || index > 6) return;
    final next = [...state];
    next[index] = characterId;
    state = next;
    await _save();
  }

  /// 清空某个位置
  Future<void> clearSlot(int index) => setSlot(index, null);
}