import 'dart:convert';
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

/// Screen for managing World Info / Lorebooks
class WorldInfoScreen extends ConsumerWidget {
  final String? characterId;
  final bool isGlobal;

  const WorldInfoScreen({super.key, this.characterId, this.isGlobal = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worldInfosAsync = ref.watch(worldInfoNotifierProvider);

    final displayInfos = worldInfosAsync.whenData((infos) {
      if (characterId != null) return infos.where((w) => w.characterId == characterId).toList();
      if (isGlobal) return infos.where((w) => w.isGlobal).toList();
      return infos;
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(isGlobal ? '全局世界书' : characterId != null ? '角色世界书' : '世界书'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: AppLocalizations.of(context)!.import,
            onPressed: () => _importWorldInfo(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: AppLocalizations.of(context)!.createLorebook,
            onPressed: () => _showCreateDialog(context, ref),
          ),
        ],
      ),
      body: displayInfos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(worldInfoNotifierProvider.notifier).refresh(),
                child: Text(AppLocalizations.of(context)!.retry),
              ),
            ],
          ),
        ),
        data: (worldInfos) {
          if (worldInfos.isEmpty) {
            return _buildEmptyState(context, ref);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: worldInfos.length,
            itemBuilder: (context, index) {
              final worldInfo = worldInfos[index];
              return _WorldInfoCard(
                worldInfo: worldInfo,
                onTap: () => _openWorldInfo(context, worldInfo),
                onEdit: () => _showEditDialog(context, ref, worldInfo),
                onDelete: () => _showDeleteConfirmation(context, ref, worldInfo),
                onToggle: (enabled) {
                  ref.read(worldInfoNotifierProvider.notifier).updateWorldInfo(
                    worldInfo.copyWith(enabled: enabled),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.auto_stories_outlined,
            size: 64,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.noLorebooksYet,
            style: const TextStyle(
              fontSize: 18,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              AppLocalizations.of(context)!.lorebooksInjectContext,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showCreateDialog(context, ref),
            icon: const Icon(Icons.add),
            label: Text(AppLocalizations.of(context)!.createLorebook),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _WorldInfoDialog(
        ref: ref,
        title: AppLocalizations.of(context)!.createLorebook,
        initialCharacterId: characterId,
        initialIsGlobal: isGlobal,
        lockToGlobal: isGlobal,
        onSave: (name, description, isGlobal, characterId) async {
          _log('Creating world info: name=$name, isGlobal=$isGlobal, characterId=$characterId');
          await ref.read(worldInfoNotifierProvider.notifier).createWorldInfo(
            name: name,
            description: description,
            isGlobal: isGlobal,
            characterId: characterId,
          );
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, WorldInfo worldInfo) {
    showDialog(
      context: context,
      builder: (context) => _WorldInfoDialog(
        ref: ref,
        title: AppLocalizations.of(context)!.editGroup,
        initialName: worldInfo.name,
        initialDescription: worldInfo.description,
        initialIsGlobal: worldInfo.isGlobal,
        initialCharacterId: worldInfo.characterId,
        onSave: (name, description, isGlobal, characterId) async {
          _log('Updating world info: name=$name, isGlobal=$isGlobal, characterId=$characterId');
          await ref.read(worldInfoNotifierProvider.notifier).updateWorldInfo(
            worldInfo.copyWith(
              name: name,
              description: description,
              isGlobal: isGlobal,
              characterId: characterId,
            ),
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, WorldInfo worldInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteGroup),
        content: Text(AppLocalizations.of(context)!.deleteLorebookConfirmation(worldInfo.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(worldInfoNotifierProvider.notifier).deleteWorldInfo(worldInfo.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
  }

  void _openWorldInfo(BuildContext context, WorldInfo worldInfo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorldInfoEntriesScreen(worldInfo: worldInfo),
      ),
    );
  }

  Future<void> _importWorldInfo(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    try {
      _log('Starting world info import...');
      
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) {
        _log('No file selected');
        return;
      }

      final file = result.files.first;
      _log('Selected file: ${file.name}');
      String jsonString;

      if (file.bytes != null) {
        jsonString = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        jsonString = await File(file.path!).readAsString();
      } else {
        throw Exception('Could not read file');
      }

      _log('File content length: ${jsonString.length} chars');
      
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      _log('Parsed JSON keys: ${json.keys.toList()}');
      
      // Parse entries from different formats
      final parsedEntries = _parseWorldInfoEntries(json);
      _log('Parsed ${parsedEntries.length} entries');
      
      // Get world info name
      final name = json['name']?.toString() ??
                   json['originalData']?['name']?.toString() ??
                   file.name.replaceAll('.json', '');
      final description = json['description']?.toString();
      
      _log('Creating world info: $name');
      
      await ref.read(worldInfoNotifierProvider.notifier).createWorldInfo(
        name: name,
        description: description,
        isGlobal: json['isGlobal'] == true,
      );

      // Import entries
      final createdWorldInfos = ref.read(worldInfoNotifierProvider).valueOrNull ?? [];
      final createdWorldInfo = createdWorldInfos.firstWhere((w) => w.name == name);
      
      _log('Adding ${parsedEntries.length} entries to world info: ${createdWorldInfo.id}');
      
      for (final entry in parsedEntries) {
        try {
          await ref.read(worldInfoNotifierProvider.notifier).addEntry(
            worldInfoId: createdWorldInfo.id,
            keys: entry['keys'] as List<String>,
            content: entry['content'] as String,
            comment: entry['comment'] as String? ?? '',
            secondaryKeys: entry['secondaryKeys'] as List<String>? ?? [],
          );
        } catch (e, st) {
          _log('Failed to add entry: ${entry['keys']}', error: e.toString(), stackTrace: st);
        }
      }

      _log('Import completed successfully');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n!.importedAndApplied(name))),
        );
      }
    } catch (e, st) {
      _log('Import failed', error: e.toString(), stackTrace: st);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.importFailed(e.toString())}')),
        );
      }
    }
  }
  
  /// Parse world info entries from various formats (SillyTavern, KiraKira, etc.)
  List<Map<String, dynamic>> _parseWorldInfoEntries(Map<String, dynamic> json) {
    final entries = <Map<String, dynamic>>[];
    
    // Check for SillyTavern format: entries is a Map<String, Entry>
    if (json['entries'] is Map) {
      _log('Detected SillyTavern format (entries as Map)');
      final entriesMap = json['entries'] as Map<String, dynamic>;
      
      for (final entry in entriesMap.entries) {
        try {
          final entryData = entry.value as Map<String, dynamic>;
          entries.add(_parseEntry(entryData));
        } catch (e, st) {
          _log('Failed to parse entry ${entry.key}', error: e.toString(), stackTrace: st);
        }
      }
    }
    // Check for KiraKira format: entries is a List<Entry>
    else if (json['entries'] is List) {
      _log('Detected KiraKira format (entries as List)');
      final entriesList = json['entries'] as List<dynamic>;
      
      for (var i = 0; i < entriesList.length; i++) {
        try {
          final entryData = entriesList[i] as Map<String, dynamic>;
          entries.add(_parseEntry(entryData));
        } catch (e, st) {
          _log('Failed to parse entry at index $i', error: e.toString(), stackTrace: st);
        }
      }
    }
    
    return entries;
  }
  
  /// Parse a single entry, handling type conversions
  Map<String, dynamic> _parseEntry(Map<String, dynamic> data) {
    // Handle keys - SillyTavern uses 'key', KiraKira uses 'keys'
    List<String> keys;
    if (data['keys'] != null) {
      keys = _parseStringList(data['keys']);
    } else if (data['key'] != null) {
      keys = _parseStringList(data['key']);
    } else {
      keys = [];
    }
    
    // Handle secondary keys
    List<String> secondaryKeys;
    if (data['secondaryKeys'] != null) {
      secondaryKeys = _parseStringList(data['secondaryKeys']);
    } else if (data['secondary_keys'] != null) {
      secondaryKeys = _parseStringList(data['secondary_keys']);
    } else if (data['keysecondary'] != null) {
      secondaryKeys = _parseStringList(data['keysecondary']);
    } else {
      secondaryKeys = [];
    }
    
    // Handle content
    final content = data['content']?.toString() ?? '';
    
    // Handle comment
    final comment = data['comment']?.toString() ?? '';
    
    return {
      'keys': keys,
      'secondaryKeys': secondaryKeys,
      'content': content,
      'comment': comment,
    };
  }
  
  /// Safely parse a list of strings from various formats
  List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    }
    if (value is String) {
      // Handle comma-separated string
      return value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    return [];
  }
}

/// Card widget for displaying a World Info
class _WorldInfoCard extends StatelessWidget {
  final WorldInfo worldInfo;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const _WorldInfoCard({
    required this.worldInfo,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppTheme.darkCard,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: worldInfo.enabled
                      ? AppTheme.primaryColor.withValues(alpha: 0.2)
                      : AppTheme.textMuted.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.auto_stories,
                  color: worldInfo.enabled ? AppTheme.primaryColor : AppTheme.textMuted,
                ),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            worldInfo.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (worldInfo.isGlobal)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.globalScope,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.accentColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context)!.entriesCount(worldInfo.entries.length),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    if (worldInfo.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        worldInfo.description!,
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Actions
              Switch(
                value: worldInfo.enabled,
                onChanged: onToggle,
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppTheme.textMuted),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                      break;
                    case 'export':
                      _exportWorldInfo(context, worldInfo);
                      break;
                    case 'delete':
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: const Icon(Icons.edit),
                      title: Text(AppLocalizations.of(context)!.edit),
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
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: const Icon(Icons.delete, color: Colors.red),
                      title: Text(AppLocalizations.of(context)!.delete, style: const TextStyle(color: Colors.red)),
                      contentPadding: EdgeInsets.zero,
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

  static Future<void> _exportWorldInfo(BuildContext context, WorldInfo worldInfo) async {
    try {
      final json = worldInfo.toJson();
      final jsonString = const JsonEncoder.withIndent('  ').convert(json);

      final tempDir = await getTemporaryDirectory();
      final fileName = '${worldInfo.name.replaceAll(RegExp(r'[^\w\s-]'), '_')}.json';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonString);

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'KiraKira World Info: ${worldInfo.name}',
      );
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n!.exportFailed(e.toString()))),
        );
      }
    }
  }
}

