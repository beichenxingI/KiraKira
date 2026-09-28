// lib/presentation/dialogs/mvu_dialog.dart
/// MVU 变量框架浮窗(极客Core迁移 P5.1)
/// 内容完整迁自 mvu_settings_screen.dart(519行),字段一个不少:
/// 引擎行为(更新方式/自动请求/上下文历史条数) · 从主配置复制
/// API配置(模型来源/API地址/密钥/模型名称) ·
/// 提示词配置(自定义开关/警告/提示词文本/恢复内置) · 关于 · 恢复默认
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/models/mvu_settings.dart';
import 'package:kirakira/presentation/providers/mvu_settings_providers.dart';
import 'package:kirakira/presentation/providers/settings_providers.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'core_dialog.dart';

Future<void> showMvuDialog(BuildContext context, WidgetRef ref) {
  return showCoreDialog(
    context,
    builder: (_) => const _MvuDialog(),
  );
}

class _MvuDialog extends ConsumerStatefulWidget {
  const _MvuDialog();

  @override
  ConsumerState<_MvuDialog> createState() => _MvuDialogState();
}

class _MvuDialogState extends ConsumerState<_MvuDialog> {
  late TextEditingController _apiUrlController;
  late TextEditingController _apiKeyController;
  late TextEditingController _modelNameController;
  late TextEditingController _customPromptController;
  bool _obscureKey = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _obscureKey = true;
    // controller 先用空值初始化,首次依赖就绪后同步真实值
    _apiUrlController = TextEditingController();
    _apiKeyController = TextEditingController();
    _modelNameController = TextEditingController();
    _customPromptController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 只在首次进入时从 state 同步到 controller 一次
    if (!_isInitialized) {
      _isInitialized = true;
      final mvu = ref.read(mvuSettingsProvider);
      _apiUrlController.text = mvu.apiUrl;
      _apiKeyController.text = mvu.apiKey;
      _modelNameController.text = mvu.modelName;
      _customPromptController.text = mvu.customPrompt;
    }
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _apiKeyController.dispose();
    _modelNameController.dispose();
    _customPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CoreDialogPalette(isDark: isDark);
    final mvu = ref.watch(mvuSettingsProvider);
    final notifier = ref.read(mvuSettingsProvider.notifier);

    // 监听 state 变化,首次加载或重置时同步到 controller(与原页一致)
    ref.listen<MvuSettings>(
      mvuSettingsProvider,
      (previous, next) {
        if (previous == null ||
            (previous.apiUrl != next.apiUrl &&
                _apiUrlController.text == previous.apiUrl)) {
          _apiUrlController.text = next.apiUrl;
          _apiKeyController.text = next.apiKey;
          _modelNameController.text = next.modelName;
          _customPromptController.text = next.customPrompt;
        }
      },
    );

