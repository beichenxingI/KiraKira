import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tts_backend.dart';

/// 小米 MiMo TTS 后端。
///
/// OpenAI 兼容协议：POST {base}/v1/chat/completions，
/// 待合成文本放 assistant 角色消息，audio.format=wav|pcm16，
/// 返回 base64 音频 → 写临时文件 → just_audio 播放。
class MimoTtsBackend implements TtsBackend {
  final String? apiKey;
  final String? baseUrl; // 可选自定义（默认官方）

  static const _defaultBaseUrl = 'https://api.xiaomimimo.com/v1';
  static const _defaultModel = 'mimo-v2.5-tts';

  final Dio _dio;
  final AudioPlayer _player = AudioPlayer();

  // 8 预置中英音色
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

    // 语速/音调映射为自然语言风格指令（MiMo 无数值参数）
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

    // base64 → wav 临时文件 → just_audio 播放
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

  /// 语速/音调 → 自然语言指令（MiMo 指令式控制）
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
  bool get supportsPitch => true; // 经自然语言指令近似支持

  @override
  bool get supportsRate => true;

  @override
  String get configHint =>
      '限时免费，8 中英音色，需在 platform.xiaomimimo.com 创建 API Key（sk-xxx）';

  /// 诊断日志（保留：接入期排障）
  @visibleForTesting
  void debugLog(String msg) => debugPrint('[MiMoTTS] $msg');
}
