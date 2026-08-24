// lib/presentation/screens/settings/geek_dashboard_screen.dart
/// 极客Core 仪表盘(返工条目4 v3:一张连续面板,分区聚合,控件全部就地)
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/providers/ai_preset_providers.dart';
import 'package:kirakira/presentation/providers/cfg_scale_providers.dart';
import 'package:kirakira/presentation/providers/logit_bias_providers.dart';
import 'package:kirakira/presentation/providers/prompt_manager_providers.dart';
import 'package:kirakira/presentation/providers/regex_providers.dart';
import 'package:kirakira/presentation/providers/settings_providers.dart';
import 'package:kirakira/presentation/providers/stt_providers.dart';
import 'package:kirakira/presentation/providers/tokenizer_providers.dart';
import 'package:kirakira/presentation/providers/translation_providers.dart';
import 'package:kirakira/presentation/providers/tts_providers.dart';
import 'package:kirakira/presentation/providers/vector_storage_providers.dart';
import 'package:kirakira/presentation/router/app_router.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';

class GeekDashboardScreen extends ConsumerWidget {
  const GeekDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final config = ref.watch(llmConfigProvider);

    // ═══ Hero 数据准备 ═══
    final budgetRatio = config.contextLength <= 0
        ? 0.0
        : (config.maxTokens / config.contextLength).clamp(0.0, 1.0);
    final onlineCount = [
      ref.watch(isCFGActiveProvider),
      ref.watch(vectorStorageSettingsProvider).enabled,
      config.streamEnabled,
      config.autoSummarizeEnabled,
      ref.watch(logitBiasSettingsProvider).enabled,
      ref.watch(tokenizerSettingsProvider).showTokenCount,
    ].where((e) => e).length;
    final activePreset = ref.watch(activeAIPresetProvider);

    final budgetColor = budgetRatio >= 1.0
        ? DesignTokens.statusError
        : budgetRatio > 0.9
            ? DesignTokens.statusWarning
            : DesignTokens.accent;
    final onlineColor =
        onlineCount == 0 ? DesignTokens.statusError : DesignTokens.accent;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(
              '极客Core', // TODO(i18n): 待补 l10n key
              style: theme.textTheme.displayLarge,
            ),
            leading: IconButton(
              icon: const Icon(CupertinoIcons.back),
              onPressed: () => context.pop(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: DesignTokens.paddingScreen,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusCard),
                  border: isDark
                      ? null
                      : Border.all(color: theme.dividerColor, width: 0.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Hero 三合一状态带 ──
                    _HeroBand(
                      budgetRatio: budgetRatio,
                      budgetColor: budgetColor,
                      isDark: isDark,
                      onlineCount: onlineCount,
                      onlineColor: onlineColor,
                      presetName: activePreset?.name,
                    ),
                    _vDivider(context),
                    // ── ZONE 1 生成生成 ──
                    const _ZoneLabel('生成生成'),
                    const _SamplingBlock(),
                    _vDivider(context),
                    _linkMoreRow('更多采样参数',
                        () => context.push(AppRoutes.advancedSettings)),
                    _vDivider(context),
                    // ── ZONE 2 工具链 ──
                    const _ZoneLabel('工具链'),
                    const _ToolchainBlock(),
                    _vDivider(context),
                    // ── ZONE 3 扩展 ──
                    const _ZoneLabel('扩展'),
                    const _ExtensionsBlock(),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }

  Widget _vDivider(BuildContext ctx) =>
      Divider(height: 0.5, thickness: 0.5, color: Theme.of(ctx).dividerColor);

  Widget _linkMoreRow(String label, VoidCallback onTap) {
    return Builder(builder: (context) {
      final theme = Theme.of(context);
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceMd,
              vertical: DesignTokens.spaceMd),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeBodyLarge,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ),
              Text(
                '全部参数',
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeSm,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(width: 6),
              Icon(CupertinoIcons.chevron_forward,
                  size: 14, color: theme.textTheme.bodySmall?.color),
            ],
          ),
        ),
      );
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Hero 三合一状态带:预算环·功能在线·预设名(无卡边,内部分区)
// ═══════════════════════════════════════════════════════════════════════════
class _HeroBand extends StatelessWidget {
  final double budgetRatio;
  final Color budgetColor;
  final bool isDark;
  final int onlineCount;
  final Color onlineColor;
  final String? presetName;

