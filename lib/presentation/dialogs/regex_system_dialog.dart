// lib/presentation/dialogs/regex_system_dialog.dart
/// Regex system dialog.
/// Merged from regex_settings_screen.dart (570 lines) + regex_script_edit_screen.dart (448 lines)
/// into a single 800px-wide split editor:
/// Left (260px): master switch, search (200ms debounce), filter chips, script list
///   (lazy build + drag reorder), new/import/export/preset/clear.
/// Right (adaptive): unselected = empty state + global apply-to settings; selected = full edit form
///   (script name/enabled/apply-to multi-select/find regex/replace content/strip-strings chips/
///    markdownOnly·promptOnly·runOnEdit/macro substitution mode/depth limit/live test preview/cancel/save).
/// Reuses globalRegexScriptsProvider as data source; import/export unchanged.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:kirakira/data/models/regex_script.dart';
import 'package:kirakira/domain/services/regex_service.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/providers/regex_providers.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'core_dialog.dart';

Future<void> showRegexSystemDialog(BuildContext context, WidgetRef ref) {
  return showCoreDialog(
    context,
    builder: (_) => const _RegexSystemDialog(),
  );
}

enum _RegexFilter { all, enabled, disabled }

class _RegexSystemDialog extends ConsumerStatefulWidget {
  const _RegexSystemDialog();

  @override
  ConsumerState<_RegexSystemDialog> createState() =>
      _RegexSystemDialogState();
}

class _RegexSystemDialogState extends ConsumerState<_RegexSystemDialog> {
  // Left list state
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  String _search = '';
  _RegexFilter _filter = _RegexFilter.all;

