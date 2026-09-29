import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:kirakira/data/models/regex_script.dart';
import 'package:kirakira/domain/services/regex_service.dart';
import 'package:kirakira/data/repositories/character_repository.dart';
import 'package:kirakira/data/repositories/regex_script_repository.dart';
import 'package:kirakira/presentation/providers/settings_providers.dart'
    show sharedPreferencesProvider;
import 'dart:async';

const _uuid = Uuid();

/// Provider for the regex service singleton
final regexServiceProvider = Provider<RegexService>((ref) {
  return RegexService.instance;
});

/// Provider for global regex scripts
/// [Phase 2.4] 优先查表（regex_scripts 表）；首启从 SharedPreferences 迁移；
/// 保存双写（表 + prefs，兼容旧版回滚）
final globalRegexScriptsProvider = StateNotifierProvider<GlobalRegexScriptsNotifier, List<RegexScript>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final regexRepo = ref.watch(regexScriptRepositoryProvider);
  return GlobalRegexScriptsNotifier(prefs, regexRepo);
});

/// Notifier for managing global regex scripts
class GlobalRegexScriptsNotifier extends StateNotifier<List<RegexScript>> {
  static const _storageKey = 'global_regex_scripts';

  final SharedPreferences _prefs;
  final RegexScriptRepository _regexRepo;

  final Completer<void> _readyCompleter = Completer<void>();
  /// 首次加载完成（成功或失败）后 complete，供渲染前 await，确保正则就绪
  Future<void> get ready => _readyCompleter.future;

  GlobalRegexScriptsNotifier(this._prefs, this._regexRepo) : super([]) {
    _loadScripts();
  }

