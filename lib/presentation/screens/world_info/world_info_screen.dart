import 'dart:convert';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/models/world_info.dart';
import 'package:kirakira/presentation/providers/character_providers.dart';
import 'package:kirakira/presentation/providers/world_info_providers.dart';
import 'package:kirakira/presentation/theme/app_theme.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Log a message to the console
void _log(String message, {String? error, StackTrace? stackTrace}) {
  final timestamp = DateTime.now().toIso8601String();
  final logMessage = '[$timestamp] WorldInfoScreen: $message';
  
  if (kDebugMode) {
    debugPrint(logMessage);
    if (error != null) {
      debugPrint('  Error: $error');
    }
  }
  
  developer.log(
    message,
    name: 'WorldInfoScreen',
    error: error,
    stackTrace: stackTrace,
  );
}

// A3-T4: NativeTavern 时期的世界书列表页(WorldInfoScreen/_WorldInfoCard/_WorldInfoDialog)已删除。
/// Screen for managing entries within a World Info
class WorldInfoEntriesScreen extends ConsumerStatefulWidget {
  final WorldInfo worldInfo;

  const WorldInfoEntriesScreen({super.key, required this.worldInfo});

  @override
  ConsumerState<WorldInfoEntriesScreen> createState() => _WorldInfoEntriesScreenState();
}

class _WorldInfoEntriesScreenState extends ConsumerState<WorldInfoEntriesScreen> {
  late WorldInfo _worldInfo;

  @override
  void initState() {
    super.initState();
    _worldInfo = widget.worldInfo;
  }

  void _refreshWorldInfo() async {
    final worldInfos = ref.read(worldInfoNotifierProvider).valueOrNull ?? [];
    final updated = worldInfos.firstWhere(
      (w) => w.id == _worldInfo.id,
      orElse: () => _worldInfo,
    );
    setState(() => _worldInfo = updated);
  }

  @override
  Widget build(BuildContext context) {
    // Listen to changes
    ref.listen(worldInfoNotifierProvider, (previous, next) {
      _refreshWorldInfo();
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(_worldInfo.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: AppLocalizations.of(context)!.addEntry,
            onPressed: () => _showEntryDialog(context, ref, null),
          ),
        ],
      ),
      body: _worldInfo.entries.isEmpty
          ? _buildEmptyState(context)
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _worldInfo.entries.length,
              onReorder: (oldIndex, newIndex) {
                // TODO: Implement reordering
                // TRACKED: recorded in DiaoYan/18 (phase-6 tech-debt)
              },
              itemBuilder: (context, index) {
                final entry = _worldInfo.entries[index];
                return _WorldInfoEntryCard(
                  key: ValueKey(entry.id),
                  entry: entry,
                  onTap: () => _showEntryDialog(context, ref, entry),
                  onDelete: () => _showDeleteEntryConfirmation(context, ref, entry),
                  onToggle: (enabled) {
                    ref.read(worldInfoNotifierProvider.notifier).updateEntry(
                      entry.copyWith(enabled: enabled),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_add_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.noEntriesYet,
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.addEntriesWithKeywords,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showEntryDialog(context, ref, null),
            icon: const Icon(Icons.add),
            label: Text(AppLocalizations.of(context)!.addEntry),
          ),
        ],
      ),
    );
  }

  void _showEntryDialog(BuildContext context, WidgetRef ref, WorldInfoEntry? entry) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _EntryEditDialog(
        worldInfoId: _worldInfo.id,
        entry: entry,
      ),
    ).then((_) => _refreshWorldInfo());
  }

  void _showDeleteEntryConfirmation(BuildContext context, WidgetRef ref, WorldInfoEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteEntry),
        content: Text(AppLocalizations.of(context)!.deleteEntryConfirmation(entry.keys.join(", "))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(worldInfoNotifierProvider.notifier).deleteEntry(entry.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
  }
}

/// Card widget for displaying a World Info Entry
class _WorldInfoEntryCard extends StatelessWidget {
  final WorldInfoEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const _WorldInfoEntryCard({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onDelete,
    required this.onToggle,
  });

