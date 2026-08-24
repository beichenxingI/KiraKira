import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/models/tokenizer.dart';
import 'package:kirakira/domain/services/tokenizer_service.dart';
import 'package:kirakira/presentation/providers/tokenizer_providers.dart';
import 'package:kirakira/presentation/widgets/common/common.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';

// 豁免:样本条配色(Token 可视化样本色谱,属于可视化取色,非主题色,不随明暗主题变化)
const _kSampleColors = <Color>[
  Colors.blue,
  Colors.green,
  Colors.orange,
  Colors.purple,
  Colors.teal,
  Colors.pink,
];

/// Settings and visualization screen for tokenizer
class TokenizerSettingsScreen extends ConsumerStatefulWidget {
  const TokenizerSettingsScreen({super.key});

  @override
  ConsumerState<TokenizerSettingsScreen> createState() => _TokenizerSettingsScreenState();
}

class _TokenizerSettingsScreenState extends ConsumerState<TokenizerSettingsScreen> {
  final _textController = TextEditingController();
  String _inputText = '';

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(tokenizerSettingsProvider);
    final service = ref.watch(tokenizerServiceProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(
              l10n.tokenizerSettings,
              style: Theme.of(context).textTheme.displayLarge,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.help_outline),
                onPressed: () => _showHelpSheet(context, service),
                tooltip: l10n.tokenizerHelp,
              ),
            ],
          ),

          // ── 设置 ──
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KiraSection(
                  title: '设置',
                  children: [
                    KiraGroupedTile(
                      title: '分词器',
                      trailing: DropdownButton<TokenizerType>(
                        value: settings.selectedTokenizer,
                        underline: const SizedBox.shrink(),
                        onChanged: (type) {
                          if (type != null) {
                            ref.read(tokenizerSettingsProvider.notifier).setSelectedTokenizer(type);
                          }
                        },
                        items: TokenizerType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type.displayName),
                          );
                        }).toList(),
                      ),
                    ),
                    KiraSwitchTile(
                      title: '显示 Token 计数',
                      subtitle: '在聊天输入中显示 Token 计数',
                      value: settings.showTokenCount,
                      onChanged: (value) {
                        ref.read(tokenizerSettingsProvider.notifier).setShowTokenCount(value);
                      },
                    ),
                    KiraSwitchTile(
                      title: '显示 Token 可视化',
                      subtitle: '高亮显示每个 Token',
                      value: settings.showTokenVisualization,
                      onChanged: (value) {
                        ref.read(tokenizerSettingsProvider.notifier).setShowTokenVisualization(value);
                      },
                    ),
                    KiraSwitchTile(
                      title: '缓存结果',
                      subtitle: '缓存分词结果以提升性能',
                      value: settings.cacheResults,
                      onChanged: (value) {
                        ref.read(tokenizerSettingsProvider.notifier).setCacheResults(value);
                      },
                    ),
                  ],
                ),
                // 组尾说明:当前分词器描述
                Padding(
                  padding: const EdgeInsets.only(
                    left: DesignTokens.spaceMd + 12,
                    right: DesignTokens.spaceMd,
                    top: DesignTokens.spaceSm,
                  ),
                  child: Text(
                    settings.selectedTokenizer.description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),

          // ── Token 可视化(输入 + 快速估计)──
          SliverToBoxAdapter(
            child: KiraSection.plain(
              title: 'Token 可视化',
              child: Padding(
                padding: const EdgeInsets.all(DesignTokens.spaceMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        labelText: '输入要分词的文本',
                        hintText: '在此输入或粘贴文本...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
                      onChanged: (value) {
                        setState(() {
                          _inputText = value;
                        });
                      },
                    ),
                    if (_inputText.isNotEmpty) ...[
                      const SizedBox(height: DesignTokens.spaceMd),
                      _QuickEstimate(text: _inputText),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // 分词结果(统计 + 明细)
          if (_inputText.isNotEmpty)
            SliverToBoxAdapter(
              child: _TokenizationResultView(
                text: _inputText,
                tokenizer: settings.selectedTokenizer,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: DesignTokens.spaceXl)),
        ],
      ),
    );
  }

  /// 帮助 → 底部 Sheet(圆角 14)
  void _showHelpSheet(BuildContext context, TokenizerService service) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusBottomSheet),
        ),
      ),
      builder: (sheetCtx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '分词器帮助',
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeHeadline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: DesignTokens.spaceMd),
              Text(service.getHelpText()),
              const SizedBox(height: DesignTokens.spaceMd),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheetCtx),
                  child: const Text('关闭'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quick token count estimate widget(嵌在 Token 可视化分组卡内,不带自有卡面)
class _QuickEstimate extends ConsumerWidget {
  final String text;

  const _QuickEstimate({required this.text});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estimate = ref.watch(tokenCountEstimateProvider(text));

    return Row(
      children: [
        Icon(
          Icons.speed,
          color: Theme.of(context).textTheme.bodyMedium?.color,
        ),
        const SizedBox(width: DesignTokens.spaceSm + 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Quick Estimate'),
              Text(
                '~$estimate tokens',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
        Text(
          '${text.length} chars',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Tokenization result visualization
class _TokenizationResultView extends ConsumerWidget {
  final String text;
  final TokenizerType tokenizer;

  const _TokenizationResultView({
    required this.text,
    required this.tokenizer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = TokenizationRequest(text: text, tokenizer: tokenizer);
    final resultAsync = ref.watch(tokenizationResultProvider(request));

    return resultAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(DesignTokens.spaceXl),
          child: CupertinoActivityIndicator(),
        ),
      ),
      error: (error, _) => Container(
        margin: DesignTokens.marginCard,
        padding: const EdgeInsets.all(DesignTokens.spaceMd),
        decoration: BoxDecoration(
          color: DesignTokens.statusError.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
          border: Border.all(
            color: DesignTokens.statusError.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          'Error: $error',
          style: const TextStyle(color: DesignTokens.statusError),
        ),
      ),
      data: (result) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Statistics
          _StatisticsCard(result: result),

          // Token visualization
          _TokenVisualization(result: result),
        ],
      ),
    );
  }
}

/// Statistics card for tokenization result
class _StatisticsCard extends ConsumerWidget {
  final TokenizationResult result;

  const _StatisticsCard({required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(tokenizerServiceProvider);
    final stats = service.getStatistics(result);

    return KiraSection.plain(
      title: '统计',
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatItem(
                  label: 'Total Tokens',
                  value: result.tokenCount.toString(),
                  icon: Icons.token,
                ),
                _StatItem(
                  label: 'Unique',
                  value: stats.uniqueTokens.toString(),
                  icon: Icons.fingerprint,
                ),
                _StatItem(
                  label: 'Chars/Token',
                  value: result.charToTokenRatio.toStringAsFixed(2),
                  icon: Icons.text_fields,
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.spaceSm + DesignTokens.spaceXs),
            Row(
              children: [
                _StatItem(
                  label: 'Avg Length',
                  value: stats.avgTokenLength.toStringAsFixed(1),
                  icon: Icons.straighten,
                ),
                _StatItem(
                  label: 'Longest',
                  value: '${stats.longestToken} chars',
                  icon: Icons.expand,
                ),
                _StatItem(
                  label: 'Shortest',
                  value: '${stats.shortestToken} chars',
                  icon: Icons.compress,
                ),
              ],
            ),
            if (stats.tokenFrequency.isNotEmpty) ...[
              const SizedBox(height: DesignTokens.spaceMd),
              Text(
                'Most Common Tokens',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: DesignTokens.spaceSm),
              Wrap(
                spacing: DesignTokens.spaceSm,
                runSpacing: DesignTokens.spaceXs,
                children: stats.getTopTokens(10).map((entry) {
                  return Chip(
                    label: Text(
                      '"${_escapeToken(entry.key)}" (${entry.value})',
                      style: const TextStyle(fontSize: DesignTokens.fontSizeXs),
                    ),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _escapeToken(String token) {
    return token
        .replaceAll('\n', '↵')
        .replaceAll('\t', '→')
        .replaceAll(' ', '␣');
  }
}

/// Single statistic item
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
          const SizedBox(height: DesignTokens.spaceXs),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Token visualization widget
class _TokenVisualization extends StatelessWidget {
  final TokenizationResult result;

  const _TokenVisualization({required this.result});

  @override
  Widget build(BuildContext context) {
    if (result.tokens.isEmpty) {
      return const SizedBox.shrink();
    }

    return KiraSection.plain(
      title: 'Token 明细',
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${result.tokens.length} tokens',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: DesignTokens.spaceSm + DesignTokens.spaceXs),
            Wrap(
              spacing: DesignTokens.spaceXs,
              runSpacing: DesignTokens.spaceXs,
              children: result.tokens.asMap().entries.map((entry) {
                final index = entry.key;
                final token = entry.value;
                return _TokenChip(
                  token: token,
                  index: index,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Single token chip
class _TokenChip extends StatelessWidget {
  final Token token;
  final int index;

  const _TokenChip({
    required this.token,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    // 豁免:样本条配色(见文件顶部 _kSampleColors)
    final color = _kSampleColors[index % _kSampleColors.length];

    return Tooltip(
      message: 'Token ID: ${token.id}\nLength: ${token.text.length} chars',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceSm, vertical: DesignTokens.spaceXs),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
        ),
        child: Text(
          _escapeToken(token.text),
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: DesignTokens.fontSizeSm,
            color: color.shade700,
          ),
        ),
      ),
    );
  }

  String _escapeToken(String text) {
    if (text.isEmpty) return '∅';
    return text
        .replaceAll('\n', '↵')
        .replaceAll('\t', '→')
        .replaceAll(' ', '␣');
  }
}

extension on Color {
  Color get shade700 {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness - 0.2).clamp(0.0, 1.0)).toColor();
  }
}
