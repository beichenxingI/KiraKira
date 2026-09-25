import 'package:flutter/foundation.dart';
import 'tts_backends/tts_backend.dart';
import 'tts_backends/flutter_tts_backend.dart';
import 'tts_backends/sherpa_onnx_backend.dart';
import 'tts_backends/mimo_tts_backend.dart';
import 'tts_backends/qwen_tts_backend.dart';
import 'tts_backends/baidu_tts_backend.dart';

/// TTS Provider types
enum TTSProvider {
  system('system', '系统 TTS'),
  sherpaOnnx('sherpaOnnx', '本地离线 TTS'),
  mimoTts('mimoTts', '小米 MiMo'),
  qwenTts('qwenTts', '阿里通义 TTS'),
  baiduTts('baiduTts', '百度语音合成'),
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
/// 单个声音的配置（正文/对话/旁白各一份）
class VoiceStyle {
  final bool enabled;   // 该类文本是否朗读
  final String? voiceId;
  final double rate;
  final double pitch;

  const VoiceStyle({
    this.enabled = true,
    this.voiceId,
    this.rate = 1.0,
    this.pitch = 1.0,
  });

  VoiceStyle copyWith({
    bool? enabled,
    String? voiceId,
    double? rate,
    double? pitch,
  }) =>
      VoiceStyle(
        enabled: enabled ?? this.enabled,
        voiceId: voiceId ?? this.voiceId,
        rate: rate ?? this.rate,
        pitch: pitch ?? this.pitch,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'voiceId': voiceId,
        'rate': rate,
        'pitch': pitch,
      };

  factory VoiceStyle.fromJson(Map<String, dynamic> json) => VoiceStyle(
        enabled: json['enabled'] as bool? ?? true,
        voiceId: json['voiceId'] as String?,
        rate: (json['rate'] as num?)?.toDouble() ?? 1.0,
        pitch: (json['pitch'] as num?)?.toDouble() ?? 1.0,
      );
}
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
  // sherpa 专用：模型清单中的名称
  final String? sherpaModelName;
  // qwen 专用：模型名（qwen3-tts-flash / cosyvoice-v3-flash 等）
  final String? qwenModel;
  // 三音色：正文/对话/旁白，各自独立开关+音色+语速+音调
  final VoiceStyle narrationVoice; // 正文（叙述）
  final VoiceStyle dialogueVoice;  // 对话（引号内）
  final VoiceStyle asideVoice;     // 旁白（括号内）

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
    this.sherpaModelName,
    this.qwenModel,
    this.narrationVoice = const VoiceStyle(),
    this.dialogueVoice = const VoiceStyle(),
    this.asideVoice = const VoiceStyle(),
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
    String? sherpaModelName,
    String? qwenModel,
    VoiceStyle? narrationVoice,
    VoiceStyle? dialogueVoice,
    VoiceStyle? asideVoice,
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
      sherpaModelName: sherpaModelName ?? this.sherpaModelName,
      qwenModel: qwenModel ?? this.qwenModel,
      narrationVoice: narrationVoice ?? this.narrationVoice,
      dialogueVoice: dialogueVoice ?? this.dialogueVoice,
      asideVoice: asideVoice ?? this.asideVoice,
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
        'sherpaModelName': sherpaModelName,
        'qwenModel': qwenModel,
        'narrationVoice': narrationVoice.toJson(),
        'dialogueVoice': dialogueVoice.toJson(),
        'asideVoice': asideVoice.toJson(),
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
        sherpaModelName: json['sherpaModelName'] as String?,
        qwenModel: json['qwenModel'] as String?,
        narrationVoice: json['narrationVoice'] != null
            ? VoiceStyle.fromJson(json['narrationVoice'] as Map<String, dynamic>)
            : const VoiceStyle(),
        dialogueVoice: json['dialogueVoice'] != null
            ? VoiceStyle.fromJson(json['dialogueVoice'] as Map<String, dynamic>)
            : const VoiceStyle(),
        asideVoice: json['asideVoice'] != null
            ? VoiceStyle.fromJson(json['asideVoice'] as Map<String, dynamic>)
            : const VoiceStyle(),
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
/// 三音色片段类型
enum _TtsType { narration, dialogue, aside }

class _TtsSegment {
  final _TtsType type;
  final String text;
  _TtsSegment(this.type, this.text);
}
class TTSService {
  TtsBackend? _backend;
  bool _isInitialized = false;
  bool _isSpeaking = false;
  final List<String> _queue = [];
  bool _cancelled = false;  // 停止时置真，打断三音色循环
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
  TtsBackend? get currentBackend => _backend;

