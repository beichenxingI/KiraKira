import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/regex_script.dart';
import '../providers/regex_providers.dart';
import '../theme/design_tokens.dart';
import '../widgets/regex/regex_widgets.dart';
import 'regex_rule_edit_dialog.dart';

/// 角色正则管理浮窗（编辑浮窗内入口）
void showCharacterRegexDialog(
  BuildContext context,
  WidgetRef ref, {
  required String characterId,
}) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (_) => _CharacterRegexDialog(characterId: characterId),
  );
}

class _CharacterRegexDialog extends ConsumerWidget {
  final String characterId;

  const _CharacterRegexDialog({required this.characterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scripts = ref.watch(characterRegexScriptsProvider(characterId));

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 400,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.textformat,
                        size: 20, color: DesignTokens.primary),
                    const SizedBox(width: 8),
                    Text('角色正则 (${scripts.length})',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: DesignTokens.weightSemibold,
                          color: isDark
                              ? const Color(0xFFF0F0F0)
                              : const Color(0xFF2C2C2C),
                        )),
                    const Spacer(),
                    IconButton(
                      icon: Icon(CupertinoIcons.xmark,
                          size: 22,
                          color: isDark
                              ? const Color(0xFF8C8C8C)
                              : const Color(0xFF8E8E93)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(
                  height: 1,
                  color:
                      isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0)),
              // 正则列表
              Flexible(
                child: scripts.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.textformat,
                                size: 40,
                                color: isDark
                                    ? const Color(0xFF6C6C6C)
                                    : const Color(0xFFBDBDBD)),
                            const SizedBox(height: 8),
                            Text('尚未添加角色正则',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? const Color(0xFF8C8C8C)
                                      : const Color(0xFF8E8E93),
                                )),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: scripts.length,
                        itemBuilder: (_, i) {
                          final script = scripts[i];
                          return RegexScriptTile(
                            key: ValueKey(script.id),
                            script: script,
                            onTap: () => _openEditor(context, ref, script),
                            onToggle: () => ref
                                .read(characterRegexScriptsProvider(characterId)
                                    .notifier)
                                .toggleScript(script.id),
                            onDelete: () => ref
                                .read(characterRegexScriptsProvider(characterId)
                                    .notifier)
                                .removeScript(script.id),
                          );
                        },
                      ),
              ),
              Divider(
                  height: 1,
                  color:
                      isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0)),
              // 添加按钮
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    color: DesignTokens.primary,
                    borderRadius: BorderRadius.circular(10),
                    onPressed: () => _openEditor(context, ref, null),
                    child: const Text('添加正则',
                        style: TextStyle(fontSize: 15, color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 新建/编辑正则
  void _openEditor(BuildContext context, WidgetRef ref, RegexScript? script) {
    if (script != null) {
      showRegexRuleEditDialog(context, ref, script: script);
      return;
    }
    // 新建：创建空脚本后打开完整编辑浮窗
    final notifier =
        ref.read(characterRegexScriptsProvider(characterId).notifier);
    final blank = RegexScript(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      scriptName: '新规则',
      findRegex: '',
      replaceString: '',
      trimStrings: [],
      placement: [RegexPlacement.aiOutput],
      scriptType: RegexScriptType.character,
      markdownOnly: false,
      promptOnly: false,
      runOnEdit: false,
      substituteRegex: SubstituteRegex.none,
      order: 0,
      characterId: characterId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    notifier.addScript(blank).then((_) {
      final scripts =
          ref.read(characterRegexScriptsProvider(characterId));
      if (scripts.isNotEmpty && context.mounted) {
        showRegexRuleEditDialog(context, ref,
            script: scripts.last);
      }
    });
  }
}

