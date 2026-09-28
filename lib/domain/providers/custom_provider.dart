import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'llm_provider.dart';

class CustomProvider implements LlmProvider {
  @override
  String get id => 'custom';
  @override
  String get displayName => '自定义中转站';

  @override
  Future<Stream<String>> sendMessage(LlmRequest request, ApiCredential credential) async {
    final url = '${credential.baseUrl}/v1/chat/completions';
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (credential.authType == 'api-key') 'x-api-key': credential.apiKey
      else 'Authorization': 'Bearer ${credential.apiKey}',
      if (credential.extraHeaders != null) ...credential.extraHeaders!,
    };
    final body = {
      'model': request.model ?? 'default',
      'messages': request.messages,
      'temperature': request.temperature,
      'max_tokens': request.maxTokens,
      'top_p': request.topP,
      'stream': true,
      if (request.extraParams != null) ...request.extraParams!,
    };
    final resp = await http.Client().send(http.Request('POST', Uri.parse(url))..headers.addAll(headers)..body = jsonEncode(body));
    return resp.stream.transform(utf8.decoder).transform(StreamTransformer.fromHandlers(
      handleData: (data, sink) {
        for (final line in data.toString().split('\n')) {
          if (line.startsWith('data: ') && line != 'data: [DONE]') {
            try {
              final delta = (jsonDecode(line.substring(6))['choices'] as List).first['delta'];
              if (delta != null && delta['content'] != null) sink.add(delta['content'].toString());
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
      final resp = await http.get(Uri.parse('${credential.baseUrl}/v1/models'), headers: {'Authorization':'Bearer ${credential.apiKey}'});
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
      final stream = await sendMessage(const LlmRequest(messages: [{'role':'user','content':'Hi'}], maxTokens: 5), credential);
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
