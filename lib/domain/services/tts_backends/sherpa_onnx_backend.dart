import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../tts_model_service.dart';
import 'tts_backend.dart';

/// sherpa-onnx 本地离线 TTS 后端。
///
/// 模型由用户导入（tar.bz2 → <docDir>/KiraKira/models/tts/），
/// manifest.json 记录清单。合成用 OfflineTts（FFI，阻塞 → Isolate.run），
/// 输出 Float32 PCM → writeWave 写临时 WAV → just_audio 播放。
class SherpaOnnxBackend implements TtsBackend {
  static bool _bindingsInitialized = false;

  final String? modelName;

  sherpa.OfflineTts? _tts;
  bool _isInitialized = false;
  AudioPlayer? _player;
  List<Map<String, String>> _voices = const [];

  SherpaOnnxBackend({this.modelName});

  @override
  Future<void> initialize() async {
    if (_isInitialized && _tts != null) return;

    if (modelName == null || modelName!.isEmpty) {
      throw Exception('未选择 sherpa-onnx 模型，请先在设置中导入模型');
    }

    final manifest = await TtsModelService.instance.loadManifest();
    TtsModelEntry entry;
    try {
      entry = manifest.firstWhere((e) => e.name == modelName);
    } catch (_) {
      throw Exception('模型 "$modelName" 不在清单中，可能已被删除，请重新导入');
    }

    if (!_bindingsInitialized) {
      sherpa.initBindings(); // 抄 STT（stt_service.dart 同款模式）
      _bindingsInitialized = true;
    }

    final config = _buildConfig(entry);
    // OfflineTts 构造是同步 FFI（模型加载可达数秒），用 Isolate.run 避免卡 UI。
    // Pointer 可跨 isolate 发送（Dart FFI 语义），GeneratedAudio 含 TypedData 可传回。
    _tts = await Isolate.run(() => sherpa.OfflineTts(config));

    // 生成 sid 音色列表
    final numSpeakers = _tts!.numSpeakers;
    _voices = List.generate(
      numSpeakers,
      (i) => {
        'value': i.toString(),
        'label': '说话人 ${i + 1}',
      },
    );

    _isInitialized = true;
    debugPrint(
        '[SherpaTTS] 初始化成功: $modelName（${entry.modelType}, ${_tts!.sampleRate}Hz, $numSpeakers 说话人）');
  }

  sherpa.OfflineTtsConfig _buildConfig(TtsModelEntry e) {
    switch (e.modelType) {
      case 'vits':
        return sherpa.OfflineTtsConfig(
          model: sherpa.OfflineTtsModelConfig(
            vits: sherpa.OfflineTtsVitsModelConfig(
              model: e.modelPath,
              lexicon: e.lexicon ?? '',
              tokens: e.tokens,
              dictDir: e.dictDir ?? '',
              dataDir: e.dataDir ?? '',
            ),
            numThreads: 2,
            debug: false,
            provider: 'cpu',
          ),
          ruleFsts: e.ruleFsts ?? '',
          ruleFars: e.ruleFars ?? '',
          maxNumSenetences: 1,
        );
      case 'kokoro':
        return sherpa.OfflineTtsConfig(
          model: sherpa.OfflineTtsModelConfig(
            kokoro: sherpa.OfflineTtsKokoroModelConfig(
              model: e.modelPath,
              voices: e.voices ?? '',
              tokens: e.tokens,
              dataDir: e.dataDir ?? '',
              dictDir: e.dictDir ?? '',
              lexicon: e.lexicon ?? '',
            ),
            numThreads: 2,
            debug: false,
            provider: 'cpu',
          ),
          ruleFsts: e.ruleFsts ?? '',
          maxNumSenetences: 1,
        );
      case 'matcha':
        return sherpa.OfflineTtsConfig(
          model: sherpa.OfflineTtsModelConfig(
            matcha: sherpa.OfflineTtsMatchaModelConfig(
              acousticModel: e.modelPath,
              vocoder: e.vocoder ?? '',
              tokens: e.tokens,
              lexicon: e.lexicon ?? '',
              dictDir: e.dictDir ?? '',
              dataDir: e.dataDir ?? '',
            ),
            numThreads: 2,
            debug: false,
            provider: 'cpu',
          ),
          ruleFsts: e.ruleFsts ?? '',
          maxNumSenetences: 1,
        );
      default:
        throw Exception('不支持的模型类型: ${e.modelType}');
    }
  }

  @override
  List<Map<String, String>> getAvailableVoices() => _voices;

  @override
  Future<void> speak(
    String text, {
    String? voiceId,
    double rate = 1.0,
    double pitch = 1.0, // sherpa 不支持音调，忽略
    double volume = 1.0,
  }) async {
    if (!_isInitialized || _tts == null) await initialize();
    final tts = _tts;
    if (tts == null) return;

    final sid = int.tryParse(voiceId ?? '0') ?? 0;
    final speed = rate.clamp(0.5, 2.0);
    final player = _player ??= AudioPlayer();

    // generate 是同步 FFI 调用（阻塞），必须 Isolate.run 包裹
    final audio = await Isolate.run(
      () => tts.generate(text: text, sid: sid, speed: speed),
    );
    if (audio.samples.isEmpty) {
      throw Exception('sherpa TTS 合成结果为空（文本或 sid 无效）');
    }

    // PCM → WAV 临时文件
    final tmpDir = await getTemporaryDirectory();
    final wavPath = p.join(
        tmpDir.path, 'tts_${DateTime.now().millisecondsSinceEpoch}.wav');
    sherpa.writeWave(
      filename: wavPath,
      samples: audio.samples,
      sampleRate: audio.sampleRate,
    );

    // just_audio 播放，await 到完成
    await player.setFilePath(wavPath);
    await player.play();
    await player.playerStateStream.firstWhere(
      (s) => s.processingState == ProcessingState.completed,
    );

    // 临时文件清理
    File(wavPath).delete().catchError((_) => File(wavPath));
  }

  @override
  Future<void> stop() async {
    await _player?.stop();
  }

  @override
  Future<void> pause() async {
    await _player?.pause();
  }

  @override
  Future<void> resume() async {
    await _player?.play();
  }

  @override
  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
    _tts?.free(); // 必须 free，否则内存泄漏
    _tts = null;
    _isInitialized = false;
  }

  @override
  bool get isLocal => true;

  @override
  String get displayName => '本地离线 TTS';

  @override
  bool get supportsPitch => false; // sherpa 不支持音调控制

  @override
  bool get supportsRate => true;

  @override
  String get configHint => '需导入模型文件（.tar.bz2），推荐 vits-icefall-zh-aishell3 (30MB)';

  /// 读取模型清单（供 UI/调试）
  Future<List<TtsModelEntry>> loadManifest() =>
      TtsModelService.instance.loadManifest();
}
