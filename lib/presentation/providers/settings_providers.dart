import 'dart:math' as math;
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirakira/domain/services/llm_service.dart';
import 'package:kirakira/domain/services/chat_summarization_service.dart';
import 'package:kirakira/domain/services/tokenizer_service.dart';
import 'package:drift/drift.dart' as drift;
import 'package:kirakira/data/database/database.dart';
import 'package:kirakira/core/services/initialization_service.dart';
import 'package:kirakira/presentation/screens/terms_dialog.dart';
import 'package:kirakira/presentation/providers/settings_providers.dart';

/// Log a message to the console
void _log(String message, {String? error, StackTrace? stackTrace}) {
  final timestamp = DateTime.now().toIso8601String();
  final logMessage = '[$timestamp] SettingsProvider: $message';
  
  if (kDebugMode) {
    debugPrint(logMessage);
    if (error != null) {
      debugPrint('  Error: $error');
    }
  }
  
  developer.log(
    message,
    name: 'SettingsProvider',
    error: error,
    stackTrace: stackTrace,
  );
}

/// Shared preferences provider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

/// Provider for LLM service
final llmServiceProvider = Provider<LLMService>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

/// Provider for EJS render registry(活跃聊天页登记 EJS 渲染函数)
final ejsRenderRegistryProvider = Provider<EJSRenderRegistry>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

class LLMConfigNotifier extends StateNotifier<LLMConfig> {
  final SharedPreferences _prefs;
  final AppDatabase _db;
  static const _configKey = 'llm_config';
  static const _providerConfigKeyPrefix = 'llm_provider_config_';

  /// Phase 3: Map a multi-config provider string to the LLMProvider enum.
  static LLMProvider _mapMultiConfigProvider(String s) {
    switch (s) {
      case 'deepseek':
        return LLMProvider.deepSeek;
      case 'openai':
        return LLMProvider.openai;
      case 'claude':
        return LLMProvider.claude;
      case 'custom':
      default:
        return LLMProvider.openAICompatible;
    }
  }

  /// Phase 3: Load the active (isDefault) entry from the llm_configs table.
  Future<void> applyActiveMultiConfig() async {
    final row = await (_db.select(_db.llmConfigs)
          ..where((t) => t.isDefault.equals(true)))
        .getSingleOrNull();
    if (row == null) {
      _log('applyActiveMultiConfig: no active multi-config, skipping');
      return;
    }
    state = state.copyWith(
      provider: _mapMultiConfigProvider(row.provider),
      apiKey: row.apiKey ?? '',
      apiUrl: row.endpoint,
      model: (row.model == null || row.model!.isEmpty) ? state.model : row.model!,
    );
    await _saveConfig();
    _log('applyActiveMultiConfig: applied config');
  }
  LLMConfigNotifier(this._prefs, this._db) : super(_defaultConfig()) {
    _loadConfig();
  }

  static LLMConfig _defaultConfig() {
    return const LLMConfig(
      provider: LLMProvider.claude,
      model: 'claude-sonnet-4-5-20250929',
      apiKey: '',
      apiUrl: 'https://api.anthropic.com',
      maxTokens: 8192,
      temperature: 0.8,
      topP: 0.95,
      topK: 40,
      frequencyPenalty: 0.0,
      presencePenalty: 0.0,
      streamEnabled: true,
    );
  }

  /// Get default URL for a provider
  static String _getDefaultUrl(LLMProvider provider) {
    switch (provider) {
      case LLMProvider.openai:
        return 'https://api.openai.com/v1';
      case LLMProvider.claude:
        return 'https://api.anthropic.com';
      case LLMProvider.openRouter:
        return 'https://openrouter.ai/api/v1';
      case LLMProvider.gemini:
        return 'https://generativelanguage.googleapis.com/v1';
      case LLMProvider.ollama:
        return 'http://localhost:11434';
      case LLMProvider.koboldCpp:
        return 'http://localhost:5001';
      case LLMProvider.deepSeek:
        return 'https://api.deepseek.com/v1';
      case LLMProvider.qwen:
        return 'https://dashscope.aliyuncs.com/compatible-mode/v1';
      case LLMProvider.openAICompatible:
        return 'http://localhost:8080/v1';
    }
  }

