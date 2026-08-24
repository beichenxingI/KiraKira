import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/domain/services/tts_service.dart';
import 'package:kirakira/presentation/providers/tts_providers.dart';
import 'package:kirakira/presentation/theme/app_theme.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/widgets/common/common.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';

/// Screen for TTS settings
class TTSSettingsScreen extends ConsumerWidget {
  const TTSSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(ttsSettingsProvider);
    final isSpeaking = ref.watch(ttsSpeakingProvider);
    final voicesAsync = ref.watch(availableVoicesProvider);
    final iconBg = Theme.of(context).colorScheme.primary.withValues(alpha: 0.12);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(
              l10n.textToSpeech,
              style: Theme.of(context).textTheme.displayLarge,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.restore),
                tooltip: l10n.resetToDefaults,
                onPressed: () {
                  ref.read(ttsSettingsProvider.notifier).reset();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.settingsResetToDefaults)),
                  );
                },
              ),
            ],
          ),

          // ── 通用 ──
          SliverToBoxAdapter(
            child: KiraSection(
              title: l10n.general,
              children: [
                KiraSwitchTile(
                  title: l10n.enableTts,
                  subtitle: l10n.readAiResponsesAloud,
                  value: settings.enabled,
                  onChanged: (value) {
                    ref.read(ttsSettingsProvider.notifier).setEnabled(value);
                  },
                ),
                KiraSwitchTile(
                  title: l10n.autoPlay,
                  subtitle: l10n.automaticallyPlayResponses,
                  value: settings.autoPlay,
                  onChanged: settings.enabled
                      ? (value) {
                          ref.read(ttsSettingsProvider.notifier).setAutoPlay(value);
                        }
                      : null,
                ),
                KiraSwitchTile(
                  title: '消息队列',
                  subtitle: '排队多条消息而非打断',
                  value: settings.queueMessages,
                  onChanged: settings.enabled
                      ? (value) {
                          ref.read(ttsSettingsProvider.notifier).setQueueMessages(value);
                        }
                      : null,
                ),
              ],
            ),
          ),

          // ── 提供商 ──
          SliverToBoxAdapter(
            child: KiraSection(
              title: l10n.provider,
              children: [
                KiraGroupedTile(
                  title: l10n.ttsProvider,
                  subtitle: settings.provider.displayName,
                  trailing: DropdownButton<TTSProvider>(
                    value: settings.provider,
                    underline: const SizedBox.shrink(),
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
                if (settings.provider != TTSProvider.system)
                  KiraGroupedTile(
                    title: l10n.apiKey,
                    subtitle: settings.apiKey?.isNotEmpty == true
                        ? '••••••••${settings.apiKey!.substring(settings.apiKey!.length - 4)}'
                        : l10n.notConfigured,
                    onTap: settings.enabled
                        ? () => _showApiKeySheet(context, ref, settings)
                        : null,
                  ),
              ],
            ),
          ),

          // ── 三音色：正文/对话/旁白 各自独立配置 ──
          SliverToBoxAdapter(
            child: _buildVoiceStyleSection(
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
          ),

          SliverToBoxAdapter(
            child: _buildVoiceStyleSection(
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
          ),

          SliverToBoxAdapter(
            child: _buildVoiceStyleSection(
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
          ),

          // ── 全局音量（三音色共用）──
          SliverToBoxAdapter(
            child: KiraSection(
              title: '音量',
              children: [
                _SliderRow(
                  title: '音量',
                  valueLabel: '${(settings.volume * 100).round()}%',
                  value: settings.volume,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  onChanged: settings.enabled
                      ? (value) {
                          ref.read(ttsSettingsProvider.notifier).setVolume(value);
                        }
                      : null,
                ),
              ],
            ),
          ),

          // ── 测试 ──
          SliverToBoxAdapter(
            child: KiraSection(
              title: l10n.test,
              children: [
                KiraGroupedTile(
                  icon: isSpeaking ? CupertinoIcons.stop_fill : CupertinoIcons.play_fill,
                  iconBg: iconBg,
                  title: isSpeaking ? l10n.stopListening : l10n.testVoice,
                  subtitle: l10n.testVoice,
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
          ),

          // ── 信息 ──
          SliverToBoxAdapter(
            child: KiraSection.plain(
              title: l10n.information,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceMd,
                  vertical: DesignTokens.spaceSm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _InfoRow(
                      icon: CupertinoIcons.info,
                      title: '关于语音合成',
                      text: 'Text-to-Speech allows you to hear messages read aloud. '
                          'You can configure different voices for different characters '
                          'in the character settings.',
                    ),
                    if (settings.provider == TTSProvider.system)
                      const _InfoRow(
                        icon: CupertinoIcons.device_phone_portrait,
                        title: '系统语音合成',
                        text: 'Using your device\'s built-in text-to-speech engine. '
                            'Available voices depend on your system settings.',
                      ),
                    if (settings.provider == TTSProvider.elevenlabs)
                      const _InfoRow(
                        icon: CupertinoIcons.cloud,
                        title: 'ElevenLabs',
                        text: 'High-quality AI voices. Requires an API key from elevenlabs.io',
                      ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: DesignTokens.spaceXl)),
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
    return KiraSection(
      title: title,
      children: [
        KiraSwitchTile(
          title: '朗读$label',
          value: style.enabled,
          onChanged: globalEnabled
              ? (v) => onChanged(style.copyWith(enabled: v))
              : null,
        ),
        // 音色下拉
        voicesAsync.when(
          data: (voices) {
            if (voices.isEmpty) {
              return const KiraGroupedTile(
                title: '音色',
                subtitle: '无可用语音',
              );
            }
            final current = (style.voiceId != null &&
                    voices.any((v) => v.id == style.voiceId))
                ? style.voiceId
                : voices.first.id;
            return KiraGroupedTile(
              title: '音色',
              trailing: DropdownButton<String>(
                value: current,
                underline: const SizedBox.shrink(),
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
          loading: () => const KiraGroupedTile(
            title: '音色',
            subtitle: '正在加载语音...',
          ),
          error: (_, __) => const KiraGroupedTile(
            title: '音色',
            subtitle: '加载语音失败',
          ),
        ),
        // 语速
        _SliderRow(
          title: '语速',
          valueLabel: '${style.rate.toStringAsFixed(1)}x',
          value: style.rate,
          min: 0.5,
          max: 2.0,
          divisions: 15,
          onChanged: active
              ? (value) => onChanged(style.copyWith(rate: value))
              : null,
        ),
        // 音调
        _SliderRow(
          title: '音调',
          valueLabel: '${style.pitch.toStringAsFixed(1)}x',
          value: style.pitch,
          min: 0.5,
          max: 2.0,
          divisions: 15,
          onChanged: active
              ? (value) => onChanged(style.copyWith(pitch: value))
              : null,
        ),
      ],
    );
  }

  /// API Key 单字段表单 → 底部 Sheet(isScrollControlled + 键盘避让,抄 ai_presets_screen)
  void _showApiKeySheet(BuildContext context, WidgetRef ref, TTSSettings settings) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: settings.apiKey);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusBottomSheet),
        ),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${settings.provider.displayName} ${l10n.apiKey}',
                style: const TextStyle(
                  fontSize: DesignTokens.fontSizeHeadline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: DesignTokens.spaceMd),
              CupertinoTextField(
                controller: controller,
                autofocus: true,
                obscureText: true,
                placeholder: l10n.enterApiKey,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(sheetCtx).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusGroupedCard),
                ),
              ),
              const SizedBox(height: DesignTokens.spaceMd),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    // 写入逻辑与原 AlertDialog 完全一致
                    ref.read(ttsSettingsProvider.notifier).setApiKey(controller.text);
                    Navigator.pop(sheetCtx);
                  },
                  child: Text(l10n.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 组内滑块行:标题 + 当前值 + Slider(KiraSection 内自动插分隔线)
class _SliderRow extends StatelessWidget {
  final String title;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double>? onChanged;

  const _SliderRow({
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceMd,
        vertical: DesignTokens.spaceXs,
      ),
      child: Column(
        children: [
          const SizedBox(height: DesignTokens.spaceXs),
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeBodyLarge,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ),
              Text(
                valueLabel,
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeSm,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: valueLabel,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// 信息行:图标 + 标题 + 多行说明(分组卡内,替代原 ListTile)
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: theme.textTheme.bodyMedium?.color),
          const SizedBox(width: DesignTokens.spaceSm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeBodyLarge,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: DesignTokens.spaceXxs),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeSm,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
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
