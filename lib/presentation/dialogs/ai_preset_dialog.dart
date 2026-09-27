// lib/presentation/dialogs/ai_preset_dialog.dart
/// AI 预设浮窗(极客Core迁移 P3)
/// 内容完整迁自 ai_presets_screen.dart(757行) + ai_preset_edit_screen.dart:
/// 信息横幅 · 导入/导出当前配置/存为预设 · 内置预设列表 · 自定义预设列表
/// (应用/导出/删除/编辑绑定) · 取消使用
/// 编辑绑定浮窗 = 名称/描述/绑定提示词预设(单选)/绑定全局正则(多选)
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:kirakira/data/models/ai_preset.dart';
import 'package:kirakira/data/models/prompt_manager.dart';
import 'package:kirakira/data/models/regex_script.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/providers/ai_preset_providers.dart';
import 'package:kirakira/presentation/providers/prompt_manager_providers.dart';
import 'package:kirakira/presentation/providers/regex_providers.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/utils/export_delivery.dart';
import 'package:uuid/uuid.dart';
import 'core_dialog.dart';

Future<void> showAIPresetDialog(BuildContext context, WidgetRef ref) {
  return showCoreDialog(
    context,
    builder: (_) => const _AIPresetDialog(),
  );
}

class _AIPresetDialog extends ConsumerWidget {
  const _AIPresetDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CoreDialogPalette(isDark: isDark);
    final allPresets = ref.watch(allAIPresetsProvider);
    final activePresetId = ref.watch(activeAIPresetIdProvider);

    final builtInPresets = allPresets.where((p) => p.isBuiltIn).toList();
    final customPresets = allPresets.where((p) => !p.isBuiltIn).toList();

