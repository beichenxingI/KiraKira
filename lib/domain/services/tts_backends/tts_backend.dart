/// TTS 后端抽象接口
///
/// 所有 TTS 引擎（系统/本地/云端）需实现此接口。
/// TTSService 按 provider 路由到具体 backend。
abstract class TtsBackend {
  /// 初始化引擎（加载模型/验证 API Key 等）
  Future<void> initialize();

  /// 获取可用音色列表，返回 [{value, label}] 统一格式
  List<Map<String, String>> getAvailableVoices();

  /// 朗读单段文本（await 到播放完成）
  ///
  /// [text] 已清洗的文本（_cleanTextForTTS 输出）
  /// [voiceId] 音色 ID（system: "name|locale"；sherpa: sid；云端: voice name）
  /// [rate] 语速 0.5-2.0
  /// [pitch] 音调 0.5-2.0（部分后端忽略）
  /// [volume] 音量 0.0-1.0
  Future<void> speak(
    String text, {
    String? voiceId,
    double rate = 1.0,
    double pitch = 1.0,
    double volume = 1.0,
  });

  /// 停止当前朗读
  Future<void> stop();

  /// 暂停（如果引擎支持）
  Future<void> pause();

  /// 恢复（如果引擎支持）
  Future<void> resume();

  /// 释放资源（sherpa 的 free / 云端无操作）
  Future<void> dispose();

  /// 是否本地引擎（影响 UI 提示）
  bool get isLocal;

  /// 引擎显示名
  String get displayName;

  /// 是否支持音调控制（sherpa 不支持，UI 隐藏 pitch 滑块）
  bool get supportsPitch => true;

  /// 是否支持语速控制
  bool get supportsRate => true;

  /// 引擎特定的配置提示（UI 显示）
  String get configHint => '';
}
