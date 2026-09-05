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

/// MVU 设置 Notifier。
///
/// 存取策略与 AppSettingsNotifier 完全一致:DB(globalStates)优先 +
/// SharedPreferences 兜底/迁移,双写保证密钥等关键数据可备份。
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
    // 页面销毁时强制保存一次(兜底,防止防抖还没触发就退出)
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
    // 强制触发一次 notifyListeners,确保 UI 能收到
    state = state.copyWith();
    if (needsMigration) _saveSettings();
  } catch (e) {
    // 解析失败沿用默认值
    if (kDebugMode) debugPrint('[MvuSettings] load failed: $e');
      }
    }
  }

  Future<void> _saveSettings() async {
    final jsonStr = jsonEncode(state.toJson());
    debugPrint('[MVU存储] 写入: apiUrl=${state.apiUrl}, model=${state.modelName}');
    await _db.into(_db.globalStates).insert(
          GlobalStatesCompanion(
            key: drift.Value(_settingsKey),
            value: drift.Value(jsonStr),
            updatedAt: drift.Value(DateTime.now()),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );
    await _prefs.setString(_settingsKey, jsonStr);
  }

  /// 防抖存储(用于高频输入,如 TextField)
  void _debouncedSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _saveSettings();
    });
  }

  // ── 低频操作:立即存 ──

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

  // ── 高频输入:防抖存储 ──

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

  // ── 其他 ──

  /// [P5-8/P1] WebView 侧(道渊/MVU 面板 saveSettingsDebounced)写回的整对象应用。
  /// 立即落盘(DB+SP 双写),让面板配置/通知四键刷新不丢。
  Future<void> applyFromWeb(MvuSettings next) async {
    state = next;
    await _saveSettings();
  }

  Future<void> resetToDefaults() async {
    state = const MvuSettings();
    await _saveSettings();
  }
}

/// MVU 设置 provider。
final mvuSettingsProvider =
    StateNotifierProvider<MvuSettingsNotifier, MvuSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final db = ref.watch(databaseProvider);
  return MvuSettingsNotifier(prefs, db);
});