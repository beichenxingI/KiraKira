// lib/presentation/dialogs/chronicle_settings_dialog.dart
library;

import 'dart:math' show min;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/models/vector_storage.dart';
import 'package:kirakira/data/repositories/chronicle_repository.dart';
import 'package:kirakira/domain/services/llm_service.dart';
import 'package:kirakira/presentation/providers/chronicle_providers.dart';
import 'package:kirakira/presentation/providers/settings_providers.dart';
import 'package:kirakira/presentation/providers/vector_storage_providers.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/utils/kira_dialog.dart';
import 'core_dialog.dart';

Future<void> showChronicleSettingsDialog(BuildContext context, WidgetRef ref) {
  return showCoreDialog(
    context,
    barrierDismissible: false,
    builder: (_) => const _ChronicleSettingsDialog(),
  );
}

class _ChronicleSettingsDialog extends ConsumerStatefulWidget {
  const _ChronicleSettingsDialog();

  @override
  ConsumerState<_ChronicleSettingsDialog> createState() =>
      _ChronicleSettingsDialogState();
}

class _ChronicleSettingsDialogState
    extends ConsumerState<_ChronicleSettingsDialog> {
  bool _migrationChecked = false;
  final _suffixController = TextEditingController();
  // [修改三] 总结模型专属配置
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelNameController = TextEditingController();
  bool _isFetchingModels = false;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    // 首帧后检查迁移（避免浮窗构建期间弹第二层）
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkMigration());
  }

  @override
  void dispose() {
    _suffixController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelNameController.dispose();
    super.dispose();
  }

  // ═══════════════════ 迁移检查（修复四） ═══════════════════

  Future<void> _checkMigration() async {
    if (_migrationChecked || !mounted) return;
    _migrationChecked = true;

    final choiceNotifier = ref.read(chronicleMigrationChoiceProvider.notifier);
    final choice = ref.read(chronicleMigrationChoiceProvider);
    if (choice != null) return; // 已做过决定，不再弹

    final vs = ref.read(vectorStorageServiceProvider);
    if (!vs.hasLegacyVectors) {
      // 无旧数据：无需用户决定，标记已迁移（Chronicle默认开启）
      await choiceNotifier.setChoice('migrated');
      return;
    }

    // 有旧RAG数据 → 迁移选择弹窗（showKiraDialog带泛型返回值）
    final migrate = await showKiraDialog<bool>(
      context: context,
      dialog: const _MigrationDialog(),
      barrierDismissible: false,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.6),
    );
    if (!mounted || migrate == null) {
      // 被强制关闭视为"暂不开启"，避免反复弹
      await choiceNotifier.setChoice('kept');
      if (mounted) {
        ref.read(chronicleSettingsProvider.notifier).setEnabled(false);
      }
      return;
    }
    if (migrate) {
      // 开启Chronicle，删除旧向量（chronicle词条向量保留）
      await vs.removeLegacyVectors();
      await choiceNotifier.setChoice('migrated');
      if (mounted) {
        ref.read(chronicleSettingsProvider.notifier).setEnabled(true);
        coreToast(context, '旧向量数据已清理，Chronicle已开启');
      }
    } else {
      // 暂不开启，保留旧数据
      await choiceNotifier.setChoice('kept');
      if (mounted) {
        ref.read(chronicleSettingsProvider.notifier).setEnabled(false);
      }
    }
  }

  // ═══════════════════ [修改三] 获取模型列表 ═══════════════════

  Future<void> _fetchSummaryModels() async {
    final baseUrl = _baseUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();
    if (baseUrl.isEmpty || apiKey.isEmpty) {
      coreToast(context, '请先填写 Base URL 和 API Key');
      return;
    }
    setState(() => _isFetchingModels = true);
    try {
      final tempConfig = LLMConfig(
        provider: LLMProvider.openAICompatible,
        apiKey: apiKey,
        apiUrl: baseUrl,
        model: _modelNameController.text.trim(),
      );
      final models =
          await ref.read(llmServiceProvider).getAvailableModels(tempConfig);
      if (!mounted) return;
      if (models.isEmpty) {
        coreToast(context, '未拉取到模型，请检查地址和密钥');
        return;
      }
      _showModelSelectDialog(models);
    } catch (e) {
      if (mounted) coreToast(context, '拉取失败: $e');
    } finally {
      if (mounted) setState(() => _isFetchingModels = false);
    }
  }

  void _showModelSelectDialog(List<String> models) {
    final current = _modelNameController.text.trim();
    String? selected = models.contains(current) ? current : null;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setState) => Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: min(MediaQuery.of(ctx).size.width - 64, 400),
              constraints: const BoxConstraints(maxHeight: 480),
              decoration: BoxDecoration(
                color: Theme.of(ctx).brightness == Brightness.dark
                    ? const Color(0xFF1C1C1C)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '选择模型',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: const Icon(CupertinoIcons.xmark,
                              size: 22, color: Color(0xFF8C8C8C)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: models.length,
                      itemBuilder: (_, i) {
                        final m = models[i];
                        final isSel = m == selected;
                        return ListTile(
                          dense: true,
                          selected: isSel,
                          title: Text(m, style: const TextStyle(fontSize: 14)),
                          trailing: isSel
                              ? const Icon(Icons.check_circle_rounded,
                                  size: 20, color: DesignTokens.primary)
                              : null,
                          onTap: () {
                            setState(() => selected = m);
                            _modelNameController.text = m;
                            _modelNameController.selection =
                                TextSelection.fromPosition(
                              TextPosition(offset: m.length),
                            );
                            ref
                                .read(chronicleSettingsProvider.notifier)
                                .setSummaryModelName(m);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════ [修改二] 工作原理 WebView 浮窗 ═══════════════════

  Future<void> _showPrincipleWebView() async {
    // 注入实时数据：分段数/向量模型/词条累计/重试上限（原理页节点展示用）
    final cs = ref.read(chronicleSettingsProvider);
    final vs = ref.read(vectorStorageSettingsProvider);
    final embeddingLabel =
        vs.embeddingProvider == EmbeddingProvider.local
            ? '本地BGE 512维'
            : (vs.embeddingModel ?? vs.embeddingProvider.defaultModel);
    int entryCount = 0;
    try {
      entryCount = await ref.read(chronicleRepositoryProvider).countAllEntries();
    } catch (_) {}
    final html = _kPrincipleHtml
        .replaceAll('{passes}', '${cs.summaryPasses}')
        .replaceAll('{embedding_label}', embeddingLabel)
        .replaceAll('{entry_count}', '$entryCount')
        .replaceAll('{max_retries}', '${cs.maxRetries}');
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: min(MediaQuery.of(context).size.width - 32, 680),
            height: MediaQuery.of(context).size.height * 0.85,
            child: InAppWebView(
              initialData: InAppWebViewInitialData(
                data: html,
                mimeType: 'text/html',
                encoding: 'utf-8',
              ),
              initialSettings: InAppWebViewSettings(
                useHybridComposition: true,
                supportZoom: false,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CoreDialogPalette(isDark: isDark);
    final settings = ref.watch(chronicleSettingsProvider);

    // 控制器只在首次或外部变更时同步（避免覆盖用户正在输入的内容）
    if (_suffixController.text.isEmpty ||
        _suffixController.text == settings.customPromptSuffix) {
      _suffixController.text = settings.customPromptSuffix;
    }
    if (_baseUrlController.text.isEmpty && settings.summaryBaseUrl.isNotEmpty) {
      _baseUrlController.text = settings.summaryBaseUrl;
    }
    if (_apiKeyController.text.isEmpty && settings.summaryApiKey.isNotEmpty) {
      _apiKeyController.text = settings.summaryApiKey;
    }
    if (_modelNameController.text.isEmpty &&
        settings.summaryModelName.isNotEmpty) {
      _modelNameController.text = settings.summaryModelName;
    }

    final notifier = ref.read(chronicleSettingsProvider.notifier);

    return CoreDialogShell(
      title: 'Chronicle 超级记忆',
      icon: CupertinoIcons.book_fill,
      maxWidth: 550,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 状态行（修复五：明确显示当前开关状态）
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: (settings.enabled ? const Color(0xFF26A69A) : palette.fill)
                  .withValues(alpha: settings.enabled ? 0.15 : 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  settings.enabled
                      ? CupertinoIcons.checkmark_circle_fill
                      : CupertinoIcons.pause_circle_fill,
                  size: 16,
                  color: settings.enabled
                      ? const Color(0xFF26A69A)
                      : palette.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  settings.enabled ? 'Chronicle 运行中' : 'Chronicle 已关闭',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: settings.enabled
                        ? const Color(0xFF26A69A)
                        : palette.textSecondary,
                  ),
                ),
                const Spacer(),
                CupertinoSwitch(
                  value: settings.enabled,
                  onChanged: notifier.setEnabled,
                  activeTrackColor: const Color(0xFF26A69A),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // [修改二] 工作原理：可点击入口行 → WebView 浮窗
          CoreGroupBox(
            title: '工作原理',
            child: CoreTile(
              title: '查看 Chronicle 工作原理',
              subtitle: '三方案对比 · 三窗口淡出 · 为什么可以永久记忆',
              onTap: _showPrincipleWebView,
            ),
          ),
          const SizedBox(height: 12),
          CoreGroupBox(
            title: '触发设置',
            child: Column(
              children: [
                CoreSliderRow(
                  label: '总结触发间隔（对话轮次）',
                  value: settings.summaryInterval.toDouble(),
                  min: 10,
                  max: 40,
                  divisions: 30,
                  display: '${settings.summaryInterval} 轮',
                  onChanged: (v) => notifier.setSummaryInterval(v.round()),
                ),
                CoreSliderRow(
                  label: 'Token压力阈值',
                  value: settings.tokenPressureThreshold,
                  min: 0.4,
                  max: 0.8,
                  divisions: 8,
                  display: '${(settings.tokenPressureThreshold * 100).round()}%',
                  onChanged: notifier.setTokenPressureThreshold,
                ),
                CoreSliderRow(
                  label: '总结精度（分段次数）',
                  value: settings.summaryPasses.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  display: '${settings.summaryPasses} 段（${settings.summaryPasses}次LLM调用）',
                  onChanged: (v) => notifier.setSummaryPasses(v.round()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CoreGroupBox(
            title: '窗口设置',
            child: Column(
              children: [
                CoreSliderRow(
                  label: '窗口大小（每区保留轮次）',
                  value: settings.hotWindowSize.toDouble(),
                  min: 10,
                  max: 40,
                  divisions: 30,
                  display: '${settings.hotWindowSize} 轮（热/温/冷各 ${settings.hotWindowSize}共 ${settings.hotWindowSize * 3} 轮）',
                  onChanged: (v) => notifier.setHotWindowSize(v.round()),
                ),
                CoreSliderRow(
                  label: '召回数量（top K）',
                  value: settings.ragTopK.toDouble(),
                  min: 3,
                  max: 10,
                  divisions: 7,
                  display: '${settings.ragTopK} 条',
                  onChanged: (v) => notifier.setRagTopK(v.round()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // [修改三] 总结模型：完整模型配置区（BaseURL/APIKey/获取模型/模型名）
          CoreGroupBox(
            title: '总结模型',
            trailing: Text(
              settings.summaryUsesMainModel ? '沿用主模型' : '专属模型',
              style: TextStyle(
                fontSize: 11,
                color: settings.summaryUsesMainModel
                    ? palette.textSecondary
                    : const Color(0xFF26A69A),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoreTextField(
                  controller: _baseUrlController,
                  palette: palette,
                  hint: 'Base URL（留空 = 沿用主模型）',
                  keyboardType: TextInputType.url,
                  onChanged: (v) => notifier.setSummaryBaseUrl(v.trim()),
                ),
                const SizedBox(height: 8),
                CoreTextField(
                  controller: _apiKeyController,
                  palette: palette,
                  hint: 'API Key（留空 = 沿用主模型）',
                  obscureText: _obscureApiKey,
                  suffix: GestureDetector(
                    onTap: () =>
                        setState(() => _obscureApiKey = !_obscureApiKey),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        _obscureApiKey
                            ? CupertinoIcons.eye
                            : CupertinoIcons.eye_slash,
                        size: 18,
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                  onChanged: (v) => notifier.setSummaryApiKey(v.trim()),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: CoreSecondaryButton(
                    label: _isFetchingModels ? '获取中…' : '获取模型列表',
                    icon: CupertinoIcons.cloud_download,
                    isLoading: _isFetchingModels,
                    onPressed: _fetchSummaryModels,
                    expanded: false,
                  ),
                ),
                const SizedBox(height: 8),
                CoreTextField(
                  controller: _modelNameController,
                  palette: palette,
                  hint: '模型名（留空 = 沿用主模型，推荐小模型省token）',
                  onChanged: (v) => notifier.setSummaryModelName(v.trim()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CoreGroupBox(
            title: '高级选项',
            child: Column(
              children: [
                CoreSwitchRow(
                  title: '情感召回加成',
                  subtitle: '活跃情感关联的实体事件召回加权',
                  value: settings.emotionRecallEnabled,
                  onChanged: notifier.setEmotionRecallEnabled,
                ),
                CoreSwitchRow(
                  title: 'MVU 桥接',
                  subtitle: 'MVU数值重大变化(±20)自动记录为记忆事件；Chronicle只读不回写',
                  value: settings.mvuBridgeEnabled,
                  onChanged: notifier.setMvuBridgeEnabled,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CoreGroupBox(
            title: '自定义提示词追加',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoreTextField(
                  controller: _suffixController,
                  palette: palette,
                  hint: '基础模板已内置，这里只写补充内容。例如：重点保留承诺与欠债',
                  maxLines: 3,
                  minLines: 2,
                  onChanged: notifier.setCustomPromptSuffix,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 迁移选择弹窗（修复四）：有旧RAG数据且用户未做过决定时弹出
class _MigrationDialog extends ConsumerWidget {
  const _MigrationDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CoreDialogPalette(isDark: isDark);

    return CoreDialogShell(
      title: '检测到旧版向量数据',
      icon: CupertinoIcons.exclamationmark_triangle_fill,
      maxWidth: 550,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '您有使用旧版RAG向量存储的数据。Chronicle超级记忆使用全新架构，'
            '旧数据与新系统不兼容。',
            style: TextStyle(fontSize: 14, color: palette.textPrimary),
          ),
          const SizedBox(height: 16),
          CoreInfoRow(
            icon: CupertinoIcons.trash,
            title: '开启Chronicle，删除旧数据',
            text: '删除旧向量数据，启用Chronicle超级记忆。新的记忆将在对话中自动积累。',
            palette: palette,
          ),
          CoreInfoRow(
            icon: CupertinoIcons.pause_circle,
            title: '暂不开启，保留旧数据',
            text: '保留旧向量数据，Chronicle保持关闭。可随时在设置中重新选择。',
            palette: palette,
          ),
        ],
      ),
      footer: CoreDialogFooter(
        child: Column(
          children: [
            CoreDangerButton(
              label: '开启Chronicle，删除旧数据',
              onPressed: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 8),
            CoreSecondaryButton(
              label: '暂不开启，保留旧数据',
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
  }
}

/// [修改二] Chronicle 工作原理 HTML（内联，无网络依赖）
/// {passes}/{embedding_label}/{entry_count}/{max_retries} 由Dart注入实时数据
const String _kPrincipleHtml = r'''<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Chronicle 工作原理</title>
<style>
  :root {
    --kira-bg-1: #0F1115;
    --kira-bg-2: #161A22;
    --kira-bg-3: #20242C;
    --kira-text-1: #F5F7FA;
    --kira-text-2: #C8CDD6;
    --kira-text-3: #8A8A8A;
    --blue: #4A9EFF;
    --green: #52C41A;
    --red: #FF4D4F;
    --orange: #FA8C16;
    --border: rgba(255,255,255,0.08);
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    background: var(--kira-bg-1);
    color: var(--kira-text-1);
    font-family: 'PingFang SC', 'Microsoft YaHei', sans-serif;
    font-size: 13px;
    line-height: 1.7;
    padding: 24px 18px 48px;
  }

  @keyframes fadeInUp {
    from { opacity: 0; transform: translateY(12px); }
    to { opacity: 1; transform: translateY(0); }
  }
  .anim { animation: fadeInUp .3s ease-out both; }
  .d1 { animation-delay: .05s; }
  .d2 { animation-delay: .12s; }
  .d3 { animation-delay: .19s; }
  .d4 { animation-delay: .26s; }
  .d5 { animation-delay: .33s; }

  .section-title {
    font-size: 14px;
    font-weight: 600;
    margin: 26px 0 12px;
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .section-title::before {
    content: '';
    width: 3px;
    height: 14px;
    border-radius: 2px;
    background: var(--blue);
    flex-shrink: 0;
  }
  @media (hover: hover) {
    .lift { transition: transform .2s ease, box-shadow .2s ease; }
    .lift:hover { transform: translateY(-2px); box-shadow: 0 8px 24px rgba(0,0,0,.35); }
  }

  .chronicle-hero { text-align: center; padding: 12px 0 4px; }
  .hero-icon { width: 48px; height: 48px; margin-bottom: 10px; }
  .chronicle-hero h2 { font-size: 14px; font-weight: 600; letter-spacing: .06em; }
  .hero-subtitle { color: var(--kira-text-3); font-size: 12px; margin-top: 6px; }

  .pipeline-svg { width: 100%; height: auto; display: block; }
  .pipeline-line {
    stroke: var(--blue);
    stroke-width: 2;
    stroke-dasharray: 6 4;
    animation: flowDash 1.5s linear infinite;
  }
  .pipeline-line.thin { stroke-width: 1.5; }
  @keyframes flowDash { to { stroke-dashoffset: -10; } }
  .node-circle { fill: var(--kira-bg-3); stroke-width: 2.5; }
  .node-pending { stroke: #666666; }
  .node-running { stroke: var(--blue); animation: pulse 1.2s ease-in-out infinite; will-change: stroke-opacity; }
  .node-done { stroke: var(--green); }
  .node-failed { stroke: var(--red); }
  @keyframes pulse { 0%, 100% { stroke-opacity: .5; } 50% { stroke-opacity: 1; } }
  .node-icon { fill: none; stroke: var(--kira-text-2); stroke-width: 2; stroke-linecap: round; stroke-linejoin: round; }
  .node-label { fill: var(--kira-text-1); font-size: 13px; font-weight: 600; text-anchor: middle; }
  .node-badge { fill: var(--blue); font-size: 11px; font-weight: 600; text-anchor: middle; font-family: monospace; }
  .node-sub { fill: var(--kira-text-3); font-size: 11px; text-anchor: middle; }
  .node-desc-grid {
    display: grid;
    grid-template-columns: repeat(5, 1fr);
    gap: 8px;
    margin-top: 8px;
    font-size: 12px;
    color: var(--kira-text-3);
    line-height: 1.5;
  }

  details.tl-collapse {
    border: 1px solid var(--border);
    border-radius: 10px;
    background: var(--kira-bg-2);
    margin-top: 14px;
    overflow: hidden;
  }
  details.tl-collapse summary {
    padding: 10px 14px;
    cursor: pointer;
    font-size: 13px;
    font-weight: 600;
    list-style: none;
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  details.tl-collapse summary::-webkit-details-marker { display: none; }
  .tl-arrow { color: var(--kira-text-3); font-size: 12px; transition: transform .2s; }
  details[open] .tl-arrow { transform: rotate(-90deg); }
  .timeline { padding: 2px 16px 14px 16px; border-top: 1px solid var(--border); }
  .tl-item { position: relative; padding: 7px 0 7px 20px; font-size: 12px; color: var(--kira-text-2); }
  .tl-item::before {
    content: '';
    position: absolute;
    left: 3px; top: 0; bottom: 0;
    width: 1px;
    background: var(--border);
  }
  .tl-dot {
    position: absolute;
    left: 0; top: 13px;
    width: 7px; height: 7px;
    border-radius: 50%;
    background: var(--kira-bg-3);
    border: 1.5px solid #666666;
  }
  .tl-dot.dot-blue { border-color: var(--blue); }
  .tl-dot.dot-green { border-color: var(--green); }
  .tl-item b { color: var(--kira-text-1); font-family: monospace; font-weight: 600; }

  .compare-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
  .compare-card {
    background: var(--kira-bg-2);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 14px;
  }
  .compare-card.good-card { border-color: rgba(82,196,26,.35); }
  .card-head { display: flex; align-items: center; gap: 8px; margin-bottom: 10px; }
  .st-ic { width: 16px; height: 16px; flex-shrink: 0; }
  .card-title { font-size: 14px; font-weight: 600; }
  .pc-list { list-style: none; font-size: 12px; color: var(--kira-text-2); }
  .pc-list li { position: relative; padding: 3px 0 3px 14px; }
  .pc-list li::before {
    content: '';
    position: absolute;
    left: 2px; top: 11px;
    width: 5px; height: 5px;
    border-radius: 50%;
    background: var(--kira-text-3);
  }
  .kw-demo, .vec-demo {
    margin-top: 12px;
    padding: 10px 12px;
    background: var(--kira-bg-3);
    border-radius: 8px;
  }
  .kw-line { display: flex; align-items: center; gap: 8px; font-size: 12px; }
  .kw { padding: 2px 8px; border-radius: 4px; font-family: monospace; }
  .kw-bad { background: rgba(255,77,79,.2); color: var(--red); }
  .kw-arrow { color: #666666; }
  .kw-miss { color: var(--red); display: inline-flex; align-items: center; gap: 4px; }
  .kw-miss .st-ic { width: 12px; height: 12px; }
  .kw-explain, .vec-explain { font-size: 11px; color: var(--kira-text-3); margin-top: 6px; }
  .vec-vis { width: 100%; max-width: 220px; height: auto; display: block; margin-top: 8px; }
  .vec-line { stroke-width: 2; stroke-linecap: round; }
  .vec-label { fill: var(--green); font-size: 12px; font-weight: 600; font-family: monospace; }
  .recall-flow {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 4px;
    margin-top: 12px;
    padding: 10px 12px;
    background: var(--kira-bg-3);
    border-radius: 8px;
  }
  .rf-step {
    font-size: 11px;
    color: var(--kira-text-2);
    background: rgba(255,255,255,.05);
    border: 1px solid var(--border);
    border-radius: 6px;
    padding: 3px 8px;
    white-space: nowrap;
  }
  .rf-step.rf-hot { color: var(--blue); border-color: rgba(74,158,255,.4); }
  .rf-conn { width: 18px; height: 8px; flex-shrink: 0; }

  .cmp-table { border: 1px solid var(--border); border-radius: 12px; overflow: hidden; }
  .cmp-row {
    display: grid;
    grid-template-columns: .8fr 1fr 1.1fr 1.2fr;
    font-size: 12px;
    color: var(--kira-text-2);
    border-top: 1px solid var(--border);
    align-items: stretch;
  }
  .cmp-row:first-child { border-top: none; }
  .cmp-row > div { padding: 9px 10px; }
  .cmp-row.cmp-head { background: var(--kira-bg-3); font-weight: 600; color: var(--kira-text-1); }
  .cmp-dim { color: var(--kira-text-1); font-weight: 600; }
  .cmp-hl { background: rgba(74,158,255,.10); }
  .cmp-row.cmp-head .cmp-hl { color: var(--blue); }
  .cmp-cell .st-ic { width: 13px; height: 13px; }
  .m-label { display: none; }
  @media (hover: hover) {
    .cmp-row:not(.cmp-head):hover { background: rgba(74,158,255,.06); }
    .cmp-row:not(.cmp-head):hover .cmp-hl { background: rgba(74,158,255,.16); }
  }

  .guarantee-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
  .guarantee-item {
    background: var(--kira-bg-2);
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 12px;
  }
  .g-icon {
    width: 20px; height: 20px;
    stroke: var(--blue); fill: none;
    stroke-width: 2; stroke-linecap: round; stroke-linejoin: round;
    margin-bottom: 6px;
  }
  .g-title { font-size: 13px; font-weight: 600; margin-bottom: 3px; }
  .g-desc { font-size: 12px; color: var(--kira-text-3); line-height: 1.5; }

  @media (max-width: 700px) {
    .compare-grid, .guarantee-grid { grid-template-columns: 1fr; }
    .cmp-row { grid-template-columns: 1fr; }
    .cmp-row.cmp-head { display: none; }
    .cmp-row > div { padding: 6px 12px; }
    .cmp-hl { border-left: 2px solid var(--blue); }
    .m-label {
      display: inline-block;
      font-size: 11px;
      color: var(--kira-text-3);
      margin-right: 4px;
    }
    .node-desc-grid { grid-template-columns: 1fr 1fr; }
  }
</style>
</head>
<body>

<svg width="0" height="0" style="position:absolute">
  <defs>
    <symbol id="ic-ok" viewBox="0 0 24 24">
      <path d="M20 6 9 17l-5-5" fill="none" stroke="#52C41A" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
    </symbol>
    <symbol id="ic-bad" viewBox="0 0 24 24">
      <path d="M18 6 6 18M6 6l12 12" fill="none" stroke="#FF4D4F" stroke-width="2" stroke-linecap="round"/>
    </symbol>
    <symbol id="ic-warn" viewBox="0 0 24 24">
      <path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" fill="none" stroke="#FA8C16" stroke-width="2" stroke-linejoin="round"/>
      <line x1="12" y1="9" x2="12" y2="13" stroke="#FA8C16" stroke-width="2" stroke-linecap="round"/>
      <line x1="12" y1="17" x2="12.01" y2="17" stroke="#FA8C16" stroke-width="2" stroke-linecap="round"/>
    </symbol>
    <symbol id="ic-na" viewBox="0 0 24 24">
      <line x1="6" y1="12" x2="18" y2="12" stroke="#8A8A8A" stroke-width="2" stroke-linecap="round"/>
    </symbol>
  </defs>
</svg>

<div class="chronicle-hero anim d1">
  <svg class="hero-icon" viewBox="0 0 48 48">
    <path d="M8 10 L8 38 L20 38 L20 10 Z" stroke="#4A9EFF" fill="none" stroke-width="2"/>
    <path d="M28 10 L28 38 L40 38 L40 10 Z" stroke="#52C41A" fill="none" stroke-width="2"/>
    <path d="M10 16 L18 16 M10 20 L18 20 M10 24 L18 24" stroke="#666666" stroke-width="1.5"/>
    <path d="M30 16 L38 16 M30 20 L38 20 M30 24 L38 24" stroke="#666666" stroke-width="1.5"/>
  </svg>
  <h2>Chronicle 超级记忆原理</h2>
  <p class="hero-subtitle">语义向量召回 × 渐进式提炼 × 永久记忆 = 真正的长会话解决方案</p>
</div>

<div class="section-title anim d1">完整工作流</div>
<div class="card anim d2 lift" style="background:var(--kira-bg-2);border:1px solid var(--border);border-radius:12px;padding:16px;">
  <svg class="pipeline-svg" viewBox="0 0 800 150">
    <line x1="100" y1="58" x2="220" y2="58" class="pipeline-line"/>
    <line x1="260" y1="58" x2="380" y2="58" class="pipeline-line"/>
    <line x1="420" y1="58" x2="540" y2="58" class="pipeline-line"/>
    <line x1="580" y1="58" x2="700" y2="58" class="pipeline-line"/>

    <circle cx="80" cy="58" r="20" class="node-circle node-pending"/>
    <circle cx="240" cy="58" r="20" class="node-circle node-running"/>
    <circle cx="400" cy="58" r="20" class="node-circle node-running"/>
    <circle cx="560" cy="58" r="20" class="node-circle node-done"/>
    <circle cx="720" cy="58" r="20" class="node-circle node-done"/>

    <g transform="translate(70,48) scale(0.8333)">
      <title>消息溢出：热区装不下的最早一批消息进入待归档集合（按轮次或token压力触发）</title>
      <path class="node-icon" d="m12.83 2.18a2 2 0 0 0-1.66 0L2.6 6.08a1 1 0 0 0 0 1.83l8.58 3.91a2 2 0 0 0 1.66 0l8.58-3.9a1 1 0 0 0 0-1.83Z"/>
      <path class="node-icon" d="m22 17.65-9.17 4.16a2 2 0 0 1-1.66 0L2 17.65"/>
      <path class="node-icon" d="m22 12.65-9.17 4.16a2 2 0 0 1-1.66 0L2 12.65"/>
    </g>
    <g transform="translate(230,48) scale(0.8333)">
      <title>入队：异步任务队列，30秒轮询+单飞守卫，绝不阻塞对话</title>
      <line class="node-icon" x1="8" y1="6" x2="21" y2="6"/>
      <line class="node-icon" x1="8" y1="12" x2="21" y2="12"/>
      <line class="node-icon" x1="8" y1="18" x2="21" y2="18"/>
      <line class="node-icon" x1="3" y1="6" x2="3.01" y2="6"/>
      <line class="node-icon" x1="3" y1="12" x2="3.01" y2="12"/>
      <line class="node-icon" x1="3" y1="18" x2="3.01" y2="18"/>
    </g>
    <text x="400" y="26" class="node-badge">{passes}-pass</text>
    <g transform="translate(390,48) scale(0.8333)">
      <title>一次性总结易遗漏细节，分{passes}段渐进式提炼保证质量；某段JSON解析失败自动降级兜底</title>
      <circle class="node-icon" cx="6" cy="6" r="3"/>
      <path class="node-icon" d="M8.12 8.12 12 13"/>
      <path class="node-icon" d="M20 4 8.12 8.12"/>
      <path class="node-icon" d="M14.8 14.8 20 20"/>
      <path class="node-icon" d="M8.12 15.88 12 11"/>
      <circle class="node-icon" cx="6" cy="18" r="3"/>
    </g>
    <g transform="translate(550,48) scale(0.8333)">
      <title>词条向量化入库，与RAG原文向量共存，供语义召回</title>
      <circle class="node-icon" cx="18" cy="5" r="3"/>
      <circle class="node-icon" cx="6" cy="12" r="3"/>
      <circle class="node-icon" cx="18" cy="19" r="3"/>
      <line class="node-icon" x1="8.59" y1="13.51" x2="15.42" y2="17.49"/>
      <line class="node-icon" x1="15.41" y1="6.51" x2="8.59" y2="10.49"/>
    </g>
    <g transform="translate(710,48) scale(0.8333)">
      <title>词条/实体/关系/情感增量upsert，原文标记归档（可随时取消归档回滚）</title>
      <ellipse class="node-icon" cx="12" cy="5" rx="9" ry="3"/>
      <path class="node-icon" d="M3 5V19A9 3 0 0 0 21 19V5"/>
      <path class="node-icon" d="M3 12A9 3 0 0 0 21 12"/>
    </g>

    <text x="80" y="102" class="node-label">消息溢出</text>
    <text x="240" y="102" class="node-label">入队</text>
    <text x="400" y="102" class="node-label">分段总结</text>
    <text x="560" y="102" class="node-label">向量化</text>
    <text x="720" y="102" class="node-label">入库</text>
    <text x="560" y="120" class="node-sub">{embedding_label}</text>
    <text x="720" y="120" class="node-sub">累计 {entry_count} 条词条</text>
  </svg>
  <div class="node-desc-grid">
    <div>热区装不下的最早一批消息进入待归档集合</div>
    <div>异步任务队列，轮询消费+单飞守卫</div>
    <div>专属模型分{passes}段渐进提炼，失败降级兜底</div>
    <div>词条向量化，供语义召回使用</div>
    <div>词条/实体/关系增量更新，原文标记归档</div>
  </div>

  <details class="tl-collapse">
    <summary>长会话的实际工作流（默认参数示例）<span class="tl-arrow">▾</span></summary>
    <div class="timeline">
      <div class="tl-item"><span class="tl-dot"></span><div><b>第1-20轮</b>：热区全量注入（最近原文，注意力最强位）</div></div>
      <div class="tl-item"><span class="tl-dot dot-blue"></span><div><b>第21轮</b>：触发总结 → 分{passes}段提炼产出词条 → 第1-20轮归档并向量化</div></div>
      <div class="tl-item"><span class="tl-dot"></span><div><b>第21-40轮</b>：热区全量注入</div></div>
      <div class="tl-item"><span class="tl-dot dot-blue"></span><div><b>第41轮</b>：再次触发总结 → 新词条增量更新 → 第21-40轮归档</div></div>
      <div class="tl-item"><span class="tl-dot"></span><div>循环往复，词条库持续增量更新，token占用稳定不膨胀</div></div>
      <div class="tl-item"><span class="tl-dot dot-green"></span><div><b>千轮处</b>：热区仍只保留最近20轮原文 + 语义召回最相关5条历史词条（锚点词条始终注入），上下文稳定</div></div>
    </div>
  </details>
</div>

<div class="section-title anim d2">语义召回 vs 关键词匹配</div>
<div class="compare-grid anim d3">
  <div class="compare-card lift">
    <div class="card-head">
      <svg class="st-ic"><use href="#ic-bad"/></svg>
      <span class="card-title">传统关键词匹配</span>
    </div>
    <ul class="pc-list">
      <li>用户说"树林"，词条写"森林" → 漏召回</li>
      <li>关键词"长伊"出现100次，无法判断哪条最相关</li>
      <li>同义词、上下位词无法识别</li>
    </ul>
    <div class="kw-demo">
      <div class="kw-line">
        <span class="kw kw-bad">森林</span>
        <span class="kw-arrow">→</span>
        <span class="kw-miss"><svg class="st-ic"><use href="#ic-bad"/></svg>未匹配</span>
      </div>
      <div class="kw-explain">关键词表里没有"树林"，错过召回</div>
    </div>
  </div>
  <div class="compare-card good-card lift">
    <div class="card-head">
      <svg class="st-ic"><use href="#ic-ok"/></svg>
      <span class="card-title">语义向量召回</span>
    </div>
    <ul class="pc-list">
      <li>向量空间中"树林"与"森林"余弦相似度0.91 → 自动召回</li>
      <li>根据当前话题语义，只召回最相关的条目（topK）</li>
      <li>理解"疲惫"与"受伤"的关联，跨词汇召回</li>
    </ul>
    <div class="vec-demo">
      <svg viewBox="0 0 100 60" class="vec-vis">
        <line x1="10" y1="30" x2="50" y2="20" class="vec-line" stroke="#52C41A"/>
        <line x1="10" y1="30" x2="48" y2="22" class="vec-line" stroke="#4A9EFF"/>
        <text x="55" y="25" class="vec-label">0.91</text>
      </svg>
      <div class="vec-explain">两条向量夹角越小，余弦相似度越高，自动召回</div>
    </div>
    <div class="recall-flow">
      <span class="rf-step">用户消息</span>
      <svg class="rf-conn" viewBox="0 0 24 8"><line x1="1" y1="4" x2="23" y2="4" class="pipeline-line thin"/></svg>
      <span class="rf-step">embedding</span>
      <svg class="rf-conn" viewBox="0 0 24 8"><line x1="1" y1="4" x2="23" y2="4" class="pipeline-line thin"/></svg>
      <span class="rf-step">相似度计算</span>
      <svg class="rf-conn" viewBox="0 0 24 8"><line x1="1" y1="4" x2="23" y2="4" class="pipeline-line thin"/></svg>
      <span class="rf-step">topK排序</span>
      <svg class="rf-conn" viewBox="0 0 24 8"><line x1="1" y1="4" x2="23" y2="4" class="pipeline-line thin"/></svg>
      <span class="rf-step rf-hot">注入</span>
    </div>
  </div>
</div>

<div class="section-title anim d3">三方案对比</div>
<div class="cmp-table anim d4">
  <div class="cmp-row cmp-head">
    <div>维度</div>
    <div>全量上下文注入</div>
    <div>长记忆条目总结</div>
    <div class="cmp-hl">Chronicle 超级记忆</div>
  </div>
  <div class="cmp-row" title="信息保留：Chronicle按事件/状态/知识/实体/关系多维度建词条，信息密度高">
    <div class="cmp-dim">信息保留</div>
    <div class="cmp-cell"><span class="m-label">全量注入</span><svg class="st-ic"><use href="#ic-ok"/></svg> 原文完整</div>
    <div class="cmp-cell"><span class="m-label">长记忆总结</span><svg class="st-ic"><use href="#ic-bad"/></svg> 压缩成一条，细节丢失</div>
    <div class="cmp-cell cmp-hl"><span class="m-label">Chronicle</span><svg class="st-ic"><use href="#ic-ok"/></svg> 结构化多维词条，信息密度高</div>
  </div>
  <div class="cmp-row" title="token消耗：默认参数下热区20轮+召回5条约5000token，不随轮数增长">
    <div class="cmp-dim">token消耗</div>
    <div class="cmp-cell"><span class="m-label">全量注入</span><svg class="st-ic"><use href="#ic-bad"/></svg> 轮数越多token线性增长</div>
    <div class="cmp-cell"><span class="m-label">长记忆总结</span><svg class="st-ic"><use href="#ic-warn"/></svg> 单条约500token，累积仍会膨胀</div>
    <div class="cmp-cell cmp-hl"><span class="m-label">Chronicle</span><svg class="st-ic"><use href="#ic-ok"/></svg> 热区20轮+召回5条，约5000token</div>
  </div>
  <div class="cmp-row" title="时序理解：词条content以[第N轮]开头，注入按turnIndex升序">
    <div class="cmp-dim">时序理解</div>
    <div class="cmp-cell"><span class="m-label">全量注入</span><svg class="st-ic"><use href="#ic-ok"/></svg> 原文有顺序</div>
    <div class="cmp-cell"><span class="m-label">长记忆总结</span><svg class="st-ic"><use href="#ic-bad"/></svg> 单条压缩无时序</div>
    <div class="cmp-cell cmp-hl"><span class="m-label">Chronicle</span><svg class="st-ic"><use href="#ic-ok"/></svg> 每条词条带[第N轮]标记</div>
  </div>
  <div class="cmp-row" title="长会话应对：词条只增量更新不膨胀，上下文窗口稳定">
    <div class="cmp-dim">长会话应对</div>
    <div class="cmp-cell"><span class="m-label">全量注入</span><svg class="st-ic"><use href="#ic-bad"/></svg> 对话一长必爆上下文</div>
    <div class="cmp-cell"><span class="m-label">长记忆总结</span><svg class="st-ic"><use href="#ic-bad"/></svg> 条目累积后仍会顶爆</div>
    <div class="cmp-cell cmp-hl"><span class="m-label">Chronicle</span><svg class="st-ic"><use href="#ic-ok"/></svg> 千轮只注入热区+召回，稳定运行</div>
  </div>
  <div class="cmp-row" title="召回精度：混合语义0.5+关键词0.2+时间0.1+情感0.1+重要度0.1打分，取topK">
    <div class="cmp-dim">召回精度</div>
    <div class="cmp-cell"><span class="m-label">全量注入</span><svg class="st-ic"><use href="#ic-na"/></svg> 全量注入，无召回概念</div>
    <div class="cmp-cell"><span class="m-label">长记忆总结</span><svg class="st-ic"><use href="#ic-bad"/></svg> 条目平铺，模型难分辨</div>
    <div class="cmp-cell cmp-hl"><span class="m-label">Chronicle</span><svg class="st-ic"><use href="#ic-ok"/></svg> 语义相似度排序，只注入最相关条目</div>
  </div>
  <div class="cmp-row" title="失败影响：JSON解析失败降级纯文本词条；失败任务退避重试">
    <div class="cmp-dim">失败影响</div>
    <div class="cmp-cell"><span class="m-label">全量注入</span><svg class="st-ic"><use href="#ic-na"/></svg> 无总结环节</div>
    <div class="cmp-cell"><span class="m-label">长记忆总结</span><svg class="st-ic"><use href="#ic-bad"/></svg> 总结失败即丢信息</div>
    <div class="cmp-cell cmp-hl"><span class="m-label">Chronicle</span><svg class="st-ic"><use href="#ic-ok"/></svg> fallback兜底+分段重试</div>
  </div>
  <div class="cmp-row" title="后台运行：30秒轮询+单飞守卫，LLM调用为IO等待不阻塞UI">
    <div class="cmp-dim">后台运行</div>
    <div class="cmp-cell"><span class="m-label">全量注入</span><svg class="st-ic"><use href="#ic-na"/></svg> 同步等待</div>
    <div class="cmp-cell"><span class="m-label">长记忆总结</span><svg class="st-ic"><use href="#ic-warn"/></svg> 阻塞主流程</div>
    <div class="cmp-cell cmp-hl"><span class="m-label">Chronicle</span><svg class="st-ic"><use href="#ic-ok"/></svg> 异步队列，静默处理</div>
  </div>
  <div class="cmp-row" title="可维护性：记忆库面板可查看/编辑/重新总结/全量重建">
    <div class="cmp-dim">可维护性</div>
    <div class="cmp-cell"><span class="m-label">全量注入</span><svg class="st-ic"><use href="#ic-bad"/></svg> 原文不可编辑</div>
    <div class="cmp-cell"><span class="m-label">长记忆总结</span><svg class="st-ic"><use href="#ic-warn"/></svg> 单条修改困难</div>
    <div class="cmp-cell cmp-hl"><span class="m-label">Chronicle</span><svg class="st-ic"><use href="#ic-ok"/></svg> 词条可查看/编辑/重新总结</div>
  </div>
</div>

<div class="section-title anim d4">四大保证</div>
<div class="guarantee-grid anim d5">
  <div class="guarantee-item lift">
    <svg class="g-icon" viewBox="0 0 24 24"><path d="M11 5 6 9H2v6h4l5 4V5z"/><line x1="22" y1="9" x2="16" y2="15"/><line x1="16" y1="9" x2="22" y2="15"/></svg>
    <div class="g-title">后台静音</div>
    <div class="g-desc">总结任务异步执行，不阻塞对话，失败不弹窗</div>
  </div>
  <div class="guarantee-item lift">
    <svg class="g-icon" viewBox="0 0 24 24"><path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/></svg>
    <div class="g-title">降级兜底</div>
    <div class="g-desc">JSON解析失败自动降级为纯文本词条，信息不丢失</div>
  </div>
  <div class="guarantee-item lift">
    <svg class="g-icon" viewBox="0 0 24 24"><path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/><path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"/><path d="M8 16H3v5"/></svg>
    <div class="g-title">智能重试</div>
    <div class="g-desc">失败任务自动退避重试（最多{max_retries}次），避免反复报错</div>
  </div>
  <div class="guarantee-item lift">
    <svg class="g-icon" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
    <div class="g-title">僵尸清理</div>
    <div class="g-desc">启动时自动重置10分钟前卡住的任务，不留残留</div>
  </div>
</div>

</body>
</html>''';

