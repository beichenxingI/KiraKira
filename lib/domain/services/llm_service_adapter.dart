import 'dart:async';
import '../providers/llm_provider.dart';
import '../services/llm_service.dart';

/// Adapter: wraps the main system's LLMService/LLMConfig into the LlmProvider
/// interface required by GeekProbe. The detection algorithm only recognizes the
/// LlmProvider abstraction; this layer forwards calls to the real LLMService.
/// Benefit: neither the algorithm layer nor the UI layer needs changes; the
/// bridge is isolated in this file.
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
    // Use the current config as the base and only override sampling parameters
    // that change for this request. This preserves the user's provider, apiKey,
    // streamEnabled, and all other settings.
    final effectiveConfig = _config.copyWith(
      model: request.model ?? _config.model,
      temperature: request.temperature,
      maxTokens: request.maxTokens,
      topP: request.topP,
    );
    // generateStream expects List<Map<String, dynamic>> while request.messages is
    // List<Map<String, String>>; in Dart the former is a supertype of the latter,
    // so it can be passed directly.
    return _service.generateStream(request.messages, effectiveConfig);
  }

  @override
  Future<List<String>> fetchModels(ApiCredential credential) async {
    return _service.getAvailableModels(_config);
  }

  @override
  Future<ConnectionTestResult> testConnection(ApiCredential credential) async {
    // LLMService.testConnection returns a String (success message or throws).
    // Wrapped here into the LlmProvider-style ConnectionTestResult.
    // GeekProbe's runDetection does not call this method; it is implemented
    // only to satisfy the abstract interface.
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