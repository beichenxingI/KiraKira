import 'dart:async';
import 'llm_provider.dart';


class ImageGenRequest {
  final String prompt;
  final String? negativePrompt;
  final int width;
  final int height;
  final int steps;
  final double cfgScale;
  final String? model;
  final Map<String, dynamic>? extraParams;

  const ImageGenRequest({
    required this.prompt,
    this.negativePrompt,
    this.width = 1024,
    this.height = 1024,
    this.steps = 28,
    this.cfgScale = 7.0,
    this.model,
    this.extraParams,
  });
}

class ImageGenResult {
  final bool success;
  final String? imageUrl;
  final List<String>? images;
  final String? errorMessage;
  final int? latencyMs;

  const ImageGenResult({
    required this.success,
    this.imageUrl,
    this.images,
    this.errorMessage,
    this.latencyMs,
  });
}

abstract class ImageGenProvider {
  String get id;
  String get displayName;
  Future<ImageGenResult> generate(ImageGenRequest request, ApiCredential credential);
  Future<List<String>> fetchModels(ApiCredential credential);
}