/// Dialog for creating/editing World Info
class _WorldInfoDialog extends StatefulWidget {
  final String title;
  final String? initialName;
  final String? initialDescription;
  final bool initialIsGlobal;
  final String? initialCharacterId;
  final bool lockToGlobal;
  final WidgetRef ref;
  final Future<void> Function(String name, String? description, bool isGlobal, String? characterId) onSave;

  const _WorldInfoDialog({
    required this.ref,
    required this.title,
    this.initialName,
    this.initialDescription,
    this.initialIsGlobal = true,
    this.initialCharacterId,
    this.lockToGlobal = false,
    required this.onSave,
  });

  @override
  State<_WorldInfoDialog> createState() => _WorldInfoDialogState();
}

/// Scope type for World Info
enum _WorldInfoScope {
  global,         // Apply to all characters universally
  allCharacters,  // Available to all characters (characterId = null)
  specificCharacter, // Bound to a specific character
}

class _WorldInfoDialogState extends State<_WorldInfoDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late _WorldInfoScope _scope;
  String? _selectedCharacterId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _descriptionController = TextEditingController(text: widget.initialDescription ?? '');
    
    // Determine initial scope
    if (widget.initialIsGlobal) {
      _scope = _WorldInfoScope.global;
    } else if (widget.initialCharacterId != null) {
      _scope = _WorldInfoScope.specificCharacter;
      _selectedCharacterId = widget.initialCharacterId;
    } else {
      _scope = _WorldInfoScope.allCharacters;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    // Get character list from provider
    final charactersAsync = widget.ref.watch(characterListProvider);
    
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.name,
                hintText: l10n.enterLorebookName,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: l10n.description,
                hintText: l10n.optionalDescriptionHint,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Scope selection
            Text(
              l10n.scope,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),

            // 全局入口：锁定为全局，只显示只读说明
            if (widget.lockToGlobal)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.public, size: 20, color: AppTheme.accentColor),
                    const SizedBox(width: 8),
                    Text(
                      l10n.globalScope,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),

            // 非锁定：显示完整三个作用域选项
            if (!widget.lockToGlobal) ...[
              // Global scope option
              RadioListTile<_WorldInfoScope>(
                title: Text(l10n.globalScope),
                subtitle: Text(l10n.applyToAllChats),
                value: _WorldInfoScope.global,
                groupValue: _scope,
                onChanged: (value) => setState(() {
                  _scope = value!;
                  _selectedCharacterId = null;
                }),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),

              // All characters option
              RadioListTile<_WorldInfoScope>(
                title: Text(l10n.allCharactersAvailable),
                subtitle: Text(l10n.availableToAllCharactersNotGlobal),
                value: _WorldInfoScope.allCharacters,
                groupValue: _scope,
                onChanged: (value) => setState(() {
                  _scope = value!;
                  _selectedCharacterId = null;
                }),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),

              // Specific character option
              RadioListTile<_WorldInfoScope>(
                title: Text(l10n.specificCharacter),
                subtitle: Text(l10n.linkToSpecificCharacter),
                value: _WorldInfoScope.specificCharacter,
                groupValue: _scope,
                onChanged: (value) => setState(() {
                  _scope = value!;
                }),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),

              // Character dropdown (when specific character is selected)
              if (_scope == _WorldInfoScope.specificCharacter)
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 8),
                  child: charactersAsync.when(
                    loading: () => const CircularProgressIndicator(),
                    error: (error, stack) => Text('Error: $error'),
                    data: (characters) {
                      if (characters.isEmpty) {
                        return Text(
                          l10n.noCharactersAvailable,
                          style: const TextStyle(color: Colors.grey),
                        );
                      }
                      return DropdownButtonFormField<String>(
                        value: _selectedCharacterId,
                        decoration: InputDecoration(
                          labelText: l10n.selectCharacter,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: characters.map((char) {
                          return DropdownMenuItem(
                            value: char.id,
                            child: Text(char.name),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedCharacterId = value);
                          _log('Selected character: $value');
                        },
                      );
                    },
                  ),
                ),
            ],
          ],
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
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseEnterName2)),
      );
      return;
    }
    
    // Validate character selection if specific character is chosen
    if (_scope == _WorldInfoScope.specificCharacter && _selectedCharacterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseSelectCharacter)),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Determine values based on scope
      final isGlobal = _scope == _WorldInfoScope.global;
      final characterId = _scope == _WorldInfoScope.specificCharacter ? _selectedCharacterId : null;
      
      _log('Saving world info: name=$name, scope=$_scope, isGlobal=$isGlobal, characterId=$characterId');
      
      await widget.onSave(
        name,
        _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        isGlobal,
        characterId,
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }
}

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
        borderRadius: BorderRadius.circular(12),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                            borderRadius: BorderRadius.circular(8),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        fontSize: 13,
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
        fontSize: 13,
      ),
      filled: true,
      fillColor: theme.cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
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

