import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/models/regex_script.dart';
import 'package:kirakira/presentation/providers/regex_providers.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/widgets/common/common.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';

/// 脚本编辑页(Block D 批2):原 RegexScriptEditor 底部 Sheet 的 push 子页形态
/// (Sheet 内含大表单,改为整页表单;角色编辑页仍用原 Sheet,本页只服务设置页)
/// 保存语义与原 Sheet 完全一致:
/// - 校验:名称/查找模式必填(提示 '名称和模式为必填',不推进)
/// - 新建 → addScript;编辑 → updateScript(保留 id/order/createdAt)
/// - 完成后 pop
class RegexScriptEditScreen extends ConsumerStatefulWidget {
  final RegexScript? script;

  const RegexScriptEditScreen({super.key, this.script});

  @override
  ConsumerState<RegexScriptEditScreen> createState() =>
      _RegexScriptEditScreenState();
}

class _RegexScriptEditScreenState extends ConsumerState<RegexScriptEditScreen> {
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
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.script?.scriptName ?? '');
    _descriptionController = TextEditingController(text: widget.script?.description ?? '');
    _findController = TextEditingController(text: widget.script?.findRegex ?? '');
    _replaceController = TextEditingController(text: widget.script?.replaceString ?? '');
    _minDepthController = TextEditingController(
      text: widget.script?.minDepth != null && widget.script!.minDepth! >= 0
          ? widget.script!.minDepth.toString()
          : '',
    );
    _maxDepthController = TextEditingController(
      text: widget.script?.maxDepth != null && widget.script!.maxDepth! >= 0
          ? widget.script!.maxDepth.toString()
          : '',
    );
    _trimInputController = TextEditingController();
    _placement = widget.script?.placement ?? [RegexPlacement.aiOutput];
    _trimStrings = List<String>.from(widget.script?.trimStrings ?? []);
    _markdownOnly = widget.script?.markdownOnly ?? false;
    _promptOnly = widget.script?.promptOnly ?? false;
    _runOnEdit = widget.script?.runOnEdit ?? false;
    _substituteRegex = widget.script?.substituteRegex ?? SubstituteRegex.none;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _findController.dispose();
    _replaceController.dispose();
    _minDepthController.dispose();
    _maxDepthController.dispose();
    _trimInputController.dispose();
    super.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('名称和模式为必填')),
      );
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
      description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
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
    final base = widget.script;
    if (base != null) {
      notifier.updateScript(script.copyWith(
        id: base.id,
        order: base.order,
        createdAt: base.createdAt,
      ));
    } else {
      notifier.addScript(script);
    }
    Navigator.pop(context);
  }

  /// 宏替换模式选择 → CupertinoActionSheet(选项数组一字不动:SubstituteRegex.values)
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 编辑/表单深页:pinned 常规标题,保存按钮放右上角(施工模板②)
          SliverAppBar(
            pinned: true,
            title: Text(widget.script == null ? l10n.newScript : l10n.editScript),
            actions: [
              TextButton(
                onPressed: _save,
                child: Text(
                  l10n.save,
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
              ),
            ],
          ),

          // ── 名称/描述 ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: KiraSection(
              title: '',
              children: [
                _borderlessField(
                  controller: _nameController,
                  placeholder: '脚本名称',
                ),
                _borderlessField(
                  controller: _descriptionController,
                  placeholder: '描述（可选）',
                ),
              ],
            ),
          ),

          // ── 查找/替换 ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: KiraSection(
              title: '',
              children: [
                _borderlessField(
                  controller: _findController,
                  placeholder: '查找模式 Find Regex',
                  monospace: true,
                ),
                _borderlessField(
                  controller: _replaceController,
                  placeholder: '替换为 Replace With',
                  monospace: true,
                  maxLines: 3,
                  minLines: 1,
                  suffix: IconButton(
                    icon: const Icon(CupertinoIcons.clear_circled_solid, size: 18),
                    tooltip: '清空（替换为空 = 删除匹配）',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _replaceController.clear(),
                  ),
                ),
              ],
            ),
          ),
          _footnote('正则示例：/hello/gi  纯文本示例：hello'),
          _footnote(r'使用 $1 $2 引用捕获组，留空则删除匹配内容'),

          // ── 应用范围 ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: KiraSection(
              title: '应用范围 Apply To',
              children: [
                _buildPlacementTile(RegexPlacement.userInput, '用户消息', 'User Input'),
                _buildPlacementTile(RegexPlacement.aiOutput, '角色消息', 'AI Output'),
                _buildPlacementTile(RegexPlacement.slashCommand, '斜杠命令', 'Slash'),
                _buildPlacementTile(RegexPlacement.worldInfo, '世界书', 'World Info'),
                _buildPlacementTile(RegexPlacement.reasoning, '推理块', 'Reasoning'),
              ],
            ),
          ),
          _footnote('选择此脚本在哪些场景生效'),

          // ── 选项 ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: KiraSection(
              title: '选项 Options',
              children: [
                KiraSwitchTile(
                  title: '仅 Markdown',
                  subtitle: '仅在 Markdown 渲染时应用',
                  value: _markdownOnly,
                  onChanged: (value) => setState(() => _markdownOnly = value),
                ),
                KiraSwitchTile(
                  title: '仅提示词',
                  subtitle: '仅在提示词生成时应用',
                  value: _promptOnly,
                  onChanged: (value) => setState(() => _promptOnly = value),
                ),
                KiraSwitchTile(
                  title: '编辑时运行',
                  subtitle: '编辑消息时也应用此脚本',
                  value: _runOnEdit,
                  onChanged: (value) => setState(() => _runOnEdit = value),
                ),
                KiraGroupedTile(
                  title: '宏替换模式 Substitute Regex',
                  onTap: _pickSubstituteRegex,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _substituteRegex.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeBodyLarge,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                      const SizedBox(width: DesignTokens.spaceXs),
                      Icon(
                        CupertinoIcons.chevron_forward,
                        size: 16,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _footnote('none = 不替换  raw = 原始宏  escaped = 转义宏'),

          // ── 高级选项(折叠) ───────────────────────────────────────
          SliverToBoxAdapter(
            child: KiraSection(
              title: '',
              children: [
                KiraGroupedTile(
                  icon: _showAdvanced
                      ? CupertinoIcons.chevron_up
                      : CupertinoIcons.chevron_down,
                  title: '高级选项 Advanced',
                  onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                  trailing: const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          if (_showAdvanced) ...[
            SliverToBoxAdapter(
              child: KiraSection(
                title: '消息深度限制 Depth Range',
                children: [
                  _borderlessField(
                    controller: _minDepthController,
                    placeholder: '最小深度 Min Depth',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  _borderlessField(
                    controller: _maxDepthController,
                    placeholder: '最大深度 Max Depth',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ],
              ),
            ),
            _footnote('限制脚本只对最近 N 条消息生效。0 = 最新消息，留空 = 不限制。'),
            SliverToBoxAdapter(
              child: KiraSection.plain(
                title: '修剪字符串 Trim Strings',
                child: Padding(
                  padding: const EdgeInsets.all(DesignTokens.spaceMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_trimStrings.isNotEmpty) ...[
                        Wrap(
                          spacing: DesignTokens.spaceXs + DesignTokens.spaceXxs,
                          runSpacing: DesignTokens.spaceXs,
                          children: _trimStrings.map((s) {
                            return Chip(
                              label: Text(
                                s,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: DesignTokens.fontSizeXs,
                                ),
                              ),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () =>
                                  setState(() => _trimStrings.remove(s)),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: DesignTokens.spaceSm),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: CupertinoTextField.borderless(
                              controller: _trimInputController,
                              placeholder: '添加修剪字符串',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                              onSubmitted: (_) => _addTrimString(),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              CupertinoIcons.add_circled_solid,
                              color: theme.colorScheme.primary,
                            ),
                            tooltip: '添加',
                            onPressed: _addTrimString,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _footnote('在替换后从结果中删除这些字符串。输入后按 + 添加'),
          ],

          const SliverToBoxAdapter(
            child: SizedBox(height: DesignTokens.spaceXl),
          ),
        ],
      ),
    );
  }

  /// inset-grouped 组内无边框输入行(与 ai_preset_edit_screen 一致)
  Widget _borderlessField({
    required TextEditingController controller,
    required String placeholder,
    bool monospace = false,
    int? maxLines = 1,
    int? minLines,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    Widget? suffix,
  }) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceMd,
        vertical: DesignTokens.spaceXs,
      ),
      child: CupertinoTextField.borderless(
        controller: controller,
        placeholder: placeholder,
        maxLines: maxLines,
        minLines: minLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        suffix: suffix,
        suffixMode: suffix != null
            ? OverlayVisibilityMode.always
            : OverlayVisibilityMode.never,
        style: monospace
            ? (baseStyle ?? const TextStyle())
                .copyWith(fontFamily: 'monospace')
            : baseStyle,
      ),
    );
  }

  /// 组脚注(iOS inset-grouped footer)
  Widget _footnote(String text) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DesignTokens.spaceMd + 12,
          DesignTokens.spaceSm,
          DesignTokens.spaceMd,
          0,
        ),
        child: Text(text, style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }

  Widget _buildPlacementTile(
      RegexPlacement placement, String labelZh, String labelEn) {
    final theme = Theme.of(context);
    final selected = _placement.contains(placement);
    return KiraGroupedTile(
      title: labelZh,
      subtitle: labelEn,
      onTap: () {
        setState(() {
          if (selected) {
            _placement.remove(placement);
          } else {
            _placement.add(placement);
          }
        });
      },
      trailing: selected
          ? Icon(
              CupertinoIcons.checkmark,
              size: 18,
              color: theme.colorScheme.primary,
            )
          : const SizedBox.shrink(),
    );
  }
}
