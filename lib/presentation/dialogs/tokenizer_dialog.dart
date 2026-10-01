// lib/presentation/dialogs/tokenizer_dialog.dart
/// Tokenizer settings dialog.
/// Settings (tokenizer/show token count/show token visualization/cache results),
/// token visualization (input/quick estimate/statistics/token detail chips), help.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/models/tokenizer.dart';
import 'package:kirakira/domain/services/tokenizer_service.dart';
import 'package:kirakira/presentation/providers/tokenizer_providers.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'core_dialog.dart';

// Sample strip colors (token visualization palette; fixed colors not tied to the light/dark theme).
const _kSampleColors = <Color>[
  Colors.blue,
  Colors.green,
  Colors.orange,
  Colors.purple,
  Colors.teal,
  Colors.pink,
];

Future<void> showTokenizerDialog(BuildContext context, WidgetRef ref) {
  return showCoreDialog(
    context,
    builder: (_) => const _TokenizerDialog(),
  );
}

class _TokenizerDialog extends ConsumerStatefulWidget {
  const _TokenizerDialog();

  @override
  ConsumerState<_TokenizerDialog> createState() => _TokenizerDialogState();
}

class _TokenizerDialogState extends ConsumerState<_TokenizerDialog> {
  final _textController = TextEditingController();
  String _inputText = '';

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CoreDialogPalette(isDark: isDark);
    final settings = ref.watch(tokenizerSettingsProvider);
    final service = ref.watch(tokenizerServiceProvider);

    return CoreDialogShell(
      title: '分词器设置',
      icon: CupertinoIcons.textformat_abc,
      maxWidth: 550,
      trailing: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minSize: 0,
        onPressed: () => _showHelpSheet(context, service, palette),
        child: Icon(Icons.help_outline,
            size: 20, color: palette.textSecondary),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Settings
          const CoreSectionLabel('设置'),
          const SizedBox(height: 4),
          _Group(
            palette: palette,
            children: [
              _DropdownTile(
                palette: palette,
                title: '分词器',
                subtitle: settings.selectedTokenizer.displayName,
                child: DropdownButton<TokenizerType>(
                  value: settings.selectedTokenizer,
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(8),
                  dropdownColor: palette.surface,
                  iconEnabledColor: palette.textSecondary,
                  onChanged: (type) {
                    if (type != null) {
                      ref
                          .read(tokenizerSettingsProvider.notifier)
                          .setSelectedTokenizer(type);
                    }
                  },
                  items: TokenizerType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(
                        type.displayName,
                        style: TextStyle(
                            fontSize: 14, color: palette.textPrimary),
                      ),
                    );
                  }).toList(),
                ),
              ),
              CoreSwitchRow(
                title: '显示 Token 计数',
                subtitle: '在聊天输入中显示 Token 计数',
                value: settings.showTokenCount,
                palette: palette,
                onChanged: (v) => ref
                    .read(tokenizerSettingsProvider.notifier)
                    .setShowTokenCount(v),
              ),
              CoreSwitchRow(
                title: '显示 Token 可视化',
                subtitle: '高亮显示每个 Token',
                value: settings.showTokenVisualization,
                palette: palette,
                onChanged: (v) => ref
                    .read(tokenizerSettingsProvider.notifier)
                    .setShowTokenVisualization(v),
              ),
              CoreSwitchRow(
                title: '缓存结果',
                subtitle: '缓存分词结果以提升性能',
                value: settings.cacheResults,
                palette: palette,
                onChanged: (v) => ref
                    .read(tokenizerSettingsProvider.notifier)
                    .setCacheResults(v),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            settings.selectedTokenizer.description,
            style: TextStyle(fontSize: 12, color: palette.textSecondary),
          ),
          const SizedBox(height: 20),