  /// Get default model for a provider
  static String _getDefaultModel(LLMProvider provider) {
    switch (provider) {
      case LLMProvider.openai:
        return '5.2';
      case LLMProvider.claude:
        return 'claude-sonnet-4-5-20250929';
      case LLMProvider.openRouter:
        return 'anthropic/claude-3.5-sonnet';
      case LLMProvider.gemini:
        return 'gemini-1.5-pro';
      case LLMProvider.ollama:
        return 'llama3.2';
      case LLMProvider.koboldCpp:
        return '';
      case LLMProvider.deepSeek:
        return 'deepseek-chat';
      case LLMProvider.qwen:
        return 'qwen-plus';
      case LLMProvider.openAICompatible:
        return '';
    }
  }

  /// Get the storage key for a provider's configuration
  String _getProviderConfigKey(LLMProvider provider) {
    return '$_providerConfigKeyPrefix${provider.name}';
  }

  /// Save the current provider's connection settings (apiKey, apiUrl, model)
  Future<void> _saveCurrentProviderConfig() async {
    final key = _getProviderConfigKey(state.provider);
    final providerConfig = {
      'apiKey': state.apiKey,
      'apiUrl': state.apiUrl,
      'model': state.model,
    };
    final jsonStr = jsonEncode(providerConfig);
    
    // Save to DB
    await _db.into(_db.globalStates).insert(
      GlobalStatesCompanion(
        key: drift.Value(key),
        value: drift.Value(jsonStr),
        updatedAt: drift.Value(DateTime.now()),
      ),
      mode: drift.InsertMode.insertOrReplace,
    );
    
    // Keep syncing to prefs for backup safety until fully migrated (optional but good for now)
    await _prefs.setString(key, jsonStr);
    _log('Saved config for provider ${state.provider.name}: apiUrl=${state.apiUrl}, model=${state.model}');
  }

