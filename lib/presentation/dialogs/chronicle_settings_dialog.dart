// lib/presentation/dialogs/chronicle_settings_dialog.dart
/// [CHRONICLE UI整合] Chronicle全局设置浮窗（极客Core规范浮窗）
///
/// 修复二：设置是全局运行参数，从API服务页直接打开，不依赖是否有聊天打开。
/// 只有"打开Wiki管理/立即整理记忆"需要聊天上下文（无聊天时置灰）。
///
/// 修复四：首次打开且存在旧版RAG向量数据时，弹迁移选择（选择后持久化不再弹）。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/repositories/chronicle_repository.dart';
import 'package:kirakira/domain/services/chronicle_orchestrator.dart';
import 'package:kirakira/presentation/providers/chat_providers.dart';
import 'package:kirakira/presentation/providers/chronicle_providers.dart';
import 'package:kirakira/presentation/providers/vector_storage_providers.dart';
import 'package:kirakira/presentation/utils/kira_dialog.dart';
import 'core_dialog.dart';
import 'chronicle_wiki_dialog.dart';

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
  bool _organizing = false;
  bool _migrationChecked = false;
  final _modelController = TextEditingController();
  final _suffixController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 首帧后检查迁移（避免浮窗构建期间弹第二层）
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkMigration());
  }

  @override
  void dispose() {
    _modelController.dispose();
    _suffixController.dispose();
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

  // ═══════════════════ 立即整理（需聊天上下文） ═══════════════════

  Future<void> _organizeNow() async {
    final chatId = ref.read(activeChatIdProvider);
    if (chatId == null) return;
    setState(() => _organizing = true);
    try {
      final chatState = ref.read(activeChatProvider);
      final orchestrator = ref.read(chronicleOrchestratorProvider);
      // 复用话题切换路径：入队溢出热窗的消息立即总结
      await orchestrator.onTopicShift(chatId, chatState.messages);
      final enqueued = await ref
          .read(chronicleRepositoryProvider)
          .hasActiveTaskForChat(chatId);
      if (mounted) {
        coreToast(
            context,
            enqueued
                ? '已入队整理任务，后台完成后词条自动生效'
                : '没有待整理的溢出消息（热窗内消息保留原文）');
      }
    } finally {
      if (mounted) setState(() => _organizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CoreDialogPalette(isDark: isDark);
    final settings = ref.watch(chronicleSettingsProvider);
    final hasActiveChat = ref.watch(activeChatIdProvider) != null;

    _modelController.text = _modelController.text.isEmpty
        ? settings.summaryModel
        : _modelController.text;
    _suffixController.text = _suffixController.text.isEmpty
        ? settings.customPromptSuffix
        : _suffixController.text;

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
          CoreInfoRow(
            icon: CupertinoIcons.lightbulb,
            title: '工作原理',
            text: '溢出热窗的对话被异步总结为结构化词条（事件/实体/关系/情感），'
                '固定层+召回层按需注入，历史原文不再全量进提示词。',
            palette: palette,
          ),
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
          CoreGroupBox(
            title: '总结模型',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoreTextField(
                  controller: _modelController,
                  palette: palette,
                  hint: '留空 = 沿用主模型（可选填小模型省token）',
                  onChanged: (v) => notifier.setSummaryModel(v.trim()),
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
      footer: CoreDialogFooter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!hasActiveChat)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '打开Wiki管理与立即整理记忆需要先进入一个聊天',
                  style: TextStyle(fontSize: 12, color: palette.textSecondary),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: CoreSecondaryButton(
                    label: '打开 Wiki 管理',
                    icon: CupertinoIcons.list_bullet,
                    onPressed: hasActiveChat
                        ? () {
                            Navigator.of(context, rootNavigator: true).pop();
                            showChronicleWikiDialog(context, ref);
                          }
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CorePrimaryButton(
                    label: '立即整理记忆',
                    icon: CupertinoIcons.wand_stars,
                    onPressed:
                        hasActiveChat && !_organizing ? _organizeNow : null,
                  ),
                ),
              ],
            ),
          ],
        ),
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
