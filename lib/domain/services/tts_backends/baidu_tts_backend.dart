import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tts_backend.dart';

/// Baidu TTS backend.
///
/// Two-step access_token auth: AK/SK exchanged at oauth/2.0/token
/// (valid ~30 days, cached with renewal). Short-text synthesis POSTs to
/// tsn.baidu.com/text2audio (form parameters, returns mp3 binary).
class BaiduTtsBackend implements TtsBackend {
  final String? apiKey;    // Baidu AK (client_id)
  final String? secretKey; // Baidu SK (client_secret)

  static const _tokenUrl = 'https://aip.baidubce.com/oauth/2.0/token';
  static const _ttsUrl = 'https://tsn.baidu.com/text2audio';

  final Dio _dio;
  final AudioPlayer _player = AudioPlayer();

  String? _accessToken;
  DateTime? _tokenExpiresAt;

  // Baidu speaker per values (common subset)
  static const _voices = <Map<String, String>>[
    {'value': '0', 'label': '度小美·标准女'},
    {'value': '1', 'label': '度小宇·活泼男'},
    {'value': '3', 'label': '度逍遥·精品男'},
    {'value': '4', 'label': '度丫丫·童声'},
    {'value': '110', 'label': '度小雯·女'},
    {'value': '111', 'label': '度小萌·女童'},
    {'value': '5003', 'label': '度小娇·情感女'},
    {'value': '5118', 'label': '度小鹿·男'},
  ];

  BaiduTtsBackend({this.apiKey, this.secretKey})
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 60),
        ));

  @override
  Future<void> initialize() async {
    if (apiKey == null || apiKey!.isEmpty || secretKey == null || secretKey!.isEmpty) {
      throw Exception('百度 AK/SK 未配置（百度智能云控制台创建应用获取）');
    }
    await ensureAccessToken();
  }

  /// Two-step access_token auth: AK/SK exchanged for a token, cached until 1 day before expiry
  Future<void> ensureAccessToken() async {
    if (_accessToken != null &&
        _tokenExpiresAt != null &&
        DateTime.now().isBefore(_tokenExpiresAt!.subtract(const Duration(days: 1)))) {
      return;
    }
    final resp = await _dio.post<dynamic>(
      _tokenUrl,
      queryParameters: {
        'grant_type': 'client_credentials',
        'client_id': apiKey,
        'client_secret': secretKey,
      },
      options: Options(responseType: ResponseType.json),
    );
    final token = resp.data['access_token'] as String?;
    if (token == null || token.isEmpty) {
      final desc = resp.data['error_description'] ?? resp.data['error'] ?? '未知错误';
      throw Exception('百度 access_token 获取失败: $desc');
    }
    _accessToken = token;
    final expiresIn = (resp.data['expires_in'] as num?)?.toInt() ?? 2592000;
    _tokenExpiresAt = DateTime.now().add(Duration(seconds: expiresIn));
    debugPrint('[BaiduTTS] access_token 已获取（${expiresIn}s 有效）');
  }

  /// Clear the token cache (force re-fetch on 401/503)
  void invalidateToken() {
    _accessToken = null;
    _tokenExpiresAt = null;
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
    if (apiKey == null || apiKey!.isEmpty || secretKey == null || secretKey!.isEmpty) {
      throw Exception('百度 AK/SK 未配置');
    }
    await ensureAccessToken();
    final token = _accessToken;
    if (token == null) throw Exception('百度 access_token 获取失败');

    final response = await _dio.post<List<int>>(
      _ttsUrl,
      queryParameters: {
        'tok': token,
        'tex': text,
        'per': (voiceId != null && voiceId.isNotEmpty) ? voiceId : '0',
        'spd': ((rate - 1.0) * 5 + 5).round().clamp(0, 15), // speed 0-15, 5=normal
        'pit': ((pitch - 1.0) * 5 + 5).round().clamp(0, 15), // pitch 0-15, 5=normal
        'vol': (volume * 15).round().clamp(0, 15),
        'aue': 3, // 3=mp3-16k
        'ctp': 1,
      },
      options: Options(responseType: ResponseType.bytes),
    );

    final bytes = response.data ?? <int>[];
    final contentType = response.headers.value('content-type') ?? '';
    // Baidu errors return JSON (content-type application/json); success returns audio
    if (contentType.contains('json') || contentType.contains('text')) {
      final body = String.fromCharCodes(bytes);
      throw Exception('百度 TTS 错误: $body');
    }
    if (bytes.isEmpty) {
      throw Exception('百度 TTS 返回空音频');
    }

    // mp3 to a temp file, then played back with just_audio
    final tmpDir = await getTemporaryDirectory();
    final mp3Path = p.join(
        tmpDir.path, 'tts_${DateTime.now().millisecondsSinceEpoch}.mp3');
    await File(mp3Path).writeAsBytes(bytes, flush: true);

    await _player.setFilePath(mp3Path);
    await _player.play();
    await _player.playerStateStream.firstWhere(
      (s) => s.processingState == ProcessingState.completed,
    );
    File(mp3Path).delete().catchError((_) => File(mp3Path));
  }

  /// Map Baidu errors to user-friendly messages
  static String friendlyError(Object error) {
    final msg = error.toString();
    if (msg.contains('"err_no":503') || msg.contains('503')) {
      return 'token 已过期，请重试（已自动刷新）';
    }
    if (msg.contains('"err_no":505')) {
      return '账户欠费，请充值';
    }
    if (msg.contains('"err_no":513')) {
      return '并发超限，请稍后再试';
    }
    if (msg.contains('error_description') || msg.contains('invalid_client')) {
      return 'AK/SK 无效，请检查配置';
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
  String get displayName => '百度语音合成';

  @override
  bool get supportsPitch => true; // pit 0-15

  @override
  bool get supportsRate => true; // spd 0-15

  @override
  String get configHint =>
      '个人认证享永久免费 5 万次，需在百度智能云控制台创建应用获取 AK/SK';

  @visibleForTesting
  void debugLog(String msg) => debugPrint('[BaiduTTS] $msg');
}
