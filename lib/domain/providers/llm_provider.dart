import 'dart:async';

/// Request to an LLM provider
class LlmRequest {
  final List<Map<String, String>> messages;
  final double temperature;
  final int maxTokens;
  final double topP;
  final String? model;
  final Map<String, dynamic>? extraParams;

  const LlmRequest({
    required this.messages,
    this.temperature = 0.7,
    this.maxTokens = 8192,
    this.topP = 0.9,
    this.model,
    this.extraParams,
  });
}

/// Credential for an API provider
class ApiCredential {
  final String baseUrl;
  final String apiKey;
  final String? authType; // 'bearer', 'api-key', 'basic'
  final Map<String, String>? extraHeaders;

  const ApiCredential({
    required this.baseUrl,
    required this.apiKey,
    this.authType = 'bearer',
    this.extraHeaders,
  });
}

/// Result of a connection test
class ConnectionTestResult {
  final bool success;
  final int? latencyMs;
  final List<String> models;
  final String? errorMessage;
  final DateTime testTime;
  final bool supportsStreaming;
  final int? contextWindowSize;

  const ConnectionTestResult({
    required this.success,
    this.latencyMs,
    this.models = const [],
    this.errorMessage,
    required this.testTime,
    this.supportsStreaming = true,
    this.contextWindowSize,
  });
}

/// Abstract interface for LLM providers
abstract class LlmProvider {
  String get id;
  String get displayName;

  Future<Stream<String>> sendMessage(LlmRequest request, ApiCredential credential);
  Future<List<String>> fetchModels(ApiCredential credential);
  Future<ConnectionTestResult> testConnection(ApiCredential credential);
}
