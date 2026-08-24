import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/providers/settings_providers.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/widgets/common/common.dart';

/// Advanced settings screen for full sampler control
class AdvancedSettingsScreen extends ConsumerWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final config = ref.watch(llmConfigProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(
              l10n.advancedSettings,
              style: Theme.of(context).textTheme.displayLarge,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.restore),
                tooltip: l10n.resetToDefaults,
                onPressed: () => _showResetConfirmation(context, ref),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                // ── 采样子组:基础采样 ──
                KiraSection.plain(
                  title: l10n.basicSampling,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSliderTile(
                        context: context,
                        title: l10n.temperature,
                        subtitle: l10n.temperatureDescription,
                        value: config.temperature,
                        min: 0.0,
                        max: 2.0,
                        divisions: 40,
                        onChanged: (v) => ref
                            .read(llmConfigProvider.notifier)
                            .updateTemperature(v),
                      ),
                      _rowDivider(context),
                      _buildSliderTile(
                        context: context,
                        title: l10n.topPNucleusSampling,
                        subtitle: l10n.topPDescription,
                        value: config.topP,
                        min: 0.0,
                        max: 1.0,
                        divisions: 20,
                        onChanged: (v) => ref
                            .read(llmConfigProvider.notifier)
                            .updateTopP(v),
                      ),
                      _rowDivider(context),
                      _buildIntSliderTile(
                        context: context,
                        title: l10n.topK,
                        subtitle: l10n.topKDescription,
                        value: config.topK,
                        min: 0,
                        max: 200,
                        onChanged: (v) => ref
                            .read(llmConfigProvider.notifier)
                            .updateTopK(v),
                      ),
                    ],
                  ),
                ),

                // ── 采样子组:高级采样 ──
                KiraSection.plain(
                  title: l10n.advancedSampling,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSliderTile(
                        context: context,
                        title: l10n.minP,
                        subtitle: l10n.minPDescription,
                        value: config.minP,
                        min: 0.0,
                        max: 1.0,
                        divisions: 20,
                        onChanged: (v) => ref
                            .read(llmConfigProvider.notifier)
                            .updateMinP(v),
                      ),
                      _rowDivider(context),
                      _buildSliderTile(
                        context: context,
                        title: l10n.typicalP,
                        subtitle: l10n.typicalPDescription,
                        value: config.typicalP,
                        min: 0.0,
                        max: 1.0,
                        divisions: 20,
                        onChanged: (v) => ref
                            .read(llmConfigProvider.notifier)
                            .updateTypicalP(v),
                      ),
                      _rowDivider(context),
                      _buildSliderTile(
                        context: context,
                        title: l10n.topA,
                        subtitle: l10n.topADescription,
                        value: config.topA,
                        min: 0.0,
                        max: 1.0,
                        divisions: 20,
                        onChanged: (v) => ref
                            .read(llmConfigProvider.notifier)
                            .updateTopA(v),
                      ),
                      _rowDivider(context),
                      _buildSliderTile(
                        context: context,
                        title: l10n.tailFreeSamplingTfs,
                        subtitle: l10n.tfsDescription,
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
                ),

                // ── 采样子组:重复控制 ──
                KiraSection.plain(
                  title: l10n.repetitionControl,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSliderTile(
                        context: context,
                        title: l10n.repetitionPenalty,
                        subtitle: l10n.repetitionPenaltyDescription,
                        value: config.repetitionPenalty,
                        min: 1.0,
                        max: 2.0,
                        divisions: 20,
                        onChanged: (v) => ref
                            .read(llmConfigProvider.notifier)
                            .updateRepetitionPenalty(v),
                      ),
                      _rowDivider(context),
                      _buildIntSliderTile(
                        context: context,
                        title: l10n.repetitionPenaltyRange,
                        subtitle: l10n.repetitionPenaltyRangeDescription,
                        value: config.repetitionPenaltyRange,
                        min: 0,
                        max: 4096,
                        onChanged: (v) => ref
                            .read(llmConfigProvider.notifier)
                            .updateRepetitionPenaltyRange(v),
                      ),
                      _rowDivider(context),
                      _buildSliderTile(
                        context: context,
                        title: l10n.frequencyPenalty,
                        subtitle: l10n.frequencyPenaltyDescription,
                        value: config.frequencyPenalty,
                        min: 0.0,
                        max: 2.0,
                        divisions: 40,
                        onChanged: (v) => ref
                            .read(llmConfigProvider.notifier)
                            .updateFrequencyPenalty(v),
                      ),
                      _rowDivider(context),
                      _buildSliderTile(
                        context: context,
                        title: l10n.presencePenalty,
                        subtitle: l10n.presencePenaltyDescription,
                        value: config.presencePenalty,
                        min: 0.0,
                        max: 2.0,
                        divisions: 40,
                        onChanged: (v) => ref
                            .read(llmConfigProvider.notifier)
                            .updatePresencePenalty(v),
                      ),
                    ],
                  ),
                ),

                // ── Mirostat 组 ──
                KiraSection.plain(
                  title: l10n.mirostatLocalModels,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(DesignTokens.spaceMd),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.mirostatMode,
                              style: TextStyle(
                                fontSize: DesignTokens.fontSizeBodyLarge,
                                color:
                                    Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                            ),
                            const SizedBox(height: DesignTokens.spaceXxs),
                            Text(
                              l10n.adaptiveSamplingForLocalModels,
                              style: const TextStyle(
                                fontSize: DesignTokens.fontSizeSm,
                                color: DesignTokens.darkTextSecondary,
                              ),
                            ),
                            const SizedBox(height: DesignTokens.spaceSm),
                            SizedBox(
                              width: double.infinity,
                              child: CupertinoSlidingSegmentedControl<int>(
                                groupValue: config.mirostatMode,
                                children: {
                                  0: Text(l10n.off),
                                  1: const Text('v1'),
                                  2: const Text('v2'),
                                },
                                onValueChanged: (v) {
                                  if (v != null) {
                                    ref
                                        .read(llmConfigProvider.notifier)
                                        .updateMirostatMode(v);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (config.mirostatMode > 0) ...[
                        _rowDivider(context),
                        _buildSliderTile(
                          context: context,
                          title: l10n.mirostatTau,
                          subtitle: l10n.mirostatTauDescription,
                          value: config.mirostatTau,
                          min: 0.0,
                          max: 10.0,
                          divisions: 20,
                          onChanged: (v) => ref
                              .read(llmConfigProvider.notifier)
                              .updateMirostatTau(v),
                        ),
                        _rowDivider(context),
                        _buildSliderTile(
                          context: context,
                          title: l10n.mirostatEta,
                          subtitle: l10n.mirostatEtaDescription,
                          value: config.mirostatEta,
                          min: 0.0,
                          max: 1.0,
                          divisions: 20,
                          onChanged: (v) => ref
                              .read(llmConfigProvider.notifier)
                              .updateMirostatEta(v),
                        ),
                      ],
                    ],
                  ),
                ),

                // ── 总结组 ──
                KiraSection(
                  title: l10n.contextManagement,
                  children: [
                    KiraSwitchTile(
                      icon: Icons.compress,
                      title: l10n.autoSummarize,
                      subtitle: l10n.autoSummarizeDescription,
                      value: config.autoSummarizeEnabled,
                      onChanged: (value) {
                        ref
                            .read(llmConfigProvider.notifier)
                            .updateAutoSummarizeEnabled(value);
                      },
                    ),
                    if (config.autoSummarizeEnabled) ...[
                      _buildSliderTile(
                        context: context,
                        title: l10n.autoSummarizeThreshold,
                        subtitle: l10n.autoSummarizeThresholdDescription,
                        value: config.autoSummarizeThreshold,
                        min: 0.5,
                        max: 0.95,
                        divisions: 9,
                        onChanged: (v) => ref
                            .read(llmConfigProvider.notifier)
                            .updateAutoSummarizeThreshold(v),
                      ),
                      KiraGroupedTile(
                        title: '总结模型',
                        subtitle: config.summaryModel.isEmpty
                            ? '沿用主聊天模型'
                            : config.summaryModel,
                        onTap: () => _showSummaryModelSheet(
                            context, ref, config.summaryModel),
                      ),
                      KiraGroupedTile(
                        title: '自定义总结提示词',
                        subtitle: config.summaryPrompt.isEmpty
                            ? '使用默认中文提示词'
                            : config.summaryPrompt,
                        onTap: () => _showSummaryPromptSheet(
                            context, ref, config.summaryPrompt),
                      ),
                    ],
                  ],
                ),

                // ── 生成控制 ──
                KiraSection(
                  title: l10n.generationControl,
                  children: [
                    _buildIntInputTile(
                      context: context,
                      title: l10n.maxTokens,
                      subtitle: l10n.maxTokensDescription,
                      value: config.maxTokens,
                      onChanged: (v) => ref
                          .read(llmConfigProvider.notifier)
                          .updateMaxTokens(v),
                    ),
                    _buildIntInputTile(
                      context: context,
                      title: l10n.seed,
                      subtitle: l10n.seedDescription,
                      value: config.seed,
                      onChanged: (v) => ref
                          .read(llmConfigProvider.notifier)
                          .updateSeed(v),
                    ),
                    KiraGroupedTile(
                      title: l10n.stopSequences,
                      subtitle: config.stopSequences.isEmpty
                          ? l10n.noStopSequencesConfigured
                          : config.stopSequences.join(', '),
                      onTap: () => _showStopSequencesSheet(
                          context, ref, config.stopSequences),
                    ),
                  ],
                ),

                const SizedBox(height: DesignTokens.spaceXl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 组内行分隔线(0.5、indent 16,与 KiraSection 默认分隔线同规格)
  Widget _rowDivider(BuildContext context) {
    return Divider(
      height: 0.5,
      thickness: 0.5,
      indent: DesignTokens.spaceMd,
      color: Theme.of(context).dividerColor,
    );
  }

  Widget _buildSliderTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceMd,
        vertical: DesignTokens.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeBodyLarge,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ),
              Text(
                value.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: DesignTokens.fontSizeBodyMedium,
                  color: DesignTokens.primary,
                  fontWeight: DesignTokens.weightSemibold,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceXxs),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: DesignTokens.fontSizeSm,
              color: DesignTokens.darkTextSecondary,
            ),
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildIntSliderTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceMd,
        vertical: DesignTokens.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeBodyLarge,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ),
              Text(
                value.toString(),
                style: const TextStyle(
                  fontSize: DesignTokens.fontSizeBodyMedium,
                  color: DesignTokens.primary,
                  fontWeight: DesignTokens.weightSemibold,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceXxs),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: DesignTokens.fontSizeSm,
              color: DesignTokens.darkTextSecondary,
            ),
          ),
          Slider(
            value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      ),
    );
  }

  Widget _buildIntInputTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return KiraGroupedTile(
      title: title,
      subtitle: subtitle,
      trailing: Text(
        value.toString(),
        style: const TextStyle(
          fontSize: DesignTokens.fontSizeBodyMedium,
          color: DesignTokens.primary,
          fontWeight: DesignTokens.weightSemibold,
        ),
      ),
      onTap: () => _showIntInputSheet(context, title, value, onChanged),
    );
  }

  /// 单字段输入(整数)→ 底部 Sheet(D-T2 规则 2,照抄 ai_presets_screen)
  void _showIntInputSheet(
    BuildContext context,
    String title,
    int currentValue,
    ValueChanged<int> onChanged,
  ) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: currentValue.toString());
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
                title,
                style: const TextStyle(
                  fontSize: DesignTokens.fontSizeHeadline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      Theme.of(sheetCtx).colorScheme.surfaceContainerHighest,
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusGroupedCard),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final value = int.tryParse(controller.text);
                    if (value != null) {
                      onChanged(value);
                    }
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

  /// 单字段输入(总结模型)→ 底部 Sheet
  void _showSummaryModelSheet(
      BuildContext context, WidgetRef ref, String current) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: current);
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
              const Text(
                '总结模型',
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeHeadline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '指定用于自动总结的模型（可填便宜的小模型省成本）。留空则沿用主聊天模型。',
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeSm,
                  color: DesignTokens.darkTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: controller,
                autofocus: true,
                placeholder: '例如 gpt-4o-mini',
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      Theme.of(sheetCtx).colorScheme.surfaceContainerHighest,
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusGroupedCard),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    ref
                        .read(llmConfigProvider.notifier)
                        .updateSummaryModel(controller.text.trim());
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

  /// 单字段输入(自定义总结提示词)→ 底部 Sheet
  void _showSummaryPromptSheet(
      BuildContext context, WidgetRef ref, String current) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: current);
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
              const Text(
                '自定义总结提示词',
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeHeadline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '自定义总结时的指令。留空则使用内置中文提示词（保留剧情、关系、时间线、状态等）。',
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeSm,
                  color: DesignTokens.darkTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: controller,
                maxLines: 8,
                placeholder: '例如：用中文总结，重点保留好感度与时间线……',
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      Theme.of(sheetCtx).colorScheme.surfaceContainerHighest,
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusGroupedCard),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    ref
                        .read(llmConfigProvider.notifier)
                        .updateSummaryPrompt(controller.text.trim());
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

  /// 单字段输入(停止序列)→ 底部 Sheet
  void _showStopSequencesSheet(
    BuildContext context,
    WidgetRef ref,
    List<String> currentSequences,
  ) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(
      text: currentSequences.join('\n'),
    );
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
                l10n.stopSequences,
                style: const TextStyle(
                  fontSize: DesignTokens.fontSizeHeadline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.stopSequencesDescription,
                style: const TextStyle(
                  fontSize: DesignTokens.fontSizeSm,
                  color: DesignTokens.darkTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: controller,
                autofocus: true,
                maxLines: 5,
                placeholder: 'e.g.\n\\n\\n\n[END]\n</s>',
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      Theme.of(sheetCtx).colorScheme.surfaceContainerHighest,
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusGroupedCard),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final sequences = controller.text
                        .split('\n')
                        .map((s) => s.trim())
                        .where((s) => s.isNotEmpty)
                        .toList();
                    ref
                        .read(llmConfigProvider.notifier)
                        .updateStopSequences(sequences);
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

  /// 破坏确认(恢复默认)→ CupertinoAlertDialog(D-T2 规则 1)
  void _showResetConfirmation(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: Text(l10n.resetToDefaults),
        content: Text(l10n.resetConfirmation),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              ref.read(llmConfigProvider.notifier).resetToDefaults();
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.settingsResetToDefaults)),
              );
            },
            child: Text(l10n.reset),
          ),
        ],
      ),
    );
  }
}
