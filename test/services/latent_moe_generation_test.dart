import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirakira/domain/services/image_generation_service.dart';

// [latent.moe] 本地 mock 服务器测试(方案C:异步队列生图 POST /api/generate →
// 轮询 GET /api/generate/{id} → GET /api/media/{id} 拉图)。
// 用 127.0.0.1 随机端口跑真实 Dio 请求链路,不依赖外部包。

// 1x1 PNG(合法图片字节,通过 _looksLikeNonImageData 检查)
final _tinyPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

class _LatentMockServer {
  final HttpServer server;
  final List<Map<String, dynamic>> generateBodies = [];
  final List<String> authHeaders = [];
  int pollCount = 0;
  // 轮询序列:依次返回;耗尽后停在最后一个
  List<Map<String, dynamic>> pollResponses;
  // 提交响应(默认 202 成功)
  ({int status, Map<String, dynamic> body}) submitResponse;
  // [误填URL] 404 HTML 错误页(模拟 Base URL 误填路径后的服务端响应)
  bool submitHtml = false;

  _LatentMockServer(this.server)
      : pollResponses = [
          {'status': 'running', 'progress': 50},
          {
            'status': 'succeeded',
            'artworkId': 'art-1',
            'seed': 12345,
            'width': 1024,
            'height': 1024,
            'steps': 12,
            'sampler': 'euler',
            'scheduler': 'sgm_uniform',
          },
        ],
        submitResponse = (
          status: 202,
          body: {'id': 'job-1', 'status': 'queued', 'prompt': 'test'},
        );

  String get baseUrl => 'http://127.0.0.1:${server.port}';

  Future<void> _json(HttpRequest req, int status, Map<String, dynamic> body) async {
    req.response.statusCode = status;
    req.response.headers.contentType = ContentType.json;
    req.response.write(jsonEncode(body));
    await req.response.close();
  }

  Future<void> handle(HttpRequest req) async {
    authHeaders.add(req.headers.value('Authorization') ?? '');
    if (req.method == 'POST' && req.uri.path == '/api/generate') {
      if (submitHtml) {
        req.response.statusCode = 404;
        req.response.headers.contentType =
            ContentType('text', 'html', charset: 'utf-8');
        req.response.write('<html><body>404 Not Found</body></html>');
        await req.response.close();
        return;
      }
      // join() 完整读取并排空请求体(只读 first 会留下未消费字节导致连接中断)
      final body =
          jsonDecode(await utf8.decoder.bind(req).join()) as Map<String, dynamic>;
      generateBodies.add(body);
      await _json(req, submitResponse.status, submitResponse.body);
      return;
    }
    if (req.method == 'GET' && req.uri.path.startsWith('/api/generate/')) {
      final idx = pollCount.clamp(0, pollResponses.length - 1);
      pollCount++;
      _json(req, 200, pollResponses[idx]);
      return;
    }
    if (req.method == 'GET' && req.uri.path.startsWith('/api/media/')) {
      req.response.headers.contentType = ContentType('image', 'png');
      req.response.add(_tinyPng);
      await req.response.close();
      return;
    }
    req.response.statusCode = 404;
    await req.response.close();
  }

  Future<void> close() => server.close(force: true);
}

Future<_LatentMockServer> _startMock({
  List<Map<String, dynamic>>? pollResponses,
  ({int status, Map<String, dynamic> body})? submitResponse,
}) async {
  final server = await HttpServer.bind('127.0.0.1', 0);
  final mock = _LatentMockServer(server);
  if (pollResponses != null) mock.pollResponses = pollResponses;
  if (submitResponse != null) mock.submitResponse = submitResponse;
  server.listen(mock.handle);
  return mock;
}

ImageGenerationService _service(String baseUrl) {
  final service = ImageGenerationService();
  service.updateSettings(const ImageGenSettings(
    enabled: true,
    provider: ImageGenProvider.latentMoe,
    apiKeys: {'latent_moe': 'lat_sk_test_key'},
    apiEndpoints: {},
  ).withApiEndpoint(baseUrl));
  return service;
}

