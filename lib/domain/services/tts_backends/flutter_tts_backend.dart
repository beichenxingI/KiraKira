import 'package:flutter_tts/flutter_tts.dart';
import 'tts_backend.dart';
import '../tts_service.dart' show TTSVoice, TTSProvider;

/// flutter_tts system TTS backend.
///
/// Migrated from the original flutter_tts logic in tts_service.dart
/// (initialize/_speakText/stop); behavior kept identical.
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
    await _tts.setLanguage('zh-CN'); // Default to Chinese
    await _tts.awaitSpeakCompletion(true); // speak() returns after reading finishes
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

  /// Fetch the real available voices from the system
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
    // flutter_tts: rate range is 0-1 (0.5 = normal); UI's 0.5-2.0 is mapped by /2
    await _tts.setSpeechRate((rate / 2.0).clamp(0.0, 1.0));
    await _tts.setPitch(pitch.clamp(0.5, 2.0));
    await _tts.setVolume(volume.clamp(0.0, 1.0));
    if (voiceId != null && voiceId.isNotEmpty) {
      // voiceId format is 'name|locale'
      final parts = voiceId.split('|');
      await _tts.setVoice({
        'name': parts.first,
        'locale': parts.length > 1 && parts[1].isNotEmpty ? parts[1] : 'zh-CN',
      });
    }
    onStart?.call();
    // With awaitSpeakCompletion(true), this waits until reading finishes
    await _tts.speak(text);
    onComplete?.call();
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }

  @override
  Future<void> pause() async {
    // Platform differences handled by flutter_tts; no-op on desktop
  }

  @override
  Future<void> resume() async {
    // Same as pause
  }

  @override
  Future<void> dispose() async {
    await stop();
  }

  @override
  bool get isLocal => false; // System TTS depends on system services

  @override
  String get displayName => '系统 TTS';

  @override
  bool get supportsPitch => true;

  @override
  bool get supportsRate => true;

  @override
  String get configHint => '使用设备系统的语音合成服务';
}
