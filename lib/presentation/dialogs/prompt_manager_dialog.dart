// lib/presentation/dialogs/prompt_manager_dialog.dart
/// 提示词管理浮窗(极客Core迁移 P4)
/// 内容完整迁自 prompt_manager_screen.dart(911行)+
/// prompt_section_edit_screen.dart(编辑并入为嵌套浮窗):
/// 信息横幅 · 段落排序开关列表(拖拽/开关/编辑)
/// 菜单:载入预设/存为预设/导入/导出/重置/帮助 · 新建提示词
/// 段落编辑浮窗:名称(自定义)/内容/元信息/重置默认(内置)/删除(自定义)
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:kirakira/data/models/prompt_manager.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/providers/prompt_manager_providers.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/utils/export_delivery.dart';
import 'core_dialog.dart';

Future<void> showPromptManagerDialog(BuildContext context, WidgetRef ref) {
  return showCoreDialog(
    context,
    builder: (_) => const _PromptManagerDialog(),
  );
}

class _PromptManagerDialog extends ConsumerWidget {
  const _PromptManagerDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CoreDialogPalette(isDark: isDark);
    final config = ref.watch(promptManagerProvider);
    final sortedSections = config.sortedSections;
    final allPresets = ref.watch(allPresetsProvider);

    return CoreDialogShell(
      title: l10n.promptManager,
      icon: CupertinoIcons.list_bullet,
      maxWidth: 550,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 新建提示词
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            minSize: 0,
            onPressed: () => _showCreatePromptSheet(context, ref),
            child: Icon(CupertinoIcons.add_circled,
                size: 22, color: DesignTokens.primary),
          ),
          // 菜单
          PopupMenuButton<String>(
            icon: Icon(CupertinoIcons.ellipsis_circle,
                size: 22, color: palette.textSecondary),
            color: palette.surface,
            onSelected: (value) {
              switch (value) {
                case 'presets':
                  _showPresetsSheet(context, ref, allPresets);
                case 'import':
                  _importPreset(context, ref);
                case 'export':
                  _exportPreset(context, ref);
                case 'save':
                  _saveAsPreset(context, ref);
                case 'reset':
                  _showResetConfirmation(context, ref);
                case 'help':
                  _showHelpSheet(context, palette);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'presets',
                child: Row(children: [
                  Icon(Icons.list, size: 18, color: palette.textSecondary),
                  const SizedBox(width: 8),
                  Text(l10n.loadPreset),
                ]),
              ),
              PopupMenuItem(
                value: 'save',
                child: Row(children: [
                  Icon(Icons.save, size: 18, color: palette.textSecondary),
                  const SizedBox(width: 8),
                  Text(l10n.saveAsPresetLabel),
                ]),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'import',
                child: Row(children: [
                  Icon(Icons.file_download,
                      size: 18, color: palette.textSecondary),
                  const SizedBox(width: 8),
                  Text(l10n.importPresetLabel),
                ]),
              ),
              PopupMenuItem(
                value: 'export',
                child: Row(children: [
                  Icon(Icons.file_upload,
                      size: 18, color: palette.textSecondary),
                  const SizedBox(width: 8),
                  Text(l10n.exportPreset),
                ]),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'reset',
                child: Row(children: [
                  Icon(Icons.restore, size: 18, color: palette.textSecondary),
                  const SizedBox(width: 8),
                  Text(l10n.resetToDefault),
                ]),
              ),
              PopupMenuItem(
                value: 'help',
                child: Row(children: [
                  Icon(Icons.help_outline,
                      size: 18, color: palette.textSecondary),
                  const SizedBox(width: 8),
                  Text(l10n.help),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 信息横幅 ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DesignTokens.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    color: DesignTokens.primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.dragToReorder,
                    style: TextStyle(
                        fontSize: 12, color: palette.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 段落排序开关列表(拖拽排序) ──
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedSections.length,
            onReorder: (oldIndex, newIndex) {
              ref
                  .read(promptManagerProvider.notifier)
                  .reorder(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final section = sortedSections[index];
              final key = section.identifier != null
                  ? ValueKey('${section.identifier}_$index')
                  : ValueKey('${section.type.name}_$index');
              return _PromptSectionTile(
                key: key,
                section: section,
                index: index,
                palette: palette,
                onToggle: () {
                  if (section.isCustom) {
                    ref
                        .read(promptManagerProvider.notifier)
                        .toggleSectionByIndex(index);
                  } else {
                    ref
                        .read(promptManagerProvider.notifier)
                        .toggleSection(section.type);
                  }
                },
                onEdit: section.isEditable
                    ? () => _showSectionEditDialog(
                        context, ref, section, index, palette)
                    : null,
              );
            },
          ),
        ],
      ),
    );
  }

  // ════════════════════ 菜单操作(与原页逻辑一致) ════════════════════

  /// [新建] 自定义提示词表单(与原页一致:名称/内容/角色/启用)
  void _showCreatePromptSheet(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CoreDialogPalette(isDark: isDark);
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    final contentController = TextEditingController();
    String role = 'system';
    bool enabled = true;

    showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusBottomSheet),
        ),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Padding(
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
                  '新建提示词',
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeHeadline,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                CupertinoTextField(
                  controller: nameController,
                  autofocus: true,
                  placeholder: '提示词名称(必填)',
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.fill,
                    borderRadius:
                        BorderRadius.circular(DesignTokens.radiusGroupedCard),
                  ),
                  style: TextStyle(color: palette.textPrimary),
                ),
                const SizedBox(height: 12),
                CupertinoTextField(
                  controller: contentController,
                  placeholder: '提示词内容(必填,支持 {{user}} {{char}} 等宏)',
                  minLines: 4,
                  maxLines: null,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.fill,
                    borderRadius:
                        BorderRadius.circular(DesignTokens.radiusGroupedCard),
                  ),
                  style: TextStyle(color: palette.textPrimary),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('角色', style: TextStyle(color: palette.textPrimary)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CupertinoSlidingSegmentedControl<String>(
                        groupValue: role,
                        children: const {
                          'system': Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Text('System'),
                          ),
                          'user': Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Text('User'),
                          ),
                          'assistant': Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Text('Assistant'),
                          ),
                        },
                        onValueChanged: (v) =>
                            setSheetState(() => role = v ?? 'system'),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                        child: Text('创建后启用',
                            style:
                                TextStyle(color: palette.textPrimary))),
                    CupertinoSwitch(
                      value: enabled,
                      onChanged: (v) => setSheetState(() => enabled = v),
                      activeTrackColor: DesignTokens.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final name = nameController.text.trim();
                      final content = contentController.text.trim();
                      if (name.isEmpty || content.isEmpty) {
                        coreToast(sheetCtx, '名称和内容不能为空');
                        return;
                      }
                      Navigator.pop(sheetCtx, {
                        'name': name,
                        'content': content,
                        'role': role,
                        'enabled': enabled,
                      });
                    },
                    child: Text(l10n.save),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((result) async {
      if (result == null) return;
      await ref.read(promptManagerProvider.notifier).addCustomSection(
            result['name'] as String,
            result['content'] as String,
            result['role'] as String,
            enabled: result['enabled'] as bool? ?? true,
          );
      if (context.mounted) {
        coreToast(context, '已创建 ${result['name']}');
      }
    });
  }

  void _showPresetsSheet(
      BuildContext context, WidgetRef ref, List<PromptManagerPreset> presets) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CoreDialogPalette(isDark: isDark);
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
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
        builder: (ctx, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.list, color: DesignTokens.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    l10n.loadPreset,
                    style: TextStyle(
                      fontSize: DesignTokens.fontSizeXl,
                      fontWeight: FontWeight.bold,
                      color: palette.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: palette.textSecondary),
                    onPressed: () => Navigator.pop(sheetCtx),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: palette.divider),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: presets.length,
                itemBuilder: (ctx, index) {
                  final preset = presets[index];
                  return ListTile(
                    leading: Icon(
                      preset.isBuiltIn ? Icons.lock : Icons.edit,
                      color: preset.isBuiltIn
                          ? palette.textTertiary
                          : DesignTokens.primary,
                    ),
                    title: Text(preset.name,
                        style:
                            TextStyle(color: palette.textPrimary)),
                    subtitle: preset.description != null
                        ? Text(preset.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: palette.textSecondary))
                        : null,
                    trailing: preset.isBuiltIn
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.delete,
                                size: 20, color: DesignTokens.statusError),
                            onPressed: () {
                              ref
                                  .read(customPresetsProvider.notifier)
                                  .deletePreset(preset.id);
                              coreToast(
                                  ctx, l10n.deleted(preset.name));
                            },
                          ),
                    onTap: () {
                      ref
                          .read(promptManagerProvider.notifier)
                          .applyPreset(preset);
                      ref
                          .read(activePresetIdProvider.notifier)
                          .setActivePreset(preset.id);
                      Navigator.pop(sheetCtx);
                      coreToast(ctx, l10n.applied(preset.name));
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
    final l10n = AppLocalizations.of(context)!;
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
      if (json['sections'] != null ||
          json['format'] == 'kirakira_prompt_preset') {
        // Import as preset
        final preset =
            await ref.read(customPresetsProvider.notifier).importPreset(json);
        ref.read(promptManagerProvider.notifier).applyPreset(preset);
        ref.read(activePresetIdProvider.notifier).setActivePreset(preset.id);

        if (context.mounted) {
          coreToast(context, l10n.imported(preset.name));
        }
      } else {
        throw Exception(l10n.invalidPresetFormatMessage);
      }
    } catch (e) {
      if (context.mounted) {
        coreToast(context, l10n.importPresetFailed(e.toString()));
      }
    }
  }

  Future<void> _exportPreset(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CoreDialogPalette(isDark: isDark);
    final nameController = TextEditingController(text: 'My Prompt Preset');

    final name = await showModalBottomSheet<String>(
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
                l10n.exportPresetTitle,
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeHeadline,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: nameController,
                autofocus: true,
                placeholder: l10n.presetNameLabel,
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
                  onPressed: () =>
                      Navigator.pop(sheetCtx, nameController.text.trim()),
                  child: Text(l10n.export),
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

      // [问题1] 统一导出交付:分享 / 保存到文件
      final fileName =
          '${name.replaceAll(RegExp(r'[^\w\s-]'), '_')}.json';
      await deliverExportFile(
        context: context,
        fileName: fileName,
        bytes: utf8.encode(jsonString),
        subject: 'KiraKira Prompt Preset: $name',
        ext: 'json',
      );
    } catch (e) {
      if (context.mounted) {
        coreToast(context, l10n.exportPresetFailed(e.toString()));
      }
    }
  }

  Future<void> _saveAsPreset(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CoreDialogPalette(isDark: isDark);
    final nameController = TextEditingController();
    final descController = TextEditingController();

    final result = await showModalBottomSheet<Map<String, String>>(
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
                l10n.saveAsPreset,
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeHeadline,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: nameController,
                autofocus: true,
                placeholder: l10n.presetName,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.fill,
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusGroupedCard),
                ),
                style: TextStyle(color: palette.textPrimary),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: descController,
                placeholder: l10n.descriptionOptional,
                maxLines: 2,
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
                    if (nameController.text.trim().isEmpty) {
                      coreToast(sheetCtx, l10n.pleaseEnterNameMessage);
                      return;
                    }
                    Navigator.pop(sheetCtx, {
                      'name': nameController.text.trim(),
                      'description': descController.text.trim(),
                    });
                  },
                  child: Text(l10n.save),
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
      final preset =
          await ref.read(customPresetsProvider.notifier).saveCurrentAsPreset(
                config,
                result['name']!,
                result['description']!.isEmpty ? null : result['description'],
              );
      ref.read(activePresetIdProvider.notifier).setActivePreset(preset.id);

      if (context.mounted) {
        coreToast(context, l10n.saved(preset.name));
      }
    } catch (e) {
      if (context.mounted) {
        coreToast(context, l10n.saveFailedMessage(e.toString()));
      }
    }
  }

  void _showResetConfirmation(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: Text(l10n.resetToDefault),
        content: Text(l10n.resetToDefaultQuestion),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              ref.read(promptManagerProvider.notifier).resetToDefault();
              ref.read(activePresetIdProvider.notifier).setActivePreset(null);
              Navigator.pop(dialogCtx);
              coreToast(context, l10n.resetToDefaultConfig);
            },
            child: Text(l10n.reset),
          ),
        ],
      ),
    );
  }

  void _showHelpSheet(BuildContext context, CoreDialogPalette palette) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
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
                Icon(Icons.help_outline,
                    color: DesignTokens.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.promptManagerHelp,
                    style: TextStyle(
                      fontSize: DesignTokens.fontSizeHeadline,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What is the Prompt Manager?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The Prompt Manager controls how the system prompt is '
                  'built when sending messages to the AI. '
                  'You can customize the order of different sections and '
                  'enable/disable them.',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Section Types:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('• System Prompt: Base roleplay instructions'),
                const Text('• User Persona: Your character information'),
                const Text(
                    '• Character Description: The AI character\'s details'),
                const Text('• Character Personality: Personality traits'),
                const Text('• Scenario: Current situation and setting'),
                const Text(
                    '• World Info: Contextual lore from lorebooks'),
                const Text('• Example Messages: Sample dialogue for style'),
                const Text('• Author\'s Note: Dynamic instructions'),
                const Text('• Post-History: Instructions after chat'),
                const SizedBox(height: 16),
                const Text(
                  'Tips:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('• Sections at the top have higher priority'),
                const Text(
                    '• Disable sections you don\'t need to save tokens'),
                const Text('• Experiment with order for different results'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(sheetCtx),
                child: Text(l10n.ok),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 段落行(原 _PromptSectionTile 浮窗形态,拖拽/开关/编辑全保留)
class _PromptSectionTile extends StatelessWidget {
  const _PromptSectionTile({
    super.key,
    required this.section,
    required this.index,
    required this.palette,
    required this.onToggle,
    this.onEdit,
  });

  final PromptSection section;
  final int index;
  final CoreDialogPalette palette;
  final VoidCallback onToggle;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
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
        case PromptSectionType.persona:
          typeIcon = Icons.person;
        case PromptSectionType.characterDescription:
        case PromptSectionType.characterPersonality:
          typeIcon = Icons.face;
        case PromptSectionType.characterScenario:
          typeIcon = Icons.landscape;
        case PromptSectionType.exampleMessages:
          typeIcon = Icons.chat_bubble_outline;
        case PromptSectionType.worldInfo:
        case PromptSectionType.worldInfoAfter:
          typeIcon = Icons.public;
        case PromptSectionType.authorNote:
          typeIcon = Icons.note;
        case PromptSectionType.postHistoryInstructions:
          typeIcon = Icons.history;
        case PromptSectionType.nsfw:
          typeIcon = Icons.warning;
        case PromptSectionType.chatHistory:
          typeIcon = Icons.forum;
        case PromptSectionType.enhanceDefinitions:
          typeIcon = Icons.auto_fix_high;
        default:
          typeIcon = Icons.text_snippet;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: section.enabled
            ? palette.fill.withValues(alpha: palette.isDark ? 0.55 : 1)
            : palette.fill.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Icon(Icons.drag_handle,
                  size: 18, color: palette.textTertiary),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            typeIcon,
            size: 20,
            color: section.enabled
                ? (section.isCustom
                    ? DesignTokens.primary
                    : palette.textSecondary)
                : palette.textTertiary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: section.enabled
                                ? FontWeight.w500
                                : FontWeight.normal,
                            color: section.enabled
                                ? palette.textPrimary
                                : palette.textSecondary,
                          ),
                        ),
                      ),
                      if (section.isCustom)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: DesignTokens.primary
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Custom',
                            style: TextStyle(
                              fontSize: 10,
                              color: section.enabled
                                  ? DesignTokens.primary
                                  : palette.textSecondary,
                            ),
                          ),
                        ),
                      if (section.isEditable && !section.isCustom)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.edit_note,
                            size: 14,
                            color: section.enabled
                                ? DesignTokens.primary
                                : palette.textTertiary,
                          ),
                        ),
                    ],
                  ),
                  Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11, color: palette.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          if (onEdit != null)
            IconButton(
              icon: Icon(Icons.edit,
                  size: 18,
                  color: section.enabled
                      ? DesignTokens.primary
                      : palette.textTertiary),
              onPressed: section.enabled ? onEdit : null,
              tooltip: AppLocalizations.of(context)!.edit,
            ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: CupertinoSwitch(
              value: section.enabled,
              onChanged: (_) => onToggle(),
              activeTrackColor: DesignTokens.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 段落编辑浮窗(原 PromptSectionEditScreen 浮窗化,字段与逻辑一致)
Future<void> _showSectionEditDialog(
  BuildContext context,
  WidgetRef ref,
  PromptSection section,
  int index,
  CoreDialogPalette palette,
) {
  return showCoreDialog(
    context,
    builder: (_) => _PromptSectionEditDialog(
      section: section,
      index: index,
      palette: palette,
    ),
  );
}

class _PromptSectionEditDialog extends ConsumerStatefulWidget {
  const _PromptSectionEditDialog({
    required this.section,
    required this.index,
    required this.palette,
  });

  final PromptSection section;
  final int index;
  final CoreDialogPalette palette;

  @override
  ConsumerState<_PromptSectionEditDialog> createState() =>
      _PromptSectionEditDialogState();
}

class _PromptSectionEditDialogState
    extends ConsumerState<_PromptSectionEditDialog> {
  late final TextEditingController _contentController;
  late final TextEditingController _nameController;

  PromptSection get _section => widget.section;

  String get _displayName => _section.isCustom
      ? _section.name
      : PromptSection.getDisplayName(_section.type);

  String get _description => _section.isCustom
      ? 'Custom prompt from imported preset'
      : PromptSection.getDescription(_section.type);

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(
      text: _section.content ?? PromptSection.getDefaultContent(_section.type),
    );
    _nameController = TextEditingController(text: _section.name);
  }

  @override
  void dispose() {
    _contentController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final newContent = _contentController.text.trim();
    final newName = _nameController.text.trim();

    if (_section.isCustom) {
      // Update custom prompt with new name and content
      ref.read(promptManagerProvider.notifier).updateSectionByIndex(
            widget.index,
            _section.copyWith(
              name: newName.isNotEmpty ? newName : _section.name,
              content: newContent,
            ),
          );
    } else {
      // Update built-in prompt content
      ref
          .read(promptManagerProvider.notifier)
          .updateSectionContent(_section.type, newContent);
    }
    coreToast(context, 'Updated ${_section.isCustom ? newName : _displayName}');
    Navigator.pop(context);
  }

  /// 仅重置输入框内容(不落库),与原页"重置为默认"按钮行为一致
  void _resetToDefault() {
    setState(() {
      _contentController.text =
          PromptSection.getDefaultContent(_section.type);
    });
  }

  /// [删除] 仅自定义提示词可删。破坏性操作 → CupertinoAlertDialog 确认。
  void _deleteCustomSection() {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('删除提示词'),
        content: Text('确定删除「${_section.name}」吗?此操作无法恢复。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              ref
                  .read(promptManagerProvider.notifier)
                  .deleteCustomSectionByIndex(widget.index);
              Navigator.pop(dialogCtx); // 关确认框
              Navigator.pop(context); // 关编辑浮窗
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;

    return CoreDialogShell(
      title: 'Edit $_displayName',
      icon: CupertinoIcons.pencil,
      maxWidth: 550,
      footer: CoreDialogFooter(
        child: Row(
          children: [
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: palette.fill,
                borderRadius: BorderRadius.circular(10),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  AppLocalizations.of(context)!.cancel,
                  style: TextStyle(fontSize: 15, color: palette.textPrimary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: DesignTokens.primary,
                borderRadius: BorderRadius.circular(10),
                onPressed: _save,
                child: Text(AppLocalizations.of(context)!.save,
                    style: const TextStyle(fontSize: 15, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 自定义段落:名称 ──
          if (_section.isCustom) ...[
            CoreSectionLabel('提示词名称'),
            const SizedBox(height: 8),
            CoreTextField(
              controller: _nameController,
              palette: palette,
              hint: '提示词名称',
            ),
            const SizedBox(height: 16),
          ],

          // ── 内容(大文本域) ──
          CoreSectionLabel('内容'),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _contentController,
            placeholder: '输入提示词内容...',
            minLines: 8,
            maxLines: null,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: palette.fill,
              borderRadius: BorderRadius.circular(8),
            ),
            style: TextStyle(fontSize: 14, color: palette.textPrimary),
          ),

          // ── 元信息 + 宏提示(原页说明文字,逐字保留) ──
          const SizedBox(height: 12),
          Text(
            _description,
            style: TextStyle(fontSize: 12, color: palette.textSecondary),
          ),
          if (_section.identifier != null) ...[
            const SizedBox(height: 4),
            Text(
              'ID: ${_section.identifier}',
              style: TextStyle(
                fontSize: 11,
                color: palette.textTertiary,
                fontFamily: 'monospace',
              ),
            ),
          ],
          if (_section.role != null) ...[
            const SizedBox(height: 4),
            Text(
              'Role: ${_section.role}',
              style: TextStyle(fontSize: 11, color: palette.textTertiary),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Supports macros: {{user}}, {{char}}, {{time}}, {{date}}, etc.',
            style: TextStyle(
              fontSize: 11,
              color: palette.textTertiary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),

          // ── 内置段落:重置为默认 ──
          if (!_section.isCustom)
            CoreSecondaryButton(
              label: '重置为默认',
              icon: CupertinoIcons.arrow_counterclockwise,
              onPressed: _resetToDefault,

            ),

          // ── 自定义段落:删除 ──
          if (_section.isCustom)
            CoreDangerButton(
              label: '删除此提示词',
              onPressed: _deleteCustomSection,
            ),
        ],
      ),
    );
  }
}
