import 'tts_backend.dart';

/// 百度 TTS 后端（Step 4 实现）。
///
/// AK/SK → access_token 两步认证 + text2audio，当前为骨架。
class BaiduTtsBackend implements TtsBackend {
  final String? apiKey;     // 百度 AK
  final String? secretKey;  // 百度 SK

  BaiduTtsBackend({this.apiKey, this.secretKey});

  @override
  Future<void> initialize() async {
    throw UnimplementedError('BaiduTtsBackend 尚未实现');
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
    throw UnimplementedError('BaiduTtsBackend 尚未实现');
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
  String get displayName => '百度语音合成';

  @override
  bool get supportsPitch => true;

  @override
  bool get supportsRate => true;

  @override
  String get configHint => '个人认证享永久免费 5 万次，需在百度控制台创建应用获取 AK/SK';
}
