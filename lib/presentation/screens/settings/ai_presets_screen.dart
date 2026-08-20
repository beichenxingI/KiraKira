import 'dart:convert';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../data/models/ai_preset.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../providers/ai_preset_providers.dart';
import '../../providers/prompt_manager_providers.dart';
import '../../theme/app_theme.dart';
import 'ai_preset_edit_screen.dart';
import '../../../data/models/regex_script.dart';
import '../../providers/regex_providers.dart';
import 'package:uuid/uuid.dart';

/// Screen for managing AI presets
class AIPresetsScreen extends ConsumerWidget {
  const AIPresetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final allPresets = ref.watch(allAIPresetsProvider);
    final activePresetId = ref.watch(activeAIPresetIdProvider);

    // Separate built-in and custom presets
    final builtInPresets = allPresets.where((p) => p.isBuiltIn).toList();
    final customPresets = allPresets.where((p) => !p.isBuiltIn).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aiPresets),
        actions: [
          if (activePresetId != null)
            TextButton.icon(
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('取消使用'),
              onPressed: () async {
                await ref.read(activeAIPresetIdProvider.notifier).setActivePreset(null);
                await ref.read(promptManagerProvider.notifier).resetToDefault();
                // 取消使用预设时，同步禁用所有全局正则，避免残留生效。
                await ref
                    .read(globalRegexScriptsProvider.notifier)
                    .setActiveScripts([]);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已取消使用预设，提示词与正则已恢复默认')),
                  );
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.aiPresetsDescription,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _importPreset(context, ref),
                  icon: const Icon(Icons.file_download, size: 20),
                  label: Text(l10n.importPreset),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _exportCurrentSettings(context, ref),
                  icon: const Icon(Icons.file_upload, size: 20),
                  label: Text(l10n.export),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _saveCurrentAsPreset(context, ref),
                  icon: const Icon(Icons.save, size: 20),
                  label: Text(l10n.saveAs),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Built-in presets
          _buildSectionHeader(context, l10n.builtInPresets),
          const SizedBox(height: 12),
          ...builtInPresets.map((preset) => _PresetCard(
                preset: preset,
                isActive: preset.id == activePresetId,
                onTap: () => _applyPreset(context, ref, preset),
              )),

          if (customPresets.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSectionHeader(context, l10n.customPresets),
            const SizedBox(height: 12),
            ...customPresets.map((preset) => _PresetCard(
                  preset: preset,
                  isActive: preset.id == activePresetId,
                  onTap: () => _applyPreset(context, ref, preset),
                  onExport: () => _exportPreset(context, preset),
                  onDelete: () => _deletePreset(context, ref, preset),
                  onEdit: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AIPresetEditScreen(preset: preset),
                    ),
                  ),
                )),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.accentColor,
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Future<void> _applyPreset(BuildContext context, WidgetRef ref, AIPreset preset) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(aiPresetManagerProvider).applyPreset(preset);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.appliedPreset(preset.name))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToApplyPreset(e.toString()))),
        );
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
      if (!json.containsKey('temperature') && !json.containsKey('generationSettings')) {
        throw Exception(l10n.invalidPresetFormat);
      }

      // Get name from filename if not in JSON
      if (json['preset_name'] == null && json['name'] == null) {
        json['preset_name'] = file.name.replaceAll('.json', '');
      }

      // Import using unified format handler
      final preset = await ref.read(aiCustomPresetsProvider.notifier).importPreset(json);
      await ref.read(aiPresetManagerProvider).applyPreset(preset);

      // Import regex scripts if present
      int importedRegexCount = 0;
      final importedRegexIds = <String>[];
      final ext = json['extensions'] as Map<String, dynamic>?;
      debugPrint('🔧 [导入正则] extensions 字段: ${ext == null ? "null" : ext.keys.toList()}');
      // 正则可能在顶层，也可能在 extensions 里
      final regexScriptsRaw = (json['regex_scripts'] as List<dynamic>?) ??
          (ext?['regex_scripts'] as List<dynamic>?) ??
          (ext?['regex'] as List<dynamic>?);
      debugPrint('🔧 [导入正则] regex_scripts 字段: ${regexScriptsRaw == null ? "null（没找到）" : " 找到 ${regexScriptsRaw.length} 条"}');
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
              debugPrint('🔧 [导入正则] 成功: ${script.scriptName}');
            } catch (e) {
              debugPrint('🔧 [导入正则] 失败: $e');
            }
          } else {
            debugPrint('🔧 [导入正则] 跳过非Map条目: ${raw.runtimeType}');
          }
        }
      }
      debugPrint('🔧 [导入正则] 共导入 $importedRegexCount 条');

      // 把导入的正则ID记进预设，删预设时按此清理
      if (importedRegexIds.isNotEmpty) {
        final updatedPreset = preset.copyWith(
          boundRegexScriptIds: importedRegexIds,
        );
        await ref.read(aiCustomPresetsProvider.notifier).updatePreset(updatedPreset);
      }

      if (context.mounted) {
        final msg = importedRegexCount > 0
            ? '已导入预设「${preset.name}」，同时导入了 $importedRegexCount 条正则脚本'
            : l10n.importedAndApplied(preset.name);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.importFailed(e.toString()))),
        );
      }
    }
  }

  Future<void> _exportCurrentSettings(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController(text: 'My AI Preset');

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.exportCurrentSettings),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: l10n.presetName,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: Text(l10n.export),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    try {
      final json = await ref.read(aiPresetManagerProvider).exportCurrentSettings(name);
      final jsonString = const JsonEncoder.withIndent('  ').convert(json);

      final tempDir = await getTemporaryDirectory();
      final fileName = '${name.replaceAll(RegExp(r'[^\w\s-]'), '_')}.json';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonString);

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'KiraKira AI Preset: $name',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportFailed(e.toString()))),
        );
      }
    }
  }

  Future<void> _saveCurrentAsPreset(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController();
    final descController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.saveAsPreset),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: l10n.presetName,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: InputDecoration(
                labelText: l10n.descriptionOptional,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.pleaseEnterAName)),
                );
                return;
              }
              Navigator.pop(context, {
                'name': nameController.text.trim(),
                'description': descController.text.trim(),
              });
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (result == null) return;

    try {
      final preset = await ref.read(aiPresetManagerProvider).createFromCurrentSettings(
            name: result['name']!,
            description: result['description']!.isEmpty ? null : result['description'],
          );
      await ref.read(aiCustomPresetsProvider.notifier).addPreset(preset);
      await ref.read(activeAIPresetIdProvider.notifier).setActivePreset(preset.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.savedPreset(preset.name))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.saveFailed(e.toString()))),
        );
      }
    }
  }

  Future<void> _exportPreset(BuildContext context, AIPreset preset) async {
    try {
      final json = preset.toExportJson();
      final jsonString = const JsonEncoder.withIndent('  ').convert(json);

      final tempDir = await getTemporaryDirectory();
      final fileName = '${preset.name.replaceAll(RegExp(r'[^\w\s-]'), '_')}.json';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonString);

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'KiraKira AI Preset: ${preset.name}',
      );
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportFailed(e.toString()))),
        );
      }
    }
  }

  Future<void> _deletePreset(BuildContext context, WidgetRef ref, AIPreset preset) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deletePreset),
        content: Text(l10n.deletePresetConfirmation(preset.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }

  }
}

