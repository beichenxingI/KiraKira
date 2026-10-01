// lib/presentation/dialogs/cfg_scale_dialog.dart
/// CFG scale settings dialog.
/// Three-tier structure: LLM global (enable/scale slider/negative prompt/
/// positive prompt), character level (characterId passed: independent toggle/
/// scale/negative prompt override), chat level (chatId passed: scale/negative/
/// positive/combine mode/clear), help, reset confirmation.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/models/cfg_scale.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/providers/cfg_scale_providers.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'core_dialog.dart';

Future<void> showCfgScaleDialog(
  BuildContext context,
  WidgetRef ref, {
  String? characterId,
  String? chatId,
}) {
  return showCoreDialog(
    context,
    builder: (_) => _CfgScaleDialog(
      characterId: characterId,
      chatId: chatId,
    ),
  );
}

class _CfgScaleDialog extends ConsumerWidget {
  const _CfgScaleDialog({this.characterId, this.chatId});

  final String? characterId;
  final String? chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CoreDialogPalette(isDark: isDark);
    final settings = ref.watch(cfgScaleSettingsProvider);

    return CoreDialogShell(
      title: l10n.cfgScale,
      icon: CupertinoIcons.speedometer,
      maxWidth: 550,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            minSize: 0,
            onPressed: () => _showHelpSheet(context, palette),
            child: Icon(CupertinoIcons.question_circle,
                size: 20, color: palette.textSecondary),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            minSize: 0,
            onPressed: () => _confirmReset(context, ref),
            child: Icon(CupertinoIcons.refresh,
                size: 20, color: palette.textSecondary),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Global settings
          CoreSectionLabel(l10n.globalSettings),
          const SizedBox(height: 4),
          _Group(
            palette: palette,
            children: [
              CoreSwitchRow(
                title: l10n.enableCfgScale,
                subtitle: l10n.cfgScaleDescription,
                value: settings.enabled,
                palette: palette,
                onChanged: (v) =>
                    ref.read(cfgScaleSettingsProvider.notifier).setEnabled(v),
              ),
              _GuidanceScaleSlider(
                palette: palette,
                label: l10n.guidanceScale,
                value: settings.globalGuidanceScale,
                onChanged: settings.enabled
                    ? (v) => ref
                        .read(cfgScaleSettingsProvider.notifier)
                        .setGlobalGuidanceScale(v)
                    : null,
              ),
              const SizedBox(height: 8),
              _PromptTextField(
                palette: palette,
                label: l10n.negativePrompt,
                hint: l10n.textToSteerAwayFrom,
                value: settings.globalNegativePrompt,
                enabled: settings.enabled,
                onChanged: (v) => ref
                    .read(cfgScaleSettingsProvider.notifier)
                    .setGlobalNegativePrompt(v),
              ),
              const SizedBox(height: 8),
              _PromptTextField(
                palette: palette,
                label: l10n.positivePromptOptional,
                hint: l10n.textToEnhanceInOutput,
                value: settings.globalPositivePrompt,
                enabled: settings.enabled,
                onChanged: (v) => ref
                    .read(cfgScaleSettingsProvider.notifier)
                    .setGlobalPositivePrompt(v),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Character level (when characterId is provided)
          if (characterId != null) ...[
            _CharacterCFGSection(
              characterId: characterId!,
              globalEnabled: settings.enabled,
              palette: palette,
            ),
            const SizedBox(height: 20),
          ],

          // Chat level (when chatId is provided)
          if (chatId != null)
            _ChatCFGSection(
              chatId: chatId!,
              globalEnabled: settings.enabled,
              palette: palette,
            ),

          // About
          const SizedBox(height: 8),
          CoreInfoRow(
            icon: CupertinoIcons.info,
            title: l10n.aboutCfgScale,
            text: l10n.aboutCfgScaleDescription,
            palette: palette,
          ),
        ],
      ),
    );
  }

  /// Reset is destructive: confirm via CupertinoAlertDialog.
  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: Text(l10n.resetToDefaults),
        content: const Text('将所有 CFG 比例设置恢复为默认值？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(l10n.resetToDefaults),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    ref.read(cfgScaleSettingsProvider.notifier).resetToDefaults();
  }

