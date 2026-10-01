import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_providers.dart';

/// Big Dipper: character id pinned to each of the seven slots (null = empty slot)
const String _bigDipperKey = 'big_dipper_slots';

final bigDipperProvider =
    StateNotifierProvider<BigDipperNotifier, List<String?>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return BigDipperNotifier(prefs);
});

class BigDipperNotifier extends StateNotifier<List<String?>> {
  final SharedPreferences _prefs;

  // Seven slots, all empty initially
  BigDipperNotifier(this._prefs) : super(List.filled(7, null)) {
    _load();
  }

  void _load() {
    final raw = _prefs.getStringList(_bigDipperKey);
    if (raw != null && raw.length == 7) {
      // Empty string encodes null in storage
      state = raw.map((e) => e.isEmpty ? null : e).toList();
    }
  }

  Future<void> _save() async {
    await _prefs.setStringList(
      _bigDipperKey,
      state.map((e) => e ?? '').toList(),
    );
  }

  /// Pins a character to the slot at [index]
  Future<void> setSlot(int index, String? characterId) async {
    if (index < 0 || index > 6) return;
    final next = [...state];
    next[index] = characterId;
    state = next;
    await _save();
  }

  /// Clears the given slot
  Future<void> clearSlot(int index) => setSlot(index, null);
}