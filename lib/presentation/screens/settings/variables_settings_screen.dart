import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/domain/services/variables_service.dart';
import 'package:kirakira/presentation/providers/variables_providers.dart';
import 'package:kirakira/presentation/theme/app_theme.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/widgets/common/kira_components.dart';
import 'variable_edit_screen.dart';

/// Screen for managing variables
class VariablesSettingsScreen extends ConsumerWidget {
  final String? chatId;

  const VariablesSettingsScreen({super.key, this.chatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final globalVars = ref.watch(globalVariablesProvider);
    final localVars = chatId != null ? ref.watch(localVariablesProvider(chatId!)) : <String, dynamic>{};

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(
              chatId != null ? AppLocalizations.of(context)!.chatVariables : AppLocalizations.of(context)!.variables,
              style: Theme.of(context).textTheme.displayLarge,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: AppLocalizations.of(context)!.addVariable,
                onPressed: () => _showAddVariableDialog(context, ref),
              ),
              PopupMenuButton<String>(
                icon: const Icon(CupertinoIcons.ellipsis_circle),
                onSelected: (value) => _handleMenuAction(context, ref, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'clear_global',
                    child: ListTile(
                      leading: Icon(Icons.delete_sweep),
                      title: Text('清除全局变量'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  if (chatId != null)
                    const PopupMenuItem(
                      value: 'clear_local',
                      child: ListTile(
                        leading: Icon(Icons.delete_sweep),
                        title: Text('清除本地变量'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ),
            ],
          ),
          SliverList(
            delegate: SliverChildListDelegate([
          // Info section
          _buildSection(
            title: '关于变量',
            children: [
              const ListTile(
                leading: Icon(Icons.info_outline, color: AppTheme.accentColor),
                title: Text('变量系统'),
                subtitle: Text(
                  'Variables store values that can be used in macros. '
                  'Global variables persist across all chats, while local variables are per-chat.',
                ),
              ),
              const ListTile(
                leading: Icon(Icons.code, color: AppTheme.textMuted),
                title: Text('宏用法'),
                subtitle: Text(
                  '{{getvar::name}} - Get local variable\n'
                  '{{setvar::name::value}} - Set local variable\n'
                  '{{getglobalvar::name}} - Get global variable\n'
                  '{{setglobalvar::name::value}} - Set global variable',
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Global variables
          _buildSection(
            title: 'Global Variables (${globalVars.length})',
            children: [
              if (globalVars.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(DesignTokens.spaceXl),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.data_object, size: 48, color: AppTheme.textMuted),
                        SizedBox(height: 16),
                        Text(
                          'No global variables',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...globalVars.entries.map((entry) => _VariableTile(
                  name: entry.key,
                  value: entry.value,
                  isGlobal: true,
                  onEdit: () => _showEditVariableDialog(context, ref, entry.key, entry.value, true),
                  onDelete: () => _confirmDeleteVariable(context, ref, entry.key, true),
                  onIncrement: () => ref.read(globalVariablesProvider.notifier).increment(entry.key),
                  onDecrement: () => ref.read(globalVariablesProvider.notifier).decrement(entry.key),
                )),
            ],
          ),

          if (chatId != null) ...[
            const SizedBox(height: 16),

            // Local variables
            _buildSection(
              title: 'Local Variables (${localVars.length})',
              children: [
                if (localVars.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(DesignTokens.spaceXl),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.data_object, size: 48, color: AppTheme.textMuted),
                          SizedBox(height: 16),
                          Text(
                            'No local variables for this chat',
                            style: TextStyle(color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...localVars.entries.map((entry) => _VariableTile(
                    name: entry.key,
                    value: entry.value,
                    isGlobal: false,
                    onEdit: () => _showEditVariableDialog(context, ref, entry.key, entry.value, false),
                    onDelete: () => _confirmDeleteVariable(context, ref, entry.key, false),
                    onIncrement: () => ref.read(localVariablesProvider(chatId!).notifier).increment(entry.key),
                    onDecrement: () => ref.read(localVariablesProvider(chatId!).notifier).decrement(entry.key),
                  )),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Test section
          _buildSection(
            title: '测试',
            children: [
              _VariableTestWidget(chatId: chatId),
            ],
          ),
        ]),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    // D-T0:inset-grouped 一组一张卡
    return KiraSection(title: title, children: children);
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'clear_global':
        _confirmClearVariables(context, ref, true);
        break;
      case 'clear_local':
        if (chatId != null) {
          _confirmClearVariables(context, ref, false);
        }
        break;
    }
  }

  /// D-T2 规则 3:添加变量(含作用域选择)→ push 子页
  void _showAddVariableDialog(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VariableEditScreen(chatId: chatId),
      ),
    );
  }

  /// D-T2:编辑变量 → push 子页
  void _showEditVariableDialog(BuildContext context, WidgetRef ref, String name, dynamic value, bool isGlobal) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VariableEditScreen(
          chatId: chatId,
          initialName: name,
          initialValue: value?.toString() ?? '',
          initialIsGlobal: isGlobal,
          allowScopeChoice: false,
        ),
      ),
    );
  }

  void _confirmDeleteVariable(BuildContext context, WidgetRef ref, String name, bool isGlobal) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('删除变量'),
        content: Text('删除"$name"？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              if (isGlobal) {
                ref.read(globalVariablesProvider.notifier).deleteVariable(name);
              } else if (chatId != null) {
                ref.read(localVariablesProvider(chatId!).notifier).deleteVariable(name);
              }
              Navigator.pop(dialogCtx);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _confirmClearVariables(BuildContext context, WidgetRef ref, bool isGlobal) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: Text('清空${isGlobal ? '全局' : '本地'}变量'),
        content: Text('将删除全部${isGlobal ? '全局' : '本地'}变量,此操作不可撤销。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              if (isGlobal) {
                ref.read(globalVariablesProvider.notifier).clearAll();
              } else if (chatId != null) {
                ref.read(localVariablesProvider(chatId!).notifier).clearAll();
              }
              Navigator.pop(dialogCtx);
            },
            child: const Text('清除全部'),
          ),
        ],
      ),
    );
  }
}

/// Tile for displaying a variable
class _VariableTile extends StatelessWidget {
  final String name;
  final dynamic value;
  final bool isGlobal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _VariableTile({
    required this.name,
    required this.value,
    required this.isGlobal,
    required this.onEdit,
    required this.onDelete,
    required this.onIncrement,
    required this.onDecrement,
  });

  String get _valueType {
    if (value == null) return 'null';
    if (value is int) return 'int';
    if (value is double) return 'double';
    if (value is bool) return 'bool';
    if (value is String) {
      final num = double.tryParse(value as String);
      if (num != null) return 'number';
      return 'string';
    }
    if (value is List) return 'array';
    if (value is Map) return 'object';
    return value.runtimeType.toString();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        isGlobal ? Icons.public : Icons.chat_bubble_outline,
        color: isGlobal ? AppTheme.accentColor : DesignTokens.statusWarning,
      ),
      title: Row(
        children: [
          Text(name),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: DesignTokens.spaceXxs),
            decoration: BoxDecoration(
              color: AppTheme.textMuted.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
            ),
            child: Text(
              _valueType,
              style: const TextStyle(
                fontSize: DesignTokens.fontSizeCaption,
                color: AppTheme.textMuted,
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        value?.toString() ?? 'null',
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: DesignTokens.fontSizeXs,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            onPressed: onDecrement,
            tooltip: '递减',
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            onPressed: onIncrement,
            tooltip: '递增',
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: onEdit,
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 18, color: DesignTokens.statusError),
            onPressed: onDelete,
            tooltip: 'Delete',
          ),
        ],
      ),
      onTap: onEdit,
    );
  }
}

/// Widget for testing variable macros
class _VariableTestWidget extends ConsumerStatefulWidget {
  final String? chatId;

