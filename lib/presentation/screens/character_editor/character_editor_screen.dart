import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/models/character.dart';
import 'package:kirakira/data/models/world_info.dart';
import 'package:kirakira/presentation/providers/character_providers.dart';
import 'package:kirakira/presentation/providers/world_info_providers.dart';
import 'package:kirakira/presentation/screens/world_info/world_info_screen.dart';
import 'package:kirakira/data/repositories/character_repository.dart';
import 'package:kirakira/presentation/theme/app_theme.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/widgets/regex/regex_widgets.dart';
import 'package:kirakira/presentation/providers/regex_providers.dart';
import 'package:kirakira/data/models/regex_script.dart';
import 'package:kirakira/presentation/widgets/common/kira_button.dart';

/// 统一表单输入框描边(radiusInput 12)
OutlineInputBorder _outlineBorder() => OutlineInputBorder(
      borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
    );

/// Character editor screen
class CharacterEditorScreen extends ConsumerStatefulWidget {
  final String? characterId;
  const CharacterEditorScreen({super.key, this.characterId});
  @override
  ConsumerState<CharacterEditorScreen> createState() => _CharacterEditorScreenState();
}

class _CharacterEditorScreenState extends ConsumerState<CharacterEditorScreen> with TickerProviderStateMixin {
  TabController? _tabController;
  String? _editingCharacterId;
  late TextEditingController _nameCtrl, _descCtrl, _personalityCtrl, _scenarioCtrl, _firstMsgCtrl, _systemPromptCtrl, _creatorNotesCtrl, _tagsCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _editingCharacterId = widget.characterId;
    _nameCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _personalityCtrl = TextEditingController();
    _scenarioCtrl = TextEditingController();
    _firstMsgCtrl = TextEditingController();
    _systemPromptCtrl = TextEditingController();
    _creatorNotesCtrl = TextEditingController();
    _tagsCtrl = TextEditingController();
    if (_editingCharacterId != null) { _initTabs(2); _loadCharacter(); } else { _initTabs(1); }
  }

  void _initTabs(int count) { _tabController = TabController(length: count, vsync: this); }

  Future<void> _loadCharacter() async {
    if (_editingCharacterId == null) return;
    final repo = ref.read(characterRepositoryProvider);
    final character = await repo.getCharacter(_editingCharacterId!);
    if (character != null && mounted) {
      _nameCtrl.text = character.name;
      _descCtrl.text = character.description;
      _personalityCtrl.text = character.personality;
      _scenarioCtrl.text = character.scenario;
      _firstMsgCtrl.text = character.firstMessage;
      _systemPromptCtrl.text = character.systemPrompt;
      _creatorNotesCtrl.text = character.creatorNotes;
      _tagsCtrl.text = character.tags.join(', ');
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _nameCtrl.dispose(); _descCtrl.dispose(); _personalityCtrl.dispose();
    _scenarioCtrl.dispose(); _firstMsgCtrl.dispose(); _systemPromptCtrl.dispose();
    _creatorNotesCtrl.dispose(); _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final notifier = ref.read(characterListProvider.notifier);
      final tags = _tagsCtrl.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
      if (_editingCharacterId != null) {
        final existingList = ref.read(characterListProvider).valueOrNull ?? [];
        final existing = existingList.cast<Character?>().firstWhere((c) => c?.id == _editingCharacterId, orElse: () => null);
        if (existing != null) {
          await notifier.updateCharacter(existing.copyWith(
            name: _nameCtrl.text.trim(), description: _descCtrl.text.trim(),
            personality: _personalityCtrl.text.trim(), scenario: _scenarioCtrl.text.trim(),
            firstMessage: _firstMsgCtrl.text.trim(), systemPrompt: _systemPromptCtrl.text.trim(),
            creatorNotes: _creatorNotesCtrl.text.trim(), tags: tags, modifiedAt: DateTime.now(),
          ));
        }
      } else {
        final now = DateTime.now();
        final newChar = Character(id: '', name: _nameCtrl.text.trim(), description: _descCtrl.text.trim(),
          personality: _personalityCtrl.text.trim(), scenario: _scenarioCtrl.text.trim(),
          firstMessage: _firstMsgCtrl.text.trim(), systemPrompt: _systemPromptCtrl.text.trim(),
          creatorNotes: _creatorNotesCtrl.text.trim(), tags: tags, createdAt: now, modifiedAt: now);
        final created = await notifier.addCharacter(newChar);
        _editingCharacterId = created.id;
        if (mounted) { _tabController?.dispose(); _initTabs(2); setState(() {}); }
        // 条目1:提示已同步生成绑定世界书(正则集随卡自带空集)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已创建,并同步生成本卡专属世界书')),
          );
        }
      }
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.save)));
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.error}: $e')));
      }
    } finally { if (mounted) setState(() => _isSaving = false); }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEdit = _editingCharacterId != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? l10n.editCharacter : l10n.createCharacter),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
            label: Text(l10n.save),
          ),
        ],
        bottom: isEdit && _tabController != null ? TabBar(controller: _tabController, tabs: [
          Tab(text: l10n.characterName),
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.auto_stories_outlined, size: 18), const SizedBox(width: DesignTokens.spaceSm), Text(l10n.worldInfo)])),
        ]) : null,
      ),
      body: isEdit && _tabController != null
          ? TabBarView(controller: _tabController, children: [
              _buildBasicInfoTab(l10n),
              _WorldBookTab(characterId: _editingCharacterId!),
            ])
          : _buildBasicInfoTab(l10n),
    );
  }

  Widget _buildBasicInfoTab(AppLocalizations l10n) {
    return SingleChildScrollView(padding: DesignTokens.paddingCard, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _field(l10n.name, _nameCtrl, hint: l10n.characterName), const SizedBox(height: DesignTokens.spaceMd),
      _field(l10n.description, _descCtrl, maxLines: 3, hint: l10n.description), const SizedBox(height: DesignTokens.spaceMd),
      _field(l10n.personality, _personalityCtrl, maxLines: 4, hint: l10n.personality), const SizedBox(height: DesignTokens.spaceMd),
      _field(l10n.scenario, _scenarioCtrl, maxLines: 3, hint: l10n.scenario), const SizedBox(height: DesignTokens.spaceMd),
      _field(l10n.firstMessage, _firstMsgCtrl, maxLines: 4, hint: l10n.firstMessage), const SizedBox(height: DesignTokens.spaceMd),
      _field(l10n.systemPrompt, _systemPromptCtrl, maxLines: 4, hint: l10n.systemPrompt), const SizedBox(height: DesignTokens.spaceMd),
      _field(l10n.creatorNotes, _creatorNotesCtrl, maxLines: 2, hint: l10n.creatorNotes), const SizedBox(height: DesignTokens.spaceMd),
      _field(l10n.tags, _tagsCtrl, hint: l10n.tagsHint), const SizedBox(height: DesignTokens.spaceLg),
      if (_editingCharacterId != null) ...[
        const Divider(height: 32),
        _buildRegexSection(l10n),
        const SizedBox(height: DesignTokens.spaceLg),
      ],
      // 试点:保存按钮统一为 KiraButton.filled(批量批换另列一轮)
      KiraButton.icon(onPressed: _isSaving ? null : _save, icon: Icons.save, isLoading: _isSaving, label: Text(l10n.save)),
    ]));
  }

  Widget _field(String label, TextEditingController ctrl, {int maxLines = 1, String? hint}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textSecondary, fontSize: DesignTokens.fontSizeSm)),
      const SizedBox(height: DesignTokens.spaceXs),
      TextField(controller: ctrl, maxLines: maxLines, decoration: InputDecoration(hintText: hint, border: _outlineBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMd, vertical: DesignTokens.spaceSm))),
    ]);
  }
  Widget _buildRegexSection(AppLocalizations l10n) {
    final scripts = ref.watch(characterRegexScriptsProvider(_editingCharacterId!));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('角色正则 (${scripts.length})',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textSecondary)),
        const Spacer(),
        IconButton(icon: const Icon(Icons.add_circle_outline), tooltip: '添加正则',
            onPressed: () => _showRegexEditor(null)),
      ]),
      const SizedBox(height: DesignTokens.spaceXs),
      if (scripts.isEmpty)
        Container(
          padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceLg),
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.find_replace, size: 40, color: AppTheme.textMuted),
            const SizedBox(height: DesignTokens.spaceSm),
            const Text('尚未添加角色正则', style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: DesignTokens.spaceMd),
            ElevatedButton.icon(onPressed: () => _showRegexEditor(null),
                icon: const Icon(Icons.add), label: const Text('添加正则')),
          ]),
        )
      else
        ...scripts.map((script) => RegexScriptTile(
              key: ValueKey(script.id),
              script: script,
              onTap: () => _showRegexEditor(script),
              onToggle: () => ref.read(characterRegexScriptsProvider(_editingCharacterId!).notifier).toggleScript(script.id),
              onDelete: () => ref.read(characterRegexScriptsProvider(_editingCharacterId!).notifier).removeScript(script.id),
            )),
    ]);
  }

  void _showRegexEditor(RegexScript? script) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => RegexScriptEditor(
        script: script,
        onSave: (newScript) {
          if (script == null) {
            ref.read(characterRegexScriptsProvider(_editingCharacterId!).notifier).addScript(newScript);
          } else {
            ref.read(characterRegexScriptsProvider(_editingCharacterId!).notifier).updateScript(newScript);
          }
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

// 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?//  World Book Tab (embedded inside the editor)
// 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?
class _WorldBookTab extends ConsumerWidget {
  final String characterId;
  const _WorldBookTab({required this.characterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final worldInfosAsync = ref.watch(characterWorldInfosProvider(characterId));

    return worldInfosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, size: 40, color: Colors.red),
        const SizedBox(height: DesignTokens.spaceSm), Text('${l10n.error}: $e'),
        const SizedBox(height: DesignTokens.spaceMd),
        ElevatedButton(onPressed: () => ref.invalidate(characterWorldInfosProvider(characterId)), child: Text(l10n.retry)),
      ])),
      data: (worldBooks) {
        return Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(DesignTokens.spaceMd, DesignTokens.spaceSm, DesignTokens.spaceSm, DesignTokens.spaceXs), child: Row(children: [
            Text('${l10n.worldInfo} (${worldBooks.length})',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppTheme.textSecondary)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.add_circle_outline), tooltip: l10n.createLorebook,
                onPressed: () => _showCreateDialog(context, ref, l10n)),
          ])),
          Expanded(child: worldBooks.isEmpty
              ? _buildEmpty(context, ref, l10n)
              : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMd),
                  itemCount: worldBooks.length, itemBuilder: (_, i) => _WorldBookCard(worldBook: worldBooks[i]))),
        ]);
      },
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.auto_stories_outlined, size: 48, color: AppTheme.textMuted), const SizedBox(height: DesignTokens.spaceMd),
      Text(l10n.noLorebooksYet, style: const TextStyle(color: AppTheme.textSecondary)), const SizedBox(height: DesignTokens.spaceMd),
      ElevatedButton.icon(onPressed: () => _showCreateDialog(context, ref, l10n),
          icon: const Icon(Icons.add), label: Text(l10n.createLorebook)),
    ]));
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    showDialog(context: context, builder: (ctx) => _WorldBookDialog(title: l10n.createLorebook, characterId: characterId,
      onSave: (name, desc) async {
        await ref.read(worldInfoNotifierProvider.notifier).createWorldInfo(name: name, description: desc, isGlobal: false, characterId: characterId);
      }));
  }
}