  /// Load a provider's connection settings, or return defaults if none exist
  Future<Map<String, String>> _loadProviderConfig(LLMProvider provider) async {
    final key = _getProviderConfigKey(provider);
    
    // Try DB first
    final row = await (_db.select(_db.globalStates)..where((t) => t.key.equals(key))).getSingleOrNull();
    String? jsonStr;
    
    if (row != null) {
      jsonStr = row.value;
    } else {
      // Fallback to prefs
      jsonStr = _prefs.getString(key);
    }
    
    if (jsonStr != null) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        _log('Loaded saved config for provider ${provider.name}: apiUrl=${map['apiUrl']}, model=${map['model']}');
        return {
          'apiKey': map['apiKey'] as String? ?? '',
          'apiUrl': map['apiUrl'] as String? ?? _getDefaultUrl(provider),
          'model': map['model'] as String? ?? _getDefaultModel(provider),
        };
      } catch (e) {
        _log('Failed to load config for provider ${provider.name}: $e');
      }
    }
    
    // Return defaults if no saved config
    _log('Using default config for provider ${provider.name}');
    return {
      'apiKey': '',
      'apiUrl': _getDefaultUrl(provider),
      'model': _getDefaultModel(provider),
    };
  }

  Future<void> _loadConfig() async {
    // 1. Try DB
    final row = await (_db.select(_db.globalStates)..where((t) => t.key.equals(_configKey))).getSingleOrNull();
    
    String? jsonStr;
    bool needsMigration = false;
    
    if (row != null) {
      jsonStr = row.value;
    } else {
      // 2. Fallback to prefs (Migration)
      jsonStr = _prefs.getString(_configKey);
      if (jsonStr != null) {
        needsMigration = true;
      }
    }

    if (jsonStr != null) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        state = LLMConfig.fromJson(map);
        
        if (needsMigration) {
          _log('Migrating LLM config from SharedPreferences to Database');
          _saveConfig(); // Save to DB
        }
      } catch (e) {
        // Use default config on error
      }
    }
    // 冷启动时用多LLM方案的 active 配置覆盖，保证聊天页与API服务页一致
    await applyActiveMultiConfig();
  }

  Future<void> _saveConfig() async {
    final jsonStr = jsonEncode(state.toJson());
    
    // Save to DB
    await _db.into(_db.globalStates).insert(
      GlobalStatesCompanion(
        key: drift.Value(_configKey),
        value: drift.Value(jsonStr),
        updatedAt: drift.Value(DateTime.now()),
      ),
      mode: drift.InsertMode.insertOrReplace,
    );
    
    // Sync to Prefs for redundancy/legacy
    await _prefs.setString(_configKey, jsonStr);
  }

  Future<void> updateProvider(LLMProvider provider) async {
    // Don't do anything if switching to the same provider
    if (provider == state.provider) {
      return;
    }

    // Save current provider's connection settings first
    await _saveCurrentProviderConfig();
    
    // Load the new provider's saved settings (or defaults)
    final newProviderConfig = await _loadProviderConfig(provider);

    state = state.copyWith(
      provider: provider,
      apiKey: newProviderConfig['apiKey'],
      apiUrl: newProviderConfig['apiUrl'],
      model: newProviderConfig['model'],
    );
    await _saveConfig();
    
    _log('Switched to provider ${provider.name}: apiUrl=${state.apiUrl}, model=${state.model}');
  }

  /// Force set provider and reload its config from DB.
  /// Unlike updateProvider, this does NOT skip if the provider is the same.
  /// Used when applying presets to ensure connection settings are refreshed.
  /// 
  /// IMPORTANT: Do NOT call _saveCurrentProviderConfig() here!
  /// This method is called after restoreProviderConfigs has already written
  /// the correct configs to DB. Saving current state would overwrite
  /// the just-restored preset configs with old values.
  Future<void> forceSetProvider(LLMProvider provider) async {
    // Load the target provider's saved settings (freshly restored from preset)
    final newProviderConfig = await _loadProviderConfig(provider);

    state = state.copyWith(
      provider: provider,
      apiKey: newProviderConfig['apiKey'],
      apiUrl: newProviderConfig['apiUrl'],
      model: newProviderConfig['model'],
    );
    await _saveConfig();
    
    _log('Force set provider ${provider.name}: apiUrl=${state.apiUrl}, model=${state.model}, apiKey=${state.apiKey.isNotEmpty ? "***" : "(empty)"}');
  }

  void updateApiKey(String apiKey) {
    state = state.copyWith(apiKey: apiKey);
    _saveConfig();
    _saveCurrentProviderConfig(); // Also save to per-provider config for persistence
  }

  void updateApiUrl(String apiUrl) {
    state = state.copyWith(apiUrl: apiUrl);
    _saveConfig();
    _saveCurrentProviderConfig(); // Also save to per-provider config for persistence
  }

  void updateModel(String model) {
    state = state.copyWith(model: model);
    _saveConfig();
    _saveCurrentProviderConfig(); // Also save to per-provider config for persistence
    _persistModelToActiveConfig(model); // 同步 model 到 DB 激活方案，避免冷启动被旧值覆盖
  }
  /// 只把 model 一列回写到 DB 中 isDefault=true 的方案行，
  /// 保证冷启动时 applyActiveMultiConfig 读到的是最新选择的模型。
  /// 注意：只 update model 一列，绝不触碰 apiKey/endpoint，避免误伤其他字段。
  Future<void> _persistModelToActiveConfig(String model) async {
    final active = await (_db.select(_db.llmConfigs)
          ..where((t) => t.isDefault.equals(true)))
        .getSingleOrNull();
    if (active == null) return; // 无激活方案（纯单配置模式），无需回写
    await (_db.update(_db.llmConfigs)
          ..where((t) => t.isDefault.equals(true)))
        .write(LlmConfigsCompanion(
      model: drift.Value(model.isEmpty ? null : model),
    ));
  }

  void updateMaxTokens(int maxTokens) {
    state = state.copyWith(maxTokens: maxTokens);
    _saveConfig();
  }

  void updateContextLength(int contextLength) {
    state = state.copyWith(contextLength: contextLength);
    _saveConfig();
  }

  void updateTemperature(double temperature) {
    state = state.copyWith(temperature: temperature);
    _saveConfig();
  }

  void updateTopP(double topP) {
    state = state.copyWith(topP: topP);
    _saveConfig();
  }

  void updateTopK(int topK) {
    state = state.copyWith(topK: topK);
    _saveConfig();
  }

  void updateFrequencyPenalty(double penalty) {
    state = state.copyWith(frequencyPenalty: penalty);
    _saveConfig();
  }

  void updatePresencePenalty(double penalty) {
    state = state.copyWith(presencePenalty: penalty);
    _saveConfig();
  }

  void updateStreamEnabled(bool enabled) {
    state = state.copyWith(streamEnabled: enabled);
    _saveConfig();
  }

  // Advanced sampler methods
  void updateTypicalP(double value) {
    state = state.copyWith(typicalP: value);
    _saveConfig();
  }

  void updateMinP(double value) {
    state = state.copyWith(minP: value);
    _saveConfig();
  }

  void updateRepetitionPenalty(double value) {
    state = state.copyWith(repetitionPenalty: value);
    _saveConfig();
  }

  void updateRepetitionPenaltyRange(int value) {
    state = state.copyWith(repetitionPenaltyRange: value);
    _saveConfig();
  }

  void updateTailFreeSampling(double value) {
    state = state.copyWith(tailFreeSampling: value);
    _saveConfig();
  }

  void updateTopA(double value) {
    state = state.copyWith(topA: value);
    _saveConfig();
  }

  void updateMirostatMode(int mode) {
    state = state.copyWith(mirostatMode: mode);
    _saveConfig();
  }

  void updateMirostatTau(double value) {
    state = state.copyWith(mirostatTau: value);
    _saveConfig();
  }

  void updateMirostatEta(double value) {
    state = state.copyWith(mirostatEta: value);
    _saveConfig();
  }

  void updateStopSequences(List<String> sequences) {
    state = state.copyWith(stopSequences: sequences);
    _saveConfig();
  }

  void updateSeed(int seed) {
    state = state.copyWith(seed: seed);
    _saveConfig();
  }

  void updateAutoSummarizeEnabled(bool enabled) {
    state = state.copyWith(autoSummarizeEnabled: enabled);
    _saveConfig();
  }

  void updateAutoSummarizeThreshold(double threshold) {
    state = state.copyWith(autoSummarizeThreshold: threshold);
    _saveConfig();
  }

  void updateSummaryModel(String model) {
    state = state.copyWith(summaryModel: model);
    _saveConfig();
  }

  void updateSummaryPrompt(String prompt) {
    state = state.copyWith(summaryPrompt: prompt);
    _saveConfig();
  }

  void resetToDefaults() {
    state = _defaultConfig();
    _saveConfig();
  }

  /// Get configuration for all providers
  Future<Map<String, Map<String, dynamic>>> getAllProviderConfigs() async {
    // Ensure current config is saved first
    await _saveCurrentProviderConfig();
    
    final result = <String, Map<String, dynamic>>{};
    for (final provider in LLMProvider.values) {
      // _loadProviderConfig returns {apiKey, apiUrl, model}
      final config = await _loadProviderConfig(provider);
      // Ensure we store concrete values, not nulls
      result[provider.name] = {
        'apiKey': config['apiKey'],
        'apiUrl': config['apiUrl'],
        'model': config['model'],
      };
    }
    return result;
  }

  /// Restore configuration for all providers (writes to DB/prefs only).
  /// The caller is responsible for refreshing the active provider state
  /// (e.g., via forceSetProvider).
  Future<void> restoreProviderConfigs(Map<String, Map<String, dynamic>> configs) async {
    for (final entry in configs.entries) {
      try {
        final providerName = entry.key;
        final config = entry.value;
        
        // Find the provider enum
        final provider = LLMProvider.values.firstWhere(
          (p) => p.name == providerName,
          orElse: () => LLMProvider.openai // Fallback
        );
        
        if (provider.name != providerName) continue; // Skip if name didn't match exactly
        
        final key = _getProviderConfigKey(provider);
        final jsonStr = jsonEncode(config);
        
        // Save to DB
        await _db.into(_db.globalStates).insert(
          GlobalStatesCompanion(
            key: drift.Value(key),
            value: drift.Value(jsonStr),
            updatedAt: drift.Value(DateTime.now()),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );
        
        // Sync to Prefs
        await _prefs.setString(key, jsonStr);
        _log('Restored config for provider ${provider.name}');
      } catch (e) {
        _log('Failed to restore config for ${entry.key}: $e');
      }
    }
  }
}

