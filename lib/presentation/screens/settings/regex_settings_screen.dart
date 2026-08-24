import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/widgets/common/common.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:kirakira/data/models/regex_script.dart';
import 'package:kirakira/domain/services/regex_service.dart';
import 'package:kirakira/presentation/providers/regex_providers.dart';
import 'package:kirakira/presentation/theme/app_theme.dart';
import 'package:kirakira/presentation/widgets/regex/regex_widgets.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'regex_script_edit_screen.dart';

/// Screen for managing regex scripts
class RegexSettingsScreen extends ConsumerWidget {
  const RegexSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(regexSettingsProvider);
    final scripts = ref.watch(globalRegexScriptsProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(
              AppLocalizations.of(context)!.regexScripts,
              style: Theme.of(context).textTheme.displayLarge,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: AppLocalizations.of(context)!.addScript,
                onPressed: () => _showScriptEditor(context, ref, null),
              ),
              PopupMenuButton<String>(
                icon: const Icon(CupertinoIcons.ellipsis_circle),
                onSelected: (value) => _handleMenuAction(context, ref, value),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'add_presets',
                    child: ListTile(
                      leading: const Icon(Icons.auto_awesome),
                      title: Text(AppLocalizations.of(context)!.addPresets),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'import',
                    child: ListTile(
                      leading: const Icon(Icons.file_download),
                      title: Text(AppLocalizations.of(context)!.import),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'export',
                    child: ListTile(
                      leading: const Icon(Icons.file_upload),
                      title: Text(AppLocalizations.of(context)!.export),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'clear_all',
                    child: ListTile(
                      leading: const Icon(Icons.delete_sweep,
                          color: DesignTokens.statusError),
                      title: Text(AppLocalizations.of(context)!.clearAll,
                          style:
                              const TextStyle(color: DesignTokens.statusError)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SliverList(
            delegate: SliverChildListDelegate([
          // Enable/Disable toggle
          _buildSection(
            context: context,
            title: AppLocalizations.of(context)!.general,
            children: [
              KiraSwitchTile(
                  title: AppLocalizations.of(context)!.enableRegexScripts,
                  subtitle: AppLocalizations.of(context)!.applyFindReplacePatterns,
                  value: settings.enabled,
                onChanged: (value) {
                  ref.read(regexSettingsProvider.notifier).setEnabled(value);
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Application settings
          _buildSection(
            context: context,
            title: AppLocalizations.of(context)!.applyTo,
            children: [
              KiraSwitchTile(
                  title: AppLocalizations.of(context)!.userInput,
                  subtitle: AppLocalizations.of(context)!.applyBeforeSending,
                  value: settings.applyToUserInput,
                onChanged: settings.enabled
                    ? (value) {
                        ref.read(regexSettingsProvider.notifier).setApplyToUserInput(value);
                      }
                    : null,
              ),
              KiraSwitchTile(
                  title: AppLocalizations.of(context)!.aiOutput,
                  subtitle: AppLocalizations.of(context)!.applyToAiResponses,
                  value: settings.applyToAiOutput,
                onChanged: settings.enabled
                    ? (value) {
                        ref.read(regexSettingsProvider.notifier).setApplyToAiOutput(value);
                      }
                    : null,
              ),
              KiraSwitchTile(
                  title: AppLocalizations.of(context)!.slashCommandsLabel,
                  subtitle: AppLocalizations.of(context)!.applyDuringCommandProcessing,
                  value: settings.applyToSlashCommands,
                onChanged: settings.enabled
                    ? (value) {
                        ref.read(regexSettingsProvider.notifier).setApplyToSlashCommands(value);
                      }
                    : null,
              ),
              KiraSwitchTile(
                  title: AppLocalizations.of(context)!.worldInfoLabel,
                  subtitle: AppLocalizations.of(context)!.applyToWorldInfoEntries,
                  value: settings.applyToWorldInfo,
                onChanged: settings.enabled
                    ? (value) {
                        ref.read(regexSettingsProvider.notifier).setApplyToWorldInfo(value);
                      }
                    : null,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Scripts list
          _buildSection(
            context: context,
            title: AppLocalizations.of(context)!.scriptsCount(scripts.length),
            children: [
              if (scripts.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(DesignTokens.spaceXl),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.find_replace, size: 48, color: AppTheme.textMuted),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context)!.noRegexScripts,
                          style: const TextStyle(color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)!.tapToAddOrUseMenu,
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: DesignTokens.fontSizeXs),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: scripts.length,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex--;
                    ref.read(globalRegexScriptsProvider.notifier).reorderScripts(oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final script = scripts[index];
                    return RegexScriptTile(
                      key: ValueKey(script.id),
                      script: script,
                      onTap: () => _showScriptEditor(context, ref, script),
                      onToggle: () {
                        ref.read(globalRegexScriptsProvider.notifier).toggleScript(script.id);
                      },
                      onDelete: () => _confirmDelete(context, ref, script),
                    );
                  },
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Test section
          _buildSection(
            context: context,
            title: AppLocalizations.of(context)!.test,
            children: [
              const _RegexTestWidget(),
            ],
          ),

          const SizedBox(height: 16),

          // Info section
          _buildSection(
            context: context,
            title: '信息',
            children: [
              const ListTile(
                leading: Icon(Icons.info_outline, color: AppTheme.accentColor),
                title: Text('关于正则脚本'),
                subtitle: Text(
                  'Regex scripts allow you to find and replace text patterns in messages. '
                  'Use capture groups (\$1, \$2) in replacements.',
                ),
              ),
              const ListTile(
                leading: Icon(Icons.code, color: AppTheme.textMuted),
                title: Text('模式格式'),
                subtitle: Text(
                  'Use /pattern/flags format (e.g., /hello/gi) or plain patterns. '
                  'Flags: i=case-insensitive, m=multiline, s=dotall',
                ),
              ),
            ],
          ),
        ]),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required List<Widget> children,
  }) {
    // D-T0:inset-grouped 一组一张卡
    return KiraSection(title: title, children: children);
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'add_presets':
        ref.read(globalRegexScriptsProvider.notifier).addPresets();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.presetScriptsAdded)),
        );
        break;
      case 'import':
        _showImportDialog(context, ref);
        break;
      case 'export':
        _showExportDialog(context, ref);
        break;
      case 'clear_all':
        _confirmClearAll(context, ref);
        break;
    }
  }

  /// D-T2 规则 3:多字段脚本编辑 → push 子页(内部自足写库)
  void _showScriptEditor(BuildContext context, WidgetRef ref, RegexScript? script) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegexScriptEditScreen(script: script),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, RegexScript script) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteScript),
        content: Text(AppLocalizations.of(context)!.deleteScriptQuestion(script.scriptName)),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              ref.read(globalRegexScriptsProvider.notifier).removeScript(script.id);
              Navigator.pop(dialogCtx);
            },
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll(BuildContext context, WidgetRef ref) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: Text(AppLocalizations.of(context)!.clearAllScripts),
        content: Text(AppLocalizations.of(context)!.clearAllScriptsQuestion),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              ref.read(globalRegexScriptsProvider.notifier).clearAll();
              Navigator.pop(dialogCtx);
            },
            child: Text(AppLocalizations.of(context)!.clearAll),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonContent = await file.readAsString();
        
        final count = await ref.read(globalRegexScriptsProvider.notifier).importScripts(jsonContent);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.importedCount(count))),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  void _showExportDialog(BuildContext context, WidgetRef ref) {
    final json = ref.read(globalRegexScriptsProvider.notifier).exportScripts();

    // D-T2:信息展示类 → 底部 Sheet(圆角 14,内容可滚)
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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.exportScripts,
                  style: const TextStyle(
                    fontSize: DesignTokens.fontSizeHeadline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 380),
                    padding: const EdgeInsets.all(DesignTokens.spaceSm),
                    decoration: BoxDecoration(
                      color: Theme.of(sheetCtx).scaffoldBackgroundColor,
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusSm),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        json,
                        style: const TextStyle(
                            fontSize: DesignTokens.fontSizeXs,
                            fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        child: Text(AppLocalizations.of(context)!.close),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: json));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(AppLocalizations.of(context)!
                                    .copiedToClipboard)),
                          );
                          Navigator.pop(sheetCtx);
                        },
                        icon: const Icon(Icons.copy),
                        label: Text(AppLocalizations.of(context)!.copy),
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
}

