import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kirakira/domain/services/tts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for TTS service
final ttsServiceProvider = Provider<TTSService>((ref) {
  final service = TTSService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for TTS settings
final ttsSettingsProvider = StateNotifierProvider<TTSSettingsNotifier, TTSSettings>((ref) {
  return TTSSettingsNotifier(ref.watch(ttsServiceProvider), ref);
});

/// Notifier for TTS settings
class TTSSettingsNotifier extends StateNotifier<TTSSettings> {
  static const _prefsKey = 'tts_settings';
  static const _secureKeyApiKey = 'tts_api_key'; // apiKey stored separately in secure storage
  final TTSService _service;
  final Ref _ref;
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  TTSSettingsNotifier(this._service, this._ref) : super(const TTSSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null) {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        // apiKey is read from secure storage first; legacy plaintext is migrated once
        final legacyKey = json['apiKey'] as String?;
        String? secureKey;
        try {
          secureKey = await _secure.read(key: _secureKeyApiKey);
          if (secureKey == null && legacyKey != null && legacyKey.isNotEmpty) {
            await _secure.write(key: _secureKeyApiKey, value: legacyKey);
            json['apiKey'] = null;
            await prefs.setString(_prefsKey, jsonEncode(json));
          }
        } catch (_) {
          // Secure storage unavailable (test env / no security module); fall back to plaintext
        }
        json['apiKey'] = secureKey ?? legacyKey;
        state = TTSSettings.fromJson(json);
        _service.updateSettings(state);
      }
    } catch (e) {
      // Use default settings on error
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = state.toJson();
      // apiKey prefers secure storage; on failure it stays plaintext (test env compatibility)
      final apiKey = json['apiKey'] as String?;
      if (apiKey != null && apiKey.isNotEmpty) {
        try {
          await _secure.write(key: _secureKeyApiKey, value: apiKey);
          json.remove('apiKey'); // secure available, so prefs do not keep the key
        } catch (_) {
          // Secure unavailable; keep plaintext in prefs (test env compatibility)
        }
      }
      await prefs.setString(_prefsKey, jsonEncode(json));
      _service.updateSettings(state);
    } catch (e) {
      // Ignore save errors
    }
  }

  void setEnabled(bool enabled) {
    state = state.copyWith(enabled: enabled);
    _saveSettings();
  }

  void setProvider(TTSProvider provider) {
    state = state.copyWith(provider: provider);
    _service.updateSettings(state);  // sync the service immediately
    _saveSettings();  // persist asynchronously
    _ref.invalidate(availableVoicesProvider);  // refresh the voice list
  }
  void setVoiceId(String? voiceId) {
    state = state.copyWith(voiceId: voiceId);
    _saveSettings();
  }

  void setRate(double rate) {
    state = state.copyWith(rate: rate.clamp(0.5, 2.0));
    _saveSettings();
  }

  void setPitch(double pitch) {
    state = state.copyWith(pitch: pitch.clamp(0.5, 2.0));
    _saveSettings();
  }

  void setVolume(double volume) {
    state = state.copyWith(volume: volume.clamp(0.0, 1.0));
    _saveSettings();
  }

  void setAutoPlay(bool autoPlay) {
    state = state.copyWith(autoPlay: autoPlay);
    _saveSettings();
  }

  void setQueueMessages(bool queue) {
    state = state.copyWith(queueMessages: queue);
    _saveSettings();
  }

  void setApiKey(String? apiKey) {
    state = state.copyWith(apiKey: apiKey);
    _saveSettings();
  }

  void setApiEndpoint(String? endpoint) {
    state = state.copyWith(apiEndpoint: endpoint);
    _saveSettings();
  }

  void setSherpaModelName(String? modelName) {
    state = state.copyWith(sherpaModelName: modelName);
    _saveSettings();
  }

  void setQwenModel(String? model) {
    state = state.copyWith(qwenModel: model);
    _saveSettings();
  }

  // -- Three voice setters: narration / dialogue / aside --
  void setNarrationVoice(VoiceStyle style) {
    state = state.copyWith(narrationVoice: style);
    _saveSettings();
  }

  void setDialogueVoice(VoiceStyle style) {
    state = state.copyWith(dialogueVoice: style);
    _saveSettings();
  }

  void setAsideVoice(VoiceStyle style) {
    state = state.copyWith(asideVoice: style);
    _saveSettings();
  }
  void reset() {
    state = const TTSSettings();
    _saveSettings();
  }
}

