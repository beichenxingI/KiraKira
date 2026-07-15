import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'llm_provider.dart';

class ClaudeProvider implements LlmProvider {
  @override
  String get id => 'claude';
  @override
  String get displayName => 'Claude';

  @override
  Future<Stream<String>> sendMessage(LlmRequest request, ApiCredential credential) async {
    final url = '${credential.baseUrl}/v1/messages';
    final headers = {
      'Content-Type': 'application/json',
      'x-api-key': credential.apiKey,
      'anthropic-version': '2023-06-01',
      if (credential.extraHeaders != null) ...credential.extraHeaders!,
    };
    final systemMsg = request.messages.where((m) => m['role'] == 'system').map((m) => m['content']).join('\n');
    final body = {
      'model': request.model ?? 'claude-3-5-sonnet-20241022',
      'max_tokens': request.maxTokens,
      'temperature': request.temperature,
      'stream': true,
      if (systemMsg.isNotEmpty) 'system': systemMsg,
      'messages': request.messages.where((m) => m['role'] != 'system').toList(),
      if (request.extraParams != null) ...request.extraParams!,
    };
    final resp = await http.Client().send(http.Request('POST', Uri.parse(url))..headers.addAll(headers)..body = jsonEncode(body));
    return resp.stream.transform(utf8.decoder).transform(StreamTransformer.fromHandlers(
      handleData: (data, sink) {
        for (final line in data.toString().split('\n')) {
          if (line.startsWith('data: ') && line != 'data: [DONE]') {
            try {
              final json = jsonDecode(line.substring(6));
              if (json['type'] == 'content_block_delta') {
                final text = json['delta']?['text']?.toString() ?? '';
                if (text.isNotEmpty) sink.add(text);
              }
            } catch (_) {}
          }
        }
      },
      handleDone: (sink) => sink.close(),
    ));
  }

  @override
  Future<List<String>> fetchModels(ApiCredential credential) async {
    try {
      final resp = await http.get(Uri.parse('${credential.baseUrl}/v1/models'), headers: {'x-api-key': credential.apiKey, 'anthropic-version': '2023-06-01'});
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body)['data'] as List<dynamic>?;
        return list?.map((m) => m['id'].toString()).toList() ?? [];
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<ConnectionTestResult> testConnection(ApiCredential credential) async {
    final start = DateTime.now();
    try {
      final stream = await sendMessage(LlmRequest(messages: [{'role':'user','content':'Hi'}], maxTokens: 5), credential);
      final completer = Completer<int>();
      stream.listen((_) { if (!completer.isCompleted) completer.complete(DateTime.now().difference(start).inMilliseconds); },
        onDone: () { if (!completer.isCompleted) completer.complete(0); },
        onError: (_) { if (!completer.isCompleted) completer.complete(0); });
      final latency = await completer.future;
      final models = await fetchModels(credential);
      return ConnectionTestResult(success: true, latencyMs: latency, models: models, testTime: DateTime.now(), supportsStreaming: true);
    } catch (e) {
      return ConnectionTestResult(success: false, errorMessage: e.toString(), testTime: DateTime.now(), latencyMs: DateTime.now().difference(start).inMilliseconds);
    }
  }
}