    return CoreDialogShell(
      title: l10n.aiPresets,
      icon: CupertinoIcons.star,
      maxWidth: 550,
      trailing: activePresetId != null
          ? CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minSize: 0,
              onPressed: () async {
                await ref
                    .read(activeAIPresetIdProvider.notifier)
                    .setActivePreset(null);
                await ref
                    .read(promptManagerProvider.notifier)
                    .resetToDefault();
                // 取消使用预设时，同步禁用所有全局正则，避免残留生效。
                await ref
                    .read(globalRegexScriptsProvider.notifier)
                    .setActiveScripts([]);
                if (context.mounted) {
                  coreToast(context, '已取消使用预设，提示词与正则已恢复默认');
                }
              },
              child: const Text(
                '取消使用',
                style: TextStyle(fontSize: 14, color: DesignTokens.primary),
              ),
            )
          : null,
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
                    l10n.aiPresetsDescription,
                    style: TextStyle(
                        fontSize: 12, color: palette.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 操作按钮 ──
          Row(
            children: [
              Expanded(
                child: _CompactAction(
                  palette: palette,
                  icon: Icons.file_download,
                  label: l10n.importPreset,
                  onTap: () => _importPreset(context, ref),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactAction(
                  palette: palette,
                  icon: Icons.file_upload,
                  label: l10n.export,
                  onTap: () => _exportCurrentSettings(context, ref),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactAction(
                  palette: palette,
                  icon: Icons.save,
                  label: l10n.saveAs,
                  primary: true,
                  onTap: () => _saveCurrentAsPreset(context, ref),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── 内置预设 ──
          CoreSectionLabel(l10n.builtInPresets),
          const SizedBox(height: 8),
          ...builtInPresets.map(
            (p) => _PresetCard(
              preset: p,
              isActive: p.id == activePresetId,
              palette: palette,
              onTap: () => _applyPreset(context, ref, p),
            ),
          ),
          const SizedBox(height: 20),

          // ── 自定义预设 ──
          CoreSectionLabel(l10n.customPresets),
          const SizedBox(height: 8),
          if (customPresets.isEmpty)
            Text(
              '暂无自定义预设',
              style: TextStyle(fontSize: 12, color: palette.textSecondary),
            )
          else
            ...customPresets.map(
              (p) => _PresetCard(
                preset: p,
                isActive: p.id == activePresetId,
                palette: palette,
                onTap: () => _applyPreset(context, ref, p),
                onExport: () => _exportPreset(context, p),
                onDelete: () => _deletePreset(context, ref, p),
                onEdit: () => _showPresetEditDialog(context, ref, p, palette),
              ),
            ),
        ],
      ),
    );
  }

  // ════════════════════ 预设操作(与原页逻辑一致) ════════════════════

  Future<void> _applyPreset(
      BuildContext context, WidgetRef ref, AIPreset preset) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(aiPresetManagerProvider).applyPreset(preset);
      if (context.mounted) {
        coreToast(context, l10n.appliedPreset(preset.name));
      }
    } catch (e) {
      if (context.mounted) {
        coreToast(context, l10n.failedToApplyPreset(e.toString()));
      }
    }
  }

  Future<void> _importPreset(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
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

      // Check if it's a valid preset format (has temperature or generationSettings)
      if (!json.containsKey('temperature') &&
          !json.containsKey('generationSettings')) {
        throw Exception(l10n.invalidPresetFormat);
      }

      // Get name from filename if not in JSON
      if (json['preset_name'] == null && json['name'] == null) {
        json['preset_name'] = file.name.replaceAll('.json', '');
      }

      // Import using unified format handler
      final preset =
          await ref.read(aiCustomPresetsProvider.notifier).importPreset(json);
      await ref.read(aiPresetManagerProvider).applyPreset(preset);

      // Import regex scripts if present
      int importedRegexCount = 0;
      final importedRegexIds = <String>[];
      final ext = json['extensions'] as Map<String, dynamic>?;
      // 正则可能在顶层，也可能在 extensions 里
      final regexScriptsRaw = (json['regex_scripts'] as List<dynamic>?) ??
          (ext?['regex_scripts'] as List<dynamic>?) ??
          (ext?['regex'] as List<dynamic>?);
      if (regexScriptsRaw != null && regexScriptsRaw.isNotEmpty) {
        final regexNotifier = ref.read(globalRegexScriptsProvider.notifier);
        for (final raw in regexScriptsRaw) {
          if (raw is Map<String, dynamic>) {
            try {
              final newId = const Uuid().v4();
              final script = RegexScript.fromSillyTavernJson(
                raw,
                newId: newId,
              );
              await regexNotifier.addScript(script);
              importedRegexIds.add(newId);
              importedRegexCount++;
            } catch (_) {
              // 单条失败跳过,与原页一致
            }
          }
        }
      }

      // 把导入的正则ID记进预设，删预设时按此清理
      if (importedRegexIds.isNotEmpty) {
        final updatedPreset = preset.copyWith(
          boundRegexScriptIds: importedRegexIds,
        );
        await ref
            .read(aiCustomPresetsProvider.notifier)
            .updatePreset(updatedPreset);
      }

      if (context.mounted) {
        final msg = importedRegexCount > 0
            ? '已导入预设「${preset.name}」，同时导入了 $importedRegexCount 条正则脚本'
            : l10n.importedAndApplied(preset.name);
        coreToast(context, msg);
      }
    } catch (e) {
      if (context.mounted) {
        coreToast(context, l10n.importFailed(e.toString()));
      }
    }
  }

  Future<void> _exportCurrentSettings(
      BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController(text: 'My AI Preset');

    final name = await _showNameSheet(
      context,
      title: l10n.exportCurrentSettings,
      hint: l10n.presetName,
      controller: nameController,
      confirmLabel: l10n.export,
    );

    if (name == null || name.isEmpty) return;

    try {
      final json =
          await ref.read(aiPresetManagerProvider).exportCurrentSettings(name);
      final jsonString = const JsonEncoder.withIndent('  ').convert(json);

      final fileName =
          '${name.replaceAll(RegExp(r'[^\w\s-]'), '_')}.json';
      // [问题1] 统一导出交付:分享 / 保存到文件
      await deliverExportFile(
        context: context,
        fileName: fileName,
        bytes: utf8.encode(jsonString),
        subject: 'KiraKira AI Preset: $name',
        ext: 'json',
      );
    } catch (e) {
      if (context.mounted) {
        coreToast(context, l10n.exportFailed(e.toString()));
      }
    }
  }

  Future<void> _saveCurrentAsPreset(
      BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController();
    final descController = TextEditingController();

    final result = await _showNameDescSheet(
      context,
      title: l10n.saveAsPreset,
      nameHint: l10n.presetName,
      descHint: l10n.descriptionOptional,
      nameController: nameController,
      descController: descController,
    );

    if (result == null) return;

    try {
      final preset = await ref
          .read(aiPresetManagerProvider)
          .createFromCurrentSettings(
            name: result['name']!,
            description:
                result['description']!.isEmpty ? null : result['description'],
          );
      await ref.read(aiCustomPresetsProvider.notifier).addPreset(preset);
      await ref
          .read(activeAIPresetIdProvider.notifier)
          .setActivePreset(preset.id);

      if (context.mounted) {
        coreToast(context, l10n.savedPreset(preset.name));
      }
    } catch (e) {
      if (context.mounted) {
        coreToast(context, l10n.saveFailed(e.toString()));
      }
    }
  }

