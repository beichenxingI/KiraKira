import 'tts_backend.dart';

/// 阿里 Qwen-TTS 后端（Step 3 实现）。
///
/// HTTP + Bearer（DashScope multimodal-generation），当前为骨架。
class QwenTtsBackend implements TtsBackend {
  final String? apiKey;
  final String? model;
  final String? baseUrl;

  QwenTtsBackend({this.apiKey, this.model, this.baseUrl});

  @override
  Future<void> initialize() async {
    throw UnimplementedError('QwenTtsBackend 尚未实现');
  }

  @override
  List<Map<String, String>> getAvailableVoices() => const [];

  @override
  Future<void> speak(
    String text, {
    String? voiceId,
    double rate = 1.0,
    double pitch = 1.0,
    double volume = 1.0,
  }) async {
    throw UnimplementedError('QwenTtsBackend 尚未实现');
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> dispose() async {}

  @override
  bool get isLocal => false;

  @override
  String get displayName => '阿里通义 TTS';

  @override
  bool get supportsPitch => false;

  @override
  bool get supportsRate => false;

  @override
  String get configHint => '48 系统音色，0.8 元/万字符，需在百炼控制台创建 API Key';
}