void main() {
  test('完整流程:提交→轮询→拉图成功,参数映射正确(steps clamp/resolution/sampler)', () async {
    final mock = await _startMock();
    final service = _service(mock.baseUrl);

    // steps 20 → clamp 12; 1024x1024 → square; 默认 sampler euler_a → euler
    final result = await service.generate(const ImageGenRequest(
      prompt: 'a cat, masterpiece',
      width: 1024,
      height: 1024,
      steps: 20,
    ));

    expect(result, isNotNull);
    expect(result!.images.length, 1);
    expect(result.images.first, _tinyPng);
    expect(result.seed, 12345);
    expect(result.metadata?['provider'], 'latent_moe');
    expect(result.metadata?['artworkId'], 'art-1');

    // 请求体参数映射
    final body = mock.generateBodies.first;
    expect(body['prompt'], 'a cat, masterpiece');
    expect(body['steps'], 12);
    expect(body['resolution'], 'square');
    expect(body['sampler'], 'euler');
    expect(body['scheduler'], 'sgm_uniform');
    expect(body.containsKey('negativePrompt'), false); // 无默认负面 → 省略
    expect(body.containsKey('model'), false); // 站点无 model 字段

    // 认证头
    expect(mock.authHeaders.first, 'Bearer lat_sk_test_key');
    expect(mock.pollCount, 2); // running → succeeded 两次轮询
    await mock.close();
  });

  test('宽高比映射:竖图→portrait,横图→landscape', () async {
    final mock = await _startMock();
    final service = _service(mock.baseUrl);

    await service.generate(const ImageGenRequest(prompt: 'p', width: 832, height: 1216));
    expect(mock.generateBodies[0]['resolution'], 'portrait');

    await service.generate(const ImageGenRequest(prompt: 'l', width: 1216, height: 832));
    expect(mock.generateBodies[1]['resolution'], 'landscape');
    await mock.close();
  });

  test('429 quota_exhausted → 友好报错', () async {
    final mock = await _startMock(
      submitResponse: (
        status: 429,
        body: {'error': {'code': 'quota_exhausted', 'message': 'weekly allowance spent'}},
      ),
    );
    final service = _service(mock.baseUrl);

    // generate() 内部 catch 异常 → onError 回调 + 返回 null(不抛出)
    String? errorMsg;
    service.onError = (msg) => errorMsg = msg;
    final result = await service.generate(const ImageGenRequest(prompt: 'x'));

    expect(result, isNull);
    expect(errorMsg, contains('本周生图额度'));
    await mock.close();
  });

  test('409 too_many_active → 友好报错', () async {
    final mock = await _startMock(
      submitResponse: (
        status: 409,
        body: {'error': 'too_many_active', 'message': 'concurrency full'},
      ),
    );
    final service = _service(mock.baseUrl);

    String? errorMsg;
    service.onError = (msg) => errorMsg = msg;
    final result = await service.generate(const ImageGenRequest(prompt: 'x'));

    expect(result, isNull);
    expect(errorMsg, contains('并发任务已满'));
    await mock.close();
  });

  test('任务 failed → 透出 errorCode', () async {
    final mock = await _startMock(
      pollResponses: [
        {'status': 'failed', 'errorCode': 'out_of_memory'},
      ],
    );
    final service = _service(mock.baseUrl);

    String? errorMsg;
    service.onError = (msg) => errorMsg = msg;
    final result = await service.generate(const ImageGenRequest(prompt: 'x'));

    expect(result, isNull);
    expect(errorMsg, contains('out_of_memory'));
    await mock.close();
  });

  test('缺 API key → 直接报错不发起请求', () async {
    final service = ImageGenerationService();
    service.updateSettings(const ImageGenSettings(
      enabled: true,
      provider: ImageGenProvider.latentMoe,
    ));

    String? errorMsg;
    service.onError = (msg) => errorMsg = msg;
    final result = await service.generate(const ImageGenRequest(prompt: 'x'));

    expect(result, isNull);
    expect(errorMsg, contains('API key is required'));
  });

  test('Base URL 误填路径(/api/novelai)自动规范化,仍命中正确端点', () async {
    final mock = await _startMock();
    // 误填完整路径 → 规范化后去掉 /api/novelai,请求应落到 {base}/api/generate
    final service = ImageGenerationService();
    service.updateSettings(const ImageGenSettings(
      enabled: true,
      provider: ImageGenProvider.latentMoe,
      apiKeys: {'latent_moe': 'lat_sk_test_key'},
    ).withApiEndpoint('${mock.baseUrl}/api/novelai'));

    final result = await service.generate(const ImageGenRequest(
      prompt: 'normalize test',
      width: 1024,
      height: 1024,
    ));

    expect(result, isNotNull);
    expect(result!.images.length, 1);
    expect(mock.generateBodies.length, 1); // 命中正确端点(未规范化会 404 拿不到图)
    expect(mock.generateBodies.first['prompt'], 'normalize test');
    await mock.close();
  });

  test('404 HTML 错误页 → 提示 Base URL 填写错误', () async {
    final mock = await _startMock();
    mock.submitHtml = true;
    final service = _service(mock.baseUrl);

    String? errorMsg;
    service.onError = (msg) => errorMsg = msg;
    final result = await service.generate(const ImageGenRequest(prompt: 'x'));

    expect(result, isNull);
    expect(errorMsg, contains('收到HTML响应'));
    expect(errorMsg, contains('Base URL 填写错误'));
    await mock.close();
  });

  test('settings 往返:latentMoe provider 持久化保留', () {
    const settings = ImageGenSettings(
      enabled: true,
      provider: ImageGenProvider.latentMoe,
      apiKeys: {'latent_moe': 'lat_sk_x'},
      apiEndpoints: {'latent_moe': 'https://custom.example.com'},
    );
    final restored = ImageGenSettings.fromJson(settings.toJson());

    expect(restored.provider, ImageGenProvider.latentMoe);
    expect(restored.provider.requiresApiKey, true);
    expect(restored.provider.defaultModel, ''); // 无模型字段
    expect(restored.apiKeys['latent_moe'], 'lat_sk_x');
    expect(restored.effectiveEndpoint, 'https://custom.example.com');
  });
}