  Future<void> _loadScripts() async {
    try {
      // [Phase 2.4] 优先查表
      final scripts = await _regexRepo.getGlobal();
      if (scripts.isNotEmpty) {
        state = scripts;
        return;
      }
      // 兜底：表为空时从 SharedPreferences 迁移（旧版本数据；
      // 迁移后保留 prefs 作备份，不删除）
      final jsonStr = _prefs.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          // [紧急修复-A] 逐条容错解析：单条失败跳过，不炸掉整个列表
          final parsed = <RegexScript>[];
          for (var i = 0; i < decoded.length; i++) {
            try {
              parsed.add(RegexScript.fromJson(decoded[i] as Map<String, dynamic>));
            } catch (e) {
              debugPrint('[GlobalRegex] prefs 第 $i 条解析失败，跳过: $e');
            }
          }
          if (parsed.isNotEmpty) {
            state = parsed;
            try {
              await _regexRepo.migrateGlobalFromPrefs(state);
            } catch (e, stackTrace) {
              debugPrint('[GlobalRegex] ❌ 迁移全局正则到表失败: $e');
              debugPrint('[GlobalRegex] StackTrace: $stackTrace');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[GlobalRegex] 加载失败: $e');
    } finally {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  Future<void> _saveScripts() async {
    try {
      // [Phase 2.4] 写表 + 双写 SharedPreferences（兼容旧版回滚）
      await _regexRepo.saveGlobal(state);
      final json = jsonEncode(state.map((s) => s.toJson()).toList());
      await _prefs.setString(_storageKey, json);
    } catch (e) {
      debugPrint('[GlobalRegex] 保存失败: $e');
    }
  }

  /// Add a new script
  Future<void> addScript(RegexScript script) async {
    state = [...state, script];
    await _saveScripts();
  }

  /// Update an existing script
  Future<void> updateScript(RegexScript script) async {
    state = state.map((s) => s.id == script.id ? script : s).toList();
    await _saveScripts();
  }

  /// Remove a script
  Future<void> removeScript(String id) async {
    state = state.where((s) => s.id != id).toList();
    await _saveScripts();
  }

  /// Toggle script enabled/disabled
  Future<void> toggleScript(String id) async {
    state = state.map((s) {
      if (s.id == id) {
        return s.copyWith(
          disabled: !s.disabled,
          updatedAt: DateTime.now(),
        );
      }
      return s;
    }).toList();
    await _saveScripts();
  }

  /// Reorder scripts
  Future<void> reorderScripts(int oldIndex, int newIndex) async {
    final scripts = List<RegexScript>.from(state);
    final script = scripts.removeAt(oldIndex);
    scripts.insert(newIndex, script);
    
    // Update order values
    state = scripts.asMap().entries.map((entry) {
      return entry.value.copyWith(order: entry.key);
    }).toList();
    
    await _saveScripts();
  }

  /// Import scripts from JSON
  Future<int> importScripts(String json) async {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! List) {
        throw Exception('Invalid JSON format');
      }
      final scripts = decoded.map((e) {
        final script = RegexScript.fromJson(e as Map<String, dynamic>);
        // Generate new ID to avoid conflicts
        return script.copyWith(
          id: _uuid.v4(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }).toList();
      
      state = [...state, ...scripts];
      await _saveScripts();
      return scripts.length;
    } catch (e) {
      print('Error importing regex scripts: $e');
      return 0;
    }
  }

  /// Export scripts to JSON
  String exportScripts() {
    return jsonEncode(state.map((s) => s.toJson()).toList());
  }
  /// Enable only the scripts with the given IDs, disable all others
  Future<void> setActiveScripts(List<String> activeIds) async {
    final activeSet = activeIds.toSet();
    state = state.map((s) => s.copyWith(
      disabled: !activeSet.contains(s.id),
      updatedAt: DateTime.now(),
    )).toList();
    await _saveScripts();
  }

  /// Add preset scripts
  Future<void> addPresets() async {
    final presets = RegexPresets.all();
    final existingIds = state.map((s) => s.id).toSet();
    
    final newPresets = presets.where((p) => !existingIds.contains(p.id)).toList();
    if (newPresets.isNotEmpty) {
      state = [...state, ...newPresets];
      await _saveScripts();
    }
  }

  /// Clear all scripts
  Future<void> clearAll() async {
    state = [];
    await _saveScripts();
  }
}

/// Provider for character-specific regex scripts
/// [Phase 2.4] 查表（regex_scripts 表）；表空时 extensions 双读降级 + 自动迁移；
/// 保存独立写表，不再触碰 extensions（消除 lost-update 竞态）
final characterRegexScriptsProvider = StateNotifierProvider.family<CharacterRegexScriptsNotifier, List<RegexScript>, String>((ref, characterId) {
  final charRepo = ref.watch(characterRepositoryProvider);
  final regexRepo = ref.watch(regexScriptRepositoryProvider);
  return CharacterRegexScriptsNotifier(
    characterId: characterId,
    charRepo: charRepo,
    regexRepo: regexRepo,
  );
});

class CharacterRegexScriptsNotifier extends StateNotifier<List<RegexScript>> {
  final String characterId;
  final CharacterRepository _charRepo;
  final RegexScriptRepository _regexRepo;

  final Completer<void> _readyCompleter = Completer<void>();
  Future<void> get ready => _readyCompleter.future;

  CharacterRegexScriptsNotifier({
    required this.characterId,
    required CharacterRepository charRepo,
    required RegexScriptRepository regexRepo,
  })  : _charRepo = charRepo,
        _regexRepo = regexRepo,
        super([]) {
    _loadScripts();
  }

  Future<void> _loadScripts() async {
    try {
      // [Phase 2.4] 改为查表，不再读 extensions
      final scripts = await _regexRepo.getForCharacter(characterId);
      if (scripts.isNotEmpty) {
        state = scripts;
        return;
      }
      // 双读降级：表为空【或表条数少于 extensions 条数】（迁移失败/部分迁移兜底），用 extensions 重建表
      final character = await _charRepo.getCharacter(characterId);
      final rawList = character?.extensions['regex_scripts'];
      if (rawList is List && rawList.isNotEmpty) {
        // [紧急修复-A] 双格式解析（自家优先/ST 兜底）+ 逐条 try-catch：
        // 单条解析失败不再炸掉整个列表（Phase 2 旧兜底只支持自家格式，ST 卡整体丢失）
        final parsed = <RegexScript>[];
        for (var i = 0; i < rawList.length; i++) {
          final raw = rawList[i];
          if (raw is! Map) {
            debugPrint(
                '[Regex] extensions 第 $i 条非 Map，跳过: ${raw?.runtimeType}');
            continue;
          }
          final s = parseRegexScriptRobust(
            Map<String, dynamic>.from(raw),
            characterId,
            i,
          );
          if (s == null) {
            debugPrint(
                '[Regex] ❌ extensions 第 $i 条解析失败: keys=${raw.keys.take(8).toList()} raw=$raw');
            continue;
          }
          parsed.add(s);
        }
        debugPrint(
            '[Regex] 双读降级解析完成: ${parsed.length}/${rawList.length} 条 (表中原有 ${scripts.length} 条)');
        if (parsed.length > scripts.length) {
          // extensions 数据更完整（表为空或部分迁移）→ 用 extensions 重建表
          try {
            await _regexRepo.saveForCharacter(characterId, parsed);
            // 保存后重读表，保证内存 id 与表行 id 一致
            final saved = await _regexRepo.getForCharacter(characterId);
            state = saved.isNotEmpty ? saved : parsed;
            debugPrint('[Regex] ✅ 重建表完成: ${state.length} 条');
          } catch (e, stackTrace) {
            debugPrint('[Regex] ❌ 重建表失败: $e');
            debugPrint('[Regex] StackTrace: $stackTrace');
            state = parsed;
          }
        } else if (scripts.isEmpty) {
          state = parsed;
        } else {
          state = scripts;
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[Regex] 加载失败: $e');
      debugPrint('[Regex] StackTrace: $stackTrace');
      state = [];
    } finally {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  Future<void> _saveScripts() async {
    try {
      // [Phase 2.4] 独立写表，删除 extensions 整行读改写（消除 lost-update 竞态）
      await _regexRepo.saveForCharacter(characterId, state);
      debugPrint('[Regex] 保存成功: ${state.length} 条');
    } catch (e, stackTrace) {
      debugPrint('❌ 正则保存失败: $e');
      debugPrint('❌ StackTrace: $stackTrace');
      // [紧急修复-E] Phase 2 误删的 rethrow 恢复：保存失败不再静默，上层可感知
      rethrow;
    }
  }

  Future<void> addScript(RegexScript script) async {
    final newScript = script.copyWith(
      characterId: characterId,
      scriptType: RegexScriptType.character,
    );
    state = [...state, newScript];
    await _saveScripts();
  }

  Future<void> updateScript(RegexScript script) async {
    state = state.map((s) => s.id == script.id ? script : s).toList();
    await _saveScripts();
  }

  Future<void> removeScript(String id) async {
    state = state.where((s) => s.id != id).toList();
    await _saveScripts();
  }

  Future<void> toggleScript(String id) async {
    state = state.map((s) {
      if (s.id == id) {
        return s.copyWith(
          disabled: !s.disabled,
          updatedAt: DateTime.now(),
        );
      }
      return s;
    }).toList();
    await _saveScripts();
  }
}

/// Provider for combined regex scripts (global + character)
final combinedRegexScriptsProvider = Provider.family<List<RegexScript>, String?>((ref, characterId) {
  final globalScripts = ref.watch(globalRegexScriptsProvider);
  
  if (characterId == null) {
    return globalScripts.where((s) => !s.disabled).toList();
  }
  
  final characterScripts = ref.watch(characterRegexScriptsProvider(characterId));
  
  // Combine and sort by order
  final combined = [...globalScripts, ...characterScripts]
    .where((s) => !s.disabled)
    .toList()
    ..sort((a, b) => a.order.compareTo(b.order));
  
  return combined;
});

/// 等待「全局正则 + 指定角色正则」都首次加载完成。
/// 渲染前 await，确保开场白等首屏消息用到的是就绪后的正则，一次渲染即正确。
final regexScriptsReadyProvider =
    Provider.family<Future<void>, String?>((ref, characterId) {
  final globalReady = ref.read(globalRegexScriptsProvider.notifier).ready;
  if (characterId == null) return globalReady;
  final charReady =
      ref.read(characterRegexScriptsProvider(characterId).notifier).ready;
  return Future.wait([globalReady, charReady]);
});

/// Provider for regex settings
final regexSettingsProvider = StateNotifierProvider<RegexSettingsNotifier, RegexSettings>((ref) {
  return RegexSettingsNotifier();
});

/// Regex feature settings
class RegexSettings {
  final bool enabled;
  final bool applyToUserInput;
  final bool applyToAiOutput;
  final bool applyToSlashCommands;
  final bool applyToWorldInfo;
  final bool applyToReasoning;

  const RegexSettings({
    this.enabled = true,
    this.applyToUserInput = true,
    this.applyToAiOutput = true,
    this.applyToSlashCommands = false,
    this.applyToWorldInfo = false,
    this.applyToReasoning = false,
  });

  RegexSettings copyWith({
    bool? enabled,
    bool? applyToUserInput,
    bool? applyToAiOutput,
    bool? applyToSlashCommands,
    bool? applyToWorldInfo,
    bool? applyToReasoning,
  }) {
    return RegexSettings(
      enabled: enabled ?? this.enabled,
      applyToUserInput: applyToUserInput ?? this.applyToUserInput,
      applyToAiOutput: applyToAiOutput ?? this.applyToAiOutput,
      applyToSlashCommands: applyToSlashCommands ?? this.applyToSlashCommands,
      applyToWorldInfo: applyToWorldInfo ?? this.applyToWorldInfo,
      applyToReasoning: applyToReasoning ?? this.applyToReasoning,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'applyToUserInput': applyToUserInput,
    'applyToAiOutput': applyToAiOutput,
    'applyToSlashCommands': applyToSlashCommands,
    'applyToWorldInfo': applyToWorldInfo,
    'applyToReasoning': applyToReasoning,
  };

  factory RegexSettings.fromJson(Map<String, dynamic> json) {
    return RegexSettings(
      enabled: json['enabled'] as bool? ?? true,
      applyToUserInput: json['applyToUserInput'] as bool? ?? true,
      applyToAiOutput: json['applyToAiOutput'] as bool? ?? true,
      applyToSlashCommands: json['applyToSlashCommands'] as bool? ?? false,
      applyToWorldInfo: json['applyToWorldInfo'] as bool? ?? false,
      applyToReasoning: json['applyToReasoning'] as bool? ?? false,
    );
  }
}

/// Notifier for regex settings
class RegexSettingsNotifier extends StateNotifier<RegexSettings> {
  static const _storageKey = 'regex_settings';
  
  RegexSettingsNotifier() : super(const RegexSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map<String, dynamic>) {
          state = RegexSettings.fromJson(decoded);
        }
      }
    } catch (e) {
      print('Error loading regex settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(state.toJson()));
    } catch (e) {
      print('Error saving regex settings: $e');
    }
  }

  void setEnabled(bool value) {
    state = state.copyWith(enabled: value);
    _saveSettings();
  }

  void setApplyToUserInput(bool value) {
    state = state.copyWith(applyToUserInput: value);
    _saveSettings();
  }

  void setApplyToAiOutput(bool value) {
    state = state.copyWith(applyToAiOutput: value);
    _saveSettings();
  }

  void setApplyToSlashCommands(bool value) {
    state = state.copyWith(applyToSlashCommands: value);
    _saveSettings();
  }

  void setApplyToWorldInfo(bool value) {
    state = state.copyWith(applyToWorldInfo: value);
    _saveSettings();
  }

  void setApplyToReasoning(bool value) {
    state = state.copyWith(applyToReasoning: value);
    _saveSettings();
  }

  void reset() {
    state = const RegexSettings();
    _saveSettings();
  }
}

/// Helper function to create a new regex script
RegexScript createRegexScript({
  required String scriptName,
  String? description,
  required String findRegex,
  required String replaceString,
  List<RegexPlacement> placement = const [RegexPlacement.aiOutput],
  RegexScriptType scriptType = RegexScriptType.global,
  bool markdownOnly = false,
  bool promptOnly = false,
  bool runOnEdit = false,
  SubstituteRegex substituteRegex = SubstituteRegex.none,
  List<String> trimStrings = const [],
  int? minDepth,
  int? maxDepth,
  String? characterId,
  String? chatId,
}) {
  return RegexScript(
    id: _uuid.v4(),
    scriptName: scriptName,
    description: description,
    findRegex: findRegex,
    replaceString: replaceString,
    placement: placement,
    trimStrings: trimStrings,
    scriptType: scriptType,
    markdownOnly: markdownOnly,
    promptOnly: promptOnly,
    runOnEdit: runOnEdit,
    substituteRegex: substituteRegex,
    minDepth: minDepth,
    maxDepth: maxDepth,
    characterId: characterId,
    chatId: chatId,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}
