import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/services/llm_service.dart';
import '../../../domain/services/region_service.dart';
import '../../providers/ai_preset_providers.dart';
import '../../providers/image_gen_providers.dart';
import '../../providers/settings_providers.dart';
import '../../router/app_router.dart';
import '../../providers/llm_configs_provider.dart';
import '../../dialogs/image_gen_config_dialog.dart';
import '../../dialogs/advanced_sampling_dialog.dart';
import '../../dialogs/logit_bias_dialog.dart';
import '../../dialogs/ai_preset_dialog.dart';
import '../../dialogs/regex_system_dialog.dart';
import '../../dialogs/prompt_manager_dialog.dart';
import '../../dialogs/global_worldbook_dialog.dart';
import '../../dialogs/chronicle_settings_dialog.dart';
import 'package:kirakira/presentation/providers/chronicle_providers.dart';
import 'package:drift/drift.dart' as drift;
import '../../../data/database/database.dart';

/// Provider for China region detection
final isChinaRegionProvider = FutureProvider<bool>((ref) async {
  return await RegionService.isChinaRegion();
});

/// API connection status for overview cards
enum ApiStatus { connected, notConfigured, error, testing }

/// AI Configuration screen - top-level entry for all AI-related settings
class AIConfigScreen extends ConsumerStatefulWidget {
  const AIConfigScreen({super.key});

  @override
  ConsumerState<AIConfigScreen> createState() => _AIConfigScreenState();
}