  /// Help content in a bottom sheet.
  void _showHelpSheet(BuildContext context, CoreDialogPalette palette) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(14),
        ),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.cfgScaleHelp,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    l10n.cfgScaleHelpContent,
                    style: TextStyle(color: palette.textPrimary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheetCtx),
                  child: Text(l10n.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Character-level CFG section.
class _CharacterCFGSection extends ConsumerWidget {
  const _CharacterCFGSection({
    required this.characterId,
    required this.globalEnabled,
    required this.palette,
  });

  final String characterId;
  final bool globalEnabled;
  final CoreDialogPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(cfgScaleSettingsProvider);
    final charSettings = settings.characterSettings.firstWhere(
      (s) => s.characterId == characterId,
      orElse: () => CharacterCFGSettings.empty(characterId),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CoreSectionLabel(l10n.characterSettings),
        const SizedBox(height: 4),
        _Group(
          palette: palette,
          children: [
            CoreSwitchRow(
              title: l10n.useCharacterSpecificSettings,
              subtitle: l10n.overrideGlobalForCharacter,
              value: charSettings.useCharacterSettings,
              palette: palette,
              onChanged: globalEnabled
                  ? (v) => ref
                      .read(cfgScaleSettingsProvider.notifier)
                      .updateCharacterSettings(
                        charSettings.copyWith(useCharacterSettings: v),
                      )
                  : null,
            ),
            if (charSettings.useCharacterSettings)
              _GuidanceScaleSlider(
                palette: palette,
                label: l10n.guidanceScale,
                value: charSettings.guidanceScale ?? 1.0,
                onChanged: globalEnabled
                    ? (v) => ref
                        .read(cfgScaleSettingsProvider.notifier)
                        .updateCharacterSettings(
                          charSettings.copyWith(guidanceScale: v),
                        )
                    : null,
              ),
            if (charSettings.useCharacterSettings)
              _PromptTextField(
                palette: palette,
                label: l10n.characterNegativePrompt,
                hint: l10n.overrideGlobalNegativePrompt,
                value: charSettings.negativePrompt ?? '',
                enabled: globalEnabled,
                onChanged: (v) => ref
                    .read(cfgScaleSettingsProvider.notifier)
                    .updateCharacterSettings(
                      charSettings.copyWith(negativePrompt: v),
                    ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Chat-level CFG section.
class _ChatCFGSection extends ConsumerWidget {
  const _ChatCFGSection({
    required this.chatId,
    required this.globalEnabled,
    required this.palette,
  });

  final String chatId;
  final bool globalEnabled;
  final CoreDialogPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final chatSettings = ref.watch(chatCFGSettingsProvider(chatId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CoreSectionLabel(l10n.chatSettings),
        const SizedBox(height: 4),
        _Group(
          palette: palette,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.chatSettingsDescription,
                      style:
                          TextStyle(fontSize: 12, color: palette.textSecondary),
                    ),
                  ),
                  TextButton(
                    onPressed:
                        globalEnabled ? () => _confirmClear(context, ref) : null,
                    child: Text(l10n.clear),
                  ),
                ],
              ),
            ),
            _GuidanceScaleSlider(
              palette: palette,
              label: l10n.guidanceScale,
              value: chatSettings.guidanceScale ?? 1.0,
              onChanged: globalEnabled
                  ? (v) => ref
                      .read(chatCFGSettingsProvider(chatId).notifier)
                      .setGuidanceScale(v)
                  : null,
            ),
            _PromptTextField(
              palette: palette,
              label: l10n.chatNegativePrompt,
              hint: l10n.overrideForThisChat,
              value: chatSettings.negativePrompt ?? '',
              enabled: globalEnabled,
              onChanged: (v) => ref
                  .read(chatCFGSettingsProvider(chatId).notifier)
                  .setNegativePrompt(v),
            ),
            const SizedBox(height: 8),
            _PromptTextField(
              palette: palette,
              label: l10n.chatPositivePrompt,
              hint: l10n.enhancementForThisChat,
              value: chatSettings.positivePrompt ?? '',
              enabled: globalEnabled,
              onChanged: (v) => ref
                  .read(chatCFGSettingsProvider(chatId).notifier)
                  .setPositivePrompt(v),
            ),
            CoreTile(
              title: l10n.promptCombineMode,
              subtitle:
                  _getCombineModeLabel(l10n, chatSettings.promptCombineMode),
              onTap: globalEnabled ? () => _pickCombineMode(context, ref) : null,
            ),
          ],
        ),
      ],
    );
  }

  /// Clear is destructive: confirm via CupertinoAlertDialog.
  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: Text(l10n.clear),
        content: const Text('将清除此聊天的 CFG 覆盖设置，回到角色/全局设置？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(l10n.clear),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    ref.read(chatCFGSettingsProvider(chatId).notifier).clearSettings();
  }

  /// Combine mode picker via CupertinoActionSheet.
  Future<void> _pickCombineMode(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final selected = await showCupertinoModalPopup<PromptCombineMode>(
      context: context,
      builder: (sheetCtx) => CupertinoActionSheet(
        title: Text(l10n.promptCombineMode),
        actions: PromptCombineMode.values.map((mode) {
          return CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetCtx, mode),
            child: Text(_getCombineModeLabel(l10n, mode)),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetCtx),
          child: Text(l10n.cancel),
        ),
      ),
    );
    if (selected == null) return; // Cancelled
    ref
        .read(chatCFGSettingsProvider(chatId).notifier)
        .setPromptCombineMode(selected);
  }

  String _getCombineModeLabel(AppLocalizations l10n, PromptCombineMode mode) {
    switch (mode) {
      case PromptCombineMode.replace:
        return l10n.replaceChatPromptOnly;
      case PromptCombineMode.prepend:
        return l10n.prependChatPlusGlobal;
      case PromptCombineMode.append:
        return l10n.appendGlobalPlusChat;
    }
  }
}

