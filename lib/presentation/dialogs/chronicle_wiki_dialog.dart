// lib/presentation/dialogs/chronicle_wiki_dialog.dart
/// Chronicle wiki management dialog (720 wide, 90% height).
/// Five tabs: entries / entities / relationships / emotions / status, with
/// work-status visualization.
/// Supports viewing, editing, deleting and manually adding entries, marking
/// anchors, and an always-inject toggle.
/// Replaces the previous workaround of editing memory by instructing the AI
/// with bracketed text.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/models/chronicle.dart' as models;
import 'package:kirakira/data/repositories/chronicle_repository.dart';
import 'package:kirakira/presentation/providers/chat_providers.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/widgets/chronicle/chronicle_status_view.dart';
import 'package:uuid/uuid.dart';
import 'core_dialog.dart';

Future<void> showChronicleWikiDialog(BuildContext context, WidgetRef ref) {
  return showCoreDialog(
    context,
    barrierDismissible: false,
    builder: (_) => const _ChronicleWikiDialog(),
  );
}

enum _WikiTab { entries, entities, relationships, emotions, status }

class _ChronicleWikiDialog extends ConsumerStatefulWidget {
  const _ChronicleWikiDialog();

  @override
  ConsumerState<_ChronicleWikiDialog> createState() =>
      _ChronicleWikiDialogState();
}

class _ChronicleWikiDialogState extends ConsumerState<_ChronicleWikiDialog> {
  static const _uuid = Uuid();

  _WikiTab _tab = _WikiTab.entries;
  bool _loading = true;
  String? _chatId;

  List<models.MemoryEntry> _entries = [];
  List<models.MemoryEntity> _entities = [];
  List<models.MemoryRelationship> _relationships = [];
  List<models.EmotionNode> _emotions = [];
  Map<String, String> _entityNames = {};

  @override
  void initState() {
    super.initState();
    _chatId = ref.read(activeChatIdProvider);
    _reload();
  }