  void _copyToClipboard(BuildContext context) {
    final text = 'Keys: ${entry.keys.join(", ")}\n'
        '${entry.comment.isNotEmpty ? "Comment: ${entry.comment}\n" : ""}'
        'Content: ${entry.content}';
    Clipboard.setData(ClipboardData(text: text));
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${l10n!.copiedToClipboard}: ${entry.keys.join(", ")}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Theme.of(context).cardColor,
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _copyToClipboard(context),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: entry.keys.map((key) => Chip(
                        label: Text(key, style: const TextStyle(fontSize: 12)),
                        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      )).toList(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () => _copyToClipboard(context),
                    tooltip: l10n.copiedToClipboard,
                  ),
                  Switch(
                    value: entry.enabled,
                    onChanged: onToggle,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: onDelete,
                  ),
                ],
              ),
              if (entry.comment.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  entry.comment,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                entry.content,
                style: const TextStyle(fontSize: 14),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (entry.constant || entry.selective) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (entry.constant)
                      _buildBadge(l10n.constant, Colors.orange),
                    if (entry.selective)
                      _buildBadge(l10n.selective, Colors.purple),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Dialog for creating/editing World Info Entry
class _WorldInfoEntryDialog extends StatefulWidget {
  final String title;
  final WorldInfoEntry? entry;
  final Future<void> Function(
    List<String> keys,
    String content,
    String comment,
    List<String> secondaryKeys,
    WorldInfoPosition position,
    bool constant,
    bool selective,
    int insertionOrder,
  ) onSave;

  const _WorldInfoEntryDialog({
    required this.title,
    this.entry,
    required this.onSave,
  });

  @override
  State<_WorldInfoEntryDialog> createState() => _WorldInfoEntryDialogState();
}

class _WorldInfoEntryDialogState extends State<_WorldInfoEntryDialog> {
  late TextEditingController _keysController;
  late TextEditingController _secondaryKeysController;
  late TextEditingController _contentController;
  late TextEditingController _commentController;
  late TextEditingController _orderController;
  late WorldInfoPosition _position;
  late bool _constant;
  late bool _selective;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _keysController = TextEditingController(
      text: widget.entry?.keys.join(', ') ?? '',
    );
    _secondaryKeysController = TextEditingController(
      text: widget.entry?.secondaryKeys.join(', ') ?? '',
    );
    _contentController = TextEditingController(
      text: widget.entry?.content ?? '',
    );
    _commentController = TextEditingController(
      text: widget.entry?.comment ?? '',
    );
    _orderController = TextEditingController(
      text: widget.entry?.insertionOrder.toString() ?? '0',
    );
    _position = widget.entry?.position ?? WorldInfoPosition.before;
    // Default constant to true for new entries (entries without keys are always included)
    _constant = widget.entry?.constant ?? true;
    _selective = widget.entry?.selective ?? false;
  }

  @override
  void dispose() {
    _keysController.dispose();
    _secondaryKeysController.dispose();
    _contentController.dispose();
    _commentController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  String _getPositionLabel(BuildContext context, WorldInfoPosition position) {
    final l10n = AppLocalizations.of(context)!;
    switch (position) {
      case WorldInfoPosition.before:
        return l10n.beforeCharacterDefinition;  // ↑Char
      case WorldInfoPosition.after:
        return l10n.afterCharacterDefinition;   // ↓Char
      case WorldInfoPosition.ANTop:
        return l10n.beforeAuthorNote;           // ↑AT
      case WorldInfoPosition.ANBottom:
        return l10n.afterAuthorNote;            // ↓AT
      case WorldInfoPosition.atDepth:
        return l10n.atDepth;                    // @D
      case WorldInfoPosition.EMTop:
        return l10n.beforeExampleMessages;      // ↑EM
      case WorldInfoPosition.EMBottom:
        return l10n.afterExampleMessages;       // ↓EM
      case WorldInfoPosition.outlet:
        return 'Outlet';                        // Named outlet
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _keysController,
                decoration: InputDecoration(
                  labelText: l10n.keywordsCommaSeparated,
                  hintText: l10n.keywordsHint,
                  border: const OutlineInputBorder(),
                  helperText: l10n.entryActivatesWhenKeywordFound,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _secondaryKeysController,
                decoration: InputDecoration(
                  labelText: l10n.secondaryKeysOptional,
                  hintText: l10n.secondaryKeysHint,
                  border: const OutlineInputBorder(),
                  helperText: l10n.bothPrimaryAndSecondaryMustMatch,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  labelText: l10n.commentOptional,
                  hintText: l10n.noteForThisEntry,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _contentController,
                decoration: InputDecoration(
                  labelText: l10n.contentLabel,
                  hintText: l10n.contextToInjectWhenMatches,
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 6,
              ),
              const SizedBox(height: 16),
              // Position dropdown
              DropdownButtonFormField<WorldInfoPosition>(
                value: _position,
                decoration: InputDecoration(
                  labelText: l10n.insertionPosition,
                  border: const OutlineInputBorder(),
                ),
                items: WorldInfoPosition.values.map((pos) {
                  return DropdownMenuItem(
                    value: pos,
                    child: Text(_getPositionLabel(context, pos)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _position = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              // Insertion order
              TextField(
                controller: _orderController,
                decoration: InputDecoration(
                  labelText: l10n.insertionOrder,
                  hintText: '0',
                  border: const OutlineInputBorder(),
                  helperText: l10n.lowerOrderInsertsFirst,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              // Constant switch
              SwitchListTile(
                title: Text(l10n.constant),
                subtitle: Text(l10n.alwaysIncludeInPrompt),
                value: _constant,
                onChanged: (value) => setState(() => _constant = value),
                contentPadding: EdgeInsets.zero,
              ),
              // Selective switch
              SwitchListTile(
                title: Text(l10n.selective),
                subtitle: Text(l10n.requiresSecondaryKey),
                value: _selective,
                onChanged: (value) => setState(() => _selective = value),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.save),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final keys = _keysController.text
        .split(',')
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();

    // Keys are optional - entries without keys are treated as constant (always included)
    // No validation needed for keys

    final content = _contentController.text.trim();
    if (content.isEmpty) {
      final message = l10n.pleaseEnterContent;
      _log('Validation failed: $message');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    final secondaryKeys = _secondaryKeysController.text
        .split(',')
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();

    final insertionOrder = int.tryParse(_orderController.text.trim()) ?? 0;
    
    // If no keys provided, force constant to true
    final actualConstant = keys.isEmpty ? true : _constant;

    setState(() => _isSaving = true);
    
    _log('Saving entry: keys=$keys, constant=$actualConstant, selective=$_selective, position=$_position');

    try {
      await widget.onSave(
        keys,
        content,
        _commentController.text.trim(),
        secondaryKeys,
        _position,
        actualConstant,
        _selective,
        insertionOrder,
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e, st) {
      _log('Failed to save entry', error: e.toString(), stackTrace: st);
      if (mounted) {
        final message = '${l10n.error}: $e';
        _log('Showing error: $message');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        setState(() => _isSaving = false);
      }
    }
  }
}
// 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?//  Entry edit dialog (showDialog version 鈥?Phase E)
// 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?
class _EntryEditDialog extends ConsumerStatefulWidget {
  final String worldInfoId;
  final WorldInfoEntry? entry;

  const _EntryEditDialog({required this.worldInfoId, this.entry});

  @override
  ConsumerState<_EntryEditDialog> createState() => _EntryEditDialogState();
}

class _EntryEditDialogState extends ConsumerState<_EntryEditDialog> {
  late TextEditingController _keysCtrl;
  late TextEditingController _secondaryCtrl;
  late TextEditingController _contentCtrl;
  late TextEditingController _commentCtrl;
  late TextEditingController _orderCtrl;

  late bool _enabled;
  late bool _constant;
  late bool _selective;
  late WorldInfoPosition _position;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _keysCtrl = TextEditingController(text: e?.keys.join(', ') ?? '');
    _secondaryCtrl = TextEditingController(text: e?.secondaryKeys.join(', ') ?? '');
    _contentCtrl = TextEditingController(text: e?.content ?? '');
    _commentCtrl = TextEditingController(text: e?.comment ?? '');
    _orderCtrl = TextEditingController(text: (e?.insertionOrder ?? 0).toString());
    _enabled = e?.enabled ?? true;
    _constant = e?.constant ?? false;
    _selective = e?.selective ?? false;
    _position = e?.position ?? WorldInfoPosition.before;
  }

  @override
  void dispose() {
    _keysCtrl.dispose();
    _secondaryCtrl.dispose();
    _contentCtrl.dispose();
    _commentCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final keys = _keysCtrl.text
        .split(',')
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();
    final content = _contentCtrl.text.trim();
    final comment = _commentCtrl.text.trim();
    final secondaryKeys = _secondaryCtrl.text
        .split(',')
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();
    final order = int.tryParse(_orderCtrl.text.trim()) ?? 0;

    if (keys.isEmpty && !_constant) {
      _showSnack('Please enter at least one trigger word');
      return;
    }
    if (content.isEmpty) {
      _showSnack('Please enter content');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final notifier = ref.read(worldInfoNotifierProvider.notifier);

      if (widget.entry == null) {
        await notifier.addEntry(
          worldInfoId: widget.worldInfoId,
          keys: keys,
          content: content,
          comment: comment,
          secondaryKeys: secondaryKeys,
          position: _position,
          constant: _constant,
          selective: _selective,
          insertionOrder: order,
        );
      } else {
        await notifier.updateEntry(
          widget.entry!.copyWith(
            keys: keys,
            content: content,
            comment: comment,
            secondaryKeys: secondaryKeys,
            enabled: _enabled,
            constant: _constant,
            selective: _selective,
            position: _position,
            insertionOrder: order,
          ),
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        _showSnack('Error: $e');
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isNew = widget.entry == null;

    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusLg)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Row(
                children: [
                  Icon(
                    isNew ? Icons.add_circle_outline : Icons.edit_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isNew ? l10n.createEntry : l10n.editEntry,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Trigger Words
              _label(l10n.keywords),
              const SizedBox(height: 4),
              TextField(
                controller: _keysCtrl,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                decoration: _inputDec('例如：剑、龙、魔法'),
              ),
              const SizedBox(height: 12),

              // Secondary Keys
              _label(l10n.secondaryKeysOptional),
              const SizedBox(height: 4),
              TextField(
                controller: _secondaryCtrl,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                decoration: _inputDec('可选的次要触发词'),
              ),
              const SizedBox(height: 12),

              // Content
              _label(l10n.content),
              const SizedBox(height: 4),
              TextField(
                controller: _contentCtrl,
                maxLines: 5,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                decoration: _inputDec('要注入的条目内容'),
              ),
              const SizedBox(height: 12),

              // Comment
              _label(l10n.commentOptional),
              const SizedBox(height: 4),
              TextField(
                controller: _commentCtrl,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                decoration: _inputDec('可选备注（不发送给AI）'),
              ),
              const SizedBox(height: 16),

              // Order + Position row
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(l10n.insertionOrder),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _orderCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                          decoration: _inputDec('0'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(l10n.insertionPosition),
                        const SizedBox(height: 4),
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<WorldInfoPosition>(
                              value: _position,
                              isExpanded: true,
                              dropdownColor: Theme.of(context).cardColor,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                              items: WorldInfoPosition.values.map((p) {
                                final String label;
                                switch (p) {
                                  case WorldInfoPosition.before:
                                    label = '角色定义之前';
                                    break;
                                  case WorldInfoPosition.after:
                                    label = '角色定义之后';
                                    break;
                                  case WorldInfoPosition.ANTop:
                                    label = '作者注释之前';
                                    break;
                                  case WorldInfoPosition.ANBottom:
                                    label = '作者注释之后';
                                    break;
                                  case WorldInfoPosition.atDepth:
                                    label = '指定深度';
                                    break;
                                  case WorldInfoPosition.EMTop:
                                    label = '示例对话之前';
                                    break;
                                  case WorldInfoPosition.EMBottom:
                                    label = '示例对话之后';
                                    break;
                                  case WorldInfoPosition.outlet:
                                    label = '命名插槽';
                                    break;
                                }
                                return DropdownMenuItem(value: p, child: Text(label));
                              }).toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => _position = v);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Switches
              Row(
                children: [
                  _switchRow(l10n.enabled, _enabled, (v) => setState(() => _enabled = v)),
                  const SizedBox(width: 16),
                  _switchRow(l10n.alwaysIncludeInPrompt, _constant, (v) => setState(() => _constant = v)),
                  const SizedBox(width: 16),
                  _switchRow(l10n.requiresSecondaryKey, _selective, (v) => setState(() => _selective = v)),
                ],
              ),
              const SizedBox(height: 20),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.cancel,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusSm)),
                    ),
                    child: _isSaving
                        ? SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.onPrimary),
                          )
                        : Text(l10n.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
        fontSize: DesignTokens.fontSizeSm,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  InputDecoration _inputDec(String hint) {
    final theme = Theme.of(context);
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        fontSize: DesignTokens.fontSizeSm,
      ),
      filled: true,
      fillColor: theme.cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        borderSide: BorderSide(color: theme.colorScheme.primary),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 24,
            child: Switch(
              value: value,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
