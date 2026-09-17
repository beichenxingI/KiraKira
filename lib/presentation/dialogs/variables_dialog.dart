// lib/presentation/dialogs/variables_dialog.dart
/// 变量管理浮窗(极客Core迁移 P5.2)
/// 内容完整迁自 variables_settings_screen.dart(475行)+
/// variable_edit_screen.dart(添加/编辑并入为嵌套浮窗):
/// 关于变量说明 · 全局变量列表(编辑/删除/递增/递减) ·
/// 本地变量列表(传入chatId时) · 宏测试 · 清除全部
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/providers/variables_providers.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'core_dialog.dart';

Future<void> showVariablesDialog(
  BuildContext context,
  WidgetRef ref, {
  String? chatId,
}) {
  return showCoreDialog(
    context,
    builder: (_) => _VariablesDialog(chatId: chatId),
  );
}

class _VariablesDialog extends ConsumerWidget {
  const _VariablesDialog({this.chatId});

  final String? chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CoreDialogPalette(isDark: isDark);
    final globalVars = ref.watch(globalVariablesProvider);
    final localVars = chatId != null
        ? ref.watch(localVariablesProvider(chatId!))
        : <String, dynamic>{};

    return CoreDialogShell(
      title: chatId != null ? l10n.chatVariables : l10n.variables,
      icon: CupertinoIcons.square_list,
      maxWidth: 550,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 添加变量
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            minSize: 0,
            onPressed: () => _showVariableEditDialog(
              context,
              chatId: chatId,
              allowScopeChoice: chatId != null,
            ),
            child: Icon(CupertinoIcons.add_circled,
                size: 22, color: DesignTokens.primary),
          ),
          // 清除菜单
          PopupMenuButton<String>(
            icon: Icon(CupertinoIcons.ellipsis_circle,
                size: 22, color: palette.textSecondary),
            color: palette.surface,
            onSelected: (value) {
              if (value == 'clear_global') {
                _confirmClearVariables(context, ref, true);
              } else if (value == 'clear_local' && chatId != null) {
                _confirmClearVariables(context, ref, false);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'clear_global',
                child: Row(children: [
                  Icon(Icons.delete_sweep,
                      size: 18, color: palette.textSecondary),
                  const SizedBox(width: 8),
                  const Text('清除全局变量'),
                ]),
              ),
              if (chatId != null)
                PopupMenuItem(
                  value: 'clear_local',
                  child: Row(children: [
                    Icon(Icons.delete_sweep,
                        size: 18, color: palette.textSecondary),
                    const SizedBox(width: 8),
                    const Text('清除本地变量'),
                  ]),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 关于变量 ──
          CoreInfoRow(
            icon: CupertinoIcons.info,
            title: '变量系统',
            text: 'Variables store values that can be used in macros. '
                'Global variables persist across all chats, while local '
                'variables are per-chat.',
            palette: palette,
          ),
          CoreInfoRow(
            icon: Icons.code,
            title: '宏用法',
            text: '{{getvar::name}} - Get local variable\n'
                '{{setvar::name::value}} - Set local variable\n'
                '{{getglobalvar::name}} - Get global variable\n'
                '{{setglobalvar::name::value}} - Set global variable',
            palette: palette,
          ),
          const SizedBox(height: 8),

          // ── 全局变量 ──
          CoreSectionLabel('Global Variables (${globalVars.length})'),
          const SizedBox(height: 4),
          if (globalVars.isEmpty)
            Text(
              'No global variables',
              style: TextStyle(fontSize: 12, color: palette.textSecondary),
            )
          else
            ...globalVars.entries.map((entry) => _VariableTile(
                  palette: palette,
                  name: entry.key,
                  value: entry.value,
                  isGlobal: true,
                  onEdit: () => _showVariableEditDialog(
                    context,
                    chatId: chatId,
                    initialName: entry.key,
                    initialValue: entry.value?.toString() ?? '',
                    initialIsGlobal: true,
                    allowScopeChoice: false,
                  ),
                  onDelete: () =>
                      _confirmDeleteVariable(context, ref, entry.key, true),
                  onIncrement: () => ref
                      .read(globalVariablesProvider.notifier)
                      .increment(entry.key),
                  onDecrement: () => ref
                      .read(globalVariablesProvider.notifier)
                      .decrement(entry.key),
                )),
          const SizedBox(height: 20),

          // ── 本地变量(传入 chatId 时) ──
          if (chatId != null) ...[
            CoreSectionLabel('Local Variables (${localVars.length})'),
            const SizedBox(height: 4),
            if (localVars.isEmpty)
              Text(
                'No local variables for this chat',
                style:
                    TextStyle(fontSize: 12, color: palette.textSecondary),
              )
            else
              ...localVars.entries.map((entry) => _VariableTile(
                    palette: palette,
                    name: entry.key,
                    value: entry.value,
                    isGlobal: false,
                    onEdit: () => _showVariableEditDialog(
                      context,
                      chatId: chatId,
                      initialName: entry.key,
                      initialValue: entry.value?.toString() ?? '',
                      initialIsGlobal: false,
                      allowScopeChoice: false,
                    ),
                    onDelete: () => _confirmDeleteVariable(
                        context, ref, entry.key, false),
                    onIncrement: () => ref
                        .read(localVariablesProvider(chatId!).notifier)
                        .increment(entry.key),
                    onDecrement: () => ref
                        .read(localVariablesProvider(chatId!).notifier)
                        .decrement(entry.key),
                  )),
            const SizedBox(height: 20),
          ],

          // ── 测试 ──
          CoreSectionLabel('测试'),
          const SizedBox(height: 8),
          _VariableTestWidget(palette: palette, chatId: chatId),
        ],
      ),
    );
  }

  void _confirmDeleteVariable(
      BuildContext context, WidgetRef ref, String name, bool isGlobal) {
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
                ref
                    .read(globalVariablesProvider.notifier)
                    .deleteVariable(name);
              } else if (chatId != null) {
                ref
                    .read(localVariablesProvider(chatId!).notifier)
                    .deleteVariable(name);
              }
              Navigator.pop(dialogCtx);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _confirmClearVariables(
      BuildContext context, WidgetRef ref, bool isGlobal) {
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
                ref
                    .read(localVariablesProvider(chatId!).notifier)
                    .clearAll();
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

/// 变量行(原 _VariableTile 浮窗形态)
class _VariableTile extends StatelessWidget {
  const _VariableTile({
    required this.palette,
    required this.name,
    required this.value,
    required this.isGlobal,
    required this.onEdit,
    required this.onDelete,
    required this.onIncrement,
    required this.onDecrement,
  });

  final CoreDialogPalette palette;
  final String name;
  final dynamic value;
  final bool isGlobal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

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
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: palette.fill.withValues(alpha: palette.isDark ? 0.55 : 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            isGlobal ? CupertinoIcons.globe : CupertinoIcons.chat_bubble,
            size: 18,
            color: isGlobal ? DesignTokens.primary : DesignTokens.statusWarning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: palette.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: palette.textTertiary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _valueType,
                        style: TextStyle(
                            fontSize: 10, color: palette.textSecondary),
                      ),
                    ),
                  ],
                ),
                Text(
                  value?.toString() ?? 'null',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: palette.textSecondary),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(4),
            minSize: 0,
            onPressed: onDecrement,
            child: Icon(CupertinoIcons.minus,
                size: 16, color: palette.textSecondary),
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(4),
            minSize: 0,
            onPressed: onIncrement,
            child: Icon(CupertinoIcons.plus,
                size: 16, color: palette.textSecondary),
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(4),
            minSize: 0,
            onPressed: onEdit,
            child: Icon(CupertinoIcons.pencil,
                size: 16, color: DesignTokens.primary),
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(4),
            minSize: 0,
            onPressed: onDelete,
            child: const Icon(CupertinoIcons.trash,
                size: 16, color: DesignTokens.statusError),
          ),
        ],
      ),
    );
  }
}

