// lib/presentation/dialogs/logit_bias_dialog.dart
/// Logit bias dialog.
/// Enable toggle · preset select/new/rename/duplicate/export/import/delete ·
/// bias entries (reorder/enable toggle/text or token/bias value/format
/// indicator/validation warnings) · help.
library;

import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/models/logit_bias.dart';
import 'package:kirakira/domain/services/logit_bias_service.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/providers/logit_bias_providers.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'core_dialog.dart';

Future<void> showLogitBiasDialog(BuildContext context, WidgetRef ref) {
  return showCoreDialog(
    context,
    builder: (_) => const _LogitBiasDialog(),
  );
}

class _LogitBiasDialog extends ConsumerStatefulWidget {
  const _LogitBiasDialog();

  @override
  ConsumerState<_LogitBiasDialog> createState() => _LogitBiasDialogState();
}

class _LogitBiasDialogState extends ConsumerState<_LogitBiasDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(logitBiasSettingsProvider.notifier)
          .createDefaultPresetIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CoreDialogPalette(isDark: isDark);
    final settings = ref.watch(logitBiasSettingsProvider);
    final service = ref.watch(logitBiasServiceProvider);

    return CoreDialogShell(
      title: l10n.logitBias,
      icon: CupertinoIcons.line_horizontal_3_decrease,
      maxWidth: 600,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minSize: 0,
            onPressed: () => _showHelpSheet(context, service, palette),
            child: Icon(CupertinoIcons.question_circle,
                size: 20, color: palette.textSecondary),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enable
          _Group(
            palette: palette,
            children: [
              CoreSwitchRow(
                title: l10n.enableLogitBias,
                subtitle: l10n.adjustTokenProbabilities,
                value: settings.enabled,
                palette: palette,
                onChanged: (v) =>
                    ref.read(logitBiasSettingsProvider.notifier).setEnabled(v),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Presets
          CoreSectionLabel(l10n.presets),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: palette.fill,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String?>(
                    value: settings.activePresetId,
                    underline: const SizedBox.shrink(),
                    borderRadius: BorderRadius.circular(8),
                    dropdownColor: palette.surface,
                    iconEnabledColor: palette.textSecondary,
                    isExpanded: true,
                    hint: Text(
                      settings.activePresetId == null
                          ? l10n.activePresetLabel
                          : '',
                      style: TextStyle(
                          fontSize: 13, color: palette.textSecondary),
                    ),
                    onChanged: (id) => ref
                        .read(logitBiasSettingsProvider.notifier)
                        .setActivePreset(id),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(l10n.none,
                            style: TextStyle(
                                fontSize: 14, color: palette.textPrimary)),
                      ),
                      ...settings.presets.map((preset) => DropdownMenuItem(
                            value: preset.id,
                            child: Text(
                              preset.name,
                              style: TextStyle(
                                  fontSize: 14, color: palette.textPrimary),
                            ),
                          )),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _IconAction(
                icon: CupertinoIcons.add_circled,
                palette: palette,
                tooltip: l10n.newPreset,
                onTap: () => _showPresetNameDialog(
                  context,
                  mode: _PresetEditMode.create,
                  palette: palette,
                ),
              ),
              _IconAction(
                icon: CupertinoIcons.pencil,
                palette: palette,
                tooltip: l10n.rename,
                onTap: settings.activePreset == null
                    ? null
                    : () => _showPresetNameDialog(
                        context,
                        mode: _PresetEditMode.rename,
                        preset: settings.activePreset,
                        palette: palette,
                      ),
              ),
              _IconAction(
                icon: CupertinoIcons.doc_on_doc,
                palette: palette,
                tooltip: l10n.duplicate,
                onTap: settings.activePresetId == null
                    ? null
                    : () => ref
                        .read(logitBiasSettingsProvider.notifier)
                        .duplicatePreset(settings.activePresetId!),
              ),
              _IconAction(
                icon: CupertinoIcons.tray_arrow_up,
                palette: palette,
                tooltip: l10n.export,
                onTap: settings.activePresetId == null
                    ? null
                    : () => _exportPreset(
                        context, settings.activePresetId!, l10n),
              ),
              _IconAction(
                icon: CupertinoIcons.tray_arrow_down,
                palette: palette,
                tooltip: l10n.importPresetLabel,
                onTap: () => _showPresetNameDialog(
                  context,
                  mode: _PresetEditMode.importJson,
                  palette: palette,
                ),
              ),
              _IconAction(
                icon: CupertinoIcons.trash,
                palette: palette,
                iconColor: DesignTokens.statusError,
                tooltip: l10n.delete,
                onTap: settings.activePresetId == null
                    ? null
                    : () => _confirmDeletePreset(
                        context, settings.activePresetId!, l10n),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Bias entries
          if (settings.activePreset != null) ...[
            const SizedBox(height: 16),
            CoreSectionLabel(l10n.biasEntries),
            const SizedBox(height: 8),
            _BiasEntriesList(
              entries: settings.activePreset!.entries,
              onAddEntry: () {
                final entry = LogitBiasEntry.create();
                ref.read(logitBiasSettingsProvider.notifier).addEntry(entry);
              },
              onUpdateEntry: (entry) {
                ref.read(logitBiasSettingsProvider.notifier).updateEntry(entry);
              },
              onDeleteEntry: (id) {
                ref.read(logitBiasSettingsProvider.notifier).deleteEntry(id);
              },
              onToggleEntry: (id) {
                ref.read(logitBiasSettingsProvider.notifier).toggleEntry(id);
              },
              onReorder: (oldIndex, newIndex) {
                ref
                    .read(logitBiasSettingsProvider.notifier)
                    .reorderEntries(oldIndex, newIndex);
              },
            ),
          ],
        ],
      ),
    );
  }

  void _exportPreset(
      BuildContext context, String presetId, AppLocalizations l10n) {
    try {
      final json =
          ref.read(logitBiasSettingsProvider.notifier).exportPreset(presetId);
      final jsonString = const JsonEncoder.withIndent('  ').convert(json);
      Clipboard.setData(ClipboardData(text: jsonString));
      coreToast(context, l10n.presetCopiedToClipboard);
    } catch (e) {
      coreToast(context, l10n.exportPresetFailed(e.toString()));
    }
  }

  void _confirmDeletePreset(
      BuildContext context, String presetId, AppLocalizations l10n) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: Text(l10n.deletePreset),
        content: Text(l10n.deletePresetQuestion),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              ref
                  .read(logitBiasSettingsProvider.notifier)
                  .deletePreset(presetId);
              Navigator.pop(dialogCtx);
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  /// Help in a bottom sheet.
  void _showHelpSheet(
    BuildContext context,
    LogitBiasService service,
    CoreDialogPalette palette,
  ) {
    final l10n = AppLocalizations.of(context);
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
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollCtrl) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.logitBiasHelp,
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeHeadline,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              Divider(height: 0.5, color: palette.divider),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    service.getHelpText(),
                    style: TextStyle(color: palette.textPrimary),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetCtx),
                    child: Text(l10n.close),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Preset name/JSON input dialog (create/rename/import JSON modes combined).
  void _showPresetNameDialog(
    BuildContext context, {
    required _PresetEditMode mode,
    required CoreDialogPalette palette,
    LogitBiasPreset? preset,
  }) {
    final l10n = AppLocalizations.of(context);
    final isJson = mode == _PresetEditMode.importJson;
    final controller = TextEditingController(text: preset?.name ?? '');

    final title = switch (mode) {
      _PresetEditMode.create => l10n.newPreset,
      _PresetEditMode.rename => l10n.editPreset,
      _PresetEditMode.importJson => l10n.importPresetLabel,
    };

    showCoreDialog(
      context,
      builder: (dialogCtx) => CoreDialogShell(
        title: title,
        maxWidth: 400,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoreSectionLabel(isJson ? l10n.json : l10n.presetName),
            const SizedBox(height: 8),
            CoreTextField(
              controller: controller,
              palette: palette,
              hint: isJson ? l10n.pastePresetJson : l10n.enterPresetName,
              autofocus: true,
              maxLines: isJson ? 8 : 1,
              minLines: isJson ? 8 : 1,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    color: palette.fill,
                    borderRadius: BorderRadius.circular(10),
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: Text(
                      l10n.cancel,
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
                    onPressed: () {
                      switch (mode) {
                        case _PresetEditMode.create:
                          final name = controller.text.trim();
                          if (name.isEmpty) return;
                          final newPreset = LogitBiasPreset.create(name: name);
                          ref
                              .read(logitBiasSettingsProvider.notifier)
                              .addPreset(newPreset);
                          ref
                              .read(logitBiasSettingsProvider.notifier)
                              .setActivePreset(newPreset.id);
                          Navigator.pop(dialogCtx);
                        case _PresetEditMode.rename:
                          final name = controller.text.trim();
                          if (name.isEmpty || preset == null) return;
                          ref
                              .read(logitBiasSettingsProvider.notifier)
                              .updatePreset(preset.copyWith(name: name));
                          Navigator.pop(dialogCtx);
                        case _PresetEditMode.importJson:
                          try {
                            final json = jsonDecode(controller.text)
                                as Map<String, dynamic>;
                            ref
                                .read(logitBiasSettingsProvider.notifier)
                                .importPreset(json);
                            Navigator.pop(dialogCtx);
                            coreToast(
                                dialogCtx, l10n.presetImportedSuccessfully);
                          } catch (e) {
                            coreToast(
                                dialogCtx, l10n.importPresetFailed(e.toString()));
                          }
                      }
                    },
                    child: Text(
                      isJson ? l10n.import : l10n.save,
                      style: const TextStyle(fontSize: 15, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _PresetEditMode { create, rename, importJson }

/// Icon action button.
class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.palette,
    required this.tooltip,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final CoreDialogPalette palette;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.all(6),
      minSize: 0,
      onPressed: onTap,
      child: Icon(
        icon,
        size: 20,
        color: onTap == null
            ? palette.textTertiary
            : (iconColor ?? palette.textSecondary),
      ),
    );
  }
}

/// Bias entry list (drag reorder + add/edit/delete).
class _BiasEntriesList extends StatelessWidget {
  const _BiasEntriesList({
    required this.entries,
    required this.onAddEntry,
    required this.onUpdateEntry,
    required this.onDeleteEntry,
    required this.onToggleEntry,
    required this.onReorder,
  });

  final List<LogitBiasEntry> entries;
  final VoidCallback onAddEntry;
  final ValueChanged<LogitBiasEntry> onUpdateEntry;
  final ValueChanged<String> onDeleteEntry;
  final ValueChanged<String> onToggleEntry;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CoreDialogPalette(isDark: isDark);

    if (entries.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: palette.fill.withValues(alpha: isDark ? 0.55 : 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(Icons.tune, size: 40, color: palette.textTertiary),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).noBiasEntries,
              style: TextStyle(fontSize: 14, color: palette.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context).addEntriesToAdjust,
              style: TextStyle(fontSize: 12, color: palette.textSecondary),
            ),
            const SizedBox(height: 12),
            CorePrimaryButton(
              label: AppLocalizations.of(context).addEntry,
              icon: CupertinoIcons.add,
              onPressed: onAddEntry,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: entries.length,
          onReorder: onReorder,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return _BiasEntryCard(
              key: ValueKey(entry.id),
              entry: entry,
              index: index,
              onUpdate: onUpdateEntry,
              onDelete: () => onDeleteEntry(entry.id),
              onToggle: () => onToggleEntry(entry.id),
            );
          },
        ),
        const SizedBox(height: 8),
        CoreSecondaryButton(
          label: AppLocalizations.of(context).addEntry,
          icon: CupertinoIcons.add,
          onPressed: onAddEntry,
        ),
      ],
    );
  }
}