    return CoreDialogShell(
      title: '变量框架',
      icon: CupertinoIcons.cube_box,
      maxWidth: 550,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 引擎行为 ──
          const CoreSectionLabel('引擎行为'),
          const SizedBox(height: 4),
          _Group(
            palette: palette,
            children: [
              _DropdownTile(
                palette: palette,
                title: '更新方式',
                subtitle: '变量由哪种方式写入',
                child: DropdownButton<String>(
                  value: ['额外模型解析', '随AI输出'].contains(mvu.updateMode)
                      ? mvu.updateMode
                      : '额外模型解析',
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(8),
                  dropdownColor: palette.surface,
                  iconEnabledColor: palette.textSecondary,
                  onChanged: (v) {
                    if (v != null) notifier.updateUpdateMode(v);
                  },
                  items: const ['额外模型解析', '随AI输出']
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e,
                              style: TextStyle(
                                  fontSize: 14,
                                  color: palette.textPrimary),
                            ),
                          ))
                      .toList(),
                ),
              ),
              CoreSwitchRow(
                title: '启用自动请求',
                subtitle: '每次 AI 回复后自动触发变量更新',
                value: mvu.autoRequest,
                palette: palette,
                onChanged: notifier.updateAutoRequest,
              ),
              _SliderTile(
                palette: palette,
                label: '上下文历史条数',
                subtitle: '额外模型能看到的最近消息数',
                value: mvu.maxChatHistory.toDouble(),
                min: 2,
                max: 100,
                divisions: 98,
                valueLabel: '${mvu.maxChatHistory} 条',
                onChanged: (v) => notifier.updateMaxChatHistory(v.round()),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 从主 LLM 配置一键复制
          Align(
            alignment: Alignment.centerRight,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: palette.fill,
              borderRadius: BorderRadius.circular(8),
              minSize: 0,
              onPressed: () {
                final llm = ref.read(llmConfigProvider);
                notifier.updateApiUrl(llm.apiUrl);
                notifier.updateApiKey(llm.apiKey);
                notifier.updateModelName(llm.model);
                _apiUrlController.text = llm.apiUrl;
                _apiKeyController.text = llm.apiKey;
                _modelNameController.text = llm.model;
                coreToast(context, '已从主模型配置复制');
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.download,
                      size: 16, color: DesignTokens.primary),
                  const SizedBox(width: 4),
                  Text(
                    '从主配置复制',
                    style: TextStyle(
                        fontSize: 13, color: palette.textPrimary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── API 配置 ──
          const CoreSectionLabel('API 配置'),
          const SizedBox(height: 4),
          _Group(
            palette: palette,
            children: [
              _DropdownTile(
                palette: palette,
                title: '模型来源',
                subtitle: '使用哪套 API 接入',
                child: DropdownButton<String>(
                  value: '自定义',
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(8),
                  dropdownColor: palette.surface,
                  iconEnabledColor: palette.textSecondary,
                  onChanged: (v) {
                    if (v != null) notifier.updateModelSource(v);
                  },
                  items: const ['自定义']
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e,
                              style: TextStyle(
                                  fontSize: 14,
                                  color: palette.textPrimary),
                            ),
                          ))
                      .toList(),
                ),
              ),
              _TextTile(
                palette: palette,
                label: 'API 地址',
                subtitle: '完整的接口根路径',
                controller: _apiUrlController,
                keyboardType: TextInputType.url,
                onChanged: notifier.updateApiUrl,
                onSubmitted: notifier.updateApiUrl,
                onEditingComplete: () =>
                    notifier.updateApiUrl(_apiUrlController.text),
              ),
              _TextTile(
                palette: palette,
                label: '密钥',
                subtitle: '发送请求时携带的 Authorization token',
                controller: _apiKeyController,
                obscureText: _obscureKey,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureKey ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                    color: palette.textSecondary,
                  ),
                  onPressed: () =>
                      setState(() => _obscureKey = !_obscureKey),
                ),
                onChanged: notifier.updateApiKey,
                onSubmitted: notifier.updateApiKey,
                onEditingComplete: () =>
                    notifier.updateApiKey(_apiKeyController.text),
              ),
              _TextTile(
                palette: palette,
                label: '模型名称',
                subtitle: '传给接口的 model 参数',
                controller: _modelNameController,
                onChanged: notifier.updateModelName,
                onSubmitted: notifier.updateModelName,
                onEditingComplete: () =>
                    notifier.updateModelName(_modelNameController.text),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── 提示词配置 ──
          const CoreSectionLabel('提示词配置'),
          const SizedBox(height: 4),
          _Group(
            palette: palette,
            children: [
              CoreSwitchRow(
                title: '使用自定义提示词',
                subtitle: '关闭时使用内置安全版 task 提示词',
                value: mvu.customPromptEnabled,
                palette: palette,
                onChanged: notifier.updateCustomPromptEnabled,
              ),
              if (mvu.customPromptEnabled) ...[
                // 免责警告
                Padding(
                  padding: const EdgeInsets.only(
                      left: 12, right: 12, top: 8, bottom: 4),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF453A).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 16, color: Color(0xFFFF453A)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '自定义提示词可能导致模型输出不符合内容政策的结果，风险由使用者自行承担。',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFFFF453A)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 提示词文本框
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  child: CupertinoTextField(
                    controller: _customPromptController,
                    maxLines: null,
                    minLines: 8,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: palette.outline),
                    ),
                    style: TextStyle(color: palette.textPrimary),
                    placeholder: 'task 提示词内容',
                    onChanged: notifier.updateCustomPrompt,
                  ),
                ),
                // 恢复默认
                Align(
                  alignment: Alignment.centerRight,
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    minSize: 0,
                    onPressed: () {
                      notifier.updateCustomPrompt(kDefaultMvuTask);
                      _customPromptController.text = kDefaultMvuTask;
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.restore,
                            size: 16, color: palette.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '恢复内置提示词',
                          style: TextStyle(
                              fontSize: 13, color: palette.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),

          // ── 关于 ──
          const CoreSectionLabel('关于'),
          const SizedBox(height: 4),
          CoreInfoRow(
            icon: CupertinoIcons.cube_box,
            title: '内置版本 · 内置MagVarUpdate',
            text: '变量框架通过额外模型解析 AI 回复，将对话状态写入结构化变量，'
                '供提示词宏和 UI 状态栏读取。',
            palette: palette,
          ),
          const SizedBox(height: 12),
          CoreDangerButton(
            label: '恢复默认（清空所有 MVU 设置并还原出厂值）',
            onPressed: () => _confirmReset(context, notifier),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context, MvuSettingsNotifier notifier) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('恢复默认设置'),
        content: const Text('所有 MVU 配置(包括密钥)将被清空并还原为出厂值。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(dialogCtx);
              notifier.resetToDefaults();
              // 同步 TextField
              const defaults = MvuSettings();
              _apiUrlController.text = defaults.apiUrl;
              _apiKeyController.text = defaults.apiKey;
              _modelNameController.text = defaults.modelName;
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}

/// 浮窗内分组容器
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

/// 带右侧下拉的行
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

/// 文本输入行(与原页 _TextTile 一致)
class _TextTile extends StatelessWidget {
  const _TextTile({
    required this.palette,
    required this.label,
    required this.controller,
    this.subtitle,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.onSubmitted,
    this.onEditingComplete,
    this.onChanged,
  });

  final CoreDialogPalette palette;
  final String label;
  final String? subtitle;
  final TextEditingController controller;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 15, color: palette.textPrimary)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 12, color: palette.textSecondary),
            ),
          ],
          const SizedBox(height: 6),
          CupertinoTextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.outline),
            ),
            suffix: suffixIcon,
            style: TextStyle(fontSize: 14, color: palette.textPrimary),
            onSubmitted: onSubmitted,
            onEditingComplete: onEditingComplete,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// 滑块行(与原页 _SliderTile 一致)
class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.palette,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.subtitle,
    this.valueLabel,
  });

  final CoreDialogPalette palette;
  final String label;
  final String? subtitle;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String? valueLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: palette.textPrimary)),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: TextStyle(
                              fontSize: 12,
                              color: palette.textSecondary)),
                  ],
                ),
              ),
              Text(
                valueLabel ?? value.toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: DesignTokens.primary,
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
      ),
    );
  }
}