  const _VariableTestWidget({this.chatId});

  @override
  ConsumerState<_VariableTestWidget> createState() => _VariableTestWidgetState();
}

class _VariableTestWidgetState extends ConsumerState<_VariableTestWidget> {
  final _inputController = TextEditingController();
  String? _result;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final service = ref.read(variablesServiceProvider);
    final result = await service.processVariableMacros(
      _inputController.text,
      chatId: widget.chatId,
    );
    setState(() {
      _result = result;
    });
    // Refresh providers to show any changes
    ref.read(globalVariablesProvider.notifier).refresh();
    if (widget.chatId != null) {
      ref.read(localVariablesProvider(widget.chatId!).notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DesignTokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _inputController,
            decoration: const InputDecoration(
              labelText: '测试输入',
              hintText: '{{setvar::counter::0}} Counter: {{getvar::counter}}',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _test,
            icon: const Icon(Icons.play_arrow),
            label: const Text('处理宏'),
          ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                border: Border.all(color: AppTheme.accentColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check, size: 16, color: AppTheme.accentColor),
                      SizedBox(width: 8),
                      Text(
                        'Result',
                        style: TextStyle(
                          color: AppTheme.accentColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(DesignTokens.spaceSm),
                    decoration: BoxDecoration(
                      color: AppTheme.darkBackground,
                      borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
                    ),
                    child: SelectableText(
                      _result!.isEmpty ? '(empty string)' : _result!,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _result!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已复制到剪贴板')),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}