  const _HeroBand({
    required this.budgetRatio,
    required this.budgetColor,
    required this.isDark,
    required this.onlineCount,
    required this.onlineColor,
    required this.presetName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tertiary = theme.textTheme.bodySmall?.color;

    return Padding(
      padding: const EdgeInsets.all(DesignTokens.spaceMd),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // 左:预算环 + 数字
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(
                      value: budgetRatio,
                      strokeWidth: 7,
                      backgroundColor: isDark
                          ? DesignTokens.darkCard
                          : DesignTokens.lightFillTertiary,
                      valueColor: AlwaysStoppedAnimation(budgetColor),
                    ),
                  ),
                  Icon(CupertinoIcons.speedometer, size: 22, color: budgetColor),
                ],
              ),
            ),
            const SizedBox(width: DesignTokens.spaceSm + 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${(budgetRatio * 100).round()}%',
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeXl,
                    fontWeight: DesignTokens.weightBold,
                    color: budgetColor,
                  ),
                ),
                Text(
                  'Token 预算',
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeXs,
                    color: tertiary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  presetName == null ? '未启用预设' : presetName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeXs,
                    color: tertiary,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // 中:功能在线计数
            VerticalDivider(
              width: 0.5,
              thickness: 0.5,
              indent: 8,
              endIndent: 8,
              color: theme.dividerColor,
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$onlineCount',
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeDisplayLarge,
                    fontWeight: DesignTokens.weightBold,
                    color: onlineColor,
                  ),
                ),
                Text(
                  '/ 6 项启用',
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeXs,
                    color: tertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ZONE 1 生成生成:温度/TopP/TopK/maxTokens 滑块全部就地
// ═══════════════════════════════════════════════════════════════════════════
class _SamplingBlock extends ConsumerWidget {
  const _SamplingBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final config = ref.watch(llmConfigProvider);
    final theme = Theme.of(context);
    final accent = DesignTokens.accent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          DesignTokens.spaceMd, 0, DesignTokens.spaceMd, DesignTokens.spaceSm),
      child: Column(
        children: [
          _MiniSlider(
            label: l10n.temperature,
            value: config.temperature,
            min: 0.0, max: 2.0, divisions: 40,
            display: config.temperature.toStringAsFixed(2),
            color: accent,
            onChanged: (v) =>
                ref.read(llmConfigProvider.notifier).updateTemperature(v),
          ),
          _MiniSlider(
            label: l10n.topPNucleusSampling,
            value: config.topP,
            min: 0.0, max: 1.0, divisions: 20,
            display: config.topP.toStringAsFixed(2),
            color: accent,
            onChanged: (v) =>
                ref.read(llmConfigProvider.notifier).updateTopP(v),
          ),
          _MiniSlider(
            label: 'Top K',
            value: config.topK.toDouble(),
            min: 0, max: 200, divisions: 200,
            display: '${config.topK}',
            color: accent,
            onChanged: (v) =>
                ref.read(llmConfigProvider.notifier).updateTopK(v.round()),
          ),
          _MiniSlider(
            label: l10n.maxTokens,
            value: config.maxTokens.toDouble(),
            min: 64, max: 4096, divisions: 63,
            display: '${config.maxTokens}',
            color: accent,
            onChanged: (v) =>
                ref.read(llmConfigProvider.notifier).updateMaxTokens(v.round()),
          ),
          _MiniSlider(
            label: l10n.contextLength,
            value: config.contextLength.toDouble(),
            min: 512, max: 131072, divisions: 32,
            display: '${config.contextLength}',
            color: accent,
            onChanged: (v) => ref
                .read(llmConfigProvider.notifier)
                .updateContextLength(v.round()),
          ),
          Divider(
              height: DesignTokens.spaceMd,
              thickness: 0.5,
              color: theme.dividerColor),
          _InlineSwitch(
            label: '流式输出',
            subtitle: '实时显示生成内容',
            value: config.streamEnabled,
            onChanged: (v) =>
                ref.read(llmConfigProvider.notifier).updateStreamEnabled(v),
          ),
          _InlineSwitch(
            label: '自动摘要',
            subtitle: '长对话自动压缩上下文',
            value: config.autoSummarizeEnabled,
            onChanged: (v) => ref
                .read(llmConfigProvider.notifier)
                .updateAutoSummarizeEnabled(v),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ZONE 2 工具链:icon·名称·就地开关·状态摘要·明显入口
// ═══════════════════════════════════════════════════════════════════════════
class _ToolchainBlock extends ConsumerWidget {
  const _ToolchainBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tts = ref.watch(ttsSettingsProvider);
    final stt = ref.watch(sttSettingsProvider);
    final trans = ref.watch(translationSettingsProvider);
    final regex = ref.watch(regexSettingsProvider);
    final scripts = ref.watch(globalRegexScriptsProvider);
    final rag = ref.watch(vectorStorageSettingsProvider);
    final enabledScripts = scripts.where((s) => !s.disabled).length;

    return Column(
      children: [
        _ToolchainRow(
          icon: CupertinoIcons.speaker_2,
          label: 'TTS 合成',
          status: tts.enabled
              ? '${tts.rate.toStringAsFixed(1)}× ${tts.voiceId ?? '默认'}'
              : '已停用',
          value: tts.enabled,
          onToggle: (v) =>
              ref.read(ttsSettingsProvider.notifier).setEnabled(v),
          onTap: () => context.push(AppRoutes.ttsSettings),
        ),
        _ToolchainRow(
          icon: CupertinoIcons.mic,
          label: 'STT 识别',
          status: stt.enabled
              ? '${stt.language} · ${stt.autoSend ? '自动发送' : '手动'}'
              : '已停用',
          value: stt.enabled,
          onToggle: (v) =>
              ref.read(sttSettingsProvider.notifier).setEnabled(v),
          onTap: () => context.push(AppRoutes.sttSettings),
        ),
        _ToolchainRow(
          icon: CupertinoIcons.globe,
          label: '翻译',
          status: trans.enabled
              ? '${trans.sourceLanguage}⇄${trans.targetLanguage}${trans.autoTranslateIncoming ? ' · 入站' : ''}'
              : '已停用',
          value: trans.enabled,
          onToggle: (v) =>
              ref.read(translationSettingsProvider.notifier).setEnabled(v),
          onTap: () => context.push(AppRoutes.translationSettings),
        ),
        _ToolchainRow(
          icon: CupertinoIcons.photo_on_rectangle,
          label: '图片生成',
          status: '未启用',
          value: false,
          onToggle: null,
          onTap: () => context.push(AppRoutes.imageGenSettings),
        ),
        _ToolchainRow(
          icon: CupertinoIcons.wand_stars,
          label: '正则系统',
          status: regex.enabled
              ? '$enabledScripts/${scripts.length} 脚本'
              : '已停用',
          value: regex.enabled,
          onToggle: (v) =>
              ref.read(regexSettingsProvider.notifier).setEnabled(v),
          onTap: () => context.push(AppRoutes.regexSettings),
        ),
        _ToolchainRow(
          icon: CupertinoIcons.square_stack_3d_up,
          label: '向量 RAG',
          status: rag.enabled
              ? 'TopK ${rag.topK} · 阈值 ${rag.similarityThreshold.toStringAsFixed(2)}'
              : '已停用',
          value: rag.enabled,
          onToggle: (v) =>
              ref.read(vectorStorageSettingsProvider.notifier).setEnabled(v),
          onTap: () => context.push(AppRoutes.vectorStorageSettings),
          isLast: true,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ZONE 3 扩展:剩余入口一行一行全部摆出来
// ═══════════════════════════════════════════════════════════════════════════
class _ExtensionsBlock extends ConsumerWidget {
  const _ExtensionsBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activePreset = ref.watch(activeAIPresetProvider);
    final enabledPrompts = ref.watch(enabledPromptSectionsProvider);
    final promptPreset = ref.watch(activePresetProvider);
    final cfg = ref.watch(cfgScaleSettingsProvider);
    final logit = ref.watch(logitBiasSettingsProvider);
    final showTokenCount = ref.watch(tokenizerSettingsProvider).showTokenCount;

    return Column(
      children: [
        _ExtensionRow(
          icon: CupertinoIcons.star,
          label: 'AI 预设',
          status: activePreset != null ? '当前:${activePreset.name}' : '未启用',
          onTap: () => context.push(AppRoutes.aiPresets),
        ),
        _ExtensionRow(
          icon: CupertinoIcons.list_bullet,
          label: '提示词管理',
          status:
              '${enabledPrompts.length} 段${promptPreset != null ? ' · ${promptPreset.name}' : ''}',
          onTap: () => context.push(AppRoutes.promptManager),
        ),
        _ExtensionRowWithSwitch(
          icon: CupertinoIcons.speedometer,
          label: 'CFG Scale',
          status: cfg.enabled
              ? 'Scale ${cfg.globalGuidanceScale.toStringAsFixed(1)}'
              : '已停用',
          value: cfg.enabled,
          onToggle: (v) =>
              ref.read(cfgScaleSettingsProvider.notifier).setEnabled(v),
          onTap: () => context.push(AppRoutes.cfgScaleSettings),
        ),
        _ExtensionRowWithSwitch(
          icon: CupertinoIcons.line_horizontal_3_decrease,
          label: 'Logit 偏置',
          status: logit.enabled
              ? (logit.activePreset != null
                  ? '${logit.activePreset!.entries.length} 条'
                  : '已启用')
              : '已停用',
          value: logit.enabled,
          onToggle: (v) =>
              ref.read(logitBiasSettingsProvider.notifier).setEnabled(v),
          onTap: () => context.push(AppRoutes.logitBiasSettings),
        ),
        _ExtensionRow(
          icon: CupertinoIcons.cube_box,
          label: 'MVU 变量框架',
          status: '',
          onTap: () => context.push(AppRoutes.mvuSettings),
        ),
        _ExtensionRowWithSwitch(
          icon: CupertinoIcons.textformat_abc,
          label: '分词器计数',
          status: showTokenCount ? '输入框旁显示' : '已停用',
          value: showTokenCount,
          onToggle: (v) =>
              ref.read(tokenizerSettingsProvider.notifier).setShowTokenCount(v),
          onTap: () => context.push(AppRoutes.tokenizerSettings),
        ),
        _ExtensionRow(
          icon: CupertinoIcons.square_list,
          label: '变量管理',
          status: '',
          onTap: () => context.push(AppRoutes.variablesSettings),
        ),
        _ExtensionRow(
          icon: CupertinoIcons.chart_bar,
          label: '日志统计',
          status: '',
          onTap: () => context.push(AppRoutes.statistics),
        ),
        _ExtensionRow(
          icon: CupertinoIcons.doc_text,
          label: '日志查看器',
          status: '',
          onTap: () => context.push(AppRoutes.settingsLogs),
          isLast: true,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 组件:区段标签大写小灰字
// ═══════════════════════════════════════════════════════════════════════════
class _ZoneLabel extends StatelessWidget {
  final String text;
  const _ZoneLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          DesignTokens.spaceMd, 4, DesignTokens.spaceMd, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: DesignTokens.fontSizeSm,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 组件:迷你滑块行(label · 数值 inline ·Track 4)
// ═══════════════════════════════════════════════════════════════════════════
class _MiniSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final Color color;
  final ValueChanged<double> onChanged;

  const _MiniSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeBodyLarge,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ),
            Text(
              display,
              style: TextStyle(
                fontSize: DesignTokens.fontSizeBodyMedium,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor: color,
            inactiveTrackColor:
                theme.textTheme.bodySmall?.color?.withValues(alpha: 0.18),
            thumbColor: color,
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 组件:摆地开关行(标签 · 说明 · 开关)
// ═══════════════════════════════════════════════════════════════════════════
class _InlineSwitch extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _InlineSwitch({
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: DesignTokens.fontSizeBodyLarge,
                        color: theme.textTheme.bodyLarge?.color)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: TextStyle(
                          fontSize: DesignTokens.fontSizeXs,
                          color: theme.textTheme.bodySmall?.color)),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 组件:工具链行(icon + 名称 + 状态 + 就地开关 + 明显入口)
// ═══════════════════════════════════════════════════════════════════════════
class _ToolchainRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String status;
  final bool value;
  final ValueChanged<bool>? onToggle;
  final VoidCallback onTap;
  final bool isLast;

  const _ToolchainRow({
    required this.icon,
    required this.label,
    required this.status,
    required this.value,
    required this.onToggle,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryDim = theme.colorScheme.primary.withValues(alpha: 0.12);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              DesignTokens.spaceMd, 6, DesignTokens.spaceSm, 6),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: primaryDim,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(icon,
                    size: 16, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: DesignTokens.spaceSm + 4),
              Expanded(
                child: InkWell(
                  onTap: onTap,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: TextStyle(
                              fontSize: DesignTokens.fontSizeBodyLarge,
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.bodyLarge?.color)),
                      Text(status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: DesignTokens.fontSizeXs,
                              color: theme.textTheme.bodySmall?.color)),
                    ],
                  ),
                ),
              ),
              if (onToggle != null)
                CupertinoSwitch(
                  value: value,
                  onChanged: onToggle,
                  activeTrackColor: theme.colorScheme.primary,
                )
              else
                Icon(CupertinoIcons.chevron_forward,
                    size: 16, color: theme.textTheme.bodySmall?.color),
              const SizedBox(width: 4),
              Icon(CupertinoIcons.chevron_forward,
                  size: 14, color: theme.textTheme.bodySmall?.color),
            ],
          ),
        ),
        if (!isLast)
          Divider(
              height: 0.5,
              thickness: 0.5,
              indent: DesignTokens.spaceMd + 42,
              color: theme.dividerColor),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 组件:扩展入口行(无开关,纯入口)
// ═══════════════════════════════════════════════════════════════════════════
class _ExtensionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String status;
  final VoidCallback onTap;
  final bool isLast;

  const _ExtensionRow({
    required this.icon,
    required this.label,
    required this.status,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryDim = theme.colorScheme.primary.withValues(alpha: 0.12);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                DesignTokens.spaceMd, 10, DesignTokens.spaceSm, 10),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: primaryDim,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon,
                      size: 16, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: DesignTokens.spaceSm + 4),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: DesignTokens.fontSizeBodyLarge,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodyLarge?.color)),
                ),
                if (status.isNotEmpty) ...[
                  Text(status,
                      style: TextStyle(
                          fontSize: DesignTokens.fontSizeXs,
                          color: theme.textTheme.bodySmall?.color)),
                  const SizedBox(width: 6),
                ],
                Icon(CupertinoIcons.chevron_forward,
                    size: 14, color: theme.textTheme.bodySmall?.color),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
              height: 0.5,
              thickness: 0.5,
              indent: DesignTokens.spaceMd + 42,
              color: theme.dividerColor),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 组件:扩展入口行带开关(CFG / Logit / 分词器 等)
// ═══════════════════════════════════════════════════════════════════════════
class _ExtensionRowWithSwitch extends StatelessWidget {
  final IconData icon;
  final String label;
  final String status;
  final bool value;
  final ValueChanged<bool>? onToggle;
  final VoidCallback onTap;
  final bool isLast;

  const _ExtensionRowWithSwitch({
    required this.icon,
    required this.label,
    required this.status,
    required this.value,
    required this.onToggle,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryDim = theme.colorScheme.primary.withValues(alpha: 0.12);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              DesignTokens.spaceMd, 6, DesignTokens.spaceSm, 6),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: primaryDim,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(icon,
                    size: 16, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: DesignTokens.spaceSm + 4),
              Expanded(
                child: InkWell(
                  onTap: onTap,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: TextStyle(
                              fontSize: DesignTokens.fontSizeBodyLarge,
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.bodyLarge?.color)),
                      Text(status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: DesignTokens.fontSizeXs,
                              color: theme.textTheme.bodySmall?.color)),
                    ],
                  ),
                ),
              ),
              if (onToggle != null) ...[
                CupertinoSwitch(
                  value: value,
                  onChanged: onToggle,
                  activeTrackColor: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4),
              ],
              Icon(CupertinoIcons.chevron_forward,
                  size: 14, color: theme.textTheme.bodySmall?.color),
            ],
          ),
        ),
        if (!isLast)
          Divider(
              height: 0.5,
              thickness: 0.5,
              indent: DesignTokens.spaceMd + 42,
              color: theme.dividerColor),
      ],
    );
  }
}