  // Right editor state
  String? _selectedId;
  RegexScript? _editingBase; // script being edited (null = new, unsaved)
  bool _editingEnabled = true; // enabled state from the edit form (written back on save)
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _findController;
  late TextEditingController _replaceController;
  late TextEditingController _minDepthController;
  late TextEditingController _maxDepthController;
  late TextEditingController _trimInputController;
  late List<RegexPlacement> _placement;
  late List<String> _trimStrings;
  late bool _markdownOnly;
  late bool _promptOnly;
  late bool _runOnEdit;
  late SubstituteRegex _substituteRegex;
  late TextEditingController _testInputController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _findController = TextEditingController();
    _replaceController = TextEditingController();
    _minDepthController = TextEditingController();
    _maxDepthController = TextEditingController();
    _trimInputController = TextEditingController();
    _testInputController = TextEditingController();
    _resetFormFields();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _findController.dispose();
    _replaceController.dispose();
    _minDepthController.dispose();
    _maxDepthController.dispose();
    _trimInputController.dispose();
    _testInputController.dispose();
    super.dispose();
  }

  void _resetFormFields() {
    _placement = [RegexPlacement.aiOutput];
    _trimStrings = [];
    _markdownOnly = false;
    _promptOnly = false;
    _runOnEdit = false;
    _substituteRegex = SubstituteRegex.none;
    _editingEnabled = true;
  }

  /// Selected script (null = blank new script)
  void _select(RegexScript? script) {
    setState(() {
      _selectedId = script?.id;
      _editingBase = script;
      if (script != null) {
        _nameController.text = script.scriptName;
        _descriptionController.text = script.description ?? '';
        _findController.text = script.findRegex;
        _replaceController.text = script.replaceString;
        _minDepthController.text =
            script.minDepth != null && script.minDepth! >= 0
                ? script.minDepth.toString()
                : '';
        _maxDepthController.text =
            script.maxDepth != null && script.maxDepth! >= 0
                ? script.maxDepth.toString()
                : '';
        _placement = List<RegexPlacement>.from(script.placement);
        _trimStrings = List<String>.from(script.trimStrings);
        _markdownOnly = script.markdownOnly ?? false;
        _promptOnly = script.promptOnly ?? false;
        _runOnEdit = script.runOnEdit ?? false;
        _substituteRegex = script.substituteRegex ?? SubstituteRegex.none;
        _editingEnabled = !script.disabled;
      } else {
        _nameController.clear();
        _descriptionController.clear();
        _findController.clear();
        _replaceController.clear();
        _minDepthController.clear();
        _maxDepthController.clear();
        _resetFormFields();
      }
      _testInputController.clear();
    });
  }

  void _onSearchChanged(String q) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      setState(() => _search = q.trim().toLowerCase());
    });
  }

  List<RegexScript> _filteredScripts(List<RegexScript> scripts) {
    var result = scripts;
    if (_search.isNotEmpty) {
      result = result
          .where((s) =>
              s.scriptName.toLowerCase().contains(_search) ||
              (s.description ?? '').toLowerCase().contains(_search) ||
              s.findRegex.toLowerCase().contains(_search))
          .toList();
    }
    switch (_filter) {
      case _RegexFilter.enabled:
        result = result.where((s) => !s.disabled).toList();
      case _RegexFilter.disabled:
        result = result.where((s) => s.disabled).toList();
      case _RegexFilter.all:
        break;
    }
    return result;
  }

  void _addTrimString() {
    final value = _trimInputController.text.trim();
    if (value.isEmpty || _trimStrings.contains(value)) return;
    setState(() {
      _trimStrings.add(value);
      _trimInputController.clear();
    });
  }

  void _save() {
    if (_nameController.text.isEmpty || _findController.text.isEmpty) {
      coreToast(context, '名称和模式为必填');
      return;
    }

    final minDepth = _minDepthController.text.isNotEmpty
        ? int.tryParse(_minDepthController.text)
        : null;
    final maxDepth = _maxDepthController.text.isNotEmpty
        ? int.tryParse(_maxDepthController.text)
        : null;

    final script = createRegexScript(
      scriptName: _nameController.text,
      description:
          _descriptionController.text.isEmpty ? null : _descriptionController.text,
      findRegex: _findController.text,
      replaceString: _replaceController.text,
      placement: _placement,
      trimStrings: _trimStrings,
      markdownOnly: _markdownOnly,
      promptOnly: _promptOnly,
      runOnEdit: _runOnEdit,
      substituteRegex: _substituteRegex,
      minDepth: minDepth,
      maxDepth: maxDepth,
    );

    final notifier = ref.read(globalRegexScriptsProvider.notifier);
    final base = _editingBase;
    if (base != null) {
      notifier.updateScript(script.copyWith(
        id: base.id,
        order: base.order,
        createdAt: base.createdAt,
      ));
    } else {
      notifier.addScript(script);
    }
    // Write back the enabled state from the edit form (same source as the list toggle, effective immediately)
    if (script.disabled != !_editingEnabled) {
      notifier.toggleScript(script.id);
    }
    setState(() => _selectedId = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CoreDialogPalette(isDark: isDark);
    final settings = ref.watch(regexSettingsProvider);
    final scripts = ref.watch(globalRegexScriptsProvider);
    final filtered = _filteredScripts(scripts);

    return CoreDialogShell(
      title: l10n.regexScripts,
      icon: CupertinoIcons.wand_stars,
      maxWidth: 800,
      horizontalMargin: 16,
      disableScroll: true,
      bodyPadding: EdgeInsets.zero,
      trailing: PopupMenuButton<String>(
        icon: Icon(CupertinoIcons.ellipsis_circle,
            size: 22, color: palette.textSecondary),
        color: palette.surface,
        onSelected: (value) => _handleMenuAction(context, ref, value),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'add_presets',
            child: Row(children: [
              Icon(Icons.auto_awesome,
                  size: 18, color: palette.textSecondary),
              const SizedBox(width: 8),
              Text(l10n.addPresets),
            ]),
          ),
          PopupMenuItem(
            value: 'clear_all',
            child: Row(children: [
              const Icon(Icons.delete_sweep,
                  size: 18, color: DesignTokens.statusError),
              const SizedBox(width: 8),
              Text(l10n.clearAll,
                  style: const TextStyle(color: DesignTokens.statusError)),
            ]),
          ),
        ],
      ),
      body: OrientationBuilder(
        builder: (context, orientation) {
          return orientation == Orientation.landscape
              ? _buildLandscape(context, ref, palette, l10n, settings, scripts, filtered)
              : _buildPortrait(context, ref, palette, l10n, settings, scripts, filtered);
        },
      ),
    );
  }

  // Responsive layout: landscape = side-by-side panes, portrait = stacked sections.
  // Both layouts are functionally identical and share the sub-builders below;
  // only the arrangement direction differs.

  /// Master switch row (enable regex scripts)
  Widget _buildMasterToggle(
      CoreDialogPalette palette, AppLocalizations l10n, WidgetRef ref, RegexSettings settings) {
    return _LeftRow(
      palette: palette,
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.enableRegexScripts,
              style: TextStyle(fontSize: 14, color: palette.textPrimary),
            ),
          ),
          CupertinoSwitch(
            value: settings.enabled,
            onChanged: (v) =>
                ref.read(regexSettingsProvider.notifier).setEnabled(v),
            activeTrackColor: DesignTokens.primary,
          ),
        ],
      ),
    );
  }

  /// Search box (200ms debounce)
  Widget _buildSearchField(CoreDialogPalette palette, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: SizedBox(
        height: 36,
        child: CupertinoTextField(
          controller: _searchCtrl,
          placeholder: l10n.search,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          prefix: Icon(CupertinoIcons.search,
              size: 16, color: palette.textTertiary),
          decoration: BoxDecoration(
            color: palette.fill,
            borderRadius: BorderRadius.circular(8),
          ),
          style: TextStyle(fontSize: 14, color: palette.textPrimary),
          onChanged: _onSearchChanged,
        ),
      ),
    );
  }

  /// Filter chips (all/enabled/disabled)
  Widget _buildFilterChips(CoreDialogPalette palette, List<RegexScript> scripts) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _FilterChip(
            palette: palette,
            label: '全部 ${scripts.length}',
            selected: _filter == _RegexFilter.all,
            onTap: () => setState(() => _filter = _RegexFilter.all),
          ),
          const SizedBox(width: 6),
          _FilterChip(
            palette: palette,
            label: '已启用',
            selected: _filter == _RegexFilter.enabled,
            onTap: () => setState(() => _filter = _RegexFilter.enabled),
          ),
          const SizedBox(width: 6),
          _FilterChip(
            palette: palette,
            label: '已禁用',
            selected: _filter == _RegexFilter.disabled,
            onTap: () => setState(() => _filter = _RegexFilter.disabled),
          ),
        ],
      ),
    );
  }

  /// Script list (lazy build + drag reorder, adaptive empty state)
  Widget _buildScriptList(BuildContext context, WidgetRef ref,
      CoreDialogPalette palette, AppLocalizations l10n, List<RegexScript> filtered) {
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.find_replace,
                  size: 36, color: palette.textTertiary),
              const SizedBox(height: 8),
              Text(
                l10n.noRegexScripts,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: palette.textSecondary),
              ),
            ],
          ),
        ),
      );
    }
    return ReorderableListView.builder(
      itemCount: filtered.length,
      onReorder: (oldIndex, newIndex) {
        // When filtered, map the reordered visible sequence back to full indexes
        if (newIndex > oldIndex) newIndex--;
        final allScripts = ref.read(globalRegexScriptsProvider);
        final visible = _filteredScripts(allScripts);
        if (oldIndex >= visible.length) return;
        final realOld = allScripts.indexOf(visible[oldIndex]);
        final realNew = newIndex >= visible.length
            ? allScripts.length - 1
            : allScripts.indexOf(visible[newIndex]);
        ref
            .read(globalRegexScriptsProvider.notifier)
            .reorderScripts(realOld, realNew);
      },
      itemBuilder: (context, index) {
        final script = filtered[index];
        final selected = script.id == _selectedId;
        return _ScriptListTile(
          key: ValueKey(script.id),
          script: script,
          selected: selected,
          palette: palette,
          index: index,
          onTap: () => _select(script),
          onToggle: () {
            ref
                .read(globalRegexScriptsProvider.notifier)
                .toggleScript(script.id);
          },
          onDelete: () => _confirmDelete(context, ref, script),
        );
      },
    );
  }

  /// Bottom bar: new / import / export
  Widget _buildBottomActions(
      BuildContext context, WidgetRef ref, CoreDialogPalette palette, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: DesignTokens.primary,
              borderRadius: BorderRadius.circular(8),
              minSize: 0,
              onPressed: () => _select(null),
              child: const Text('+ 新建',
                  style: TextStyle(fontSize: 13, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: palette.fill,
              borderRadius: BorderRadius.circular(8),
              minSize: 0,
              onPressed: () => _showImportDialog(context, ref),
              child: Text(l10n.import,
                  style:
                      TextStyle(fontSize: 13, color: palette.textPrimary)),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: palette.fill,
              borderRadius: BorderRadius.circular(8),
              minSize: 0,
              onPressed: () => _showExportSheet(context, ref),
              child: Text(l10n.export,
                  style:
                      TextStyle(fontSize: 13, color: palette.textPrimary)),
            ),
          ),
        ],
      ),
    );
  }

  /// Editor area (empty-state hint / full edit form)
  Widget _buildEditArea(BuildContext context, WidgetRef ref, CoreDialogPalette palette) {
    return _selectedId == null && _editingBase == null
        ? _buildEmptyPane(context, ref, palette)
        : _buildEditPane(context, ref, palette);
  }

  /// Landscape: side-by-side split (left 260px list pane + right editor pane)
  Widget _buildLandscape(
    BuildContext context,
    WidgetRef ref,
    CoreDialogPalette palette,
    AppLocalizations l10n,
    RegexSettings settings,
    List<RegexScript> scripts,
    List<RegexScript> filtered,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left: list pane (fixed 260px)
        SizedBox(
          width: 260,
          child: Column(
            children: [
              _buildMasterToggle(palette, l10n, ref, settings),
              Divider(height: 0.5, thickness: 0.5, color: palette.divider),
              _buildSearchField(palette, l10n),
              _buildFilterChips(palette, scripts),
              Expanded(
                child: _buildScriptList(context, ref, palette, l10n, filtered),
              ),
              Divider(height: 0.5, thickness: 0.5, color: palette.divider),
              _buildBottomActions(context, ref, palette, l10n),
            ],
          ),
        ),
        // Divider
        VerticalDivider(width: 0.5, thickness: 0.5, color: palette.divider),
        // Right: editor pane (adaptive, scrollable)
        Expanded(child: _buildEditArea(context, ref, palette)),
      ],
    );
  }

  /// Portrait: stacked sections (top toolbar + list + editor area + bottom buttons)
  /// List height auto-collapses when a script is selected (AnimatedContainer 250ms)
  Widget _buildPortrait(
    BuildContext context,
    WidgetRef ref,
    CoreDialogPalette palette,
    AppLocalizations l10n,
    RegexSettings settings,
    List<RegexScript> scripts,
    List<RegexScript> filtered,
  ) {
    final hasSelection = _selectedId != null || _editingBase != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top: master switch + search + filter (fixed)
        _buildMasterToggle(palette, l10n, ref, settings),
        _buildSearchField(palette, l10n),
        _buildFilterChips(palette, scripts),
        Divider(height: 0.5, thickness: 0.5, color: palette.divider),
        // Script list (fixed height, collapses when selected, scrollable)
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          height: hasSelection ? 180 : 240,
          child: _buildScriptList(context, ref, palette, l10n, filtered),
        ),
        Divider(height: 0.5, thickness: 0.5, color: palette.divider),
        // Editor area (fills remaining space, scrollable)
        Expanded(child: _buildEditArea(context, ref, palette)),
        Divider(height: 0.5, thickness: 0.5, color: palette.divider),
        // Bottom: new / import / export
        _buildBottomActions(context, ref, palette, l10n),
      ],
    );
  }

  /// Right-side empty state: hint + global apply-to settings (the settings screen's global switch is fully preserved)
  Widget _buildEmptyPane(
      BuildContext context, WidgetRef ref, CoreDialogPalette palette) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(regexSettingsProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(CupertinoIcons.wand_stars,
                      size: 40, color: palette.textTertiary),
                  const SizedBox(height: 8),
                  Text(
                    '从左侧选择脚本编辑，或点「+ 新建」',
                    style: TextStyle(
                        fontSize: 13, color: palette.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          CoreSectionLabel(l10n.applyTo),
          const SizedBox(height: 4),
          _Group(
            palette: palette,
            children: [
              CoreSwitchRow(
                title: l10n.userInput,
                subtitle: l10n.applyBeforeSending,
                value: settings.applyToUserInput,
                palette: palette,
                onChanged: settings.enabled
                    ? (v) => ref
                        .read(regexSettingsProvider.notifier)
                        .setApplyToUserInput(v)
                    : null,
              ),
              CoreSwitchRow(
                title: l10n.aiOutput,
                subtitle: l10n.applyToAiResponses,
                value: settings.applyToAiOutput,
                palette: palette,
                onChanged: settings.enabled
                    ? (v) => ref
                        .read(regexSettingsProvider.notifier)
                        .setApplyToAiOutput(v)
                    : null,
              ),
              CoreSwitchRow(
                title: l10n.slashCommandsLabel,
                subtitle: l10n.applyDuringCommandProcessing,
                value: settings.applyToSlashCommands,
                palette: palette,
                onChanged: settings.enabled
                    ? (v) => ref
                        .read(regexSettingsProvider.notifier)
                        .setApplyToSlashCommands(v)
                    : null,
              ),
              CoreSwitchRow(
                title: l10n.worldInfoLabel,
                subtitle: l10n.applyToWorldInfoEntries,
                value: settings.applyToWorldInfo,
                palette: palette,
                onChanged: settings.enabled
                    ? (v) => ref
                        .read(regexSettingsProvider.notifier)
                        .setApplyToWorldInfo(v)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          CoreInfoRow(
            icon: CupertinoIcons.info,
            title: '关于正则脚本',
            text: 'Regex scripts allow you to find and replace text patterns '
                'in messages. Use capture groups (\$1, \$2) in replacements.',
            palette: palette,
          ),
          CoreInfoRow(
            icon: Icons.code,
            title: '模式格式',
            text: 'Use /pattern/flags format (e.g., /hello/gi) or plain '
                'patterns. Flags: i=case-insensitive, m=multiline, s=dotall',
            palette: palette,
          ),
        ],
      ),
    );
  }

  /// Right-side edit form (fields match regex_script_edit_screen)
  Widget _buildEditPane(
      BuildContext context, WidgetRef ref, CoreDialogPalette palette) {
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Script name (required) + enabled toggle
          const CoreSectionLabel('脚本名（必填）'),
          const SizedBox(height: 6),
          CoreTextField(
            controller: _nameController,
            palette: palette,
            hint: '脚本名称',
          ),
          const SizedBox(height: 8),
          CoreTextField(
            controller: _descriptionController,
            palette: palette,
            hint: '描述（可选）',
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          CoreSwitchRow(
            title: '启用此脚本',
            value: _editingEnabled,
            palette: palette,
            onChanged: (v) => setState(() => _editingEnabled = v),
          ),
          const SizedBox(height: 12),

          // Apply to (multi-select chips)
          const CoreSectionLabel('应用范围 Apply To'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PlacementChip(
                palette: palette,
                label: '用户消息',
                selected: _placement.contains(RegexPlacement.userInput),
                onTap: () => setState(() => _placement
                    .contains(RegexPlacement.userInput)
                    ? _placement.remove(RegexPlacement.userInput)
                    : _placement.add(RegexPlacement.userInput)),
              ),
              _PlacementChip(
                palette: palette,
                label: '角色消息',
                selected: _placement.contains(RegexPlacement.aiOutput),
                onTap: () => setState(() => _placement
                        .contains(RegexPlacement.aiOutput)
                    ? _placement.remove(RegexPlacement.aiOutput)
                    : _placement.add(RegexPlacement.aiOutput)),
              ),
              _PlacementChip(
                palette: palette,
                label: '斜杠命令',
                selected: _placement.contains(RegexPlacement.slashCommand),
                onTap: () => setState(() => _placement
                        .contains(RegexPlacement.slashCommand)
                    ? _placement.remove(RegexPlacement.slashCommand)
                    : _placement.add(RegexPlacement.slashCommand)),
              ),
              _PlacementChip(
                palette: palette,
                label: '世界书',
                selected: _placement.contains(RegexPlacement.worldInfo),
                onTap: () => setState(() => _placement
                        .contains(RegexPlacement.worldInfo)
                    ? _placement.remove(RegexPlacement.worldInfo)
                    : _placement.add(RegexPlacement.worldInfo)),
              ),
              _PlacementChip(
                palette: palette,
                label: '推理块',
                selected: _placement.contains(RegexPlacement.reasoning),
                onTap: () => setState(() => _placement
                        .contains(RegexPlacement.reasoning)
                    ? _placement.remove(RegexPlacement.reasoning)
                    : _placement.add(RegexPlacement.reasoning)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Find regex (single line, code font)
          const CoreSectionLabel('查找模式 Find Regex'),
          const SizedBox(height: 6),
          CupertinoTextField(
            controller: _findController,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: palette.fill,
              borderRadius: BorderRadius.circular(8),
            ),
            style: TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                color: palette.textPrimary),
            placeholder: '/hello/gi 或 hello',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 4),
          Text(
            '正则示例：/hello/gi  纯文本示例：hello',
            style: TextStyle(fontSize: 11, color: palette.textSecondary),
          ),
          const SizedBox(height: 12),

          // Replace with (multiline)
          const CoreSectionLabel('替换为 Replace With'),
          const SizedBox(height: 6),
          CupertinoTextField(
            controller: _replaceController,
            maxLines: 3,
            minLines: 1,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: palette.fill,
              borderRadius: BorderRadius.circular(8),
            ),
            style: TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                color: palette.textPrimary),
            suffix: CupertinoButton(
              padding: const EdgeInsets.all(4),
              minSize: 0,
              onPressed: () {
                _replaceController.clear();
                setState(() {});
              },
              child: Icon(CupertinoIcons.clear_circled_solid,
                  size: 18, color: palette.textTertiary),
            ),
            suffixMode: OverlayVisibilityMode.always,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 4),
          Text(
            r'使用 $1 $2 引用捕获组，留空则删除匹配内容',
            style: TextStyle(fontSize: 11, color: palette.textSecondary),
          ),
          const SizedBox(height: 16),

          // Option toggles
          const CoreSectionLabel('选项 Options'),
          const SizedBox(height: 4),
          _Group(
            palette: palette,
            children: [
              CoreSwitchRow(
                title: '仅 Markdown',
                subtitle: '仅在 Markdown 渲染时应用',
                value: _markdownOnly,
                palette: palette,
                onChanged: (v) => setState(() => _markdownOnly = v),
              ),
              CoreSwitchRow(
                title: '仅提示词',
                subtitle: '仅在提示词生成时应用',
                value: _promptOnly,
                palette: palette,
                onChanged: (v) => setState(() => _promptOnly = v),
              ),
              CoreSwitchRow(
                title: '编辑时运行',
                subtitle: '编辑消息时也应用此脚本',
                value: _runOnEdit,
                palette: palette,
                onChanged: (v) => setState(() => _runOnEdit = v),
              ),
              CoreTile(
                title: '宏替换模式 Substitute Regex',
                subtitle: 'none = 不替换  raw = 原始宏  escaped = 转义宏',
                trailing: Text(
                  _substituteRegex.name.toUpperCase(),
                  style: TextStyle(
                      fontSize: 14, color: palette.textSecondary),
                ),
                onTap: _pickSubstituteRegex,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Advanced: depth limit + strip strings
          const CoreSectionLabel('高级 Advanced'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: CoreTextField(
                  controller: _minDepthController,
                  palette: palette,
                  hint: '最小深度 Min',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CoreTextField(
                  controller: _maxDepthController,
                  palette: palette,
                  hint: '最大深度 Max',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '限制脚本只对最近 N 条消息生效。0 = 最新消息，留空 = 不限制。',
            style: TextStyle(fontSize: 11, color: palette.textSecondary),
          ),
          const SizedBox(height: 12),

          // Strip strings (chip input)
          if (_trimStrings.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _trimStrings.map((s) {
                return Chip(
                  label: Text(
                    s,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 11),
                  ),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => setState(() => _trimStrings.remove(s)),
                  backgroundColor: palette.fill,
                );
              }).toList(),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: CupertinoTextField(
                    controller: _trimInputController,
                    placeholder: '添加修剪字符串',
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: palette.fill,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        color: palette.textPrimary),
                    onSubmitted: (_) => _addTrimString(),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.add_circled_solid,
                    color: DesignTokens.primary, size: 22),
                onPressed: _addTrimString,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '在替换后从结果中删除这些字符串。输入后按 + 添加',
            style: TextStyle(fontSize: 11, color: palette.textSecondary),
          ),
          const SizedBox(height: 16),

          // Test area (input -> live preview of the replacement result)
          CoreSectionLabel(l10n.test),
          const SizedBox(height: 6),
          CupertinoTextField(
            controller: _testInputController,
            maxLines: 3,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: palette.fill,
              borderRadius: BorderRadius.circular(8),
            ),
            style: TextStyle(fontSize: 14, color: palette.textPrimary),
            placeholder: '输入测试字符串…',
            onChanged: (_) => setState(() {}),
          ),
          if (_testInputController.text.isNotEmpty ||
              _findController.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            _TestPreview(
              palette: palette,
              result: ref.read(regexServiceProvider).testRegex(
                    _findController.text,
                    _testInputController.text,
                    _replaceController.text,
                  ),
            ),
          ],
          const SizedBox(height: 16),

          // Bottom: cancel / save
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: palette.fill,
                  borderRadius: BorderRadius.circular(10),
                  onPressed: () => setState(() {
                    _selectedId = null;
                    _editingBase = null;
                  }),
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
                      style:
                          TextStyle(fontSize: 15, color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Macro substitution mode -> CupertinoActionSheet (matches original screen)
  Future<void> _pickSubstituteRegex() async {
    final selected = await showCupertinoModalPopup<SubstituteRegex>(
      context: context,
      builder: (sheetCtx) => CupertinoActionSheet(
        title: const Text('宏替换模式 Substitute Regex'),
        actions: SubstituteRegex.values.map((s) {
          return CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetCtx, s),
            child: Text(s.name.toUpperCase()),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetCtx),
          child: Text(AppLocalizations.of(context).cancel),
        ),
      ),
    );
    if (selected != null) setState(() => _substituteRegex = selected);
  }

  void _handleMenuAction(
      BuildContext context, WidgetRef ref, String action) {
    final l10n = AppLocalizations.of(context);
    switch (action) {
      case 'add_presets':
        ref.read(globalRegexScriptsProvider.notifier).addPresets();
        coreToast(context, l10n.presetScriptsAdded);
      case 'clear_all':
        _confirmClearAll(context, ref);
    }
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, RegexScript script) {
    final l10n = AppLocalizations.of(context);
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: Text(l10n.deleteScript),
        content: Text(l10n.deleteScriptQuestion(script.scriptName)),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              ref
                  .read(globalRegexScriptsProvider.notifier)
                  .removeScript(script.id);
              if (_selectedId == script.id) {
                setState(() {
                  _selectedId = null;
                  _editingBase = null;
                });
              }
              Navigator.pop(dialogCtx);
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: Text(l10n.clearAllScripts),
        content: Text(l10n.clearAllScriptsQuestion),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              ref.read(globalRegexScriptsProvider.notifier).clearAll();
              setState(() {
                _selectedId = null;
                _editingBase = null;
              });
              Navigator.pop(dialogCtx);
            },
            child: Text(l10n.clearAll),
          ),
        ],
      ),
    );
  }

  Future<void> _showImportDialog(
      BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonContent = await file.readAsString();

        final count = await ref
            .read(globalRegexScriptsProvider.notifier)
            .importScripts(jsonContent);

        if (context.mounted) {
          coreToast(context, l10n.importedCount(count));
        }
      }
    } catch (e) {
      if (context.mounted) {
        coreToast(context, 'Import failed: $e');
      }
    }
  }

  void _showExportSheet(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CoreDialogPalette(isDark: isDark);
    final json = ref.read(globalRegexScriptsProvider.notifier).exportScripts();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
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
                l10n.exportScripts,
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeHeadline,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 380),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: palette.fill,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      json,
                      style: const TextStyle(
                          fontSize: 11, fontFamily: 'monospace'),
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
                      child: Text(l10n.close),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: json));
                        coreToast(sheetCtx, l10n.copiedToClipboard);
                        Navigator.pop(sheetCtx);
                      },
                      icon: const Icon(Icons.copy),
                      label: Text(l10n.copy),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Left panel row container