class _WorldBookCard extends ConsumerWidget {
  final WorldInfo worldBook;
  const _WorldBookCard({required this.worldBook});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final entryCount = worldBook.entries.length;

    return Card(margin: const EdgeInsets.only(bottom: DesignTokens.spaceSm), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radiusCard)), child: InkWell(borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
      onTap: () => _openEntries(context),
      child: Padding(padding: DesignTokens.paddingCard, child: Row(children: [
        const Icon(Icons.auto_stories, color: AppTheme.textSecondary), const SizedBox(width: DesignTokens.spaceMd),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(worldBook.name, style: Theme.of(context).textTheme.titleSmall, overflow: TextOverflow.ellipsis),
          if (worldBook.description != null && worldBook.description!.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: DesignTokens.spaceXxs), child: Text(worldBook.description!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(height: DesignTokens.spaceXs),
          Text('$entryCount entries',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textSecondary)),
        ])),
        IconButton(icon: const Icon(Icons.edit_outlined, size: 20), tooltip: l10n.edit,
            onPressed: () => _showEditDialog(context, ref, l10n)),
        IconButton(icon: const Icon(Icons.delete_outline, size: 20), tooltip: l10n.delete,
            onPressed: () => _confirmDelete(context, ref, l10n)),
      ]))),
    );
  }

  void _openEntries(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => WorldInfoEntriesScreen(worldInfo: worldBook)));
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    showDialog(context: context, builder: (ctx) => _WorldBookDialog(title: l10n.editGroup,
      initialName: worldBook.name, initialDescription: worldBook.description, characterId: worldBook.characterId ?? '',
      onSave: (name, desc) async {
        await ref.read(worldInfoNotifierProvider.notifier).updateWorldInfo(worldBook.copyWith(name: name, description: desc));
      }));
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(l10n.deleteGroup), content: Text('Delete "' + worldBook.name + '"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
        TextButton(onPressed: () { Navigator.pop(ctx); ref.read(worldInfoNotifierProvider.notifier).deleteWorldInfo(worldBook.id); },
            style: TextButton.styleFrom(foregroundColor: Colors.red), child: Text(l10n.delete)),
      ],
    ));
  }
}