/// 宏测试(原 _VariableTestWidget 浮窗形态)
class _VariableTestWidget extends ConsumerStatefulWidget {
  const _VariableTestWidget({required this.palette, this.chatId});

  final CoreDialogPalette palette;
  final String? chatId;

  @override
  ConsumerState<_VariableTestWidget> createState() =>
      _VariableTestWidgetState();
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
    final palette = widget.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CoreTextField(
          controller: _inputController,
          palette: palette,
          hint: '{{setvar::counter::0}} Counter: {{getvar::counter}}',
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        CorePrimaryButton(
          label: '处理宏',
          icon: CupertinoIcons.play_fill,
          onPressed: _test,
        ),
        if (_result != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DesignTokens.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: DesignTokens.primary),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check,
                        size: 16, color: DesignTokens.primary),
                    SizedBox(width: 8),
                    Text(
                      'Result',
                      style: TextStyle(
                        color: DesignTokens.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: palette.isDark
                        ? const Color(0xFF0D0D0D)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: SelectableText(
                    _result!.isEmpty ? '(empty string)' : _result!,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      minSize: 0,
                      color: palette.fill,
                      borderRadius: BorderRadius.circular(8),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _result!));
                        coreToast(context, '已复制到剪贴板');
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy,
                              size: 14, color: palette.textSecondary),
                          const SizedBox(width: 4),
                          Text('Copy',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: palette.textPrimary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// 变量编辑浮窗(原 VariableEditScreen 浮窗化,字段与写入逻辑一致)
Future<void> _showVariableEditDialog(
  BuildContext context, {
  String? chatId,
  String? initialName,
  String initialValue = '',
  bool initialIsGlobal = true,
  bool allowScopeChoice = false,
}) {
  return showCoreDialog(
    context,
    builder: (_) => _VariableEditDialog(
      chatId: chatId,
      initialName: initialName,
      initialValue: initialValue,
      initialIsGlobal: initialIsGlobal,
      allowScopeChoice: allowScopeChoice,
    ),
  );
}

class _VariableEditDialog extends ConsumerStatefulWidget {
  const _VariableEditDialog({
    this.chatId,
    this.initialName,
    this.initialValue = '',
    this.initialIsGlobal = true,
    this.allowScopeChoice = false,
  });

  final String? chatId;
  final String? initialName;
  final String initialValue;
  final bool initialIsGlobal;
  final bool allowScopeChoice;

  @override
  ConsumerState<_VariableEditDialog> createState() =>
      _VariableEditDialogState();
}

class _VariableEditDialogState extends ConsumerState<_VariableEditDialog> {
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

  /// 写入逻辑与原页完全一致(provider 调用零改动)
  void _save() {
    final name =
        _isEditing ? widget.initialName! : _nameController.text.trim();
    if (name.isEmpty) {
      coreToast(context, '请输入变量名');
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CoreDialogPalette(isDark: isDark);

    return CoreDialogShell(
      title: _isEditing ? '编辑变量' : '添加变量',
      icon: CupertinoIcons.pencil,
      maxWidth: 400,
      footer: CoreDialogFooter(
        child: Row(
          children: [
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: palette.fill,
                borderRadius: BorderRadius.circular(10),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  '取消',
                  style:
                      TextStyle(fontSize: 15, color: palette.textPrimary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: DesignTokens.primary,
                borderRadius: BorderRadius.circular(10),
                onPressed: _save,
                child: const Text('保存',
                    style: TextStyle(fontSize: 15, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 变量信息 ──
          CoreSectionLabel('变量信息'),
          const SizedBox(height: 8),
          CoreTextField(
            controller: _nameController,
            palette: palette,
            hint: '变量名',
            readOnly: _isEditing,
            autofocus: !_isEditing,
          ),
          const SizedBox(height: 8),
          CoreTextField(
            controller: _valueController,
            palette: palette,
            hint: '值',
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          // ── 作用域(仅添加模式且在有 chatId 时可选) ──
          if (!_isEditing && widget.allowScopeChoice) ...[
            CoreSectionLabel('作用域'),
            const SizedBox(height: 4),
            CoreTile(
              title: '全局',
              subtitle: '所有聊天共享',
              trailing: _isGlobal
                  ? const Icon(CupertinoIcons.checkmark,
                      size: 18, color: DesignTokens.primary)
                  : null,
              onTap: () => setState(() => _isGlobal = true),
            ),
            CoreTile(
              title: '本地',
              subtitle: '仅当前聊天',
              trailing: !_isGlobal
                  ? const Icon(CupertinoIcons.checkmark,
                      size: 18, color: DesignTokens.primary)
                  : null,
              onTap: () => setState(() => _isGlobal = false),
            ),
          ],
        ],
      ),
    );
  }
}
