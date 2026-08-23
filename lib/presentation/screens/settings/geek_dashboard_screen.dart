import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kirakira/presentation/providers/cfg_scale_providers.dart';
import 'package:kirakira/presentation/providers/settings_providers.dart';
import 'package:kirakira/presentation/widgets/common/kira_components.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/providers/vector_storage_providers.dart';
import 'package:kirakira/presentation/providers/logit_bias_providers.dart';
import 'package:kirakira/presentation/providers/tokenizer_providers.dart';

/// 极客Core 仪表盘（新版）
/// 结构分三层，便于持续扩展：
///   1. 直接可调区（_quickAdjustSection）—— 高频参数，滑块直接调
///   2. 快调卡区（_statusCardSection）—— 状态展示 + 简单开关，Wrap 错落排
///   3. 入口网格区（_entryGridSection）—— 必须独立页面的功能，紧凑网格跳转
class GeekDashboardScreen extends ConsumerWidget {
  const GeekDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('极客Core'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/settings'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          DesignTokens.spaceMd,
          DesignTokens.spaceSm,
          DesignTokens.spaceMd,
          DesignTokens.spaceXl,
        ),
        children: [
          _quickAdjustSection(context, ref),
          const SizedBox(height: DesignTokens.spaceLg),
          _statusCardSection(context, ref),
          const SizedBox(height: DesignTokens.spaceLg),
          _entryGridSection(context),
        ],
      ),
    );
  }

  // ── 第一层：采样参数大卡（高频，直接拖滑块）──
  Widget _quickAdjustSection(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final config = ref.watch(llmConfigProvider);

    return KiraSection(
      title: '采样参数',
      icon: Icons.tune,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceMd,
            vertical: DesignTokens.spaceXs,
          ),
          child: Column(
            children: [
              // ── 基础采样 ──
              _DashboardSlider(
                label: l10n.temperature,
                value: config.temperature,
                min: 0.0,
                max: 2.0,
                divisions: 40,
                onChanged: (v) =>
                    ref.read(llmConfigProvider.notifier).updateTemperature(v),
              ),
              _DashboardSlider(
                label: l10n.topPNucleusSampling,
                value: config.topP,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                onChanged: (v) =>
                    ref.read(llmConfigProvider.notifier).updateTopP(v),
              ),
              _DashboardSlider(
                label: l10n.topK,
                value: config.topK.toDouble(),
                min: 0,
                max: 200,
                divisions: 200,
                valueLabel: config.topK.toString(),
                onChanged: (v) =>
                    ref.read(llmConfigProvider.notifier).updateTopK(v.round()),
              ),
              // ── 高级采样（可折叠，默认收起）──
              _CollapsibleSection(
                label: '高级采样参数',
                children: [
                  _DashboardSlider(
                    label: l10n.minP,
                    value: config.minP,
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    onChanged: (v) =>
                        ref.read(llmConfigProvider.notifier).updateMinP(v),
                  ),
                  _DashboardSlider(
                    label: l10n.typicalP,
                    value: config.typicalP,
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    onChanged: (v) =>
                        ref.read(llmConfigProvider.notifier).updateTypicalP(v),
                  ),
                  _DashboardSlider(
                    label: l10n.topA,
                    value: config.topA,
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    onChanged: (v) =>
                        ref.read(llmConfigProvider.notifier).updateTopA(v),
                  ),
                  _DashboardSlider(
                    label: l10n.tailFreeSamplingTfs,
                    value: config.tailFreeSampling,
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    onChanged: (v) => ref
                        .read(llmConfigProvider.notifier)
                        .updateTailFreeSampling(v),
                  ),
                ],
              ),
              // ── 重复惩罚（折叠）──
              _CollapsibleSection(
                label: '重复惩罚',
                children: [
                  _DashboardSlider(
                    label: l10n.repetitionPenalty,
                    value: config.repetitionPenalty,
                    min: 1.0,
                    max: 2.0,
                    divisions: 20,
                    onChanged: (v) => ref
                        .read(llmConfigProvider.notifier)
                        .updateRepetitionPenalty(v),
                  ),
                  _DashboardSlider(
                    label: l10n.frequencyPenalty,
                    value: config.frequencyPenalty,
                    min: -2.0,
                    max: 2.0,
                    divisions: 40,
                    onChanged: (v) => ref
                        .read(llmConfigProvider.notifier)
                        .updateFrequencyPenalty(v),
                  ),
                  _DashboardSlider(
                    label: l10n.presencePenalty,
                    value: config.presencePenalty,
                    min: -2.0,
                    max: 2.0,
                    divisions: 40,
                    onChanged: (v) => ref
                        .read(llmConfigProvider.notifier)
                        .updatePresencePenalty(v),
                  ),
                ],
              ),
              // ── 生成控制（折叠，整数弹窗输入）──
              _CollapsibleSection(
                label: '生成控制',
                children: [
                  _IntInputRow(
                    label: l10n.maxTokens,
                    value: config.maxTokens,
                    onChanged: (v) =>
                        ref.read(llmConfigProvider.notifier).updateMaxTokens(v),
                  ),
                  _IntInputRow(
                    label: l10n.contextLength,
                    value: config.contextLength,
                    onChanged: (v) => ref
                        .read(llmConfigProvider.notifier)
                        .updateContextLength(v),
                  ),
                  _IntInputRow(
                    label: l10n.seed,
                    value: config.seed,
                    onChanged: (v) =>
                        ref.read(llmConfigProvider.notifier).updateSeed(v),
                  ),
                ],
              ),
              // Mirostat/停止序列/重复惩罚等冷门参数留子页面
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => context.push('/advanced-settings'),
                  icon: const Icon(Icons.more_horiz, size: 18),
                  label: const Text('更多采样参数'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 第二层：快调状态卡（Wrap 错落，半宽对称）──
  Widget _statusCardSection(BuildContext context, WidgetRef ref) {
    final cfgEnabled = ref.watch(isCFGActiveProvider);
    final ragEnabled = ref.watch(vectorStorageSettingsProvider).enabled;
    final config = ref.watch(llmConfigProvider);
    final screenWidth = MediaQuery.of(context).size.width - 24;
    final halfWidth = (screenWidth - 10) / 2;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        // CFG Scale（半宽，开关 + 进详细配置）
        _StatusCard(
          width: halfWidth,
          icon: Icons.speed,
          title: 'CFG Scale',
          subtitle: cfgEnabled ? '已启用' : '未启用',
          trailing: Switch(
            value: cfgEnabled,
            onChanged: (v) =>
                ref.read(cfgScaleSettingsProvider.notifier).setEnabled(v),
          ),
          onTap: () => context.push('/cfg-scale-settings'),
        ),
        // 向量 RAG（半宽，与 CFG 对称）
        _StatusCard(
          width: halfWidth,
          icon: Icons.storage,
          title: '向量 RAG',
          subtitle: ragEnabled ? '已启用' : '未启用',
          trailing: Switch(
            value: ragEnabled,
            onChanged: (v) => ref
                .read(vectorStorageSettingsProvider.notifier)
                .setEnabled(v),
          ),
          onTap: () => context.push('/vector-storage-settings'),
        ),
        // 流式输出（半宽，纯开关，无子页面）
        _StatusCard(
          width: halfWidth,
          icon: Icons.stream,
          title: '流式输出',
          subtitle: config.streamEnabled ? '实时显示' : '整段返回',
          trailing: Switch(
            value: config.streamEnabled,
            onChanged: (v) =>
                ref.read(llmConfigProvider.notifier).updateStreamEnabled(v),
          ),
        ),
        // 自动摘要（半宽，纯开关，无子页面）
        _StatusCard(
          width: halfWidth,
          icon: Icons.summarize,
          title: '自动摘要',
          subtitle: config.autoSummarizeEnabled ? '已启用' : '未启用',
          note: '长对话会额外消耗 API 额度',
          trailing: Switch(
            value: config.autoSummarizeEnabled,
            onChanged: (v) => ref
                .read(llmConfigProvider.notifier)
                .updateAutoSummarizeEnabled(v),
          ),
        ),
        _StatusCard(
          width: halfWidth,
          icon: Icons.exposure,
          title: 'Logit 偏置',
          subtitle: ref.watch(logitBiasSettingsProvider).enabled ? '已启用' : '未启用',
          trailing: Switch(
            value: ref.watch(logitBiasSettingsProvider).enabled,
            onChanged: (v) =>
                ref.read(logitBiasSettingsProvider.notifier).setEnabled(v),
          ),
          onTap: () => context.push('/logit-bias-settings'),
        ),
        // 分词器状态卡（半宽）
        _StatusCard(
          width: halfWidth,
          icon: Icons.text_fields,
          title: '分词器',
          subtitle: ref.watch(tokenizerSettingsProvider).showTokenCount
              ? '已启用计数'
              : '计数关闭',
          trailing: Switch(
            value: ref.watch(tokenizerSettingsProvider).showTokenCount,
            onChanged: (v) => ref
                .read(tokenizerSettingsProvider.notifier)
                .setShowTokenCount(v),
          ),
          onTap: () => context.push('/tokenizer-settings'),
        ),
      ],
    );
  }

  // ── 第三层：入口网格（必须独立页面的功能）──
  Widget _entryGridSection(BuildContext context) {
    const entries = <_GeekEntry>[
      _GeekEntry(Icons.tune, 'API 高级', '/advanced-settings'),
      _GeekEntry(Icons.auto_awesome, 'AI 预设', '/ai-presets'),
      _GeekEntry(Icons.reorder, '提示词管理', '/prompt-manager'),
      _GeekEntry(Icons.code, '正则系统', '/regex-settings'),
      _GeekEntry(Icons.storage, '向量 RAG', '/vector-storage-settings'),
      _GeekEntry(Icons.record_voice_over, 'TTS 合成', '/tts-settings'),
      _GeekEntry(Icons.mic, 'STT 识别', '/stt-settings'),
      _GeekEntry(Icons.translate, '翻译', '/translation-settings'),
      _GeekEntry(Icons.image, '图像生成', '/image-gen-settings'),
      _GeekEntry(Icons.emoji_emotions, '精灵图', '/sprite-settings'),
      _GeekEntry(Icons.data_object, '变量管理', '/variables-settings'),
      _GeekEntry(Icons.analytics, '日志统计', '/statistics'),
      _GeekEntry(Icons.extension, 'MVU 变量框架', '/mvu-settings'),
    ];

    return KiraSection(
      title: '全部功能',
      icon: Icons.apps,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (context, i) => _EntryTile(entry: entries[i]),
          ),
        ),
      ],
    );
  }
}

