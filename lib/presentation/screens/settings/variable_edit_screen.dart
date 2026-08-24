import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/presentation/providers/variables_providers.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/widgets/common/common.dart';

/// 变量编辑页(D-T2:添加/编辑两个 AlertDialog 表单合并 → push 子页)
///
/// [initialName] 为空 = 添加模式;非空 = 编辑模式(变量名锁定,只改值)。
/// [allowScopeChoice] = 聊天内打开时,添加模式可选 全局/本地 作用域。
class VariableEditScreen extends ConsumerStatefulWidget {
  final String? chatId;
  final String? initialName;
  final String initialValue;
  final bool initialIsGlobal;
  final bool allowScopeChoice;

  const VariableEditScreen({
    super.key,
    this.chatId,
    this.initialName,
    this.initialValue = '',
    this.initialIsGlobal = true,
    this.allowScopeChoice = false,
  });

  @override
  ConsumerState<VariableEditScreen> createState() => _VariableEditScreenState();
}

class _VariableEditScreenState extends ConsumerState<VariableEditScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _valueController;
  late bool _isGlobal;

  bool get _isEditing => widget.initialName != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _valueController = TextEditingController(text: widget.initialValue);
    _isGlobal = widget.initialIsGlobal;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  /// 写入逻辑与原 添加/编辑 AlertDialog 完全一致(provider 调用零改动)
  void _save() {
    final name = _isEditing ? widget.initialName! : _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入变量名')),
      );
      return;
    }
    final value = _valueController.text;
    if (_isGlobal || widget.chatId == null) {
      ref.read(globalVariablesProvider.notifier).setVariable(name, value);
    } else {
      ref
          .read(localVariablesProvider(widget.chatId!).notifier)
          .setVariable(name, value);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 表单深页:pinned 常规标题(施工模板①例外)
          SliverAppBar(
            pinned: true,
            title: Text(_isEditing ? '编辑变量' : '添加变量'),
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

          // 变量信息
          SliverToBoxAdapter(
            child: KiraSection(
              title: '变量信息',
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceMd,
                    vertical: DesignTokens.spaceXs,
                  ),
                  child: CupertinoTextField.borderless(
                    controller: _nameController,
                    placeholder: '变量名',
                    readOnly: _isEditing,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceMd,
                    vertical: DesignTokens.spaceXs,
                  ),
                  child: CupertinoTextField.borderless(
                    controller: _valueController,
                    placeholder: '值',
                    maxLines: 3,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),

          // 作用域(仅添加模式且在有 chatId 时可选,替代原 ChoiceChip)
          if (!_isEditing && widget.allowScopeChoice)
            SliverToBoxAdapter(
              child: KiraSection(
                title: '作用域',
                children: [
                  KiraGroupedTile(
                    icon: Icons.public,
                    title: '全局',
                    subtitle: '所有聊天共享',
                    onTap: () => setState(() => _isGlobal = true),
                    trailing: _isGlobal
                        ? Icon(
                            CupertinoIcons.checkmark,
                            size: 18,
                            color: theme.colorScheme.primary,
                          )
                        : const SizedBox.shrink(),
                  ),
                  KiraGroupedTile(
                    icon: Icons.chat_bubble_outline,
                    title: '本地',
                    subtitle: '仅当前聊天',
                    onTap: () => setState(() => _isGlobal = false),
                    trailing: !_isGlobal
                        ? Icon(
                            CupertinoIcons.checkmark,
                            size: 18,
                            color: theme.colorScheme.primary,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: DesignTokens.spaceXl),
          ),
        ],
      ),
    );
  }
}
