import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tts_backend.dart';

/// Xiaomi MiMo TTS backend.
///
/// OpenAI-compatible protocol: POST {base}/v1/chat/completions,
/// the text to synthesize goes in an assistant role message, audio.format=wav|pcm16,
/// returns base64 audio, written to a temp file and played with just_audio.
class MimoTtsBackend implements TtsBackend {
  final String? apiKey;
  final String? baseUrl; // optional custom (defaults to official)

  static const _defaultBaseUrl = 'https://api.xiaomimimo.com/v1';
  static const _defaultModel = 'mimo-v2.5-tts';

  final Dio _dio;
  final AudioPlayer _player = AudioPlayer();

  // 8 preset Chinese/English voices
  static const _voices = <Map<String, String>>[
    {'value': 'mimo_default', 'label': '默认音色'},
    {'value': '冰糖', 'label': '冰糖（中文女）'},
    {'value': '茉莉', 'label': '茉莉（中文女）'},
    {'value': '苏打', 'label': '苏打（中文）'},
    {'value': '白桦', 'label': '白桦（中文男）'},
    {'value': 'Mia', 'label': 'Mia（英文女）'},
    {'value': 'Chloe', 'label': 'Chloe（英文女）'},
    {'value': 'Milo', 'label': 'Milo（英文男）'},
    {'value': 'Dean', 'label': 'Dean（英文男）'},
  ];

  MimoTtsBackend({this.apiKey, this.baseUrl})
      : _dio = Dio(BaseOptions(
          baseUrl: (baseUrl != null && baseUrl.isNotEmpty)
              ? baseUrl
              : _defaultBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 60),
        ));

  @override
  Future<void> initialize() async {
    if (apiKey == null || apiKey!.isEmpty) {
      throw Exception('小米 MiMo API Key 未配置（platform.xiaomimimo.com 创建）');
    }
  }

  @override
  List<Map<String, String>> getAvailableVoices() => _voices;

  @override
  Future<void> speak(
    String text, {
    String? voiceId,
    double rate = 1.0,
    double pitch = 1.0,
    double volume = 1.0,
  }) async {
    if (apiKey == null || apiKey!.isEmpty) {
      throw Exception('小米 MiMo API Key 未配置');
    }

    // Rate/pitch mapped to natural-language style instructions (MiMo has no numeric parameters)
    final instructions = _buildStyleInstruction(rate, pitch);

    final response = await _dio.post(
      '/chat/completions',
      options: Options(headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      }),
      data: {
        'model': _defaultModel,
        'messages': [
          if (instructions != null)
            {'role': 'user', 'content': instructions},
          {'role': 'assistant', 'content': text},
        ],
        'audio': {
          'format': 'wav',
          'voice': (voiceId != null && voiceId.isNotEmpty) ? voiceId : 'mimo_default',
        },
        'stream': false,
      },
    );

    final data = response.data;
    final audioData =
        data['choices']?[0]?['message']?['audio']?['data'] as String?;
    if (audioData == null || audioData.isEmpty) {
      final err = data['error']?['message'] ?? data['message'] ?? '未知错误';
      throw Exception('MiMo TTS 错误: $err');
    }

    // base64 to a wav temp file, played with just_audio
    final bytes = base64Decode(audioData);
    final tmpDir = await getTemporaryDirectory();
    final wavPath = p.join(
        tmpDir.path, 'tts_${DateTime.now().millisecondsSinceEpoch}.wav');
    await File(wavPath).writeAsBytes(bytes, flush: true);

    await _player.setFilePath(wavPath);
    await _player.setVolume(volume.clamp(0.0, 1.0));
    await _player.play();
    await _player.playerStateStream.firstWhere(
      (s) => s.processingState == ProcessingState.completed,
    );
    File(wavPath).delete().catchError((_) => File(wavPath));
  }

  /// Rate/pitch to natural-language instruction (MiMo instruction-style control)
  String? _buildStyleInstruction(double rate, double pitch) {
    final parts = <String>[];
    if ((rate - 1.0).abs() > 0.05) {
      parts.add(rate > 1.0 ? '语速较快' : '语速较慢');
    }
    if ((pitch - 1.0).abs() > 0.05) {
      parts.add(pitch > 1.0 ? '音调偏高' : '音调偏低');
    }
    return parts.isEmpty ? null : '朗读要求：${parts.join('，')}。';
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.play();

  @override
  Future<void> dispose() async {
    await _player.dispose();
    _dio.close();
  }

  @override
  bool get isLocal => false;

  @override
  String get displayName => '小米 MiMo';

  @override
  bool get supportsPitch => true; // approximately supported via natural-language instructions

  @override
  bool get supportsRate => true;

  @override
  String get configHint =>
      '限时免费，8 中英音色，需在 platform.xiaomimimo.com 创建 API Key（sk-xxx）';

  /// Diagnostic log (kept for onboarding troubleshooting)
  @visibleForTesting
  void debugLog(String msg) => debugPrint('[MiMoTTS] $msg');
}