  Future<void> _exportPreset(
      BuildContext context, AIPreset preset) async {
    final l10n = AppLocalizations.of(context);
    try {
      final json = preset.toExportJson();
      final jsonString = const JsonEncoder.withIndent('  ').convert(json);

      final fileName =
          '${preset.name.replaceAll(RegExp(r'[^\w\s-]'), '_')}.json';
      // [问题1] 统一导出交付:分享 / 保存到文件
      await deliverExportFile(
        context: context,
        fileName: fileName,
        bytes: utf8.encode(jsonString),
        subject: 'KiraKira AI Preset: ${preset.name}',
        ext: 'json',
      );
    } catch (e) {
      if (context.mounted) {
        coreToast(context, l10n.exportFailed(e.toString()));
      }
    }
  }

  Future<void> _deletePreset(
      BuildContext context, WidgetRef ref, AIPreset preset) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: Text(l10n.deletePreset),
        content: Text(l10n.deletePresetConfirmation(preset.name)),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final activeId = ref.read(activeAIPresetIdProvider);
    final isActive = activeId == preset.id;

    // 方案B：删除此预设导入的正则脚本
    final boundRegexIds = preset.boundRegexScriptIds;
    int removedRegexCount = 0;
    if (boundRegexIds.isNotEmpty) {
      final regexNotifier = ref.read(globalRegexScriptsProvider.notifier);
      for (final regexId in boundRegexIds) {
        await regexNotifier.removeScript(regexId);
        removedRegexCount++;
      }
    }

    await ref.read(aiCustomPresetsProvider.notifier).deletePreset(preset.id);

    if (isActive) {
      await ref.read(activeAIPresetIdProvider.notifier).setActivePreset(null);
      await ref.read(promptManagerProvider.notifier).resetToDefault();
    }

