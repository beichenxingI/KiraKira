import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../tts_service.dart' show TTSProvider;
import 'tts_backend.dart';

/// 阿里 Qwen-TTS 后端。
///
/// DashScope HTTP：POST {base}/api/v1/services/aigc/multimodal-generation/generation，
/// Bearer 认证，返回 output.audio.url（wav，24h 有效）→ 下载 → just_audio 播放。
///
/// qwen3-tts-flash 不支持 rate/pitch 数值参数（仅 instructions）；
/// cosyvoice 系列走 SpeechSynthesizer 端点，支持 rate/pitch/volume。
class QwenTtsBackend implements TtsBackend {
  final String? apiKey;
  final String? model; // qwen3-tts-flash / cosyvoice-v3-flash 等
  final String? baseUrl; // 可选自定义

  static const _defaultBaseUrl = 'https://dashscope.aliyuncs.com';
  static const _defaultModel = 'qwen3-tts-flash';

  final Dio _dio;
  final AudioPlayer _player = AudioPlayer();

  bool _isCosyvoice = false;

  // Qwen-TTS 系统音色（节选常用 20 个；cosyvoice 音色按模型版本配对）
  static const _qwenVoices = <Map<String, String>>[
    {'value': 'Cherry', 'label': '芊悦·阳光小姐姐'},
    {'value': 'Serena', 'label': '苏瑶·温柔'},
    {'value': 'Ethan', 'label': '晨煦·阳光男'},
    {'value': 'Chelsie', 'label': '千雪·二次元'},
    {'value': 'Momo', 'label': '茉兔'},
    {'value': 'Moon', 'label': '月白·男'},
    {'value': 'Maia', 'label': '四月'},
    {'value': 'Kai', 'label': '凯·男'},
    {'value': 'Nofish', 'label': '不吃鱼·男'},
    {'value': 'Bella', 'label': '萌宝'},
    {'value': 'Jennifer', 'label': '詹妮弗·美语女'},
    {'value': 'Ryan', 'label': '甜茶·男'},
    {'value': 'Vincent', 'label': '田叔·沙哑烟嗓'},
    {'value': 'Neil', 'label': '阿闻·新闻主播'},
    {'value': 'Eldric Sage', 'label': '沧明子·老者'},
    {'value': 'Stella', 'label': '少女阿月'},
    {'value': 'Jada', 'label': '阿珍·上海话'},
    {'value': 'Dylan', 'label': '晓东·北京话'},
    {'value': 'Sunny', 'label': '晴儿·四川话'},
    {'value': 'Rocky', 'label': '阿强·粤语'},
  ];

  // CosyVoice v3-flash 常用音色
  static const _cosyVoices = <Map<String, String>>[
    {'value': 'longanyang', 'label': '阳光大男孩'},
    {'value': 'longanhuan_v3', 'label': '欢脱元气女'},
    {'value': 'longhuhu_v3', 'label': '女童'},
    {'value': 'longxiaochun_v3', 'label': '知性女'},
    {'value': 'longlaotie_v3', 'label': '东北老铁'},
    {'value': 'longanyue_v3', 'label': '粤语男'},
    {'value': 'longanmin_v3', 'label': '闽南男'},
    {'value': 'loongbella_v3', 'label': 'Bella·英文女'},
  ];

  QwenTtsBackend({this.apiKey, this.model, this.baseUrl})
      : _dio = Dio(BaseOptions(
          baseUrl:
              (baseUrl != null && baseUrl.isNotEmpty) ? baseUrl : _defaultBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 60),
        )) {
    _isCosyvoice = (model ?? _defaultModel).startsWith('cosyvoice');
  }

  @override
  Future<void> initialize() async {
    if (apiKey == null || apiKey!.isEmpty) {
      throw Exception('阿里 Qwen-TTS API Key 未配置（百炼控制台创建）');
    }
  }

  @override
  List<Map<String, String>> getAvailableVoices() =>
      _isCosyvoice ? _cosyVoices : _qwenVoices;

  @override
  Future<void> speak(
    String text, {
    String? voiceId,
    double rate = 1.0,
    double pitch = 1.0,
    double volume = 1.0,
  }) async {
    if (apiKey == null || apiKey!.isEmpty) {
      throw Exception('阿里 Qwen-TTS API Key 未配置');
    }

    late final Response<dynamic> response;
    if (_isCosyvoice) {
      // CosyVoice：SpeechSynthesizer 端点，支持 rate/pitch/volume 数值
      response = await _dio.post(
        '/api/v1/services/audio/tts/SpeechSynthesizer',
        options: Options(headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        }),
        data: {
          'model': model ?? 'cosyvoice-v3-flash',
          'input': {
            'text': text,
            'voice': (voiceId != null && voiceId.isNotEmpty)
                ? voiceId
                : 'longanyang',
            'format': 'wav',
            'sample_rate': 24000,
            'rate': rate.clamp(0.5, 2.0),
            'pitch': pitch.clamp(0.5, 2.0),
            'volume': (volume * 100).round().clamp(0, 100),
          },
        },
      );
    } else {
      // Qwen-TTS：multimodal-generation 端点（无 rate/pitch 数值参数）
      response = await _dio.post(
        '/api/v1/services/aigc/multimodal-generation/generation',
        options: Options(headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        }),
        data: {
          'model': model ?? _defaultModel,
          'input': {
            'text': text,
            'voice': (voiceId != null && voiceId.isNotEmpty)
                ? voiceId
                : 'Cherry',
            'language_type': 'Auto',
          },
        },
      );
    }

    final data = response.data;
    final audioUrl = data['output']?['audio']?['url'] as String?;
    if (audioUrl == null || audioUrl.isEmpty) {
      final code = data['code'] ?? '';
      final message = data['message'] ?? '未知错误';
      throw Exception('Qwen-TTS 错误 $code: $message');
    }

    // 下载 wav → 临时文件 → just_audio 播放（OSS URL 24h 有效，立即用）
    final tmpDir = await getTemporaryDirectory();
    final wavPath = p.join(
        tmpDir.path, 'tts_${DateTime.now().millisecondsSinceEpoch}.wav');
    await _dio.download(audioUrl, wavPath);

    await _player.setFilePath(wavPath);
    await _player.play();
    await _player.playerStateStream.firstWhere(
      (s) => s.processingState == ProcessingState.completed,
    );
    File(wavPath).delete().catchError((_) => File(wavPath));
  }

  /// 解析 DashScope 错误码为用户友好提示
  static String friendlyError(Object error) {
    final msg = error.toString();
    if (msg.contains('429') || msg.contains('rate limit')) {
      return '请求过于频繁，请稍后再试';
    }
    if (msg.contains('403') || msg.contains('FreeTierOnly')) {
      return '免费额度已用完，请充值或切换引擎';
    }
    if (msg.contains('Arrearage')) {
      return '账户欠费，请充值';
    }
    if (msg.contains('418')) {
      return '音色与模型版本不匹配';
    }
    if (msg.contains('401') || msg.contains('InvalidApiKey')) {
      return 'API Key 无效';
    }
    return 'TTS 错误: $msg';
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
  String get displayName => '阿里通义 TTS';

  @override
  bool get supportsPitch => _isCosyvoice; // 仅 cosyvoice 支持数值 pitch

  @override
  bool get supportsRate => _isCosyvoice;

  @override
  String get configHint =>
      '48 系统音色，0.8 元/万字符，cosyvoice 系列支持语速/音调控制，需在百炼控制台创建 API Key';

  @visibleForTesting
  void debugLog(String msg) => debugPrint('[QwenTTS] $msg');
}
