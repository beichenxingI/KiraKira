import 'package:dio/dio.dart';
import 'package:kirakira/data/models/vector_storage.dart';
import 'package:kirakira/domain/services/local_embedder.dart';

/// Engine for converting text to vectors (embeddings).
///
/// Current implementation: calls an OpenAI-compatible /embeddings endpoint (cloud).
///
/// Notes for future maintainers:
/// Cloud embedding has two pain points: inflated relay pricing (seen as high as
/// 22 CNY/1M) and heavy memory users eventually being priced out by the bill.
/// A local model (int8-quantized bge-small / MiniLM, tens of MB) solves both:
/// zero token cost, zero latency, and privacy since data never leaves the device.
/// The integration point is generateEmbedding below: swap the HTTP request for
/// local ONNX inference; the retrieval/storage/prompt injection layers need no changes.
class EmbeddingService {
  final Dio _dio = Dio();

  // Local inference engine (lazy-loaded; the model is initialized only when the local provider is used)
  LocalEmbedder? _localEmbedder;

  /// Convert a single text to a vector. Throws on failure; callers handle it.
  Future<List<double>> generateEmbedding(
    String text,
    VectorStorageSettings settings,
  ) async {
    final results = await generateEmbeddings([text], settings);
    return results.first;
  }

  /// Batch conversion of multiple texts to vectors (used for storage; one request saves round trips).
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

  /// Local ONNX inference: converts one text at a time. First call loads the model (~24MB), which is slow.
  Future<List<List<double>>> _generateLocal(List<String> texts) async {
    _localEmbedder ??= LocalEmbedder();
    final out = <List<double>>[];
    for (final t in texts) {
      out.add(await _localEmbedder!.embed(t));
    }
    return out;
  }

  /// OpenAI-compatible /embeddings call (works with the official OpenAI API and various relay endpoints).
  Future<List<List<double>>> _generateOpenAICompatible(
    List<String> texts,
    VectorStorageSettings settings,
  ) async {
    final apiKey = settings.embeddingApiKey?.trim() ?? '';
    if (apiKey.isEmpty) {
      throw Exception('未配置 Embedding API Key');
    }

    // Normalize baseUrl: allow users to include /v1 or omit it, and always build /embeddings
    var baseUrl = (settings.embeddingApiUrl?.trim().isNotEmpty ?? false)
        ? settings.embeddingApiUrl!.trim()
        : 'https://api.openai.com/v1';
    baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''); // Strip trailing slashes
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