          // Token visualization
          const CoreSectionLabel('Token 可视化'),
          const SizedBox(height: 8),
          CoreTextField(
            controller: _textController,
            palette: palette,
            hint: '在此输入或粘贴文本...',
            maxLines: 5,
            onChanged: (value) => setState(() => _inputText = value),
          ),
          if (_inputText.isNotEmpty) ...[
            const SizedBox(height: 12),
            _QuickEstimate(text: _inputText, palette: palette),
            const SizedBox(height: 12),
            _TokenizationResultView(
              text: _inputText,
              tokenizer: settings.selectedTokenizer,
              palette: palette,
            ),
          ],
        ],
      ),
    );
  }

  /// Help in a bottom sheet.
  void _showHelpSheet(
    BuildContext context,
    TokenizerService service,
    CoreDialogPalette palette,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
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
              Text(
                '分词器帮助',
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeHeadline,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: DesignTokens.spaceMd),
              Text(
                service.getHelpText(),
                style: TextStyle(color: palette.textPrimary),
              ),
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

/// Quick estimate.
class _QuickEstimate extends ConsumerWidget {
  const _QuickEstimate({required this.text, required this.palette});

  final String text;
  final CoreDialogPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estimate = ref.watch(tokenCountEstimateProvider(text));

    return Row(
      children: [
        Icon(Icons.speed, color: palette.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick Estimate',
                style: TextStyle(fontSize: 12, color: palette.textSecondary),
              ),
              Text(
                '~$estimate tokens',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Text(
          '${text.length} chars',
          style: TextStyle(fontSize: 12, color: palette.textSecondary),
        ),
      ],
    );
  }
}

/// Tokenization result (statistics + details).
class _TokenizationResultView extends ConsumerWidget {
  const _TokenizationResultView({
    required this.text,
    required this.tokenizer,
    required this.palette,
  });

  final String text;
  final TokenizerType tokenizer;
  final CoreDialogPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = TokenizationRequest(text: text, tokenizer: tokenizer);
    final resultAsync = ref.watch(tokenizationResultProvider(request));

    return resultAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CupertinoActivityIndicator(),
        ),
      ),
      error: (error, _) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DesignTokens.statusError.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
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
          _StatisticsCard(result: result, palette: palette),
          const SizedBox(height: 12),
          _TokenVisualization(result: result, palette: palette),
        ],
      ),
    );
  }
}

/// Statistics card.
class _StatisticsCard extends ConsumerWidget {
  const _StatisticsCard({required this.result, required this.palette});

  final TokenizationResult result;
  final CoreDialogPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(tokenizerServiceProvider);
    final stats = service.getStatistics(result);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.fill.withValues(alpha: palette.isDark ? 0.55 : 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatItem(
                label: 'Total Tokens',
                value: result.tokenCount.toString(),
                icon: Icons.token,
                palette: palette,
              ),
              _StatItem(
                label: 'Unique',
                value: stats.uniqueTokens.toString(),
                icon: Icons.fingerprint,
                palette: palette,
              ),
              _StatItem(
                label: 'Chars/Token',
                value: result.charToTokenRatio.toStringAsFixed(2),
                icon: Icons.text_fields,
                palette: palette,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatItem(
                label: 'Avg Length',
                value: stats.avgTokenLength.toStringAsFixed(1),
                icon: Icons.straighten,
                palette: palette,
              ),
              _StatItem(
                label: 'Longest',
                value: '${stats.longestToken} chars',
                icon: Icons.expand,
                palette: palette,
              ),
              _StatItem(
                label: 'Shortest',
                value: '${stats.shortestToken} chars',
                icon: Icons.compress,
                palette: palette,
              ),
            ],
          ),
          if (stats.tokenFrequency.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Most Common Tokens',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
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
    );
  }

  String _escapeToken(String token) {
    return token
        .replaceAll('\n', '↵')
        .replaceAll('\t', '→')
        .replaceAll(' ', '␣');
  }
}

/// Single statistic item.
class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.palette,
  });

  final String label;
  final String value;
  final IconData icon;
  final CoreDialogPalette palette;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: palette.textSecondary),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: palette.textPrimary,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Token detail list.
class _TokenVisualization extends StatelessWidget {
  const _TokenVisualization({required this.result, required this.palette});

  final TokenizationResult result;
  final CoreDialogPalette palette;

  @override
  Widget build(BuildContext context) {
    if (result.tokens.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.fill.withValues(alpha: palette.isDark ? 0.55 : 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Token 明细 · ${result.tokens.length} tokens',
            style: TextStyle(fontSize: 12, color: palette.textSecondary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: result.tokens.asMap().entries.map((entry) {
              return _TokenChip(token: entry.value, index: entry.key);
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Single token chip.
class _TokenChip extends StatelessWidget {
  const _TokenChip({required this.token, required this.index});

  final Token token;
  final int index;

  @override
  Widget build(BuildContext context) {
    // Sample strip colors (see _kSampleColors at the top of the file).
    final color = _kSampleColors[index % _kSampleColors.length];

    return Tooltip(
      message: 'Token ID: ${token.id}\nLength: ${token.text.length} chars',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

/// Group container used inside the dialog.
class _Group extends StatelessWidget {
  const _Group({required this.palette, required this.children});

  final CoreDialogPalette palette;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color:
            palette.fill.withValues(alpha: palette.isDark ? 0.55 : 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: children),
    );
  }
}

/// Row with a trailing dropdown.
class _DropdownTile extends StatelessWidget {
  const _DropdownTile({
    required this.palette,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final CoreDialogPalette palette;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        TextStyle(fontSize: 15, color: palette.textPrimary)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: TextStyle(
                          fontSize: 12, color: palette.textSecondary)),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}
