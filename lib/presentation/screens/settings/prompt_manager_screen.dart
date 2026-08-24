import 'dart:convert';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/widgets/common/common.dart';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:kirakira/data/models/prompt_manager.dart';
import 'package:kirakira/presentation/providers/prompt_manager_providers.dart';
import 'package:kirakira/presentation/theme/app_theme.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'prompt_section_edit_screen.dart';

/// Screen for managing prompt section order and visibility
class PromptManagerScreen extends ConsumerWidget {
  const PromptManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(promptManagerProvider);
    final sortedSections = config.sortedSections;
    final allPresets = ref.watch(allPresetsProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(
              AppLocalizations.of(context)!.promptManager,
              style: Theme.of(context).textTheme.displayLarge,
            ),
            actions: [
          PopupMenuButton<String>(
            icon: const Icon(CupertinoIcons.ellipsis_circle),
            tooltip: AppLocalizations.of(context)!.moreOptions,
            onSelected: (value) {
              switch (value) {
                case 'presets':
                  _showPresetsDialog(context, ref, allPresets);
                  break;
                case 'import':
                  _importPreset(context, ref);
                  break;
                case 'export':
                  _exportPreset(context, ref);
                  break;
                case 'save':
                  _saveAsPreset(context, ref);
                  break;
                case 'reset':
                  _showResetConfirmation(context, ref);
                  break;
                case 'help':
                  _showHelpDialog(context);
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'presets',
                child: ListTile(
                  leading: const Icon(Icons.list),
                  title: Text(AppLocalizations.of(context)!.loadPreset),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'save',
                child: ListTile(
                  leading: const Icon(Icons.save),
                  title: Text(AppLocalizations.of(context)!.saveAsPresetLabel),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: const Icon(Icons.file_download),
                  title: Text(AppLocalizations.of(context)!.importPresetLabel),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: const Icon(Icons.file_upload),
                  title: Text(AppLocalizations.of(context)!.exportPreset),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'reset',
                child: ListTile(
                  leading: const Icon(Icons.restore),
                  title: Text(AppLocalizations.of(context)!.resetToDefault),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'help',
                child: ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: Text(AppLocalizations.of(context)!.help),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
          ),

          // Info banner
          SliverToBoxAdapter(
            child: Padding(
              padding: DesignTokens.paddingScreen,
              child: Container(
                padding: const EdgeInsets.all(DesignTokens.spaceMd),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.dragToReorder,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Reorderable list(sliver 化)
          SliverReorderableList(
            itemCount: sortedSections.length,
            onReorder: (oldIndex, newIndex) {
              ref.read(promptManagerProvider.notifier).reorder(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final section = sortedSections[index];
              // Use a unique key that includes identifier for custom prompts
              final key = section.identifier != null
                  ? ValueKey('${section.identifier}_$index')
                  : ValueKey('${section.type.name}_$index');
              return ReorderableDelayedDragStartListener(
                key: key,
                index: index,
                child: _PromptSectionTile(
                  key: key,
                  section: section,
                  index: index,
                  onToggle: () {
                    // Use index-based toggle for custom prompts
                    if (section.isCustom) {
                      ref.read(promptManagerProvider.notifier).toggleSectionByIndex(index);
                    } else {
                      ref.read(promptManagerProvider.notifier).toggleSection(section.type);
                    }
                  },
                  onEdit: section.isEditable
                      ? () => _openSectionEditor(context, section, index)
                      : null,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: DesignTokens.spaceXl)),
        ],
      ),
    );
  }

  /// 段落编辑:push 子页(Block D 批2;原大表单弹窗)
  void _openSectionEditor(BuildContext context, PromptSection section, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PromptSectionEditScreen(section: section, index: index),
      ),
    );
  }

  void _showPresetsDialog(BuildContext context, WidgetRef ref, List<PromptManagerPreset> presets) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(DesignTokens.spaceMd),
              child: Row(
                children: [
                  const Icon(Icons.list, color: AppTheme.accentColor),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.loadPreset,
                    style: const TextStyle(fontSize: DesignTokens.fontSizeXl, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: presets.length,
                itemBuilder: (context, index) {
                  final preset = presets[index];
                  return ListTile(
                    leading: Icon(
                      preset.isBuiltIn ? Icons.lock : Icons.edit,
                      color: preset.isBuiltIn ? AppTheme.textMuted : AppTheme.accentColor,
                    ),
                    title: Text(preset.name),
                    subtitle: preset.description != null
                        ? Text(preset.description!, maxLines: 1, overflow: TextOverflow.ellipsis)
                        : null,
                    trailing: preset.isBuiltIn
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.delete, size: 20),
                            onPressed: () {
                              ref.read(customPresetsProvider.notifier).deletePreset(preset.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(AppLocalizations.of(context)!.deleted(preset.name))),
                              );
                            },
                          ),
                    onTap: () {
                      ref.read(promptManagerProvider.notifier).applyPreset(preset);
                      ref.read(activePresetIdProvider.notifier).setActivePreset(preset.id);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppLocalizations.of(context)!.applied(preset.name))),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importPreset(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      String jsonString;

      if (file.bytes != null) {
        jsonString = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        jsonString = await File(file.path!).readAsString();
      } else {
        throw Exception('Could not read file');
      }

      final json = jsonDecode(jsonString) as Map<String, dynamic>;

      // Check if it's a valid preset format
      if (json['sections'] != null || json['format'] == 'kirakira_prompt_preset') {
        // Import as preset
        final preset = await ref.read(customPresetsProvider.notifier).importPreset(json);
        ref.read(promptManagerProvider.notifier).applyPreset(preset);
        ref.read(activePresetIdProvider.notifier).setActivePreset(preset.id);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.imported(preset.name))),
          );
        }
      } else {
        throw Exception(AppLocalizations.of(context)!.invalidPresetFormatMessage);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.importPresetFailed(e.toString()))),
        );
      }
    }
  }

