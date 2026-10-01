/// TTS backend abstract interface
///
/// All TTS engines (system/local/cloud) must implement this interface.
/// TTSService routes to the concrete backend by provider.
abstract class TtsBackend {
  /// Initializes the engine (loads models / validates API key etc.)
  Future<void> initialize();

  /// Gets the available voice list, returns the unified [{value, label}] format
  List<Map<String, String>> getAvailableVoices();

  /// Speaks a single segment of text (awaits until playback completes)
  ///
  /// [text] cleaned text (_cleanTextForTTS output)
  /// [voiceId] voice ID (system: "name|locale"; sherpa: sid; cloud: voice name)
  /// [rate] speech rate 0.5-2.0
  /// [pitch] pitch 0.5-2.0 (ignored by some backends)
  /// [volume] volume 0.0-1.0
  Future<void> speak(
    String text, {
    String? voiceId,
    double rate = 1.0,
    double pitch = 1.0,
    double volume = 1.0,
  });

  /// Stops the current playback
  Future<void> stop();

  /// Pauses (if the engine supports it)
  Future<void> pause();

  /// Resumes (if the engine supports it)
  Future<void> resume();

  /// Releases resources (sherpa's free / no-op for cloud)
  Future<void> dispose();

  /// Whether this is a local engine (affects UI hints)
  bool get isLocal;

  /// Engine display name
  String get displayName;

  /// Whether pitch control is supported (sherpa does not support it; the UI hides the pitch slider)
  bool get supportsPitch => true;

  /// Whether speech rate control is supported
  bool get supportsRate => true;

  /// Engine-specific configuration hint (shown in the UI)
  String get configHint => '';
}