  /// 按 provider 路由到具体 backend
  TtsBackend _createBackend(TTSSettings s) {
    switch (s.provider) {
      case TTSProvider.system:
        return FlutterTtsBackend(
          onStart: () {},
          onComplete: () {},
          onError: (_) {},
        );
      case TTSProvider.sherpaOnnx:
        return SherpaOnnxBackend(modelName: s.sherpaModelName);
      case TTSProvider.mimoTts:
        return MimoTtsBackend(apiKey: s.apiKey, baseUrl: s.apiEndpoint);
      case TTSProvider.qwenTts:
        return QwenTtsBackend(
          apiKey: s.apiKey,
          model: s.qwenModel,
          baseUrl: s.apiEndpoint,
        );
      case TTSProvider.baiduTts:
        return BaiduTtsBackend(apiKey: s.apiKey, secretKey: s.apiEndpoint);
      case TTSProvider.elevenlabs:
      case TTSProvider.azure:
        // 占位 provider 回退到系统 TTS
        return FlutterTtsBackend(
          onStart: () {},
          onComplete: () {},
          onError: (_) {},
        );
    }
  }

  /// Initialize the TTS service
  Future<void> initialize() async {
    if (_isInitialized && _backend != null) return;
    try {
      _backend = _createBackend(_settings);
      await _backend!.initialize();
      _availableVoices = _backend!
          .getAvailableVoices()
          .map((v) => TTSVoice(
                id: v['value'] ?? '',
                name: v['label'] ?? (v['value'] ?? ''),
                provider: _settings.provider,
              ))
          .where((v) => v.id.isNotEmpty)
          .toList();
      _isInitialized = true;
    } catch (e) {
      onError?.call('Failed to initialize TTS: $e');
    }
  }