  Future<void> _reload() async {
    if (_chatId == null) {
      setState(() => _loading = false);
      return;
    }
    final repo = ref.read(chronicleRepositoryProvider);
    final entries = await repo.getAllEntries(_chatId!);
    final entities = await repo.getAllEntities(_chatId!);
    final relationships = await repo.getAllRelationships(_chatId!);
    final emotions = await repo.getAllEmotions(_chatId!);
    if (!mounted) return;
    setState(() {
      _entries = entries.reversed.toList(); // newest first
      _entities = entities;
      _relationships = relationships;
      _emotions = emotions;
      _entityNames = {for (final e in entities) e.id: e.name};
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CoreDialogPalette(isDark: isDark);

    return CoreDialogShell(
      title: 'Chronicle 记忆管理',
      icon: CupertinoIcons.book_fill,
      maxWidth: 720,
      maxHeightFactor: 0.9,
      disableScroll: true, // lists manage their own scrolling (Expanded needs bounded constraints)
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        minSize: 0,
        onPressed: _loading ? null : _reload,
        child: const Icon(
          CupertinoIcons.refresh,
          size: 20,
          color: DesignTokens.primary,
        ),
      ),
      body: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : _chatId == null
              ? CoreInfoRow(
                  icon: CupertinoIcons.chat_bubble,
                  title: '尚未打开聊天',
                  text: '请先进入一个聊天后再管理记忆词条。',
                  palette: palette,
                )
              : Column(
                  children: [
                    _buildSegment(palette),
                    const SizedBox(height: 12),
                    Expanded(child: _buildList(palette)),
                  ],
                ),
      footer: _tab == _WikiTab.status
          ? null // Status tab is read-only, no create button
          : CoreDialogFooter(
              child: CoreSecondaryButton(
                label: _newItemLabel,
                icon: CupertinoIcons.add,
                onPressed: _chatId == null ? null : _onAdd,
              ),
            ),
    );
  }

  String get _newItemLabel {
    switch (_tab) {
      case _WikiTab.entries:
        return '新建词条';
      case _WikiTab.entities:
        return '新建实体';
      case _WikiTab.relationships:
        return '新建关系';
      case _WikiTab.emotions:
        return '新建情感';
      case _WikiTab.status:
        return '';
    }
  }

  Widget _buildSegment(CoreDialogPalette palette) {
    return CupertinoSlidingSegmentedControl<_WikiTab>(
      backgroundColor: palette.fill,
      thumbColor: isDarkSegment ? const Color(0xFF484848) : Colors.white,
      groupValue: _tab,
      children: const {
        _WikiTab.entries: Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text('词条'),
        ),
        _WikiTab.entities: Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text('实体'),
        ),
        _WikiTab.relationships: Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text('关系'),
        ),
        _WikiTab.emotions: Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text('情感'),
        ),
        _WikiTab.status: Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text('状态'),
        ),
      },
      onValueChanged: (v) => setState(() => _tab = v!),
    );
  }

  bool get isDarkSegment =>
      Theme.of(context).brightness == Brightness.dark;

  Widget _buildList(CoreDialogPalette palette) {
    switch (_tab) {
      case _WikiTab.entries:
        if (_entries.isEmpty) return _buildEmpty('暂无词条，总结管线运行后自动生成', palette);
        return ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: _entries.length,
          itemBuilder: (_, i) => _buildEntryTile(_entries[i], palette),
        );
      case _WikiTab.entities:
        if (_entities.isEmpty) return _buildEmpty('暂无实体', palette);
        return ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: _entities.length,
          itemBuilder: (_, i) => _buildEntityTile(_entities[i], palette),
        );
      case _WikiTab.relationships:
        if (_relationships.isEmpty) return _buildEmpty('暂无关系', palette);
        return ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: _relationships.length,
          itemBuilder: (_, i) =>
              _buildRelationshipTile(_relationships[i], palette),
        );
      case _WikiTab.emotions:
        if (_emotions.isEmpty) return _buildEmpty('暂无情感节点', palette);
        return ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: _emotions.length,
          itemBuilder: (_, i) => _buildEmotionTile(_emotions[i], palette),
        );
      case _WikiTab.status:
        // Work-status visualization (five-zone display + progress bars)
        return ChronicleStatusView(chatId: _chatId!);
    }
  }

  Widget _buildEmpty(String text, CoreDialogPalette palette) {
    return Center(
      child: Text(text, style: TextStyle(fontSize: 14, color: palette.textSecondary)),
    );
  }

  // List items

  Widget _buildEntryTile(models.MemoryEntry e, CoreDialogPalette palette) {
    final badges = <Widget>[
      if (e.anchor)
        _badge('锚点', const Color(0xFFFFB300), palette),
      if (e.alwaysInject)
        _badge('始终注入', const Color(0xFF26A69A), palette),
      if (e.deprecated) _badge('已过时', const Color(0xFF9E9E9E), palette),
      _badge('重要度${e.importance}', _importanceColor(e.importance), palette),
    ];
    return CoreTile(
      title: e.title,
      subtitle: e.content,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: badges),
      onTap: () => _editEntry(e),
    );
  }

  Widget _buildEntityTile(models.MemoryEntity e, CoreDialogPalette palette) {
    return CoreTile(
      title: e.name,
      subtitle:
          '${e.type.name} · ${e.currentState.isNotEmpty ? e.currentState : e.description}',
      onTap: () => _editEntity(e),
    );
  }

  Widget _buildRelationshipTile(
      models.MemoryRelationship r, CoreDialogPalette palette) {
    final from = _entityNames[r.fromEntityId] ?? '？';
    final to = _entityNames[r.toEntityId] ?? '？';
    return CoreTile(
      title: '$from → $to（${r.relationType} ${r.strength}）',
      subtitle: r.description,
      onTap: () => _editRelationship(r),
    );
  }

  Widget _buildEmotionTile(models.EmotionNode e, CoreDialogPalette palette) {
    final name = _entityNames[e.entityId] ?? '？';
    return CoreTile(
      title: '$name · ${e.emotion}（强度${e.intensity}${e.isActive ? '' : '，已平复'}）',
      subtitle: e.trigger,
      onTap: () => _editEmotion(e),
    );
  }

  Widget _badge(String text, Color color, CoreDialogPalette palette) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Color _importanceColor(int importance) {
    if (importance >= 8) return const Color(0xFFF44336);
    if (importance >= 5) return const Color(0xFFFFA726);
    return const Color(0xFF8C8C8C);
  }

  // Editors

  void _onAdd() {
    switch (_tab) {
      case _WikiTab.entries:
        _editEntry(null);
      case _WikiTab.entities:
        _editEntity(null);
      case _WikiTab.relationships:
        _editRelationship(null);
      case _WikiTab.emotions:
        _editEmotion(null);
      case _WikiTab.status:
          break; // Status tab is read-only, nothing to create
    }
  }

  Future<void> _editEntry(models.MemoryEntry? existing) async {
    final now = DateTime.now();
    final entry = existing ??
        models.MemoryEntry(
          id: _uuid.v4(),
          chatId: _chatId!,
          title: '',
          content: '',
          createdAt: now,
          updatedAt: now,
        );

    final titleCtrl = TextEditingController(text: entry.title);
    final contentCtrl = TextEditingController(text: entry.content);
    final tagsCtrl = TextEditingController(text: entry.tags.join(', '));
    var importance = existing?.importance ?? 5;
    var alwaysInject = existing?.alwaysInject ?? false;
    var anchor = existing?.anchor ?? false;

    await showCoreDialog(
      context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => _EditorShell(
          title: existing == null ? '新建词条' : '编辑词条',
          onSave: () async {
            final repo = ref.read(chronicleRepositoryProvider);
            await repo.upsertMemoryEntry(entry.copyWith(
              title: titleCtrl.text.trim().isEmpty ? '未命名事件' : titleCtrl.text.trim(),
              content: contentCtrl.text.trim(),
              importance: importance,
              alwaysInject: alwaysInject,
              anchor: anchor,
              neverEvict: anchor,
              tags: tagsCtrl.text
                  .split(RegExp(r'[,，]'))
                  .map((t) => t.trim())
                  .where((t) => t.isNotEmpty)
                  .toList(),
              updatedAt: DateTime.now(),
            ));
          },
          onDelete: existing == null
              ? null
              : () => ref
                  .read(chronicleRepositoryProvider)
                  .deleteEntry(existing.id),
          children: [
            const CoreSectionLabel('标题'),
            const SizedBox(height: 6),
            CoreTextField(controller: titleCtrl, palette: _palette(ctx), hint: '简短标题'),
            const SizedBox(height: 12),
            const CoreSectionLabel('内容（50-120字精炼描述）'),
            const SizedBox(height: 6),
            CoreTextField(
              controller: contentCtrl,
              palette: _palette(ctx),
              maxLines: 5,
              minLines: 3,
            ),
            const SizedBox(height: 12),
            CoreSliderRow(
              label: '重要度',
              value: importance.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              display: '$importance',
              onChanged: (v) => setDialogState(() => importance = v.round()),
            ),
            CoreSwitchRow(
              title: '始终注入',
              subtitle: '固定层每次都注入',
              value: alwaysInject,
              onChanged: (v) => setDialogState(() => alwaysInject = v),
            ),
            CoreSwitchRow(
              title: '锚点',
              subtitle: '永久保留，永不丢弃',
              value: anchor,
              onChanged: (v) => setDialogState(() => anchor = v),
            ),
            const SizedBox(height: 12),
            const CoreSectionLabel('标签（逗号分隔，召回加权用）'),
            const SizedBox(height: 6),
            CoreTextField(controller: tagsCtrl, palette: _palette(ctx), hint: '如：承诺, 好感, 战斗'),
          ],
        ),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _editEntity(models.MemoryEntity? existing) async {
    final now = DateTime.now();
    final entity = existing ??
        models.MemoryEntity(
          id: _uuid.v4(),
          chatId: _chatId!,
          name: '',
          createdAt: now,
          updatedAt: now,
        );

    final nameCtrl = TextEditingController(text: entity.name);
    final descCtrl = TextEditingController(text: entity.description);
    final stateCtrl = TextEditingController(text: entity.currentState);

    await showCoreDialog(
      context,
      barrierDismissible: false,
      builder: (dialogCtx) => _EditorShell(
        title: existing == null ? '新建实体' : '编辑实体',
        onSave: () async {
          if (nameCtrl.text.trim().isEmpty) return;
          final repo = ref.read(chronicleRepositoryProvider);
          await repo.upsertEntity(entity.copyWith(
            name: nameCtrl.text.trim(),
            description: descCtrl.text.trim(),
            currentState: stateCtrl.text.trim(),
            updatedAt: DateTime.now(),
          ));
        },
        onDelete: existing == null
            ? null
            : () =>
                ref.read(chronicleRepositoryProvider).deleteEntity(existing.id),
        children: [
          const CoreSectionLabel('名称'),
          const SizedBox(height: 6),
          CoreTextField(controller: nameCtrl, palette: _palette(dialogCtx), hint: '如：艾拉'),
          const SizedBox(height: 12),
          const CoreSectionLabel('身份描述'),
          const SizedBox(height: 6),
          CoreTextField(controller: descCtrl, palette: _palette(dialogCtx), maxLines: 3),
          const SizedBox(height: 12),
          const CoreSectionLabel('当前状态'),
          const SizedBox(height: 6),
          CoreTextField(controller: stateCtrl, palette: _palette(dialogCtx), maxLines: 3),
        ],
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _editRelationship(models.MemoryRelationship? existing) async {
    if (_entities.length < 2) {
      coreToast(context, '需要至少两个实体才能建立关系');
      return;
    }
    final now = DateTime.now();
    final rel = existing ??
        models.MemoryRelationship(
          id: _uuid.v4(),
          chatId: _chatId!,
          fromEntityId: _entities.first.id,
          toEntityId: _entities[1].id,
          createdAt: now,
          updatedAt: now,
        );

    var fromId = rel.fromEntityId;
    var toId = rel.toEntityId;
    var strength = rel.strength;
    final typeCtrl = TextEditingController(text: rel.relationType);
    final descCtrl = TextEditingController(text: rel.description);

    await showCoreDialog(
      context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => _EditorShell(
          title: existing == null ? '新建关系' : '编辑关系',
          onSave: () async {
            final repo = ref.read(chronicleRepositoryProvider);
            await repo.upsertRelationship(
              _chatId!,
              models.UpsertRelationshipInstruction(
                relationType: typeCtrl.text.trim().isEmpty
                    ? 'trust'
                    : typeCtrl.text.trim(),
                strength: strength,
                description: descCtrl.text.trim(),
              ),
              fromEntityId: fromId,
              toEntityId: toId,
            );
          },
          onDelete: existing == null
              ? null
              : () => ref
                  .read(chronicleRepositoryProvider)
                  .deleteRelationship(existing.id),
          children: [
            const CoreSectionLabel('从实体'),
            _entityPicker(ctx, fromId, (v) => setDialogState(() => fromId = v)),
            const SizedBox(height: 10),
            const CoreSectionLabel('到实体'),
            _entityPicker(ctx, toId, (v) => setDialogState(() => toId = v)),
            const SizedBox(height: 12),
            CoreSliderRow(
              label: '强度（-100敌对 ~ +100亲密）',
              value: strength.toDouble(),
              min: -100,
              max: 100,
              divisions: 40,
              display: '$strength',
              onChanged: (v) => setDialogState(() => strength = v.round()),
            ),
            const SizedBox(height: 12),
            const CoreSectionLabel('类型（trust/friendship/romantic/hostile/family/mentor）'),
            const SizedBox(height: 6),
            CoreTextField(controller: typeCtrl, palette: _palette(ctx)),
            const SizedBox(height: 12),
            const CoreSectionLabel('描述'),
            const SizedBox(height: 6),
            CoreTextField(controller: descCtrl, palette: _palette(ctx), maxLines: 3),
          ],
        ),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _editEmotion(models.EmotionNode? existing) async {
    if (_entities.isEmpty) {
      coreToast(context, '需要至少一个实体才能记录情感');
      return;
    }
    final now = DateTime.now();
    final emo = existing ??
        models.EmotionNode(
          id: _uuid.v4(),
          chatId: _chatId!,
          entityId: _entities.first.id,
          createdAt: now,
          updatedAt: now,
        );

    var entityId = emo.entityId;
    var intensity = emo.intensity;
    var isActive = emo.isActive;
    final emotionCtrl = TextEditingController(text: emo.emotion);
    final triggerCtrl = TextEditingController(text: emo.trigger);

    await showCoreDialog(
      context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => _EditorShell(
          title: existing == null ? '新建情感' : '编辑情感',
          onSave: () async {
            final repo = ref.read(chronicleRepositoryProvider);
            await repo.upsertEmotion(
              _chatId!,
              models.UpsertEmotionInstruction(
                emotion: emotionCtrl.text.trim(),
                intensity: intensity,
                trigger: triggerCtrl.text.trim(),
                active: isActive,
              ),
              entityId: entityId,
            );
          },
          onDelete: existing == null
              ? null
              : () =>
                  ref.read(chronicleRepositoryProvider).deleteEmotion(existing.id),
          children: [
            const CoreSectionLabel('实体'),
            _entityPicker(ctx, entityId, (v) => setDialogState(() => entityId = v)),
            const SizedBox(height: 12),
            const CoreSectionLabel('情感类型（如 感激/愤怒/不安/期待）'),
            const SizedBox(height: 6),
            CoreTextField(controller: emotionCtrl, palette: _palette(ctx)),
            const SizedBox(height: 12),
            CoreSliderRow(
              label: '强度',
              value: intensity.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              display: '$intensity',
              onChanged: (v) => setDialogState(() => intensity = v.round()),
            ),
            CoreSwitchRow(
              title: '仍然活跃',
              subtitle: '关闭=已平复，不再注入固定层',
              value: isActive,
              onChanged: (v) => setDialogState(() => isActive = v),
            ),
            const SizedBox(height: 12),
            const CoreSectionLabel('触发原因'),
            const SizedBox(height: 6),
            CoreTextField(controller: triggerCtrl, palette: _palette(ctx), maxLines: 2),
          ],
        ),
      ),
    );
    if (mounted) _reload();
  }

  Widget _entityPicker(
      BuildContext ctx, String selectedId, ValueChanged<String> onChanged) {
    final palette = _palette(ctx);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: palette.fill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _entityNames.containsKey(selectedId)
              ? selectedId
              : (_entityNames.isEmpty ? null : _entityNames.keys.first),
          isExpanded: true,
          dropdownColor: palette.surface,
          items: _entityNames.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  CoreDialogPalette _palette(BuildContext ctx) {
    return CoreDialogPalette(
        isDark: Theme.of(ctx).brightness == Brightness.dark);
  }
}

/// Editor shell: title bar + form + footer (delete / save).
class _EditorShell extends StatelessWidget {
  const _EditorShell({
    required this.title,
    required this.children,
    required this.onSave,
    this.onDelete,
  });

  final String title;
  final List<Widget> children;
  final Future<void> Function() onSave;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    return CoreDialogShell(
      title: title,
      maxWidth: 550,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
      footer: CoreDialogFooter(
        child: Row(
          children: [
            if (onDelete != null) ...[
              CoreDangerButton(
                label: '删除',
                onPressed: () async {
                  await onDelete!();
                  if (context.mounted) Navigator.pop(context, true);
                },
                expanded: false,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: CorePrimaryButton(
                label: '保存',
                onPressed: () async {
                  await onSave();
                  if (context.mounted) Navigator.pop(context, true);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
