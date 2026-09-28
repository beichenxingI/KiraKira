import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

/// 裸 RGB(top-down, w×h×3, 无 padding) → PNG 字节。
/// 放 isolate 跑(compute),避免大图编码阻塞主线程。
/// Local Dream 后端返回的 raw 即此:RGB 顺序、每像素3字节、第0行为图顶。
Uint8List _rawRgbToPng((Uint8List, int, int) args) {
  final image = img.Image.fromBytes(
    width: args.$2,
    height: args.$3,
    bytes: args.$1.buffer,
    numChannels: 3,
    order: img.ChannelOrder.rgb,
  );
  return Uint8List.fromList(img.encodePng(image));
}

/// 解码 base64 图片数据,兼容各家 OpenAI 兼容接口的差异:
/// - data URI 前缀(`data:image/png;base64,`)
/// - 混入空白/换行
/// - URL-safe base64(`-`/`_`)
/// - 缺失 padding
/// 任何无法解析的情况都抛出带原因的 FormatException
Uint8List decodeBase64Image(String raw) {
  var s = raw.trim();
  if (s.isEmpty) {
    throw const FormatException('Base64 image data is empty');
  }
  // 去掉 data URI 前缀(data:image/png;base64,xxx)
  final commaIdx = s.indexOf(',');
  if (commaIdx > 0 && s.substring(0, commaIdx).toLowerCase().contains('base64')) {
    s = s.substring(commaIdx + 1).trim();
  }
  // 去掉所有空白(部分接口会在 base64 中混入换行)
  s = s.replaceAll(RegExp(r'\s'), '');
  // URL-safe base64 → 标准 base64
  s = s.replaceAll('-', '+').replaceAll('_', '/');
  // 补齐 padding
  final rem = s.length % 4;
  if (rem == 1) {
    throw FormatException('Invalid base64 image data (length ${s.length}, rem 1)');
  }
  if (rem > 1) {
    s = s.padRight(s.length + (4 - rem), '=');
  }
  try {
    return base64Decode(s);
  } on FormatException catch (e) {
    throw FormatException('Invalid base64 image data: ${e.message}');
  }
}

/// 判断响应内容是否明显不是图片(HTML 错误页 / JSON 错误体)。
/// 用于在下载 URL 后提前识别垃圾数据,避免把 HTML/JSON 当图片传给 UI
/// (UI 层会报 "Invalid image data")。
bool _looksLikeNonImageData(Uint8List bytes) {
  if (bytes.isEmpty) return true;
  // 跳过前导空白
  var i = 0;
  while (i < bytes.length &&
      (bytes[i] == 0x20 || bytes[i] == 0x09 || bytes[i] == 0x0A || bytes[i] == 0x0D)) {
    i++;
  }
  if (i >= bytes.length) return true;
  final head = utf8.decode(
    bytes.sublist(i, math.min(i + 32, bytes.length)),
    allowMalformed: true,
  ).trimLeft().toLowerCase();
  // 二进制图片格式(PNG/JPEG/GIF/WebP 等)不会以 < { [ 开头
  return head.startsWith('<') || head.startsWith('{') || head.startsWith('[');
}
/// Image Generation Provider types (channels, not models)
enum ImageGenProvider {
  // Cloud providers
  openai('openai', 'OpenAI', 'https://api.openai.com/v1'),
  openaiChat('openai_chat', 'OpenAI-Chat', 'https://api.openai.com/v1'),
  gemini('gemini', 'Gemini', 'https://generativelanguage.googleapis.com/v1beta'),
  novelai('novelai', 'NovelAI', 'https://image.novelai.net'),
  latentMoe('latent_moe', 'Latent.moe', 'https://latent.moe'),
  
  // Local SD backends
  automatic1111('automatic1111', 'Automatic1111', 'http://localhost:7860'),
  comfyui('comfyui', 'ComfyUI', 'http://127.0.0.1:8188'),

