import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:archive/archive.dart';

/// Image Generation Provider types (channels, not models)
enum ImageGenProvider {
  // Cloud providers
  openai('openai', 'OpenAI', 'https://api.openai.com/v1'),
  openaiChat('openai_chat', 'OpenAI-Chat', 'https://api.openai.com/v1'),
  gemini('gemini', 'Gemini', 'https://generativelanguage.googleapis.com/v1beta'),
  novelai('novelai', 'NovelAI', 'https://image.novelai.net'),
  
  // Local SD backends
  automatic1111('automatic1111', 'Automatic1111', 'http://localhost:7860'),
  comfyui('comfyui', 'ComfyUI', 'http://127.0.0.1:8188'),
  ;

  final String id;
  final String displayName;
  final String defaultEndpoint;

  const ImageGenProvider(this.id, this.displayName, this.defaultEndpoint);

  static ImageGenProvider? fromId(String id) {
    try {
      return ImageGenProvider.values.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
  
  /// Check if this provider requires an API key
  bool get requiresApiKey => [
    openai,
    openaiChat,
    gemini,
    novelai,
  ].contains(this);
  
  /// Check if this provider uses local endpoint
  bool get isLocalProvider => [
    automatic1111,
    comfyui,
  ].contains(this);
  
  /// Get default model for this provider
  String get defaultModel {
    switch (this) {
      case openai:
        return 'dall-e-3';
      case openaiChat:
        return 'gpt-image-1';
      case gemini:
        return 'gemini-2.5-flash-image';
      case novelai:
        return 'nai-diffusion-4-5-curated';
      case automatic1111:
      case comfyui:
        return '';
    }
  }
  
  /// Check if this provider supports fetching model list from API
  bool get supportsFetchingModels => [
    openai,
    openaiChat,
    gemini,
    automatic1111,
    comfyui,
  ].contains(this);
  
  /// Get default/fallback models for this provider (used when API fetch fails)
  List<String> get defaultModels {
    switch (this) {
      case openai:
        return [
          'dall-e-3',
          'dall-e-2',
          'gpt-image-1',
        ];
      case openaiChat:
        return [
          'gpt-image-1',
          'gemini-2.5-flash-image',
        ];
      case gemini:
        return [
          'gemini-2.5-flash-image',      // Nano-Banana
          'gemini-3-pro-image-preview',       // Nano-Banana-Pro
        ];
      case novelai:
        return [
          'nai-diffusion-4-5-curated',
          'nai-diffusion-4-5-full',
          'nai-diffusion-4-curated-preview',
          'nai-diffusion-4-full',
          'nai-diffusion-3',
          'nai-diffusion-furry-3',
        ];
      case automatic1111:
      case comfyui:
        return []; // Models are fetched from the local server
    }
  }
  
  /// Get model display name
  static String getModelDisplayName(String model) {
    switch (model) {
      // OpenAI
      case 'dall-e-3': return 'DALL-E 3';
      case 'dall-e-2': return 'DALL-E 2';
      case 'gpt-image-1': return 'GPT-Image-1';
      // Gemini
      case 'gemini-2.5-flash-image': return 'Nano-Banana';
      case 'gemini-3-pro-image-preview': return 'Nano-Banana-Pro';
      // NovelAI
      case 'nai-diffusion-4-curated-preview': return 'NAI Diffusion V4 Curated';
      case 'nai-diffusion-4-full': return 'NAI Diffusion V4 Full';
      case 'nai-diffusion-3': return 'NAI Diffusion V3';
      case 'nai-diffusion-furry-3': return 'NAI Diffusion Furry V3';
      default: return model;
    }
  }
}

/// Image generation mode
enum ImageGenMode {
  free('free', 'Free Prompt'),
  character('character', 'Character Portrait'),
  face('face', 'Face/Portrait'),
  background('background', 'Background'),
  lastMessage('last_message', 'Based on Last Message'),
  scenario('scenario', 'Based on Scenario'),
  ;

  final String id;
  final String displayName;
  
  const ImageGenMode(this.id, this.displayName);
}

/// Image Generation Settings
/// 自动生图模式：关闭 / 仅写提示词 / 全自动生成
enum AutoImageMode {
  off('off', '关闭'),
  promptOnly('promptOnly', '仅写提示词'),
  auto('auto', '全自动生成');

  const AutoImageMode(this.id, this.displayName);
  final String id;
  final String displayName;

  static AutoImageMode fromId(String? id) =>
      AutoImageMode.values.firstWhere((e) => e.id == id,
          orElse: () => AutoImageMode.off);
}

class ImageGenSettings {
  final bool enabled;
  final ImageGenProvider provider;
  
  // Per-provider configurations stored as Maps
  final Map<String, String> apiKeys; // provider.id -> apiKey
  final Map<String, String> apiEndpoints; // provider.id -> endpoint
  final Map<String, String> models; // provider.id -> model
  
  // Shared defaults
  final int defaultWidth;
  final int defaultHeight;
  final int defaultSteps;
  final double defaultCfgScale;
  final String defaultSampler;
  final String defaultScheduler;
  final String? defaultNegativePrompt;
  
  // NovelAI specific
  final bool novelaiAnlasGuard;
  final bool novelaiSm;
  final bool novelaiSmDyn;
  final bool novelaiDecrisper;
  final bool novelaiVarietyBoost;
  
  // OpenAI specific
  final String openaiStyle; // vivid or natural
  final String openaiQuality; // standard or hd

  // 自动生图
  final AutoImageMode autoImageMode;

  const ImageGenSettings({
    this.enabled = false,
    this.provider = ImageGenProvider.openai,
    this.apiKeys = const {},
    this.apiEndpoints = const {},
    this.models = const {},
    this.defaultWidth = 1024,
    this.defaultHeight = 1024,
    this.defaultSteps = 20,
    this.defaultCfgScale = 7.0,
    this.defaultSampler = 'euler_a',
    this.defaultScheduler = 'karras',
    this.defaultNegativePrompt,
    // NovelAI
    this.novelaiAnlasGuard = true,
    this.novelaiSm = false,
    this.novelaiSmDyn = false,
    this.novelaiDecrisper = false,
    this.novelaiVarietyBoost = false,
    // OpenAI
    this.openaiStyle = 'vivid',
    this.openaiQuality = 'standard',
    // 自动生图
    this.autoImageMode = AutoImageMode.off,
  });
  
  // Convenience getters for current provider's config
  String? get apiKey => apiKeys[provider.id];
  String? get apiEndpoint => apiEndpoints[provider.id];
  String get model => models[provider.id] ?? provider.defaultModel;
  
  /// Get the effective API endpoint for current provider
  String get effectiveEndpoint => apiEndpoint ?? provider.defaultEndpoint;

  ImageGenSettings copyWith({
    bool? enabled,
    ImageGenProvider? provider,
    Map<String, String>? apiKeys,
    Map<String, String>? apiEndpoints,
    Map<String, String>? models,
    int? defaultWidth,
    int? defaultHeight,
    int? defaultSteps,
    double? defaultCfgScale,
    String? defaultSampler,
    String? defaultScheduler,
    String? defaultNegativePrompt,
    bool? novelaiAnlasGuard,
    bool? novelaiSm,
    bool? novelaiSmDyn,
    bool? novelaiDecrisper,
    bool? novelaiVarietyBoost,
    String? openaiStyle,
    String? openaiQuality,
    AutoImageMode? autoImageMode,
  }) {
    return ImageGenSettings(
      enabled: enabled ?? this.enabled,
      provider: provider ?? this.provider,
      apiKeys: apiKeys ?? this.apiKeys,
      apiEndpoints: apiEndpoints ?? this.apiEndpoints,
      models: models ?? this.models,
      defaultWidth: defaultWidth ?? this.defaultWidth,
      defaultHeight: defaultHeight ?? this.defaultHeight,
      defaultSteps: defaultSteps ?? this.defaultSteps,
      defaultCfgScale: defaultCfgScale ?? this.defaultCfgScale,
      defaultSampler: defaultSampler ?? this.defaultSampler,
      defaultScheduler: defaultScheduler ?? this.defaultScheduler,
      defaultNegativePrompt: defaultNegativePrompt ?? this.defaultNegativePrompt,
      novelaiAnlasGuard: novelaiAnlasGuard ?? this.novelaiAnlasGuard,
      novelaiSm: novelaiSm ?? this.novelaiSm,
      novelaiSmDyn: novelaiSmDyn ?? this.novelaiSmDyn,
      novelaiDecrisper: novelaiDecrisper ?? this.novelaiDecrisper,
      novelaiVarietyBoost: novelaiVarietyBoost ?? this.novelaiVarietyBoost,
      openaiStyle: openaiStyle ?? this.openaiStyle,
      openaiQuality: openaiQuality ?? this.openaiQuality,
      autoImageMode: autoImageMode ?? this.autoImageMode,
    );
  }
  
  /// Helper to update apiKey for current provider
  ImageGenSettings withApiKey(String? key) {
    final newKeys = Map<String, String>.from(apiKeys);
    if (key != null && key.isNotEmpty) {
      newKeys[provider.id] = key;
    } else {
      newKeys.remove(provider.id);
    }
    return copyWith(apiKeys: newKeys);
  }
  
  /// Helper to update apiEndpoint for current provider
  ImageGenSettings withApiEndpoint(String? endpoint) {
    final newEndpoints = Map<String, String>.from(apiEndpoints);
    if (endpoint != null && endpoint.isNotEmpty) {
      newEndpoints[provider.id] = endpoint;
    } else {
      newEndpoints.remove(provider.id);
    }
    return copyWith(apiEndpoints: newEndpoints);
  }
  
  /// Helper to update model for current provider
  ImageGenSettings withModel(String model) {
    final newModels = Map<String, String>.from(models);
    newModels[provider.id] = model;
    return copyWith(models: newModels);
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'provider': provider.id,
    'apiKeys': apiKeys,
    'apiEndpoints': apiEndpoints,
    'models': models,
    'defaultWidth': defaultWidth,
    'defaultHeight': defaultHeight,
    'defaultSteps': defaultSteps,
    'defaultCfgScale': defaultCfgScale,
    'defaultSampler': defaultSampler,
    'defaultScheduler': defaultScheduler,
    'defaultNegativePrompt': defaultNegativePrompt,
    'novelaiAnlasGuard': novelaiAnlasGuard,
    'novelaiSm': novelaiSm,
    'novelaiSmDyn': novelaiSmDyn,
    'novelaiDecrisper': novelaiDecrisper,
    'novelaiVarietyBoost': novelaiVarietyBoost,
    'openaiStyle': openaiStyle,
    'openaiQuality': openaiQuality,
    'autoImageMode': autoImageMode.id,
  };

  factory ImageGenSettings.fromJson(Map<String, dynamic> json) {
    // Handle migration from old format (single apiKey/apiEndpoint/model)
    Map<String, String> apiKeys = {};
    Map<String, String> apiEndpoints = {};
    Map<String, String> models = {};
    
    if (json['apiKeys'] is Map) {
      apiKeys = Map<String, String>.from(json['apiKeys'] as Map);
    } else if (json['apiKey'] != null) {
      // Migration: old single apiKey format
      final provider = json['provider'] as String? ?? 'openai';
      apiKeys[provider] = json['apiKey'] as String;
    }
    
    if (json['apiEndpoints'] is Map) {
      apiEndpoints = Map<String, String>.from(json['apiEndpoints'] as Map);
    } else if (json['apiEndpoint'] != null) {
      // Migration: old single apiEndpoint format
      final provider = json['provider'] as String? ?? 'openai';
      apiEndpoints[provider] = json['apiEndpoint'] as String;
    }
    
    if (json['models'] is Map) {
      models = Map<String, String>.from(json['models'] as Map);
    } else if (json['model'] != null) {
      // Migration: old single model format
      final provider = json['provider'] as String? ?? 'openai';
      models[provider] = json['model'] as String;
    }
    
    return ImageGenSettings(
      enabled: json['enabled'] as bool? ?? false,
      provider: ImageGenProvider.fromId(json['provider'] as String? ?? 'openai') ?? ImageGenProvider.openai,
      apiKeys: apiKeys,
      apiEndpoints: apiEndpoints,
      models: models,
      defaultWidth: json['defaultWidth'] as int? ?? 1024,
      defaultHeight: json['defaultHeight'] as int? ?? 1024,
      defaultSteps: json['defaultSteps'] as int? ?? 20,
      defaultCfgScale: (json['defaultCfgScale'] as num?)?.toDouble() ?? 7.0,
      defaultSampler: json['defaultSampler'] as String? ?? 'euler_a',
      defaultScheduler: json['defaultScheduler'] as String? ?? 'karras',
      defaultNegativePrompt: json['defaultNegativePrompt'] as String?,
      novelaiAnlasGuard: json['novelaiAnlasGuard'] as bool? ?? true,
      novelaiSm: json['novelaiSm'] as bool? ?? false,
      novelaiSmDyn: json['novelaiSmDyn'] as bool? ?? false,
      novelaiDecrisper: json['novelaiDecrisper'] as bool? ?? false,
      novelaiVarietyBoost: json['novelaiVarietyBoost'] as bool? ?? false,
      openaiStyle: json['openaiStyle'] as String? ?? 'vivid',
      openaiQuality: json['openaiQuality'] as String? ?? 'standard',
      autoImageMode: AutoImageMode.fromId(json['autoImageMode'] as String?),
    );
  }
}

/// Image generation request parameters
class ImageGenRequest {
  final String prompt;
  final String? negativePrompt;
  final int width;
  final int height;
  final int steps;
  final double cfgScale;
  final String sampler;
  final String? scheduler;
  final String? model;
  final int? seed;
  final int batchSize;
  final ImageGenMode mode;

  const ImageGenRequest({
    required this.prompt,
    this.negativePrompt,
    this.width = 1024,
    this.height = 1024,
    this.steps = 20,
    this.cfgScale = 7.0,
    this.sampler = 'euler_a',
    this.scheduler,
    this.model,
    this.seed,
    this.batchSize = 1,
    this.mode = ImageGenMode.free,
  });

  Map<String, dynamic> toJson() => {
    'prompt': prompt,
    'negative_prompt': negativePrompt,
    'width': width,
    'height': height,
    'steps': steps,
    'cfg_scale': cfgScale,
    'sampler_name': sampler,
    'scheduler': scheduler,
    'model': model,
    'seed': seed ?? -1,
    'batch_size': batchSize,
  };
}

/// Image generation result
class ImageGenResult {
  final List<Uint8List> images;
  final List<String> imageUrls; // For URL-based results
  final String prompt;
  final int seed;
  final String format; // png, jpg, webp
  final Map<String, dynamic>? metadata;

  const ImageGenResult({
    this.images = const [],
    this.imageUrls = const [],
    required this.prompt,
    required this.seed,
    this.format = 'png',
    this.metadata,
  });
  
  bool get hasImages => images.isNotEmpty || imageUrls.isNotEmpty;
}

/// Available samplers
class ImageGenSampler {
  final String id;
  final String name;

  const ImageGenSampler({required this.id, required this.name});

  static const List<ImageGenSampler> samplers = [
    ImageGenSampler(id: 'euler', name: 'Euler'),
    ImageGenSampler(id: 'euler_a', name: 'Euler Ancestral'),
    ImageGenSampler(id: 'heun', name: 'Heun'),
    ImageGenSampler(id: 'dpm_2', name: 'DPM2'),
    ImageGenSampler(id: 'dpm_2_a', name: 'DPM2 Ancestral'),
    ImageGenSampler(id: 'lms', name: 'LMS'),
    ImageGenSampler(id: 'dpm_fast', name: 'DPM Fast'),
    ImageGenSampler(id: 'dpm_adaptive', name: 'DPM Adaptive'),
    ImageGenSampler(id: 'dpmpp_2s_a', name: 'DPM++ 2S Ancestral'),
    ImageGenSampler(id: 'dpmpp_sde', name: 'DPM++ SDE'),
    ImageGenSampler(id: 'dpmpp_2m', name: 'DPM++ 2M'),
    ImageGenSampler(id: 'ddim', name: 'DDIM'),
    ImageGenSampler(id: 'plms', name: 'PLMS'),
    ImageGenSampler(id: 'uni_pc', name: 'UniPC'),
    // NovelAI specific
    ImageGenSampler(id: 'k_euler', name: 'K-Euler'),
    ImageGenSampler(id: 'k_euler_ancestral', name: 'K-Euler Ancestral'),
    ImageGenSampler(id: 'k_dpmpp_2m', name: 'K-DPM++ 2M'),
    ImageGenSampler(id: 'k_dpmpp_2s_ancestral', name: 'K-DPM++ 2S Ancestral'),
    ImageGenSampler(id: 'k_dpmpp_sde', name: 'K-DPM++ SDE'),
  ];
  
  static List<ImageGenSampler> forProvider(ImageGenProvider provider) {
    switch (provider) {
      case ImageGenProvider.novelai:
        return samplers.where((s) => s.id.startsWith('k_') || s.id == 'ddim').toList();
      case ImageGenProvider.openai:
      case ImageGenProvider.openaiChat:
      case ImageGenProvider.gemini:
        return []; // These don't use samplers
      default:
        return samplers;
    }
  }
}

/// Image aspect ratios
class ImageAspectRatio {
  final String name;
  final int width;
  final int height;

  const ImageAspectRatio({
    required this.name,
    required this.width,
    required this.height,
  });

  double get ratio => width / height;

  static const List<ImageAspectRatio> presets = [
    ImageAspectRatio(name: 'Square (1:1)', width: 1024, height: 1024),
    ImageAspectRatio(name: 'Portrait (2:3)', width: 832, height: 1216),
    ImageAspectRatio(name: 'Landscape (3:2)', width: 1216, height: 832),
    ImageAspectRatio(name: 'Wide (16:9)', width: 1344, height: 768),
    ImageAspectRatio(name: 'Tall (9:16)', width: 768, height: 1344),
    ImageAspectRatio(name: 'SD Square', width: 512, height: 512),
    ImageAspectRatio(name: 'SD Portrait', width: 512, height: 768),
    ImageAspectRatio(name: 'SD Landscape', width: 768, height: 512),
  ];
}

/// Image Generation Service
class ImageGenerationService {
  ImageGenSettings _settings = const ImageGenSettings();
  final Dio _dio = Dio();

  /// Callbacks
  void Function(double)? onProgress;
  void Function(String)? onError;

  ImageGenSettings get settings => _settings;

  /// Update settings
  void updateSettings(ImageGenSettings settings) {
    _settings = settings;
  }

  /// Fetch available models from the provider's API
  /// Returns null if the provider doesn't support fetching or if the request fails
  Future<List<String>?> fetchModels() async {
    debugPrint('fetchModels() called for provider: ${_settings.provider.displayName}');
    
    if (!_settings.provider.supportsFetchingModels) {
      debugPrint('Provider does not support fetching models');
      return null;
    }
    
    try {
      debugPrint('Fetching models from ${_settings.effectiveEndpoint}...');
      
      switch (_settings.provider) {
        case ImageGenProvider.openai:
        case ImageGenProvider.openaiChat:
          return await _fetchOpenAIModels();
        case ImageGenProvider.gemini:
          return await _fetchGeminiModels();
        case ImageGenProvider.automatic1111:
          return await _fetchAutomatic1111Models();
        case ImageGenProvider.comfyui:
          return await _fetchComfyUIModels();
        default:
          return null;
      }
    } catch (e, stack) {
      debugPrint('Failed to fetch models: $e\n$stack');
      return null;
    }
  }
  
  /// Fetch available image generation models from OpenAI
  Future<List<String>> _fetchOpenAIModels() async {
    final apiKey = _settings.apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('OpenAI: No API key configured, returning default models');
      return _settings.provider.defaultModels;
    }
    
    final endpoint = _settings.effectiveEndpoint;
    debugPrint('OpenAI: Fetching models from $endpoint/models');
    
    final response = await _dio.get<Map<String, dynamic>>(
      '$endpoint/models',
      options: Options(headers: {
        'Authorization': 'Bearer $apiKey',
      }),
    );
    
    debugPrint('OpenAI: Response status ${response.statusCode}');
    
    if (response.statusCode != 200 || response.data == null) {
      debugPrint('OpenAI: Failed to fetch, returning default models');
      return _settings.provider.defaultModels;
    }
    
    final data = response.data!;
    final models = <String>[];
    
    // Get all models and filter for image generation capable ones
    final modelList = data['data'] as List? ?? [];
    debugPrint('OpenAI: Found ${modelList.length} total models');
    
    for (final model in modelList) {
      final id = model['id'] as String?;
      if (id != null) {
        // Include known image generation models
        if (id.contains('dall-e') || id.contains('gpt-image') || id.contains('image')) {
          models.add(id);
          debugPrint('OpenAI: Found image model: $id');
        }
      }
    }
    
    debugPrint('OpenAI: Found ${models.length} image models');
    return models.isEmpty ? _settings.provider.defaultModels : models;
  }
  
  /// Fetch available models from Gemini API
  Future<List<String>> _fetchGeminiModels() async {
    final apiKey = _settings.apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('Gemini: No API key configured, returning default models');
      return _settings.provider.defaultModels;
    }
    
    final endpoint = _settings.effectiveEndpoint;
    debugPrint('Gemini: Fetching models from $endpoint/models');
    
    final response = await _dio.get<Map<String, dynamic>>(
      '$endpoint/models?key=$apiKey',
    );
    
    debugPrint('Gemini: Response status ${response.statusCode}');
    
    if (response.statusCode != 200 || response.data == null) {
      debugPrint('Gemini: Failed to fetch, returning default models');
      return _settings.provider.defaultModels;
    }
    
    final data = response.data!;
    final models = <String>[];
    
    // Get all models and filter for image generation capable ones
    final modelList = data['models'] as List? ?? [];
    debugPrint('Gemini: Found ${modelList.length} total models');
    
    for (final model in modelList) {
      final name = model['name'] as String?;
      // Model name format: models/gemini-xxx
      if (name != null) {
        final modelId = name.replaceFirst('models/', '');
        
        if (
            (modelId.contains('image') || 
             modelId.contains('banana'))) {
          models.add(modelId);
          debugPrint('Gemini: Found model: $modelId');
        }
      }
    }
    
    debugPrint('Gemini: Found ${models.length} usable models');
    return models.isEmpty ? _settings.provider.defaultModels : models;
  }
  