// 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?//  World Book create / edit dialog
// 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?
class _WorldBookDialog extends StatefulWidget {
  final String title;
  final String? initialName;
  final String? initialDescription;
  final String? characterId;
  final Future<void> Function(String name, String? description) onSave;

  const _WorldBookDialog({required this.title, required this.onSave, this.initialName, this.initialDescription, this.characterId});
  @override
  State<_WorldBookDialog> createState() => _WorldBookDialogState();
}
class _WorldBookDialogState extends State<_WorldBookDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName ?? '');
    _descCtrl = TextEditingController(text: widget.initialDescription ?? '');
  }

  @override
  void dispose() { _nameCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(controller: _nameCtrl, autofocus: true,
            decoration: InputDecoration(labelText: l10n.name, border: _outlineBorder())),
        const SizedBox(height: DesignTokens.spaceMd),
        TextField(controller: _descCtrl, maxLines: 3,
            decoration: InputDecoration(labelText: l10n.description, border: _outlineBorder())),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        ElevatedButton(
          onPressed: _saving ? null : () async {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.nameRequired)));
              return;
            }
            setState(() => _saving = true);
            try {
              await widget.onSave(name, _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim());
              if (mounted) Navigator.pop(context);
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.error}: $e')));
                setState(() => _saving = false);
              }
            }
          },
          child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l10n.save),
        ),
      ],
    );
  }
}