import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' as drift;
import 'package:kirakira/data/database/database.dart';
import 'package:kirakira/data/models/mvu_settings.dart';
import 'package:kirakira/core/services/initialization_service.dart';
import 'package:kirakira/presentation/providers/settings_providers.dart'
    show sharedPreferencesProvider;

/// MVU settings notifier.
///
/// Storage strategy matches AppSettingsNotifier exactly: DB (globalStates)
/// first with SharedPreferences as fallback/migration, dual-written so key
/// data such as API keys stays backed up.
class MvuSettingsNotifier extends StateNotifier<MvuSettings> {
  final SharedPreferences _prefs;
  final AppDatabase _db;
  static const _settingsKey = 'mvu_settings';
  Timer? _debounceTimer;

  MvuSettingsNotifier(this._prefs, this._db) : super(const MvuSettings()) {
    _loadSettings();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    // Force a save on disposal (safety net in case the debounce never fires)
    _saveSettings();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final row = await (_db.select(_db.globalStates)
          ..where((t) => t.key.equals(_settingsKey)))
        .getSingleOrNull();

    String? jsonStr;
    bool needsMigration = false;

    if (row != null) {
      jsonStr = row.value;
    } else {
      jsonStr = _prefs.getString(_settingsKey);
      if (jsonStr != null) needsMigration = true;
    }

if (jsonStr != null) {
  debugPrint('[MVU加载] 读到: ${jsonStr.substring(0, jsonStr.length > 100 ? 100 : jsonStr.length)}');
  try {
    final loaded = MvuSettings.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    state = loaded;
    // Force a notification so the UI receives the loaded state
    state = state.copyWith();
    if (needsMigration) _saveSettings();
  } catch (e) {
    // Fall back to defaults when parsing fails
    if (kDebugMode) debugPrint('[MvuSettings] load failed: $e');
      }
    }
  }

  Future<void> _saveSettings() async {
    final jsonStr = jsonEncode(state.toJson());
    debugPrint('[MVU存储] 写入: apiUrl=${state.apiUrl}, model=${state.modelName}');
    await _db.into(_db.globalStates).insert(
          GlobalStatesCompanion(
            key: const drift.Value(_settingsKey),
            value: drift.Value(jsonStr),
            updatedAt: drift.Value(DateTime.now()),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );
    await _prefs.setString(_settingsKey, jsonStr);
  }

  /// Debounced save (for high-frequency input such as TextField)
  void _debouncedSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _saveSettings();
    });
  }

  // -- Low-frequency operations: save immediately --

  Future<void> updateUpdateMode(String mode) async {
    state = state.copyWith(updateMode: mode);
    await _saveSettings();
  }

  Future<void> updateMaxChatHistory(int n) async {
    state = state.copyWith(maxChatHistory: n.clamp(2, 100));
    await _saveSettings();
  }

  Future<void> updateModelSource(String source) async {
    state = state.copyWith(modelSource: source);
    await _saveSettings();
  }

  Future<void> updateJailbreakScheme(String scheme) async {
    state = state.copyWith(jailbreakScheme: scheme);
    await _saveSettings();
  }

  Future<void> updateAutoRequest(bool enabled) async {
    state = state.copyWith(autoRequest: enabled);
    await _saveSettings();
  }

  Future<void> updateCustomPromptEnabled(bool enabled) async {
    state = state.copyWith(customPromptEnabled: enabled);
    await _saveSettings();
  }

  // -- High-frequency input: debounced save --

  void updateApiUrl(String url) {
    state = state.copyWith(apiUrl: url.trim());
debugPrint('[MVU] updateApiUrl调用: $url');
    _debouncedSave();
  }

  void updateApiKey(String key) {
    state = state.copyWith(apiKey: key.trim());
    _debouncedSave();
  }

  void updateModelName(String name) {
    state = state.copyWith(modelName: name.trim());
    _debouncedSave();
  }

  void updateCustomPrompt(String prompt) {
    state = state.copyWith(customPrompt: prompt);
    _debouncedSave();
  }

  // -- Other --

  /// Applies a whole settings object written back from the WebView side
  /// (Daoyuan/MVU panel saveSettingsDebounced).
  /// Persists immediately (dual-write DB + SharedPreferences) so panel config
  /// and the four notification toggles refresh without data loss.
  Future<void> applyFromWeb(MvuSettings next) async {
    state = next;
    await _saveSettings();
  }

  Future<void> resetToDefaults() async {
    state = const MvuSettings();
    await _saveSettings();
  }
}

/// MVU settings provider.
final mvuSettingsProvider =
    StateNotifierProvider<MvuSettingsNotifier, MvuSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final db = ref.watch(databaseProvider);
  return MvuSettingsNotifier(prefs, db);
});