class _AIConfigScreenState extends ConsumerState<AIConfigScreen> {
  /// [极客Core迁移 P2] LLM卡采样参数展开区(默认折叠,展开才渲染Slider省内存)
  bool _samplingExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: isDark
            ? const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.3, -0.5),
                  radius: 1.0,
                  colors: [Color(0xFF1A1A1A), Color(0xFF0D0D0D)],
                  stops: [0.0, 0.7],
                ),
              )
            : const BoxDecoration(color: Color(0xFFF7F8FA)),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: _buildStatusCards(context, ref, isDark),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildLlmConfigCard(context, ref, isDark),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildImageGenConfigCard(context, ref, isDark),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _buildQuickActionsCard(context, ref, isDark),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }

  // ─── 概览卡片方法 ───

  Widget _buildStatusCards(BuildContext context, WidgetRef ref, bool isDark) {
    final llmConfig = ref.watch(llmConfigProvider);
    final imageGenSettings = ref.watch(imageGenSettingsProvider);
    final testState = ref.watch(connectionTestProvider);
    final chronicleEnabled = ref.watch(chronicleSettingsProvider).enabled;

    final llmStatus = llmConfig.apiUrl.isEmpty
        ? ApiStatus.notConfigured
        : (testState.status == ConnectionStatus.success
            ? ApiStatus.connected
            : testState.status == ConnectionStatus.error
                ? ApiStatus.error
                : ApiStatus.notConfigured);

    final imageStatus = imageGenSettings.enabled
        ? ApiStatus.connected
        : ApiStatus.notConfigured;

    // [CHRONICLE UI整合] 顶部第三个状态卡：旧"全局书"入口删除（保留下方快捷区的世界书），
    // 替换为Chronicle超级记忆入口，直接弹全局设置浮窗，不依赖是否进入聊天。
    final chronicleStatus =
        chronicleEnabled ? ApiStatus.connected : ApiStatus.notConfigured;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatusCard(
              icon: CupertinoIcons.chat_bubble_2_fill,
              iconColor: const Color(0xFF42A5F5),
              label: '对话模型',
              status: llmStatus,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatusCard(
              icon: CupertinoIcons.photo_fill,
              iconColor: const Color(0xFFEC407A),
              label: '图像生成',
              status: imageStatus,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatusCard(
              icon: Icons.auto_stories,
              iconColor: const Color(0xFF9C6ADE),
              label: chronicleEnabled ? '记忆已开启' : '记忆已关闭',
              status: chronicleStatus,
              isDark: isDark,
              onTap: () => showChronicleSettingsDialog(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    ApiStatus? status,
    bool isDark = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: isDark
                ? null
                : Border.all(color: Colors.black.withValues(alpha: 0.05), width: 0.5),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(height: 8),
              if (status != null) _buildStatusIcon(status),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF8C8C8C) : const Color(0xFF8E8E93),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(ApiStatus status) {
    switch (status) {
      case ApiStatus.connected:
        return const Icon(Icons.check_circle, size: 20, color: Color(0xFF4CAF50));
      case ApiStatus.notConfigured:
        return const Icon(Icons.circle_outlined, size: 20, color: Color(0xFF9E9E9E));
      case ApiStatus.error:
        return const Icon(Icons.error, size: 20, color: Color(0xFFF44336));
      case ApiStatus.testing:
        return const SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
    }
  }

  Widget _buildLlmConfigCard(BuildContext context, WidgetRef ref, bool isDark) {
    final llmConfig = ref.watch(llmConfigProvider);
    final testState = ref.watch(connectionTestProvider);
    final llmConfigs = ref.watch(llmConfigsProvider);
    final activePreset = ref.watch(activeAIPresetProvider);

    final status = llmConfig.apiUrl.isEmpty
        ? ApiStatus.notConfigured
        : (testState.status == ConnectionStatus.success
            ? ApiStatus.connected
            : testState.status == ConnectionStatus.error
                ? ApiStatus.error
                : ApiStatus.notConfigured);

    final schemeName = llmConfigs.active?.name ?? activePreset?.name ?? '默认';
    final urlDisplay = llmConfig.apiUrl.isEmpty
        ? '未配置'
        : llmConfig.apiUrl.replaceAll('https://', '').replaceAll('http://', '');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? null
            : Border.all(color: Colors.black.withValues(alpha: 0.05), width: 0.5),
        boxShadow: isDark
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(CupertinoIcons.chat_bubble_2_fill, size: 20, color: Color(0xFF42A5F5)),
                const SizedBox(width: 8),
                const Text('对话模型', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const Spacer(),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minSize: 0,
                  onPressed: () => _showLlmConfigSwitcher(context, ref),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(schemeName, style: const TextStyle(fontSize: 13, color: DesignTokens.primary)),
                      const SizedBox(width: 4),
                      const Icon(CupertinoIcons.chevron_down, size: 14, color: DesignTokens.primary),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildCompactInfoRow('方案', schemeName, isDark),
            const SizedBox(height: 6),
            _buildCompactInfoRow('URL', urlDisplay, isDark),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _buildCompactInfoRow('模型', llmConfig.model.isNotEmpty ? llmConfig.model : '未配置', isDark)),
                const SizedBox(width: 8),
                _buildCompactStatusIcon(status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                    minSize: 0,
                    onPressed: () => ref.read(connectionTestProvider.notifier).testConnection(llmConfig),
                    child: Text('测试连接', style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C))),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    color: DesignTokens.primary,
                    borderRadius: BorderRadius.circular(8),
                    minSize: 0,
                    onPressed: () => _showLlmConfigDialog(context, ref),
                    child: const Text('完整配置', style: TextStyle(fontSize: 13, color: Colors.white)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ══ [极客Core迁移 P2] 采样参数折叠区(默认收起,展开才渲染Slider) ══
            _buildSamplingExpansion(context, ref, isDark),
          ],
        ),
      ),
    );
  }

  /// 采样参数折叠区:标题行(温度/TopP/TopK/令牌数/上下文摘要)+ 展开Slider
  /// + 底部 [更多参数 →] [Logit偏置 →] 两个浮窗入口
  Widget _buildSamplingExpansion(BuildContext context, WidgetRef ref, bool isDark) {
    final config = ref.watch(llmConfigProvider);
    final dividerColor = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 0.5, thickness: 0.5, color: dividerColor),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _samplingExpanded = !_samplingExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.slider_horizontal_3,
                    size: 18,
                    color: DesignTokens.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '采样参数',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _samplingExpanded
                          ? ''
                          : '温度 ${config.temperature.toStringAsFixed(2)} · '
                            'T${config.topP.toStringAsFixed(2)} · '
                            'K${config.topK} · '
                            '${config.maxTokens} · '
                            '上下文 ${_fmtContext(config.contextLength)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF8C8C8C) : const Color(0xFF8E8E93),
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _samplingExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      CupertinoIcons.chevron_down,
                      size: 14,
                      color: isDark ? const Color(0xFF8C8C8C) : const Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // 展开时才渲染 Slider(节省内存)
        if (_samplingExpanded) ...[
          const SizedBox(height: 4),
          _MiniSlider(
            label: '温度',
            value: config.temperature,
            min: 0.0, max: 2.0, divisions: 40,
            display: config.temperature.toStringAsFixed(2),
            onChanged: (v) =>
                ref.read(llmConfigProvider.notifier).updateTemperature(v),
          ),
          _MiniSlider(
            label: 'Top P',
            value: config.topP,
            min: 0.0, max: 1.0, divisions: 20,
            display: config.topP.toStringAsFixed(2),
            onChanged: (v) => ref.read(llmConfigProvider.notifier).updateTopP(v),
          ),
          _MiniSlider(
            label: 'Top K',
            value: config.topK.toDouble(),
            min: 0, max: 200, divisions: 200,
            display: '${config.topK}',
            onChanged: (v) =>
                ref.read(llmConfigProvider.notifier).updateTopK(v.round()),
          ),
          _MiniSlider(
            label: '最大令牌数',
            value: config.maxTokens.toDouble(),
            min: 64, max: 4096, divisions: 63,
            display: '${config.maxTokens}',
            onChanged: (v) =>
                ref.read(llmConfigProvider.notifier).updateMaxTokens(v.round()),
          ),
          _MiniSlider(
            label: '上下文长度',
            value: config.contextLength.toDouble(),
            min: 512, max: 131072, divisions: 32,
            display: '${config.contextLength}',
            onChanged: (v) => ref
                .read(llmConfigProvider.notifier)
                .updateContextLength(v.round()),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
                minSize: 0,
                onPressed: () => showAdvancedSamplingDialog(context, ref),
                child: Text(
                  '更多参数 →',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
                minSize: 0,
                onPressed: () => showLogitBiasDialog(context, ref),
                child: Text(
                  'Logit偏置 →',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _fmtContext(int v) => v >= 1024 ? '${(v / 1024).toStringAsFixed(0)}K' : '$v';

  void _showLlmConfigSwitcher(BuildContext context, WidgetRef ref) {
    final llmConfigs = ref.read(llmConfigsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    _showConfigSwitcherDialog(
      ctx: context,
      ref: ref,
      allConfigs: llmConfigs.configs,
      currentConfigName: llmConfigs.active?.name ?? '',
      onSwitchConfig: (config) => ref.read(llmConfigsProvider.notifier).setActive(config.id),
      onNewConfig: () => _showLlmConfigDialog(context, ref),
      isDark: isDark,
    );
  }

  // ══════════════════════════════════════════════════════════
  // 对话模型配置浮窗 —— 从零实现，不再复用 QuickSetupCard
  // - Material 包裹整个浮窗，避免 "No Material widget found" 错误
  // - 中性灰黑配色（#1C1C1C / #FFFFFF），无任何蓝调
  // - StatefulBuilder 管理表单状态，TextEditingController 在方法作用域创建
  // ══════════════════════════════════════════════════════════
  void _showLlmConfigDialog(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final currentConfig = ref.read(llmConfigProvider);
    final llmConfigs = ref.read(llmConfigsProvider);
    final rootContext = context;

    // 表单控制器（方法作用域创建，弹窗关闭后统一释放）
    final nameController = TextEditingController(text: llmConfigs.active?.name ?? '');
    final urlController = TextEditingController(text: currentConfig.apiUrl);
    final keyController = TextEditingController(text: currentConfig.apiKey);
    final modelController = TextEditingController(text: currentConfig.model);

    // 局部可变状态
    LLMProvider selectedProvider = currentConfig.provider;
    List<String> availableModels = [];
    bool isFetchingModels = false;
    bool isTestingConnection = false;
    bool obscureKey = true;
    String? testResult;
    String activeConfigName = llmConfigs.active?.name ?? '';

    String defaultUrlForProvider(LLMProvider p) {
      switch (p) {
        case LLMProvider.openai:
          return 'https://api.openai.com/v1';
        case LLMProvider.claude:
          return 'https://api.anthropic.com';
        case LLMProvider.openRouter:
          return 'https://openrouter.ai/api/v1';
        case LLMProvider.gemini:
          return 'https://generativelanguage.googleapis.com/v1';
        case LLMProvider.ollama:
          return 'http://localhost:11434';
        case LLMProvider.koboldCpp:
          return 'http://localhost:5001';
        case LLMProvider.deepSeek:
          return 'https://api.deepseek.com/v1';
        case LLMProvider.qwen:
          return 'https://dashscope.aliyuncs.com/compatible-mode/v1';
        case LLMProvider.openAICompatible:
          return 'http://localhost:8080/v1';
      }
    }

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setState) {
          return Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: screenWidth - 48 < 550 ? screenWidth - 48 : 550.0,
                constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ===== 标题栏 =====
                    _buildDialogHeader(
                      isDark: isDark,
                      currentConfigName: activeConfigName,
                      onShowSwitcher: () {
                        final configs = ref.read(llmConfigsProvider).configs;
                        _showConfigSwitcherDialog(
                          ctx: ctx,
                          ref: ref,
                          allConfigs: configs,
                          currentConfigName: activeConfigName,
                          onSwitchConfig: (config) async {
                            await ref.read(llmConfigsProvider.notifier).setActive(config.id);
                            final newConfig = ref.read(llmConfigProvider);
                            setState(() {
                              activeConfigName = config.name;
                              nameController.text = config.name;
                              urlController.text = newConfig.apiUrl;
                              keyController.text = newConfig.apiKey;
                              modelController.text = newConfig.model;
                              selectedProvider = newConfig.provider;
                              availableModels = [];
                              testResult = null;
                            });
                          },
                          onNewConfig: () {
                            setState(() {
                              activeConfigName = '';
                              nameController.clear();
                              selectedProvider = LLMProvider.openAICompatible;
                              urlController.text = defaultUrlForProvider(LLMProvider.openAICompatible);
                              keyController.clear();
                              modelController.clear();
                              availableModels = [];
                              testResult = null;
                            });
                          },
                          isDark: isDark,
                        );
                      },
                      onClose: () => Navigator.pop(dialogContext),
                    ),
                    // ===== 滚动内容区 =====
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. 方案名称
                            _buildSectionLabel('方案名称', isDark),
                            const SizedBox(height: 8),
                            _buildDialogTextField(
                              controller: nameController,
                              hint: '例如：GPT-4默认',
                              isDark: isDark,
                            ),
                            const SizedBox(height: 20),
                            // 2. 接口类型
                            _buildSectionLabel('接口类型', isDark),
                            const SizedBox(height: 8),
                            _buildProviderChips(
                              selectedProvider: selectedProvider,
                              isDark: isDark,
                              onSelect: (p) {
                                setState(() {
                                  selectedProvider = p;
                                  urlController.text = defaultUrlForProvider(p);
                                  availableModels = [];
                                });
                              },
                            ),
                            const SizedBox(height: 20),
                            // 3. API 地址
                            _buildSectionLabel('API 地址', isDark),
                            const SizedBox(height: 8),
                            _buildDialogTextField(
                              controller: urlController,
                              hint: 'https://api.openai.com/v1',
                              isDark: isDark,
                            ),
                            const SizedBox(height: 20),
                            // 4. API 密钥
                            _buildSectionLabel('API 密钥', isDark),
                            const SizedBox(height: 8),
                            _buildDialogTextField(
                              controller: keyController,
                              hint: 'sk-...',
                              isDark: isDark,
                              obscureText: obscureKey,
                              suffix: GestureDetector(
                                onTap: () => setState(() => obscureKey = !obscureKey),
                                child: Icon(
                                  obscureKey ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                                  size: 18,
                                  color: isDark ? const Color(0xFF8C8C8C) : const Color(0xFF8E8E93),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // 5. 拉取可用模型
                            _buildDialogActionButton(
                              label: isFetchingModels ? '拉取中...' : '拉取可用模型',
                              icon: CupertinoIcons.cloud_download,
                              isDark: isDark,
                              isLoading: isFetchingModels,
                              onTap: () async {
                                final url = urlController.text.trim();
                                final key = keyController.text.trim();
                                if (url.isEmpty || key.isEmpty) {
                                  _showDialogSnackBar(rootContext, '请先填写 API 地址和密钥');
                                  return;
                                }
                                setState(() => isFetchingModels = true);
                                try {
                                  final tempConfig = currentConfig.copyWith(
                                    provider: selectedProvider,
                                    apiUrl: url,
                                    apiKey: key,
                                    model: modelController.text.trim(),
                                  );
                                  await ref.read(modelFetchProvider.notifier).fetchModels(tempConfig);
                                  if (!ctx.mounted) return;
                                  final fetchState = ref.read(modelFetchProvider);
                                  setState(() {
                                    isFetchingModels = false;
                                    if (fetchState.status == ModelFetchStatus.success) {
                                      availableModels = fetchState.models;
                                    }
                                  });
                                  if (fetchState.status == ModelFetchStatus.error) {
                                    _showDialogSnackBar(ctx, '拉取失败: ${fetchState.errorMessage ?? "请检查地址和密钥"}');
                                  } else if (availableModels.isNotEmpty) {
                                    _showModelPickerDialog(
                                      ctx,
                                      availableModels,
                                      (m) => setState(() => modelController.text = m),
                                      isDark,
                                    );
                                  }
                                } catch (e) {
                                  setState(() => isFetchingModels = false);
                                  if (ctx.mounted) _showDialogSnackBar(ctx, '拉取失败: $e');
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            // 6. 模型名称（手动输入 + 可从列表选择）
                            _buildSectionLabel(
                              availableModels.isNotEmpty ? '模型名称（可从列表选择）' : '模型名称（手动输入）',
                              isDark,
                            ),
                            const SizedBox(height: 8),
                            _buildDialogTextField(
                              controller: modelController,
                              hint: 'gpt-4-turbo',
                              isDark: isDark,
                            ),
                            if (availableModels.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _buildSecondaryButton(
                                label: '从列表选择',
                                icon: CupertinoIcons.list_bullet,
                                isDark: isDark,
                                onTap: () => _showModelPickerDialog(
                                  ctx,
                                  availableModels,
                                  (m) => setState(() => modelController.text = m),
                                  isDark,
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            // 7. 测试连接
                            _buildDialogActionButton(
                              label: isTestingConnection ? '测试中...' : '测试连接',
                              icon: CupertinoIcons.arrow_2_circlepath,
                              isDark: isDark,
                              isLoading: isTestingConnection,
                              onTap: () async {
                                final url = urlController.text.trim();
                                final key = keyController.text.trim();
                                final model = modelController.text.trim();
                                if (url.isEmpty || key.isEmpty || model.isEmpty) {
                                  _showDialogSnackBar(rootContext, '请填写完整配置信息');
                                  return;
                                }
                                setState(() {
                                  isTestingConnection = true;
                                  testResult = null;
                                });
                                try {
                                  final tempConfig = currentConfig.copyWith(
                                    provider: selectedProvider,
                                    apiUrl: url,
                                    apiKey: key,
                                    model: model,
                                  );
                                  await ref.read(connectionTestProvider.notifier).testConnection(tempConfig);
                                  final testState = ref.read(connectionTestProvider);
                                  setState(() {
                                    isTestingConnection = false;
                                    if (testState.status == ConnectionStatus.success) {
                                      testResult = '✓ 连接成功';
                                    } else if (testState.status == ConnectionStatus.error) {
                                      testResult = '✗ ${testState.message ?? "连接失败"}';
                                    } else {
                                      testResult = null;
                                    }
                                  });
                                } catch (e) {
                                  setState(() {
                                    isTestingConnection = false;
                                    testResult = '✗ 错误: $e';
                                  });
                                }
                              },
                            ),
                            if (testResult != null) ...[
                              const SizedBox(height: 12),
                              _buildTestResult(testResult!, isDark),
                            ],
                            const SizedBox(height: 20),
                            // 8. 极客Probe深度检测
                            _buildSecondaryButton(
                              label: '极客Probe深度检测',
                              icon: CupertinoIcons.speedometer,
                              isDark: isDark,
                              onTap: () {
                                Navigator.pop(dialogContext);
                                context.push(AppRoutes.modelDetection);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    // ===== 底部操作栏 =====
                    _buildDialogFooter(
                      isDark: isDark,
                      onCancel: () => Navigator.pop(dialogContext),
                      onSave: () async {
                        final name = nameController.text.trim();
                        final url = urlController.text.trim();
                        final key = keyController.text.trim();
                        final model = modelController.text.trim();
                        if (name.isEmpty || url.isEmpty || key.isEmpty || model.isEmpty) {
                          _showDialogSnackBar(rootContext, '请填写完整配置信息');
                          return;
                        }
                        // 1. 写入运行时配置
                        if (selectedProvider != currentConfig.provider) {
                          await ref.read(llmConfigProvider.notifier).updateProvider(selectedProvider);
                        }
                        ref.read(llmConfigProvider.notifier).updateApiUrl(url);
                        ref.read(llmConfigProvider.notifier).updateApiKey(key);
                        ref.read(llmConfigProvider.notifier).updateModel(model);
                        // 2. 同步多方案表（更新或新建当前方案）
                        final active = ref.read(llmConfigsProvider).active;
                        final now = DateTime.now();
                        await ref.read(llmConfigsProvider.notifier).upsert(LlmConfigsCompanion(
                          id: drift.Value(active?.id ?? now.millisecondsSinceEpoch.toString()),
                          name: drift.Value(name),
                          provider: drift.Value(selectedProvider.name),
                          endpoint: drift.Value(url),
                          apiKey: drift.Value(key),
                          model: drift.Value(model),
                          enabled: const drift.Value(true),
                          isDefault: const drift.Value(true),
                          defaultSettingsJson: drift.Value(active?.defaultSettingsJson ?? '{}'),
                          createdAt: drift.Value(active?.createdAt ?? now),
                          modifiedAt: drift.Value(now),
                        ));
                        if (rootContext.mounted) {
                          Navigator.pop(dialogContext);
                          _showDialogSnackBar(rootContext, '配置已保存');
                        }
                      },
                      onSaveAsNew: () async {
                        final name = nameController.text.trim();
                        final url = urlController.text.trim();
                        final key = keyController.text.trim();
                        final model = modelController.text.trim();
                        if (name.isEmpty || url.isEmpty || key.isEmpty || model.isEmpty) {
                          _showDialogSnackBar(ctx, '请填写完整配置信息');
                          return;
                        }
                        final now = DateTime.now();
                        final newId = now.millisecondsSinceEpoch.toString();
                        await ref.read(llmConfigsProvider.notifier).upsert(LlmConfigsCompanion(
                          id: drift.Value(newId),
                          name: drift.Value(name),
                          provider: drift.Value(selectedProvider.name),
                          endpoint: drift.Value(url),
                          apiKey: drift.Value(key),
                          model: drift.Value(model),
                          enabled: const drift.Value(true),
                          isDefault: const drift.Value(true),
                          defaultSettingsJson: const drift.Value('{}'),
                          createdAt: drift.Value(now),
                          modifiedAt: drift.Value(now),
                        ));
                        await ref.read(llmConfigsProvider.notifier).setActive(newId);
                        final runtimeConfig = ref.read(llmConfigProvider);
                        if (selectedProvider != runtimeConfig.provider) {
                          await ref.read(llmConfigProvider.notifier).updateProvider(selectedProvider);
                        }
                        ref.read(llmConfigProvider.notifier).updateApiUrl(url);
                        ref.read(llmConfigProvider.notifier).updateApiKey(key);
                        ref.read(llmConfigProvider.notifier).updateModel(model);
                        if (ctx.mounted) {
                          setState(() => activeConfigName = name);
                          _showDialogSnackBar(ctx, '已保存为新方案');
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ).then((_) {
      nameController.dispose();
      urlController.dispose();
      keyController.dispose();
      modelController.dispose();
    });
  }

  // ===== 浮窗组件（全部从零实现，不复用 QuickSetupCard） =====

  Widget _buildDialogHeader({
    required bool isDark,
    required String currentConfigName,
    required VoidCallback onShowSwitcher,
    required VoidCallback onClose,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.chat_bubble_2_fill, size: 20, color: Color(0xFF42A5F5)),
          const SizedBox(width: 8),
          Text(
            '对话模型配置',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
            ),
          ),
          const Spacer(),
          // ===== 方案下拉菜单 =====
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minSize: 0,
            onPressed: onShowSwitcher,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentConfigName.isEmpty ? '默认方案' : currentConfigName,
                  style: const TextStyle(fontSize: 14, color: DesignTokens.primary),
                ),
                const SizedBox(width: 4),
                const Icon(CupertinoIcons.chevron_down, size: 14, color: DesignTokens.primary),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            onPressed: onClose,
            child: Icon(
              CupertinoIcons.xmark_circle_fill,
              size: 24,
              color: isDark ? const Color(0xFF6C6C6C) : const Color(0xFFBDBDBD),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogFooter({
    required bool isDark,
    required VoidCallback onCancel,
    required VoidCallback onSave,
    required VoidCallback onSaveAsNew,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                  onPressed: onCancel,
                  child: Text(
                    '取消',
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: DesignTokens.primary,
                  borderRadius: BorderRadius.circular(10),
                  onPressed: onSave,
                  child: const Text('保存', style: TextStyle(fontSize: 15, color: Colors.white)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 保存为新方案
          CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 10),
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            onPressed: onSaveAsNew,
            child: const Text(
              '保存为新方案',
              style: TextStyle(fontSize: 15, color: DesignTokens.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, bool isDark) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
      ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return CupertinoTextField(
      controller: controller,
      placeholder: hint,
      obscureText: obscureText,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      style: TextStyle(
        fontSize: 14,
        color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
      ),
      suffix: suffix,
    );
  }

  Widget _buildProviderChips({
    required LLMProvider selectedProvider,
    required bool isDark,
    required ValueChanged<LLMProvider> onSelect,
  }) {
    const providers = <LLMProvider, (String, String)>{
      LLMProvider.openAICompatible: ('OpenAI兼容', '推荐·多数中转'),
      LLMProvider.openai: ('OpenAI', '官方'),
      LLMProvider.claude: ('Claude', 'Anthropic'),
      LLMProvider.gemini: ('Gemini', 'Google'),
      LLMProvider.deepSeek: ('DeepSeek', '深度求索'),
      LLMProvider.qwen: ('通义千问', '阿里'),
      LLMProvider.openRouter: ('OpenRouter', '聚合'),
      LLMProvider.ollama: ('Ollama', '本地'),
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: providers.entries.map((e) {
        final isSelected = selectedProvider == e.key;
        final name = e.value.$1;
        final desc = e.value.$2;
        return GestureDetector(
          onTap: () => onSelect(e.key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? DesignTokens.primary.withValues(alpha: 0.15)
                  : (isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5)),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? DesignTokens.primary
                    : (isDark ? const Color(0xFF3C3C3C) : const Color(0xFFE0E0E0)),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? DesignTokens.primary
                        : (isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C)),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF8C8C8C) : const Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDialogActionButton({
    required String label,
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(10),
      onPressed: isLoading ? null : onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(DesignTokens.primary),
              ),
            )
          else
            Icon(icon, size: 18, color: DesignTokens.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryButton({
    required String label,
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(10),
      onPressed: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: const Color(0xFFAB47BC)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestResult(String result, bool isDark) {
    final isSuccess = result.startsWith('✓');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSuccess
            ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
            : const Color(0xFFF44336).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.error,
            size: 18,
            color: isSuccess ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              result,
              style: TextStyle(
                fontSize: 14,
                color: isSuccess ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showModelPickerDialog(
    BuildContext context,
    List<String> models,
    ValueChanged<String> onSelect,
    bool isDark,
  ) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogCtx) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(dialogCtx).size.width - 64 < 400
                ? MediaQuery.of(dialogCtx).size.width - 64
                : 400.0,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(dialogCtx).size.height * 0.6,
            ),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        '选择模型',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
                        ),
                      ),
                      const Spacer(),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minSize: 0,
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: Icon(
                          CupertinoIcons.xmark_circle_fill,
                          size: 24,
                          color: isDark ? const Color(0xFF6C6C6C) : const Color(0xFFBDBDBD),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0)),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: models.length,
                    itemBuilder: (_, i) {
                      final m = models[i];
                      return ListTile(
                        title: Text(
                          m,
                          style: TextStyle(
                            color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
                          ),
                        ),
                        onTap: () {
                          onSelect(m);
                          Navigator.pop(dialogCtx);
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
    );
  }

  // ══════════════════════════════════════════════════════════
  // 方案管理浮窗（居中 Dialog · 无 BottomSheet）
  // ══════════════════════════════════════════════════════════
  void _showConfigSwitcherDialog({
    required BuildContext ctx,
    required WidgetRef ref,
    required List<LlmConfig> allConfigs,
    required String currentConfigName,
    required Future<void> Function(LlmConfig) onSwitchConfig,
    required VoidCallback onNewConfig,
    required bool isDark,
  }) {
    showDialog<void>(
      context: ctx,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogCtx) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(dialogCtx).size.width - 64 < 400
                ? MediaQuery.of(dialogCtx).size.width - 64
                : 400.0,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(dialogCtx).size.height * 0.7,
            ),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题栏
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.square_stack_3d_up_fill, size: 20, color: Color(0xFFFFA726)),
                      const SizedBox(width: 8),
                      Text(
                        '切换方案',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
                        ),
                      ),
                      const Spacer(),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minSize: 0,
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: Icon(
                          CupertinoIcons.xmark_circle_fill,
                          size: 24,
                          color: isDark ? const Color(0xFF6C6C6C) : const Color(0xFFBDBDBD),
                        ),
                      ),
                    ],
                  ),
                ),
                // 方案列表
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      ...allConfigs.map((config) {
                        final isActive = config.name == currentConfigName && config.isDefault;
                        final displayName = config.name.isEmpty ? '未命名方案' : config.name;
                        final urlDisplay = config.endpoint
                            .replaceAll('https://', '')
                            .replaceAll('http://', '');
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              onSwitchConfig(config);
                              Navigator.pop(dialogCtx);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Icon(
                                    isActive
                                        ? CupertinoIcons.checkmark_circle_fill
                                        : CupertinoIcons.circle,
                                    size: 20,
                                    color: isActive
                                        ? DesignTokens.primary
                                        : (isDark ? const Color(0xFF6C6C6C) : const Color(0xFFBDBDBD)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                                            color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$urlDisplay • ${config.model ?? '未配置'}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? const Color(0xFF8C8C8C) : const Color(0xFF8E8E93),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  // 重命名 / 删除
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CupertinoButton(
                                        padding: const EdgeInsets.all(4),
                                        minSize: 0,
                                        onPressed: () {
                                          Navigator.pop(dialogCtx);
                                          _showRenameDialog(ctx, ref, config, isDark);
                                        },
                                        child: Icon(
                                          CupertinoIcons.pencil,
                                          size: 18,
                                          color: isDark ? const Color(0xFF8C8C8C) : const Color(0xFF8E8E93),
                                        ),
                                      ),
                                      if (allConfigs.length > 1)
                                        CupertinoButton(
                                          padding: const EdgeInsets.all(4),
                                          minSize: 0,
                                          onPressed: () {
                                            Navigator.pop(dialogCtx);
                                            _showDeleteConfirmDialog(ctx, ref, config, isDark);
                                          },
                                          child: const Icon(
                                            CupertinoIcons.trash,
                                            size: 18,
                                            color: Color(0xFFF44336),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                // 新建方案
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    color: DesignTokens.primary,
                    borderRadius: BorderRadius.circular(10),
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      onNewConfig();
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.add_circled, size: 18, color: Colors.white),
                        SizedBox(width: 8),
                        Text('新建方案', style: TextStyle(fontSize: 15, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    LlmConfig config,
    bool isDark,
  ) {
    final controller = TextEditingController(text: config.name);

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogCtx) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(dialogCtx).size.width - 64 < 400
                ? MediaQuery.of(dialogCtx).size.width - 64
                : 400.0,
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '重命名方案',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
                  ),
                ),
                const SizedBox(height: 16),
                CupertinoTextField(
                  controller: controller,
                  placeholder: '输入新名称',
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(10),
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: Text(
                          '取消',
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: DesignTokens.primary,
                        borderRadius: BorderRadius.circular(10),
                        onPressed: () async {
                          final newName = controller.text.trim();
                          if (newName.isEmpty) return;
                          await ref.read(llmConfigsProvider.notifier).upsert(LlmConfigsCompanion(
                            id: drift.Value(config.id),
                            name: drift.Value(newName),
                            provider: drift.Value(config.provider),
                            endpoint: drift.Value(config.endpoint),
                            apiKey: drift.Value(config.apiKey ?? ''),
                            model: drift.Value(config.model),
                            enabled: drift.Value(config.enabled),
                            isDefault: drift.Value(config.isDefault),
                            defaultSettingsJson: drift.Value(config.defaultSettingsJson),
                            createdAt: drift.Value(config.createdAt),
                            modifiedAt: drift.Value(DateTime.now()),
                          ));
                          if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        },
                        child: const Text('保存', style: TextStyle(fontSize: 15, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) => controller.dispose());
  }

  void _showDeleteConfirmDialog(
    BuildContext context,
    WidgetRef ref,
    LlmConfig config,
    bool isDark,
  ) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogCtx) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(dialogCtx).size.width - 64 < 400
                ? MediaQuery.of(dialogCtx).size.width - 64
                : 400.0,
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.exclamationmark_triangle_fill,
                  size: 48,
                  color: Color(0xFFF44336),
                ),
                const SizedBox(height: 16),
                Text(
                  '确认删除方案？',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '方案"${config.name.isEmpty ? "未命名方案" : config.name}"将被永久删除',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? const Color(0xFF8C8C8C) : const Color(0xFF8E8E93),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(10),
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: Text(
                          '取消',
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: const Color(0xFFF44336),
                        borderRadius: BorderRadius.circular(10),
                        onPressed: () async {
                          await ref.read(llmConfigsProvider.notifier).delete(config.id);
                          if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        },
                        child: const Text('删除', style: TextStyle(fontSize: 15, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDialogSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildCompactInfoRow(String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ', style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF8C8C8C) : const Color(0xFF8E8E93))),
        Expanded(
          child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C)), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _buildCompactStatusIcon(ApiStatus status) {
    return switch (status) {
      ApiStatus.connected => const Icon(Icons.check_circle, size: 18, color: Color(0xFF4CAF50)),
      ApiStatus.notConfigured => const Icon(Icons.circle_outlined, size: 18, color: Color(0xFF9E9E9E)),
      ApiStatus.error => const Icon(Icons.error, size: 18, color: Color(0xFFF44336)),
      ApiStatus.testing => const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
    };
  }

  Widget _buildImageGenConfigCard(BuildContext context, WidgetRef ref, bool isDark) {
    final settings = ref.watch(imageGenSettingsProvider);
    final status = settings.enabled ? ApiStatus.connected : ApiStatus.notConfigured;
    final providerName = settings.provider.displayName;
    final modelName = settings.model.isNotEmpty ? settings.model : '未配置';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? null
            : Border.all(color: Colors.black.withValues(alpha: 0.05), width: 0.5),
        boxShadow: isDark
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(CupertinoIcons.photo_fill, size: 20, color: Color(0xFFEC407A)),
                const SizedBox(width: 8),
                const Text('图像生成', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const Spacer(),
                _buildCompactStatusIcon(status),
              ],
            ),
            const SizedBox(height: 12),
            _buildCompactInfoRow('服务', providerName, isDark),
            const SizedBox(height: 6),
            _buildCompactInfoRow('模型', modelName, isDark),
            const SizedBox(height: 6),
            _buildCompactInfoRow('状态', settings.enabled ? '已启用' : '未启用', isDark),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: DesignTokens.primary,
                borderRadius: BorderRadius.circular(8),
                minSize: 0,
                onPressed: () => showImageGenConfigDialog(context, ref),
                child: const Text('完整配置', style: TextStyle(fontSize: 13, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard(
      BuildContext context, WidgetRef ref, bool isDark) {
    // [极客Core迁移 P2] Core块删除(极客Core功能已分流至各浮窗);
    // [P4] 扩展为四块:预设/世界书/正则/提示词。
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildQuickActionTile(
              icon: CupertinoIcons.square_stack_3d_up_fill,
              iconColor: const Color(0xFFFFA726),
              label: '预设',
              isDark: isDark,
              onTap: () => showAIPresetDialog(context, ref),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildQuickActionTile(
              icon: CupertinoIcons.book_fill,
              iconColor: const Color(0xFF26A69A),
              label: '世界书',
              isDark: isDark,
              onTap: () => showGlobalWorldbookDialog(context, ref),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildQuickActionTile(
              icon: CupertinoIcons.wand_stars,
              iconColor: const Color(0xFFAB47BC),
              label: '正则',
              isDark: isDark,
              onTap: () => showRegexSystemDialog(context, ref),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildQuickActionTile(
              icon: CupertinoIcons.list_bullet,
              iconColor: const Color(0xFF42A5F5),
              label: '提示词',
              isDark: isDark,
              onTap: () => showPromptManagerDialog(context, ref),
            ),
          ),
          // [CHRONICLE UI整合] 快捷区'记忆'瓷砖已移除：
          // 入口统一收口到顶部状态卡（全局书也仅保留本区'世界书'一个入口）。
        ],
      ),
    );
  }

  Widget _buildQuickActionTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: isDark
                ? null
                : Border.all(color: Colors.black.withValues(alpha: 0.05), width: 0.5),
            boxShadow: isDark
                ? null
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C)), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// [极客Core迁移 P2] 迷你滑块行(原极客Core仪表盘 _MiniSlider 原样复用)
// ═══════════════════════════════════════════════════════════════════════════
class _MiniSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  const _MiniSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = DesignTokens.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ),
            Text(
              display,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor: color,
            inactiveTrackColor:
                theme.textTheme.bodySmall?.color?.withValues(alpha: 0.18),
            thumbColor: color,
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
