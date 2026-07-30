import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/models/character.dart';
import 'package:kirakira/data/models/regex_script.dart';
import 'package:kirakira/data/repositories/character_repository.dart';
import 'package:kirakira/presentation/providers/regex_providers.dart';
import 'package:kirakira/presentation/theme/app_theme.dart';
import 'package:kirakira/presentation/widgets/regex/regex_widgets.dart';

/// 角色正则脚本管理页面（全屏独立页）
class CharacterRegexScreen extends ConsumerStatefulWidget {
  final String characterId;

  const CharacterRegexScreen({super.key, required this.characterId});

  @override
  ConsumerState<CharacterRegexScreen> createState() => _CharacterRegexScreenState();
}

class _CharacterRegexScreenState extends ConsumerState<CharacterRegexScreen> {
  Character? _character;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCharacter();
  }

  Future<void> _loadCharacter() async {
    final repo = ref.read(characterRepositoryProvider);
    final char = await repo.getCharacter(widget.characterId);
    if (mounted) {
      setState(() {
        _character = char;
        _loading = false;
      });
    }
  }

  void _showScriptEditor([RegexScript? script]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: RegexScriptEditor(
          script: script,
          onSave: (newScript) {
            if (script == null) {
              ref.read(characterRegexScriptsProvider(widget.characterId).notifier).addScript(newScript);
            } else {
              ref.read(characterRegexScriptsProvider(widget.characterId).notifier).updateScript(
                newScript.copyWith(
                  id: script.id,
                  createdAt: script.createdAt,
                  updatedAt: DateTime.now(),
                ),
              );
            }
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _deleteScript(RegexScript script) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除正则脚本'),
        content: Text('确定删除「${script.scriptName}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(characterRegexScriptsProvider(widget.characterId).notifier).removeScript(script.id);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_character == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('角色正则')),
        body: const Center(child: Text('角色不存在')),
      );
    }

    final scripts = ref.watch(characterRegexScriptsProvider(widget.characterId));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('角色正则脚本', style: TextStyle(fontSize: 18)),
            Text(
              _character!.name,
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('正则脚本说明'),
                  content: const SingleChildScrollView(
                    child: Text(
                      '角色正则脚本仅对当前角色生效，会在全局正则之后执行。\n\n'
                      '应用范围：\n'
                      '• 用户消息：发送前处理\n'
                      '• 角色消息：接收后处理\n'
                      '• 斜杠命令：命令执行时处理\n'
                      '• 世界书：世界书内容处理\n'
                      '• 推理块：思考内容处理\n\n'
                      '查找模式支持：\n'
                      '• 正则表达式：/pattern/flags\n'
                      '• 纯文本：直接输入\n\n'
                      '替换内容支持：\n'
                      '• \$1, \$2：引用捕获组\n'
                      '• 纯文本：直接替换',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('知道了'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: scripts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.find_replace, size: 64, color: AppTheme.textMuted.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  const Text(
                    '还没有角色正则脚本',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '点击右下角按钮添加',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                  ),
                ],
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: scripts.length,
              onReorder: (oldIndex, newIndex) {
                // ReorderableListView 的 newIndex 逻辑：拖到后面时 newIndex 会比实际位置大 1
                // 不需要手动调整，provider 内部会处理
              },
              itemBuilder: (context, index) {
                final script = scripts[index];
                return Card(
                  key: ValueKey(script.id),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: RegexScriptTile(
                    script: script,
                    onTap: () => _showScriptEditor(script),
                    onToggle: () {
                      ref.read(characterRegexScriptsProvider(widget.characterId).notifier).toggleScript(script.id);
                    },
                    onDelete: () => _deleteScript(script),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showScriptEditor(),
        icon: const Icon(Icons.add),
        label: const Text('添加脚本'),
      ),
    );
  }
}