final llmConfigProvider = StateNotifierProvider<LLMConfigNotifier, LLMConfig>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final db = ref.watch(databaseProvider);
  return LLMConfigNotifier(prefs, db);
});

/// App settings state
class AppSettings {
  final String theme;
  final String language;
  final bool enableNotifications;
  final bool enableHaptics;
  final String defaultCharacterSortOrder;
  final bool confirmBeforeDelete;
  final bool autoSaveChats;
  final bool enableDebugLog;
  final bool useCharacterAvatarAsBackground;
  final bool enableBackgroundBlur;
  final double backgroundOpacity;
  final String chatLayoutMode;

  const AppSettings({
    this.theme = 'dark',
    this.language = 'en',
    this.enableNotifications = true,
    this.enableHaptics = true,
    this.defaultCharacterSortOrder = 'name',
    this.confirmBeforeDelete = true,
    this.autoSaveChats = true,
    this.enableDebugLog = false,
    this.useCharacterAvatarAsBackground = true,
    this.enableBackgroundBlur = false,
    this.backgroundOpacity = 1.0,
    this.chatLayoutMode = 'bubble',
  });

  AppSettings copyWith({
    String? theme,
    String? language,
    bool? enableNotifications,
    bool? enableHaptics,
    String? defaultCharacterSortOrder,
    bool? confirmBeforeDelete,
    bool? autoSaveChats,
    bool? enableDebugLog,
    bool? useCharacterAvatarAsBackground,
    bool? enableBackgroundBlur,
    double? backgroundOpacity,
    String? chatLayoutMode,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      language: language ?? this.language,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      enableHaptics: enableHaptics ?? this.enableHaptics,
      defaultCharacterSortOrder:
          defaultCharacterSortOrder ?? this.defaultCharacterSortOrder,
      confirmBeforeDelete: confirmBeforeDelete ?? this.confirmBeforeDelete,
      autoSaveChats: autoSaveChats ?? this.autoSaveChats,
      enableDebugLog: enableDebugLog ?? this.enableDebugLog,
      useCharacterAvatarAsBackground: useCharacterAvatarAsBackground ?? this.useCharacterAvatarAsBackground,
      enableBackgroundBlur: enableBackgroundBlur ?? this.enableBackgroundBlur,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      chatLayoutMode: chatLayoutMode ?? this.chatLayoutMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'theme': theme,
        'language': language,
        'enableNotifications': enableNotifications,
        'enableHaptics': enableHaptics,
        'defaultCharacterSortOrder': defaultCharacterSortOrder,
        'confirmBeforeDelete': confirmBeforeDelete,
        'autoSaveChats': autoSaveChats,
        'enableDebugLog': enableDebugLog,
        'useCharacterAvatarAsBackground': useCharacterAvatarAsBackground,
        'enableBackgroundBlur': enableBackgroundBlur,
        'backgroundOpacity': backgroundOpacity,
        'chatLayoutMode': chatLayoutMode,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      theme: json['theme'] as String? ?? 'dark',
      language: json['language'] as String? ?? 'en',
      enableNotifications: json['enableNotifications'] as bool? ?? true,
      enableHaptics: json['enableHaptics'] as bool? ?? true,
      defaultCharacterSortOrder:
          json['defaultCharacterSortOrder'] as String? ?? 'name',
      confirmBeforeDelete: json['confirmBeforeDelete'] as bool? ?? true,
      autoSaveChats: json['autoSaveChats'] as bool? ?? true,
      enableDebugLog: json['enableDebugLog'] as bool? ?? false,
      useCharacterAvatarAsBackground: json['useCharacterAvatarAsBackground'] as bool? ?? true,
      enableBackgroundBlur: json['enableBackgroundBlur'] as bool? ?? false,
      backgroundOpacity: (json['backgroundOpacity'] as num?)?.toDouble() ?? 1.0,
      chatLayoutMode: json['chatLayoutMode'] as String? ?? 'bubble',
    );
  }
}

