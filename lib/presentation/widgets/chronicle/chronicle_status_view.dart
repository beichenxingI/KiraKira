// lib/presentation/widgets/chronicle/chronicle_status_view.dart
/// Super Memory status visualization (five-zone display + progress bar).
/// All icons are hand-drawn CustomPainter paths (no emoji, no Material Icons, no third-party libraries);
/// the progress bar is drawn with CustomPainter and its colors follow the theme (dark/light adaptive).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/presentation/providers/chronicle_providers.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';

class ChronicleStatusView extends ConsumerWidget {
  final String chatId;
  const ChronicleStatusView({required this.chatId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(chronicleVisualizationProvider(chatId));
    return dataAsync.when(
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (e, _) => Center(
        child: Text(
          '加载失败: $e',
          style: TextStyle(
              fontSize: DesignTokens.fontSizeSm,
              color: Theme.of(context).colorScheme.error),
        ),
      ),
      data: (data) => _StatusContent(data: data),
    );
  }
}

class _StatusContent extends StatelessWidget {
  final ChronicleVisualizationData data;
  const _StatusContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(DesignTokens.spaceMd),
      children: [
        Text(
          '超级记忆工作状态',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: DesignTokens.spaceMd),
        _UnarchivedCard(data: data),
        const SizedBox(height: DesignTokens.spaceSm),
        for (final zone in data.zones)
          Padding(
            padding: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
            child: _ZoneCard(zone: zone),
          ),
        if (data.zones.isEmpty) const _EmptyState(),
      ],
    );
  }
}

