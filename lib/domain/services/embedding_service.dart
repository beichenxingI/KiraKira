import 'package:dio/dio.dart';
import 'package:kirakira/data/models/vector_storage.dart';
import 'package:kirakira/domain/services/local_embedder.dart';

/// 把文字转成向量（embedding）的引擎。
///
/// 当前实现：调用 OpenAI 兼容的 /embeddings 端点（云端）。
///
/// ── 致未来的你 ──────────────────────────────────────────────
/// 如果你正在读这段注释，八成是来接本地模型的。欢迎回来。
/// 云端 embedding 有两个痛点：中转站定价虚高（见过 22元/1M 的离谱货），
/// 以及重度记忆用户迟早被账单劝退。本地模型（bge-small / MiniLM 的
/// int8 量化版，几十MB）能一举解决——零 token 费、零延迟、隐私不出设备。
/// 接入点就在下面的 generateEmbedding：把"发 HTTP 请求"换成"调本地
/// ONNX 推理"即可，上层的检索/存储/prompt 注入全都不用动。
/// 加油，这个功能值得。
/// ────────────────────────────────────────────────────────
class EmbeddingService {
  final Dio _dio = Dio();

  // 本地推理器（懒加载，仅 local provider 用到时才初始化模型）
  LocalEmbedder? _localEmbedder;

  /// 把单段文字转成向量。失败抛异常，由调用方处理。
  Future<List<double>> generateEmbedding(
    String text,
    VectorStorageSettings settings,
  ) async {
    final results = await generateEmbeddings([text], settings);
    return results.first;
  }

  /// 批量把多段文字转成向量（入库时用，一次请求省往返）。
  Future<List<List<double>>> generateEmbeddings(
    List<String> texts,
    VectorStorageSettings settings,
  ) async {
    switch (settings.embeddingProvider) {
      case EmbeddingProvider.openai:
      case EmbeddingProvider.custom:
      case EmbeddingProvider.cohere:
        return _generateOpenAICompatible(texts, settings);
      case EmbeddingProvider.local:
        return _generateLocal(texts);
    }
  }

  /// 本地 ONNX 推理：逐条转向量。首次调用会加载模型（约24MB），稍慢。
  Future<List<List<double>>> _generateLocal(List<String> texts) async {
    _localEmbedder ??= LocalEmbedder();
    final out = <List<double>>[];
    for (final t in texts) {
      out.add(await _localEmbedder!.embed(t));
    }
    return out;
  }

  /// OpenAI 兼容的 /embeddings 调用（OpenAI 官方、各类中转站通用）。
  Future<List<List<double>>> _generateOpenAICompatible(
    List<String> texts,
    VectorStorageSettings settings,
  ) async {
    final apiKey = settings.embeddingApiKey?.trim() ?? '';
    if (apiKey.isEmpty) {
      throw Exception('未配置 Embedding API Key');
    }

    // 归一化 baseUrl：允许用户填到 /v1 或不填，统一拼出 /embeddings
    var baseUrl = (settings.embeddingApiUrl?.trim().isNotEmpty ?? false)
        ? settings.embeddingApiUrl!.trim()
        : 'https://api.openai.com/v1';
    baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''); // 去尾部斜杠
    final url = baseUrl.endsWith('/embeddings')
        ? baseUrl
        : '$baseUrl/embeddings';

    final model = (settings.embeddingModel?.trim().isNotEmpty ?? false)
        ? settings.embeddingModel!.trim()
        : settings.embeddingProvider.defaultModel;

    final resp = await _dio.post(
      url,
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      ),
      data: {
        'model': model,
        'input': texts,
      },
    );

    final data = resp.data;
    final list = (data['data'] as List)
        .map((e) => (e['embedding'] as List)
            .map((v) => (v as num).toDouble())
            .toList())
        .toList();
    return list;
  }
}