/// App settings notifier
class AppSettingsNotifier extends StateNotifier<AppSettings> {
  final SharedPreferences _prefs;
  final AppDatabase _db;
  static const _settingsKey = 'app_settings';

  AppSettingsNotifier(this._prefs, this._db) : super(const AppSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // 1. Try DB
    final row = await (_db.select(_db.globalStates)..where((t) => t.key.equals(_settingsKey))).getSingleOrNull();
    
    String? jsonStr;
    bool needsMigration = false;
    
    if (row != null) {
      jsonStr = row.value;
    } else {
      // 2. Fallback to prefs
      jsonStr = _prefs.getString(_settingsKey);
      if (jsonStr != null) {
        needsMigration = true;
      }
    }
    
    if (jsonStr != null) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        state = AppSettings.fromJson(map);
        
        if (needsMigration) {
          _log('Migrating App Settings from SharedPreferences to Database');
          _saveSettings();
        }
      } catch (e) {
        // Use default settings on error
      }
    }
  }

  Future<void> _saveSettings() async {
    final jsonStr = jsonEncode(state.toJson());
    
    // Save to DB
    await _db.into(_db.globalStates).insert(
      GlobalStatesCompanion(
        key: drift.Value(_settingsKey),
        value: drift.Value(jsonStr),
        updatedAt: drift.Value(DateTime.now()),
      ),
      mode: drift.InsertMode.insertOrReplace,
    );
    
    // Sync to Prefs
    await _prefs.setString(_settingsKey, jsonStr);
  }

  void updateTheme(String theme) {
    state = state.copyWith(theme: theme);
    _saveSettings();
  }

  void updateLanguage(String language) {
    state = state.copyWith(language: language);
    _saveSettings();
  }

  void updateNotifications(bool enabled) {
    state = state.copyWith(enableNotifications: enabled);
    _saveSettings();
  }

  void updateHaptics(bool enabled) {
    state = state.copyWith(enableHaptics: enabled);
    _saveSettings();
  }

  void updateCharacterSortOrder(String order) {
    state = state.copyWith(defaultCharacterSortOrder: order);
    _saveSettings();
  }

  void updateConfirmBeforeDelete(bool confirm) {
    state = state.copyWith(confirmBeforeDelete: confirm);
    _saveSettings();
  }

  void updateAutoSaveChats(bool autoSave) {
    state = state.copyWith(autoSaveChats: autoSave);
    _saveSettings();
  }

  void updateDebugLog(bool enabled) {
    state = state.copyWith(enableDebugLog: enabled);
    _saveSettings();
  }

  void updateUseCharacterAvatarAsBackground(bool enabled) {
    state = state.copyWith(useCharacterAvatarAsBackground: enabled);
    _saveSettings();
  }

  void updateEnableBackgroundBlur(bool enabled) {
    state = state.copyWith(enableBackgroundBlur: enabled);
    _saveSettings();
  }

  void updateBackgroundOpacity(double opacity) {
    state = state.copyWith(backgroundOpacity: opacity.clamp(0.1, 1.0));
    _saveSettings();
  }

  void updateChatLayoutMode(String mode) {
    state = state.copyWith(chatLayoutMode: mode);
    _saveSettings();
  }

  void resetToDefaults() {
    state = const AppSettings();
    _saveSettings();
  }
}