/// Guidance scale slider with quick presets.
class _GuidanceScaleSlider extends StatelessWidget {
  const _GuidanceScaleSlider({
    required this.palette,
    required this.label,
    required this.value,
    this.onChanged,
  });

  final CoreDialogPalette palette;
  final String label;
  final double value;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style:
                      TextStyle(fontSize: 15, color: palette.textPrimary),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: DesignTokens.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  value.toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: DesignTokens.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Text('0.1',
                style: TextStyle(fontSize: 11, color: palette.textSecondary)),
            Expanded(
              child: Slider(
                value: value,
                min: 0.1,
                max: 30.0,
                divisions: 299,
                onChanged: enabled ? onChanged : null,
              ),
            ),
            Text('30.0',
                style: TextStyle(fontSize: 11, color: palette.textSecondary)),
          ],
        ),
        // Quick presets
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Wrap(
            spacing: 6,
            children: [1.0, 1.5, 2.0, 3.0, 5.0, 7.0].map((v) {
              final isSelected = (value - v).abs() < 0.01;
              return GestureDetector(
                onTap:
                    onChanged != null ? () => onChanged!(v) : null,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? DesignTokens.primary.withValues(alpha: 0.15)
                        : palette.fill,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? DesignTokens.primary : palette.outline,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    v.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? DesignTokens.primary
                          : palette.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// Prompt input field.
class _PromptTextField extends StatefulWidget {
  const _PromptTextField({
    required this.palette,
    required this.label,
    required this.hint,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final CoreDialogPalette palette;
  final String label;
  final String hint;
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  State<_PromptTextField> createState() => _PromptTextFieldState();
}

class _PromptTextFieldState extends State<_PromptTextField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_PromptTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            widget.label,
            style: TextStyle(fontSize: 15, color: widget.palette.textPrimary),
          ),
        ),
        const SizedBox(height: 4),
        CupertinoTextField(
          controller: _controller,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.palette.fill,
            borderRadius: BorderRadius.circular(8),
          ),
          placeholder: widget.hint,
          style: TextStyle(fontSize: 14, color: widget.palette.textPrimary),
          maxLines: 3,
          enabled: widget.enabled,
          onChanged: widget.onChanged,
        ),
      ],
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
