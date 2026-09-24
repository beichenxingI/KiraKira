import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kirakira/domain/services/image_generation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for image generation service
final imageGenServiceProvider = Provider<ImageGenerationService>((ref) {
  final service = ImageGenerationService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for image generation settings
final imageGenSettingsProvider = StateNotifierProvider<ImageGenSettingsNotifier, ImageGenSettings>((ref) {
  return ImageGenSettingsNotifier(ref.watch(imageGenServiceProvider));
});

/// Notifier for image generation settings
class ImageGenSettingsNotifier extends StateNotifier<ImageGenSettings> {
  static const _prefsKey = 'image_gen_settings';
  // [密钥安全] API 密钥只存 secure storage，SharedPreferences 不落明文
  static const _secureStorage = FlutterSecureStorage();
  static const _secureApiKeysKey = 'image_gen_apikeys';
  static const _securePromptOptApiKey = 'image_gen_promptopt_apikey';
  final ImageGenerationService _service;

  // 上次写入 secure storage 的密钥（滑杆等高频保存时密钥未变化则跳过 Keystore 写入）
  Map<String, String> _lastSavedApiKeys = const {};
  String? _lastSavedPromptOptKey;

  ImageGenSettingsNotifier(this._service) : super(const ImageGenSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKey);
      if (jsonStr == null) return;
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      // [密钥安全] 密钥从 secure storage 读；prefs 里的旧明文一次性迁移后清除
      Map<String, String> secureKeys = {};
      try {
        final raw = await _secureStorage.read(key: _secureApiKeysKey);
        if (raw != null && raw.isNotEmpty) {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          secureKeys = decoded.map((k, v) => MapEntry(k, v?.toString() ?? ''));
        }
      } catch (_) {}
      final legacyKeys = (json['apiKeys'] is Map)
          ? Map<String, String>.from(json['apiKeys'] as Map)
          : (json['apiKey'] != null
              ? <String, String>{
                  (json['provider'] as String? ?? 'openai'): json['apiKey'].toString()
                }
              : <String, String>{});
      legacyKeys.removeWhere((_, v) => v.isEmpty);
      final migrated = Map<String, String>.from(secureKeys);
      var didMigrate = false;
      for (final entry in legacyKeys.entries) {
        if ((migrated[entry.key] ?? '').isEmpty) {
          migrated[entry.key] = entry.value;
          didMigrate = true;
        }
      }
      if (didMigrate) {
        await _secureStorage.write(key: _secureApiKeysKey, value: jsonEncode(migrated));
        _lastSavedApiKeys = migrated;
      }
      json['apiKeys'] = migrated;

      // promptOptApiKey 同样迁移
      String? secureOpt;
      try {
        secureOpt = await _secureStorage.read(key: _securePromptOptApiKey);
      } catch (_) {}
      final legacyOpt = json['promptOptApiKey'] as String?;
      if ((secureOpt == null || secureOpt.isEmpty) &&
          legacyOpt != null &&
          legacyOpt.isNotEmpty) {
        await _secureStorage.write(key: _securePromptOptApiKey, value: legacyOpt);
        json['promptOptApiKey'] = legacyOpt;
        _lastSavedPromptOptKey = legacyOpt;
        didMigrate = true;
      } else if (secureOpt != null && secureOpt.isNotEmpty) {
        json['promptOptApiKey'] = secureOpt;
      }

      state = ImageGenSettings.fromJson(json);
      _service.updateSettings(state);

      // 迁移完成后立即清除 prefs 明文
      if (didMigrate) {
        final stripped = Map<String, dynamic>.from(json);
        stripped['apiKeys'] = <String, String>{};
        stripped['apiKey'] = null;
        stripped['promptOptApiKey'] = null;
        await prefs.setString(_prefsKey, jsonEncode(stripped));
      }
    } catch (e) {
      // Use default settings on error
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = state.toJson();
      // [密钥安全] 密钥只写 secure storage，prefs 不落明文
      final keysToStore = Map<String, String>.from(state.apiKeys)
        ..removeWhere((_, v) => v.isEmpty);
      if (!mapEquals(_lastSavedApiKeys, keysToStore)) {
        await _secureStorage.write(key: _secureApiKeysKey, value: jsonEncode(keysToStore));
        _lastSavedApiKeys = keysToStore;
      }
      json['apiKeys'] = <String, String>{};
      final optKey = state.promptOptApiKey;
      if ((optKey ?? '').isNotEmpty && optKey != _lastSavedPromptOptKey) {
        await _secureStorage.write(key: _securePromptOptApiKey, value: optKey!);
        _lastSavedPromptOptKey = optKey;
      }
      json['promptOptApiKey'] = null;
      final jsonStr = jsonEncode(json);
      await prefs.setString(_prefsKey, jsonStr);
      _service.updateSettings(state);
    } catch (e) {
      // Ignore save errors
    }
  }

  void setEnabled(bool enabled) {
    state = state.copyWith(enabled: enabled);
    _saveSettings();
  }

  void setProvider(ImageGenProvider provider) {
    // Also update the default model and clear custom endpoint when provider changes
    // When switching providers, don't reset the apiEndpoint - each provider has its own
    state = state.copyWith(provider: provider);
    _saveSettings();
  }

  void setApiKey(String? apiKey) {
    // Use helper method to update the current provider's API key
    state = state.withApiKey(apiKey);
    _saveSettings();
  }

  void setApiEndpoint(String? endpoint) {
    // Use helper method to update the current provider's endpoint
    state = state.withApiEndpoint(endpoint?.isEmpty == true ? null : endpoint);
    _saveSettings();
  }

  void setModel(String model) {
    // Use helper method to update the current provider's model
    state = state.withModel(model);
    _saveSettings();
  }

  void setAutoImageMode(AutoImageMode mode) {
    state = state.copyWith(autoImageMode: mode);
    _saveSettings();
  }

  void setDefaultWidth(int width) {
    state = state.copyWith(defaultWidth: width.clamp(256, 2048));
    _saveSettings();
  }

  void setDefaultHeight(int height) {
    state = state.copyWith(defaultHeight: height.clamp(256, 2048));
    _saveSettings();
  }

  void setDefaultSteps(int steps) {
    state = state.copyWith(defaultSteps: steps.clamp(1, 150));
    _saveSettings();
  }

  void setDefaultCfgScale(double cfgScale) {
    state = state.copyWith(defaultCfgScale: cfgScale.clamp(1.0, 30.0));
    _saveSettings();
  }

  void setDefaultSampler(String sampler) {
    state = state.copyWith(defaultSampler: sampler);
    _saveSettings();
  }
  
  void setDefaultScheduler(String scheduler) {
    state = state.copyWith(defaultScheduler: scheduler);
    _saveSettings();
  }

  void setDefaultNegativePrompt(String? negativePrompt) {
    state = state.copyWith(defaultNegativePrompt: negativePrompt);
    _saveSettings();
  }

  // [生图提示词自定义]
  void setPositivePromptPrefix(String? prefix) {
    state = state.copyWith(positivePromptPrefix: prefix);
    _saveSettings();
  }

  void setExtractionInstruction(String? instruction) {
    state = state.copyWith(extractionInstruction: instruction);
    _saveSettings();
  }

  void setImageTagInstruction(String? instruction) {
    state = state.copyWith(imageTagInstruction: instruction);
    _saveSettings();
  }

  // [全自动生图] 额外调 LLM 优化提示词
  void setEnableAutoPromptGeneration(bool value) {
    state = state.copyWith(enableAutoPromptGeneration: value);
    _saveSettings();
  }

  void setAutoPromptConfigId(String? configId) {
    state = state.copyWith(autoPromptConfigId: configId);
    _saveSettings();
  }

  // [提示词优化] 独立生图 API 配置
  void setPromptOptBaseUrl(String? baseUrl) {
    state = state.copyWith(promptOptBaseUrl: baseUrl?.isEmpty == true ? null : baseUrl);
    _saveSettings();
  }

  void setPromptOptApiKey(String? apiKey) {
    state = state.copyWith(promptOptApiKey: apiKey?.isEmpty == true ? null : apiKey);
    _saveSettings();
  }

  void setPromptOptModel(String? model) {
    state = state.copyWith(promptOptModel: model?.isEmpty == true ? null : model);
    _saveSettings();
  }
  
  // NovelAI specific setters
  void setNovelaiAnlasGuard(bool value) {
    state = state.copyWith(novelaiAnlasGuard: value);
    _saveSettings();
  }
  
  void setNovelaiSm(bool value) {
    state = state.copyWith(novelaiSm: value);
    // Disable sm_dyn if sm is disabled
    if (!value) {
      state = state.copyWith(novelaiSmDyn: false);
    }
    _saveSettings();
  }
  
  void setNovelaiSmDyn(bool value) {
    state = state.copyWith(novelaiSmDyn: value);
    _saveSettings();
  }
  
  void setNovelaiDecrisper(bool value) {
    state = state.copyWith(novelaiDecrisper: value);
    _saveSettings();
  }
  
  void setNovelaiVarietyBoost(bool value) {
    state = state.copyWith(novelaiVarietyBoost: value);
    _saveSettings();
  }
  
  // OpenAI specific setters
  void setOpenaiStyle(String style) {
    state = state.copyWith(openaiStyle: style);
    _saveSettings();
  }
  
  void setOpenaiQuality(String quality) {
    state = state.copyWith(openaiQuality: quality);
    _saveSettings();
  }

  void reset() {
    state = const ImageGenSettings();
    _saveSettings();
  }
}

