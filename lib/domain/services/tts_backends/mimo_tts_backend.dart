import 'tts_backend.dart';

/// 小米 MiMo TTS 后端（Step 2 实现）。
///
/// OpenAI 兼容协议（/v1/chat/completions），当前为骨架。
class MimoTtsBackend implements TtsBackend {
  final String? apiKey;
  final String? baseUrl;

  MimoTtsBackend({this.apiKey, this.baseUrl});

  @override
  Future<void> initialize() async {
    throw UnimplementedError('MimoTtsBackend 尚未实现');
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
    throw UnimplementedError('MimoTtsBackend 尚未实现');
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
  String get displayName => '小米 MiMo';

  @override
  bool get supportsPitch => false;

  @override
  bool get supportsRate => false;

  @override
  String get configHint => '限时免费，8 中英音色，需在 platform.xiaomimimo.com 创建 API Key';
}
