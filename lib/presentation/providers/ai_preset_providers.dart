import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/ai_preset.dart';
import '../../data/models/prompt_manager.dart';
import 'settings_providers.dart';
import 'prompt_manager_providers.dart';
import 'instruct_providers.dart';
import '../../domain/services/llm_service.dart';
import 'regex_providers.dart';

const _customPresetsKey = 'ai_custom_presets';
const _activePresetIdKey = 'ai_active_preset_id';

/// Provider for custom AI presets
final aiCustomPresetsProvider =
    StateNotifierProvider<AICustomPresetsNotifier, List<AIPreset>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AICustomPresetsNotifier(prefs);
});

class AICustomPresetsNotifier extends StateNotifier<List<AIPreset>> {
  final SharedPreferences _prefs;

  AICustomPresetsNotifier(this._prefs) : super([]) {
    _load();
  }

  void _load() {
    final json = _prefs.getString(_customPresetsKey);
    if (json != null) {
      try {
        final list = jsonDecode(json) as List<dynamic>;
        state = list
            .map((e) => AIPreset.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        state = [];
      }
    }
  }

  Future<void> _save() async {
    await _prefs.setString(
      _customPresetsKey,
      jsonEncode(state.map((p) => p.toJson()).toList()),
    );
  }

  /// Add a new custom preset
  Future<void> addPreset(AIPreset preset) async {
    state = [...state, preset];
    await _save();
  }

  /// Update an existing preset
  Future<void> updatePreset(AIPreset preset) async {
    state = state.map((p) => p.id == preset.id ? preset : p).toList();
    await _save();
  }

  /// Delete a preset
  Future<void> deletePreset(String id) async {
    // Find the preset before deleting to get bound IDs
    final preset = state.where((p) => p.id == id).firstOrNull;
    state = state.where((p) => p.id != id).toList();
    await _save();

    // Clean up bound prompt preset
    if (preset?.boundPromptPresetId != null) {
      await _prefs.remove('prompt_manager_active_preset_id');
    }

    // Clean up bound regex scripts — handled by regex_providers separately
    // Just clear active state if this preset was active
    final activeId = _prefs.getString('ai_active_preset_id');
    if (activeId == id) {
      await _prefs.remove('ai_active_preset_id');
    }
  }

  /// Import a preset from JSON (supports both SillyTavern and KiraKira formats)
  Future<AIPreset> importPreset(Map<String, dynamic> json) async {
    final id = const Uuid().v4();
    final preset = AIPreset.fromExportJson(json, id);
    await addPreset(preset);
    return preset;
  }
}

/// Provider for all AI presets (built-in + custom)
/// Custom presets with the same ID as a built-in one will override it.
final allAIPresetsProvider = Provider<List<AIPreset>>((ref) {
  final customPresets = ref.watch(aiCustomPresetsProvider);
  final customIds = customPresets.map((p) => p.id).toSet();
  // Built-in presets that haven't been overridden by custom versions
  final nonOverriddenBuiltIn = BuiltInAIPresets.all.where((p) => !customIds.contains(p.id));
  return [...nonOverriddenBuiltIn, ...customPresets];
});

/// Active AI preset ID provider
final activeAIPresetIdProvider =
    StateNotifierProvider<ActiveAIPresetIdNotifier, String?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ActiveAIPresetIdNotifier(prefs);
});

class ActiveAIPresetIdNotifier extends StateNotifier<String?> {
  final SharedPreferences _prefs;

  ActiveAIPresetIdNotifier(this._prefs) : super(null) {
    state = _prefs.getString(_activePresetIdKey);
  }

  Future<void> setActivePreset(String? id) async {
    state = id;
    if (id != null) {
      await _prefs.setString(_activePresetIdKey, id);
    } else {
      await _prefs.remove(_activePresetIdKey);
    }
  }
}

/// Provider for the currently active AI preset
final activeAIPresetProvider = Provider<AIPreset?>((ref) {
  final activeId = ref.watch(activeAIPresetIdProvider);
  if (activeId == null) return null;

  final allPresets = ref.watch(allAIPresetsProvider);
  try {
    return allPresets.firstWhere((p) => p.id == activeId);
  } catch (_) {
    return null;
  }
});

/// AI Preset Manager - handles applying presets and creating from current settings
class AIPresetManager {
  final Ref _ref;

  AIPresetManager(this._ref);

