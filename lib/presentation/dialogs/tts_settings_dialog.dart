// lib/presentation/dialogs/tts_settings_dialog.dart
/// TTS 合成设置浮窗(极客Core迁移 P1)
/// 内容完整迁自 tts_settings_screen.dart,字段一个不少:
/// 通用(启用/自动播放/消息队列) · 提供商(引擎/API密钥)
/// 三音色(正文/对话/旁白:朗读开关/音色/语速/音调) · 全局音量
/// 测试试听 · 信息说明 · 恢复默认
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/domain/services/tts_service.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/providers/tts_providers.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'core_dialog.dart';

Future<void> showTtsSettingsDialog(BuildContext context, WidgetRef ref) {
  return showCoreDialog(
    context,
    builder: (_) => const _TtsSettingsDialog(),
  );
}

class _TtsSettingsDialog extends ConsumerWidget {
  const _TtsSettingsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CoreDialogPalette(isDark: isDark);
    final settings = ref.watch(ttsSettingsProvider);
    final isSpeaking = ref.watch(ttsSpeakingProvider);
    final voicesAsync = ref.watch(availableVoicesProvider);

    return CoreDialogShell(
      title: 'TTS 合成设置',
      icon: CupertinoIcons.speaker_2,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 通用 ──
          CoreSectionLabel(l10n.general),
          const SizedBox(height: 4),
          _Group(
            palette: palette,
            children: [
              CoreSwitchRow(
                title: l10n.enableTts,
                subtitle: l10n.readAiResponsesAloud,
                value: settings.enabled,
                palette: palette,
                onChanged: (v) =>
                    ref.read(ttsSettingsProvider.notifier).setEnabled(v),
              ),
              CoreSwitchRow(
                title: l10n.autoPlay,
                subtitle: l10n.automaticallyPlayResponses,
                value: settings.autoPlay,
                palette: palette,
                onChanged: settings.enabled
                    ? (v) => ref
                        .read(ttsSettingsProvider.notifier)
                        .setAutoPlay(v)
                    : null,
              ),
              CoreSwitchRow(
                title: '消息队列',
                subtitle: '排队多条消息而非打断',
                value: settings.queueMessages,
                palette: palette,
                onChanged: settings.enabled
                    ? (v) => ref
                        .read(ttsSettingsProvider.notifier)
                        .setQueueMessages(v)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── 提供商 ──
          CoreSectionLabel(l10n.provider),
          const SizedBox(height: 4),
          _Group(
            palette: palette,
            children: [
              _DropdownTile(
                palette: palette,
                title: l10n.ttsProvider,
                subtitle: settings.provider.displayName,
                child: DropdownButton<TTSProvider>(
                  value: settings.provider,
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(8),
                  dropdownColor: palette.surface,
                  iconEnabledColor: palette.textSecondary,
                  onChanged: settings.enabled
                      ? (value) {
                          if (value != null) {
                            ref
                                .read(ttsSettingsProvider.notifier)
                                .setProvider(value);
                          }
                        }
                      : null,
                  items: TTSProvider.values.map((provider) {
                    return DropdownMenuItem(
                      value: provider,
                      child: Text(
                        provider.displayName,
                        style: TextStyle(fontSize: 14, color: palette.textPrimary),
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (settings.provider != TTSProvider.system)
                CoreTile(
                  title: l10n.apiKey,
                  subtitle: settings.apiKey?.isNotEmpty == true
                      ? '••••••••${settings.apiKey!.substring(settings.apiKey!.length - 4)}'
                      : l10n.notConfigured,
                  onTap: settings.enabled
                      ? () => _showApiKeySheet(context, ref, settings, palette)
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 20),

          // ── 三音色 ──
          _buildVoiceStyleSection(
            context,
            ref,
            palette,
            title: '正文声音（叙述）',
            label: '正文',
            globalEnabled: settings.enabled,
            style: settings.narrationVoice,
            voicesAsync: voicesAsync,
            onChanged: (s) => ref
                .read(ttsSettingsProvider.notifier)
                .setNarrationVoice(s),
          ),
          _buildVoiceStyleSection(
            context,
            ref,
            palette,
            title: '对话声音（引号内）',
            label: '对话',
            globalEnabled: settings.enabled,
            style: settings.dialogueVoice,
            voicesAsync: voicesAsync,
            onChanged: (s) => ref
                .read(ttsSettingsProvider.notifier)
                .setDialogueVoice(s),
          ),
          _buildVoiceStyleSection(
            context,
            ref,
            palette,
            title: '旁白声音（括号内）',
            label: '旁白',
            globalEnabled: settings.enabled,
            style: settings.asideVoice,
            voicesAsync: voicesAsync,
            onChanged: (s) =>
                ref.read(ttsSettingsProvider.notifier).setAsideVoice(s),
          ),
          const SizedBox(height: 20),

          // ── 全局音量 ──
          CoreSectionLabel('音量'),
          const SizedBox(height: 4),
          _Group(
            palette: palette,
            child: _SliderRow(
              palette: palette,
              title: '音量',
              valueLabel: '${(settings.volume * 100).round()}%',
              value: settings.volume,
              min: 0.0,
              max: 1.0,
              divisions: 10,
              onChanged: settings.enabled
                  ? (value) => ref
                      .read(ttsSettingsProvider.notifier)
                      .setVolume(value)
                  : null,
            ),
          ),
          const SizedBox(height: 20),

          // ── 测试 ──
          CoreSectionLabel(l10n.test),
          const SizedBox(height: 8),
          CoreSecondaryButton(
            label: isSpeaking ? l10n.stopListening : l10n.testVoice,
            icon: isSpeaking ? CupertinoIcons.stop_fill : CupertinoIcons.play_fill,
            onPressed: settings.enabled
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
          const SizedBox(height: 20),

          // ── 信息 ──
          CoreSectionLabel(l10n.information),
          const SizedBox(height: 4),
          CoreInfoRow(
            icon: CupertinoIcons.info,
            title: '关于语音合成',
            text: 'Text-to-Speech allows you to hear messages read aloud. '
                'You can configure different voices for different characters '
                'in the character settings.',
            palette: palette,
          ),
          if (settings.provider == TTSProvider.system)
            CoreInfoRow(
              icon: CupertinoIcons.device_phone_portrait,
              title: '系统语音合成',
              text: 'Using your device\'s built-in text-to-speech engine. '
                  'Available voices depend on your system settings.',
              palette: palette,
            ),
          if (settings.provider == TTSProvider.elevenlabs)
            CoreInfoRow(
              icon: CupertinoIcons.cloud,
              title: 'ElevenLabs',
              text: 'High-quality AI voices. Requires an API key from elevenlabs.io',
              palette: palette,
            ),
          const SizedBox(height: 20),

          // ── 恢复默认 ──
          CoreSecondaryButton(
            label: l10n.resetToDefaults,
            icon: CupertinoIcons.arrow_counterclockwise,
            onPressed: () {
              ref.read(ttsSettingsProvider.notifier).reset();
              coreToast(context, l10n.settingsResetToDefaults);
            },
          ),
        ],
      ),
    );
  }

  /// 单个音色配置区(正文/对话/旁白复用,字段与原页一致)
  Widget _buildVoiceStyleSection(
    BuildContext context,
    WidgetRef ref,
    CoreDialogPalette palette, {
    required String title,
    required String label,
    required bool globalEnabled,
    required VoiceStyle style,
    required AsyncValue<List<TTSVoice>> voicesAsync,
    required ValueChanged<VoiceStyle> onChanged,
  }) {
    final active = globalEnabled && style.enabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CoreSectionLabel(title),
        const SizedBox(height: 4),
        _Group(
          palette: palette,
          children: [
            CoreSwitchRow(
              title: '朗读$label',
              value: style.enabled,
              palette: palette,
              onChanged: globalEnabled
                  ? (v) => onChanged(style.copyWith(enabled: v))
                  : null,
            ),
            voicesAsync.when(
              data: (voices) {
                if (voices.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      '音色：无可用语音',
                      style: TextStyle(fontSize: 13, color: palette.textSecondary),
                    ),
                  );
                }
                final current = (style.voiceId != null &&
                        voices.any((v) => v.id == style.voiceId))
                    ? style.voiceId
                    : voices.first.id;
                return _DropdownTile(
                  palette: palette,
                  title: '音色',
                  subtitle: voices.firstWhere((v) => v.id == current,
                      orElse: () => voices.first)
                      .name,
                  child: DropdownButton<String>(
                    value: current,
                    underline: const SizedBox.shrink(),
                    borderRadius: BorderRadius.circular(8),
                    dropdownColor: palette.surface,
                    iconEnabledColor: palette.textSecondary,
                    onChanged: active
                        ? (value) => onChanged(style.copyWith(voiceId: value))
                        : null,
                    items: voices
                        .map((v) => DropdownMenuItem(
                              value: v.id,
                              child: Text(
                                v.name,
                                style: TextStyle(
                                    fontSize: 14, color: palette.textPrimary),
                              ),
                            ))
                        .toList(),
                  ),
                );
              },
              loading: () => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  '音色：正在加载语音...',
                  style: TextStyle(fontSize: 13, color: palette.textSecondary),
                ),
              ),
              error: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  '音色：加载语音失败',
                  style: TextStyle(fontSize: 13, color: palette.textSecondary),
                ),
              ),
            ),
            _SliderRow(
              palette: palette,
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
            _SliderRow(
              palette: palette,
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
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  /// API Key 表单 → 底部 Sheet(键盘避让,与原页一致)
  void _showApiKeySheet(
    BuildContext context,
    WidgetRef ref,
    TTSSettings settings,
    CoreDialogPalette palette,
  ) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: settings.apiKey);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
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
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeHeadline,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
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
                  color: palette.fill,
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusGroupedCard),
                ),
                style: TextStyle(color: palette.textPrimary),
              ),
              const SizedBox(height: DesignTokens.spaceMd),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    ref
                        .read(ttsSettingsProvider.notifier)
                        .setApiKey(controller.text);
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

/// 浮窗内分组容器(填充灰底)
class _Group extends StatelessWidget {
  const _Group({required this.palette, this.children = const [], this.child});

  final CoreDialogPalette palette;
  final List<Widget> children;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: palette.fill.withValues(
            alpha: palette.isDark ? 0.55 : 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child ?? Column(children: children),
    );
  }
}

/// 带右侧下拉的行(浮窗版 KiraGroupedTile+trailing Dropdown)
class _DropdownTile extends StatelessWidget {
  const _DropdownTile({
    required this.palette,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final CoreDialogPalette palette;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        TextStyle(fontSize: 15, color: palette.textPrimary)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: TextStyle(
                          fontSize: 12, color: palette.textSecondary)),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// 组内滑块行(标题 + 当前值 + Slider)
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.palette,
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    this.onChanged,
  });

  final CoreDialogPalette palette;
  final String title;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(title,
                    style:
                        TextStyle(fontSize: 15, color: palette.textPrimary)),
              ),
              Text(valueLabel,
                  style: TextStyle(
                      fontSize: 13, color: palette.textSecondary)),
            ],
          ),
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
    );
  }
}