/// Widget for testing regex patterns
class _RegexTestWidget extends ConsumerStatefulWidget {
  const _RegexTestWidget();

  @override
  ConsumerState<_RegexTestWidget> createState() => _RegexTestWidgetState();
}

class _RegexTestWidgetState extends ConsumerState<_RegexTestWidget> {
  final _patternController = TextEditingController();
  final _testController = TextEditingController();
  final _replaceController = TextEditingController();
  RegexTestResult? _result;

  @override
  void dispose() {
    _patternController.dispose();
    _testController.dispose();
    _replaceController.dispose();
    super.dispose();
  }

  void _test() {
    final service = ref.read(regexServiceProvider);
    setState(() {
      _result = service.testRegex(
        _patternController.text,
        _testController.text,
        _replaceController.text,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DesignTokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _patternController,
            decoration: const InputDecoration(
              labelText: '模式',
              hintText: '/pattern/flags',
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _testController,
            decoration: const InputDecoration(
              labelText: '测试字符串',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _replaceController,
            decoration: const InputDecoration(
              labelText: '替换',
              hintText: r'$1, $2, {{match}}',
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _test,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Test'),
          ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _result!.success
                    ? AppTheme.accentColor.withValues(alpha: 0.1)
                    : DesignTokens.statusError.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                border: Border.all(
                  color: _result!.success ? AppTheme.accentColor : DesignTokens.statusError,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _result!.success ? Icons.check : Icons.error,
                        size: 16,
                        color: _result!.success ? AppTheme.accentColor : DesignTokens.statusError,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _result!.success
                            ? '${_result!.matches.length} match(es)'
                            : 'Error',
                        style: TextStyle(
                          color: _result!.success ? AppTheme.accentColor : DesignTokens.statusError,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (_result!.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _result!.error!,
                      style: const TextStyle(color: DesignTokens.statusError),
                    ),
                  ],
                  if (_result!.success) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Result:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(DesignTokens.spaceSm),
                      decoration: BoxDecoration(
                        color: AppTheme.darkBackground,
                        borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
                      ),
                      child: SelectableText(
                        _result!.result,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}