/// Unarchived zone (highest priority) + progress bar toward the next summarize pass
class _UnarchivedCard extends StatelessWidget {
  final ChronicleVisualizationData data;
  const _UnarchivedCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = data.progress.clamp(0.0, 1.0);
    final percent = (data.progress * 100).toStringAsFixed(1);
    final range = data.unarchivedStartFloor <= 0
        ? '${data.unarchivedCount} 条原文'
        : data.unarchivedStartFloor == data.unarchivedEndFloor
            ? '第 ${data.unarchivedStartFloor} 条（${data.unarchivedCount} 条原文）'
            : '第 ${data.unarchivedStartFloor}-${data.unarchivedEndFloor} 条'
                '（${data.unarchivedCount} 条原文）';
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spaceMd),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DesignTokens.radiusGroupedCard),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ZoneIcon(iconKey: 'unsummarized', color: theme.colorScheme.primary),
              const SizedBox(width: DesignTokens.spaceSm),
              Text(
                '未总结区',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: DesignTokens.spaceXs),
              Text(
                '（最高优先级 · 原文注入末尾）',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          Text(range, style: theme.textTheme.bodyLarge),
          const SizedBox(height: DesignTokens.spaceSm),
          Divider(
              color: theme.colorScheme.outlineVariant, height: 1),
          const SizedBox(height: DesignTokens.spaceSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '距离下一次总结',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${data.unarchivedUserTurns}/${data.summaryInterval} 轮',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                  child: SizedBox(
                    height: 14,
                    child: CustomPaint(
                      painter: _ProgressBarPainter(
                        progress: progress,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHigh,
                        foregroundColor: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: DesignTokens.spaceSm),
              Text(
                '$percent%',
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Archive zone card (hot/warm/cold/frozen)
class _ZoneCard extends StatelessWidget {
  final ChronicleZone zone;
  const _ZoneCard({required this.zone});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _zoneColor(zone.key);
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spaceMd),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(DesignTokens.radiusGroupedCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ZoneIcon(iconKey: zone.key, color: color),
              const SizedBox(width: DesignTokens.spaceSm),
              Text(
                zone.name,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(width: DesignTokens.spaceXs),
              Text(
                '（${_zonePriority(zone.key)}）',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          Text(
            zone.startIndex == zone.endIndex
                ? '第 ${zone.startIndex} 条'
                : '第 ${zone.startIndex}-${zone.endIndex} 条',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: DesignTokens.spaceXs),
          Text(
            zone.hasOriginalText
                ? '${zone.messageCount} 条原文 + 总结词条'
                : '只注入总结词条（原文已彻底淡出）',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            _ZoneIcon(
              iconKey: 'unsummarized',
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无归档记忆',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '继续聊天，超级记忆会自动归档',
              style: theme.textTheme.bodySmall?.copyWith(
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Zone colors and labels

/// Zone theme color (fixed hue, readable on both dark and light backgrounds; text/background adapt to the theme)
Color _zoneColor(String key) {
  switch (key) {
    case 'hot':
      return const Color(0xFFFF7043);
    case 'warm':
      return const Color(0xFFFFB300);
    case 'cold':
      return const Color(0xFF42A5F5);
    case 'frozen':
      return const Color(0xFF26C6DA);
    default:
      return const Color(0xFF7C4DFF);
  }
}

String _zonePriority(String key) {
  switch (key) {
    case 'hot':
      return '高优先级 · 原文注入';
    case 'warm':
      return '中优先级 · 渐进淡出';
    case 'cold':
      return '低优先级 · 渐进淡出';
    case 'frozen':
      return '最低优先级 · 仅词条召回';
    default:
      return '';
  }
}

// Hand-drawn icons (CustomPainter, 24x24 design space)

class _ZoneIcon extends StatelessWidget {
  final String iconKey;
  final Color color;
  final double size;

  const _ZoneIcon({required this.iconKey, required this.color, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: switch (iconKey) {
          'hot' => _FlameIconPainter(color),
          'warm' => _ThermoIconPainter(color),
          'cold' => _SnowflakeIconPainter(color),
          'frozen' => _ArchiveBoxIconPainter(color),
          _ => _BoltIconPainter(color),
        },
      ),
    );
  }
}

/// Lightning bolt (unarchived zone)
class _BoltIconPainter extends CustomPainter {
  final Color color;
  _BoltIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final path = Path()
      ..moveTo(13 * s, 2 * s)
      ..lineTo(3 * s, 14 * s)
      ..lineTo(11 * s, 14 * s)
      ..lineTo(11 * s, 22 * s)
      ..lineTo(21 * s, 10 * s)
      ..lineTo(13 * s, 10 * s)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _BoltIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Flame (hot zone)
class _FlameIconPainter extends CustomPainter {
  final Color color;
  _FlameIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final fill = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final outer = Path()
      ..moveTo(12 * s, 2 * s)
      ..cubicTo(9 * s, 5 * s, 7 * s, 8.5 * s, 7 * s, 12.5 * s)
      ..arcToPoint(
        Offset(17 * s, 12.5 * s),
        radius: Radius.circular(5 * s),
      )
      ..cubicTo(17 * s, 8.5 * s, 15 * s, 5 * s, 12 * s, 2 * s)
      ..close();
    canvas.drawPath(outer, fill);
    canvas.drawPath(outer, stroke);
    final inner = Path()
      ..moveTo(12 * s, 9.5 * s)
      ..cubicTo(11 * s, 11 * s, 10 * s, 12.2 * s, 10 * s, 13.5 * s)
      ..arcToPoint(
        Offset(14 * s, 13.5 * s),
        radius: Radius.circular(2 * s),
      )
      ..cubicTo(14 * s, 12.2 * s, 13 * s, 11 * s, 12 * s, 9.5 * s)
      ..close();
    canvas.drawPath(inner, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _FlameIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Thermometer (warm zone)
class _ThermoIconPainter extends CustomPainter {
  final Color color;
  _ThermoIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Glass tube: U shape (left wall - top - right wall), meeting the bulb at the bottom
    final stem = Path()
      ..moveTo(10 * s, 15 * s)
      ..lineTo(10 * s, 4 * s)
      ..arcToPoint(
        Offset(14 * s, 4 * s),
        radius: Radius.circular(2 * s),
      )
      ..lineTo(14 * s, 15 * s);
    canvas.drawPath(stem, stroke);
    // Bulb
    canvas.drawCircle(Offset(12 * s, 18 * s), 3.5 * s, stroke);
    // Mercury
    canvas.drawCircle(
        Offset(12 * s, 18 * s), 1.7 * s, Paint()..color = color);
    canvas.drawRect(
      Rect.fromLTWH(11.2 * s, 9 * s, 1.6 * s, 7 * s),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _ThermoIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Snowflake (cold zone)
class _SnowflakeIconPainter extends CustomPainter {
  final Color color;
  _SnowflakeIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round;
    final c = Offset(12 * s, 12 * s);
    // Three main axes (vertical + two diagonals)
    final arms = <List<Offset>>[
      [Offset(12 * s, 2.5 * s), Offset(12 * s, 21.5 * s)],
      [Offset(3.8 * s, 7.2 * s), Offset(20.2 * s, 16.8 * s)],
      [Offset(3.8 * s, 16.8 * s), Offset(20.2 * s, 7.2 * s)],
    ];
    for (final arm in arms) {
      canvas.drawLine(arm[0], arm[1], stroke);
    }
    // Axis endpoints
    final dot = Paint()..color = color;
    for (final arm in arms) {
      canvas.drawCircle(arm[0], 1.3 * s, dot);
      canvas.drawCircle(arm[1], 1.3 * s, dot);
    }
    // Center
    canvas.drawCircle(c, 1.6 * s, dot);
  }

  @override
  bool shouldRepaint(covariant _SnowflakeIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Archive box (frozen zone: originals archived and faded out)
class _ArchiveBoxIconPainter extends CustomPainter {
  final Color color;
  _ArchiveBoxIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Box body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4 * s, 6.5 * s, 16 * s, 14 * s),
        Radius.circular(2 * s),
      ),
      stroke,
    );
    // Lid divider line
    canvas.drawLine(
      Offset(4 * s, 10.5 * s),
      Offset(20 * s, 10.5 * s),
      stroke,
    );
    // Handle
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(9.5 * s, 13 * s, 5 * s, 2.4 * s),
        Radius.circular(1.2 * s),
      ),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _ArchiveBoxIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Progress bar (drawn with CustomPainter, no third-party library)
class _ProgressBarPainter extends CustomPainter {
  final double progress; // 0.0-1.0
  final Color backgroundColor;
  final Color foregroundColor;

  _ProgressBarPainter({
    required this.progress,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    // Background
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = backgroundColor,
    );
    // Foreground (progress)
    if (progress > 0) {
      final progressWidth = size.width * progress;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, progressWidth, size.height),
          radius,
        ),
        Paint()..color = foregroundColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressBarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.foregroundColor != foregroundColor;
  }
}
