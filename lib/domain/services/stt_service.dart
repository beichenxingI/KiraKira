import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// STT Provider types
enum STTProvider {
  sherpa('sherpa', '本地离线识别'),
  system('system', 'System STT'),
  whisper('whisper', 'Whisper'),
  azure('azure', 'Azure Speech'),
  ;

  final String id;
  final String displayName;

  const STTProvider(this.id, this.displayName);

  static STTProvider? fromId(String id) {
    try {
      return STTProvider.values.firstWhere((pr) => pr.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// STT Settings
class STTSettings {
  final bool enabled;
  final STTProvider provider;
  final String language;
  final bool continuousListening;
  final bool autoSend;
  final bool showPartialResults;
  final String? apiKey;
  final String? apiEndpoint;

  const STTSettings({
    this.enabled = false,
    this.provider = STTProvider.sherpa,
    this.language = 'zh-CN',
    this.continuousListening = false,
    this.autoSend = false,
    this.showPartialResults = true,
    this.apiKey,
    this.apiEndpoint,
  });

  STTSettings copyWith({
    bool? enabled,
    STTProvider? provider,
    String? language,
    bool? continuousListening,
    bool? autoSend,
    bool? showPartialResults,
    String? apiKey,
    String? apiEndpoint,
  }) {
    return STTSettings(
      enabled: enabled ?? this.enabled,
      provider: provider ?? this.provider,
      language: language ?? this.language,
      continuousListening: continuousListening ?? this.continuousListening,
      autoSend: autoSend ?? this.autoSend,
      showPartialResults: showPartialResults ?? this.showPartialResults,
      apiKey: apiKey ?? this.apiKey,
      apiEndpoint: apiEndpoint ?? this.apiEndpoint,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'provider': provider.id,
        'language': language,
        'continuousListening': continuousListening,
        'autoSend': autoSend,
        'showPartialResults': showPartialResults,
        'apiKey': apiKey,
        'apiEndpoint': apiEndpoint,
      };

  factory STTSettings.fromJson(Map<String, dynamic> json) => STTSettings(
        enabled: json['enabled'] as bool? ?? false,
        provider: STTProvider.fromId(json['provider'] as String? ?? 'sherpa') ?? STTProvider.sherpa,
        language: json['language'] as String? ?? 'zh-CN',
        continuousListening: json['continuousListening'] as bool? ?? false,
        autoSend: json['autoSend'] as bool? ?? false,
        showPartialResults: json['showPartialResults'] as bool? ?? true,
        apiKey: json['apiKey'] as String?,
        apiEndpoint: json['apiEndpoint'] as String?,
      );
}

/// Supported languages for STT
class STTLanguage {
  final String code;
  final String name;
  final String nativeName;

  const STTLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
  });

  static const List<STTLanguage> supportedLanguages = [
    STTLanguage(code: 'zh-CN', name: 'Chinese (Simplified)', nativeName: '简体中文'),
    STTLanguage(code: 'zh-TW', name: 'Chinese (Traditional)', nativeName: '繁體中文'),
    STTLanguage(code: 'en-US', name: 'English (US)', nativeName: 'English'),
    STTLanguage(code: 'en-GB', name: 'English (UK)', nativeName: 'English'),
    STTLanguage(code: 'es-ES', name: 'Spanish (Spain)', nativeName: 'Español'),
    STTLanguage(code: 'es-MX', name: 'Spanish (Mexico)', nativeName: 'Español'),
    STTLanguage(code: 'fr-FR', name: 'French (Français)', nativeName: 'Français'),
    STTLanguage(code: 'de-DE', name: 'German (Deutsch)', nativeName: 'Deutsch'),
    STTLanguage(code: 'it-IT', name: 'Italian (Italiano)', nativeName: 'Italiano'),
    STTLanguage(code: 'pt-BR', name: 'Portuguese (Brazil)', nativeName: 'Português'),
    STTLanguage(code: 'pt-PT', name: 'Portuguese (Portugal)', nativeName: 'Português'),
    STTLanguage(code: 'ru-RU', name: 'Russian (Русский)', nativeName: 'Русский'),
    STTLanguage(code: 'ja-JP', name: 'Japanese (日本語)', nativeName: '日本語'),
    STTLanguage(code: 'ko-KR', name: 'Korean (한국어)', nativeName: '한국어'),
    STTLanguage(code: 'ar-SA', name: 'Arabic (العربية)', nativeName: 'العربية'),
    STTLanguage(code: 'hi-IN', name: 'Hindi (हिन्दी)', nativeName: 'हिन्दी'),
  ];

  static STTLanguage? fromCode(String code) {
    try {
      return supportedLanguages.firstWhere((l) => l.code == code);
    } catch (_) {
      return null;
    }
  }
}

/// STT recognition result
class STTResult {
  final String text;
  final bool isFinal;
  final double confidence;

  const STTResult({
    required this.text,
    this.isFinal = false,
    this.confidence = 1.0,
  });
}

/// STT Service for speech-to-text functionality
///
/// [STTProvider.sherpa] runs local offline recognition. Bundles a sherpa-onnx
/// streaming Zipformer2-CTC Chinese int8 model (assets/models/stt/), copied to
/// the app documents directory on first use. Recording uses the record package
/// to capture 16kHz mono PCM16 fed in real time to the streaming recognizer.
/// Other providers are placeholders (produce no recognition results).
class STTService {
  static bool _bindingsInitialized = false;

  static const _modelAsset = 'assets/models/stt/model.int8.onnx';
  static const _tokensAsset = 'assets/models/stt/tokens.txt';
  static const _sampleRate = 16000;

  bool _isInitialized = false;
  bool _isListening = false;
  STTSettings _settings = const STTSettings();

  sherpa.OnlineRecognizer? _recognizer;
  sherpa.OnlineStream? _stream;
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioSub;
  String _lastPartial = '';

  /// Callbacks
  void Function(STTResult)? onResult;
  VoidCallback? onListeningStarted;
  VoidCallback? onListeningStopped;
  void Function(String)? onError;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  STTSettings get settings => _settings;

  /// Copy the recognition model from assets to <docDir>/KiraKira/models/stt/ (first use only)
  Future<String> _prepareModelFiles() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'KiraKira', 'models', 'stt'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final modelFile = File(p.join(dir.path, 'model.int8.onnx'));
    final tokensFile = File(p.join(dir.path, 'tokens.txt'));
    if (!await modelFile.exists()) {
      final data = await rootBundle.load(_modelAsset);
      await modelFile.writeAsBytes(data.buffer.asUint8List(
          data.offsetInBytes, data.lengthInBytes), flush: true);
    }
    if (!await tokensFile.exists()) {
      final data = await rootBundle.load(_tokensAsset);
      await tokensFile.writeAsBytes(data.buffer.asUint8List(
          data.offsetInBytes, data.lengthInBytes), flush: true);
    }
    return dir.path;
  }

  /// Initialize the STT service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (_settings.provider == STTProvider.sherpa) {
        final modelDir = await _prepareModelFiles();
        if (!_bindingsInitialized) {
          sherpa.initBindings();
          _bindingsInitialized = true;
        }
        final config = sherpa.OnlineRecognizerConfig(
          model: sherpa.OnlineModelConfig(
            zipformer2Ctc: sherpa.OnlineZipformer2CtcModelConfig(
              model: p.join(modelDir, 'model.int8.onnx'),
            ),
            tokens: p.join(modelDir, 'tokens.txt'),
            numThreads: 2,
            debug: false,
          ),
        );
        _recognizer?.free();
        _recognizer = sherpa.OnlineRecognizer(config);
      }
      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      onError?.call('Failed to initialize STT: $e');
    }
  }

  /// Update settings
  void updateSettings(STTSettings settings) {
    final providerChanged = settings.provider != _settings.provider;
    _settings = settings;
    if (providerChanged) {
      // Re-initialize with the new config after switching provider
      _isInitialized = false;
    }
  }

  /// Check if STT is available
  Future<bool> isAvailable() async {
    await initialize();
    return _isInitialized;
  }

  /// Start listening
  Future<void> startListening() async {
    if (!_settings.enabled) return;
    if (_isListening) return;

    try {
      await initialize();
      if (!_isInitialized) {
        onError?.call('STT 未就绪（模型初始化失败）');
        return;
      }
      if (_settings.provider == STTProvider.sherpa) {
        if (!await _recorder.hasPermission()) {
          onError?.call('麦克风权限被拒绝');
          return;
        }
        _stream = _recognizer!.createStream();
        _lastPartial = '';
        final audio = await _recorder.startStream(const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: 1,
        ));
        _isListening = true;
        onListeningStarted?.call();
        _audioSub = audio.listen(_feedPcmChunk, onError: (Object e) {
          onError?.call('录音错误: $e');
          _teardown(emitStopped: true);
        });
      } else {
        // Other providers are placeholders for now
        _isListening = true;
        onListeningStarted?.call();
        debugPrint('STT: provider ${_settings.provider.id} not implemented yet');
      }
    } catch (e) {
      await _teardown(emitStopped: true);
      onError?.call('STT error: $e');
    }
  }

  void _feedPcmChunk(Uint8List chunk) {
    final stream = _stream;
    final recognizer = _recognizer;
    if (stream == null || recognizer == null) return;
    if (chunk.lengthInBytes < 2) return;
    final sampleCount = chunk.lengthInBytes ~/ 2;
    final int16 = Int16List.view(
        chunk.buffer, chunk.offsetInBytes, sampleCount);
    final f32 = Float32List(sampleCount);
    for (var i = 0; i < sampleCount; i++) {
      f32[i] = int16[i] / 32768.0;
    }
    stream.acceptWaveform(samples: f32, sampleRate: _sampleRate);
    while (recognizer.isReady(stream)) {
      recognizer.decode(stream);
    }
    if (_settings.showPartialResults) {
      final text = recognizer.getResult(stream).text.trim();
      if (text.isNotEmpty && text != _lastPartial) {
        _lastPartial = text;
        onResult?.call(STTResult(text: text, isFinal: false));
      }
    }
  }

  /// Stop listening and emit the final result
  Future<void> stopListening() async {
    if (!_isListening) return;
    try {
      final stream = _stream;
      final recognizer = _recognizer;
      if (stream != null && recognizer != null) {
        stream.inputFinished();
        while (recognizer.isReady(stream)) {
          recognizer.decode(stream);
        }
        final text = recognizer.getResult(stream).text.trim();
        await _teardown(emitStopped: true);
        if (text.isNotEmpty) {
          onResult?.call(STTResult(text: text, isFinal: true));
        }
      } else {
        await _teardown(emitStopped: true);
      }
    } catch (e) {
      await _teardown(emitStopped: true);
      onError?.call('STT stop error: $e');
    }
  }

  /// Toggle listening
  Future<void> toggleListening() async {
    if (_isListening) {
      await stopListening();
    } else {
      await startListening();
    }
  }

  /// Cancel listening (discard results)
  Future<void> cancelListening() async {
    if (!_isListening) return;
    try {
      await _teardown(emitStopped: true, discard: true);
    } catch (e) {
      await _teardown(emitStopped: true, discard: true);
      onError?.call('STT cancel error: $e');
    }
  }

  Future<void> _teardown(
      {required bool emitStopped, bool discard = false}) async {
    await _audioSub?.cancel();
    _audioSub = null;
    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (_) {
      // The recorder may have already stopped on its own
    }
    _stream?.free();
    _stream = null;
    _lastPartial = '';
    _isListening = false;
    if (emitStopped) {
      onListeningStopped?.call();
    }
    debugPrint(discard ? 'STT: Cancelled listening' : 'STT: Stopped listening');
  }

  /// Dispose the service
  void dispose() {
    _teardown(emitStopped: false);
    _recognizer?.free();
    _recognizer = null;
    _isInitialized = false;
  }
}