/// Image generation state
class ImageGenState {
  final bool isGenerating;
  final double progress;
  final ImageGenResult? result;
  final String? error;

  const ImageGenState({
    this.isGenerating = false,
    this.progress = 0.0,
    this.result,
    this.error,
  });

  ImageGenState copyWith({
    bool? isGenerating,
    double? progress,
    ImageGenResult? result,
    String? error,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return ImageGenState(
      isGenerating: isGenerating ?? this.isGenerating,
      progress: progress ?? this.progress,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier for image generation state
class ImageGenStateNotifier extends StateNotifier<ImageGenState> {
  final ImageGenerationService _service;

  ImageGenStateNotifier(this._service) : super(const ImageGenState()) {
    _service.onProgress = (progress) {
      state = state.copyWith(progress: progress);
    };
    _service.onError = (error) {
      state = state.copyWith(isGenerating: false, error: error);
    };
  }

  Future<ImageGenResult?> generate(ImageGenRequest request) async {
    state = state.copyWith(
      isGenerating: true, 
      progress: 0.0, 
      clearError: true,
      clearResult: true,
    );
    
    try {
      final result = await _service.generate(request);
      state = state.copyWith(isGenerating: false, result: result);
      return result;
    } catch (e) {
      state = state.copyWith(isGenerating: false, error: e.toString());
      return null;
    }
  }

  Future<ImageGenResult?> generatePortrait({
    required String characterName,
    required String characterDescription,
    String? style,
  }) async {
    state = state.copyWith(
      isGenerating: true, 
      progress: 0.0, 
      clearError: true,
      clearResult: true,
    );
    
    try {
      final result = await _service.generatePortrait(
        characterName: characterName,
        characterDescription: characterDescription,
        style: style,
      );
      state = state.copyWith(isGenerating: false, result: result);
      return result;
    } catch (e) {
      state = state.copyWith(isGenerating: false, error: e.toString());
      return null;
    }
  }
  
  /// Generate image from a specific mode (character, face, background, etc.)
  Future<ImageGenResult?> generateFromMode({
    required ImageGenMode mode,
    required String prompt,
    String? negativePrompt,
  }) async {
    final settings = _service.settings;
    
    return generate(ImageGenRequest(
      prompt: prompt,
      negativePrompt: negativePrompt ?? settings.defaultNegativePrompt,
      width: settings.defaultWidth,
      height: settings.defaultHeight,
      steps: settings.defaultSteps,
      cfgScale: settings.defaultCfgScale,
      sampler: settings.defaultSampler,
      mode: mode,
    ));
  }

  void clear() {
    state = const ImageGenState();
  }
}

/// Provider for image generation state
final imageGenStateProvider = StateNotifierProvider<ImageGenStateNotifier, ImageGenState>((ref) {
  final service = ref.watch(imageGenServiceProvider);
  return ImageGenStateNotifier(service);
});

/// Provider for generating images
final generateImageProvider = Provider<Future<ImageGenResult?> Function(ImageGenRequest)>((ref) {
  return (ImageGenRequest request) async {
    return ref.read(imageGenStateProvider.notifier).generate(request);
  };
});

/// Provider for parsing /imagine command
final parseImagineCommandProvider = Provider<ImageGenRequest? Function(String)>((ref) {
  final service = ref.watch(imageGenServiceProvider);
  return service.parseImagineCommand;
});

/// Provider for extracting image URLs from text (base feature for all channels)
final extractImageUrlsProvider = Provider<List<String> Function(String)>((ref) {
  return ImageGenerationService.extractImageUrls;
});

/// Provider for downloading images from URL
final downloadImageProvider = Provider<Future<dynamic> Function(String)>((ref) {
  final service = ref.watch(imageGenServiceProvider);
  return service.downloadImage;
});

/// Provider for default models for current provider (fallback)
final defaultModelsProvider = Provider<List<String>>((ref) {
  final settings = ref.watch(imageGenSettingsProvider);
  return settings.provider.defaultModels;
});

/// State for fetched models
class FetchedModelsState {
  final List<String>? models;
  final bool isLoading;
  final String? error;
  
  const FetchedModelsState({
    this.models,
    this.isLoading = false,
    this.error,
  });
  
  FetchedModelsState copyWith({
    List<String>? models,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return FetchedModelsState(
      models: models ?? this.models,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier for fetched models
class FetchedModelsNotifier extends StateNotifier<FetchedModelsState> {
  final ImageGenerationService _service;
  final ImageGenSettings _settings;
  
  FetchedModelsNotifier(this._service, this._settings) : super(const FetchedModelsState()) {
    // Auto-fetch models on initialization if provider supports it
    if (_settings.provider.supportsFetchingModels) {
      fetchModels();
    } else {
      // Use default models immediately for providers that don't support fetching
      state = FetchedModelsState(models: _settings.provider.defaultModels);
    }
  }
  
  Future<void> fetchModels() async {
    debugPrint('FetchedModelsNotifier.fetchModels() called');
    debugPrint('  Provider: ${_settings.provider.displayName}');
    debugPrint('  Supports fetching: ${_settings.provider.supportsFetchingModels}');
    
    if (!_settings.provider.supportsFetchingModels) {
      // Provider doesn't support fetching, use default models
      debugPrint('  Using default models: ${_settings.provider.defaultModels}');
      state = FetchedModelsState(models: _settings.provider.defaultModels);
      return;
    }
    
    state = state.copyWith(isLoading: true, clearError: true);
    
    try {
      debugPrint('  Calling service.fetchModels()...');
      final models = await _service.fetchModels();
      debugPrint('  Fetched models: $models');
      
      if (!mounted) return; // 页面已销毁，避免 after dispose 崩溃
      if (models != null && models.isNotEmpty) {
        state = FetchedModelsState(models: models);
      } else {
        // [硬编码修复] 不再把 defaultModels 塞进 state.models,
        // 否则 UI 无法区分"真实拉取"和"硬编码回退" → 永远显示 DALL-E 3/2。
        // null = 没拉到真实模型,UI 走手动输入分支。
        debugPrint('  No models returned, state.models = null (UI shows manual input)');
        state = const FetchedModelsState();
      }
    } catch (e) {
      debugPrint('  Error fetching models: $e');
      if (!mounted) return; // 同上
      // [硬编码修复] error 时也不塞 defaultModels,只存错误信息
      state = FetchedModelsState(
        error: e.toString(),
      );
    }
  }
  
  void reset() {
    state = const FetchedModelsState();
  }
}

/// Provider for fetched models state - only rebuilds when provider type changes
final fetchedModelsProvider = StateNotifierProvider<FetchedModelsNotifier, FetchedModelsState>((ref) {
  final service = ref.watch(imageGenServiceProvider);
  // Only rebuild when the provider type changes, not when model or other settings change
  final provider = ref.watch(imageGenSettingsProvider.select((s) => s.provider));
  final apiKeys = ref.watch(imageGenSettingsProvider.select((s) => s.apiKeys));
  final apiEndpoints = ref.watch(imageGenSettingsProvider.select((s) => s.apiEndpoints));
  
  // Create a temporary settings object with just the fields we need for fetching
  final settings = ImageGenSettings(
    provider: provider,
    apiKeys: apiKeys,
    apiEndpoints: apiEndpoints,
  );
  
  return FetchedModelsNotifier(service, settings);
});

/// Provider for available models - combines fetched and default models
final availableModelsProvider = Provider<List<String>>((ref) {
  final provider = ref.watch(imageGenSettingsProvider.select((s) => s.provider));
  final fetchedState = ref.watch(fetchedModelsProvider);
  
  // If we have fetched models, use them
  if (fetchedState.models != null && fetchedState.models!.isNotEmpty) {
    return fetchedState.models!;
  }
  
  // Otherwise fall back to default models
  return provider.defaultModels;
});

/// Provider for model display name
final modelDisplayNameProvider = Provider.family<String, String>((ref, model) {
  return ImageGenProvider.getModelDisplayName(model);
});

/// Provider to check if provider supports fetching models
final supportsFetchingModelsProvider = Provider<bool>((ref) {
  final provider = ref.watch(imageGenSettingsProvider.select((s) => s.provider));
  return provider.supportsFetchingModels;
});