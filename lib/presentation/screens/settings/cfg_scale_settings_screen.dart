import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/widgets/common/common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/models/cfg_scale.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/providers/cfg_scale_providers.dart';

/// Settings screen for CFG Scale configuration
class CFGScaleSettingsScreen extends ConsumerWidget {
  final String? characterId;
  final String? chatId;

  const CFGScaleSettingsScreen({
    super.key,
    this.characterId,
    this.chatId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(cfgScaleSettingsProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(
              l10n.cfgScale,
              style: Theme.of(context).textTheme.displayLarge,
            ),
            actions: [
              IconButton(
                icon: const Icon(CupertinoIcons.question_circle),
                onPressed: () => _showHelpSheet(context),
                tooltip: l10n.help,
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.refresh),
                onPressed: () => _confirmReset(context, ref),
                tooltip: l10n.resetToDefaults,
              ),
            ],
          ),

          // 启用开关(置顶高频组,无组头)
          SliverToBoxAdapter(
            child: KiraSection(
              title: '',
              children: [
                KiraSwitchTile(
                  title: l10n.enableCfgScale,
                  subtitle: l10n.cfgScaleDescription,
                  value: settings.enabled,
                  onChanged: (value) {
                    ref.read(cfgScaleSettingsProvider.notifier).setEnabled(value);
                  },
                ),
              ],
            ),
          ),

          // 全局设置
          SliverToBoxAdapter(
            child: KiraSection.plain(
              title: l10n.globalSettings,
              child: Padding(
                padding: const EdgeInsets.all(DesignTokens.spaceMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GuidanceScaleSlider(
                      value: settings.globalGuidanceScale,
                      onChanged: settings.enabled
                          ? (value) {
                              ref
                                  .read(cfgScaleSettingsProvider.notifier)
                                  .setGlobalGuidanceScale(value);
                            }
                          : null,
                    ),
                    const SizedBox(height: DesignTokens.spaceMd),
                    _PromptTextField(
                      label: l10n.negativePrompt,
                      hint: l10n.textToSteerAwayFrom,
                      value: settings.globalNegativePrompt,
                      enabled: settings.enabled,
                      onChanged: (value) {
                        ref
                            .read(cfgScaleSettingsProvider.notifier)
                            .setGlobalNegativePrompt(value);
                      },
                    ),
                    const SizedBox(height: DesignTokens.spaceMd),
                    _PromptTextField(
                      label: l10n.positivePromptOptional,
                      hint: l10n.textToEnhanceInOutput,
                      value: settings.globalPositivePrompt,
                      enabled: settings.enabled,
                      onChanged: (value) {
                        ref
                            .read(cfgScaleSettingsProvider.notifier)
                            .setGlobalPositivePrompt(value);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Character-specific settings (if characterId provided)
          if (characterId != null)
            SliverToBoxAdapter(
              child: _CharacterCFGSection(
                characterId: characterId!,
                globalEnabled: settings.enabled,
              ),
            ),

          // Chat-specific settings (if chatId provided)
          if (chatId != null)
            SliverToBoxAdapter(
              child: _ChatCFGSection(
                chatId: chatId!,
                globalEnabled: settings.enabled,
              ),
            ),

          // Info section
          SliverToBoxAdapter(
            child: KiraSection.plain(
              title: l10n.aboutCfgScale,
              child: Padding(
                padding: const EdgeInsets.all(DesignTokens.spaceMd),
                child: Text(
                  l10n.aboutCfgScaleDescription,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ),

          // 留呼吸
          const SliverToBoxAdapter(child: SizedBox(height: DesignTokens.spaceXl)),
        ],
      ),
    );
  }

  /// 重置 = 破坏操作 → CupertinoAlertDialog 确认
  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: Text(l10n.resetToDefaults),
        // TODO(i18n): 待补 l10n key
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

  /// 信息帮助类 → 底部 Sheet(圆角 14,内容可滚)
  void _showHelpSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusBottomSheet),
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
                style: const TextStyle(
                  fontSize: DesignTokens.fontSizeHeadline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    l10n.cfgScaleHelpContent,
                    style: Theme.of(sheetCtx).textTheme.bodyMedium,
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

/// Slider widget for guidance scale
class _GuidanceScaleSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double>? onChanged;

  const _GuidanceScaleSlider({
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context).guidanceScale,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: DesignTokens.spaceXs),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
              ),
              child: Text(
                value.toStringAsFixed(2),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('0.1'),
            Expanded(
              child: Slider(
                value: value,
                min: 0.1,
                max: 30.0,
                divisions: 299,
                onChanged: enabled ? onChanged : null,
              ),
            ),
            const Text('30.0'),
          ],
        ),
        // Quick presets
        Wrap(
          spacing: 8,
          children: [
            _PresetChip(label: '1.0', value: 1.0, currentValue: value, onTap: onChanged),
            _PresetChip(label: '1.5', value: 1.5, currentValue: value, onTap: onChanged),
            _PresetChip(label: '2.0', value: 2.0, currentValue: value, onTap: onChanged),
            _PresetChip(label: '3.0', value: 3.0, currentValue: value, onTap: onChanged),
            _PresetChip(label: '5.0', value: 5.0, currentValue: value, onTap: onChanged),
            _PresetChip(label: '7.0', value: 7.0, currentValue: value, onTap: onChanged),
          ],
        ),
      ],
    );
  }
}

/// Chip for quick preset selection
class _PresetChip extends StatelessWidget {
  final String label;
  final double value;
  final double currentValue;
  final ValueChanged<double>? onTap;

