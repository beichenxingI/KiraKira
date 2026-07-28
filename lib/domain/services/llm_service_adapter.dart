import 'dart:async';
import '../providers/llm_provider.dart';
import '../services/llm_service.dart';

/// 适配器：把主系统的 LLMService/LLMConfig 包装成极客Probe 所需的 LlmProvider 接口。
/// 极客Probe 的检测算法只认 LlmProvider 抽象接口，这一层负责把调用转发到真实的 LLMService。
/// 好处：算法层和 UI 层都不用改，桥单独隔离在这个文件里。
class LlmServiceAdapter implements LlmProvider {
  final LLMService _service;
  final LLMConfig _config;

  LlmServiceAdapter(this._service, this._config);

  @override
  String get id => _config.provider.name;

  @override
  String get displayName => '${_config.provider.name} / ${_config.model}';

  @override
  Future<Stream<String>> sendMessage(
    LlmRequest request,
    ApiCredential credential,
  ) async {
    // 用当前配置为底，只覆盖本次请求要变的采样参数。
    // 这样保留了用户的 provider、apiKey、streamEnabled 等全部设置。
    final effectiveConfig = _config.copyWith(
      model: request.model ?? _config.model,
      temperature: request.temperature,
      maxTokens: request.maxTokens,
      topP: request.topP,
    );
    // generateStream 要 List<Map<String, dynamic>>，request.messages 是
    // List<Map<String, String>>，Dart 里前者是后者的父类型，可直接传。
    return _service.generateStream(request.messages, effectiveConfig);
  }

  @override
  Future<List<String>> fetchModels(ApiCredential credential) async {
    return _service.getAvailableModels(_config);
  }

  @override
  Future<ConnectionTestResult> testConnection(ApiCredential credential) async {
    // LLMService.testConnection 返回 String（成功信息或抛异常）。
    // 这里包装成 LlmProvider 那套的 ConnectionTestResult。
    // 注意：极客Probe 的 runDetection 不调用这个方法，实现它只为满足抽象接口。
    try {
      await _service.testConnection(_config);
      return ConnectionTestResult(
        success: true,
        testTime: DateTime.now(),
      );
    } catch (e) {
      return ConnectionTestResult(
        success: false,
        errorMessage: e.toString(),
        testTime: DateTime.now(),
      );
    }
  }
}