/// Single bias entry card (toggle + text + bias value + delete + format indicator + warnings).
class _BiasEntryCard extends ConsumerStatefulWidget {
  const _BiasEntryCard({
    super.key,
    required this.entry,
    required this.index,
    required this.onUpdate,
    required this.onDelete,
    required this.onToggle,
  });

  final LogitBiasEntry entry;
  final int index;
  final ValueChanged<LogitBiasEntry> onUpdate;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  @override
  ConsumerState<_BiasEntryCard> createState() => _BiasEntryCardState();
}

class _BiasEntryCardState extends ConsumerState<_BiasEntryCard> {
  late TextEditingController _textController;
  late TextEditingController _valueController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.entry.text);
    _valueController =
        TextEditingController(text: widget.entry.value.toString());
  }

  @override
  void didUpdateWidget(_BiasEntryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.text != widget.entry.text) {
      _textController.text = widget.entry.text;
    }
    if (oldWidget.entry.value != widget.entry.value) {
      _valueController.text = widget.entry.value.toString();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CoreDialogPalette(isDark: isDark);
    final validation = ref.watch(logitBiasValidationProvider(widget.entry));
    final service = ref.watch(logitBiasServiceProvider);
    final parsed = service.parseEntry(widget.entry);

    return Container(
      key: ValueKey('card_${widget.entry.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.fill.withValues(alpha: isDark ? 0.55 : 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ReorderableDragStartListener(
                index: widget.index,
                child: Icon(Icons.drag_handle, color: palette.textTertiary),
              ),
              const SizedBox(width: 8),
              CupertinoSwitch(
                value: widget.entry.enabled,
                onChanged: (_) => widget.onToggle(),
                activeTrackColor: DesignTokens.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: CupertinoTextField(
                  controller: _textController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: validation.errors.isNotEmpty
                          ? DesignTokens.statusError
                          : palette.outline,
                      width: 1,
                    ),
                  ),
                  placeholder: l10n.textOrToken,
                  style: TextStyle(fontSize: 14, color: palette.textPrimary),
                  enabled: widget.entry.enabled,
                  onChanged: (value) =>
                      widget.onUpdate(widget.entry.copyWith(text: value)),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: CupertinoTextField(
                  controller: _valueController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: palette.outline, width: 1),
                  ),
                  placeholder: l10n.bias,
                  style: TextStyle(fontSize: 14, color: palette.textPrimary),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  enabled: widget.entry.enabled,
                  onChanged: (value) {
                    final parsedValue = double.tryParse(value);
                    if (parsedValue != null) {
                      widget
                          .onUpdate(widget.entry.copyWith(value: parsedValue));
                    }
                  },
                ),
              ),
              const SizedBox(width: 4),
              CupertinoButton(
                padding: const EdgeInsets.all(4),
                minSize: 0,
                onPressed: widget.onDelete,
                child: const Icon(
                  CupertinoIcons.trash,
                  size: 18,
                  color: DesignTokens.statusError,
                ),
              ),
            ],
          ),
          // Placeholder hint (word, {raw text}, or [1234])
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Text(
              '词、{原文} 或 [1234]',
              style: TextStyle(fontSize: 11, color: palette.textTertiary),
            ),
          ),
          // Format indicator
          if (widget.entry.text.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const SizedBox(width: 48),
                Icon(
                  _getFormatIcon(parsed.format),
                  size: 14,
                  color: palette.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  service.getFormatDescription(parsed.format),
                  style: TextStyle(
                      fontSize: 11, color: palette.textTertiary),
                ),
              ],
            ),
          ],
          // Validation errors / warnings
          if (validation.errors.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Text(
                validation.errors.first,
                style: const TextStyle(
                    fontSize: 11, color: DesignTokens.statusError),
              ),
            ),
          ],
          if (validation.warnings.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const SizedBox(width: 48),
                const Icon(
                  Icons.warning_amber,
                  size: 14,
                  color: DesignTokens.statusWarning,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    validation.warnings.first,
                    style: const TextStyle(
                        fontSize: 11, color: DesignTokens.statusWarning),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _getFormatIcon(LogitBiasInputFormat format) {
    switch (format) {
      case LogitBiasInputFormat.text:
        return Icons.text_fields;
      case LogitBiasInputFormat.verbatim:
        return Icons.format_quote;
      case LogitBiasInputFormat.tokenIds:
        return Icons.numbers;
    }
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