  localDream('local_dream', 'Local Dream (手机本地生图)', 'http://127.0.0.1:8081'),
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
    latentMoe,
  ].contains(this);

  bool get isLocalProvider => [
    automatic1111,
    comfyui,
    localDream,
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
      case latentMoe:
        return ''; // 站点 GPU 池固定模型,无 model 字段
      case automatic1111:
      case comfyui:
      case localDream:
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
      case latentMoe:
        return []; // 站点 GPU 池固定模型,无模型列表 API
      case automatic1111:
      case comfyui:
      case localDream:
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

  // [生图提示词自定义] 自动生图时控制 AI 提取的提示词
  final String? positivePromptPrefix; // 正面提示词前缀(拼到最终 prompt 前)
  final String? extractionInstruction; // _extractVisualTags 用:从对话正文提炼视觉标签的 LLM system 指令
  final String? imageTagInstruction; // 注入对话 system prompt,教 AI 怎么写 <image> 标签
  // [全自动生图] 额外调 LLM 优化提示词的开关 + 用哪个 API 服务(llmConfigsProvider 的 config id)
  final bool enableAutoPromptGeneration;
  final String? autoPromptConfigId;

  // [提示词优化] 独立生图 API 配置(与主生图配置完全独立)
  final String? promptOptBaseUrl;
  final String? promptOptApiKey;
  final String? promptOptModel;

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
    this.positivePromptPrefix,
    this.extractionInstruction,
    this.imageTagInstruction,
    this.enableAutoPromptGeneration = false,
    this.autoPromptConfigId,
    this.promptOptBaseUrl,
    this.promptOptApiKey,
    this.promptOptModel,
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
    String? positivePromptPrefix,
    String? extractionInstruction,
    String? imageTagInstruction,
    bool? enableAutoPromptGeneration,
    String? autoPromptConfigId,
    String? promptOptBaseUrl,
    String? promptOptApiKey,
    String? promptOptModel,
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
      positivePromptPrefix: positivePromptPrefix ?? this.positivePromptPrefix,
      extractionInstruction: extractionInstruction ?? this.extractionInstruction,
      imageTagInstruction: imageTagInstruction ?? this.imageTagInstruction,
      enableAutoPromptGeneration: enableAutoPromptGeneration ?? this.enableAutoPromptGeneration,
      autoPromptConfigId: autoPromptConfigId ?? this.autoPromptConfigId,
      promptOptBaseUrl: promptOptBaseUrl ?? this.promptOptBaseUrl,
      promptOptApiKey: promptOptApiKey ?? this.promptOptApiKey,
      promptOptModel: promptOptModel ?? this.promptOptModel,
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
    'positivePromptPrefix': positivePromptPrefix,
    'extractionInstruction': extractionInstruction,
    'imageTagInstruction': imageTagInstruction,
    'enableAutoPromptGeneration': enableAutoPromptGeneration,
    'autoPromptConfigId': autoPromptConfigId,
    'promptOptBaseUrl': promptOptBaseUrl,
    'promptOptApiKey': promptOptApiKey,
    'promptOptModel': promptOptModel,
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
      positivePromptPrefix: json['positivePromptPrefix'] as String?,
      extractionInstruction: json['extractionInstruction'] as String? ?? json['imagePromptInstruction'] as String?,
      imageTagInstruction: json['imageTagInstruction'] as String?,
      enableAutoPromptGeneration: json['enableAutoPromptGeneration'] as bool? ?? false,
      autoPromptConfigId: json['autoPromptConfigId'] as String?,
      promptOptBaseUrl: json['promptOptBaseUrl'] as String?,
      promptOptApiKey: json['promptOptApiKey'] as String?,
      promptOptModel: json['promptOptModel'] as String?,
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
    
    final response = await _dio.get<dynamic>(
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
    
    // [云端修复] 兼容 Map 和 List 两种响应格式(反代可能返回不同结构)
    final data = response.data;
    final List<dynamic> modelList;
    if (data is Map<String, dynamic>) {
      modelList = data['data'] as List? ?? [];
    } else if (data is List) {
      modelList = data;
    } else {
      debugPrint('OpenAI: Unexpected response type ${data.runtimeType}');
      return _settings.provider.defaultModels;
    }
    debugPrint('OpenAI: Found ${modelList.length} total models');
    
    final models = <String>[];
    for (final model in modelList) {
      final id = model is Map<String, dynamic> ? model['id'] as String? : null;
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
    
    final response = await _dio.get<dynamic>(
      '$endpoint/models?key=$apiKey',
    );
    
    debugPrint('Gemini: Response status ${response.statusCode}');
    
    if (response.statusCode != 200 || response.data == null) {
      debugPrint('Gemini: Failed to fetch, returning default models');
      return _settings.provider.defaultModels;
    }
    
    // [云端修复] 兼容 Map 和 List 两种响应格式
    final data = response.data;
    final List<dynamic> modelList;
    if (data is Map<String, dynamic>) {
      modelList = data['models'] as List? ?? [];
    } else if (data is List) {
      modelList = data;
    } else {
      debugPrint('Gemini: Unexpected response type ${data.runtimeType}');
      return _settings.provider.defaultModels;
    }
    debugPrint('Gemini: Found ${modelList.length} total models');
    
    final models = <String>[];
    for (final model in modelList) {
      final name = model is Map<String, dynamic> ? model['name'] as String? : null;
      // Model name format: models/gemini-xxx
      if (name != null) {
        final modelId = name.replaceFirst('models/', '');
        
        if (
            (modelId.contains('image') || 
             modelId.contains('banana') ||
             modelId.contains('flash-image') ||
             modelId.contains('pro-image'))) {
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
          images.add(decodeBase64Image(b64));
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
            images.add(decodeBase64Image(base64Data));
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
    final apiKey = _settings.apiKey;

    debugPrint('[IMAGE_GEN] provider=${_settings.provider.id}');
    debugPrint('[IMAGE_GEN] apiKey=${(apiKey == null || apiKey.isEmpty) ? "" : "非空(${apiKey.length}字符)"}');
    debugPrint('[IMAGE_GEN] endpoint=${_settings.effectiveEndpoint}');

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
        case ImageGenProvider.latentMoe:
          debugPrint('[IMAGE_GEN] 进入latent.moe分支');
          return await _generateLatentMoe(request);
        case ImageGenProvider.automatic1111:
          return await _generateAutomatic1111(request);
        case ImageGenProvider.comfyui:
          return await _generateComfyUI(request);
        case ImageGenProvider.localDream:
          return await _generateLocalDream(request);
      }
    } catch (e, stack) {
      debugPrint('Image generation error: $e\n$stack');
      debugPrint('  Provider: ${_settings.provider.id} (${_settings.provider.displayName})');
      debugPrint('  Base URL: ${_settings.effectiveEndpoint}');
      debugPrint('  Model: $model');
      final msg = e.toString();
      if (msg.contains('Invalid image data')) {
        onError?.call('图片格式不兼容,请检查API是否支持OpenAI格式');
      } else {
        onError?.call('Image generation error: $e');
      }
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

    // OpenAI 兼容接口的 data 字段格式不统一:
    // - 标准格式: data: [{url: ...} 或 {b64_json: ...}]
    // - 某些兼容接口直接返回 data: "<base64 字符串>"
    final rawData = data['data'];
    final List<dynamic> dataList;
    if (rawData is List) {
      dataList = rawData;
    } else if (rawData is String && rawData.isNotEmpty) {
      debugPrint('OpenAI: data is a raw string, treating as base64 image');
      dataList = [{'b64_json': rawData}];
    } else {
      dataList = [];
    }

    if (dataList.isEmpty) {
      throw Exception(
        'No image data in response. Response keys: ${data.keys.join(", ")}',
      );
    }

    for (var i = 0; i < dataList.length; i++) {
      final item = dataList[i];
      if (item is! Map) continue;

      final b64 = item['b64_json'];
      final url = item['url'];

      // 优先 Base64 (格式B: Agens、部分自建服务)
      if (b64 is String && b64.isNotEmpty) {
        try {
          images.add(decodeBase64Image(b64));
          debugPrint('OpenAI: item[$i] decoded from b64_json');
          continue;
        } catch (e) {
          debugPrint('OpenAI: item[$i] b64_json decode failed: $e');
        }
      }

      // Base64 缺失或解码失败时尝试 URL (格式A: GPT官方、OpenRouter)
      if (url is String && url.isNotEmpty) {
        debugPrint('OpenAI: item[$i] downloading image from URL: $url');
        final imgData = await downloadImage(url);
        if (imgData == null) {
          throw Exception('Failed to download image from URL: $url');
        }
        images.add(imgData);
        continue;
      }

      // 未知格式
      throw Exception(
        'Unsupported image format at data[$i]. Available keys: ${item.keys.join(", ")}',
      );
    }

    // Fallback: try to extract images from the raw response
    if (images.isEmpty) {
      debugPrint('OpenAI: No images in standard format, trying fallback extraction...');
      final fallbackImages = await _extractImagesFromResponse(data, debugPrefix: 'OpenAI: ');
      images.addAll(fallbackImages);
    }

    // 兜底失败时给出清晰错误(而不是返回空结果让 UI 报 Invalid image data)
    if (images.isEmpty) {
      final firstItem = dataList.first;
      final itemKeys = firstItem is Map<String, dynamic> ? firstItem.keys.join(', ') : 'unknown';
      throw Exception(
        'No usable image data in response. Response keys: ${data.keys.join(", ")}, data[0] keys: $itemKeys',
      );
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
                  try {
                    images.add(decodeBase64Image(b64));
                    debugPrint('OpenAI-Chat: Found inline base64 image');
                  } catch (e) {
                    debugPrint('OpenAI-Chat: inline base64 decode failed: $e');
                  }
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
            images.add(decodeBase64Image(base64Data));
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
              images.add(decodeBase64Image(imgData));
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

  /// Generate image using Latent.moe (异步队列生图)
  /// 协议(方案C,独立实现,与 NovelAI 同步 ZIP 完全不同):
  /// 1. POST /api/generate → 202 + GenerationJob(id)
  /// 2. 每 2s 轮询 GET /api/generate/{id} 直到 succeeded/failed/cancelled
  /// 3. succeeded → GET /api/media/{artworkId}?size=original 拉图片字节
  /// 限制: resolution 三档枚举(square 1024²/portrait 920×1536/landscape 1536×920),
  /// steps 8-12, 无 model/CFG 字段, 每周额度 + GENERATION_CONCURRENCY 并发。
  /// 文档: https://latent.moe/docs/api + /openapi.json
  Future<ImageGenResult?> _generateLatentMoe(ImageGenRequest request) async {
    final apiKey = _settings.apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Latent.moe API key is required (lat_sk_...)');
    }

    // 规范化 base URL：去尾部斜杠 + 移除用户可能误填的路径后缀
    // (如 /api/novelai、/api/generate、/api —— 拼接时变成 {base}/api/generate 导致 404)
    final rawEndpoint = _settings.effectiveEndpoint;
    var baseUrl = rawEndpoint.trim().isNotEmpty ? rawEndpoint.trim() : 'https://latent.moe';
    baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
    baseUrl = baseUrl
        .replaceAll(RegExp(r'/api/novelai$'), '')
        .replaceAll(RegExp(r'/api/generate$'), '')
        .replaceAll(RegExp(r'/api$'), '');
    final endpoint = baseUrl;
    debugPrint('[LATENT] 规范化后Base URL=$baseUrl');

    debugPrint('[LATENT] 开始生成 provider=${_settings.provider.id}');
    debugPrint('[LATENT] API Key长度=${apiKey.length}');
    debugPrint('[LATENT] Base URL=$endpoint');

    // 参数映射(文档枚举):
    // 宽高比 → resolution: ≈1 → square, <1 → portrait, >1 → landscape
    final ratio = request.width / request.height;
    final resolution = ratio > 1.25
        ? 'landscape'
        : ratio < 0.8
            ? 'portrait'
            : 'square';
    // steps clamp 8-12(文档限制)
    final steps = request.steps < 8 ? 8 : (request.steps > 12 ? 12 : request.steps);
    // sampler 映射: 枚举 euler/res_multistep/er_sde,不在枚举内用默认 euler
    const latentSamplers = {'euler', 'res_multistep', 'er_sde'};
    final sampler =
        latentSamplers.contains(request.sampler) ? request.sampler : 'euler';
    // scheduler 映射: 枚举 sgm_uniform/beta/beta57/linear_quadratic,默认 sgm_uniform
    const latentSchedulers = {'sgm_uniform', 'beta', 'beta57', 'linear_quadratic'};
    final scheduler = latentSchedulers.contains(_settings.defaultScheduler)
        ? _settings.defaultScheduler
        : 'sgm_uniform';

    final body = <String, dynamic>{
      'prompt': request.prompt,
      'resolution': resolution,
      'steps': steps,
      'sampler': sampler,
      'scheduler': scheduler,
      // negativePrompt 省略时不发送负面且站点默认不应用 → 用户配了默认负面就带上
      if ((request.negativePrompt ?? _settings.defaultNegativePrompt)
              ?.trim()
              .isNotEmpty ==
          true)
        'negativePrompt': request.negativePrompt ?? _settings.defaultNegativePrompt,
      if (request.seed != null) 'seed': request.seed,
    };

    onProgress?.call(0.1);
    debugPrint('[LATENT] POST $endpoint/api/generate');
    debugPrint('[LATENT] 请求体(映射后)：resolution=$resolution steps=$steps sampler=$sampler scheduler=$scheduler');
    debugPrint('[LATENT] ${const JsonEncoder.withIndent('  ').convert(body)}');

    // [LATENT] 主流程:提交 → 轮询 → 拉图,异常日志后 rethrow(由 generate() 统一 onError)
    try {
      // 1. 提交任务(202 + GenerationJob; 401/409/422/429/503 友好报错)
      debugPrint('[LATENT] 提交任务：prompt=${request.prompt.length > 50 ? request.prompt.substring(0, 50) : request.prompt}...');
      final submit = await _dio.post<dynamic>(
        '$endpoint/api/generate',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.json, // 明确期望JSON
          validateStatus: (status) => true, // 允许非202，手动处理
        ),
        data: body,
      );
      debugPrint('[LATENT] 提交响应：status=${submit.statusCode}, body=${submit.data}');

      if (submit.statusCode != 202 || submit.data == null) {
        throw Exception(_latentError('Latent.moe', submit.statusCode, submit.data));
      }
      // [类型检查] 404/HTML 错误页时 data 是 String,直接取 ['id'] 会炸出难懂 TypeError
      final taskData = submit.data;
      if (taskData is! Map) {
        throw Exception(
            'Latent.moe 提交响应格式错误：期望JSON对象，收到${taskData.runtimeType}');
      }
      final jobId = taskData['id'] as String?;
      if (jobId == null || jobId.isEmpty) {
        throw Exception('Latent.moe: 提交成功但未返回任务 id');
      }
      debugPrint('[LATENT] 任务已入队：任务ID=$jobId');

      // 2. 轮询(官方建议 2s 一次; 超时 10 分钟保护,超时尝试取消避免占并发名额)
      const pollInterval = Duration(seconds: 2);
      const pollTimeout = Duration(minutes: 10);
      final deadline = DateTime.now().add(pollTimeout);
      Map<String, dynamic> job = Map<String, dynamic>.from(taskData);
      int pollN = 0;
      while (DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(pollInterval);
        pollN++;
        debugPrint('[LATENT] 轮询第$pollN次，任务ID=$jobId');
        final poll = await _dio.get<dynamic>(
          '$endpoint/api/generate/$jobId',
          options: Options(
            headers: {'Authorization': 'Bearer $apiKey'},
            responseType: ResponseType.json,
            validateStatus: (status) => true,
          ),
        );
        debugPrint('[LATENT] 状态：status=${poll.statusCode}, body=${poll.data}');
        if (poll.statusCode != 200 || poll.data == null) {
          // 404 = 任务不属于此 designer;其他非 200 视为暂时故障,重试
          if (poll.statusCode == 404) {
            throw Exception('Latent.moe: 任务不存在或已被清理(404)');
          }
          debugPrint('[LATENT] 轮询 HTTP ${poll.statusCode}, 重试');
          continue;
        }
        // [类型检查] 200 但非 JSON(代理/网关返回 HTML) → 视为暂时故障重试
        if (poll.data is! Map) {
          debugPrint('[LATENT] 轮询响应非JSON对象(${poll.data.runtimeType}), 重试');
          continue;
        }
        job = Map<String, dynamic>.from(poll.data as Map);
        final status = job['status'] as String?;
        final progress = (job['progress'] as num?)?.toInt() ?? 0;
        // progress 0-100 映射到 0.2-0.9 进度回调
        if (status == 'running') {
          onProgress?.call(0.3 + (progress / 100.0) * 0.6);
        } else if (status == 'queued' || status == 'leased') {
          onProgress?.call(0.2);
        }
        if (status == 'succeeded') break;
        if (status == 'failed') {
          throw Exception(
              'Latent.moe: 生成失败 (errorCode: ${job['errorCode'] ?? 'unknown'})');
        }
        if (status == 'cancelled') {
          throw Exception('Latent.moe: 任务已取消');
        }
      }
      if ((job['status'] as String?) != 'succeeded') {
        try {
          await _dio.post('$endpoint/api/generate/$jobId/cancel',
              options: Options(headers: {'Authorization': 'Bearer $apiKey'}));
        } catch (_) {}
        throw Exception('Latent.moe: 轮询超时(10分钟),任务已尝试取消');
      }

      final artworkId = job['artworkId'] as String?;
      if (artworkId == null || artworkId.isEmpty) {
        throw Exception('Latent.moe: 任务成功但未返回 artworkId');
      }

      // 3. 拉取图片字节(文档: /api/media/{artworkId}?size=original;size 枚举 thumb/preview/original)
      debugPrint('[LATENT] 下载图片：artworkId=$artworkId');
      onProgress?.call(0.95);
      final media = await _dio.get<List<int>>(
        '$endpoint/api/media/$artworkId?size=original',
        options: Options(
          headers: {'Authorization': 'Bearer $apiKey'},
          responseType: ResponseType.bytes,
          validateStatus: (status) => true,
        ),
      );
      if (media.statusCode != 200 || media.data == null) {
        throw Exception(_latentError('Latent.moe media', media.statusCode, media.data));
      }
      final bytes = Uint8List.fromList(media.data as List<int>);
      debugPrint('[LATENT] 图片大小=${bytes.length} bytes');
      if (_looksLikeNonImageData(bytes)) {
        throw Exception('Latent.moe: media 返回非图片内容');
      }

      onProgress?.call(1.0);
      final seed =
          (job['seed'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
      return ImageGenResult(
        images: [bytes],
        prompt: request.prompt,
        seed: seed,
        format: 'png',
        metadata: {
          'provider': 'latent_moe',
          'jobId': jobId,
          'artworkId': artworkId,
          'resolution': job['resolution'],
          'sampler': job['sampler'],
          'scheduler': job['scheduler'],
        },
      );
    } catch (e, stack) {
      debugPrint('[LATENT] ❌ 异常：$e');
      debugPrint('[LATENT] Stack: $stack');
      rethrow;
    }
  }

  /// latent.moe 错误体解析(结构: {error:{code,message}} 或 {error:string,message};
  /// 状态码语义: 401 key 无效/409 并发满/422 参数越界/429 周额度/503 队列满;
  /// HTML 错误页 → 明确提示 Base URL 填写错误)
  String _latentError(String prefix, int? statusCode, dynamic data) {
    // [Fix 3] HTML 错误页(很可能是 Base URL 误填路径,拼出 404) → 明确指引
    if (data is String && data.trim().toLowerCase().startsWith('<')) {
      final body = data.trim();
      final excerpt = body.length > 200 ? '${body.substring(0, 200)}...' : body;
      return '$prefix: 收到HTML响应而非JSON (HTTP ${statusCode ?? '??'})。\n'
          '可能原因：Base URL 填写错误（应填 https://latent.moe，不含路径）或服务端问题。\n'
          '原始响应：$excerpt';
    }
    String detail = '';
    if (data is Map) {
      final err = data['error'];
      if (err is Map) {
        detail = '${err['code'] ?? ''} ${err['message'] ?? ''}'.trim();
      } else if (err is String) {
        detail = err;
      }
    } else if (data is List) {
      try {
        detail = utf8.decode(data as List<int>);
      } catch (_) {}
    } else if (data is String) {
      detail = data;
    }
    final hint = switch (statusCode) {
      401 => 'API key 无效或已撤销',
      409 => '并发任务已满(too_many_active),请稍后再试',
      422 => '参数越界,请检查设置',
      429 => '本周生图额度已用完(quota_exhausted)',
      503 => '队列已满(queue_full),请稍后再试',
      _ => '',
    };
    return '$prefix error: ${statusCode ?? '??'}'
        '${hint.isNotEmpty ? ' - $hint' : ''}'
        '${detail.isNotEmpty ? ' ($detail)' : ''}';
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

  /// Generate image using Local Dream (local NPU/CPU SD engine)
  /// 通信: HTTP 127.0.0.1:8081, POST /generate, 行流式 JSON(NDJSON,非SSE)
  /// 响应逐行: {type:progress,progress:0~1} / {type:complete,image,width,height,seed,format} / {type:error,message}
  /// 参考: localdream-flutter background_generation_service._generateViaLocalBackend
  Future<ImageGenResult?> _generateLocalDream(ImageGenRequest request) async {
    final rawEndpoint = _settings.effectiveEndpoint;
    // 去掉尾部斜杠,避免拼成 //generate 导致 404
    final endpoint = rawEndpoint.endsWith('/')
        ? rawEndpoint.substring(0, rawEndpoint.length - 1)
        : rawEndpoint;

    // 健康检查：能连上即视为在线。后端根路径 / 不返回 200(只有 /generate、
    // /tokenize),所以不校验状态码，只要不是连接层失败(拒绝/超时)就算在线。
    onProgress?.call(0.02);
    try {
      await _dio.get(
        '$endpoint/',
        options: Options(
          validateStatus: (_) => true, // 任何状态码都算"连上了"
          receiveTimeout: const Duration(seconds: 3),
          sendTimeout: const Duration(seconds: 3),
        ),
      );
      // 走到这里 = 拿到了 HTTP 响应(哪怕 404/405)= 服务在监听
    } on DioException catch (e) {
      // 只有连接被拒/超时才是真离线
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        throw Exception('Local Dream 服务离线，请先在 Local Dream 中加载模型。');
      }
      // 其他 DioException(收到了响应但异常)视为在线,继续
    }

    // 构造请求体（照 Local Dream 作者 _generateViaLocalBackend 的 body 字段）
    final body = <String, dynamic>{
      'prompt': request.prompt,
      'negative_prompt':
          request.negativePrompt ?? _settings.defaultNegativePrompt ?? '',
      'width': request.width,
      'height': request.height,
      'steps': request.steps,
      'cfg': request.cfgScale,
      'scheduler': request.sampler,
      if (request.seed != null) 'seed': request.seed,
    };

    // 用 HttpClient 做行流式（作者亲注：Dio 不支持逐行流）
    final client = HttpClient();
    Uint8List? resultBytes;
    int resultWidth = request.width;
    int resultHeight = request.height;
    int? resultSeed;
    String resultFormat = 'raw';

    try {
      final uri = Uri.parse('$endpoint/generate');
      final httpReq = await client.postUrl(uri);
      httpReq.headers.contentType = ContentType.json;
      httpReq.write(jsonEncode(body));
      final response = await httpReq.close();

      if (response.statusCode != 200) {
        throw Exception('Local Dream 返回 HTTP ${response.statusCode}');
      }

      await for (final line in response
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        // SSE 格式:每个事件含 "event: xxx" 行 + "data: {json}" 行 + 空行。
        // 只处理 data: 行,剥前缀后解析 JSON。
        if (!line.startsWith('data:')) continue;
        final jsonStr = line.substring(5).trim();
        if (jsonStr.isEmpty) continue;
        Map<String, dynamic> msg;
        try {
          msg = jsonDecode(jsonStr) as Map<String, dynamic>;
        } on FormatException {
          continue; // 跳过无法解析的行
        }
        final type = msg['type'] as String?;
        switch (type) {
          case 'progress':
            final step = (msg['step'] as num?)?.toDouble() ?? 0.0;
            final total = (msg['total_steps'] as num?)?.toDouble() ?? 0.0;
            if (total > 0) onProgress?.call((step / total).clamp(0.0, 1.0));
            break;
          case 'complete':
            final b64 = msg['image'] as String? ?? '';
            if (b64.isEmpty) throw Exception('Local Dream 未返回图片数据');
            resultBytes = base64Decode(b64);
            resultWidth = (msg['width'] as num?)?.toInt() ?? request.width;
            resultHeight = (msg['height'] as num?)?.toInt() ?? request.height;
            resultSeed = (msg['seed'] as num?)?.toInt();
            // 官方 complete 事件:image 是裸 RGB,channels=3,无 format 字段。
            // 保持 'raw',交给阶段IV转 PNG。
            resultFormat = 'raw';
            break;
          case 'error':
            throw Exception(
                (msg['message'] as String?) ?? 'Local Dream 生成错误');
        }
      }
    } finally {
      client.close();
    }

    if (resultBytes == null) {
      throw Exception('Local Dream 未返回完整结果');
    }

    // 阶段IV: raw(RGB,top-down,w×h×3,无padding)→ PNG,isolate编码防卡顿
    if (resultFormat == 'raw') {
      resultBytes = await compute(
        _rawRgbToPng,
        (resultBytes, resultWidth, resultHeight),
      );
      resultFormat = 'png';
    }

    onProgress?.call(1.0);
    return ImageGenResult(
      images: [resultBytes],
      prompt: request.prompt,
      seed: resultSeed ?? DateTime.now().millisecondsSinceEpoch,
      format: resultFormat,
      metadata: {'provider': 'local_dream', 'raw_format': resultFormat},
    );
  }

  /// ComfyUI 文生图（SD1.5/SDXL 通用）
  /// 流程：构建 workflow → POST /prompt → 轮询 /history/{prompt_id} → GET /view 拉图
  /// 提示词约定：与 A1111/Local Dream 后端一致，Service 内不重复拼接
  /// （positivePromptPrefix 已由调用方拼进 request.prompt，negative 用 request 或默认值）
  Future<ImageGenResult?> _generateComfyUI(ImageGenRequest request) async {
    final endpoint = _settings.apiEndpoints['comfyui']?.trim();
    if (endpoint == null || endpoint.isEmpty) {
      throw Exception('ComfyUI endpoint 未配置');
    }

    // 1. 提示词（遵循现有约定：前缀已由调用方拼好，Service 内原样使用）
    final finalPrompt = request.prompt;
    final finalNegative =
        request.negativePrompt ?? _settings.defaultNegativePrompt ?? '';

    // 2. 模型名（优先 request.model，否则用设置的默认）
    final model = request.model ??
        _settings.models['comfyui'] ??
        'v1-5-pruned-emaonly.safetensors';

    // 3. 采样器名映射（A1111 → ComfyUI）
    final samplerName = _mapComfyUISampler(request.sampler);

    // 4. 随机 seed（防止 ComfyUI 部分图缓存：相同 workflow+seed 第二次直接返回缓存）
    final seed = request.seed ?? DateTime.now().millisecondsSinceEpoch;

    // 5. 构建 workflow JSON（SD1.5/SDXL 通用 6 节点模板）
    final workflow = _buildComfyUITxt2ImgWorkflow(
      prompt: finalPrompt,
      negativePrompt: finalNegative,
      width: request.width,
      height: request.height,
      steps: request.steps,
      cfg: request.cfgScale,
      samplerName: samplerName,
      scheduler: request.scheduler ?? _settings.defaultScheduler,
      seed: seed,
      model: model,
    );

    // 6. 生成 client_id（WebSocket 订阅用，本阶段占位）
    final clientId = 'kira-${const Uuid().v4()}';

    onProgress?.call(0.1);
    debugPrint('[ComfyUI] POST $endpoint/prompt');
    debugPrint('[ComfyUI] model=$model sampler=$samplerName '
        'size=${request.width}x${request.height} steps=${request.steps}');

    // 7. 提交任务（validateStatus 手动处理，400 时解析 node_errors）
    try {
      final response = await _dio.post<dynamic>(
        '$endpoint/prompt',
        data: {
          'prompt': workflow,
          'client_id': clientId,
        },
        options: Options(
          validateStatus: (_) => true, // 手动处理错误
        ),
      );
      debugPrint('[ComfyUI] 提交响应：status=${response.statusCode}');

      if (response.statusCode != 200) {
        final error = response.data;
        if (error is Map && error.containsKey('node_errors')) {
          // [类型检查] node_errors 可能为空 Map（如 no_prompt），.first 会抛 StateError
          final nodeErrors = error['node_errors'] as Map? ?? {};
          if (nodeErrors.isNotEmpty) {
            final firstError = nodeErrors.values.first;
            if (firstError is Map) {
              final errors = firstError['errors'];
              throw Exception(
                  'ComfyUI workflow 错误: ${errors is List && errors.isNotEmpty ? errors.first : firstError}');
            }
            throw Exception('ComfyUI workflow 错误: $firstError');
          }
        }
        throw Exception('ComfyUI 提交失败: ${response.statusCode} ${response.data}');
      }

      // [类型检查] 非 JSON 响应（代理/网关返回 HTML）时 data 是 String
      final submitData = response.data;
      if (submitData is! Map) {
        throw Exception(
            'ComfyUI 提交响应格式错误：期望JSON对象，收到${submitData.runtimeType}');
      }
      final promptId = submitData['prompt_id'] as String?;
      if (promptId == null || promptId.isEmpty) {
        throw Exception('ComfyUI: 提交成功但未返回 prompt_id');
      }
      debugPrint('[ComfyUI] 任务已提交: prompt_id=$promptId');

      // 8. 轮询任务完成（参考 _generateLatentMoe 的轮询循环）
      // ⚠️ history 只在任务执行完成后才写入记录：排队/运行中查询返回 {}（空对象）
      final startTime = DateTime.now();
      const maxWaitMinutes = 10;
      const pollInterval = Duration(seconds: 2);

      Map<String, dynamic>? result;
      while (true) {
        // 超时检查
        if (DateTime.now().difference(startTime).inMinutes >= maxWaitMinutes) {
          throw Exception('ComfyUI 生成超时（$maxWaitMinutes分钟）');
        }

        await Future<void>.delayed(pollInterval);

        // 查询 history
        final historyResp = await _dio.get<dynamic>(
          '$endpoint/history/$promptId',
          options: Options(validateStatus: (_) => true),
        );

        if (historyResp.statusCode != 200) {
          throw Exception('ComfyUI 查询状态失败: ${historyResp.statusCode}');
        }

        // [类型检查] 非 JSON 响应视为暂时故障，重试
        if (historyResp.data is! Map) {
          debugPrint(
              '[ComfyUI] history 响应非JSON(${historyResp.data.runtimeType}), 重试');
          continue;
        }
        final history = historyResp.data as Map<String, dynamic>;

        // history 为空 = 还在队列/执行中 → 更新进度回调后继续轮询
        if (!history.containsKey(promptId)) {
          final progress = 0.2 +
              (DateTime.now().difference(startTime).inSeconds /
                  (maxWaitMinutes * 60)) *
                  0.7;
          onProgress?.call(progress.clamp(0.2, 0.9));
          continue;
        }

        // 任务完成
        result = history[promptId] as Map<String, dynamic>;
        final status = result['status'] as Map<String, dynamic>?;

        if (status?['status_str'] != 'success') {
          final messages = status?['messages'] as List? ?? [];
          throw Exception('ComfyUI 生成失败: ${messages.join(', ')}');
        }
        break;
      }

      // 9. 提取图片信息（遍历所有节点输出，找第一个有 images 的）
      final outputs = result['outputs'] as Map<String, dynamic>? ?? {};
      String? filename;
      String subfolder = '';
      String type = 'output';

      for (final output in outputs.values) {
        if (output is Map && output.containsKey('images')) {
          final images = output['images'] as List?;
          if (images != null && images.isNotEmpty) {
            final img = images.first as Map<String, dynamic>;
            filename = img['filename'] as String?;
            subfolder = img['subfolder'] as String? ?? '';
            type = img['type'] as String? ?? 'output';
            break;
          }
        }
      }

      if (filename == null) {
        throw Exception('ComfyUI 返回结果中未找到图片');
      }

      debugPrint('[ComfyUI] 图片文件: $filename');

      // 10. 下载图片（GET /view?filename=&subfolder=&type=）
      onProgress?.call(0.95);
      final imageUrl =
          '$endpoint/view?filename=$filename&subfolder=$subfolder&type=$type';
      final imageResp = await _dio.get<List<int>>(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      if (imageResp.statusCode != 200 || imageResp.data == null) {
        throw Exception('ComfyUI 下载图片失败: ${imageResp.statusCode}');
      }

      final imageBytes = Uint8List.fromList(imageResp.data!);
      if (_looksLikeNonImageData(imageBytes)) {
        throw Exception('ComfyUI: /view 返回非图片内容');
      }
      onProgress?.call(1.0);

      debugPrint('[ComfyUI] 生成成功: ${imageBytes.length} bytes');

      return ImageGenResult(
        images: [imageBytes],
        imageUrls: [imageUrl],
        prompt: finalPrompt,
        seed: seed,
        format: 'png',
        metadata: {
          'provider': 'comfyui',
          'prompt_id': promptId,
          'model': model,
          'sampler': samplerName,
          'steps': request.steps,
          'cfg': request.cfgScale,
        },
      );
    } catch (e, stack) {
      debugPrint('[ComfyUI] ❌ 异常：$e');
      debugPrint('[ComfyUI] Stack: $stack');
      rethrow;
    }
  }

  /// 构建 ComfyUI txt2img workflow（SD1.5/SDXL 通用 6 节点模板）
  /// CheckpointLoaderSimple 输出 [MODEL(0), CLIP(1), VAE(2)]；
  /// 连接方式 ["node_id", output_index]
  Map<String, dynamic> _buildComfyUITxt2ImgWorkflow({
    required String prompt,
    required String negativePrompt,
    required int width,
    required int height,
    required int steps,
    required double cfg,
    required String samplerName,
    required String scheduler,
    required int seed,
    required String model,
  }) {
    return {
      '3': {
        'class_type': 'KSampler',
        'inputs': {
          'seed': seed,
          'steps': steps,
          'cfg': cfg,
          'sampler_name': samplerName,
          'scheduler': scheduler,
          'denoise': 1.0,
          'model': ['4', 0],
          'positive': ['6', 0],
          'negative': ['7', 0],
          'latent_image': ['5', 0],
        },
      },
      '4': {
        'class_type': 'CheckpointLoaderSimple',
        'inputs': {'ckpt_name': model},
      },
      '5': {
        'class_type': 'EmptyLatentImage',
        'inputs': {
          'width': width,
          'height': height,
          'batch_size': 1,
        },
      },
      '6': {
        'class_type': 'CLIPTextEncode',
        'inputs': {
          'text': prompt,
          'clip': ['4', 1],
        },
      },
      '7': {
        'class_type': 'CLIPTextEncode',
        'inputs': {
          'text': negativePrompt,
          'clip': ['4', 1],
        },
      },
      '8': {
        'class_type': 'VAEDecode',
        'inputs': {
          'samples': ['3', 0],
          'vae': ['4', 2],
        },
      },
      '9': {
        'class_type': 'SaveImage',
        'inputs': {
          'filename_prefix': 'kira',
          'images': ['8', 0],
        },
      },
    };
  }

  /// A1111 采样器名 → ComfyUI 采样器名映射
  /// （ComfyUI SAMPLER_NAMES 见 comfy/samplers.py:971-975+1356）
  String _mapComfyUISampler(String a1111Sampler) {
    const mapping = {
      'euler': 'euler',
      'euler_a': 'euler_ancestral',
      'heun': 'heun',
      'dpm_2': 'dpm_2',
      'dpm_2_a': 'dpm_2_ancestral',
      'lms': 'lms',
      'dpm_fast': 'dpm_fast',
      'dpm_adaptive': 'dpm_adaptive',
      'dpmpp_2s_a': 'dpmpp_2s_ancestral',
      'dpmpp_sde': 'dpmpp_sde',
      'dpmpp_2m': 'dpmpp_2m',
      'ddim': 'ddim',
      'plms': 'dpmpp_2m', // PLMS 在 ComfyUI 不存在，映射到 dpmpp_2m
      'uni_pc': 'uni_pc',
      // NovelAI k_ 前缀系列
      'k_euler': 'euler',
      'k_euler_a': 'euler_ancestral',
      'k_euler_ancestral': 'euler_ancestral',
    };

    return mapping[a1111Sampler] ?? 'euler'; // 默认 euler
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
  /// 兼容:
  /// - data URI (`data:image/...;base64,...`)
  /// - 普通 URL (2xx, 带重定向)
  /// 下载内容若为 HTML/JSON 错误页,记录日志并返回 null(避免把垃圾数据当图片)
  Future<Uint8List?> downloadImage(String url) async {
    try {
      if (url.startsWith('data:')) {
        // Handle base64 data URL
        return decodeBase64Image(url);
      }

      final response = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': 'image/*,*/*',
          },
        ),
      );
      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        final bytes = Uint8List.fromList(response.data as List<int>);
        if (_looksLikeNonImageData(bytes)) {
          final head = utf8.decode(
            bytes.sublist(0, math.min(120, bytes.length)),
            allowMalformed: true,
          );
          debugPrint('downloadImage: non-image content from $url '
              '(${bytes.length} bytes), head: $head');
          return null;
        }
        return bytes;
      }
      debugPrint('downloadImage: HTTP ${response.statusCode} for $url');
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