import 'package:flutter_tts/flutter_tts.dart';
import 'tts_backend.dart';
import '../tts_service.dart' show TTSVoice, TTSProvider;

/// flutter_tts 系统 TTS 后端。
///
/// 迁移自 tts_service.dart 原有 flutter_tts 逻辑（L270-297 initialize /
/// L533-568 _speakText / L570-579 stop），行为保持一致。
class FlutterTtsBackend implements TtsBackend {
  final FlutterTts _tts = FlutterTts();
  final void Function()? onStart;
  final void Function()? onComplete;
  final void Function(String)? onError;

  bool _isInitialized = false;
  List<TTSVoice> _voices = [];

  FlutterTtsBackend({this.onStart, this.onComplete, this.onError});

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    await _tts.setLanguage('zh-CN'); // 默认中文
    await _tts.awaitSpeakCompletion(true); // speak() 等到读完再返回
    _tts.setCompletionHandler(() {
      onComplete?.call();
    });
    _tts.setCancelHandler(() {});
    _tts.setErrorHandler((msg) {
      onError?.call('TTS error: $msg');
    });
    await _loadSystemVoices();
    _isInitialized = true;
  }

  /// 从系统拉取真实可用的语音列表（迁移自 tts_service.dart L300-329）
  Future<void> _loadSystemVoices() async {
    try {
      final raw = await _tts.getVoices;
      if (raw is List) {
        final voices = <TTSVoice>[];
        final seen = <String>{};
        for (final v in raw) {
          if (v is Map) {
            final name = (v['name'] ?? '').toString();
            final locale = (v['locale'] ?? '').toString();
            if (name.isEmpty) continue;
            final uid = '$name|$locale';
            if (!seen.add(uid)) continue;
            voices.add(TTSVoice(
              id: uid,
              name: locale.isNotEmpty ? '$name ($locale)' : name,
              language: locale,
              provider: TTSProvider.system,
            ));
          }
        }
        if (voices.isNotEmpty) {
          _voices = voices;
          return;
        }
      }
    } catch (_) {}
    _voices = [
      const TTSVoice(
        id: 'default',
        name: 'Default',
        language: 'en-US',
        provider: TTSProvider.system,
      ),
    ];
  }

  @override
  List<Map<String, String>> getAvailableVoices() {
    return _voices
        .map((v) => {'value': v.id, 'label': v.name})
        .toList();
  }

  @override
  Future<void> speak(
    String text, {
    String? voiceId,
    double rate = 1.0,
    double pitch = 1.0,
    double volume = 1.0,
  }) async {
    if (!_isInitialized) await initialize();
    // flutter_tts: rate 范围 0~1（0.5=正常），UI 的 0.5~2.0 映射为 /2
    await _tts.setSpeechRate((rate / 2.0).clamp(0.0, 1.0));
    await _tts.setPitch(pitch.clamp(0.5, 2.0));
    await _tts.setVolume(volume.clamp(0.0, 1.0));
    if (voiceId != null && voiceId.isNotEmpty) {
      // voiceId 格式 'name|locale'
      final parts = voiceId.split('|');
      await _tts.setVoice({
        'name': parts.first,
        'locale': parts.length > 1 && parts[1].isNotEmpty ? parts[1] : 'zh-CN',
      });
    }
    onStart?.call();
    // awaitSpeakCompletion(true) 下，这里会等到读完
    await _tts.speak(text);
    onComplete?.call();
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }

  @override
  Future<void> pause() async {
    // 平台差异由 flutter_tts 处理；桌面端无操作
  }

  @override
  Future<void> resume() async {
    // 同上
  }

  @override
  Future<void> dispose() async {
    await stop();
  }

  @override
  bool get isLocal => false; // 系统 TTS 依赖系统服务

  @override
  String get displayName => '系统 TTS';

  @override
  bool get supportsPitch => true;

  @override
  bool get supportsRate => true;

  @override
  String get configHint => '使用设备系统的语音合成服务';
}
