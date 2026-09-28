// lib/presentation/dialogs/tts_settings_dialog.dart
/// TTS 合成设置浮窗（Phase C 多引擎重设计）
///
/// 四 Tab 分组布局（通用 / 引擎配置 / 三音色 / 高级），
/// 按后端能力动态显隐 rate/pitch 滑块，sherpa 模型导入管理，
/// 云端 API Key 走 flutter_secure_storage（见 tts_providers）。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/domain/services/tts_service.dart';
import 'package:kirakira/domain/services/tts_model_service.dart';
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

class _TtsSettingsDialog extends ConsumerStatefulWidget {
  const _TtsSettingsDialog();

  @override
  ConsumerState<_TtsSettingsDialog> createState() => _TtsSettingsDialogState();
}

class _TtsSettingsDialogState extends ConsumerState<_TtsSettingsDialog> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CoreDialogPalette(isDark: isDark);
    final settings = ref.watch(ttsSettingsProvider);
    final isSpeaking = ref.watch(ttsSpeakingProvider);
    final voicesAsync = ref.watch(availableVoicesProvider);

    return CoreDialogShell(
      title: 'TTS 合成设置',
      icon: CupertinoIcons.speaker_2,
      maxWidth: 560,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Tab 切换 ──
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: _tab,
              onValueChanged: (v) => setState(() => _tab = v ?? 0),
              children: const {
                0: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Text('通用', style: TextStyle(fontSize: 13)),
                ),
                1: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Text('引擎配置', style: TextStyle(fontSize: 13)),
                ),
                2: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Text('三音色', style: TextStyle(fontSize: 13)),
                ),
                3: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Text('高级', style: TextStyle(fontSize: 13)),
                ),
              },
            ),
          ),
          // ── Tab 内容 ──
          switch (_tab) {
            0 => _buildGeneralTab(context, ref, palette, settings, isSpeaking, l10n),
            1 => _buildEngineTab(context, ref, palette, settings, l10n),
            2 => _buildVoicesTab(context, ref, palette, settings, voicesAsync, l10n),
            _ => _buildAdvancedTab(context, ref, palette, settings),
          },
        ],
      ),
    );
  }

  // ── Tab 0：通用 ──
  Widget _buildGeneralTab(
    BuildContext context,
    WidgetRef ref,
    CoreDialogPalette palette,
    TTSSettings s,
    bool isSpeaking,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCurrentEngineCard(ref, palette, s),
        const SizedBox(height: 20),
        CoreSectionLabel(l10n.general),
        const SizedBox(height: 4),
        _Group(
          palette: palette,
          children: [
            CoreSwitchRow(
              title: l10n.enableTts,
              subtitle: l10n.readAiResponsesAloud,
              value: s.enabled,
              palette: palette,
              onChanged: (v) =>
                  ref.read(ttsSettingsProvider.notifier).setEnabled(v),
            ),
            CoreSwitchRow(
              title: l10n.autoPlay,
              subtitle: l10n.automaticallyPlayResponses,
              value: s.autoPlay,
              palette: palette,
              onChanged: s.enabled
                  ? (v) =>
                      ref.read(ttsSettingsProvider.notifier).setAutoPlay(v)
                  : null,
            ),
            CoreSwitchRow(
              title: '消息队列',
              subtitle: '排队多条消息而非打断',
              value: s.queueMessages,
              palette: palette,
              onChanged: s.enabled
                  ? (v) => ref
                      .read(ttsSettingsProvider.notifier)
                      .setQueueMessages(v)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const CoreSectionLabel('音量'),
        const SizedBox(height: 4),
        _Group(
          palette: palette,
          child: _SliderRow(
            palette: palette,
            title: '音量',
            valueLabel: '${(s.volume * 100).round()}%',
            value: s.volume,
            min: 0.0,
            max: 1.0,
            divisions: 10,
            onChanged: s.enabled
                ? (v) =>
                    ref.read(ttsSettingsProvider.notifier).setVolume(v)
                : null,
          ),
        ),
        const SizedBox(height: 20),
        CoreSectionLabel(l10n.test),
        const SizedBox(height: 8),
        CoreSecondaryButton(
          label: isSpeaking ? l10n.stopListening : l10n.testVoice,
          icon: isSpeaking
              ? CupertinoIcons.stop_fill
              : CupertinoIcons.play_fill,
          onPressed: s.enabled
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
    );
  }

  /// 当前引擎卡片
  Widget _buildCurrentEngineCard(
    WidgetRef ref,
    CoreDialogPalette palette,
    TTSSettings s,
  ) {
    final isLocal = s.provider == TTSProvider.sherpaOnnx;
    final name = s.provider.displayName;
    String status;
    if (s.provider == TTSProvider.sherpaOnnx) {
      status = s.sherpaModelName != null && s.sherpaModelName!.isNotEmpty
          ? '模型：${s.sherpaModelName}'
          : '未选择模型';
    } else if (s.provider == TTSProvider.system) {
      status = '使用设备系统语音';
    } else {
      status = (s.apiKey?.isNotEmpty ?? false) ? 'API Key 已配置' : 'API Key 未配置';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.fill.withValues(alpha: palette.isDark ? 0.55 : 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isLocal ? CupertinoIcons.cube_box : CupertinoIcons.cloud,
            size: 22,
            color: DesignTokens.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary)),
                const SizedBox(height: 2),
                Text(status,
                    style: TextStyle(
                        fontSize: 12, color: palette.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            onPressed: () => setState(() => _tab = 1),
            child: Icon(CupertinoIcons.chevron_forward,
                size: 16, color: palette.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── Tab 1：引擎配置 ──
  Widget _buildEngineTab(
    BuildContext context,
    WidgetRef ref,
    CoreDialogPalette palette,
    TTSSettings s,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CoreSectionLabel(l10n.provider),
        const SizedBox(height: 4),
        _Group(
          palette: palette,
          child: _DropdownTile(
            palette: palette,
            title: l10n.ttsProvider,
            subtitle: s.provider.displayName,
            child: DropdownButton<TTSProvider>(
              value: s.provider,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(8),
              dropdownColor: palette.surface,
              iconEnabledColor: palette.textSecondary,
              onChanged: s.enabled
                  ? (v) {
                      if (v != null) {
                        ref.read(ttsSettingsProvider.notifier).setProvider(v);
                        ref.invalidate(availableVoicesProvider);
                      }
                    }
                  : null,
              items: TTSProvider.values.map((p) {
                return DropdownMenuItem(
                  value: p,
                  child: Text(p.displayName,
                      style:
                          TextStyle(fontSize: 14, color: palette.textPrimary)),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // 按 provider 分支
        switch (s.provider) {
          TTSProvider.sherpaOnnx =>
            _buildSherpaConfig(context, ref, palette, s),
          TTSProvider.qwenTts ||
          TTSProvider.baiduTts ||
          TTSProvider.mimoTts =>
            _buildCloudConfig(context, ref, palette, s),
          _ => _buildSystemInfo(palette),
        },
      ],
    );
  }

  Widget _buildSherpaConfig(
    BuildContext context,
    WidgetRef ref,
    CoreDialogPalette palette,
    TTSSettings s,
  ) {
    return FutureBuilder<List<TtsModelEntry>>(
      future: TtsModelService.instance.loadManifest(),
      builder: (context, snap) {
        final models = snap.data ?? const <TtsModelEntry>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CoreSectionLabel('已导入模型'),
            const SizedBox(height: 4),
            if (models.isEmpty)
              _Group(
                palette: palette,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('暂无模型，请导入',
                      style:
                          TextStyle(fontSize: 13, color: palette.textSecondary)),
                ),
              )
            else
              _Group(
                palette: palette,
                child: Column(
                  children: [
                    for (final m in models)
                      RadioListTile<String>(
                        value: m.name,
                        groupValue: s.sherpaModelName,
                        dense: true,
                        activeColor: DesignTokens.primary,
                        onChanged: s.enabled
                            ? (v) => ref
                                .read(ttsSettingsProvider.notifier)
                                .setSherpaModelName(v)
                            : null,
                        title: Text(m.name,
                            style: TextStyle(
                                fontSize: 14, color: palette.textPrimary)),
                        subtitle: Text(
                          '${m.modelType.toUpperCase()} · ${m.numSpeakers} 说话人 · '
                          '${(m.modelSizeBytes / 1024 / 1024).toStringAsFixed(1)} MB',
                          style: TextStyle(
                              fontSize: 11, color: palette.textSecondary),
                        ),
                        secondary: IconButton(
                          icon: const Icon(CupertinoIcons.delete,
                              size: 18, color: Color(0xFFF44336)),
                          onPressed: () =>
                              _confirmDeleteModel(context, ref, m.name),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            CoreSecondaryButton(
              label: '导入模型 (.tar.bz2)',
              icon: CupertinoIcons.folder_open,
              onPressed: s.enabled ? () => _importModel(context, ref) : null,
            ),
            const SizedBox(height: 20),
            CoreInfoRow(
              icon: CupertinoIcons.info,
              title: '模型推荐',
              text: '轻量首选：vits-icefall-zh-aishell3 (30MB)\n'
                  '高质多语言：kokoro-multi-lang-v1_1-int8 (140MB)\n'
                  '下载：https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models',
              palette: palette,
            ),
          ],
        );
      },
    );
  }

  Widget _buildCloudConfig(
    BuildContext context,
    WidgetRef ref,
    CoreDialogPalette palette,
    TTSSettings s,
  ) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CoreSectionLabel(l10nApiKey(s.provider)),
        const SizedBox(height: 4),
        _Group(
          palette: palette,
          child: CoreTile(
            title: l10n.apiKey,
            subtitle: (s.apiKey?.isNotEmpty ?? false)
                ? '••••••••${s.apiKey!.substring(s.apiKey!.length - 4)}'
                : l10n.notConfigured,
            onTap: s.enabled
                ? () => _showApiKeySheet(context, ref, s, palette)
                : null,
          ),
        ),
        // 百度额外需要 SK
        if (s.provider == TTSProvider.baiduTts) ...[
          const SizedBox(height: 8),
          _Group(
            palette: palette,
            child: CoreTile(
              title: 'Secret Key (SK)',
              subtitle: (s.apiEndpoint?.isNotEmpty ?? false)
                  ? '••••••••${s.apiEndpoint!.substring(s.apiEndpoint!.length - 4)}'
                  : l10n.notConfigured,
              onTap: s.enabled
                  ? () => _showSecretKeySheet(context, ref, s, palette)
                  : null,
            ),
          ),
        ],
        // Qwen 模型选择
        if (s.provider == TTSProvider.qwenTts) ...[
          const SizedBox(height: 8),
          _Group(
            palette: palette,
            child: _DropdownTile(
              palette: palette,
              title: '模型',
              subtitle: s.qwenModel ?? 'qwen3-tts-flash',
              child: DropdownButton<String>(
                value: s.qwenModel ?? 'qwen3-tts-flash',
                underline: const SizedBox.shrink(),
                dropdownColor: palette.surface,
                iconEnabledColor: palette.textSecondary,
                onChanged: s.enabled
                    ? (v) => ref
                        .read(ttsSettingsProvider.notifier)
                        .setQwenModel(v)
                    : null,
                items: const [
                  DropdownMenuItem(
                      value: 'qwen3-tts-flash',
                      child: Text('qwen3-tts-flash（便宜·不支持速率）')),
                  DropdownMenuItem(
                      value: 'cosyvoice-v3-flash',
                      child: Text('cosyvoice-v3-flash（支持速率/音调）')),
                  DropdownMenuItem(
                      value: 'cosyvoice-v3-plus', child: Text('cosyvoice-v3-plus')),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        _providerInfo(s.provider, palette),
      ],
    );
  }

  Widget _buildSystemInfo(CoreDialogPalette palette) {
    return CoreInfoRow(
      icon: CupertinoIcons.device_phone_portrait,
      title: '系统语音合成',
      text: '使用设备系统的语音合成服务，可用音色取决于系统设置。',
      palette: palette,
    );
  }

  Widget _providerInfo(TTSProvider p, CoreDialogPalette palette) {
    final map = <TTSProvider, (String, String)>{
      TTSProvider.mimoTts: (
        '小米 MiMo TTS',
        '限时免费，8 中英音色，需在 platform.xiaomimimo.com 创建 API Key。'
      ),
      TTSProvider.qwenTts: (
        '阿里通义 TTS',
        '48 系统音色，cosyvoice 支持语速/音调，0.8 元/万字符。'
      ),
      TTSProvider.baiduTts: (
        '百度语音合成',
        '个人认证享永久免费 5 万次，国内网络友好。'
      ),
    };
    final info = map[p];
    if (info == null) return const SizedBox.shrink();
    return CoreInfoRow(
      icon: CupertinoIcons.info,
      title: info.$1,
      text: info.$2,
      palette: palette,
    );
  }

  String l10nApiKey(TTSProvider p) {
    switch (p) {
      case TTSProvider.baiduTts:
        return 'API Key (AK)';
      case TTSProvider.mimoTts:
        return 'API Key';
      case TTSProvider.qwenTts:
        return 'API Key';
      default:
        return 'API Key';
    }
  }

  // ── Tab 2：三音色 ──
  Widget _buildVoicesTab(
    BuildContext context,
    WidgetRef ref,
    CoreDialogPalette palette,
    TTSSettings s,
    AsyncValue<List<TTSVoice>> voicesAsync,
    AppLocalizations l10n,
  ) {
    final supportsPitch = _pitchSupported(s);
    final supportsRate = _rateSupported(s);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildVoiceStyleSection(
          ref,
          palette,
          title: '正文声音（叙述）',
          label: '正文',
          globalEnabled: s.enabled,
          style: s.narrationVoice,
          voicesAsync: voicesAsync,
          supportsPitch: supportsPitch,
          supportsRate: supportsRate,
          onChanged: (v) =>
              ref.read(ttsSettingsProvider.notifier).setNarrationVoice(v),
        ),
        _buildVoiceStyleSection(
          ref,
          palette,
          title: '对话声音（引号内）',
          label: '对话',
          globalEnabled: s.enabled,
          style: s.dialogueVoice,
          voicesAsync: voicesAsync,
          supportsPitch: supportsPitch,
          supportsRate: supportsRate,
          onChanged: (v) =>
              ref.read(ttsSettingsProvider.notifier).setDialogueVoice(v),
        ),
        _buildVoiceStyleSection(
          ref,
          palette,
          title: '旁白声音（括号内）',
          label: '旁白',
          globalEnabled: s.enabled,
          style: s.asideVoice,
          voicesAsync: voicesAsync,
          supportsPitch: supportsPitch,
          supportsRate: supportsRate,
          onChanged: (v) =>
              ref.read(ttsSettingsProvider.notifier).setAsideVoice(v),
        ),
      ],
    );
  }

  bool _pitchSupported(TTSSettings s) {
    switch (s.provider) {
      case TTSProvider.sherpaOnnx:
        return false;
      case TTSProvider.qwenTts:
        return (s.qwenModel ?? '').startsWith('cosyvoice');
      default:
        return true;
    }
  }

  bool _rateSupported(TTSSettings s) {
    switch (s.provider) {
      case TTSProvider.sherpaOnnx:
        return true;
      case TTSProvider.qwenTts:
        return (s.qwenModel ?? '').startsWith('cosyvoice');
      default:
        return true;
    }
  }

  Widget _buildVoiceStyleSection(
    WidgetRef ref,
    CoreDialogPalette palette, {
    required String title,
    required String label,
    required bool globalEnabled,
    required VoiceStyle style,
    required AsyncValue<List<TTSVoice>> voicesAsync,
    required bool supportsPitch,
    required bool supportsRate,
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
                    child: Text('音色：无可用语音',
                        style: TextStyle(
                            fontSize: 13, color: palette.textSecondary)),
                  );
                }
                final current = (style.voiceId != null &&
                        voices.any((v) => v.id == style.voiceId))
                    ? style.voiceId
                    : voices.first.id;
                return _DropdownTile(
                  palette: palette,
                  title: '音色',
                  subtitle: voices
                      .firstWhere((v) => v.id == current,
                          orElse: () => voices.first)
                      .name,
                  child: DropdownButton<String>(
                    value: current,
                    underline: const SizedBox.shrink(),
                    borderRadius: BorderRadius.circular(8),
                    dropdownColor: palette.surface,
                    iconEnabledColor: palette.textSecondary,
                    onChanged: active
                        ? (v) => onChanged(style.copyWith(voiceId: v))
                        : null,
                    items: voices
                        .map((v) => DropdownMenuItem(
                              value: v.id,
                              child: Text(v.name,
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: palette.textPrimary)),
                            ))
                        .toList(),
                  ),
                );
              },
              loading: () => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text('音色：加载中...',
                    style: TextStyle(
                        fontSize: 13, color: palette.textSecondary)),
              ),
              error: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text('音色：加载失败',
                    style: TextStyle(
                        fontSize: 13, color: palette.textSecondary)),
              ),
            ),
            if (supportsRate)
              _SliderRow(
                palette: palette,
                title: '语速',
                valueLabel: '${style.rate.toStringAsFixed(1)}x',
                value: style.rate,
                min: 0.5,
                max: 2.0,
                divisions: 15,
                onChanged: active
                    ? (v) => onChanged(style.copyWith(rate: v))
                    : null,
              ),
            if (supportsPitch)
              _SliderRow(
                palette: palette,
                title: '音调',
                valueLabel: '${style.pitch.toStringAsFixed(1)}x',
                value: style.pitch,
                min: 0.5,
                max: 2.0,
                divisions: 15,
                onChanged: active
                    ? (v) => onChanged(style.copyWith(pitch: v))
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Tab 3：高级 ──
  Widget _buildAdvancedTab(
    BuildContext context,
    WidgetRef ref,
    CoreDialogPalette palette,
    TTSSettings s,
  ) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CoreSectionLabel('引擎信息'),
        const SizedBox(height: 4),
        _Group(
          palette: palette,
          child: Column(
            children: [
              CoreStatRow(
                  label: '引擎', value: s.provider.displayName),
              CoreStatRow(
                  label: '类型',
                  value: s.provider == TTSProvider.sherpaOnnx
                      ? '本地离线'
                      : '云端在线'),
              CoreStatRow(
                  label: '音调控制',
                  value: _pitchSupported(s) ? '支持' : '不支持'),
              CoreStatRow(
                  label: '语速控制',
                  value: _rateSupported(s) ? '支持' : '不支持'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const CoreSectionLabel('维护'),
        const SizedBox(height: 4),
        _Group(
          palette: palette,
          child: Column(
            children: [
              CoreTile(
                title: '清除临时音频文件',
                subtitle: '删除生成的 WAV/MP3 缓存',
                onTap: () async {
                  final n = await TtsModelService.instance.clearTempWavFiles();
                  if (context.mounted) {
                    coreToast(context, '已清除 $n 个临时文件');
                  }
                },
              ),
              CoreTile(
                title: l10n.resetToDefaults,
                subtitle: '恢复全部 TTS 设置为默认',
                onTap: () {
                  ref.read(ttsSettingsProvider.notifier).reset();
                  coreToast(context, l10n.settingsResetToDefaults);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 操作 ──

  Future<void> _importModel(BuildContext context, WidgetRef ref) async {
    try {
      final name = await TtsModelService.instance.importModel();
      if (name == null) return; // 用户取消
      ref.read(ttsSettingsProvider.notifier).setSherpaModelName(name);
      ref.invalidate(availableVoicesProvider);
      if (context.mounted) coreToast(context, '模型已导入：$name');
    } catch (e) {
      if (context.mounted) coreToast(context, '导入失败: $e');
    }
  }

  Future<void> _confirmDeleteModel(
    BuildContext context,
    WidgetRef ref,
    String name,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: const Text('删除模型'),
        content: Text('确定删除 "$name"？此操作不可撤销。'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(c, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await TtsModelService.instance.deleteModel(name);
      final s = ref.read(ttsSettingsProvider);
      if (s.sherpaModelName == name) {
        ref.read(ttsSettingsProvider.notifier).setSherpaModelName(null);
      }
      if (context.mounted) coreToast(context, '已删除模型：$name');
    } catch (e) {
      if (context.mounted) coreToast(context, '删除失败: $e');
    }
  }

  void _showApiKeySheet(
    BuildContext context,
    WidgetRef ref,
    TTSSettings s,
    CoreDialogPalette palette,
  ) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: s.apiKey ?? '');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(DesignTokens.radiusBottomSheet)),
      ),
      builder: (sheetCtx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${s.provider.displayName} ${l10n.apiKey}',
                  style: TextStyle(
                      fontSize: DesignTokens.fontSizeHeadline,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary)),
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

  void _showSecretKeySheet(
    BuildContext context,
    WidgetRef ref,
    TTSSettings s,
    CoreDialogPalette palette,
  ) {
    final controller = TextEditingController(text: s.apiEndpoint ?? '');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(DesignTokens.radiusBottomSheet)),
      ),
      builder: (sheetCtx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Secret Key (SK)',
                  style: TextStyle(
                      fontSize: DesignTokens.fontSizeHeadline,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary)),
              const SizedBox(height: DesignTokens.spaceMd),
              CupertinoTextField(
                controller: controller,
                autofocus: true,
                obscureText: true,
                placeholder: '百度 SK',
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
                        .setApiEndpoint(controller.text);
                    Navigator.pop(sheetCtx);
                  },
                  child: const Text('保存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 浮窗内分组容器
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
        color: palette.fill.withValues(alpha: palette.isDark ? 0.55 : 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child ?? Column(children: children),
    );
  }
}

/// 带右侧下拉的行
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

/// 组内滑块行
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