/// Provider for app settings
final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final db = ref.watch(databaseProvider);
  return AppSettingsNotifier(prefs, db);
});

/// API connection test state
enum ConnectionStatus { idle, testing, success, error }

class ConnectionTestState {
  final ConnectionStatus status;
  final String? message;
  final List<String>? availableModels;

  const ConnectionTestState({
    this.status = ConnectionStatus.idle,
    this.message,
    this.availableModels,
  });

  ConnectionTestState copyWith({
    ConnectionStatus? status,
    String? message,
    List<String>? availableModels,
  }) {
    return ConnectionTestState(
      status: status ?? this.status,
      message: message,
      availableModels: availableModels ?? this.availableModels,
    );
  }
}

/// Connection test notifier
class ConnectionTestNotifier extends StateNotifier<ConnectionTestState> {
  final LLMService _llmService;

  ConnectionTestNotifier(this._llmService) : super(const ConnectionTestState());

  Future<void> testConnection(LLMConfig config) async {
    _log('Starting connection test for ${config.provider.name}');
    _log('API URL: ${config.apiUrl}');
    _log('API Key: ${config.apiKey.isEmpty ? "(empty)" : "${config.apiKey.substring(0, 8)}..."}');
    _log('Model: ${config.model}');
    
    state = const ConnectionTestState(status: ConnectionStatus.testing);

    try {
      // testConnection now returns a success message or throws an exception
      _log('Calling LLMService.testConnection...');
      final successMessage = await _llmService.testConnection(config);
      _log('Connection test successful: $successMessage');
      
      // Try to get available models
      List<String>? models;
      try {
        _log('Fetching available models...');
        models = await _llmService.getAvailableModels(config);
        _log('Fetched ${models.length} models');
      } catch (e, stackTrace) {
        // Models fetching is optional, don't fail the test
        _log('Failed to fetch models: $e', error: e.toString(), stackTrace: stackTrace);
      }

      state = ConnectionTestState(
        status: ConnectionStatus.success,
        message: successMessage,
        availableModels: models,
      );
      _log('Connection test completed successfully');
    } catch (e, stackTrace) {
      // Extract the error message from the exception
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring(11);
      }
      
      _log('Connection test failed: $errorMessage', error: e.toString(), stackTrace: stackTrace);
      
      state = ConnectionTestState(
        status: ConnectionStatus.error,
        message: errorMessage,
      );
    }
  }

  void reset() {
    _log('Resetting connection test state');
    state = const ConnectionTestState();
  }
}