class _LeftRow extends StatelessWidget {
  const _LeftRow({required this.palette, required this.child});

  final CoreDialogPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: child,
    );
  }
}

/// Filter chip
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final CoreDialogPalette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? DesignTokens.primary.withValues(alpha: 0.15)
              : palette.fill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? DesignTokens.primary : palette.outline,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color:
                selected ? DesignTokens.primary : palette.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Script list row (name + enabled toggle + selection highlight + delete)
class _ScriptListTile extends StatelessWidget {
  const _ScriptListTile({
    super.key,
    required this.script,
    required this.selected,
    required this.palette,
    required this.index,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  final RegexScript script;
  final bool selected;
  final CoreDialogPalette palette;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: selected
            ? DesignTokens.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? DesignTokens.primary : Colors.transparent,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Icon(Icons.drag_handle,
                      size: 16, color: palette.textTertiary),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    script.scriptName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: script.disabled
                          ? palette.textSecondary
                          : palette.textPrimary,
                    ),
                  ),
                ),
                SizedBox(
                  width: 34,
                  height: 24,
                  child: CupertinoSwitch(
                    value: !script.disabled,
                    onChanged: (_) => onToggle(),
                    activeTrackColor: DesignTokens.primary,
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.all(2),
                  minSize: 0,
                  onPressed: onDelete,
                  child: Icon(CupertinoIcons.trash,
                      size: 14, color: palette.textTertiary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Apply-to multi-select chip
class _PlacementChip extends StatelessWidget {
  const _PlacementChip({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final CoreDialogPalette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? DesignTokens.primary.withValues(alpha: 0.15)
              : palette.fill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? DesignTokens.primary : palette.outline,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color:
                selected ? DesignTokens.primary : palette.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Live test preview (input -> replacement result)
class _TestPreview extends StatelessWidget {
  const _TestPreview({required this.palette, required this.result});

  final CoreDialogPalette palette;
  final RegexTestResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: result.success
            ? DesignTokens.primary.withValues(alpha: 0.08)
            : DesignTokens.statusError.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: result.success
              ? DesignTokens.primary
              : DesignTokens.statusError,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.success ? Icons.check : Icons.error,
                size: 16,
                color: result.success
                    ? DesignTokens.primary
                    : DesignTokens.statusError,
              ),
              const SizedBox(width: 8),
              Text(
                result.success
                    ? '${result.matches.length} 处匹配'
                    : '模式错误',
                style: TextStyle(
                  color: result.success
                      ? DesignTokens.primary
                      : DesignTokens.statusError,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (result.error != null) ...[
            const SizedBox(height: 6),
            Text(
              result.error!,
              style: const TextStyle(
                  fontSize: 12, color: DesignTokens.statusError),
            ),
          ],
          if (result.success) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: palette.isDark
                    ? const Color(0xFF0D0D0D)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(
                result.result,
                style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: palette.textPrimary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Group container for dialogs
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
