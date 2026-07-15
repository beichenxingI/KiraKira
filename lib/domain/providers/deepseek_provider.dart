import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'llm_provider.dart';

class DeepSeekProvider implements LlmProvider {
  @override
  String get id => 'deepseek';

  @override
  String get displayName => 'DeepSeek';

  @override
  Future<Stream<String>> sendMessage(
      LlmRequest request, ApiCredential credential) async {
    final url = '${credential.baseUrl}/v1/chat/completions';
    final headers = _buildHeaders(credential);
    final body = {
      'model': request.model ?? 'deepseek-chat',
      'messages': request.messages,
      'temperature': request.temperature,
      'max_tokens': request.maxTokens,
      'top_p': request.topP,
      'stream': true,
      if (request.extraParams != null) ...request.extraParams!,
    };

    final response = await http.Client().send(
      http.Request('POST', Uri.parse(url))
        ..headers.addAll(headers)
        ..body = jsonEncode(body),
    );

    return response.stream.transform(utf8.decoder).transform(
          StreamTransformer.fromHandlers(
            handleData: (data, sink) {
              for (final line in data.toString().split('\n')) {
                if (line.startsWith('data: ') && line != 'data: [DONE]') {
                  try {
                    final json = jsonDecode(line.substring(6));
                    final delta = (jsonDecode(line.substring(6))['choices'] as List).first['delta'];
                    if (delta != null && delta['content'] != null) {
                      final content = delta['content'].toString();
                      if (content.isNotEmpty) sink.add(content);
                    }
                    if (delta != null && delta['content'] != null) {
                      final content = delta['content'].toString();
                      if (content.isNotEmpty) sink.add(content);
                    }
                  } catch (_) {}
                }
              }
            },
            handleDone: (sink) => sink.close(),
          ),
        );
  }

  @override
  Future<List<String>> fetchModels(ApiCredential credential) async {
    final url = '${credential.baseUrl}/models';
    final headers = _buildHeaders(credential);

    final response = await http.get(Uri.parse(url), headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final models = data['data'] as List<dynamic>?;
      return models?.map((m) => m['id'].toString()).toList() ?? [];
    }
    return [];
  }

  @override
  Future<ConnectionTestResult> testConnection(
      ApiCredential credential) async {
    final startTime = DateTime.now();
    try {
      final firstTokenCompleter = Completer<int>();

      final stream = await sendMessage(
        LlmRequest(messages: [
          {'role': 'user', 'content': 'Hello'}
        ], maxTokens: 10),
        credential,
      );

      int? firstTokenMs;
      stream.listen(
        (token) {
          if (!firstTokenCompleter.isCompleted) {
            firstTokenCompleter.complete(
                DateTime.now().difference(startTime).inMilliseconds);
          }
        },
        onDone: () {
          if (!firstTokenCompleter.isCompleted) {
            firstTokenCompleter.complete(0);
          }
        },
        onError: (_) {
          if (!firstTokenCompleter.isCompleted) firstTokenCompleter.complete(0);
        },
      );

      firstTokenMs = await firstTokenCompleter.future;

      final models = await fetchModels(credential);

      return ConnectionTestResult(
        success: true,
        latencyMs: firstTokenMs,
        models: models,
        testTime: DateTime.now(),
        supportsStreaming: true,
      );
    } catch (e) {
      return ConnectionTestResult(
        success: false,
        errorMessage: e.toString(),
        testTime: DateTime.now(),
        latencyMs:
            DateTime.now().difference(startTime).inMilliseconds,
      );
    }
  }

  Map<String, String> _buildHeaders(ApiCredential cred) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${cred.apiKey}',
    };
    if (cred.extraHeaders != null) headers.addAll(cred.extraHeaders!);
    return headers;
  }
}
