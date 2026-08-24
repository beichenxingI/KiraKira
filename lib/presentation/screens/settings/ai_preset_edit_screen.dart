import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/widgets/common/common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/ai_preset.dart';
import '../../../data/models/prompt_manager.dart';
import '../../../data/models/regex_script.dart';
import '../../providers/ai_preset_providers.dart';
import '../../providers/prompt_manager_providers.dart';
import '../../providers/regex_providers.dart';

class AIPresetEditScreen extends ConsumerStatefulWidget {
  final AIPreset preset;

  const AIPresetEditScreen({super.key, required this.preset});

  @override
  ConsumerState<AIPresetEditScreen> createState() => _AIPresetEditScreenState();
}

class _AIPresetEditScreenState extends ConsumerState<AIPresetEditScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  String? _selectedPromptPresetId;
  late Set<String> _selectedRegexIds;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.preset.name);
    _descController = TextEditingController(text: widget.preset.description ?? '');
    _selectedPromptPresetId = widget.preset.boundPromptPresetId;
    _selectedRegexIds = Set.from(widget.preset.boundRegexScriptIds);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('预设名称不能为空')),
      );
      return;
    }
    final updated = widget.preset.copyWith(
      name: _nameController.text.trim(),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      boundPromptPresetId: _selectedPromptPresetId,
      boundRegexScriptIds: _selectedRegexIds.toList(),
      updatedAt: DateTime.now(),
    );
    await ref.read(aiCustomPresetsProvider.notifier).updatePreset(updated);
    if (mounted) Navigator.pop(context);
  }

  /// 单选绑定 → CupertinoActionSheet(iOS 常规选择器)
  Future<void> _pickPromptPreset(List<PromptManagerPreset> presets) async {
    final selected = await showCupertinoModalPopup<String>(
      context: context,
      builder: (sheetCtx) => CupertinoActionSheet(
        title: const Text('绑定提示词预设'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetCtx, ''),
            child: const Text('不绑定（使用全局激活的提示词预设）'),
          ),
          ...presets.map(
            (p) => CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(sheetCtx, p.id),
              child: Text(
                p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetCtx),
          child: const Text('取消'),
        ),
      ),
    );
    if (selected == null) return; // 取消
    setState(
      () => _selectedPromptPresetId = selected.isEmpty ? null : selected,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allPromptPresets = ref.watch(allPresetsProvider);
    final allRegexScripts = ref.watch(globalRegexScriptsProvider);

    final boundPreset = _selectedPromptPresetId == null
        ? null
        : allPromptPresets
            .where((p) => p.id == _selectedPromptPresetId)
            .firstOrNull;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 编辑/表单深页:pinned 常规标题,不进 large(施工模板①例外)
          SliverAppBar(
            pinned: true,
            title: const Text('编辑预设'),
            actions: [
              TextButton(
                onPressed: _save,
                child: Text(
                  '保存',
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
              ),
            ],
          ),

          // 基本信息
          SliverToBoxAdapter(
            child: KiraSection(
              title: '基本信息',
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceMd,
                    vertical: DesignTokens.spaceXs,
                  ),
                  child: CupertinoTextField.borderless(
                    controller: _nameController,
                    placeholder: '预设名称',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceMd,
                    vertical: DesignTokens.spaceXs,
                  ),
                  child: CupertinoTextField.borderless(
                    controller: _descController,
                    placeholder: '描述（可选）',
                    maxLines: 2,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),

          // 绑定提示词预设
          SliverToBoxAdapter(
            child: KiraSection(
              title: '绑定提示词预设',
              children: [
                KiraGroupedTile(
                  title: '提示词预设',
                  subtitle:
                      boundPreset?.name ?? '不绑定（使用全局激活的提示词预设）',
                  onTap: () => _pickPromptPreset(allPromptPresets),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                DesignTokens.spaceMd + 12,
                DesignTokens.spaceSm,
                DesignTokens.spaceMd,
                0,
              ),
              child: Text(
                '切换此AI预设时，自动切换到绑定的提示词预设',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),

          // 绑定全局正则脚本
          SliverToBoxAdapter(
            child: KiraSection(
              title: _selectedRegexIds.isEmpty
                  ? '绑定全局正则脚本'
                  : '绑定全局正则脚本（已选 ${_selectedRegexIds.length} 个）',
              children: [
                if (allRegexScripts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: DesignTokens.spaceMd,
                    ),
                    child: Center(
                      child: Text(
                        '暂无全局正则脚本',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  )
                else
                  ...allRegexScripts.map(_buildRegexTile),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                DesignTokens.spaceMd + 12,
                DesignTokens.spaceSm,
                DesignTokens.spaceMd,
                0,
              ),
              child: Text(
                '切换此AI预设时，仅启用选中的正则脚本，其余自动禁用',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: DesignTokens.spaceXl)),
        ],
      ),
    );
  }

  /// 正则脚本行:整行点按勾选,选中尾标 = Cupertino checkmark + 状态徽标
  Widget _buildRegexTile(RegexScript script) {
    final theme = Theme.of(context);
    final selected = _selectedRegexIds.contains(script.id);
    return KiraGroupedTile(
      title: script.scriptName,
      subtitle: script.description,
      onTap: () {
        setState(() {
          if (selected) {
            _selectedRegexIds.remove(script.id);
          } else {
            _selectedRegexIds.add(script.id);
          }
        });
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceSm,
              vertical: DesignTokens.spaceXxs,
            ),
            decoration: BoxDecoration(
              color: script.disabled
                  ? theme.colorScheme.surfaceContainerHighest
                  : theme.colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
            ),
            child: Text(
              script.disabled ? '已禁用' : '启用',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeCaption,
                color: script.disabled
                    ? theme.textTheme.bodySmall?.color
                    : theme.colorScheme.primary,
              ),
            ),
          ),
          if (selected) ...[
            const SizedBox(width: DesignTokens.spaceSm),
            Icon(
              CupertinoIcons.checkmark,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ],
        ],
      ),
    );
  }
}
