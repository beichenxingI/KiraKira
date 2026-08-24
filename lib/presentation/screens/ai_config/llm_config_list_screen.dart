// lib/presentation/screens/ai_config/llm_config_list_screen.dart
/// LLM 配置管理(G-T4):Sliver 化 + KiraGroupedTile 行 + 编辑 push 子页
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/widgets/common/common.dart';
import '../../../data/database/database.dart';
import '../../providers/llm_configs_provider.dart';
import 'llm_config_edit_screen.dart';

class LlmConfigListScreen extends ConsumerWidget {
  const LlmConfigListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(llmConfigsProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // G-T4:Sliver 化;英文页名改中文(工程页,保留直白)
          SliverAppBar.large(
            title: Text(
              'LLM 配置管理', // TODO(i18n): 待补 l10n key
              style: Theme.of(context).textTheme.displayLarge,
            ),
            actions: [
              IconButton(
                icon: const Icon(CupertinoIcons.add),
                tooltip: '新建配置',
                onPressed: () => _openEditor(context, ref),
              ),
              const SizedBox(width: DesignTokens.spaceSm),
            ],
          ),
          if (state.loading)
            const SliverFillRemaining(
              child: Center(child: CupertinoActivityIndicator()),
            )
          else if (state.configs.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  '暂无配置。点右上角 + 新建。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          else
            // 一份 inset-grouped 卡内列全部配置
            SliverToBoxAdapter(
              child: KiraSection(
                title: '全部配置',
                children: [
                  for (final c in state.configs)
                    _ConfigTile(config: c),
                ],
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  void _openEditor(BuildContext context, WidgetRef ref, {LlmConfig? existing}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LlmConfigEditScreen(existing: existing),
      ),
    );
  }
}

/// 单条配置行(inset-grouped 内,KiraGroupedTile 规格)
class _ConfigTile extends ConsumerWidget {
  const _ConfigTile({required this.config});

  final LlmConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = config;
    return KiraGroupedTile(
      icon: c.isDefault
          ? CupertinoIcons.checkmark_circle_fill
          : CupertinoIcons.circle,
      iconColor: c.isDefault
          ? DesignTokens.statusSuccess
          : theme.textTheme.bodySmall?.color,
      title: c.name,
      subtitle:
          '${c.provider} · ${c.model ?? "no model"} · ${c.endpoint}',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LlmConfigEditScreen(existing: c)),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (c.isDefault)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: DesignTokens.statusSuccess.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
              ),
              child: const Text(
                '当前',
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeXs,
                  color: DesignTokens.statusSuccess,
                ),
              ),
            ),
          PopupMenuButton<String>(
            icon: const Icon(CupertinoIcons.ellipsis_circle, size: 18),
            onSelected: (v) async {
              if (v == 'activate') {
                await ref.read(llmConfigsProvider.notifier).setActive(c.id);
              } else if (v == 'edit') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => LlmConfigEditScreen(existing: c)),
                );
              } else if (v == 'delete') {
                await ref.read(llmConfigsProvider.notifier).delete(c.id);
              }
            },
            itemBuilder: (_) => [
              if (!c.isDefault)
                const PopupMenuItem(value: 'activate', child: Text('设为当前')),
              const PopupMenuItem(value: 'edit', child: Text('编辑')),
              const PopupMenuItem(value: 'delete', child: Text('删除')),
            ],
          ),
        ],
      ),
    );
  }
}
