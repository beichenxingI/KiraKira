import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/chat_statistics.dart';
import '../../providers/statistics_providers.dart';
import '../../widgets/common/common.dart';

/// Screen for viewing app and chat statistics
class StatisticsScreen extends ConsumerWidget {
  final String? chatId;

  const StatisticsScreen({super.key, this.chatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(
              chatId != null ? '会话统计' : '应用统计',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            actions: [
              if (chatId == null)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: '重置统计数据',
                  onPressed: () => _showResetConfirmation(context, ref),
                ),
            ],
          ),
          if (chatId != null)
            SliverToBoxAdapter(child: _ChatStatisticsView(chatId: chatId!))
          else
            const SliverToBoxAdapter(child: _AppStatisticsView()),
          const SliverToBoxAdapter(
              child: SizedBox(height: DesignTokens.spaceXl)),
        ],
      ),
    );
  }

  void _showResetConfirmation(BuildContext context, WidgetRef ref) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('重置统计数据'),
        content: const Text('确定要重置全部统计数据吗？此操作无法撤销。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              ref.read(appStatisticsProvider.notifier).reset();
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('统计数据已重置')),
              );
            },
            child: const Text('重置'),
          ),
        ],
      ),
    );
  }
}

class _AppStatisticsView extends ConsumerWidget {
  const _AppStatisticsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(appStatisticsProvider);
    final summary = ref.watch(statisticsSummaryProvider);

    return Column(
      children: [
        // 总览
        KiraSection(
          title: '总览',
          icon: Icons.dashboard,
          children: [
            _StatRow(
              label: '首次使用',
              value: stats.appFirstUsed != null
                  ? _formatDate(stats.appFirstUsed!)
                  : '未知',
            ),
            _StatRow(
              label: '累计字符数',
              value: summary.characterCount.toString(),
            ),
            _StatRow(
              label: '聊天总数',
              value: stats.totalChats.toString(),
            ),
            _StatRow(
              label: '群组总数',
              value: stats.totalGroups.toString(),
            ),
          ],
        ),

        // 消息
        KiraSection(
          title: '消息',
          icon: Icons.message,
          children: [
            _StatRow(
              label: '消息总数',
              value: _formatNumber(stats.totalMessages),
            ),
            _StatRow(
              label: '生成次数',
              value: _formatNumber(stats.totalGenerations),
            ),
          ],
        ),

        // Token 用量
        KiraSection(
          title: 'Token 用量',
          icon: Icons.token,
          children: [
            _StatRow(
              label: '累计 Token',
              value: _formatNumber(stats.totalTokensUsed),
            ),
            _StatRow(
              label: '平均 Token/次生成',
              value: stats.averageTokensPerGeneration.toStringAsFixed(1),
            ),
          ],
        ),

        // 性能
        KiraSection(
          title: '性能',
          icon: Icons.speed,
          children: [
            _StatRow(
              label: '累计生成耗时',
              value: _formatDuration(stats.totalGenerationTime),
            ),
            _StatRow(
              label: '平均生成耗时',
              value: _formatDuration(stats.averageGenerationTime),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChatStatisticsView extends ConsumerWidget {
  final String chatId;

  const _ChatStatisticsView({required this.chatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(computedChatStatisticsProvider(chatId));

    return statsAsync.when(
      data: (stats) => _buildStatsList(context, stats),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
    );
  }

  Widget _buildStatsList(BuildContext context, ChatStatistics stats) {
    return Column(
      children: [
        // 消息
        KiraSection(
          title: '消息',
          icon: Icons.message,
          children: [
            _StatRow(
              label: '消息总数',
              value: stats.totalMessages.toString(),
            ),
            _StatRow(
              label: '用户消息',
              value: stats.userMessages.toString(),
            ),
            _StatRow(
              label: '助手消息',
              value: stats.assistantMessages.toString(),
            ),
            _StatRow(
              label: '系统消息',
              value: stats.systemMessages.toString(),
            ),
          ],
        ),

        // 时间线
        KiraSection(
          title: '时间线',
          icon: Icons.timeline,
          children: [
            _StatRow(
              label: '首条消息',
              value: stats.firstMessageAt != null
                  ? _formatDateTime(stats.firstMessageAt!)
                  : '暂无',
            ),
            _StatRow(
              label: '最近消息',
              value: stats.lastMessageAt != null
                  ? _formatDateTime(stats.lastMessageAt!)
                  : '暂无',
            ),
            _StatRow(
              label: '会话时长',
              value: _formatDuration(stats.chatDuration),
            ),
          ],
        ),

        // Token 用量
        KiraSection(
          title: 'Token 用量',
          icon: Icons.token,
          children: [
            _StatRow(
              label: '累计 Token',
              value: _formatNumber(stats.totalTokensUsed),
            ),
            _StatRow(
              label: '输入 Token',
              value: _formatNumber(stats.promptTokens),
            ),
            _StatRow(
              label: '输出 Token',
              value: _formatNumber(stats.completionTokens),
            ),
            _StatRow(
              label: '平均 Token/条',
              value: stats.averageTokensPerMessage.toStringAsFixed(1),
            ),
          ],
        ),

        // 生成性能
        KiraSection(
          title: '生成性能',
          icon: Icons.speed,
          children: [
            _StatRow(
              label: '生成次数',
              value: stats.generationCount.toString(),
            ),
            _StatRow(
              label: '累计生成耗时',
              value: _formatDuration(stats.totalGenerationTime),
            ),
            _StatRow(
              label: '平均生成耗时',
              value: _formatDuration(stats.averageGenerationTime),
            ),
          ],
        ),
      ],
    );
  }
}

/// 统计行:iOS 设置式「左标签 + 右值」纯信息行
class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return KiraGroupedTile(
      title: label,
      trailing: Text(
        value,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

String _formatNumber(int number) {
  if (number >= 1000000) {
    return '${(number / 1000000).toStringAsFixed(1)}M';
  } else if (number >= 1000) {
    return '${(number / 1000).toStringAsFixed(1)}K';
  }
  return number.toString();
}

String _formatDuration(Duration duration) {
  if (duration.inDays > 0) {
    return '${duration.inDays}d ${duration.inHours % 24}h';
  } else if (duration.inHours > 0) {
    return '${duration.inHours}h ${duration.inMinutes % 60}m';
  } else if (duration.inMinutes > 0) {
    return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
  } else if (duration.inSeconds > 0) {
    return '${duration.inSeconds}.${(duration.inMilliseconds % 1000) ~/ 100}s';
  } else if (duration.inMilliseconds > 0) {
    return '${duration.inMilliseconds}ms';
  }
  return '0s';
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String _formatDateTime(DateTime date) {
  return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