// ── 数据类 ──

class _GeekEntry {
  final IconData icon;
  final String label;
  final String route;
  const _GeekEntry(this.icon, this.label, this.route);
}

// ── 小组件 ──

class _EntryTile extends StatelessWidget {
  final _GeekEntry entry;
  const _EntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
      onTap: () => context.push(entry.route),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(entry.icon, size: 19, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 3),
          Text(
            entry.label,
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// 状态卡：半宽或全宽，显示功能状态 + 快速开关，点击进详细配置。
class _StatusCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? note;

  const _StatusCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : theme.dividerColor.withValues(alpha: 0.5),
            width: 0.8,
          ),
          boxShadow: isDark
              ? const []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 24,
                    spreadRadius: -4,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 4),
            Text(subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color
                        ?.withValues(alpha: 0.7))),
            if (note != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 11, color: theme.colorScheme.tertiary),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(note!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: theme.colorScheme.tertiary,
                        )),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 可折叠区域：默认收起，点标题展开内容。
class _CollapsibleSection extends StatefulWidget {
  final String label;
  final List<Widget> children;
  const _CollapsibleSection({required this.label, required this.children});

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(widget.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
        ),
        if (_expanded) ...widget.children,
      ],
    );
  }
}

/// 仪表盘紧凑滑块：标签 + 当前值同行，滑块紧贴，比 ListTile 更省高度。
class _DashboardSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String? valueLabel;
  final ValueChanged<double> onChanged;

  const _DashboardSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.valueLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500)),
            ),
            Text(
              valueLabel ?? value.toStringAsFixed(2),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
 }
/// 整数输入行：显示当前值，点击弹窗输入。用于 Token/上下文/种子这类精确整数。
class _IntInputRow extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _IntInputRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _showDialog(context),
      borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500)),
            ),
            Text(
              value.toString(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit, size: 14, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Future<void> _showDialog(BuildContext context) async {
    final controller = TextEditingController(text: value.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              Navigator.pop(ctx, parsed);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (result != null) onChanged(result);
  }
}