/// Provider for connection testing
final connectionTestProvider =
    StateNotifierProvider<ConnectionTestNotifier, ConnectionTestState>((ref) {
  final llmService = ref.watch(llmServiceProvider);
  return ConnectionTestNotifier(llmService);
});

/// Model fetching state
enum ModelFetchStatus { idle, loading, success, error }

class ModelFetchState {
  final ModelFetchStatus status;
  final List<String> models;
  final String? errorMessage;

  const ModelFetchState({
    this.status = ModelFetchStatus.idle,
    this.models = const [],
    this.errorMessage,
  });

  ModelFetchState copyWith({
    ModelFetchStatus? status,
    List<String>? models,
    String? errorMessage,
  }) {
    return ModelFetchState(
      status: status ?? this.status,
      models: models ?? this.models,
      errorMessage: errorMessage,
    );
  }
}

/// Model fetch notifier
class ModelFetchNotifier extends StateNotifier<ModelFetchState> {
  final LLMService _llmService;

  ModelFetchNotifier(this._llmService) : super(const ModelFetchState());

  Future<void> fetchModels(LLMConfig config) async {
    _log('Starting model fetch for ${config.provider.name}');
    _log('API URL: ${config.apiUrl}');
    
    state = const ModelFetchState(status: ModelFetchStatus.loading);

    try {
      _log('Calling LLMService.getAvailableModels...');
      final models = await _llmService.getAvailableModels(config);
      _log('Received ${models.length} models');
      
      if (models.isNotEmpty) {
        _log('Models: ${models.take(10).join(", ")}${models.length > 10 ? "..." : ""}');
        state = ModelFetchState(
          status: ModelFetchStatus.success,
          models: models,
        );
        _log('Model fetch completed successfully');
      } else {
        // Provide helpful message based on provider
        String message;
        switch (config.provider) {
          
          case LLMProvider.openRouter:
          case LLMProvider.gemini:
          case LLMProvider.deepSeek:
          case LLMProvider.qwen:
          case LLMProvider.openAICompatible:
          case LLMProvider.openai:
            message = 'No models found. Check your API key.';
            break;
          case LLMProvider.ollama:
            message = 'No models found. Run "ollama pull <model>" to download models.';
            break;
          case LLMProvider.koboldCpp:
            message = 'No model loaded. Load a model in KoboldCpp first.';
            break;
          case LLMProvider.claude:
            message = 'Claude models are pre-defined. Select from the list.';
            break;
        }
        _log('No models found: $message');
        state = ModelFetchState(
          status: ModelFetchStatus.error,
          errorMessage: message,
        );
      }
    } catch (e, stackTrace) {
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring(11);
      }
      _log('Model fetch failed: $errorMessage', error: e.toString(), stackTrace: stackTrace);
      state = ModelFetchState(
        status: ModelFetchStatus.error,
        errorMessage: errorMessage,
      );
    }
  }

  void reset() {
    _log('Resetting model fetch state');
    state = const ModelFetchState();
  }
}

