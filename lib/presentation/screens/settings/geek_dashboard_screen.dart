import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kirakira/presentation/providers/cfg_scale_providers.dart';
import 'package:kirakira/presentation/providers/settings_providers.dart';
import 'package:kirakira/presentation/widgets/common/kira_components.dart';
import 'package:kirakira/presentation/widgets/common/kira_grouped_tile.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/providers/vector_storage_providers.dart';
import 'package:kirakira/presentation/providers/logit_bias_providers.dart';
import 'package:kirakira/presentation/providers/tokenizer_providers.dart';
import 'package:kirakira/presentation/providers/regex_providers.dart';
import 'package:kirakira/presentation/providers/tts_providers.dart';
import 'package:kirakira/presentation/providers/stt_providers.dart';
import 'package:kirakira/presentation/providers/translation_providers.dart';
import 'package:kirakira/presentation/providers/ai_preset_providers.dart';
import 'package:kirakira/presentation/providers/prompt_manager_providers.dart';

/// 极客Core 仪表盘(Block F v2:推翻网格,iOS 健康/设置 App 手法)
///
/// 结构(自上而下):
///   0. Hero 摘要条(_HeroStrip)        —— 一行两区 inset-grouped 卡
///   1. 功能 组(_FeatureCardsSection)  —— 7 张可展开功能卡(总开关+就地参数)
///   2. 配置 组(_ConfigSection)        —— 3 行只读摘要 + 详情
///   3. 快捷调整(_QuickAdjustSection)  —— 采样参数滑块自留地
///   4. 更多 组(_MoreSection)          —— 剩余入口紧凑列表
class GeekDashboardScreen extends ConsumerWidget {
  const GeekDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // F-T1:大标题
          SliverAppBar.large(
            title: Text(
              '极客Core', // TODO(i18n): 待补 l10n key
              style: Theme.of(context).textTheme.displayLarge,
            ),
            leading: IconButton(
              icon: const Icon(CupertinoIcons.back),
              onPressed: () => context.go('/settings'),
            ),
          ),
          const SliverToBoxAdapter(
            child: _SectionEntrance(index: 0, child: _HeroStrip()),
          ),
          const SliverToBoxAdapter(
            child: _SectionEntrance(index: 1, child: _FeatureCardsSection()),
          ),
          const SliverToBoxAdapter(
            child: _SectionEntrance(index: 2, child: _ConfigSection()),
          ),
          const SliverToBoxAdapter(
            child: _SectionEntrance(index: 3, child: _QuickAdjustSection()),
          ),
          const SliverToBoxAdapter(
            child: _SectionEntrance(index: 4, child: _MoreSection()),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// F-T2 Hero 摘要条:一张 inset-grouped 卡,左右两区 + 中央 0.5 竖分隔
// ═══════════════════════════════════════════════════════════════════════════
class _HeroStrip extends ConsumerWidget {
  const _HeroStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final config = ref.watch(llmConfigProvider);
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

    // F-T2.3: 预算环语义色 —— 正常 accent(青) / >0.9 警告 / 超额错误
    final budgetColor = budgetRatio >= 1.0
        ? DesignTokens.statusError
        : budgetRatio > 0.9
            ? DesignTokens.statusWarning
            : DesignTokens.accent;
    final onlineColor =
        onlineCount == 0 ? DesignTokens.statusError : DesignTokens.accent;

    return Padding(
      padding: DesignTokens.paddingScreen,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(DesignTokens.radiusGroupedCard),
          border: isDark
              ? null
              : Border.all(color: theme.dividerColor, width: 0.5),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // 左区:生成预算环 + maxTokens 大数字
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(DesignTokens.spaceMd),
                  child: Row(
                    children: [
                      _RingGauge(
                        value: budgetRatio,
                        isDark: isDark,
                        color: budgetColor,
                      ),
                      const SizedBox(width: DesignTokens.spaceMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${config.maxTokens}',
                              style: TextStyle(
                                fontSize: DesignTokens.fontSizeDisplayLarge,
                                fontWeight: DesignTokens.weightBold,
                                color: budgetColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'tokens / 次',
                              style: TextStyle(
                                fontSize: DesignTokens.fontSizeXs,
                                color: theme.textTheme.bodySmall?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 中央竖分隔(0.5px separator)
              VerticalDivider(
                width: 0.5,
                thickness: 0.5,
                color: theme.dividerColor,
                indent: 12,
                endIndent: 12,
              ),
              // 右区:功能在线 + 胶囊进度
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(DesignTokens.spaceMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
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
                            ' / 6 项启用',
                            style: TextStyle(
                              fontSize: DesignTokens.fontSizeXs,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: DesignTokens.spaceSm),
                      _CapsuleProgressBar(
                        value: onlineCount / 6,
                        isDark: isDark,
                        color: onlineColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// F-T3 功能组:7 张可展开功能卡
// ═══════════════════════════════════════════════════════════════════════════
class _FeatureCardsSection extends ConsumerWidget {
  const _FeatureCardsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryDim = Theme.of(context).colorScheme.primary.withValues(alpha: 0.12);

    final cfg = ref.watch(cfgScaleSettingsProvider);
    final logit = ref.watch(logitBiasSettingsProvider);
    final regex = ref.watch(regexSettingsProvider);
    final scripts = ref.watch(globalRegexScriptsProvider);
    final enabledScripts = scripts.where((s) => !s.disabled).length;
    final rag = ref.watch(vectorStorageSettingsProvider);
    final tts = ref.watch(ttsSettingsProvider);
    final stt = ref.watch(sttSettingsProvider);
    final trans = ref.watch(translationSettingsProvider);

    return KiraSection.plain(
      title: '功能',
      child: Column(
        children: [
          // 1. CFG Scale
          _FeatureCard(
            icon: CupertinoIcons.speedometer,
            iconBg: primaryDim,
            title: 'CFG Scale',
            enabled: cfg.enabled,
            onToggle: (v) =>
                ref.read(cfgScaleSettingsProvider.notifier).setEnabled(v),
            summaryOn: 'Scale ${cfg.globalGuidanceScale.toStringAsFixed(1)}',
            route: AppRoutes.cfgScaleSettings,
            expanded: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceMd),
              child: _DashboardSlider(
                label: 'Scale',
                value: cfg.globalGuidanceScale,
                min: 0.1,
                max: 30.0,
                divisions: 299,
                valueLabel: cfg.globalGuidanceScale.toStringAsFixed(1),
                onChanged: (v) => ref
                    .read(cfgScaleSettingsProvider.notifier)
                    .setGlobalGuidanceScale(v),
              ),
            ),
          ),
          _cardGap(),
          // 2. Logit 偏置
          _FeatureCard(
            icon: CupertinoIcons.line_horizontal_3_decrease,
            iconBg: primaryDim,
            title: 'Logit 偏置',
            enabled: logit.enabled,
            onToggle: (v) =>
                ref.read(logitBiasSettingsProvider.notifier).setEnabled(v),
            summaryOn: logit.activePreset != null
                ? '已配置 ${logit.activePreset!.entries.length} 条偏置'
                : '已启用',
            route: AppRoutes.logitBiasSettings,
          ),
          _cardGap(),
          // 3. 正则系统
          _FeatureCard(
            icon: CupertinoIcons.wand_stars,
            iconBg: primaryDim,
            title: '正则系统',
            enabled: regex.enabled,
            onToggle: (v) =>
                ref.read(regexSettingsProvider.notifier).setEnabled(v),
            summaryOn: '启用 $enabledScripts / 共 ${scripts.length} 个脚本',
            route: AppRoutes.regexSettings,
          ),
          _cardGap(),
          // 4. 向量 RAG
          _FeatureCard(
            icon: CupertinoIcons.square_stack_3d_up,
            iconBg: primaryDim,
            title: '向量 RAG',
            enabled: rag.enabled,
            onToggle: (v) =>
                ref.read(vectorStorageSettingsProvider.notifier).setEnabled(v),
            summaryOn:
                'TopK ${rag.topK} · 阈值 ${rag.similarityThreshold.toStringAsFixed(2)}',
            route: AppRoutes.vectorStorageSettings,
            expanded: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceMd),
              child: _DashboardSlider(
                label: 'TopK',
                value: rag.topK.toDouble(),
                min: 1,
                max: 20,
                divisions: 19,
                valueLabel: '${rag.topK}',
                onChanged: (v) => ref
                    .read(vectorStorageSettingsProvider.notifier)
                    .setTopK(v.round().clamp(1, 20)),
              ),
            ),
          ),
          _cardGap(),
          // 5. TTS 合成
          _FeatureCard(
            icon: CupertinoIcons.speaker_2,
            iconBg: primaryDim,
            title: 'TTS 合成',
            enabled: tts.enabled,
            onToggle: (v) =>
                ref.read(ttsSettingsProvider.notifier).setEnabled(v),
            summaryOn:
                '语速 ${tts.rate.toStringAsFixed(1)}× · ${tts.voiceId ?? '默认声音'}',
            route: AppRoutes.ttsSettings,
            expanded: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceMd),
              child: _DashboardSlider(
                label: '语速',
                value: tts.rate,
                min: 0.5,
                max: 2.0,
                divisions: 30,
                valueLabel: '${tts.rate.toStringAsFixed(1)}×',
                onChanged: (v) =>
                    ref.read(ttsSettingsProvider.notifier).setRate(v),
              ),
            ),
          ),
          _cardGap(),
          // 6. STT 识别
          _FeatureCard(
            icon: CupertinoIcons.mic,
            iconBg: primaryDim,
            title: 'STT 识别',
            enabled: stt.enabled,
            onToggle: (v) =>
                ref.read(sttSettingsProvider.notifier).setEnabled(v),
            summaryOn:
                '语言 ${stt.language}${stt.autoSend ? ' · 自动发送' : ''}',
            route: AppRoutes.sttSettings,
            expanded: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceMd),
              child: KiraSwitchTile(
                title: '自动发送',
                subtitle: '说话结束后自动发送',
                value: stt.autoSend,
                onChanged: (v) =>
                    ref.read(sttSettingsProvider.notifier).setAutoSend(v),
              ),
            ),
          ),
          _cardGap(),
          // 7. 翻译
          _FeatureCard(
            icon: CupertinoIcons.globe,
            iconBg: primaryDim,
            title: '翻译',
            enabled: trans.enabled,
            onToggle: (v) =>
                ref.read(translationSettingsProvider.notifier).setEnabled(v),
            summaryOn:
                '${trans.sourceLanguage} ⇄ ${trans.targetLanguage}${trans.autoTranslateIncoming ? ' · 入站自动' : ''}',
            route: AppRoutes.translationSettings,
            expanded: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceMd),
              child: KiraSwitchTile(
                title: '入站自动翻译',
                subtitle: '收到消息时自动译为中文',
                value: trans.autoTranslateIncoming,
                onChanged: (v) => ref
                    .read(translationSettingsProvider.notifier)
                    .setAutoTranslateIncoming(v),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardGap() => const SizedBox(height: DesignTokens.spaceSm);
}

/// 可展开功能卡(F-T3 核心件)
///
/// 头行(44 高):彩块 icon 26×26 + 标题 17/w600 + 右侧 CupertinoSwitch;
/// ON:头行+摘要行(13 secondary);OFF:头行+'已停用'(tertiary,整卡降低存在感);
/// 点卡体非开关区 → 展开(250ms AnimatedSize),展开区 + 底部"高级设置 ›"推详情。
class _FeatureCard extends StatefulWidget {
  const _FeatureCard({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.enabled,
    required this.onToggle,
    required this.route,
    this.summaryOn,
    this.expanded,
  });

  final IconData icon;
  final Color iconBg;
  final String title;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final String route;
  final String? summaryOn;
  final Widget? expanded;

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusGroupedCard),
        border: isDark
            ? null
            : Border.all(color: theme.dividerColor, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 头行:icon + 标题 + 展开 chevron + 开关 ──
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  DesignTokens.spaceMd, 10, DesignTokens.spaceMd, 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: widget.iconBg,
                        borderRadius: BorderRadius.circular(
                            DesignTokens.radiusGroupedCard),
                      ),
                      alignment: Alignment.center,
                      child: Icon(widget.icon,
                          size: 15, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: DesignTokens.spaceSm + 4),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeHeadline,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                    Icon(
                      _expanded
                          ? CupertinoIcons.chevron_up
                          : CupertinoIcons.chevron_down,
                      size: 14,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                    const SizedBox(width: DesignTokens.spaceSm),
                    CupertinoSwitch(
                      value: widget.enabled,
                      onChanged: widget.onToggle,
                      activeTrackColor: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── ON 摘要 / OFF 停用 / 展开区 ──
          if (!widget.enabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  DesignTokens.spaceMd, 0, DesignTokens.spaceMd, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '已停用',
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeSm,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              ),
            )
          else if (!_expanded && widget.summaryOn != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  DesignTokens.spaceMd, 0, DesignTokens.spaceMd, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.summaryOn!,
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeSm,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          if (_expanded && widget.enabled) ...[
            Divider(
                height: 0.5, thickness: 0.5, color: theme.dividerColor),
            Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: DesignTokens.spaceSm),
              child: widget.expanded ?? const SizedBox.shrink(),
            ),
            // 进详情
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.push(widget.route),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(DesignTokens.spaceMd,
                      DesignTokens.spaceSm, DesignTokens.spaceMd, DesignTokens.spaceSm),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '高级设置',
                          style: TextStyle(
                            fontSize: DesignTokens.fontSizeBodyMedium,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      Icon(CupertinoIcons.chevron_forward,
                          size: 16, color: theme.colorScheme.primary),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// F-T4 配置组:3 行只读摘要 + 详情
// ═══════════════════════════════════════════════════════════════════════════
class _ConfigSection extends ConsumerWidget {
  const _ConfigSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(llmConfigProvider);
    final activePreset = ref.watch(activeAIPresetProvider);
    final allPresets = ref.watch(allAIPresetsProvider);
    final enabledPrompts = ref.watch(enabledPromptSectionsProvider);
    final promptPreset = ref.watch(activePresetProvider);

    final modelSub = (config.model.isEmpty)
        ? '未选择模型 · maxTokens ${config.maxTokens}'
        : '${config.model} · maxTokens ${config.maxTokens}';

    return KiraSection(
      title: '配置',
      children: [
        // API 高级参数(可展开行:流式输出 / 自动摘要两个真开关)
        _ApiAdvancedTile(subtitle: modelSub),
        KiraGroupedTile(
          icon: CupertinoIcons.star,
          iconBg: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          title: 'AI 预设',
          subtitle: activePreset == null
              ? '未启用预设'
              : '当前：${activePreset.name} · 共 ${allPresets.length} 套',
          onTap: () => context.push(AppRoutes.aiPresets),
        ),
        KiraGroupedTile(
          icon: CupertinoIcons.list_bullet,
          iconBg: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          title: '提示词管理',
          subtitle: promptPreset == null
              ? '启用 ${enabledPrompts.length} 段'
              : '启用 ${enabledPrompts.length} 段 · 预设：${promptPreset.name}',
          onTap: () => context.push(AppRoutes.promptManager),
        ),
      ],
    );
  }
}

/// API 高级参数:只读摘要行 + 展开区(流式输出/自动摘要 真开关,进详情)
class _ApiAdvancedTile extends ConsumerStatefulWidget {
  const _ApiAdvancedTile({required this.subtitle});

  final String subtitle;

  @override
  ConsumerState<_ApiAdvancedTile> createState() => _ApiAdvancedTileState();
}

class _ApiAdvancedTileState extends ConsumerState<_ApiAdvancedTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = ref.watch(llmConfigProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        KiraGroupedTile(
          icon: CupertinoIcons.slider_horizontal_3,
          iconBg: theme.colorScheme.primary.withValues(alpha: 0.12),
          title: 'API 高级参数',
          subtitle: widget.subtitle,
          trailing: Icon(
            _expanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
            size: 16,
            color: theme.textTheme.bodySmall?.color,
          ),
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded) ...[
          Divider(height: 0.5, thickness: 0.5, color: theme.dividerColor),
          KiraSwitchTile(
            title: '流式输出',
            subtitle: '实时显示生成内容',
            value: config.streamEnabled,
            onChanged: (v) =>
                ref.read(llmConfigProvider.notifier).updateStreamEnabled(v),
          ),
          KiraSwitchTile(
            title: '自动摘要',
            subtitle: '长对话自动压缩上下文',
            value: config.autoSummarizeEnabled,
            onChanged: (v) =>
                ref.read(llmConfigProvider.notifier).updateAutoSummarizeEnabled(v),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(DesignTokens.spaceMd, 0,
                DesignTokens.spaceMd, DesignTokens.spaceSm),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '自动摘要会额外消耗 API 额度',
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeSm,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
            ),
          ),
          KiraGroupedTile(
            title: '更多采样参数',
            trailing: Icon(CupertinoIcons.chevron_forward,
                size: 16, color: theme.textTheme.bodySmall?.color),
            onTap: () => context.push(AppRoutes.advancedSettings),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// F-T5 快捷调整组:采样参数滑块自留地(沿 v1 结构,仅样式对齐)
// ═══════════════════════════════════════════════════════════════════════════
class _QuickAdjustSection extends ConsumerWidget {
  const _QuickAdjustSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final config = ref.watch(llmConfigProvider);

    return KiraSection.plain(
      title: '快捷调整',
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceMd,
          vertical: DesignTokens.spaceXs,
        ),
        child: Column(
          children: [
            _DashboardSlider(
              label: l10n.temperature,
              value: config.temperature,
              min: 0.0,
              max: 2.0,
              divisions: 40,
              onChanged: (v) =>
                  ref.read(llmConfigProvider.notifier).updateTemperature(v),
            ),
            _DashboardSlider(
              label: l10n.topPNucleusSampling,
              value: config.topP,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              onChanged: (v) =>
                  ref.read(llmConfigProvider.notifier).updateTopP(v),
            ),
            _DashboardSlider(
              label: l10n.topK,
              value: config.topK.toDouble(),
              min: 0,
              max: 200,
              divisions: 200,
              valueLabel: config.topK.toString(),
              onChanged: (v) =>
                  ref.read(llmConfigProvider.notifier).updateTopK(v.round()),
            ),
            _CollapsibleSection(
              label: '高级采样参数',
              children: [
                _DashboardSlider(
                  label: l10n.minP,
                  value: config.minP,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  onChanged: (v) =>
                      ref.read(llmConfigProvider.notifier).updateMinP(v),
                ),
                _DashboardSlider(
                  label: l10n.typicalP,
                  value: config.typicalP,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  onChanged: (v) =>
                      ref.read(llmConfigProvider.notifier).updateTypicalP(v),
                ),
                _DashboardSlider(
                  label: l10n.topA,
                  value: config.topA,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  onChanged: (v) =>
                      ref.read(llmConfigProvider.notifier).updateTopA(v),
                ),
                _DashboardSlider(
                  label: l10n.tailFreeSamplingTfs,
                  value: config.tailFreeSampling,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  onChanged: (v) => ref
                      .read(llmConfigProvider.notifier)
                      .updateTailFreeSampling(v),
                ),
              ],
            ),
            _CollapsibleSection(
              label: '重复惩罚',
              children: [
                _DashboardSlider(
                  label: l10n.repetitionPenalty,
                  value: config.repetitionPenalty,
                  min: 1.0,
                  max: 2.0,
                  divisions: 20,
                  onChanged: (v) => ref
                      .read(llmConfigProvider.notifier)
                      .updateRepetitionPenalty(v),
                ),
                _DashboardSlider(
                  label: l10n.frequencyPenalty,
                  value: config.frequencyPenalty,
                  min: -2.0,
                  max: 2.0,
                  divisions: 40,
                  onChanged: (v) => ref
                      .read(llmConfigProvider.notifier)
                      .updateFrequencyPenalty(v),
                ),
                _DashboardSlider(
                  label: l10n.presencePenalty,
                  value: config.presencePenalty,
                  min: -2.0,
                  max: 2.0,
                  divisions: 40,
                  onChanged: (v) => ref
                      .read(llmConfigProvider.notifier)
                      .updatePresencePenalty(v),
                ),
              ],
            ),
            _CollapsibleSection(
              label: '生成控制',
              children: [
                _IntInputRow(
                  label: l10n.maxTokens,
                  value: config.maxTokens,
                  onChanged: (v) =>
                      ref.read(llmConfigProvider.notifier).updateMaxTokens(v),
                ),
                _IntInputRow(
                  label: l10n.contextLength,
                  value: config.contextLength,
                  onChanged: (v) => ref
                      .read(llmConfigProvider.notifier)
                      .updateContextLength(v),
                ),
                _IntInputRow(
                  label: l10n.seed,
                  value: config.seed,
                  onChanged: (v) =>
                      ref.read(llmConfigProvider.notifier).updateSeed(v),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => context.push(AppRoutes.advancedSettings),
                icon: const Icon(Icons.more_horiz, size: 18),
                label: const Text('更多采样参数'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// F-T6 更多组:剩余入口紧凑列表 + 分词器计数真开关
// ═══════════════════════════════════════════════════════════════════════════
class _MoreSection extends ConsumerWidget {
  const _MoreSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryDim =
        Theme.of(context).colorScheme.primary.withValues(alpha: 0.12);
    final showTokenCount =
        ref.watch(tokenizerSettingsProvider).showTokenCount;

    return KiraSection(
      title: '更多',
      children: [
        KiraGroupedTile(
          icon: CupertinoIcons.photo_on_rectangle, iconBg: primaryDim,
          title: '图像生成',
          onTap: () => context.push(AppRoutes.imageGenSettings),
        ),
        KiraGroupedTile(
          icon: CupertinoIcons.smiley, iconBg: primaryDim,
          title: '精灵图',
          onTap: () => context.push(AppRoutes.spriteSettings),
        ),
        KiraGroupedTile(
          icon: CupertinoIcons.square_list, iconBg: primaryDim,
          title: '变量管理',
          onTap: () => context.push(AppRoutes.variablesSettings),
        ),
        KiraGroupedTile(
          icon: CupertinoIcons.chart_bar, iconBg: primaryDim,
          title: '日志统计',
          onTap: () => context.push(AppRoutes.statistics),
        ),
        KiraGroupedTile(
          icon: CupertinoIcons.cube_box, iconBg: primaryDim,
          title: 'MVU 变量框架',
          onTap: () => context.push(AppRoutes.mvuSettings),
        ),
        KiraSwitchTile(
          icon: CupertinoIcons.textformat_abc, iconBg: primaryDim,
          title: '分词器计数',
          subtitle: showTokenCount ? '已启用计数' : '计数关闭',
          value: showTokenCount,
          onChanged: (v) =>
              ref.read(tokenizerSettingsProvider.notifier).setShowTokenCount(v),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 小组件区(F-T5 沿用,样式对齐)
// ═══════════════════════════════════════════════════════════════════════════

/// 仪表盘紧凑滑块:标签 17,值 15/w600 primary,track 高 4(F-T5)
class _DashboardSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String? valueLabel;
  final ValueChanged<double> onChanged;

  const _DashboardSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.valueLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(
                      fontSize: DesignTokens.fontSizeBodyLarge,
                      color: theme.textTheme.bodyLarge?.color,
                    )),
              ),
              Text(
                valueLabel ?? value.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeBodyMedium,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
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
      ),
    );
  }
}

/// 可折叠区域(F-T5):箭头换 Cupertino,色次级
class _CollapsibleSection extends StatefulWidget {
  final String label;
  final List<Widget> children;
  const _CollapsibleSection({required this.label, required this.children});

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = theme.textTheme.bodySmall?.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceSm),
            child: Row(
              children: [
                Icon(
                  _expanded
                      ? CupertinoIcons.chevron_up
                      : CupertinoIcons.chevron_down,
                  size: 16,
                  color: sub,
                ),
                const SizedBox(width: 4),
                Text(widget.label,
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
        ),
        if (_expanded) ...widget.children,
      ],
    );
  }
}

/// 整数输入行(F-T5):点击 → 底部 Sheet 输入(不弹 AlertDialog)
class _IntInputRow extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _IntInputRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _showSheet(context),
      borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceSm),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeBodyLarge,
                    color: theme.textTheme.bodyLarge?.color,
                  )),
            ),
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: DesignTokens.fontSizeBodyMedium,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(CupertinoIcons.pencil,
                size: 14, color: theme.textTheme.bodySmall?.color),
          ],
        ),
      ),
    );
  }

  Future<void> _showSheet(BuildContext context) async {
    final controller = TextEditingController(text: value.toString());
    final result = await showModalBottomSheet<int>(
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
                label,
                style: const TextStyle(
                  fontSize: DesignTokens.fontSizeHeadline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(sheetCtx).colorScheme.surfaceContainerHighest,
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusGroupedCard),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final parsed = int.tryParse(controller.text.trim());
                    Navigator.pop(sheetCtx, parsed);
                  },
                  child: const Text('确定'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null) onChanged(result);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 保留的可视化件
// ═══════════════════════════════════════════════════════════════════════════

/// 环形进度(F-T2:环宽 8、尺寸 64、动画 curveSpring 温和回弹)
class _RingGauge extends StatelessWidget {
  final double value; // 0.0~1.0
  final Color color;
  final bool isDark;

  const _RingGauge({
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 350),
      curve: DesignTokens.curveSpring,
      builder: (context, v, _) => SizedBox(
        width: 64,
        height: 64,
        child: CustomPaint(
          painter: _RingPainter(
            value: v,
            color: color,
            trackColor: isDark
                ? DesignTokens.darkCard
                : DesignTokens.lightFillTertiary,
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;
  final Color trackColor;

  _RingPainter({
    required this.value,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 8.0;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -3.14159265 / 2, 2 * 3.14159265 * value, false, valuePaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.trackColor != trackColor;
}

/// 胶囊进度条(功能在线等)
class _CapsuleProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  final bool isDark;

  const _CapsuleProgressBar({
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: DesignTokens.durationMd),
      curve: DesignTokens.curveEmphasized,
      builder: (context, v, _) => ClipRRect(
        borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
        child: LinearProgressIndicator(
          value: v,
          minHeight: 6,
          backgroundColor: isDark
              ? DesignTokens.darkCard
              : DesignTokens.lightFillTertiary,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    );
  }
}

/// 分区入场:错峰 50ms 淡入上移(保留,F-T1)
class _SectionEntrance extends StatelessWidget {
  final int index;
  final Widget child;

  const _SectionEntrance({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    const duration = DesignTokens.durationMd;
    final delay = index.clamp(0, 12) * 50;
    final total = duration + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: DesignTokens.curveDecelerate),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
