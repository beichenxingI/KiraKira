import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/domain/services/tts_service.dart';
import 'package:kirakira/presentation/providers/tts_providers.dart';
import 'package:kirakira/presentation/theme/app_theme.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';

/// Screen for TTS settings
class TTSSettingsScreen extends ConsumerWidget {
  const TTSSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(ttsSettingsProvider);
    final isSpeaking = ref.watch(ttsSpeakingProvider);
    final voicesAsync = ref.watch(availableVoicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.textToSpeech),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: AppLocalizations.of(context)!.resetToDefaults,
            onPressed: () {
              ref.read(ttsSettingsProvider.notifier).reset();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.of(context)!.settingsResetToDefaults)),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(DesignTokens.spaceMd),
        children: [
          // Enable/Disable toggle
          _buildSection(
            context,
            title: AppLocalizations.of(context)!.general,
            children: [
              SwitchListTile(
                title: Text(AppLocalizations.of(context)!.enableTts),
                subtitle: Text(AppLocalizations.of(context)!.readAiResponsesAloud),
                value: settings.enabled,
                onChanged: (value) {
                  ref.read(ttsSettingsProvider.notifier).setEnabled(value);
                },
              ),
              SwitchListTile(
                title: Text(AppLocalizations.of(context)!.autoPlay),
                subtitle: Text(AppLocalizations.of(context)!.automaticallyPlayResponses),
                value: settings.autoPlay,
                onChanged: settings.enabled
                    ? (value) {
                        ref.read(ttsSettingsProvider.notifier).setAutoPlay(value);
                      }
                    : null,
              ),
              SwitchListTile(
                title: const Text('消息队列'),
                subtitle: const Text('排队多条消息而非打断'),
                value: settings.queueMessages,
                onChanged: settings.enabled
                    ? (value) {
                        ref.read(ttsSettingsProvider.notifier).setQueueMessages(value);
                      }
                    : null,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Provider selection
          _buildSection(
            context,
            title: AppLocalizations.of(context)!.provider,
            children: [
              ListTile(
                title: Text(AppLocalizations.of(context)!.ttsProvider),
                subtitle: Text(settings.provider.displayName),
                trailing: DropdownButton<TTSProvider>(
                  value: settings.provider,
                  onChanged: settings.enabled
                      ? (value) {
                          if (value != null) {
                            ref.read(ttsSettingsProvider.notifier).setProvider(value);
                          }
                        }
                      : null,
                  items: TTSProvider.values.map((provider) {
                    return DropdownMenuItem(
                      value: provider,
                      child: Text(provider.displayName),
                    );
                  }).toList(),
                ),
              ),
              if (settings.provider != TTSProvider.system) ...[
                ListTile(
                  title: Text(AppLocalizations.of(context)!.apiKey),
                  subtitle: Text(
                    settings.apiKey?.isNotEmpty == true
                        ? '••••••••${settings.apiKey!.substring(settings.apiKey!.length - 4)}'
                        : AppLocalizations.of(context)!.notConfigured,
                  ),
                  trailing: const Icon(Icons.edit),
                  onTap: settings.enabled
                      ? () => _showApiKeyDialog(context, ref, settings)
                      : null,
                ),
              ],
            ],
          ),

          const SizedBox(height: 16),

          // ── 三音色：正文/对话/旁白 各自独立配置 ──
          _buildVoiceStyleSection(
            context,
            ref,
            title: '正文声音（叙述）',
            label: '正文',
            globalEnabled: settings.enabled,
            style: settings.narrationVoice,
            voicesAsync: voicesAsync,
            onChanged: (s) =>
                ref.read(ttsSettingsProvider.notifier).setNarrationVoice(s),
          ),

          const SizedBox(height: 16),

          _buildVoiceStyleSection(
            context,
            ref,
            title: '对话声音（引号内）',
            label: '对话',
            globalEnabled: settings.enabled,
            style: settings.dialogueVoice,
            voicesAsync: voicesAsync,
            onChanged: (s) =>
                ref.read(ttsSettingsProvider.notifier).setDialogueVoice(s),
          ),

          const SizedBox(height: 16),

          _buildVoiceStyleSection(
            context,
            ref,
            title: '旁白声音（括号内）',
            label: '旁白',
            globalEnabled: settings.enabled,
            style: settings.asideVoice,
            voicesAsync: voicesAsync,
            onChanged: (s) =>
                ref.read(ttsSettingsProvider.notifier).setAsideVoice(s),
          ),

          const SizedBox(height: 16),

          // 全局音量（三音色共用）
          _buildSection(
            context,
            title: '音量',
            children: [
              ListTile(
                title: const Text('音量'),
                subtitle: Slider(
                  value: settings.volume,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  label: '${(settings.volume * 100).round()}%',
                  onChanged: settings.enabled
                      ? (value) {
                          ref.read(ttsSettingsProvider.notifier).setVolume(value);
                        }
                      : null,
                ),
                trailing: Text(
                  '${(settings.volume * 100).round()}%',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Test section
          _buildSection(
            context,
            title: AppLocalizations.of(context)!.test,
            children: [
              ListTile(
                leading: Icon(
                  isSpeaking ? Icons.stop : Icons.play_arrow,
                  color: AppTheme.accentColor,
                ),
                title: Text(isSpeaking ? AppLocalizations.of(context)!.stopListening : AppLocalizations.of(context)!.testVoice),
                subtitle: Text(AppLocalizations.of(context)!.testVoice),
                onTap: settings.enabled
                    ? () async {
                        if (isSpeaking) {
                          await ref.read(ttsStopProvider)();
                        } else {
                          await ref.read(ttsSpeakProvider)(
                            '她轻轻推开门（心里有些紧张），'
                            '“你终于来了。”她轻声说道。',
                          );
                        }
                      }
                    : null,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Info section
          _buildSection(
            context,
            title: AppLocalizations.of(context)!.information,
            children: [
              const ListTile(
                leading: Icon(Icons.info_outline, color: AppTheme.accentColor),
                title: Text('关于语音合成'),
                subtitle: Text(
                  'Text-to-Speech allows you to hear messages read aloud. '
                  'You can configure different voices for different characters '
                  'in the character settings.',
                ),
              ),
              if (settings.provider == TTSProvider.system)
                const ListTile(
                  leading: Icon(Icons.phone_android, color: AppTheme.textMuted),
                  title: Text('系统语音合成'),
                  subtitle: Text(
                    'Using your device\'s built-in text-to-speech engine. '
                    'Available voices depend on your system settings.',
                  ),
                ),
              if (settings.provider == TTSProvider.elevenlabs)
                const ListTile(
                  leading: Icon(Icons.cloud, color: AppTheme.textMuted),
                  title: Text('ElevenLabs'),
                  subtitle: Text(
                    'High-quality AI voices. Requires an API key from elevenlabs.io',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
  /// 单个音色配置区（正文/对话/旁白复用）
  Widget _buildVoiceStyleSection(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String label,
    required bool globalEnabled,
    required VoiceStyle style,
    required AsyncValue<List<TTSVoice>> voicesAsync,
    required ValueChanged<VoiceStyle> onChanged,
  }) {
    final active = globalEnabled && style.enabled;
    return _buildSection(
      context,
      title: title,
      children: [
        SwitchListTile(
          title: Text('朗读$label'),
          value: style.enabled,
          onChanged: globalEnabled
              ? (v) => onChanged(style.copyWith(enabled: v))
              : null,
        ),
        // 音色下拉
        voicesAsync.when(
          data: (voices) {
            if (voices.isEmpty) {
              return const ListTile(
                  title: Text('音色'), subtitle: Text('无可用语音'));
            }
            final current = (style.voiceId != null &&
                    voices.any((v) => v.id == style.voiceId))
                ? style.voiceId
                : voices.first.id;
            return ListTile(
              title: const Text('音色'),
              trailing: DropdownButton<String>(
                value: current,
                onChanged: active
                    ? (value) => onChanged(style.copyWith(voiceId: value))
                    : null,
                items: voices
                    .map((v) => DropdownMenuItem(
                        value: v.id, child: Text(v.name)))
                    .toList(),
              ),
            );
          },
          loading: () => const ListTile(
              title: Text('音色'), subtitle: Text('正在加载语音...')),
          error: (_, __) => const ListTile(
              title: Text('音色'), subtitle: Text('加载语音失败')),
        ),
        // 语速
        ListTile(
          title: const Text('语速'),
          subtitle: Slider(
            value: style.rate,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            label: '${style.rate.toStringAsFixed(1)}x',
            onChanged: active
                ? (value) => onChanged(style.copyWith(rate: value))
                : null,
          ),
          trailing: Text('${style.rate.toStringAsFixed(1)}x',
              style: const TextStyle(color: AppTheme.textSecondary)),
        ),
        // 音调
        ListTile(
          title: const Text('音调'),
          subtitle: Slider(
            value: style.pitch,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            label: '${style.pitch.toStringAsFixed(1)}x',
            onChanged: active
                ? (value) => onChanged(style.copyWith(pitch: value))
                : null,
          ),
          trailing: Text('${style.pitch.toStringAsFixed(1)}x',
              style: const TextStyle(color: AppTheme.textSecondary)),
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(DesignTokens.spaceMd, DesignTokens.spaceMd, DesignTokens.spaceMd, DesignTokens.spaceSm),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: DesignTokens.fontSizeBodyMedium,
                fontWeight: FontWeight.bold,
                color: AppTheme.accentColor,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  void _showApiKeyDialog(BuildContext context, WidgetRef ref, TTSSettings settings) {
    final controller = TextEditingController(text: settings.apiKey);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${settings.provider.displayName} ${AppLocalizations.of(context)!.apiKey}'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.apiKey,
            hintText: AppLocalizations.of(context)!.enterApiKey,
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(ttsSettingsProvider.notifier).setApiKey(controller.text);
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
    );
  }
}

/// Widget for TTS button in chat messages
class TTSMessageButton extends ConsumerWidget {
  final String text;
  final String? characterId;
  final double size;

  const TTSMessageButton({
    super.key,
    required this.text,
    this.characterId,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(ttsSettingsProvider);
    final isSpeaking = ref.watch(ttsSpeakingProvider);

    if (!settings.enabled) return const SizedBox.shrink();

    return IconButton(
      icon: Icon(
        isSpeaking ? Icons.stop : Icons.volume_up,
        size: size,
      ),
      tooltip: isSpeaking ? 'Stop' : 'Read aloud',
      onPressed: () async {
        if (isSpeaking) {
          await ref.read(ttsStopProvider)();
        } else {
          await ref.read(ttsSpeakProvider)(text, characterId: characterId);
        }
      },
    );
  }
}

/// Compact TTS controls for chat
class TTSControls extends ConsumerWidget {
  const TTSControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(ttsSettingsProvider);
    final isSpeaking = ref.watch(ttsSpeakingProvider);

    if (!settings.enabled) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isSpeaking)
          IconButton(
            icon: const Icon(Icons.stop, size: 20),
            tooltip: '停止朗读',
            onPressed: () => ref.read(ttsStopProvider)(),
          ),
        Icon(
          Icons.volume_up,
          size: 16,
          color: settings.enabled ? AppTheme.accentColor : AppTheme.textMuted,
        ),
      ],
    );
  }
}