/// Provider for model fetching
final modelFetchProvider =
    StateNotifierProvider<ModelFetchNotifier, ModelFetchState>((ref) {
  final llmService = ref.watch(llmServiceProvider);
  return ModelFetchNotifier(llmService);
});

/// Provider for tokenizer service
final tokenizerServiceProvider = Provider<TokenizerService>((ref) {
  return TokenizerService();
});

/// Provider for chat summarization service
final chatSummarizationServiceProvider = Provider<ChatSummarizationService>((ref) {
  final llmService = ref.watch(llmServiceProvider);
  final tokenizerService = ref.watch(tokenizerServiceProvider);
  return ChatSummarizationService(llmService, tokenizerService);
});
enum MetricsStatus { idle, measuring, success, error }

class ConnectionMetricsState {
  final MetricsStatus status;
  final int? ttftMs;
  final double? charsPerSec;
  final String? error;
  // 稳定性深度检测（独立状态）
  final MetricsStatus stabilityStatus;
  final String? stabilityRating;
  const ConnectionMetricsState({
    this.status = MetricsStatus.idle,
    this.ttftMs,
    this.charsPerSec,
    this.error,
    this.stabilityStatus = MetricsStatus.idle,
    this.stabilityRating,
  });

  ConnectionMetricsState copyWith({
    MetricsStatus? status,
    int? ttftMs,
    double? charsPerSec,
    String? error,
    MetricsStatus? stabilityStatus,
    String? stabilityRating,
  }) {
    return ConnectionMetricsState(
      status: status ?? this.status,
      ttftMs: ttftMs ?? this.ttftMs,
      charsPerSec: charsPerSec ?? this.charsPerSec,
      error: error ?? this.error,
      stabilityStatus: stabilityStatus ?? this.stabilityStatus,
      stabilityRating: stabilityRating ?? this.stabilityRating,
    );
  }
}

class ConnectionMetricsNotifier
    extends StateNotifier<ConnectionMetricsState> {
  final LLMService _llmService;
  ConnectionMetricsNotifier(this._llmService)
      : super(const ConnectionMetricsState());

  Future<void> measure(LLMConfig config) async {
    state = state.copyWith(status: MetricsStatus.measuring, error: null);
    try {
      final result = await _llmService.measureConnection(config);
      state = state.copyWith(
        status: MetricsStatus.success,
        ttftMs: result.ttftMs,
        charsPerSec: result.charsPerSec,
      );
    } catch (e) {
      state = state.copyWith(
        status: MetricsStatus.error,
        error: e.toString(),
      );
    }
  }

  /// 稳定性深度检测：连测3次，看首Token延迟的波动
  Future<void> measureStability(LLMConfig config) async {
    state = state.copyWith(stabilityStatus: MetricsStatus.measuring);
    try {
      final samples = <int>[];
      for (var i = 0; i < 3; i++) {
        final result = await _llmService.measureConnection(config);
        samples.add(result.ttftMs);
      }
      final mean = samples.reduce((a, b) => a + b) / samples.length;
      final variance = samples
              .map((x) => (x - mean) * (x - mean))
              .reduce((a, b) => a + b) /
          samples.length;
      final stdDev = variance <= 0 ? 0.0 : math.sqrt(variance);
      final cv = mean > 0 ? stdDev / mean : 0.0; // 变异系数
      final String rating;
      if (cv < 0.15) {
        rating = '稳定';
      } else if (cv < 0.35) {
        rating = '一般';
      } else {
        rating = '波动大';
      }
      state = state.copyWith(
        stabilityStatus: MetricsStatus.success,
        stabilityRating: rating,
      );
    } catch (e) {
      state = state.copyWith(
        stabilityStatus: MetricsStatus.error,
        stabilityRating: '检测失败',
      );
    }
  }
}

final connectionMetricsProvider = StateNotifierProvider<
    ConnectionMetricsNotifier, ConnectionMetricsState>((ref) {
  final llmService = ref.watch(llmServiceProvider);
  return ConnectionMetricsNotifier(llmService);
});
