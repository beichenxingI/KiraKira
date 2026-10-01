import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/regex_script.dart';
import '../components/kira_accordion_card.dart';
import '../components/kira_dialog_theme.dart';
import '../components/kira_dialog_widgets.dart';
import '../components/kira_input_dialog.dart';
import '../components/kira_toast.dart';
import '../providers/regex_providers.dart';
import '../theme/design_tokens.dart';

/// Full regex rule editor dialog (match rules + application scope + test area).
Future<void> showRegexRuleEditDialog(
  BuildContext context,
  WidgetRef ref, {
  required RegexScript script,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => _RegexRuleEditDialog(script: script),
  );
}

class _RegexRuleEditDialog extends ConsumerStatefulWidget {
  final RegexScript script;
  const _RegexRuleEditDialog({required this.script});
  @override
  ConsumerState<_RegexRuleEditDialog> createState() =>
      _RegexRuleEditDialogState();
}

class _RegexRuleEditDialogState extends ConsumerState<_RegexRuleEditDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _findCtrl;
  late final TextEditingController _replaceCtrl;
  late final TextEditingController _testInputCtrl;
  String _testResult = '';
  List<String> _trimStrings = [];
  List<RegexPlacement> _placements = [];
  bool _enabled = true;
  bool _markdownOnly = false;
  bool _promptOnly = false;
  bool _runOnEdit = false;
  String? _openSection;

  @override
  void initState() {
    super.initState();
    final s = widget.script;
    _nameCtrl = TextEditingController(text: s.scriptName);
    _findCtrl = TextEditingController(text: s.findRegex);
    _replaceCtrl = TextEditingController(text: s.replaceString);
    _testInputCtrl = TextEditingController();
    _trimStrings = List.from(s.trimStrings);
    _placements = List.from(s.placement);
    _enabled = !s.disabled;
    _markdownOnly = s.markdownOnly;
    _promptOnly = s.promptOnly;
    _runOnEdit = s.runOnEdit;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _findCtrl.dispose();
    _replaceCtrl.dispose();
    _testInputCtrl.dispose();
    super.dispose();
  }

  void _toggleSection(String key, bool open) {
    setState(() => _openSection = open ? key : null);
  }

  void _togglePlacement(RegexPlacement p) {
    setState(() {
      if (_placements.contains(p)) {
        _placements.remove(p);
      } else {
        _placements.add(p);
      }
    });
  }

  void _runTest() {
    final find = _findCtrl.text;
    final replace = _replaceCtrl.text;
    final input = _testInputCtrl.text;
    if (find.isEmpty) {
      setState(() => _testResult = '请先输入查找正则表达式');
      return;
    }
    try {
      final regex = RegExp(find);
      final result = input.replaceAllMapped(regex, (match) {
        var r = replace;
        for (int i = 0; i <= match.groupCount; i++) {
          r = r.replaceAll('\$$i', match.group(i) ?? '');
        }
        return r;
      });
      setState(() => _testResult = result);
    } catch (e) {
      setState(() => _testResult = '正则表达式错误: $e');
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      KiraToast.show(context, '规则名不能为空', type: KiraToastType.warning);
      return;
    }
    if (_findCtrl.text.trim().isEmpty) {
      KiraToast.show(context, '查找表达式不能为空', type: KiraToastType.warning);
      return;
    }
    final cid = widget.script.characterId;
    if (cid == null) {
      KiraToast.show(context, '规则未绑定角色，无法保存', type: KiraToastType.error);
      return;
    }
    try {
      final notifier = ref.read(characterRegexScriptsProvider(cid).notifier);
      await notifier.updateScript(widget.script.copyWith(
        scriptName: _nameCtrl.text.trim(),
        findRegex: _findCtrl.text,
        replaceString: _replaceCtrl.text,
        trimStrings: _trimStrings,
        placement: _placements,
        disabled: !_enabled,
        markdownOnly: _markdownOnly,
        promptOnly: _promptOnly,
        runOnEdit: _runOnEdit,
        updatedAt: DateTime.now(),
      ));
      if (mounted) {
        KiraToast.show(context, '规则已保存', type: KiraToastType.success);
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
                      color:
                          const Color(0xFF7B5EA7).withValues(alpha: 0.15),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('编辑正则规则',
                          style: TextStyle(
                            fontSize: DesignTokens.fontSizeHeadline,
                            fontWeight: DesignTokens.weightBold,
                            color: titleColor,
                          )),
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
                      // Basic info
                      Text('规则名',
                          style: TextStyle(
                              fontSize: DesignTokens.fontSizeSm,
                              color: labelColor?.withValues(alpha: 0.7))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _nameCtrl,
                        cursorColor: KiraDialogTheme.primary,
                        style: TextStyle(
                            fontSize: DesignTokens.fontSizeBodyMedium,
                            color: titleColor),
                        decoration: dec('规则名称（必填）'),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('启用',
                                  style: TextStyle(
                                      fontSize: DesignTokens.fontSizeSm,
                                      color: labelColor)),
                            ),
                            Switch(
                              value: _enabled,
                              activeColor: KiraDialogTheme.primary,
                              onChanged: (v) =>
                                  setState(() => _enabled = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Match rules
                      KiraAccordionCard(
                        title: '匹配规则',
                        preview: _findCtrl.text.isEmpty
                            ? '未设置'
                            : _findCtrl.text,
                        icon: Icons.code,
                        accentColor: KiraDialogTheme.regex,
                        isExpanded: _openSection == 'match',
                        onExpansionChanged: (v) =>
                            _toggleSection('match', v),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('查找正则表达式',
                                style: TextStyle(
                                    fontSize: DesignTokens.fontSizeSm,
                                    color: labelColor
                                        ?.withValues(alpha: 0.7))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _findCtrl,
                              cursorColor: KiraDialogTheme.primary,
                              style: TextStyle(
                                  fontSize: DesignTokens.fontSizeSm,
                                  fontFamily: 'monospace',
                                  color: titleColor),
                              decoration: dec('正则表达式（必填）'),
                            ),
                            const SizedBox(height: 12),
                            Text('替换内容',
                                style: TextStyle(
                                    fontSize: DesignTokens.fontSizeSm,
                                    color: labelColor
                                        ?.withValues(alpha: 0.7))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _replaceCtrl,
                              maxLines: 4,
                              minLines: 2,
                              cursorColor: KiraDialogTheme.primary,
                              style: TextStyle(
                                  fontSize: DesignTokens.fontSizeSm,
                                  fontFamily: 'monospace',
                                  color: titleColor),
                              decoration: dec('替换为（支持 \$1 捕获组）'),
                            ),
                            const SizedBox(height: 12),
                            Text('去除字符串',
                                style: TextStyle(
                                    fontSize: DesignTokens.fontSizeSm,
                                    color: labelColor
                                        ?.withValues(alpha: 0.7))),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                for (int i = 0;
                                    i < _trimStrings.length;
                                    i++)
                                  KiraTagChip(
                                    label: _trimStrings[i],
                                    color: KiraDialogTheme.regex,
                                    onRemove: () => setState(() =>
                                        _trimStrings.removeAt(i)),
                                  ),
                                GestureDetector(
                                  onTap: () async {
                                    final v = await showKiraInputDialog(
                                      context,
                                      title: '添加去除字符串',
                                      placeholder: '输入字符串',
                                    );
                                    if (v == null ||
                                        v.trim().isEmpty) {
                                      return;
                                    }
                                    setState(() =>
                                        _trimStrings.add(v.trim()));
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: KiraDialogTheme.regex
                                              .withValues(alpha: 0.4),
                                          width: 1.5),
                                      borderRadius: BorderRadius.circular(
                                          DesignTokens.radiusChip),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.add,
                                            size: 14,
                                            color:
                                                KiraDialogTheme.regex),
                                        SizedBox(width: 4),
                                        Text('添加',
                                            style: TextStyle(
                                                color:
                                                    KiraDialogTheme.regex,
                                                fontSize:
                                                    DesignTokens
                                                        .fontSizeSm,
                                                fontWeight: DesignTokens
                                                    .weightMedium)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Application scope
                      KiraAccordionCard(
                        title: '应用范围',
                        preview: '${_placements.length} 个位置',
                        icon: Icons.place_outlined,
                        accentColor: KiraDialogTheme.opening,
                        isExpanded: _openSection == 'scope',
                        onExpansionChanged: (v) =>
                            _toggleSection('scope', v),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('应用位置（可多选）',
                                style: TextStyle(
                                    fontSize: DesignTokens.fontSizeSm,
                                    color: labelColor
                                        ?.withValues(alpha: 0.7))),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: RegexPlacement.values
                                  .map((p) => _PlacementChip(
                                        label: _placementLabel(p),
                                        selected:
                                            _placements.contains(p),
                                        onTap: () =>
                                            _togglePlacement(p),
                                      ))
                                  .toList(),
                            ),
                            const SizedBox(height: 8),
                            _SwitchRow(
                                label: '仅 Markdown 渲染时执行',
                                value: _markdownOnly,
                                onChanged: (v) => setState(
                                    () => _markdownOnly = v)),
                            _SwitchRow(
                                label: '仅发送给模型前执行',
                                value: _promptOnly,
                                onChanged: (v) => setState(
                                    () => _promptOnly = v)),
                            _SwitchRow(
                                label: '编辑消息时也执行',
                                value: _runOnEdit,
                                onChanged: (v) => setState(
                                    () => _runOnEdit = v)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Test area
                      KiraAccordionCard(
                        title: '测试',
                        preview: '实时预览替换结果',
                        icon: Icons.science_outlined,
                        accentColor: KiraDialogTheme.alternate,
                        defaultExpanded: false,
                        isExpanded: _openSection == 'test',
                        onExpansionChanged: (v) =>
                            _toggleSection('test', v),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('测试输入',
                                style: TextStyle(
                                    fontSize: DesignTokens.fontSizeSm,
                                    color: labelColor
                                        ?.withValues(alpha: 0.7))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _testInputCtrl,
                              maxLines: 4,
                              minLines: 2,
                              cursorColor: KiraDialogTheme.primary,
                              style: TextStyle(
                                  fontSize: DesignTokens.fontSizeSm,
                                  color: titleColor),
                              decoration: dec('输入测试文本...'),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(
                                      DesignTokens.radiusMd),
                                  onTap: _runTest,
                                  child: Container(
                                    height: 40,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF6C5CE7),
                                          Color(0xFFA855F7),
                                        ],
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(
                                              DesignTokens.radiusMd),
                                    ),
                                    child: const Text('执行测试',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize:
                                                DesignTokens.fontSizeSm,
                                            fontWeight: DesignTokens
                                                .weightSemibold)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('测试结果',
                                style: TextStyle(
                                    fontSize: DesignTokens.fontSizeSm,
                                    color: labelColor
                                        ?.withValues(alpha: 0.7))),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              constraints:
                                  const BoxConstraints(minHeight: 60),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white
                                        .withValues(alpha: 0.05)
                                    : Colors.black
                                        .withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(
                                    DesignTokens.radiusMd),
                                border: Border.all(
                                  color: const Color(0xFF7B5EA7)
                                      .withValues(alpha: 0.2),
                                ),
                              ),
                              child: SingleChildScrollView(
                                child: Text(
                                  _testResult.isEmpty
                                      ? '点击"执行测试"查看结果'
                                      : _testResult,
                                  style: TextStyle(
                                    fontSize: DesignTokens.fontSizeSm,
                                    fontFamily: 'monospace',
                                    color: _testResult
                                            .startsWith('正则表达式错误')
                                        ? Colors.red
                                        : titleColor,
                                  ),
                                ),
                              ),
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
                  confirmText: '保存',
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

  String _placementLabel(RegexPlacement p) => switch (p) {
        RegexPlacement.userInput => '用户输入',
        RegexPlacement.aiOutput => 'AI响应',
        RegexPlacement.slashCommand => '斜杠命令',
        RegexPlacement.worldInfo => '世界书内容',
        RegexPlacement.reasoning => '推理块',
      };
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({
    required this.label,
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
            child: Text(label,
                style: TextStyle(
                    fontSize: DesignTokens.fontSizeSm,
                    color:
                        Theme.of(context).textTheme.bodyMedium?.color)),
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

class _PlacementChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PlacementChip({
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected)
              const Icon(Icons.check, size: 14, color: KiraDialogTheme.primary),
            if (selected) const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeXs,
                  fontWeight: selected
                      ? DesignTokens.weightSemibold
                      : DesignTokens.weightMedium,
                  color: selected
                      ? KiraDialogTheme.primary
                      : Theme.of(context).textTheme.bodyMedium?.color,
                )),
          ],
        ),
      ),
    );
  }
}
