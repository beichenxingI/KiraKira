// lib/presentation/dialogs/advanced_sampling_dialog.dart
/// Advanced sampling parameter dialog.
/// Sections: basic sampling (temperature/TopP/TopK),
/// advanced sampling (minP/typicalP/topA/TFS),
/// repetition control (repPenalty/Range/freqPen/presPen), Mirostat (mode/tau/eta),
/// generation control (maxTokens/seed/stop sequences), CFG scale (LLM global),
/// reset to defaults (with confirmation).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/providers/cfg_scale_providers.dart';
import 'package:kirakira/presentation/providers/settings_providers.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'core_dialog.dart';

Future<void> showAdvancedSamplingDialog(BuildContext context, WidgetRef ref) {
  return showCoreDialog(
    context,
    builder: (_) => const _AdvancedSamplingDialog(),
  );
}

class _AdvancedSamplingDialog extends ConsumerWidget {
  const _AdvancedSamplingDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CoreDialogPalette(isDark: isDark);
    final config = ref.watch(llmConfigProvider);
    final cfg = ref.watch(cfgScaleSettingsProvider);

    return CoreDialogShell(
      title: '高级采样参数',
      icon: CupertinoIcons.slider_horizontal_3,
      maxWidth: 550,
      trailing: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minSize: 0,
        onPressed: () => _showResetConfirmation(context, ref, l10n),
        child: Icon(
          CupertinoIcons.arrow_counterclockwise,
          size: 20,
          color: palette.textSecondary,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic sampling
          CoreSectionLabel(l10n.basicSampling),
          const SizedBox(height: 4),
          _Group(
            palette: palette,
            children: [
              _SliderTile(
                palette: palette,
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
              _rowDivider(palette),
              _SliderTile(
                palette: palette,
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
              _rowDivider(palette),
              _SliderTile(
                palette: palette,
                title: l10n.topK,
                subtitle: l10n.topKDescription,
                value: config.topK.toDouble(),
                min: 0,
                max: 200,
                divisions: 200,
                display: '${config.topK}',
                onChanged: (v) => ref
                    .read(llmConfigProvider.notifier)
                    .updateTopK(v.round()),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Advanced sampling
          CoreSectionLabel(l10n.advancedSampling),
          const SizedBox(height: 4),
          _Group(
            palette: palette,
            children: [
              _SliderTile(
                palette: palette,
                title: l10n.minP,
                subtitle: l10n.minPDescription,
                value: config.minP,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                onChanged: (v) =>
                    ref.read(llmConfigProvider.notifier).updateMinP(v),
              ),
              _rowDivider(palette),
              _SliderTile(
                palette: palette,
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
              _rowDivider(palette),
              _SliderTile(
                palette: palette,
                title: l10n.topA,
                subtitle: l10n.topADescription,
                value: config.topA,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                onChanged: (v) =>
                    ref.read(llmConfigProvider.notifier).updateTopA(v),
              ),
              _rowDivider(palette),
              _SliderTile(
                palette: palette,
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
          const SizedBox(height: 20),

          // Repetition control
          CoreSectionLabel(l10n.repetitionControl),
          const SizedBox(height: 4),
          _Group(
            palette: palette,
            children: [
              _SliderTile(
                palette: palette,
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
              _rowDivider(palette),
              _SliderTile(
                palette: palette,
                title: l10n.repetitionPenaltyRange,
                subtitle: l10n.repetitionPenaltyRangeDescription,
                value: config.repetitionPenaltyRange.toDouble(),
                min: 0,
                max: 4096,
                divisions: 4096,
                display: '${config.repetitionPenaltyRange}',
                onChanged: (v) => ref
                    .read(llmConfigProvider.notifier)
                    .updateRepetitionPenaltyRange(v.round()),
              ),
              _rowDivider(palette),
              _SliderTile(
                palette: palette,
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
              _rowDivider(palette),
              _SliderTile(
                palette: palette,
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
          const SizedBox(height: 20),

          // Mirostat
          CoreSectionLabel(l10n.mirostatLocalModels),
          const SizedBox(height: 4),
          _Group(
            palette: palette,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.mirostatMode,
                      style: TextStyle(
                          fontSize: 15, color: palette.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.adaptiveSamplingForLocalModels,
                      style: TextStyle(
                          fontSize: 12, color: palette.textSecondary),
                    ),
                    const SizedBox(height: 8),
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
                _rowDivider(palette),
                _SliderTile(
                  palette: palette,
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
                _rowDivider(palette),
                _SliderTile(
                  palette: palette,
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
          const SizedBox(height: 20),

          // Generation control
          CoreSectionLabel(l10n.generationControl),
          const SizedBox(height: 4),
          _Group(
            palette: palette,
            children: [
              _IntInputTile(
                palette: palette,
                title: l10n.maxTokens,
                subtitle: l10n.maxTokensDescription,
                value: config.maxTokens,
                onOpen: () => _showIntInputSheet(
                  context,
                  l10n.maxTokens,
                  config.maxTokens,
                  (v) => ref
                      .read(llmConfigProvider.notifier)
                      .updateMaxTokens(v),
                  palette,
                ),
              ),
              _rowDivider(palette),
              _IntInputTile(
                palette: palette,
                title: l10n.seed,
                subtitle: l10n.seedDescription,
                value: config.seed,
                onOpen: () => _showIntInputSheet(
                  context,
                  l10n.seed,
                  config.seed,
                  (v) =>
                      ref.read(llmConfigProvider.notifier).updateSeed(v),
                  palette,
                ),
              ),
              _rowDivider(palette),
              CoreTile(
                title: l10n.stopSequences,
                subtitle: config.stopSequences.isEmpty
                    ? l10n.noStopSequencesConfigured
                    : config.stopSequences.join(', '),
                onTap: () => _showStopSequencesSheet(
                    context, ref, config.stopSequences, palette),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // CFG scale (LLM global)
          const CoreSectionLabel('CFG Scale（LLM 全局级）'),
          const SizedBox(height: 4),
          _Group(
            palette: palette,
            children: [
              CoreSwitchRow(
                title: l10n.enableCfgScale,
                subtitle: l10n.cfgScaleDescription,
                value: cfg.enabled,
                palette: palette,
                onChanged: (v) => ref
                    .read(cfgScaleSettingsProvider.notifier)
                    .setEnabled(v),
              ),
              _SliderTile(
                palette: palette,
                title: l10n.guidanceScale,
                subtitle: '',
                value: cfg.globalGuidanceScale,
                min: 0.1,
                max: 30.0,
                divisions: 299,
                display: cfg.globalGuidanceScale.toStringAsFixed(2),
                onChanged: cfg.enabled
                    ? (v) => ref
                        .read(cfgScaleSettingsProvider.notifier)
                        .setGlobalGuidanceScale(v)
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Wrap(
                  spacing: 8,
                  children: [1.0, 1.5, 2.0, 3.0, 5.0, 7.0]
                      .map((v) => _PresetChip(
                            palette: palette,
                            label: v.toString(),
                            value: v,
                            currentValue: cfg.globalGuidanceScale,
                            onTap: cfg.enabled
                                ? (val) => ref
                                    .read(cfgScaleSettingsProvider.notifier)
                                    .setGlobalGuidanceScale(val)
                                : null,
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rowDivider(CoreDialogPalette palette) =>
      Divider(height: 0.5, thickness: 0.5, color: palette.divider);

  /// Reset to defaults (destructive confirmation).
  void _showResetConfirmation(
      BuildContext context, WidgetRef ref, AppLocalizations l10n) {
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
              coreToast(context, l10n.settingsResetToDefaults);
            },
            child: Text(l10n.reset),
          ),
        ],
      ),
    );
  }

  /// Integer input in a bottom sheet.
  void _showIntInputSheet(
    BuildContext context,
    String title,
    int currentValue,
    ValueChanged<int> onChanged,
    CoreDialogPalette palette,
  ) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: currentValue.toString());
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
                title,
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeHeadline,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.fill,
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusGroupedCard),
                ),
                style: TextStyle(color: palette.textPrimary),
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

  // Legacy auto-summary entries were removed (_showSummaryModelSheet/_showSummaryPromptSheet);
  // summarization is now managed by the Chronicle settings dialog (summary model / custom append instructions).

  /// Stop sequences in a bottom sheet.
  void _showStopSequencesSheet(
    BuildContext context,
    WidgetRef ref,
    List<String> currentSequences,
    CoreDialogPalette palette,
  ) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(
      text: currentSequences.join('\n'),
    );
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
                l10n.stopSequences,
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeHeadline,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.stopSequencesDescription,
                style: TextStyle(
                    fontSize: DesignTokens.fontSizeSm,
                    color: palette.textSecondary),
              ),
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: controller,
                autofocus: true,
                maxLines: 5,
                placeholder: 'e.g.\n\\n\\n\n[END]\n</s>',
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.fill,
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusGroupedCard),
                ),
                style: TextStyle(color: palette.textPrimary),
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
}

/// Slider row (title + current value + description + slider).
class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.palette,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.display,
  });

  final CoreDialogPalette palette;
  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String? display;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 15, color: palette.textPrimary),
                ),
              ),
              Text(
                display ?? value.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: DesignTokens.primary,
                ),
              ),
            ],
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: palette.textSecondary),
            ),
          ],
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
}

/// Integer input row (opens a bottom sheet on tap).
class _IntInputTile extends StatelessWidget {
  const _IntInputTile({
    required this.palette,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onOpen,
  });

  final CoreDialogPalette palette;
  final String title;
  final String subtitle;
  final int value;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return CoreTile(
      title: title,
      subtitle: subtitle,
      trailing: Text(
        value.toString(),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: DesignTokens.primary,
        ),
      ),
      onTap: onOpen,
    );
  }
}

/// Quick CFG preset chip.
class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.palette,
    required this.label,
    required this.value,
    required this.currentValue,
    this.onTap,
  });

  final CoreDialogPalette palette;
  final String label;
  final double value;
  final double currentValue;
  final ValueChanged<double>? onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = (currentValue - value).abs() < 0.01;
    return GestureDetector(
      onTap: onTap != null ? () => onTap!(value) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? DesignTokens.primary.withValues(alpha: 0.15)
              : palette.fill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? DesignTokens.primary : palette.outline,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color:
                isSelected ? DesignTokens.primary : palette.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Group container used inside the dialog.
class _Group extends StatelessWidget {
  const _Group({required this.palette, required this.children});

  final CoreDialogPalette palette;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color:
            palette.fill.withValues(alpha: palette.isDark ? 0.55 : 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: children),
    );
  }
}
