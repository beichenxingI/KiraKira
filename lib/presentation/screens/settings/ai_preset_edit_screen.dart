import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/ai_preset.dart';
import '../../../data/models/regex_script.dart';
import '../../providers/ai_preset_providers.dart';
import '../../providers/prompt_manager_providers.dart';
import '../../providers/regex_providers.dart';
import '../../theme/app_theme.dart';

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

  @override
  Widget build(BuildContext context) {
    final allPromptPresets = ref.watch(allPresetsProvider);
    final allRegexScripts = ref.watch(globalRegexScriptsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑预设'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存', style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 基本信息
          Text('基本信息',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.accentColor,
                    fontWeight: FontWeight.bold,
                  )),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '预设名称',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(
              labelText: '描述（可选）',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // 绑定提示词预设
          Text('绑定提示词预设',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.accentColor,
                    fontWeight: FontWeight.bold,
                  )),
          const SizedBox(height: 4),
          Text(
            '切换此AI预设时，自动切换到绑定的提示词预设',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: _selectedPromptPresetId,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            hint: const Text('不绑定（使用全局激活的提示词预设）'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('不绑定'),
              ),
              ...allPromptPresets.map((p) => DropdownMenuItem<String?>(
                    value: p.id,
                    child: Text(p.name, overflow: TextOverflow.ellipsis),
                  )),
            ],
            onChanged: (v) => setState(() => _selectedPromptPresetId = v),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // 绑定正则脚本
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('绑定全局正则脚本',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.accentColor,
                        fontWeight: FontWeight.bold,
                      )),
              if (_selectedRegexIds.isNotEmpty)
                Text(
                  '已选 ${_selectedRegexIds.length} 个',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.primaryColor),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '切换此AI预设时，仅启用选中的正则脚本，其余自动禁用',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),

          if (allRegexScripts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                '暂无全局正则脚本',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppTheme.textMuted),
                textAlign: TextAlign.center,
              ),
            )else
            ..._buildRegexList(allRegexScripts),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  List<Widget> _buildRegexList(List<RegexScript> scripts) {
    return scripts.map((script) {
      final selected = _selectedRegexIds.contains(script.id);
      return CheckboxListTile(
        value: selected,
        title: Text(
          script.scriptName,
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: script.description != null
            ? Text(
                script.description!,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        secondary: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: script.disabled
                ? AppTheme.darkCard
                : AppTheme.primaryColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            script.disabled ? '已禁用' : '启用',
            style: TextStyle(
              fontSize: 10,
              color: script.disabled ? AppTheme.textMuted : AppTheme.primaryColor,
            ),
          ),
        ),
        onChanged: (v) {
          setState(() {
            if (v == true) {
              _selectedRegexIds.add(script.id);
            } else {
              _selectedRegexIds.remove(script.id);
            }
          });
        },
        activeColor: AppTheme.primaryColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
        dense: true,
      );
    }).toList();
  }
}