  /// Update settings
  void updateSettings(TTSSettings settings) {
    final providerChanged = settings.provider != _settings.provider;
    final modelChanged = (settings.sherpaModelName != _settings.sherpaModelName) ||
        (settings.qwenModel != _settings.qwenModel);
    _settings = settings;
    if (providerChanged || modelChanged) {
      // provider/model 变化：重置 backend，下次 initialize 按新配置创建
      _backend?.dispose();
      _backend = null;
      _isInitialized = false;
    }
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

  /// 三音色朗读：按 对话(引号)/旁白(括号)/正文 切分，逐段串行"换装"播放。
  /// 同一引擎，每段读前重设 voice/rate/pitch —— 串行+换装，三声音互不干扰。
  /// 三音色朗读：按 对话(引号)/旁白(括号)/正文 切分，逐段串行"换装"播放。
  /// 同一后端，每段读前重设 voice/rate/pitch —— 串行+换装，三声音互不干扰。
  Future<void> speakByStyle(String text) async {
    if (!_isInitialized || !_settings.enabled) return;
    final cleaned = _cleanTextForTTS(text);
    if (cleaned.isEmpty) return;

    await stop();          // 打断上一次
    _cancelled = false;
    if (_backend == null) return;

    _isSpeaking = true;
    onStart?.call();
    try {
      final segments = _splitByType(cleaned);
      for (final seg in segments) {
        final style = _styleFor(seg.type);
        if (_cancelled) break;
        if (!style.enabled) continue; // 该类关闭 → 跳过不读
        if (!_hasReadable(seg.text)) continue; // 纯标点会卡住引擎，跳过

        // 换装：每段读前按类型重设（三声音的关键）
        await _backend!.speak(
          seg.text,
          voiceId: style.voiceId,
          rate: style.rate,
          pitch: style.pitch,
          volume: _settings.volume,
        ).timeout(
          Duration(seconds: 5 + seg.text.length ~/ 3),
          onTimeout: () {
            debugPrint('[TTS] speak超时跳过: "${seg.text}"'); // 保留：卡死兜底提示
          },
        );
      }
    } catch (e, s) {
      debugPrint('[TTS异常] $e\n$s');
      onError?.call('TTS error: $e');
    } finally {
      _isSpeaking = false;
      if (!_cancelled) onComplete?.call();
    }
  }

  VoiceStyle _styleFor(_TtsType type) {
    switch (type) {
      case _TtsType.dialogue:
        return _settings.dialogueVoice;
      case _TtsType.aside:
        return _settings.asideVoice;
      case _TtsType.narration:
        return _settings.narrationVoice;
    }
  }

  /// 把文本按 对话(引号)/旁白(括号)/正文 切成有序片段。
  /// 复用渲染层的引号/括号正则思路，按出现顺序扫描，不处理嵌套。
  List<_TtsSegment> _splitByType(String text) {
    final pattern = RegExp(
      r'(“[^”\r\n]*”|「[^」\r\n]*」|『[^』\r\n]*』|《[^》\r\n]*》|"[^"\r\n]*")' // 组1：对话
      r'|([（(][^（）()]*[）)])', // 组2：旁白
      dotAll: true,
    );
    final segments = <_TtsSegment>[];
    var last = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > last) {
        final narr = text.substring(last, m.start).trim();
        if (narr.isNotEmpty) {
          segments.add(_TtsSegment(_TtsType.narration, narr));
        }
      }
      if (m.group(1) != null) {
        final inner = _stripWrappers(m.group(1)!).trim();
        if (inner.isNotEmpty) {
          segments.add(_TtsSegment(_TtsType.dialogue, inner));
        }
      } else if (m.group(2) != null) {
        final inner = _stripWrappers(m.group(2)!).trim();
        if (inner.isNotEmpty) {
          segments.add(_TtsSegment(_TtsType.aside, inner));
        }
      }
      last = m.end;
    }
    if (last < text.length) {
      final narr = text.substring(last).trim();
      if (narr.isNotEmpty) segments.add(_TtsSegment(_TtsType.narration, narr));
    }
    return segments;
  }

  /// 去掉首尾包裹符号（引号/括号），不朗读符号本身
  /// 是否含可朗读内容（至少一个字母/数字/文字）。
  /// 纯标点会让 TTS 引擎不触发完成回调，导致 await 永久挂起。
  bool _hasReadable(String s) =>
      RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(s);
  String _stripWrappers(String s) =>
      s.length < 2 ? s : s.substring(1, s.length - 1);

  /// Process the speech queue
  Future<void> _processQueue({String? characterId}) async {
    while (_queue.isNotEmpty) {
      final text = _queue.removeAt(0);
      await _speakText(text, characterId: characterId);
    }
  }

  /// Actually speak the text
  Future<void> _speakText(String text, {String? characterId}) async {
    final backend = _backend;
    if (backend == null) return;
    _isSpeaking = true;
    onStart?.call();
    try {
      final charVoice = characterId != null ? _characterVoices[characterId] : null;
      final voiceId = charVoice?.voiceId ?? _settings.voiceId;
      final rate = charVoice?.rate ?? _settings.rate;
      final pitch = charVoice?.pitch ?? _settings.pitch;
      final volume = charVoice?.volume ?? _settings.volume;

      await backend.speak(
        text,
        voiceId: voiceId,
        rate: rate,
        pitch: pitch,
        volume: volume,
      );
    } catch (e) {
      onError?.call('TTS error: $e');
    } finally {
      _isSpeaking = false;
    }
  }

  /// Stop speaking
  Future<void> stop() async {
    _cancelled = true; // 打断三音色循环
    _queue.clear();
    await _backend?.stop();
    if (_isSpeaking) {
      _isSpeaking = false;
      onCancel?.call();
    }
  }

  /// Pause speaking
  Future<void> pause() async {
    await _backend?.pause();
  }

  /// Resume speaking
  Future<void> resume() async {
    await _backend?.resume();
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
  Future<void> dispose() async {
    await stop();
    await _backend?.dispose();
    _backend = null;
    _isInitialized = false;
  }
}
