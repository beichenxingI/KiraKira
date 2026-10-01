// lib/presentation/providers/character_grid_provider.dart
/// Character grid page items-per-page setting for in-memory pagination (choices 4/8/12/16),
/// persisted to SharedPreferences following the same pattern as advanced_mode_provider.dart.
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

  /// Allowed choices (2 columns x 2/4/6/8 rows)
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