class _PresetCard extends StatelessWidget {
  final AIPreset preset;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onExport;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const _PresetCard({
    required this.preset,
    required this.isActive,
    required this.onTap,
    this.onExport,
    this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isActive ? AppTheme.primaryColor.withValues(alpha: 0.15) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        side: isActive
            ? const BorderSide(color: AppTheme.primaryColor, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppTheme.primaryColor
                      : AppTheme.primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                ),
                child: Icon(
                  _getPresetIcon(preset),
                  color: isActive ? Colors.white : AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          preset.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                            ),
                            child: Builder(
                              builder: (context) {
                                final l10n = AppLocalizations.of(context);
                                return Text(
                                  l10n.active,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (preset.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        preset.description!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Settings summary
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (preset.provider != null)
                          _SettingChip(
                            icon: Icons.cloud,
                            label: preset.provider!,
                          ),
                        _SettingChip(
                          icon: Icons.thermostat,
                          label: 'T: ${preset.generationSettings.temperature.toStringAsFixed(1)}',
                        ),
                        _SettingChip(
                          icon: Icons.pie_chart,
                          label: 'P: ${preset.generationSettings.topP.toStringAsFixed(2)}',
                        ),
                        _SettingChip(
                          icon: Icons.format_list_numbered,
                          label: 'K: ${preset.generationSettings.topK}',
                        ),
                        _SettingChip(
                          icon: Icons.token,
                          label: '${preset.generationSettings.maxTokens}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Actions
              if (!preset.isBuiltIn)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'export') onExport?.call();
                    if (value == 'delete') onDelete?.call();
                  },
            itemBuilder: (context) {
                    final l10n = AppLocalizations.of(context);
                    return [
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: const Icon(Icons.edit),
                          title: const Text('编辑绑定'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'export',
                        child: ListTile(
                          leading: const Icon(Icons.file_upload),
                          title: Text(l10n.export),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: const Icon(Icons.delete, color: Colors.red),
                          title: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ];
                  },
                ),
            ],
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

class _SettingChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SettingChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: DesignTokens.fontSizeCaption, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}