  /// Save current settings back to the currently active preset.
  /// This ensures user changes (e.g., API URL modifications) are preserved
  /// when switching between presets.
  Future<void> _saveCurrentToActivePreset() async {
    final activeId = _ref.read(activeAIPresetIdProvider);
    if (activeId == null) return;

    // Find the active preset (could be custom or built-in)
    final allPresets = _ref.read(allAIPresetsProvider);
    final activePreset = allPresets.where((p) => p.id == activeId).firstOrNull;
    if (activePreset == null) return;

    // Capture current settings
    final llmConfig = _ref.read(llmConfigProvider);
    final llmNotifier = _ref.read(llmConfigProvider.notifier);
    final promptConfig = _ref.read(promptManagerProvider);
    final instructTemplateId = _ref.read(activeInstructTemplateIdProvider);
    final allProviderConfigs = await llmNotifier.getAllProviderConfigs();

    final updatedPreset = activePreset.copyWith(
      isBuiltIn: false,
      updatedAt: DateTime.now(),generationSettings: GenerationPreset(
        temperature: llmConfig.temperature,
        topP: llmConfig.topP,
        topK: llmConfig.topK,
        minP: llmConfig.minP,
        typicalP: llmConfig.typicalP,
        repetitionPenalty: llmConfig.repetitionPenalty,
        repetitionPenaltyRange: llmConfig.repetitionPenaltyRange,
        frequencyPenalty: llmConfig.frequencyPenalty,
        presencePenalty: llmConfig.presencePenalty,
        tailFreeSampling: llmConfig.tailFreeSampling,
        topA: llmConfig.topA,
        mirostatMode: llmConfig.mirostatMode,
        mirostatTau: llmConfig.mirostatTau,
        mirostatEta: llmConfig.mirostatEta,
        maxTokens: llmConfig.maxTokens,
        stopSequences: llmConfig.stopSequences,
        seed: llmConfig.seed,
        streamEnabled: llmConfig.streamEnabled,),
      promptManagerConfig: promptConfig,
      instructTemplateId: instructTemplateId,
      provider: llmConfig.provider.name,
      providerSettings: allProviderConfigs,
    );

    // Check if already exists in custom presets
    final customPresets = _ref.read(aiCustomPresetsProvider);
    final existsInCustom = customPresets.any((p) => p.id == activeId);
    
    if (existsInCustom) {
      await _ref.read(aiCustomPresetsProvider.notifier).updatePreset(updatedPreset);
    } else {
      // First time saving a built-in preset — add to custom presets
      await _ref.read(aiCustomPresetsProvider.notifier).addPreset(updatedPreset);
    }
  }

