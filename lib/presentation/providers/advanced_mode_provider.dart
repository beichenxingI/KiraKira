import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final advancedModeProvider = StateNotifierProvider<AdvancedModeNotifier, bool>((ref) {
  return AdvancedModeNotifier();
});

class AdvancedModeNotifier extends StateNotifier<bool> {
  AdvancedModeNotifier() : super(false) { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('advanced_mode_enabled') ?? false;
  }

  Future<void> toggle(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('advanced_mode_enabled', value);
    state = value;
  }
}
