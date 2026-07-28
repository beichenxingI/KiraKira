import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kirakira/data/models/regex_script.dart';
import 'package:kirakira/presentation/providers/regex_providers.dart';
import 'package:kirakira/presentation/theme/app_theme.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';

/// 单条正则脚本的列表项（可复用：设置页、角色编辑页）
class RegexScriptTile extends StatelessWidget {
  final RegexScript script;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const RegexScriptTile({
    super.key,
    required this.script,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        Icons.find_replace,
        color: script.disabled ? AppTheme.textMuted : AppTheme.accentColor,
      ),
      title: Text(
        script.scriptName,
        style: TextStyle(
          color: script.disabled ? AppTheme.textMuted : null,
          decoration: script.disabled ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(
        script.findRegex,
        style: const TextStyle(
          fontSize: 12,
          fontFamily: 'monospace',
          color: AppTheme.textMuted,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              script.disabled ? Icons.toggle_off : Icons.toggle_on,
              color: script.disabled ? AppTheme.textMuted : AppTheme.accentColor,
            ),
            onPressed: onToggle,
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: onDelete,
          ),
          const Icon(Icons.drag_handle, color: AppTheme.textMuted),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// 创建/编辑正则脚本的编辑器（可复用：设置页、角色编辑页）
class RegexScriptEditor extends StatefulWidget {
  final RegexScript? script;
  final void Function(RegexScript) onSave;

  const RegexScriptEditor({
    super.key,
    this.script,
    required this.onSave,
  });

  @override
  State<RegexScriptEditor> createState() => _RegexScriptEditorState();
}

class _RegexScriptEditorState extends State<RegexScriptEditor> {
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

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              // 拖动把手
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 标题栏
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.script == null
                          ? AppLocalizations.of(context).newScript
                          : AppLocalizations.of(context).editScript,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _save,
                      child: Text(AppLocalizations.of(context).save),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // 内容区
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── 基本信息 ──────────────────────────────────────
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '脚本名称',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: '描述（可选）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── 核心逻辑 ──────────────────────────────────────
                    TextField(
                      controller: _findController,
                      decoration: const InputDecoration(
                        labelText: '查找模式 Find Regex',
                        hintText: '/模式/标志 或纯文本',
                        helperText: '正则示例：/hello/gi  纯文本示例：hello',
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _replaceController,
                      decoration: InputDecoration(
                        labelText: '替换为 Replace With',
                        hintText: r'使用 $1 $2 引用捕获组，留空则删除匹配内容',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          tooltip: '清空（替换为空 = 删除匹配）',
                          onPressed: () => _replaceController.clear(),
                        ),
                      ),
                      style: const TextStyle(fontFamily: 'monospace'),
                      maxLines: 3,
                      minLines: 1,
                    ),
                    const SizedBox(height: 24),

                    // ── 应用范围 ──────────────────────────────────────
                    const Text(
                      '应用范围 Apply To',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '选择此脚本在哪些场景生效',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildPlacementChip(RegexPlacement.userInput, '用户消息', 'User Input'),
                        _buildPlacementChip(RegexPlacement.aiOutput, '角色消息', 'AI Output'),
                        _buildPlacementChip(RegexPlacement.slashCommand, '斜杠命令', 'Slash'),
                        _buildPlacementChip(RegexPlacement.worldInfo, '世界书', 'World Info'),
                        _buildPlacementChip(RegexPlacement.reasoning, '推理块', 'Reasoning'),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── 标准选项 ──────────────────────────────────────
                    const Text(
                      '选项 Options',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    SwitchListTile(
                      title: const Text('仅 Markdown'),
                      subtitle: const Text('仅在 Markdown 渲染时应用'),
                      value: _markdownOnly,
                      onChanged: (value) => setState(() => _markdownOnly = value),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('仅提示词'),
                      subtitle: const Text('仅在提示词生成时应用'),
                      value: _promptOnly,
                      onChanged: (value) => setState(() => _promptOnly = value),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('编辑时运行'),
                      subtitle: const Text('编辑消息时也应用此脚本'),
                      value: _runOnEdit,
                      onChanged: (value) => setState(() => _runOnEdit = value),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<SubstituteRegex>(
                      value: _substituteRegex,
                      decoration: const InputDecoration(
                        labelText: '宏替换模式 Substitute Regex',
                        helperText: 'none = 不替换  raw = 原始宏  escaped = 转义宏',
                        border: OutlineInputBorder(),
                      ),
                      items: SubstituteRegex.values.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text(s.name.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _substituteRegex = value);
                      },
                    ),
                    const SizedBox(height: 24),

                    // ── 高级选项（折叠） ───────────────────────────────
                    InkWell(
                      onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(
                              _showAdvanced ? Icons.expand_less : Icons.expand_more,
                              color: AppTheme.textMuted,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '高级选项 Advanced',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showAdvanced) ...[
                      const SizedBox(height: 8),
                      // 消息深度范围
                      const Text(
                        '消息深度限制 Depth Range',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '限制脚本只对最近 N 条消息生效。0 = 最新消息，留空 = 不限制。',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _minDepthController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: const InputDecoration(
                                labelText: '最小深度 Min Depth',
                                hintText: '留空 = 不限制',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _maxDepthController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: const InputDecoration(
                                labelText: '最大深度 Max Depth',
                                hintText: '留空 = 不限制',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 修剪字符串
                      const Text(
                        '修剪字符串 Trim Strings',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '在替换后从结果中删除这些字符串。',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 8),
                      if (_trimStrings.isNotEmpty) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: _trimStrings.map((s) {
                            return Chip(
                              label: Text(
                                s,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () => setState(() => _trimStrings.remove(s)),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _trimInputController,
                              decoration: const InputDecoration(
                                labelText: '添加修剪字符串',
                                hintText: '输入后按 + 添加',
                                border: OutlineInputBorder(),
                              ),
                              style: const TextStyle(fontFamily: 'monospace'),
                              onSubmitted: (_) => _addTrimString(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _addTrimString,
                            icon: const Icon(Icons.add),
                            tooltip: '添加',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlacementChip(RegexPlacement placement, String labelZh, String labelEn) {
    final selected = _placement.contains(placement);
    return FilterChip(
      label: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(labelZh, style: const TextStyle(fontSize: 13)),
          Text(labelEn, style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
        ],
      ),
      selected: selected,
      onSelected: (value) {
        setState(() {
          if (value) {
            _placement.add(placement);
          } else {
            _placement.remove(placement);
          }
        });
      },
    );
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

    if (widget.script != null) {
      widget.onSave(script.copyWith(
        id: widget.script!.id,
        order: widget.script!.order,
        createdAt: widget.script!.createdAt,
      ));
    } else {
      widget.onSave(script);
    }
  }
}