  /// Fetch available models from Automatic1111 WebUI
  Future<List<String>> _fetchAutomatic1111Models() async {
    final endpoint = _settings.effectiveEndpoint;
    final response = await _dio.get<List<dynamic>>(
      '$endpoint/sdapi/v1/sd-models',
    );
    
    if (response.statusCode != 200 || response.data == null) {
      return [];
    }
    
    return response.data!
        .map((model) => model['model_name'] as String? ?? model['title'] as String? ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
  }
  
  /// Fetch available checkpoints from ComfyUI
  Future<List<String>> _fetchComfyUIModels() async {
    final endpoint = _settings.effectiveEndpoint;
    final response = await _dio.get<Map<String, dynamic>>(
      '$endpoint/object_info/CheckpointLoaderSimple',
    );
    
    if (response.statusCode != 200 || response.data == null) {
      return [];
    }
    
    // ComfyUI returns checkpoint names in a specific format
    final checkpointInfo = response.data!['CheckpointLoaderSimple'] as Map<String, dynamic>?;
    final input = checkpointInfo?['input'] as Map<String, dynamic>?;
    final required = input?['required'] as Map<String, dynamic>?;
    final ckptName = required?['ckpt_name'] as List?;
    
    if (ckptName != null && ckptName.isNotEmpty) {
      final options = ckptName[0] as List?;
      if (options != null) {
        return options.map((e) => e.toString()).toList();
      }
    }
    
    return [];
  }

  /// Extract images from arbitrary response data (text containing URLs, base64, etc.)
  /// This is used as a fallback when the response doesn't contain images in standard format
  Future<List<Uint8List>> _extractImagesFromResponse(dynamic responseData, {String debugPrefix = ''}) async {
    final images = <Uint8List>[];
    
    // Convert response to string for URL extraction
    String textContent = '';
    
    if (responseData is String) {
      textContent = responseData;
    } else if (responseData is Map) {
      // Try common response formats
      final content = responseData['content'] ?? 
                      responseData['text'] ?? 
                      responseData['message'] ??
                      responseData['output'] ??
                      responseData['result'];
      if (content is String) {
        textContent = content;
      } else if (content is Map) {
        textContent = content['text'] as String? ?? content.toString();
      }
      
      // Check for inline base64 data
      final b64 = responseData['b64_json'] ?? 
                  responseData['data'] ?? 
                  responseData['image'] ??
                  responseData['base64'];
      if (b64 is String && b64.isNotEmpty) {
        try {
          final base64Data = b64.replaceFirst(RegExp(r'^data:image/[^;]+;base64,'), '');
          images.add(base64Decode(base64Data));
          debugPrint('$debugPrefix Found inline base64 image');
        } catch (e) {
          debugPrint('$debugPrefix Failed to decode base64: $e');
        }
      }
      
      // Check for URL field
      final url = responseData['url'] ?? responseData['image_url'];
      if (url is String && url.isNotEmpty) {
        textContent += ' $url';
      }
    }
    
    // Extract and download any image URLs found in the text
    if (textContent.isNotEmpty) {
      final urls = extractImageUrls(textContent);
      for (final url in urls) {
        debugPrint('$debugPrefix Found URL: $url');
        try {
          if (url.startsWith('data:image')) {
            // Base64 data URL
            final base64Data = url.replaceFirst(RegExp(r'^data:image/[^;]+;base64,'), '');
            images.add(base64Decode(base64Data));
          } else {
            // Regular URL - download it
            final imgData = await downloadImage(url);
            if (imgData != null) {
              images.add(imgData);
            }
          }
        } catch (e) {
          debugPrint('$debugPrefix Failed to process URL $url: $e');
        }
      }
    }
    
    return images;
  }
  /// 从消息内容提取生图提示词:优先 <image>...</image> 标签,无标签返回 null
  static String? extractImagePrompt(String content) {
    final match = RegExp(r'<image>([\s\S]*?)</image>', caseSensitive: false)
        .firstMatch(content);
    final tag = match?.group(1)?.trim();
    return (tag != null && tag.isNotEmpty) ? tag : null;
  }

  /// Generate images based on current provider
  Future<ImageGenResult?> generate(ImageGenRequest request) async {
    if (!_settings.enabled) return null;

    final model = request.model ?? _settings.model;
    
    try {
      debugPrint('Image Generation [${_settings.provider.displayName}]');
      debugPrint('  Model: $model');
      debugPrint('  Prompt: "${request.prompt}"');
      debugPrint('  Size: ${request.width}x${request.height}');
      debugPrint('  Endpoint: ${_settings.effectiveEndpoint}');

      switch (_settings.provider) {
        case ImageGenProvider.openai:
          return await _generateOpenAI(request, model);
        case ImageGenProvider.openaiChat:
          return await _generateOpenAIChat(request, model);
        case ImageGenProvider.gemini:
          return await _generateGemini(request, model);
        case ImageGenProvider.novelai:
          return await _generateNovelAI(request, model);
        case ImageGenProvider.automatic1111:
          return await _generateAutomatic1111(request);
        case ImageGenProvider.comfyui:
          return await _generateComfyUI(request);
      }
    } catch (e, stack) {
      debugPrint('Image generation error: $e\n$stack');
      onError?.call('Image generation error: $e');
      return null;
    }
  }

  /// Generate image using OpenAI (DALL-E 2/3 or GPT-Image-1)
  Future<ImageGenResult?> _generateOpenAI(ImageGenRequest request, String model) async {
    final apiKey = _settings.apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('OpenAI API key is required');
    }

    onProgress?.call(0.1);

    final isDalle2 = model.contains('dall-e-2');
    final isDalle3 = model.contains('dall-e-3');
    final isGptImg = model.contains('gpt-image');

    // Apply prompt limits
    String prompt = request.prompt;
    if (isDalle2 && prompt.length > 1000) {
      prompt = prompt.substring(0, 1000);
    } else if (isDalle3 && prompt.length > 4000) {
      prompt = prompt.substring(0, 4000);
    } else if (isGptImg && prompt.length > 32000) {
      prompt = prompt.substring(0, 32000);
    }

    // Determine size based on model and aspect ratio
    String size;
    final aspectRatio = request.width / request.height;
    
    if (isDalle3) {
      if (aspectRatio < 0.8) {
        size = '1024x1792';
      } else if (aspectRatio > 1.2) {
        size = '1792x1024';
      } else {
        size = '1024x1024';
      }
    } else if (isGptImg) {
      if (aspectRatio < 0.8) {
        size = '1024x1536';
      } else if (aspectRatio > 1.2) {
        size = '1536x1024';
      } else {
        size = '1024x1024';
      }
    } else {
      // DALL-E 2
      size = (request.width <= 512 && request.height <= 512) ? '512x512' : '1024x1024';
    }

    final requestBody = {
      'model': model,
      'prompt': prompt,
      'n': 1,
      'size': size,
      if (isDalle2 || isDalle3 || isGptImg) 'response_format': 'b64_json',
      if (isDalle3) ...{
        'style': _settings.openaiStyle,
        'quality': _settings.openaiQuality,
      },
    };

    onProgress?.call(0.3);

    final endpoint = _settings.effectiveEndpoint;
    final response = await _dio.post<Map<String, dynamic>>(
      '$endpoint/images/generations',
      options: Options(headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      }),
      data: requestBody,
    );

