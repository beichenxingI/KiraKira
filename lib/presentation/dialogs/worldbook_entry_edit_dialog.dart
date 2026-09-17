import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/world_info.dart';
import '../components/kira_accordion_card.dart';
import '../components/kira_dialog_theme.dart';
import '../components/kira_dialog_widgets.dart';
import '../components/kira_input_dialog.dart';
import '../components/kira_toast.dart';
import '../providers/world_info_providers.dart';
import '../theme/design_tokens.dart';

/// 世界书条目完整编辑浮窗
/// [entry] 非空 = 编辑；[worldInfoId] 非空 = 新增
Future<void> showWorldBookEntryEditDialog(
  BuildContext context,
  WidgetRef ref, {
  WorldInfoEntry? entry,
  String? worldInfoId,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => _WorldBookEntryEditDialog(entry: entry, worldInfoId: worldInfoId),
  );
}

class _WorldBookEntryEditDialog extends ConsumerStatefulWidget {
  final WorldInfoEntry? entry;
  final String? worldInfoId;
  const _WorldBookEntryEditDialog({this.entry, this.worldInfoId});
  @override
  ConsumerState<_WorldBookEntryEditDialog> createState() =>
      _WorldBookEntryEditDialogState();
}

class _WorldBookEntryEditDialogState
    extends ConsumerState<_WorldBookEntryEditDialog> {
  late final TextEditingController _commentCtrl;
  late final TextEditingController _contentCtrl;
  late final TextEditingController _groupCtrl;
  List<String> _keys = [];
  List<String> _secondaryKeys = [];

  bool _enabled = true;
  bool _constant = false;
  bool _selective = false;
  bool _caseSensitive = false;
  bool _matchWholeWords = false;
  bool _useProbability = false;
  bool _useGroupScoring = false;
  bool _preventRecursion = false;
  bool _excludeRecursion = false;

  int _scanDepth = 0;
  int _probability = 100;
  int _insertionOrder = 100;
  int _depth = 4;
  int _groupWeight = 100;
  int _groupOverride = 0;
  int _sticky = 0;
  int _cooldown = 0;
  int _delay = 0;

  WorldInfoPosition _position = WorldInfoPosition.before;
  WorldInfoRole _role = WorldInfoRole.system;

  bool get _isEdit => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _commentCtrl = TextEditingController(text: e?.comment ?? '');
    _contentCtrl = TextEditingController(text: e?.content ?? '');
    _groupCtrl = TextEditingController(text: e?.group ?? '');
    _keys = List.from(e?.keys ?? []);
    _secondaryKeys = List.from(e?.secondaryKeys ?? []);
    _enabled = e?.enabled ?? true;
    _constant = e?.constant ?? false;
    _selective = e?.selective ?? false;
    _caseSensitive = e?.caseSensitive ?? false;
    _matchWholeWords = e?.matchWholeWords ?? false;
    _useProbability = e?.useProbability ?? false;
    _useGroupScoring = e?.useGroupScoring ?? false;
    _preventRecursion = e?.preventRecursion ?? false;
    _excludeRecursion = e?.excludeRecursion ?? false;
    _scanDepth = e?.scanDepth ?? 0;
    _probability = e?.probability ?? 100;
    _insertionOrder = e?.insertionOrder ?? 100;
    _depth = e?.depth ?? 4;
    _groupWeight = e?.groupWeight ?? 100;
    _groupOverride = e?.groupOverride ?? 0;
    _sticky = e?.timedEffects.sticky ?? 0;
    _cooldown = e?.timedEffects.cooldown ?? 0;
    _delay = e?.timedEffects.delay ?? 0;
    _position = e?.position ?? WorldInfoPosition.before;
    _role = e?.role ?? WorldInfoRole.system;
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _contentCtrl.dispose();
    _groupCtrl.dispose();
    super.dispose();
  }

  WorldInfoEntry _buildEntry() {
    final base = widget.entry;
    return (base ?? WorldInfoEntry(
      id: '',
      worldInfoId: widget.worldInfoId ?? '',
    )).copyWith(
      keys: _keys,
      secondaryKeys: _secondaryKeys,
      content: _contentCtrl.text,
      comment: _commentCtrl.text,
      enabled: _enabled,
      constant: _constant,
      selective: _selective,
      caseSensitive: _caseSensitive,
      matchWholeWords: _matchWholeWords,
      useProbability: _useProbability,
      probability: _probability,
      useGroupScoring: _useGroupScoring,
      preventRecursion: _preventRecursion,
      excludeRecursion: _excludeRecursion,
      scanDepth: _scanDepth,
      insertionOrder: _insertionOrder,
      depth: _depth,
      group: _groupCtrl.text.trim().isEmpty ? null : _groupCtrl.text.trim(),
      groupWeight: _groupWeight,
      groupOverride: _groupOverride,
      position: _position,
      role: _role,
      timedEffects: (base?.timedEffects ?? const WorldInfoTimedEffects())
          .copyWith(sticky: _sticky, cooldown: _cooldown, delay: _delay),
    );
  }

  Future<void> _save() async {
    if (_keys.isEmpty && !_constant) {
      KiraToast.show(context, '非常量条目至少需要一个关键词', type: KiraToastType.warning);
      return;
    }
    final notifier = ref.read(worldInfoNotifierProvider.notifier);
    try {
      if (_isEdit) {
        await notifier.updateEntry(_buildEntry());
      } else {
        // 新增：先 addEntry 拿到带 id 的条目，再 updateEntry 补全全部字段
        final created = await notifier.addEntry(
          worldInfoId: widget.worldInfoId!,
          keys: _keys,
          content: _contentCtrl.text,
        );
        await notifier.updateEntry(_buildEntry().copyWith(
          id: created.id,
          worldInfoId: created.worldInfoId,
        ));
      }
      ref.invalidate(characterWorldInfosProvider);
      if (mounted) {
        KiraToast.show(context, _isEdit ? '条目已保存' : '条目已添加',
            type: KiraToastType.success);
        Navigator.of(context, rootNavigator: true).pop();
      }
    } catch (e) {
      if (mounted) {
        KiraToast.show(context, '保存失败: $e', type: KiraToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final titleColor = Theme.of(context).textTheme.bodyLarge?.color;
    final labelColor = Theme.of(context).textTheme.bodyMedium?.color;

    OutlineInputBorder border() => OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          borderSide: BorderSide(
            color: const Color(0xFF7B5EA7).withValues(alpha: 0.3),
          ),
        );

    InputDecoration dec(String hint) => InputDecoration(
          hintText: hint,
          isDense: true,
          filled: true,
          fillColor: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: border(),
          enabledBorder: border(),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
            borderSide: const BorderSide(
                color: KiraDialogTheme.primary, width: 1.5),
          ),
        );

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: screenW - 32 < 600 ? screenW - 32 : 600,
          constraints: BoxConstraints(maxHeight: screenH * 0.9),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1B2E) : const Color(0xFFF4F3FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF7B5EA7).withValues(alpha: 0.25),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: const Color(0xFF7B5EA7).withValues(alpha: 0.15),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEdit ? '编辑条目' : '添加条目',
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeHeadline,
                          fontWeight: DesignTokens.weightBold,
                          color: titleColor,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close,
                          size: 20,
                          color: labelColor?.withValues(alpha: 0.6)),
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: true).pop(),
                    ),
                  ],
                ),
              ),
              // Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 基础信息 ──
                      Text('备注',
                          style: _labelStyle(labelColor)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _commentCtrl,
                        cursorColor: KiraDialogTheme.primary,
                        style: _inputStyle(titleColor),
                        decoration: dec('备注名称（可选）'),
                      ),
                      const SizedBox(height: 8),
                      _SwitchRow(
                        label: '启用',
                        value: _enabled,
                        onChanged: (v) => setState(() => _enabled = v),
                      ),
                      _SwitchRow(
                        label: '常量模式',
                        hint: '始终插入，无需关键词触发',
                        value: _constant,
                        onChanged: (v) => setState(() => _constant = v),
                      ),
                      const SizedBox(height: 12),
                      // ── 触发条件 ──
                      KiraAccordionCard(
                        title: '触发条件',
                        preview: _keys.isEmpty ? '无关键词' : _keys.join(', '),
                        icon: Icons.flash_on_outlined,
                        accentColor: KiraDialogTheme.opening,
                        isExpanded: _openSection == 'trigger',
                        onExpansionChanged: (v) =>
                            _toggleSection('trigger', v),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ChipsInput(
                              label: '主关键词（任一匹配即触发）',
                              chips: _keys,
                              accent: KiraDialogTheme.opening,
                              onChanged: (v) =>
                                  setState(() => _keys = v),
                              context: context,
                            ),
                            const SizedBox(height: 12),
                            _ChipsInput(
                              label: '二次关键词',
                              chips: _secondaryKeys,
                              accent: KiraDialogTheme.alternate,
                              onChanged: (v) =>
                                  setState(() => _secondaryKeys = v),
                              context: context,
                            ),
                            const SizedBox(height: 8),
                            _SwitchRow(
                              label: '启用二次筛选',
                              value: _selective,
                              onChanged: (v) =>
                                  setState(() => _selective = v),
                            ),
                            _SwitchRow(
                              label: '大小写敏感',
                              value: _caseSensitive,
                              onChanged: (v) =>
                                  setState(() => _caseSensitive = v),
                            ),
                            _SwitchRow(
                              label: '全词匹配',
                              value: _matchWholeWords,
                              onChanged: (v) =>
                                  setState(() => _matchWholeWords = v),
                            ),
                            const SizedBox(height: 8),
                            _NumberField(
                              label: '扫描深度（0=全局）',
                              value: _scanDepth,
                              max: 100,
                              onChanged: (v) =>
                                  setState(() => _scanDepth = v),
                            ),
                            const SizedBox(height: 8),
                            Text('触发概率',
                                style: _labelStyle(labelColor)),
                            Row(
                              children: [
                                Expanded(
                                  child: Slider(
                                    value: _probability.toDouble(),
                                    min: 0,
                                    max: 100,
                                    activeColor: KiraDialogTheme.primary,
                                    onChanged: (v) => setState(() =>
                                        _probability = v.round()),
                                  ),
                                ),
                                SizedBox(
                                  width: 48,
                                  child: Text('$_probability%',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize:
                                              DesignTokens.fontSizeSm,
                                          color: titleColor)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // ── 内容 ──
                      KiraAccordionCard(
                        title: '内容',
                        preview: _contentCtrl.text.isEmpty
                            ? '无内容'
                            : _contentCtrl.text,
                        icon: Icons.article_outlined,
                        accentColor: KiraDialogTheme.description,
                        isExpanded: _openSection == 'content',
                        onExpansionChanged: (v) =>
                            _toggleSection('content', v),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            KiraEditTrigger(
                              value: _contentCtrl.text,
                              placeholder: '点击输入条目内容...',
                              isDark: isDark,
                              accentColor: KiraDialogTheme.description,
                              onTap: () async {
                                final v = await showKiraInputDialog(
                                  context,
                                  title: '编辑条目内容',
                                  initialValue: _contentCtrl.text,
                                  multiline: true,
                                  maxLength: 5000,
                                  placeholder: '条目内容...',
                                );
                                if (v != null) {
                                  setState(() {
                                    _contentCtrl.text = v;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 8),
                            Text('内容角色',
                                style: _labelStyle(labelColor)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              children: WorldInfoRole.values
                                  .map((r) => _ChoiceChip(
                                        label: _roleLabel(r),
                                        selected: _role == r,
                                        onTap: () =>
                                            setState(() => _role = r),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // ── 插入控制 ──
                      KiraAccordionCard(
                        title: '插入控制',
                        preview: _positionLabel(_position),
                        icon: Icons.low_priority,
                        accentColor: KiraDialogTheme.worldbook,
                        isExpanded: _openSection == 'insert',
                        onExpansionChanged: (v) =>
                            _toggleSection('insert', v),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _NumberField(
                              label: '插入顺序（越小越靠前）',
                              value: _insertionOrder,
                              max: 999,
                              onChanged: (v) => setState(() =>
                                  _insertionOrder = v),
                            ),
                            const SizedBox(height: 8),
                            Text('插入位置',
                                style: _labelStyle(labelColor)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: WorldInfoPosition.values
                                  .where((p) => p !=
                                      WorldInfoPosition.outlet)
                                  .map((p) => _ChoiceChip(
                                        label: _positionLabel(p),
                                        selected: _position == p,
                                        onTap: () =>
                                            setState(() => _position = p),
                                      ))
                                  .toList(),
                            ),
                            const SizedBox(height: 8),
                            _NumberField(
                              label: '插入深度',
                              value: _depth,
                              max: 100,
                              onChanged: (v) =>
                                  setState(() => _depth = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // ── 高级设置 ──
                      KiraAccordionCard(
                        title: '高级设置',
                        preview: '分组/粘性/冷却/延迟',
                        icon: Icons.tune,
                        accentColor: KiraDialogTheme.regex,
                        defaultExpanded: false,
                        isExpanded: _openSection == 'advanced',
                        onExpansionChanged: (v) =>
                            _toggleSection('advanced', v),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SwitchRow(
                              label: '使用组合评分',
                              value: _useGroupScoring,
                              onChanged: (v) => setState(
                                  () => _useGroupScoring = v),
                            ),
                            _SwitchRow(
                              label: '阻止递归扫描',
                              value: _preventRecursion,
                              onChanged: (v) => setState(
                                  () => _preventRecursion = v),
                            ),
                            _SwitchRow(
                              label: '排除递归',
                              value: _excludeRecursion,
                              onChanged: (v) => setState(
                                  () => _excludeRecursion = v),
                            ),
                            const SizedBox(height: 8),
                            Text('分组名称',
                                style: _labelStyle(labelColor)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _groupCtrl,
                              cursorColor: KiraDialogTheme.primary,
                              style: _inputStyle(titleColor),
                              decoration: dec('分组（可选）'),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _NumberField(
                                    label: '组权重',
                                    value: _groupWeight,
                                    max: 999,
                                    onChanged: (v) => setState(
                                        () => _groupWeight = v),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _NumberField(
                                    label: '组优先级',
                                    value: _groupOverride,
                                    max: 999,
                                    onChanged: (v) => setState(
                                        () => _groupOverride = v),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _NumberField(
                                    label: '粘性轮数',
                                    value: _sticky,
                                    max: 999,
                                    onChanged: (v) => setState(
                                        () => _sticky = v),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _NumberField(
                                    label: '冷却轮数',
                                    value: _cooldown,
                                    max: 999,
                                    onChanged: (v) => setState(
                                        () => _cooldown = v),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _NumberField(
                                    label: '延迟轮数',
                                    value: _delay,
                                    max: 999,
                                    onChanged: (v) => setState(
                                        () => _delay = v),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color:
                          const Color(0xFF7B5EA7).withValues(alpha: 0.15),
                    ),
                  ),
                ),
                child: KiraDialogActions(
                  confirmText: _isEdit ? '保存' : '添加',
                  onCancel: () =>
                      Navigator.of(context, rootNavigator: true).pop(),
                  onConfirm: _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── helpers ──
  String? _openSection;
  void _toggleSection(String key, bool open) {
    setState(() => _openSection = open ? key : null);
  }

  TextStyle _labelStyle(Color? c) => TextStyle(
      fontSize: DesignTokens.fontSizeSm, color: c?.withValues(alpha: 0.7));
  TextStyle _inputStyle(Color? c) => TextStyle(
      fontSize: DesignTokens.fontSizeBodyMedium, color: c);

  String _positionLabel(WorldInfoPosition p) => switch (p) {
        WorldInfoPosition.before => '对话前',
        WorldInfoPosition.after => '对话后',
        WorldInfoPosition.ANTop => '注释前',
        WorldInfoPosition.ANBottom => '注释后',
        WorldInfoPosition.atDepth => '指定深度',
        WorldInfoPosition.EMTop => '示例前',
        WorldInfoPosition.EMBottom => '示例后',
        WorldInfoPosition.outlet => '出口',
      };

  String _roleLabel(WorldInfoRole r) => switch (r) {
        WorldInfoRole.system => '系统',
        WorldInfoRole.user => '用户',
        WorldInfoRole.assistant => '助手',
      };
}

// ── 辅助组件 ──

class _SwitchRow extends StatelessWidget {
  final String label;
  final String? hint;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({
    required this.label,
    this.hint,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: DesignTokens.fontSizeSm,
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color)),
                if (hint != null)
                  Text(hint!,
                      style: TextStyle(
                          fontSize: DesignTokens.fontSizeXs,
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color
                              ?.withValues(alpha: 0.5))),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: KiraDialogTheme.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;
  const _NumberField({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: DesignTokens.fontSizeSm,
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withValues(alpha: 0.7))),
        const SizedBox(height: 4),
        SizedBox(
          width: 120,
          child: TextField(
            controller: TextEditingController(text: value.toString()),
            keyboardType: TextInputType.number,
            cursorColor: KiraDialogTheme.primary,
            style: TextStyle(
                fontSize: DesignTokens.fontSizeBodyMedium,
                color: Theme.of(context).textTheme.bodyLarge?.color),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(DesignTokens.radiusMd),
                borderSide: BorderSide(
                    color: const Color(0xFF7B5EA7)
                        .withValues(alpha: 0.3)),
              ),
            ),
            onChanged: (v) {
              final n = int.tryParse(v.trim());
              if (n != null) {
                onChanged(n.clamp(0, max));
              }
            },
          ),
        ),
      ],
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? KiraDialogTheme.primary.withValues(alpha: 0.2)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
          border: Border.all(
            color: selected
                ? KiraDialogTheme.primary
                : const Color(0xFF7B5EA7).withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: DesignTokens.fontSizeXs,
            fontWeight: selected
                ? DesignTokens.weightSemibold
                : DesignTokens.weightMedium,
            color: selected
                ? KiraDialogTheme.primary
                : Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ),
    );
  }
}

class _ChipsInput extends StatelessWidget {
  final String label;
  final List<String> chips;
  final Color accent;
  final ValueChanged<List<String>> onChanged;
  final BuildContext context;
  const _ChipsInput({
    required this.label,
    required this.chips,
    required this.accent,
    required this.onChanged,
    required this.context,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: DesignTokens.fontSizeSm,
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withValues(alpha: 0.7))),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (int i = 0; i < chips.length; i++)
              KiraTagChip(
                label: chips[i],
                color: accent,
                onRemove: () {
                  final newList = List<String>.from(chips)..removeAt(i);
                  onChanged(newList);
                },
              ),
            GestureDetector(
              onTap: () async {
                final v = await showKiraInputDialog(this.context,
                    title: '添加关键词', placeholder: '输入关键词');
                if (v == null || v.trim().isEmpty) return;
                final t = v.trim();
                if (chips.contains(t)) {
                  KiraToast.show(this.context, '关键词已存在',
                      type: KiraToastType.warning);
                  return;
                }
                onChanged([...chips, t]);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: accent.withValues(alpha: 0.4), width: 1.5),
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusChip),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 14, color: accent),
                    const SizedBox(width: 4),
                    Text('添加',
                        style: TextStyle(
                            color: accent,
                            fontSize: DesignTokens.fontSizeSm,
                            fontWeight: DesignTokens.weightMedium)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