  /// Apply an AI preset to current settings
  Future<void> applyPreset(AIPreset preset) async {
    // Auto-save current settings to the currently active custom preset
    // so that user changes are not lost when switching presets
    await _saveCurrentToActivePreset();

    // Apply generation settings to LLM config
    final llmNotifier = _ref.read(llmConfigProvider.notifier);
    final gen = preset.generationSettings;

    llmNotifier.updateTemperature(gen.temperature);
    llmNotifier.updateTopP(gen.topP);
    llmNotifier.updateTopK(gen.topK);
    llmNotifier.updateMinP(gen.minP);
    llmNotifier.updateTypicalP(gen.typicalP);
    llmNotifier.updateRepetitionPenalty(gen.repetitionPenalty);
    llmNotifier.updateRepetitionPenaltyRange(gen.repetitionPenaltyRange);
    llmNotifier.updateFrequencyPenalty(gen.frequencyPenalty);
    llmNotifier.updatePresencePenalty(gen.presencePenalty);
    llmNotifier.updateTailFreeSampling(gen.tailFreeSampling);
    llmNotifier.updateTopA(gen.topA);
    llmNotifier.updateMirostatMode(gen.mirostatMode);
    llmNotifier.updateMirostatTau(gen.mirostatTau);
    llmNotifier.updateMirostatEta(gen.mirostatEta);
    llmNotifier.updateMaxTokens(gen.maxTokens);
    llmNotifier.updateStopSequences(gen.stopSequences);
    llmNotifier.updateSeed(gen.seed);
    llmNotifier.updateStreamEnabled(gen.streamEnabled);

    // Restore ALL provider configurations
    if (preset.providerSettings != null && preset.providerSettings!.isNotEmpty) {
      await llmNotifier.restoreProviderConfigs(preset.providerSettings!);
    }

    // Switch provider and force-refresh connection settings
    if (preset.provider != null) {
      try {
        final targetProvider = LLMProvider.values.firstWhere(
          (p) => p.name == preset.provider,
          orElse: () => LLMProvider.openai,
        );
        // Force switch: first change to a different provider then back,
        // or use forceRefreshProvider which we added
        await llmNotifier.forceSetProvider(targetProvider);
      } catch (_) {
        // Ignore invalid provider strings
      }
    }

    // Apply prompt manager config
    // Priority: boundPromptPresetId > inline promptManagerConfig > default
    final promptNotifier = _ref.read(promptManagerProvider.notifier);
    if (preset.boundPromptPresetId != null) {
      // Switch to the bound prompt preset
      await _ref.read(activePresetIdProvider.notifier)
          .setActivePreset(preset.boundPromptPresetId);
      final allPromptPresets = _ref.read(allPresetsProvider);
      final boundPromptPreset = allPromptPresets
          .where((p) => p.id == preset.boundPromptPresetId)
          .firstOrNull;
      if (boundPromptPreset != null) {
        await promptNotifier.applyPreset(boundPromptPreset);
      }
    } else if (preset.promptManagerConfig != null) {
      await promptNotifier.applyPreset(PromptManagerPreset(
        id: preset.id,
        name: preset.name,
        config: preset.promptManagerConfig!,
        createdAt: preset.createdAt,
        updatedAt: preset.updatedAt,
      ));
    } else {
      await promptNotifier.resetToDefault();
    }

    // Apply bound regex scripts —— 无论是否为空都调用：
    // 空列表会禁用所有全局正则，从而清除上一个预设残留的正则。
    {
      final regexNotifier = _ref.read(globalRegexScriptsProvider.notifier);
      await regexNotifier.setActiveScripts(preset.boundRegexScriptIds);
    }

    // Apply instruct template if present
    if (preset.instructTemplateId != null) {
      _ref.read(activeInstructTemplateIdProvider.notifier).state =
          preset.instructTemplateId!;
    }

    // Set as active preset
    await _ref.read(activeAIPresetIdProvider.notifier).setActivePreset(preset.id);
  }

  /// Create a preset from current settings
  Future<AIPreset> createFromCurrentSettings({
    required String name,
    String? description,
  }) async {
    final llmConfig = _ref.read(llmConfigProvider);
    final llmNotifier = _ref.read(llmConfigProvider.notifier);
    final promptConfig = _ref.read(promptManagerProvider);
    final instructTemplateId = _ref.read(activeInstructTemplateIdProvider);

    // Capture configurations for ALL providers
    final allProviderConfigs = await llmNotifier.getAllProviderConfigs();

    return AIPreset(
      id: const Uuid().v4(),
      name: name,
      description: description,
      isBuiltIn: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      generationSettings: GenerationPreset(
        temperature: llmConfig.temperature,
        topP: llmConfig.topP,
        topK: llmConfig.topK,
        minP: llmConfig.minP,
        typicalP: llmConfig.typicalP,
        repetitionPenalty: llmConfig.repetitionPenalty,
        repetitionPenaltyRange: llmConfig.repetitionPenaltyRange,
        frequencyPenalty: llmConfig.frequencyPenalty,
        presencePenalty: llmConfig.presencePenalty,
        tailFreeSampling: llmConfig.tailFreeSampling,
        topA: llmConfig.topA,
        mirostatMode: llmConfig.mirostatMode,
        mirostatTau: llmConfig.mirostatTau,
        mirostatEta: llmConfig.mirostatEta,
        maxTokens: llmConfig.maxTokens,
        stopSequences: llmConfig.stopSequences,
        seed: llmConfig.seed,
        streamEnabled: llmConfig.streamEnabled,
      ),
      promptManagerConfig: promptConfig,
      instructTemplateId: instructTemplateId,
      provider: llmConfig.provider.name,
      providerSettings: allProviderConfigs,
    );
  }

  /// Export current settings as JSON
  Future<Map<String, dynamic>> exportCurrentSettings(String name) async {
    final preset = await createFromCurrentSettings(name: name);
    return preset.toExportJson();
  }
}

/// Provider for AI Preset Manager
final aiPresetManagerProvider = Provider<AIPresetManager>((ref) {
  return AIPresetManager(ref);
});