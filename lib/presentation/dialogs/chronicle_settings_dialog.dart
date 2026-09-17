// lib/presentation/dialogs/chronicle_settings_dialog.dart
/// [CHRONICLE Phase 4] Chronicle设置浮窗（极客Core规范浮窗）
/// 总开关/总结间隔/总结模型/热窗大小/召回数量/自定义指令/情感召回/MVU桥接
/// + [打开Wiki管理] + [立即整理记忆]
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/models/chronicle.dart';
import 'package:kirakira/data/repositories/chronicle_repository.dart';
import 'package:kirakira/domain/services/chronicle_orchestrator.dart';
import 'package:kirakira/presentation/providers/chat_providers.dart';
import 'package:kirakira/presentation/providers/chronicle_providers.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
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
  ChronicleSettings _settings = const ChronicleSettings();
  bool _loading = true;
  bool _organizing = false;
  String? _chatId;
  final _modelController = TextEditingController();
  final _suffixController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _chatId = ref.read(activeChatIdProvider);
    if (_chatId == null) {
      _loading = false;
      return;
    }
    _load();
  }

  @override
  void dispose() {
    _modelController.dispose();
    _suffixController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(chronicleRepositoryProvider);
    final s = await repo.getSettings(_chatId!);
    if (!mounted) return;
    setState(() {
      _settings = s;
      _modelController.text = s.summaryModel;
      _suffixController.text = s.customPromptSuffix;
      _loading = false;
    });
  }

  Future<void> _save(ChronicleSettings next) async {
    setState(() => _settings = next);
    await ref
        .read(chronicleRepositoryProvider)
        .saveSettings(_chatId!, next);
  }

  Future<void> _organizeNow() async {
    if (_chatId == null) return;
    setState(() => _organizing = true);
    try {
      final chatState = ref.read(activeChatProvider);
      final orchestrator = ref.read(chronicleOrchestratorProvider);
      // 复用话题切换路径：入队溢出热窗的消息立即总结
      await orchestrator.onTopicShift(_chatId!, chatState.messages);
      final enqueued = await ref
          .read(chronicleRepositoryProvider)
          .hasActiveTaskForChat(_chatId!);
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

    return CoreDialogShell(
      title: 'Chronicle 超级记忆',
      icon: CupertinoIcons.book_fill,
      maxWidth: 550,
      body: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : _chatId == null
              ? _buildNoChat(palette)
              : _buildBody(palette),
      footer: _chatId == null || _loading
          ? null
          : CoreDialogFooter(
              child: Row(
                children: [
                  Expanded(
                    child: CoreSecondaryButton(
                      label: '打开 Wiki 管理',
                      icon: CupertinoIcons.list_bullet,
                      onPressed: () {
                        Navigator.of(context, rootNavigator: true).pop();
                        showChronicleWikiDialog(context, ref);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CorePrimaryButton(
                      label: '立即整理记忆',
                      icon: CupertinoIcons.wand_stars,
                      onPressed: _organizing ? null : _organizeNow,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildNoChat(CoreDialogPalette palette) {
    return CoreInfoRow(
      icon: CupertinoIcons.chat_bubble,
      title: '尚未打开聊天',
      text: 'Chronicle按聊天管理记忆。请先进入一个聊天，再从API服务页配置本聊天的超级记忆。',
      palette: palette,
    );
  }

  Widget _buildBody(CoreDialogPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CoreInfoRow(
          icon: CupertinoIcons.lightbulb,
          title: '工作原理',
          text: '溢出热窗的对话被异步总结为结构化词条（事件/实体/关系/情感），'
              '固定层+召回层按需注入，历史原文不再全量进提示词。',
          palette: palette,
        ),
        CoreGroupBox(
          title: '基础',
          child: Column(
            children: [
              CoreSwitchRow(
                title: '启用超级记忆',
                subtitle: '关闭后回落旧的全量注入+自动总结',
                value: _settings.enabled,
                onChanged: (v) => _save(_settings.copyWith(enabled: v)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CoreGroupBox(
          title: '总结管线',
          child: Column(
            children: [
              CoreSliderRow(
                label: '总结触发间隔（新增消息数）',
                value: _settings.summaryInterval.toDouble(),
                min: 10,
                max: 40,
                divisions: 30,
                display: '${_settings.summaryInterval} 条',
                onChanged: (v) =>
                    _save(_settings.copyWith(summaryInterval: v.round())),
              ),
              CoreSliderRow(
                label: '热区窗口（保留原文条数）',
                value: _settings.hotWindowSize.toDouble(),
                min: 10,
                max: 40,
                divisions: 30,
                display: '${_settings.hotWindowSize} 条',
                onChanged: (v) =>
                    _save(_settings.copyWith(hotWindowSize: v.round())),
              ),
              const SizedBox(height: 6),
              CoreSectionLabel('总结模型（空=沿用主模型，可填小模型省token）'),
              const SizedBox(height: 6),
              CoreTextField(
                controller: _modelController,
                palette: CoreDialogPalette(
                    isDark: Theme.of(context).brightness == Brightness.dark),
                hint: '如 gemini-flash / deepseek-chat',
                onChanged: (v) =>
                    _save(_settings.copyWith(summaryModel: v.trim())),
              ),
              const SizedBox(height: 10),
              CoreSectionLabel('自定义追加指令（拼到总结Prompt末尾）'),
              const SizedBox(height: 6),
              CoreTextField(
                controller: _suffixController,
                palette: CoreDialogPalette(
                    isDark: Theme.of(context).brightness == Brightness.dark),
                hint: '例如：重点保留角色间的承诺与欠债',
                maxLines: 3,
                onChanged: (v) =>
                    _save(_settings.copyWith(customPromptSuffix: v)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CoreGroupBox(
          title: '召回与桥接',
          child: Column(
            children: [
              CoreSliderRow(
                label: '召回词条数量（top K）',
                value: _settings.ragTopK.toDouble(),
                min: 3,
                max: 10,
                divisions: 7,
                display: '${_settings.ragTopK} 条',
                onChanged: (v) => _save(_settings.copyWith(ragTopK: v.round())),
              ),
              CoreSwitchRow(
                title: '情感节点召回加成',
                subtitle: '活跃情感关联的实体事件召回加权',
                value: _settings.emotionRecallEnabled,
                onChanged: (v) =>
                    _save(_settings.copyWith(emotionRecallEnabled: v)),
              ),
              CoreSwitchRow(
                title: 'MVU 桥接',
                subtitle: 'MVU数值重大变化(±20)自动记录为记忆事件；Chronicle只读不回写',
                value: _settings.mvuBridgeEnabled,
                onChanged: (v) => _save(_settings.copyWith(mvuBridgeEnabled: v)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
