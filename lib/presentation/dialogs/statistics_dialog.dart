// lib/presentation/dialogs/statistics_dialog.dart
/// Usage statistics dialog.
/// Mirrors statistics_screen.dart: app statistics (overview / messages / token
/// usage / performance) and chat statistics (messages / timeline / token usage
/// / generation performance), including the reset entry point.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/models/chat_statistics.dart';
import 'package:kirakira/presentation/providers/statistics_providers.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'core_dialog.dart';

Future<void> showStatisticsDialog(
  BuildContext context,
  WidgetRef ref, {
  String? chatId,
}) {
  return showCoreDialog(
    context,
    builder: (_) => _StatisticsDialog(chatId: chatId),
  );
}

class _StatisticsDialog extends ConsumerWidget {
  const _StatisticsDialog({this.chatId});

  final String? chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CoreDialogPalette(isDark: isDark);

    return CoreDialogShell(
      title: chatId != null ? '会话统计' : '应用统计',
      icon: CupertinoIcons.chart_bar,
      maxWidth: 550,
      trailing: chatId == null
          ? CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minSize: 0,
              onPressed: () => _showResetConfirmation(context, ref),
              child: Icon(
                CupertinoIcons.refresh,
                size: 20,
                color: palette.textSecondary,
              ),
            )
          : null,
      body: chatId != null
          ? _ChatStatisticsView(chatId: chatId!, palette: palette)
          : _AppStatisticsView(palette: palette),
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
              coreToast(context, '统计数据已重置');
            },
            child: const Text('重置'),
          ),
        ],
      ),
    );
  }
}

class _AppStatisticsView extends ConsumerWidget {
  const _AppStatisticsView({required this.palette});

  final CoreDialogPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(appStatisticsProvider);
    final summary = ref.watch(statisticsSummaryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CoreSectionLabel('总览'),
        const SizedBox(height: 4),
        _Group(
          palette: palette,
          children: [
            CoreStatRow(
              label: '首次使用',
              value: stats.appFirstUsed != null
                  ? _formatDate(stats.appFirstUsed!)
                  : '未知',
            ),
            CoreStatRow(
              label: '累计字符数',
              value: summary.characterCount.toString(),
            ),
            CoreStatRow(label: '聊天总数', value: stats.totalChats.toString()),
            CoreStatRow(label: '群组总数', value: stats.totalGroups.toString()),
          ],
        ),
        const SizedBox(height: 20),
        const CoreSectionLabel('消息'),
        const SizedBox(height: 4),
        _Group(
          palette: palette,
          children: [
            CoreStatRow(
                label: '消息总数', value: _formatNumber(stats.totalMessages)),
            CoreStatRow(
                label: '生成次数',
                value: _formatNumber(stats.totalGenerations)),
          ],
        ),
        const SizedBox(height: 20),
        const CoreSectionLabel('Token 用量'),
        const SizedBox(height: 4),
        _Group(
          palette: palette,
          children: [
            CoreStatRow(
                label: '累计 Token',
                value: _formatNumber(stats.totalTokensUsed)),
            CoreStatRow(
              label: '平均 Token/次生成',
              value: stats.averageTokensPerGeneration.toStringAsFixed(1),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const CoreSectionLabel('性能'),
        const SizedBox(height: 4),
        _Group(
          palette: palette,
          children: [
            CoreStatRow(
              label: '累计生成耗时',
              value: _formatDuration(stats.totalGenerationTime),
            ),
            CoreStatRow(
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
  const _ChatStatisticsView({required this.chatId, required this.palette});

  final String chatId;
  final CoreDialogPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(computedChatStatisticsProvider(chatId));

    return statsAsync.when(
      data: (stats) => _buildStatsList(stats),
      loading: () =>
          const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(strokeWidth: 2),
          )),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('加载失败: $e',
              style: const TextStyle(color: DesignTokens.statusError)),
        ),
      ),
    );
  }

  Widget _buildStatsList(ChatStatistics stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CoreSectionLabel('消息'),
        const SizedBox(height: 4),
        _Group(
          palette: palette,
          children: [
            CoreStatRow(
                label: '消息总数', value: stats.totalMessages.toString()),
            CoreStatRow(
                label: '用户消息', value: stats.userMessages.toString()),
            CoreStatRow(
                label: '助手消息', value: stats.assistantMessages.toString()),
            CoreStatRow(
                label: '系统消息', value: stats.systemMessages.toString()),
          ],
        ),
        const SizedBox(height: 20),
        const CoreSectionLabel('时间线'),
        const SizedBox(height: 4),
        _Group(
          palette: palette,
          children: [
            CoreStatRow(
              label: '首条消息',
              value: stats.firstMessageAt != null
                  ? _formatDateTime(stats.firstMessageAt!)
                  : '暂无',
            ),
            CoreStatRow(
              label: '最近消息',
              value: stats.lastMessageAt != null
                  ? _formatDateTime(stats.lastMessageAt!)
                  : '暂无',
            ),
            CoreStatRow(
                label: '会话时长', value: _formatDuration(stats.chatDuration)),
          ],
        ),
        const SizedBox(height: 20),
        const CoreSectionLabel('Token 用量'),
        const SizedBox(height: 4),
        _Group(
          palette: palette,
          children: [
            CoreStatRow(
                label: '累计 Token',
                value: _formatNumber(stats.totalTokensUsed)),
            CoreStatRow(
                label: '输入 Token',
                value: _formatNumber(stats.promptTokens)),
            CoreStatRow(
                label: '输出 Token',
                value: _formatNumber(stats.completionTokens)),
            CoreStatRow(
              label: '平均 Token/条',
              value: stats.averageTokensPerMessage.toStringAsFixed(1),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const CoreSectionLabel('生成性能'),
        const SizedBox(height: 4),
        _Group(
          palette: palette,
          children: [
            CoreStatRow(
                label: '生成次数', value: stats.generationCount.toString()),
            CoreStatRow(
              label: '累计生成耗时',
              value: _formatDuration(stats.totalGenerationTime),
            ),
            CoreStatRow(
              label: '平均生成耗时',
              value: _formatDuration(stats.averageGenerationTime),
            ),
          ],
        ),
      ],
    );
  }
}

/// Group container used inside the dialog.
class _Group extends StatelessWidget {
  const _Group({required this.palette, required this.children});

  final CoreDialogPalette palette;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color:
            palette.fill.withValues(alpha: palette.isDark ? 0.55 : 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: children),
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
