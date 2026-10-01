import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../tts_model_service.dart';
import 'tts_backend.dart';

/// sherpa-onnx local offline TTS backend.
///
/// Models are user-imported (tar.bz2 extracted to <docDir>/KiraKira/models/tts/)
/// and listed in manifest.json. Synthesis uses OfflineTts via FFI (blocking, so
/// wrapped in Isolate.run), producing Float32 PCM written to a temp WAV file
/// via writeWave and played back with just_audio.
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
      sherpa.initBindings(); // Same pattern as STT (stt_service.dart)
      _bindingsInitialized = true;
    }

    final config = _buildConfig(entry);
    // sherpa_onnx FFI bindings cannot cross isolates; create on the main isolate
    _tts = sherpa.OfflineTts(config);

    // Build the sid voice list
    final numSpeakers = entry.numSpeakers;
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
    double pitch = 1.0, // sherpa does not support pitch; ignored
    double volume = 1.0,
  }) async {
    if (!_isInitialized || _tts == null) await initialize();
    final tts = _tts;
    if (tts == null) return;

    final sid = int.tryParse(voiceId ?? '0') ?? 0;
    final speed = rate.clamp(0.5, 2.0);
    final player = _player ??= AudioPlayer();

    // generate is a synchronous FFI call and must run on the main isolate
    // (bindings cannot cross isolates)
    final audio = tts.generate(text: text, sid: sid, speed: speed);
    if (audio.samples.isEmpty) {
      throw Exception('sherpa TTS 合成结果为空（文本或 sid 无效）');
    }

    // PCM to a temp WAV file
    final tmpDir = await getTemporaryDirectory();
    final wavPath = p.join(
        tmpDir.path, 'tts_${DateTime.now().millisecondsSinceEpoch}.wav');
    sherpa.writeWave(
      filename: wavPath,
      samples: audio.samples,
      sampleRate: audio.sampleRate,
    );

    // just_audio playback, awaited until completion
    await player.setFilePath(wavPath);
    await player.play();
    await player.playerStateStream.firstWhere(
      (s) => s.processingState == ProcessingState.completed,
    );

    // Temp file cleanup
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
    _tts?.free(); // Must free, otherwise memory leaks
    _tts = null;
    _isInitialized = false;
  }

  @override
  bool get isLocal => true;

  @override
  String get displayName => '本地离线 TTS';

  @override
  bool get supportsPitch => false; // sherpa does not support pitch control

  @override
  bool get supportsRate => true;

  @override
  String get configHint => '需导入模型文件（.tar.bz2），推荐 vits-icefall-zh-aishell3 (30MB)';

  /// Load the model manifest (for UI/debugging)
  Future<List<TtsModelEntry>> loadManifest() =>
      TtsModelService.instance.loadManifest();
}