  Future<void> _exportPreset(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController(text: 'My Prompt Preset');

    // D-T2 规则 2:单字段输入 → 底部 Sheet(键盘顶起)
    final name = await showModalBottomSheet<String>(
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
                AppLocalizations.of(sheetCtx)!.exportPresetTitle,
                style: const TextStyle(
                  fontSize: DesignTokens.fontSizeHeadline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: nameController,
                autofocus: true,
                placeholder: AppLocalizations.of(sheetCtx)!.presetNameLabel,
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
                  onPressed: () =>
                      Navigator.pop(sheetCtx, nameController.text.trim()),
                  child: Text(AppLocalizations.of(sheetCtx)!.export),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (name == null || name.isEmpty) return;

    try {
      final json = ref.read(promptManagerProvider.notifier).exportToJson(name);
      final jsonString = const JsonEncoder.withIndent('  ').convert(json);

      // Save to temp file and share
      final tempDir = await getTemporaryDirectory();
      final fileName = '${name.replaceAll(RegExp(r'[^\w\s-]'), '_')}.json';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonString);

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'KiraKira Prompt Preset: $name',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.exportPresetFailed(e.toString()))),
        );
      }
    }
  }

  Future<void> _saveAsPreset(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    // D-T2:双字段表单 → 底部 Sheet(isScrollControlled + 键盘避让)
    final result = await showModalBottomSheet<Map<String, String>>(
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
                AppLocalizations.of(sheetCtx)!.saveAsPreset,
                style: const TextStyle(
                  fontSize: DesignTokens.fontSizeHeadline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: nameController,
                autofocus: true,
                placeholder: AppLocalizations.of(sheetCtx)!.presetName,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(sheetCtx).colorScheme.surfaceContainerHighest,
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusGroupedCard),
                ),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: descController,
                placeholder: AppLocalizations.of(sheetCtx)!.descriptionOptional,
                maxLines: 2,
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
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context)!
                              .pleaseEnterNameMessage),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(sheetCtx, {
                      'name': nameController.text.trim(),
                      'description': descController.text.trim(),
                    });
                  },
                  child: Text(AppLocalizations.of(sheetCtx)!.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null) return;

    try {
      final config = ref.read(promptManagerProvider);
      final preset = await ref.read(customPresetsProvider.notifier).saveCurrentAsPreset(
        config,
        result['name']!,
        result['description']!.isEmpty ? null : result['description'],
      );
      ref.read(activePresetIdProvider.notifier).setActivePreset(preset.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.saved(preset.name))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.saveFailedMessage(e.toString()))),
        );
      }
    }
  }

  void _showResetConfirmation(BuildContext context, WidgetRef ref) {
    // D-T2 规则 1:破坏确认 → CupertinoAlertDialog
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: Text(AppLocalizations.of(context)!.resetToDefault),
        content: Text(AppLocalizations.of(context)!.resetToDefaultQuestion),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              ref.read(promptManagerProvider.notifier).resetToDefault();
              ref.read(activePresetIdProvider.notifier).setActivePreset(null);
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.of(context)!.resetToDefaultConfig)),
              );
            },
            child: Text(AppLocalizations.of(context)!.reset),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    // D-T2 规则 3:信息帮助 → 底部 Sheet
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusBottomSheet),
        ),
      ),
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (sheetCtx, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Row(
              children: [
                const Icon(Icons.help_outline, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(sheetCtx)!.promptManagerHelp,
                    style: const TextStyle(
                      fontSize: DesignTokens.fontSizeHeadline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(
                'What is the Prompt Manager?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'The Prompt Manager controls how the system prompt is built when sending messages to the AI. '
                'You can customize the order of different sections and enable/disable them.',
              ),
              SizedBox(height: 16),
              Text(
                'Section Types:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• System Prompt: Base roleplay instructions'),
              Text('• User Persona: Your character information'),
              Text('• Character Description: The AI character\'s details'),
              Text('• Character Personality: Personality traits'),
              Text('• Scenario: Current situation and setting'),
              Text('• World Info: Contextual lore from lorebooks'),
              Text('• Example Messages: Sample dialogue for style'),
              Text('• Author\'s Note: Dynamic instructions'),
              Text('• Post-History: Instructions after chat'),
              SizedBox(height: 16),
              Text(
                'Tips:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Sections at the top have higher priority'),
              Text('• Disable sections you don\'t need to save tokens'),
              Text('• Experiment with order for different results'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(sheetCtx),
                child: Text(AppLocalizations.of(sheetCtx)!.ok),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _PromptSectionTile extends StatelessWidget {
  final PromptSection section;
  final int index;
  final VoidCallback onToggle;
  final VoidCallback? onEdit;

  const _PromptSectionTile({
    super.key,
    required this.section,
    required this.index,
    required this.onToggle,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine display name and description
    final displayName = section.isCustom
        ? section.name
        : PromptSection.getDisplayName(section.type);
    final description = section.isCustom
        ? (section.content?.isNotEmpty == true
            ? '${section.content!.substring(0, section.content!.length.clamp(0, 50))}...'
            : 'Custom prompt')
        : PromptSection.getDescription(section.type);

    // Determine icon based on type
    IconData typeIcon;
    if (section.isCustom) {
      typeIcon = Icons.code;
    } else {
      switch (section.type) {
        case PromptSectionType.systemPrompt:
          typeIcon = Icons.settings_system_daydream;
          break;
        case PromptSectionType.persona:
          typeIcon = Icons.person;
          break;
        case PromptSectionType.characterDescription:
        case PromptSectionType.characterPersonality:
          typeIcon = Icons.face;
          break;
        case PromptSectionType.characterScenario:
          typeIcon = Icons.landscape;
          break;
        case PromptSectionType.exampleMessages:
          typeIcon = Icons.chat_bubble_outline;
          break;
        case PromptSectionType.worldInfo:
        case PromptSectionType.worldInfoAfter:
          typeIcon = Icons.public;
          break;
        case PromptSectionType.authorNote:
          typeIcon = Icons.note;
          break;
        case PromptSectionType.postHistoryInstructions:
          typeIcon = Icons.history;
          break;
        case PromptSectionType.nsfw:
          typeIcon = Icons.warning;
          break;
        case PromptSectionType.chatHistory:
          typeIcon = Icons.forum;
          break;
        case PromptSectionType.enhanceDefinitions:
          typeIcon = Icons.auto_fix_high;
          break;
        default:
          typeIcon = Icons.text_snippet;
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMd, vertical: DesignTokens.spaceXs),
      color: section.enabled
          ? colorScheme.surface
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.drag_handle,
                color: section.enabled ? AppTheme.textSecondary : AppTheme.textMuted,
              ),
              const SizedBox(width: 8),
              Icon(
                typeIcon,
                size: 20,
                color: section.isCustom
                    ? (section.enabled ? AppTheme.accentColor : AppTheme.textMuted)
                    : (section.enabled ? AppTheme.primaryColor : AppTheme.textMuted),
              ),
            ],
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                displayName,
                style: TextStyle(
                  color: section.enabled ? AppTheme.textPrimary : AppTheme.textMuted,
                  fontWeight: section.enabled ? FontWeight.w500 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (section.isCustom)
              Container(
                margin: const EdgeInsets.only(left: DesignTokens.spaceXs),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: DesignTokens.spaceXxs),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
                ),
                child: Text(
                  'Custom',
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeCaption,
                    color: section.enabled ? AppTheme.accentColor : AppTheme.textMuted,
                  ),
                ),
              ),
            if (section.isEditable && !section.isCustom)
              Padding(
                padding: const EdgeInsets.only(left: DesignTokens.spaceXs),
                child: Icon(
                  Icons.edit_note,
                  size: 16,
                  color: section.enabled ? AppTheme.accentColor : AppTheme.textMuted,
                ),
              ),
          ],
        ),
        subtitle: Text(
          description,
          style: TextStyle(
            color: section.enabled ? AppTheme.textSecondary : AppTheme.textMuted,
            fontSize: DesignTokens.fontSizeXs,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onEdit != null)
              IconButton(
                icon: Icon(
                  Icons.edit,
                  size: 20,
                  color: section.enabled ? AppTheme.accentColor : AppTheme.textMuted,
                ),
                onPressed: section.enabled ? onEdit : null,
                tooltip: AppLocalizations.of(context)!.edit,
              ),
            KiraSwitch(
              value: section.enabled,
              onChanged: (_) => onToggle(),
            ),
          ],
        ),
        onTap: onEdit != null && section.enabled ? onEdit : null,
      ),
    );
  }
}