    if (context.mounted) {
      final msg = removedRegexCount > 0
          ? '已删除预设「${preset.name}」，同时移除了 $removedRegexCount 条正则脚本'
          : l10n.deletedPreset(preset.name);
      coreToast(context, msg);
    }
  }

  /// 单字段输入 → 底部 Sheet(D-T2 规则 2,与原页一致)
  Future<String?> _showNameSheet(
    BuildContext context, {
    required String title,
    required String hint,
    required TextEditingController controller,
    required String confirmLabel,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CoreDialogPalette(isDark: isDark);
    return showModalBottomSheet<String>(
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
                placeholder: hint,
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
                      Navigator.pop(sheetCtx, controller.text.trim()),
                  child: Text(confirmLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 双字段表单 → 底部 Sheet(与原页一致)
  Future<Map<String, String>?> _showNameDescSheet(
    BuildContext context, {
    required String title,
    required String nameHint,
    required String descHint,
    required TextEditingController nameController,
    required TextEditingController descController,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CoreDialogPalette(isDark: isDark);
    final l10n = AppLocalizations.of(context);
    return showModalBottomSheet<Map<String, String>>(
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
                controller: nameController,
                autofocus: true,
                placeholder: nameHint,
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
                placeholder: descHint,
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
                      coreToast(sheetCtx, l10n.pleaseEnterAName);
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
  }
}

/// 紧凑操作按钮(导入/导出/存为三连)
class _CompactAction extends StatelessWidget {
  const _CompactAction({
    required this.palette,
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final CoreDialogPalette palette;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: primary ? DesignTokens.primary : palette.fill,
      borderRadius: BorderRadius.circular(10),
      minSize: 0,
      onPressed: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 16, color: primary ? Colors.white : DesignTokens.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: primary ? Colors.white : palette.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 预设卡(原 _PresetCard 浮窗形态,信息与操作全保留)
class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.isActive,
    required this.palette,
    required this.onTap,
    this.onExport,
    this.onDelete,
    this.onEdit,
  });

  final AIPreset preset;
  final bool isActive;
  final CoreDialogPalette palette;
  final VoidCallback onTap;
  final VoidCallback? onExport;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isActive
            ? DesignTokens.primary.withValues(alpha: 0.12)
            : palette.fill.withValues(alpha: palette.isDark ? 0.55 : 1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? DesignTokens.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isActive
                        ? DesignTokens.primary
                        : DesignTokens.primary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getPresetIcon(preset),
                    size: 20,
                    color: isActive ? Colors.white : DesignTokens.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              preset.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: palette.textPrimary,
                              ),
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: DesignTokens.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                AppLocalizations.of(context).active,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (preset.description != null &&
                          preset.description!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          preset.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: palette.textSecondary),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _SettingChip(
                              icon: Icons.thermostat,
                              label:
                                  'T: ${preset.generationSettings.temperature.toStringAsFixed(1)}',
                              palette: palette),
                          _SettingChip(
                              icon: Icons.pie_chart,
                              label:
                                  'P: ${preset.generationSettings.topP.toStringAsFixed(2)}',
                              palette: palette),
                          _SettingChip(
                              icon: Icons.format_list_numbered,
                              label: 'K: ${preset.generationSettings.topK}',
                              palette: palette),
                          _SettingChip(
                              icon: Icons.token,
                              label: '${preset.generationSettings.maxTokens}',
                              palette: palette),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!preset.isBuiltIn)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert,
                        size: 20, color: palette.textSecondary),
                    color: palette.surface,
                    onSelected: (value) {
                      if (value == 'edit') onEdit?.call();
                      if (value == 'export') onExport?.call();
                      if (value == 'delete') onDelete?.call();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit,
                                size: 18, color: palette.textSecondary),
                            const SizedBox(width: 8),
                            const Text('编辑绑定'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'export',
                        child: Row(
                          children: [
                            Icon(Icons.file_upload,
                                size: 18, color: palette.textSecondary),
                            const SizedBox(width: 8),
                            Text(AppLocalizations.of(context).export),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete,
                                size: 18, color: DesignTokens.statusError),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalizations.of(context).delete,
                              style: const TextStyle(
                                  color: DesignTokens.statusError),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getPresetIcon(AIPreset preset) {
    switch (preset.id) {
      case 'default':
        return Icons.tune;
      case 'creative':
        return Icons.auto_awesome;
      case 'precise':
        return Icons.precision_manufacturing;
      case 'deterministic':
        return Icons.lock;
      case 'longform':
        return Icons.article;
      case 'mirostat':
        return Icons.auto_graph;
      default:
        return Icons.settings;
    }
  }
}

/// 设置摘要 Chip
class _SettingChip extends StatelessWidget {
  const _SettingChip({
    required this.icon,
    required this.label,
    required this.palette,
  });

  final IconData icon;
  final String label;
  final CoreDialogPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: palette.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: palette.textSecondary),
        ),
      ],
    );
  }
}

/// 预设编辑绑定浮窗(原 AIPresetEditScreen 浮窗化,字段与逻辑一致)
Future<void> _showPresetEditDialog(
  BuildContext context,
  WidgetRef ref,
  AIPreset preset,
  CoreDialogPalette palette,
) {
  return showCoreDialog(
    context,
    builder: (_) => _AIPresetEditDialog(preset: preset, palette: palette),
  );
}

class _AIPresetEditDialog extends ConsumerStatefulWidget {
  const _AIPresetEditDialog({required this.preset, required this.palette});

  final AIPreset preset;
  final CoreDialogPalette palette;

  @override
  ConsumerState<_AIPresetEditDialog> createState() =>
      _AIPresetEditDialogState();
}

