import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// TTS Provider types
enum TTSProvider {
  system('system', 'System TTS'),
  elevenlabs('elevenlabs', 'ElevenLabs'),
  azure('azure', 'Azure Speech'),
  ;

  final String id;
  final String displayName;

  const TTSProvider(this.id, this.displayName);

  static TTSProvider? fromId(String id) {
    try {
      return TTSProvider.values.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// TTS Voice configuration
class TTSVoice {
  final String id;
  final String name;
  final String? language;
  final String? gender;
  final TTSProvider provider;

  const TTSVoice({
    required this.id,
    required this.name,
    this.language,
    this.gender,
    required this.provider,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'language': language,
        'gender': gender,
        'provider': provider.id,
      };

  factory TTSVoice.fromJson(Map<String, dynamic> json) => TTSVoice(
        id: json['id'] as String,
        name: json['name'] as String,
        language: json['language'] as String?,
        gender: json['gender'] as String?,
        provider: TTSProvider.fromId(json['provider'] as String) ?? TTSProvider.system,
      );
}

/// TTS Settings
class TTSSettings {
  final bool enabled;
  final TTSProvider provider;
  final String? voiceId;
  final double rate;
  final double pitch;
  final double volume;
  final bool autoPlay;
  final bool queueMessages;
  final String? apiKey;
  final String? apiEndpoint;

  const TTSSettings({
    this.enabled = false,
    this.provider = TTSProvider.system,
    this.voiceId,
    this.rate = 1.0,
    this.pitch = 1.0,
    this.volume = 1.0,
    this.autoPlay = false,
    this.queueMessages = true,
    this.apiKey,
    this.apiEndpoint,
  });

  TTSSettings copyWith({
    bool? enabled,
    TTSProvider? provider,
    String? voiceId,
    double? rate,
    double? pitch,
    double? volume,
    bool? autoPlay,
    bool? queueMessages,
    String? apiKey,
    String? apiEndpoint,
  }) {
    return TTSSettings(
      enabled: enabled ?? this.enabled,
      provider: provider ?? this.provider,
      voiceId: voiceId ?? this.voiceId,
      rate: rate ?? this.rate,
      pitch: pitch ?? this.pitch,
      volume: volume ?? this.volume,
      autoPlay: autoPlay ?? this.autoPlay,
      queueMessages: queueMessages ?? this.queueMessages,
      apiKey: apiKey ?? this.apiKey,
      apiEndpoint: apiEndpoint ?? this.apiEndpoint,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'provider': provider.id,
        'voiceId': voiceId,
        'rate': rate,
        'pitch': pitch,
        'volume': volume,
        'autoPlay': autoPlay,
        'queueMessages': queueMessages,
        'apiKey': apiKey,
        'apiEndpoint': apiEndpoint,
      };

  factory TTSSettings.fromJson(Map<String, dynamic> json) => TTSSettings(
        enabled: json['enabled'] as bool? ?? false,
        provider: TTSProvider.fromId(json['provider'] as String? ?? 'system') ?? TTSProvider.system,
        voiceId: json['voiceId'] as String?,
        rate: (json['rate'] as num?)?.toDouble() ?? 1.0,
        pitch: (json['pitch'] as num?)?.toDouble() ?? 1.0,
        volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
        autoPlay: json['autoPlay'] as bool? ?? false,
        queueMessages: json['queueMessages'] as bool? ?? true,
        apiKey: json['apiKey'] as String?,
        apiEndpoint: json['apiEndpoint'] as String?,
      );
}

/// Character voice settings
class CharacterVoiceSettings {
  final String characterId;
  final String? voiceId;
  final double? rate;
  final double? pitch;
  final double? volume;

  const CharacterVoiceSettings({
    required this.characterId,
    this.voiceId,
    this.rate,
    this.pitch,
    this.volume,
  });

  Map<String, dynamic> toJson() => {
        'characterId': characterId,
        'voiceId': voiceId,
        'rate': rate,
        'pitch': pitch,
        'volume': volume,
      };

  factory CharacterVoiceSettings.fromJson(Map<String, dynamic> json) => CharacterVoiceSettings(
        characterId: json['characterId'] as String,
        voiceId: json['voiceId'] as String?,
        rate: (json['rate'] as num?)?.toDouble(),
        pitch: (json['pitch'] as num?)?.toDouble(),
        volume: (json['volume'] as num?)?.toDouble(),
      );
}

/// TTS Service for text-to-speech functionality
class TTSService {
  bool _isInitialized = false;
  FlutterTts? _flutterTts;
  bool _isSpeaking = false;
  final List<String> _queue = [];
  TTSSettings _settings = const TTSSettings();
  final Map<String, CharacterVoiceSettings> _characterVoices = {};

  /// Available voices (populated after initialization)
  List<TTSVoice> _availableVoices = [];

  /// Callbacks
  VoidCallback? onStart;
  VoidCallback? onComplete;
  VoidCallback? onCancel;
  void Function(String)? onError;

  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;
  List<TTSVoice> get availableVoices => _availableVoices;
  TTSSettings get settings => _settings;

  /// Initialize the TTS service
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final tts = FlutterTts();
      _flutterTts = tts;
      await tts.setLanguage('zh-CN'); // 默认中文
      await tts.awaitSpeakCompletion(true); // speak() 等到读完再返回
      // 播放结束回调
      tts.setCompletionHandler(() {
        _isSpeaking = false;
        onComplete?.call();
      });
      tts.setCancelHandler(() {
        _isSpeaking = false;
        onCancel?.call();
      });
      tts.setErrorHandler((msg) {
        _isSpeaking = false;
        onError?.call('TTS error: $msg');
      });
      // 拉取系统真实可用语音
      await _loadSystemVoices();
      _isInitialized = true;
    } catch (e) {
      onError?.call('Failed to initialize TTS: $e');
    }
  }

  /// 从系统拉取真实可用的语音列表（替换原来的英文假数据）
  Future<void> _loadSystemVoices() async {
    try {
      final raw = await _flutterTts?.getVoices;
      if (raw is List) {
        final voices = <TTSVoice>[];
        for (final v in raw) {
          if (v is Map) {
            final name = (v['name'] ?? '').toString();
            final locale = (v['locale'] ?? '').toString();
            if (name.isEmpty) continue;
            voices.add(TTSVoice(
              id: name, // 系统 voice 用 name 作为 id
              name: locale.isNotEmpty ? '$name ($locale)' : name,
              language: locale,
              provider: TTSProvider.system,
            ));
          }
        }
        if (voices.isNotEmpty) {
          _availableVoices = voices;
          return;
        }
      }
    } catch (_) {}
    // 拉取失败兜底：至少给个默认项
    _availableVoices = _getDefaultVoices();
  }

  /// Get default system voices (placeholder)
  List<TTSVoice> _getDefaultVoices() {
    return [
      const TTSVoice(
        id: 'default',
        name: 'Default',
        language: 'en-US',
        gender: 'neutral',
        provider: TTSProvider.system,
      ),
      const TTSVoice(
        id: 'en-us-female',
        name: 'English (US) Female',
        language: 'en-US',
        gender: 'female',
        provider: TTSProvider.system,
      ),
      const TTSVoice(
        id: 'en-us-male',
        name: 'English (US) Male',
        language: 'en-US',
        gender: 'male',
        provider: TTSProvider.system,
      ),
      const TTSVoice(
        id: 'en-gb-female',
        name: 'English (UK) Female',
        language: 'en-GB',
        gender: 'female',
        provider: TTSProvider.system,
      ),
      const TTSVoice(
        id: 'en-gb-male',
        name: 'English (UK) Male',
        language: 'en-GB',
        gender: 'male',
        provider: TTSProvider.system,
      ),
    ];
  }

  /// Update settings
  void updateSettings(TTSSettings settings) {
    _settings = settings;
  }

  /// Set character voice settings
  void setCharacterVoice(CharacterVoiceSettings voiceSettings) {
    _characterVoices[voiceSettings.characterId] = voiceSettings;
  }

  /// Get character voice settings
  CharacterVoiceSettings? getCharacterVoice(String characterId) {
    return _characterVoices[characterId];
  }

  /// Speak text
  Future<void> speak(String text, {String? characterId}) async {
    if (!_isInitialized || !_settings.enabled) return;
    if (text.isEmpty) return;

    // Clean text for TTS (remove markdown, special characters, etc.)
    final cleanText = _cleanTextForTTS(text);
    if (cleanText.isEmpty) return;

    if (_settings.queueMessages) {
      _queue.add(cleanText);
      if (!_isSpeaking) {
        await _processQueue(characterId: characterId);
      }
    } else {
      await stop();
      await _speakText(cleanText, characterId: characterId);
    }
  }

  /// Process the speech queue
  Future<void> _processQueue({String? characterId}) async {
    while (_queue.isNotEmpty) {
      final text = _queue.removeAt(0);
      await _speakText(text, characterId: characterId);
    }
  }

  /// Actually speak the text
  Future<void> _speakText(String text, {String? characterId}) async {
    final tts = _flutterTts;
    if (tts == null) return;
    _isSpeaking = true;
    onStart?.call();
    try {
      final charVoice = characterId != null ? _characterVoices[characterId] : null;
      final voiceId = charVoice?.voiceId ?? _settings.voiceId;
      final rate = charVoice?.rate ?? _settings.rate;
      final pitch = charVoice?.pitch ?? _settings.pitch;
      final volume = charVoice?.volume ?? _settings.volume;

      // flutter_tts: rate 范围 0~1（0.5=正常），这里把 UI 的 0.5~2.0 映射一下
      await tts.setSpeechRate((rate / 2.0).clamp(0.0, 1.0));
      await tts.setPitch(pitch.clamp(0.5, 2.0));
      await tts.setVolume(volume.clamp(0.0, 1.0));
      if (voiceId != null && voiceId.isNotEmpty) {
        // 用选定语音（name+locale）
        final v = _availableVoices.firstWhere(
          (e) => e.id == voiceId,
          orElse: () => _availableVoices.isNotEmpty
              ? _availableVoices.first
              : const TTSVoice(id: '', name: '', provider: TTSProvider.system),
        );
        if (v.id.isNotEmpty) {
          await tts.setVoice({'name': v.id, 'locale': v.language ?? 'zh-CN'});
        }
      }
      // awaitSpeakCompletion(true) 下，这里会等到读完（或 completionHandler 触发）
      await tts.speak(text);
    } catch (e) {
      onError?.call('TTS error: $e');
    } finally {
      _isSpeaking = false;
    }
  }

  /// Stop speaking
  Future<void> stop() async {
    _queue.clear();
    await _flutterTts?.stop();
    if (_isSpeaking) {
      _isSpeaking = false;
      onCancel?.call();
    }
  }

  /// Pause speaking
  Future<void> pause() async {
    // Would pause the current speech
    debugPrint('TTS: Pause');
  }

  /// Resume speaking
  Future<void> resume() async {
    // Would resume the paused speech
    debugPrint('TTS: Resume');
  }

  /// Clean text for TTS
  String _cleanTextForTTS(String text) {
    var cleaned = text;

    // 先删整段不该读的（顺序重要：先删块，再处理行内）
    // 代码块 ```...```（跨行）
    cleaned = cleaned.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    // 生图标签 <image>...</image>（自动生图的视觉提示词，绝不能读）
    cleaned = cleaned.replaceAll(
        RegExp(r'<image>[\s\S]*?</image>', caseSensitive: false), '');
    // HTML 标签
    cleaned = cleaned.replaceAll(RegExp(r'<[^>]+>'), '');

    // 行内标记：去符号留内容 —— 必须用 replaceAllMapped，
    // replaceAll 不支持 $1 捕获组（原代码 bug：把内容替换成了字面 "$1"）
    cleaned = cleaned.replaceAllMapped(
        RegExp(r'\*\*([^*]+)\*\*'), (m) => m.group(1)!); // 粗体
    cleaned = cleaned.replaceAllMapped(
        RegExp(r'__([^_]+)__'), (m) => m.group(1)!); // 下划线
    cleaned = cleaned.replaceAllMapped(
        RegExp(r'~~([^~]+)~~'), (m) => m.group(1)!); // 删除线
    cleaned = cleaned.replaceAllMapped(
        RegExp(r'\*([^*]+)\*'), (m) => m.group(1)!); // 斜体
    cleaned = cleaned.replaceAllMapped(
        RegExp(r'`([^`]+)`'), (m) => m.group(1)!); // 行内代码
    // 链接 [文字](url) → 文字
    cleaned = cleaned.replaceAllMapped(
        RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m.group(1)!);

    // 折叠空白 + 去首尾
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned;
  }

  /// Dispose the service
  void dispose() {
    stop();
    _isInitialized = false;
  }
}