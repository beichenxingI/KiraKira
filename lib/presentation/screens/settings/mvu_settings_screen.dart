import 'dart:convert';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/models/mvu_settings.dart';
import 'package:kirakira/presentation/providers/mvu_settings_providers.dart';
import 'package:kirakira/presentation/widgets/common/kira_components.dart';
import 'package:kirakira/presentation/providers/settings_providers.dart';

class MvuSettingsScreen extends ConsumerStatefulWidget {
  const MvuSettingsScreen({super.key});

  @override
  ConsumerState<MvuSettingsScreen> createState() => _MvuSettingsScreenState();
}

class _MvuSettingsScreenState extends ConsumerState<MvuSettingsScreen> {
  late TextEditingController _apiUrlController;
  late TextEditingController _apiKeyController;
  late TextEditingController _modelNameController;
  late TextEditingController _customPromptController;
  bool _obscureKey = true;
  bool _isInitialized = false;  // ← 新增这行

  @override
  void initState() {
    super.initState();
    _obscureKey = true;
    // controller 先用空值初始化,等 didChangeDependencies 里同步真实值
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
    // 监听 state 变化,首次加载时同步到 controller
    ref.listen<MvuSettings>(
      mvuSettingsProvider,
      (previous, next) {
        // 只在首次加载(previous == null)或重置时同步
        if (previous == null || 
            (previous.apiUrl != next.apiUrl && _apiUrlController.text == previous.apiUrl)) {
          _apiUrlController.text = next.apiUrl;
          _apiKeyController.text = next.apiKey;
          _modelNameController.text = next.modelName;
          _customPromptController.text = next.customPrompt;
        }
      },
    );

    final mvu = ref.watch(mvuSettingsProvider);
    final notifier = ref.read(mvuSettingsProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('变量框架'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // ── 引擎行为 ──
          KiraSection(
            title: '引擎行为',
            icon: Icons.tune,
            children: [
              // 更新方式
              _DropdownTile(
                label: '更新方式',
                subtitle: '变量由哪种方式写入',
                value: mvu.updateMode,
                items: const ['额外模型解析', '随AI输出'],
                onChanged: notifier.updateUpdateMode,
              ),
              // 自动请求
              _SwitchTile(
                label: '启用自动请求',
                subtitle: '每次 AI 回复后自动触发变量更新',
                value: mvu.autoRequest,
                onChanged: notifier.updateAutoRequest,
              ),
              // 历史条数滑块
              _SliderTile(
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

// 从主 LLM 配置一键复制
Padding(
  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
  child: Align(
    alignment: Alignment.centerRight,
    child: OutlinedButton.icon(
      icon: const Icon(Icons.download, size: 16),
      label: const Text('从主配置复制'),
      onPressed: () {
        final llm = ref.read(llmConfigProvider);
        notifier.updateApiUrl(llm.apiUrl);
        notifier.updateApiKey(llm.apiKey);
        notifier.updateModelName(llm.model);
        // 同步 TextField
        _apiUrlController.text = llm.apiUrl;
        _apiKeyController.text = llm.apiKey;
        _modelNameController.text = llm.model;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已从主模型配置复制'),
            duration: Duration(seconds: 2),
          ),
        );
      },
    ),
  ),
),
          // ── API 配置 ──
          KiraSection(
            title: 'API 配置',
            icon: Icons.cloud_outlined,
            children: [
              // 模型来源
              _DropdownTile(
                label: '模型来源',
                subtitle: '使用哪套 API 接入',
                value: mvu.modelSource,
                items: const ['自定义'],
                onChanged: notifier.updateModelSource,
              ),

             _TextTile(
               label: 'API 地址',
               subtitle: '完整的接口根路径',
               controller: _apiUrlController,
               keyboardType: TextInputType.url,
               onChanged: notifier.updateApiUrl,  // ← 新增
               onSubmitted: notifier.updateApiUrl,
               onEditingComplete: () => notifier.updateApiUrl(_apiUrlController.text),
             ),

             _TextTile(
                 label: '密钥',
                 subtitle: '发送请求时携带的 Authorization token',
                 controller: _apiKeyController,
                 obscureText: _obscureKey,
                 suffixIcon: IconButton(
                   icon: Icon(
                     _obscureKey ? Icons.visibility_off : Icons.visibility,
                     size: 18,
                   ),
                   onPressed: () => setState(() => _obscureKey = !_obscureKey),
                 ),
                 onChanged: notifier.updateApiKey,  // ← 新增
                 onSubmitted: notifier.updateApiKey,
                 onEditingComplete: () => notifier.updateApiKey(_apiKeyController.text),
               ),
              // 模型名称
             _TextTile(
               label: '模型名称',
                subtitle: '传给接口的 model 参数',
                controller: _modelNameController,
                onChanged: notifier.updateModelName,  // ← 新增
                onSubmitted: notifier.updateModelName,
                onEditingComplete: () => notifier.updateModelName(_modelNameController.text),
              ),
            ],
          ),

// ── 提示词配置 ──
KiraSection(
  title: '提示词配置',
  icon: Icons.edit_note,
  children: [
    _SwitchTile(
      label: '使用自定义提示词',
      subtitle: '关闭时使用内置安全版 task 提示词',
      value: mvu.customPromptEnabled,
      onChanged: notifier.updateCustomPromptEnabled,
    ),
    if (mvu.customPromptEnabled) ...[
      // 免责警告
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer.withOpacity(0.4),
            borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 18, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '自定义提示词可能导致模型输出不符合内容政策的结果，风险由使用者自行承担。',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            ],
          ),
        ),
      ),
      // 提示词文本框
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: TextField(
          controller: _customPromptController,
          maxLines: null,
          minLines: 8,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'task 提示词内容',
            contentPadding: EdgeInsets.all(12),
          ),
          onChanged: notifier.updateCustomPrompt,
        ),
      ),
      // 恢复默认
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.restore, size: 16),
            label: const Text('恢复内置提示词'),
            onPressed: () {
              notifier.updateCustomPrompt(kDefaultMvuTask);
              _customPromptController.text = kDefaultMvuTask;
            },
          ),
        ),
      ),
    ],
  ],
),

          // ── 关于 ──
          KiraSection(
            title: '关于',
            icon: Icons.info_outline,
            children: [
              _InfoTile(
                label: '内置版本',
                // ← 版本号确认后替换这里
                value: '内置MagVarUpdate',
              ),
              _InfoTile(
                label: '说明',
                value: '变量框架通过额外模型解析 AI 回复，将对话状态写入结构化变量，供提示词宏和 UI 状态栏读取。',
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                title: Text(
                  '恢复默认',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                subtitle: const Text('清空所有 MVU 设置并还原出厂值'),
                trailing: Icon(Icons.restore, color: theme.colorScheme.error),
                onTap: () => _confirmReset(context, notifier),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context, MvuSettingsNotifier notifier) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复默认设置'),
        content: const Text('所有 MVU 配置(包括密钥)将被清空并还原为出厂值。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              notifier.resetToDefaults();
              // 同步 TextField
              final defaults = const MvuSettings();
              _apiUrlController.text = defaults.apiUrl;
              _apiKeyController.text = defaults.apiKey;
              _modelNameController.text = defaults.modelName;
            },
            child: Text(
              '确认',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 私有小组件
// ─────────────────────────────────────────────

class _SliderTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String? valueLabel;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.subtitle,
    this.valueLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
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
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w500)),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Text(
                valueLabel ?? value.toStringAsFixed(0),
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
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Text(label),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      value: value,
      onChanged: onChanged,
    );
  }
}

class _DropdownTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _DropdownTile({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          DropdownButton<String>(
            value: items.contains(value) ? value : items.first,
            underline: const SizedBox.shrink(),
            items: items
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

class _TextTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final TextEditingController controller;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onChanged;  // ← 新增

  const _TextTile({
    required this.label,
    required this.controller,
    this.subtitle,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.onSubmitted,
    this.onEditingComplete,
    this.onChanged,  // ← 新增
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.titleSmall),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              suffixIcon: suffixIcon,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            onSubmitted: onSubmitted,
            onEditingComplete: onEditingComplete,
            onChanged: onChanged, 
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}