  const _PresetChip({
    required this.label,
    required this.value,
    required this.currentValue,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = (currentValue - value).abs() < 0.01;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onTap != null ? (_) => onTap!(value) : null,
    );
  }
}

/// Text field for prompts
class _PromptTextField extends StatefulWidget {
  final String label;
  final String hint;
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _PromptTextField({
    required this.label,
    required this.hint,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

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
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
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
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        border: const OutlineInputBorder(),
        enabled: widget.enabled,
      ),
      maxLines: 3,
      onChanged: widget.onChanged,
    );
  }
}

/// Section for character-specific CFG settings
class _CharacterCFGSection extends ConsumerWidget {
  final String characterId;
  final bool globalEnabled;

  const _CharacterCFGSection({
    required this.characterId,
    required this.globalEnabled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(cfgScaleSettingsProvider);
    final charSettings = settings.characterSettings.firstWhere(
      (s) => s.characterId == characterId,
      orElse: () => CharacterCFGSettings.empty(characterId),
    );

    return KiraSection.plain(
      title: l10n.characterSettings,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KiraSwitchTile(
            title: l10n.useCharacterSpecificSettings,
            subtitle: l10n.overrideGlobalForCharacter,
            value: charSettings.useCharacterSettings,
            onChanged: globalEnabled
                ? (value) {
                    ref.read(cfgScaleSettingsProvider.notifier).updateCharacterSettings(
                          charSettings.copyWith(useCharacterSettings: value),
                        );
                  }
                : null,
          ),
          if (charSettings.useCharacterSettings)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DesignTokens.spaceMd,
                DesignTokens.spaceSm,
                DesignTokens.spaceMd,
                DesignTokens.spaceMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GuidanceScaleSlider(
                    value: charSettings.guidanceScale ?? 1.0,
                    onChanged: globalEnabled
                        ? (value) {
                            ref.read(cfgScaleSettingsProvider.notifier).updateCharacterSettings(
                                  charSettings.copyWith(guidanceScale: value),
                                );
                          }
                        : null,
                  ),
                  const SizedBox(height: DesignTokens.spaceMd),
                  _PromptTextField(
                    label: l10n.characterNegativePrompt,
                    hint: l10n.overrideGlobalNegativePrompt,
                    value: charSettings.negativePrompt ?? '',
                    enabled: globalEnabled,
                    onChanged: (value) {
                      ref.read(cfgScaleSettingsProvider.notifier).updateCharacterSettings(
                            charSettings.copyWith(negativePrompt: value),
                          );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Section for chat-specific CFG settings
class _ChatCFGSection extends ConsumerWidget {
  final String chatId;
  final bool globalEnabled;

  const _ChatCFGSection({
    required this.chatId,
    required this.globalEnabled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final chatSettings = ref.watch(chatCFGSettingsProvider(chatId));

    return KiraSection.plain(
      title: l10n.chatSettings,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DesignTokens.spaceMd,
              DesignTokens.spaceSm,
              DesignTokens.spaceSm,
              0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    l10n.chatSettingsDescription,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: globalEnabled
                      ? () => _confirmClear(context, ref)
                      : null,
                  child: Text(l10n.clear),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(DesignTokens.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GuidanceScaleSlider(
                  value: chatSettings.guidanceScale ?? 1.0,
                  onChanged: globalEnabled
                      ? (value) {
                          ref.read(chatCFGSettingsProvider(chatId).notifier).setGuidanceScale(value);
                        }
                      : null,
                ),
                const SizedBox(height: DesignTokens.spaceMd),
                _PromptTextField(
                  label: l10n.chatNegativePrompt,
                  hint: l10n.overrideForThisChat,
                  value: chatSettings.negativePrompt ?? '',
                  enabled: globalEnabled,
                  onChanged: (value) {
                    ref.read(chatCFGSettingsProvider(chatId).notifier).setNegativePrompt(value);
                  },
                ),
                const SizedBox(height: DesignTokens.spaceMd),
                _PromptTextField(
                  label: l10n.chatPositivePrompt,
                  hint: l10n.enhancementForThisChat,
                  value: chatSettings.positivePrompt ?? '',
                  enabled: globalEnabled,
                  onChanged: (value) {
                    ref.read(chatCFGSettingsProvider(chatId).notifier).setPositivePrompt(value);
                  },
                ),
                const SizedBox(height: DesignTokens.spaceMd),
                // 合并模式:单选 → CupertinoActionSheet
                KiraGroupedTile(
                  title: l10n.promptCombineMode,
                  subtitle: _getCombineModeLabel(l10n, chatSettings.promptCombineMode),
                  onTap: globalEnabled
                      ? () => _pickCombineMode(context, ref)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 清除 = 破坏操作 → CupertinoAlertDialog 确认
  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: Text(l10n.clear),
        // TODO(i18n): 待补 l10n key
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

  /// 单选合并模式 → CupertinoActionSheet(iOS 常规选择器)
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
    if (selected == null) return; // 取消
    ref.read(chatCFGSettingsProvider(chatId).notifier).setPromptCombineMode(selected);
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
