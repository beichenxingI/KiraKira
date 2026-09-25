import 'tts_backend.dart';

/// sherpa-onnx 本地 TTS 后端（Step 1 实现）。
///
/// 当前为骨架：initialize 抛出未实现，等待模型导入服务与
/// OfflineTts 集成完成后填充。
class SherpaOnnxBackend implements TtsBackend {
  final String? modelName;

  SherpaOnnxBackend({this.modelName});

  @override
  Future<void> initialize() async {
    throw UnimplementedError('SherpaOnnxBackend 尚未实现');
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
    throw UnimplementedError('SherpaOnnxBackend 尚未实现');
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
  bool get isLocal => true;

  @override
  String get displayName => '本地离线 TTS';

  @override
  bool get supportsPitch => false;

  @override
  bool get supportsRate => true;

  @override
  String get configHint => '需导入模型文件（.tar.bz2），推荐 vits-icefall-zh-aishell3 (30MB)';
}