    onProgress?.call(0.9);

    if (response.statusCode != 200) {
      throw Exception('OpenAI error: ${response.statusCode} ${response.data}');
    }

    final data = response.data as Map<String, dynamic>;
    final images = <Uint8List>[];
    
    for (final item in data['data'] as List? ?? []) {
      if (item['b64_json'] != null) {
        images.add(base64Decode(item['b64_json'] as String));
      } else if (item['url'] != null) {
        // Some responses return URL instead of base64
        final imgData = await downloadImage(item['url'] as String);
        if (imgData != null) {
          images.add(imgData);
        }
      }
    }
    
    // Fallback: try to extract images from the raw response
    if (images.isEmpty) {
      debugPrint('OpenAI: No images in standard format, trying fallback extraction...');
      final fallbackImages = await _extractImagesFromResponse(data, debugPrefix: 'OpenAI: ');
      images.addAll(fallbackImages);
    }

    onProgress?.call(1.0);

    return ImageGenResult(
      images: images,
      prompt: prompt,
      seed: DateTime.now().millisecondsSinceEpoch,
      format: 'png',
      metadata: {'model': model, 'provider': 'openai'},
    );
  }

  /// Generate image using OpenAI Chat API (chat/completions)
  /// This is for APIs that use chat format for image generation (like some compatible APIs)
  Future<ImageGenResult?> _generateOpenAIChat(ImageGenRequest request, String model) async {
    final apiKey = _settings.apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API key is required');
    }

    onProgress?.call(0.1);

    final prompt = request.prompt;

    // Build the chat message requesting image generation
    final requestBody = <String, dynamic>{
      'model': model,
      'messages': [
        {
          'role': 'user',
          'content': 'Generate an image: $prompt',
        }
      ],
      'max_tokens': 4096,
    };

    debugPrint('OpenAI-Chat: Sending request to chat/completions');
    debugPrint('OpenAI-Chat: Model: $model');
    debugPrint('OpenAI-Chat: Prompt: $prompt');

    onProgress?.call(0.3);

    final endpoint = _settings.effectiveEndpoint;
    final response = await _dio.post<Map<String, dynamic>>(
      '$endpoint/chat/completions',
      options: Options(headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      }),
      data: requestBody,
    );

    onProgress?.call(0.7);

    if (response.statusCode != 200) {
      throw Exception('OpenAI-Chat error: ${response.statusCode} ${response.data}');
    }

    final data = response.data as Map<String, dynamic>;
    final images = <Uint8List>[];
    
    // Parse the response - look for base64 image data or URLs in the content
    final choices = data['choices'] as List? ?? [];
    for (final choice in choices) {
      final message = choice['message'] as Map<String, dynamic>?;
      if (message == null) continue;
      
      final content = message['content'];
      
      // Check if content is a list (multimodal response with images)
      if (content is List) {
        for (final item in content) {
          if (item is Map<String, dynamic>) {
            // Check for inline image data
            if (item['type'] == 'image' || item['type'] == 'image_url') {
              final imageData = item['image'] ?? item['image_url'];
              if (imageData is Map<String, dynamic>) {
                final b64 = imageData['b64_json'] ?? imageData['data'];
                if (b64 != null && b64 is String) {
                  // Remove data URL prefix if present
                  final base64Data = b64.replaceFirst(RegExp(r'^data:image/[^;]+;base64,'), '');
                  images.add(base64Decode(base64Data));
                  debugPrint('OpenAI-Chat: Found inline base64 image');
                }
                final url = imageData['url'];
                if (url != null && url is String) {
                  // Download the image from URL
                  debugPrint('OpenAI-Chat: Downloading image from URL: $url');
                  final imgData = await downloadImage(url);
                  if (imgData != null) {
                    images.add(imgData);
                  }
                }
              }
            }
          }
        }
      }
      // Check if content is a string - look for URLs or base64
      else if (content is String) {
        // Try to extract image URLs from the text response
        final urls = extractImageUrls(content);
        for (final url in urls) {
          debugPrint('OpenAI-Chat: Found URL in response: $url');
          if (url.startsWith('data:image')) {
            // Base64 data URL
            final base64Data = url.replaceFirst(RegExp(r'^data:image/[^;]+;base64,'), '');
            images.add(base64Decode(base64Data));
          } else {
            // Regular URL - download it
            final imgData = await downloadImage(url);
            if (imgData != null) {
              images.add(imgData);
            }
          }
        }
      }
    }

    onProgress?.call(1.0);

    if (images.isEmpty) {
      debugPrint('OpenAI-Chat: No images found in response');
      debugPrint('OpenAI-Chat: Response data: $data');
      throw Exception('No images generated - response did not contain image data');
    }

    debugPrint('OpenAI-Chat: Generated ${images.length} images');

    return ImageGenResult(
      images: images,
      prompt: prompt,
      seed: DateTime.now().millisecondsSinceEpoch,
      format: 'png',
      metadata: {'model': model, 'provider': 'openai_chat'},
    );
  }

  /// Generate image using Gemini (Imagen / Nano-Banana models)
  Future<ImageGenResult?> _generateGemini(ImageGenRequest request, String model) async {
    final apiKey = _settings.apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Gemini API key is required');
    }

    onProgress?.call(0.1);
    
    // Determine aspect ratio
    String aspectRatio;
    final ratio = request.width / request.height;
    if ((ratio - 1.0).abs() < 0.1) {
      aspectRatio = '1:1';
    } else if (ratio > 1.5) {
      aspectRatio = '16:9';
    } else if (ratio < 0.7) {
      aspectRatio = '9:16';
    } else if (ratio > 1.2) {
      aspectRatio = '4:3';
    } else {
      aspectRatio = '3:4';
    }

    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': request.prompt}
          ]
        }
      ],
      'generationConfig': {
        'responseModalities': ['image', 'text'],
        'responseMimeType': 'image/png',
      },
      'imageGenerationConfig': {
        'aspectRatio': aspectRatio,
        'numberOfImages': 1,
        if (request.negativePrompt != null) 
          'negativePrompt': request.negativePrompt,
      },
    };

    onProgress?.call(0.3);

    final endpoint = _settings.effectiveEndpoint;
    final response = await _dio.post<Map<String, dynamic>>(
      '$endpoint/models/$model:generateContent?key=$apiKey',
      options: Options(headers: {
        'Content-Type': 'application/json',
      }),
      data: requestBody,
    );

    onProgress?.call(0.9);

    if (response.statusCode != 200) {
      throw Exception('Gemini error: ${response.statusCode} ${response.data}');
    }

    final data = response.data as Map<String, dynamic>;
    final images = <Uint8List>[];
    
    // Extract image from Gemini response
    final candidates = data['candidates'] as List?;
    if (candidates != null && candidates.isNotEmpty) {
      final content = candidates[0]['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      if (parts != null) {
        for (final part in parts) {
          if (part['inlineData'] != null) {
            final inlineData = part['inlineData'] as Map<String, dynamic>;
            final mimeType = inlineData['mimeType'] as String?;
            final imgData = inlineData['data'] as String?;
            if (mimeType?.startsWith('image/') == true && imgData != null) {
              images.add(base64Decode(imgData));
            }
          }
          // Also check for text content that may contain image URLs
          if (part['text'] != null && images.isEmpty) {
            final textImages = await _extractImagesFromResponse(part['text'], debugPrefix: 'Gemini: ');
            images.addAll(textImages);
          }
        }
      }
    }
    
    // Fallback: try to extract images from the raw response
    if (images.isEmpty) {
      debugPrint('Gemini: No images in standard format, trying fallback extraction...');
      final fallbackImages = await _extractImagesFromResponse(data, debugPrefix: 'Gemini: ');
      images.addAll(fallbackImages);
    }

    if (images.isEmpty) {
      throw Exception('Gemini: No image found in response');
    }

    onProgress?.call(1.0);

    return ImageGenResult(
      images: images,
      prompt: request.prompt,
      seed: DateTime.now().millisecondsSinceEpoch,
      format: 'png',
      metadata: {'model': model, 'provider': 'gemini'},
    );
  }

  /// Generate image using NovelAI
  Future<ImageGenResult?> _generateNovelAI(ImageGenRequest request, String model) async {
    final apiKey = _settings.apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('NovelAI API key is required');
    }

    onProgress?.call(0.1);

    // Apply Anlas guard if enabled
    int width = request.width;
    int height = request.height;
    int steps = request.steps;
    
    if (_settings.novelaiAnlasGuard) {
      const maxPixels = 1024 * 1024;
      const maxSteps = 28;
      
      if (width * height > maxPixels) {
        final ratio = math.sqrt(maxPixels / (width * height));
        width = ((width * ratio) ~/ 64) * 64;
        height = ((height * ratio) ~/ 64) * 64;
        debugPrint('Anlas Guard: Reduced size to ${width}x$height');
      }
      
      if (steps > maxSteps) {
        steps = maxSteps;
        debugPrint('Anlas Guard: Reduced steps to $steps');
      }
    }

    final isV4Model = model.contains('nai-diffusion-4');
    
    // Disable SM for DDIM sampler or V4 models
    final sm = (request.sampler == 'ddim' || isV4Model) ? false : _settings.novelaiSm;
    final smDyn = sm ? _settings.novelaiSmDyn : false;
    
    final seed = request.seed ?? DateTime.now().millisecondsSinceEpoch % 4294967295;
    
    final negativePrompt = request.negativePrompt ?? _settings.defaultNegativePrompt ?? 
        'blurry, lowres, upscaled, artistic error, film grain, scan artifacts, worst quality, bad quality, jpeg artifacts, very displeasing, chromatic aberration, halftone, multiple views, logo, too many watermarks, negative space, blank page';

    final requestBody = <String, dynamic>{
      'input': request.prompt,
      'model': model,
      'action': 'generate',
      'parameters': <String, dynamic>{
        'params_version': 3,
        'width': width,
        'height': height,
        'scale': request.cfgScale,
        'sampler': request.sampler,
        'steps': steps,
        'seed': seed,
        'n_samples': 1,
        'ucPreset': 0,
        'qualityToggle': true,
        'autoSmea': sm,
        'dynamic_thresholding': _settings.novelaiDecrisper,
        'controlnet_strength': 1,
        'legacy': false,
        'add_original_image': true,
        'cfg_rescale': 0,
        'noise_schedule': _settings.defaultScheduler,
        'legacy_v3_extend': false,
        'skip_cfg_above_sigma': _settings.novelaiVarietyBoost 
            ? _calculateSkipCfgAboveSigma(width, height, model) 
            : null,
        'use_coords': false,
        'normalize_reference_strength_multiple': true,
        'inpaintImg2ImgStrength': 1,
        'characterPrompts': <dynamic>[],
        'negative_prompt': negativePrompt,
        'deliberate_euler_ancestral_bug': false,
        'prefer_brownian': true,
        'image_format': 'png',
        if (isV4Model) ...{
          'v4_prompt': {
            'caption': {
              'base_caption': request.prompt,
              'char_captions': <dynamic>[],
            },
            'use_coords': false,
            'use_order': true,
          },
          'v4_negative_prompt': {
            'caption': {
              'base_caption': negativePrompt,
              'char_captions': <dynamic>[],
            },
          },
        },
        if (!isV4Model) ...{
          'sm': sm,
          'sm_dyn': smDyn,
          'uncond_scale': 1,
        },
      },
    };

    onProgress?.call(0.2);
    
    // Debug: print the request body
    debugPrint('NovelAI: Request body:');
    debugPrint(const JsonEncoder.withIndent('  ').convert(requestBody));

    final endpoint = _settings.effectiveEndpoint;
    
    try {
      final response = await _dio.post<List<int>>(
        '$endpoint/ai/generate-image',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.bytes,
          validateStatus: (status) => true, // Accept all status codes to read error body
        ),
        data: requestBody,
      );

      onProgress?.call(0.8);

      if (response.statusCode != 200) {
        // Try to decode error message
        String errorMsg = 'NovelAI error: ${response.statusCode}';
        try {
          final errorBody = utf8.decode(response.data as List<int>);
          debugPrint('NovelAI: Error response: $errorBody');
          errorMsg = 'NovelAI error: ${response.statusCode} - $errorBody';
        } catch (_) {
          debugPrint('NovelAI: Could not decode error body');
        }
        throw Exception(errorMsg);
      }

    // NovelAI returns a ZIP file containing the PNG
    final archive = ZipDecoder().decodeBytes(response.data as List<int>);
    Uint8List? imageBytes;
    
    for (final file in archive) {
      if (file.isFile && file.name.endsWith('.png')) {
        imageBytes = Uint8List.fromList(file.content as List<int>);
        break;
      }
    }

    if (imageBytes == null) {
      throw Exception('NovelAI: No image found in response');
    }

    onProgress?.call(1.0);

    return ImageGenResult(
      images: [imageBytes],
      prompt: request.prompt,
      seed: seed,
      format: 'png',
      metadata: {'model': model, 'provider': 'novelai'},
    );
    } catch (e) {
      if (e is DioException && e.response != null) {
        try {
          final errorBody = utf8.decode(e.response!.data as List<int>);
          debugPrint('NovelAI: DioException response: $errorBody');
          throw Exception('NovelAI error: ${e.response!.statusCode} - $errorBody');
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Calculate skip_cfg_above_sigma for NovelAI Variety+
  double _calculateSkipCfgAboveSigma(int width, int height, String model) {
    const referencePixelCount = 1011712; // 832 * 1216
    const sigmaMagicNumber = 19;
    const sigmaMagicNumberV4_5 = 58;
    
    final magicConstant = model.contains('nai-diffusion-4-5') 
        ? sigmaMagicNumberV4_5 
        : sigmaMagicNumber;
    
    final pixelCount = width * height;
    final ratio = pixelCount / referencePixelCount;
    
    return math.sqrt(ratio) * magicConstant;
  }

  /// Generate image using Automatic1111 WebUI
  Future<ImageGenResult?> _generateAutomatic1111(ImageGenRequest request) async {
    onProgress?.call(0.1);

    final requestBody = {
      'prompt': request.prompt,
      'negative_prompt': request.negativePrompt ?? _settings.defaultNegativePrompt ?? '',
      'width': request.width,
      'height': request.height,
      'steps': request.steps,
      'cfg_scale': request.cfgScale,
      'sampler_name': request.sampler,
      'seed': request.seed ?? -1,
      'batch_size': 1,
    };

    onProgress?.call(0.2);

    final endpoint = _settings.effectiveEndpoint;
    final response = await _dio.post<Map<String, dynamic>>(
      '$endpoint/sdapi/v1/txt2img',
      options: Options(headers: {
        'Content-Type': 'application/json',
      }),
      data: requestBody,
    );

    onProgress?.call(0.9);

    if (response.statusCode != 200) {
      throw Exception('Automatic1111 error: ${response.statusCode} ${response.data}');
    }

    final data = response.data as Map<String, dynamic>;
    final images = <Uint8List>[];
    
    for (final b64 in data['images'] as List) {
      images.add(base64Decode(b64 as String));
    }

    final info = jsonDecode(data['info'] as String? ?? '{}') as Map<String, dynamic>;
    final seed = info['seed'] as int? ?? DateTime.now().millisecondsSinceEpoch;

    onProgress?.call(1.0);

    return ImageGenResult(
      images: images,
      prompt: request.prompt,
      seed: seed,
      format: 'png',
      metadata: {'provider': 'automatic1111'},
    );
  }

  /// Generate image using ComfyUI (placeholder)
  Future<ImageGenResult?> _generateComfyUI(ImageGenRequest request) async {
    // ComfyUI requires workflow-based generation
    throw UnimplementedError('ComfyUI generation requires workflow configuration');
  }

  /// Extract image URLs from AI response text (base feature for all channels)
  static List<String> extractImageUrls(String text) {
    final urls = <String>[];
    
    // Common image URL patterns
    final patterns = [
      // Direct image URLs
      RegExp(r'https?://[^\s<>"]+\.(?:png|jpg|jpeg|gif|webp)(?:\?[^\s<>"]*)?', caseSensitive: false),
      // Markdown image syntax
      RegExp(r'!\[[^\]]*\]\((https?://[^\s)]+)\)', caseSensitive: false),
      // Common image hosting patterns
      RegExp(r'https?://(?:i\.)?imgur\.com/[^\s<>"]+', caseSensitive: false),
      RegExp(r'https?://cdn\.discordapp\.com/attachments/[^\s<>"]+', caseSensitive: false),
      RegExp(r'https?://media\.discordapp\.net/attachments/[^\s<>"]+', caseSensitive: false),
      // Base64 data URLs
      RegExp(r'data:image/[^;]+;base64,[a-zA-Z0-9+/=]+', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      for (final match in pattern.allMatches(text)) {
        final url = match.group(match.groupCount > 0 ? 1 : 0);
        if (url != null && !urls.contains(url)) {
          urls.add(url);
        }
      }
    }
    
    return urls;
  }

  /// Download image from URL
  Future<Uint8List?> downloadImage(String url) async {
    try {
      if (url.startsWith('data:image')) {
        // Handle base64 data URL
        final base64Data = url.split(',').last;
        return base64Decode(base64Data);
      }
      
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.statusCode == 200) {
        return Uint8List.fromList(response.data as List<int>);
      }
    } catch (e) {
      debugPrint('Failed to download image: $e');
    }
    return null;
  }

  /// Generate character portrait
  Future<ImageGenResult?> generatePortrait({
    required String characterName,
    required String characterDescription,
    String? style,
  }) async {
    final prompt = _buildPortraitPrompt(
      characterName,
      characterDescription,
      style,
    );

    return generate(ImageGenRequest(
      prompt: prompt,
      negativePrompt: _settings.defaultNegativePrompt ?? _defaultNegativePrompt,
      width: _settings.defaultWidth,
      height: _settings.defaultHeight,
      steps: _settings.defaultSteps,
      cfgScale: _settings.defaultCfgScale,
      sampler: _settings.defaultSampler,
      mode: ImageGenMode.character,
    ));
  }

  /// Build portrait prompt from character info
  String _buildPortraitPrompt(
    String name,
    String description,
    String? style,
  ) {
    final parts = <String>[];
    
    // Add style prefix
    if (style != null && style.isNotEmpty) {
      parts.add(style);
    } else {
      parts.add('high quality portrait');
    }

    // Add character description
    if (description.isNotEmpty) {
      parts.add(description);
    }

    // Add quality tags
    parts.add('detailed face');
    parts.add('beautiful lighting');
    parts.add('professional photography');

    return parts.join(', ');
  }

  /// Default negative prompt
  static const String _defaultNegativePrompt = 
      'low quality, blurry, distorted, deformed, ugly, bad anatomy, '
      'bad proportions, extra limbs, mutated hands, poorly drawn face, '
      'watermark, text, signature';

  /// Parse /imagine command
  ImageGenRequest? parseImagineCommand(String command) {
    // Format: /imagine <prompt> [--width N] [--height N] [--steps N] [--cfg N] [--seed N]
    if (!command.startsWith('/imagine ')) return null;

    var prompt = command.substring(9).trim();
    int width = _settings.defaultWidth;
    int height = _settings.defaultHeight;
    int steps = _settings.defaultSteps;
    double cfgScale = _settings.defaultCfgScale;
    int? seed;

    // Parse optional parameters
    final widthMatch = RegExp(r'--width\s+(\d+)').firstMatch(prompt);
    if (widthMatch != null) {
      width = int.parse(widthMatch.group(1)!);
      prompt = prompt.replaceFirst(widthMatch.group(0)!, '').trim();
    }

    final heightMatch = RegExp(r'--height\s+(\d+)').firstMatch(prompt);
    if (heightMatch != null) {
      height = int.parse(heightMatch.group(1)!);
      prompt = prompt.replaceFirst(heightMatch.group(0)!, '').trim();
    }

    final stepsMatch = RegExp(r'--steps\s+(\d+)').firstMatch(prompt);
    if (stepsMatch != null) {
      steps = int.parse(stepsMatch.group(1)!);
      prompt = prompt.replaceFirst(stepsMatch.group(0)!, '').trim();
    }

    final cfgMatch = RegExp(r'--cfg\s+([\d.]+)').firstMatch(prompt);
    if (cfgMatch != null) {
      cfgScale = double.parse(cfgMatch.group(1)!);
      prompt = prompt.replaceFirst(cfgMatch.group(0)!, '').trim();
    }

    final seedMatch = RegExp(r'--seed\s+(\d+)').firstMatch(prompt);
    if (seedMatch != null) {
      seed = int.parse(seedMatch.group(1)!);
      prompt = prompt.replaceFirst(seedMatch.group(0)!, '').trim();
    }

    if (prompt.isEmpty) return null;

    return ImageGenRequest(
      prompt: prompt,
      negativePrompt: _settings.defaultNegativePrompt,
      width: width,
      height: height,
      steps: steps,
      cfgScale: cfgScale,
      sampler: _settings.defaultSampler,
      seed: seed,
    );
  }
  
  void dispose() {
    _dio.close();
  }
}