/// Provider for character voice settings
final characterVoiceSettingsProvider = StateNotifierProvider.family<
    CharacterVoiceSettingsNotifier, CharacterVoiceSettings?, String>((ref, characterId) {
  final service = ref.watch(ttsServiceProvider);
  return CharacterVoiceSettingsNotifier(service, characterId);
});

/// Notifier for character voice settings
class CharacterVoiceSettingsNotifier extends StateNotifier<CharacterVoiceSettings?> {
  final TTSService _service;
  final String characterId;

  CharacterVoiceSettingsNotifier(this._service, this.characterId)
      : super(null) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('character_voice_$characterId');
      if (jsonStr != null) {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        state = CharacterVoiceSettings.fromJson(json);
        if (state != null) {
          _service.setCharacterVoice(state!);
        }
      }
    } catch (e) {
      // Use default settings on error
    }
  }

  Future<void> _saveSettings() async {
    if (state == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(state!.toJson());
      await prefs.setString('character_voice_$characterId', jsonStr);
      _service.setCharacterVoice(state!);
    } catch (e) {
      // Ignore save errors
    }
  }

  void setVoiceId(String? voiceId) {
    state = CharacterVoiceSettings(
      characterId: characterId,
      voiceId: voiceId,
      rate: state?.rate,
      pitch: state?.pitch,
      volume: state?.volume,
    );
    _saveSettings();
  }

  void setRate(double? rate) {
    state = CharacterVoiceSettings(
      characterId: characterId,
      voiceId: state?.voiceId,
      rate: rate?.clamp(0.5, 2.0),
      pitch: state?.pitch,
      volume: state?.volume,
    );
    _saveSettings();
  }

  void setPitch(double? pitch) {
    state = CharacterVoiceSettings(
      characterId: characterId,
      voiceId: state?.voiceId,
      rate: state?.rate,
      pitch: pitch?.clamp(0.5, 2.0),
      volume: state?.volume,
    );
    _saveSettings();
  }

  void setVolume(double? volume) {
    state = CharacterVoiceSettings(
      characterId: characterId,
      voiceId: state?.voiceId,
      rate: state?.rate,
      pitch: state?.pitch,
      volume: volume?.clamp(0.0, 1.0),
    );
    _saveSettings();
  }

  void clear() {
    state = null;
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('character_voice_$characterId');
    });
  }
}

/// Provider for TTS speaking state
final ttsSpeakingProvider = StateProvider<bool>((ref) => false);

/// Provider for available voices
final availableVoicesProvider = FutureProvider<List<TTSVoice>>((ref) async {
  final service = ref.watch(ttsServiceProvider);
  ref.watch(ttsSettingsProvider); // forces a dependency on settings so voices are re-queried when the provider changes
  await service.initialize();
  return service.availableVoices;
});

/// TTS action provider for speaking text
final ttsSpeakProvider = Provider<Future<void> Function(String, {String? characterId})>((ref) {
  final service = ref.watch(ttsServiceProvider);
  final settings = ref.watch(ttsSettingsProvider);
  
  return (String text, {String? characterId}) async {
    if (!settings.enabled) return;
    
    await service.initialize();
    ref.read(ttsSpeakingProvider.notifier).state = true;
    
    service.onComplete = () {
      ref.read(ttsSpeakingProvider.notifier).state = false;
    };
    service.onCancel = () {
      ref.read(ttsSpeakingProvider.notifier).state = false;
    };
    service.onError = (error) {
      ref.read(ttsSpeakingProvider.notifier).state = false;
    };
    
    await service.speakByStyle(text);
  };
});

/// TTS stop provider
final ttsStopProvider = Provider<Future<void> Function()>((ref) {
  final service = ref.watch(ttsServiceProvider);
  
  return () async {
    await service.stop();
    ref.read(ttsSpeakingProvider.notifier).state = false;
  };
});