class _AIPresetEditDialogState extends ConsumerState<_AIPresetEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  String? _selectedPromptPresetId;
  late Set<String> _selectedRegexIds;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.preset.name);
    _descController =
        TextEditingController(text: widget.preset.description ?? '');
    _selectedPromptPresetId = widget.preset.boundPromptPresetId;
    _selectedRegexIds = Set.from(widget.preset.boundRegexScriptIds);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      coreToast(context, '预设名称不能为空');
      return;
    }
    final updated = widget.preset.copyWith(
      name: _nameController.text.trim(),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      boundPromptPresetId: _selectedPromptPresetId,
      boundRegexScriptIds: _selectedRegexIds.toList(),
      updatedAt: DateTime.now(),
    );
    await ref.read(aiCustomPresetsProvider.notifier).updatePreset(updated);
    if (mounted) Navigator.pop(context);
  }

  /// 单选绑定 → CupertinoActionSheet(与原页一致)
  Future<void> _pickPromptPreset(List<PromptManagerPreset> presets) async {
    final selected = await showCupertinoModalPopup<String>(
      context: context,
      builder: (sheetCtx) => CupertinoActionSheet(
        title: const Text('绑定提示词预设'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetCtx, ''),
            child: const Text('不绑定（使用全局激活的提示词预设）'),
          ),
          ...presets.map(
            (p) => CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(sheetCtx, p.id),
              child: Text(
                p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetCtx),
          child: const Text('取消'),
        ),
      ),
    );
    if (selected == null) return; // 取消
    setState(
      () => _selectedPromptPresetId = selected.isEmpty ? null : selected,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final allPromptPresets = ref.watch(allPresetsProvider);
    final allRegexScripts = ref.watch(globalRegexScriptsProvider);

    final boundPreset = _selectedPromptPresetId == null
        ? null
        : allPromptPresets
            .where((p) => p.id == _selectedPromptPresetId)
            .firstOrNull;

    return CoreDialogShell(
      title: '编辑预设',
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
                  '取消',
                  style:
                      TextStyle(fontSize: 15, color: palette.textPrimary),
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
                child: const Text('保存',
                    style: TextStyle(fontSize: 15, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 基本信息 ──
          CoreSectionLabel('基本信息'),
          const SizedBox(height: 8),
          CoreTextField(
            controller: _nameController,
            palette: palette,
            hint: '预设名称',
          ),
          const SizedBox(height: 8),
          CoreTextField(
            controller: _descController,
            palette: palette,
            hint: '描述（可选）',
            maxLines: 2,
          ),
          const SizedBox(height: 20),

          // ── 绑定提示词预设 ──
          CoreSectionLabel('绑定提示词预设'),
          const SizedBox(height: 4),
          CoreTile(
            title: '提示词预设',
            subtitle:
                boundPreset?.name ?? '不绑定（使用全局激活的提示词预设）',
            onTap: () => _pickPromptPreset(allPromptPresets),
          ),
          const SizedBox(height: 4),
          Text(
            '切换此AI预设时，自动切换到绑定的提示词预设',
            style: TextStyle(fontSize: 12, color: palette.textSecondary),
          ),
          const SizedBox(height: 20),

          // ── 绑定全局正则脚本 ──
          CoreSectionLabel(
            _selectedRegexIds.isEmpty
                ? '绑定全局正则脚本'
                : '绑定全局正则脚本（已选 ${_selectedRegexIds.length} 个）',
          ),
          const SizedBox(height: 4),
          if (allRegexScripts.isEmpty)
            Text(
              '暂无全局正则脚本',
              style: TextStyle(fontSize: 12, color: palette.textSecondary),
            )
          else
            ...allRegexScripts.map((script) {
              final selected = _selectedRegexIds.contains(script.id);
              return _RegexBindTile(
                palette: palette,
                script: script,
                selected: selected,
                onTap: () {
                  setState(() {
                    if (selected) {
                      _selectedRegexIds.remove(script.id);
                    } else {
                      _selectedRegexIds.add(script.id);
                    }
                  });
                },
              );
            }),
          const SizedBox(height: 4),
          Text(
            '切换此AI预设时，仅启用选中的正则脚本，其余自动禁用',
            style: TextStyle(fontSize: 12, color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// 正则绑定行
class _RegexBindTile extends StatelessWidget {
  const _RegexBindTile({
    required this.palette,
    required this.script,
    required this.selected,
    required this.onTap,
  });

  final CoreDialogPalette palette;
  final RegexScript script;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      script.scriptName,
                      style:
                          TextStyle(fontSize: 14, color: palette.textPrimary),
                    ),
                    if (script.description != null &&
                        script.description!.isNotEmpty)
                      Text(
                        script.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: palette.textSecondary),
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: script.disabled
                      ? palette.fill
                      : DesignTokens.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  script.disabled ? '已禁用' : '启用',
                  style: TextStyle(
                    fontSize: 10,
                    color: script.disabled
                        ? palette.textSecondary
                        : DesignTokens.primary,
                  ),
                ),
              ),
              if (selected)
                const Icon(CupertinoIcons.checkmark,
                    size: 18, color: DesignTokens.primary)
              else
                const SizedBox(width: 18),
            ],
          ),
        ),
      ),
    );
  }
}
