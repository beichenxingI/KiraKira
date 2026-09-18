// lib/presentation/dialogs/chronicle_settings_dialog.dart
/// [CHRONICLE UI整合] Chronicle全局设置浮窗（极客Core规范浮窗）
///
/// 修复二：设置是全局运行参数，从API服务页直接打开，不依赖是否有聊天打开。
///
/// 修改一：移除底部"打开Wiki管理/立即整理记忆"按钮（改在聊天页实现）。
/// 修改二："工作原理"由信息行改为可点击入口，弹出WebView浮窗加载原理HTML。
/// 修改三："总结模型"由单行文本框改为完整模型配置区（BaseURL/APIKey/获取模型/模型名）。
library;

import 'dart:math' show min;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  void _showPrincipleWebView() {
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
                data: _kPrincipleHtml,
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
                  label: '总结间隔（新增消息数）',
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
              ],
            ),
          ),
          const SizedBox(height: 12),
          CoreGroupBox(
            title: '窗口设置',
            child: Column(
              children: [
                CoreSliderRow(
                  label: '热区大小（保留原文条数）',
                  value: settings.hotWindowSize.toDouble(),
                  min: 10,
                  max: 40,
                  divisions: 30,
                  display: '${settings.hotWindowSize} 条',
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
const String _kPrincipleHtml = r'''<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Chronicle 工作原理</title>
<style>
  :root {
    --bg: #0f0f0f;
    --surface: #1a1a1a;
    --border: #2a2a2a;
    --accent: #e8956d;
    --accent-dim: rgba(232,149,109,0.15);
    --text: #f0ebe4;
    --muted: #8a8480;
    --green: #6db86d;
    --yellow: #d4b85a;
    --bad: #c46060;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    background: var(--bg);
    color: var(--text);
    font-family: 'PingFang SC', 'Microsoft YaHei', sans-serif;
    font-size: 14px;
    line-height: 1.7;
    padding: 28px 24px 48px;
  }
  .hero { text-align: center; padding: 32px 0 40px; }
  .hero-icon { font-size: 48px; margin-bottom: 16px; }
  .hero h1 { font-size: 22px; font-weight: 700; letter-spacing: .08em; color: var(--accent); margin-bottom: 8px; }
  .hero p { color: var(--muted); font-size: 13px; max-width: 420px; margin: 0 auto; }
  .compare-grid { display: grid; grid-template-columns: 1fr; gap: 16px; margin: 8px 0 40px; }
  .compare-card { border: 1px solid var(--border); border-radius: 14px; padding: 20px; background: var(--surface); }
  .compare-card.highlight { border-color: var(--accent); background: linear-gradient(135deg, rgba(232,149,109,0.08), var(--surface)); }
  .card-header { display: flex; align-items: center; gap: 10px; margin-bottom: 14px; }
  .badge { font-size: 11px; padding: 3px 8px; border-radius: 999px; font-weight: 600; letter-spacing: .04em; }
  .badge-bad { background: rgba(196,96,96,0.2); color: var(--bad); }
  .badge-ok { background: rgba(212,184,90,0.2); color: var(--yellow); }
  .badge-good { background: rgba(109,184,109,0.2); color: var(--green); }
  .card-title { font-weight: 700; font-size: 15px; }
  .card-desc { color: var(--muted); font-size: 12px; margin-bottom: 14px; }
  .flow { display: flex; flex-direction: column; gap: 6px; }
  .flow-row { display: flex; align-items: center; gap: 8px; font-size: 12px; }
  .flow-box { padding: 5px 10px; border-radius: 8px; background: rgba(255,255,255,0.05); border: 1px solid var(--border); white-space: nowrap; flex-shrink: 0; }
  .flow-box.accent { border-color: var(--accent); color: var(--accent); }
  .flow-arrow { color: var(--muted); font-size: 14px; }
  .flow-note { font-size: 11px; color: var(--muted); margin-left: 4px; flex: 1; }
  .pros-cons { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 14px; padding-top: 14px; border-top: 1px solid var(--border); }
  .tag { font-size: 11px; padding: 3px 8px; border-radius: 6px; }
  .tag-pro { background: rgba(109,184,109,0.12); color: var(--green); }
  .tag-con { background: rgba(196,96,96,0.12); color: var(--bad); }
  .window-demo { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 6px; margin: 14px 0; font-size: 11px; text-align: center; }
  .win-cold { background: rgba(255,255,255,0.03); border: 1px solid #2a2a2a; border-radius: 8px; padding: 8px 4px; color: #555; }
  .win-warm { background: rgba(232,149,109,0.06); border: 1px solid rgba(232,149,109,0.2); border-radius: 8px; padding: 8px 4px; color: #a07060; }
  .win-hot  { background: rgba(232,149,109,0.14); border: 1px solid rgba(232,149,109,0.45); border-radius: 8px; padding: 8px 4px; color: var(--accent); }
  .win-label { font-weight: 700; margin-bottom: 4px; }
  .win-sub { opacity: .7; font-size: 10px; }
  .section-title { font-size: 16px; font-weight: 700; margin: 32px 0 16px; color: var(--accent); display: flex; align-items: center; gap: 8px; }
  .memory-layers { display: flex; flex-direction: column; gap: 10px; margin-bottom: 32px; }
  .layer-row { display: flex; gap: 14px; align-items: flex-start; padding: 14px; border-radius: 12px; border: 1px solid var(--border); background: var(--surface); }
  .layer-icon { font-size: 22px; flex-shrink: 0; margin-top: 2px; }
  .layer-title { font-weight: 600; font-size: 13px; margin-bottom: 4px; }
  .layer-desc { color: var(--muted); font-size: 12px; }
  .conclusion { background: var(--accent-dim); border: 1px solid rgba(232,149,109,0.3); border-radius: 14px; padding: 20px; text-align: center; font-size: 13px; line-height: 1.8; }
  .conclusion strong { color: var(--accent); }
</style>
</head>
<body>

<div class="hero">
  <div class="hero-icon">📖</div>
  <h1>Chronicle 工作原理</h1>
  <p>为什么理论上可以实现永久记忆，以及它与传统方案的本质区别</p>
</div>

<div class="section-title">⚖️ 三种方案对比</div>

<div class="compare-grid">

  <div class="compare-card">
    <div class="card-header">
      <span class="badge badge-bad">传统方案</span>
      <span class="card-title">全量注入</span>
    </div>
    <div class="card-desc">每次对话都把所有历史记录塞给模型</div>
    <div class="flow">
      <div class="flow-row">
        <div class="flow-box">角色卡</div>
        <div class="flow-arrow">+</div>
        <div class="flow-box">第1条消息</div>
        <div class="flow-arrow">+</div>
        <div class="flow-box">···</div>
        <div class="flow-arrow">+</div>
        <div class="flow-box">第N条</div>
      </div>
      <div class="flow-row">
        <div class="flow-arrow" style="margin-left:8px">↓</div>
        <div class="flow-note">全部塞入上下文窗口</div>
      </div>
    </div>
    <div class="pros-cons">
      <span class="tag tag-pro">信息完整</span>
      <span class="tag tag-con">token暴增</span>
      <span class="tag tag-con">模型变笨</span>
      <span class="tag tag-con">费用爆炸</span>
      <span class="tag tag-con">对话一长就崩</span>
    </div>
  </div>

  <div class="compare-card">
    <div class="card-header">
      <span class="badge badge-ok">常见方案</span>
      <span class="card-title">向量 + 总结</span>
    </div>
    <div class="card-desc">把历史压缩成一段总结，加上语义检索</div>
    <div class="flow">
      <div class="flow-row">
        <div class="flow-box">一坨总结文本</div>
        <div class="flow-arrow">+</div>
        <div class="flow-box">向量召回原文</div>
      </div>
      <div class="flow-row">
        <div class="flow-arrow" style="margin-left:8px">↓</div>
        <div class="flow-note">召回的是冗长原文，噪音多</div>
      </div>
    </div>
    <div class="pros-cons">
      <span class="tag tag-pro">比全量省token</span>
      <span class="tag tag-con">总结仍然很长</span>
      <span class="tag tag-con">召回噪音多</span>
      <span class="tag tag-con">关系不清晰</span>
    </div>
  </div>

  <div class="compare-card highlight">
    <div class="card-header">
      <span class="badge badge-good">Chronicle</span>
      <span class="card-title">三窗口 + Wiki召回</span>
    </div>
    <div class="card-desc">结构化词条取代叙事总结，精炼摘要入向量库</div>

    <div class="window-demo">
      <div class="win-cold">
        <div class="win-label">冷区</div>
        <div class="win-sub">即将淡出</div>
        <div class="win-sub">低注意力位</div>
      </div>
      <div class="win-warm">
        <div class="win-label">温区</div>
        <div class="win-sub">过渡记忆</div>
        <div class="win-sub">中间区域</div>
      </div>
      <div class="win-hot">
        <div class="win-label">热区</div>
        <div class="win-sub">最近原文</div>
        <div class="win-sub">末尾高注意力</div>
      </div>
    </div>

    <div class="flow">
      <div class="flow-row">
        <div class="flow-box accent">Wiki词条</div>
        <div class="flow-arrow">+</div>
        <div class="flow-box">精准召回</div>
        <div class="flow-arrow">+</div>
        <div class="flow-box">热区原文</div>
      </div>
    </div>
    <div class="pros-cons">
      <span class="tag tag-pro">token大幅减少</span>
      <span class="tag tag-pro">关系清晰</span>
      <span class="tag tag-pro">召回精准</span>
      <span class="tag tag-pro">上下文稳定</span>
      <span class="tag tag-pro">理论永久记忆</span>
    </div>
  </div>

</div>

<div class="section-title">♾️ 为什么可以永久记忆</div>

<div class="memory-layers">
  <div class="layer-row">
    <div class="layer-icon">⚓</div>
    <div>
      <div class="layer-title">锚点层 · 永不遗忘</div>
      <div class="layer-desc">初次相遇、重大转折等关键时刻被标记为锚点，无论对话多少轮都始终注入，一千轮后模型仍然记得第一次见面。</div>
    </div>
  </div>
  <div class="layer-row">
    <div class="layer-icon">🗂️</div>
    <div>
      <div class="layer-title">词条层 · 结构化记忆</div>
      <div class="layer-desc">每隔N轮，模型将对话提炼为结构化词条——人物当前状态、关系变化、情感节点。词条只增量更新，不叠加膨胀。</div>
    </div>
  </div>
  <div class="layer-row">
    <div class="layer-icon">🔍</div>
    <div>
      <div class="layer-title">语义召回层 · 按需检索</div>
      <div class="layer-desc">向量库只存精炼词条（非原文），混合语义相似度+关键词+时间权重召回，相关的事件精准浮现，无关内容不占token。</div>
    </div>
  </div>
  <div class="layer-row">
    <div class="layer-icon">🌡️</div>
    <div>
      <div class="layer-title">三窗口层 · 渐进淡出</div>
      <div class="layer-desc">原文按热/温/冷三区排列，利用模型对上下文末尾注意力更强的特性。旧内容渐进淡出而非突然消失，不会突然失忆。</div>
    </div>
  </div>
</div>

<div class="conclusion">
  结果是：<strong>上下文窗口始终稳定</strong>，不随对话轮数增长。<br>
  无论聊了多少轮，模型每次拿到的都是<strong>精炼的关键记忆</strong>而非冗长历史。<br>
  这就是理论上可以实现<strong>永久记忆</strong>的原因。
</div>

</body>
</html>''';
