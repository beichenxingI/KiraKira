import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/services/image_generation_service.dart';
import '../../domain/services/llm_service.dart';
import '../providers/image_gen_providers.dart';
import '../providers/settings_providers.dart';
import '../theme/design_tokens.dart';

void showImageGenConfigDialog(BuildContext context, WidgetRef ref) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (ctx) => const _ImageGenConfigDialog(),
  );
}

class _ImageGenConfigDialog extends ConsumerStatefulWidget {
  const _ImageGenConfigDialog();

  @override
  ConsumerState<_ImageGenConfigDialog> createState() => _ImageGenConfigDialogState();
}

class _ImageGenConfigDialogState extends ConsumerState<_ImageGenConfigDialog> {
  bool _autoImageExpanded = false;
  bool _promptOptExpanded = false;
  bool _advancedExpanded = false;

  bool _isFetchingModels = false;
  bool _isFetchingPromptOptModels = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final settings = ref.watch(imageGenSettingsProvider);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: min(screenWidth - 48, 600),
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
              _buildHeader(isDark),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildEnableToggle(settings, isDark),
                      if (settings.enabled) ...[
                        const SizedBox(height: 20),
                        _buildProviderTypeSelector(settings, isDark),
                        const SizedBox(height: 20),
                        if (_isCloudProvider(settings.provider))
                          _buildCloudConfig(settings, isDark)
                        else
                          _buildLocalConfig(settings, isDark),
                        const SizedBox(height: 20),
                        _buildQuickParams(settings, isDark),
                        const SizedBox(height: 12),
                        _buildAutoImageSection(settings, isDark),
                        const SizedBox(height: 12),
                        _buildPromptOptSection(settings, isDark),
                        const SizedBox(height: 12),
                        _buildAdvancedSection(settings, isDark),
                      ],
                    ],
                  ),
                ),
              ),
              _buildFooter(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
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
          const Icon(CupertinoIcons.photo_fill, size: 20, color: Color(0xFFEC407A)),
          const SizedBox(width: 8),
          Text('图像生成配置',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
              )),
          const Spacer(),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            onPressed: () => Navigator.pop(context),
            child: Icon(CupertinoIcons.xmark_circle_fill,
                size: 24,
                color: isDark ? const Color(0xFF6C6C6C) : const Color(0xFFBDBDBD)),
          ),
        ],
      ),
    );
  }

  Widget _buildEnableToggle(ImageGenSettings settings, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('启用图像生成',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
                    )),
                const SizedBox(height: 4),
                Text('关闭后将无法使用AI绘图功能',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF8C8C8C) : const Color(0xFF8E8E93),
                    )),
              ],
            ),
          ),
          CupertinoSwitch(
            value: settings.enabled,
            activeColor: DesignTokens.primary,
            onChanged: (v) => ref.read(imageGenSettingsProvider.notifier).setEnabled(v),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderTypeSelector(ImageGenSettings settings, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('服务类型',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
            )),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<ImageGenProvider>(
            value: settings.provider,
            isExpanded: true,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: ImageGenProvider.openai, child: Text('☁️ OpenAI 兼容（云端）')),
              DropdownMenuItem(value: ImageGenProvider.openaiChat, child: Text('☁️ OpenAI-Chat（云端）')),
              DropdownMenuItem(value: ImageGenProvider.gemini, child: Text('☁️ Gemini（云端）')),
              DropdownMenuItem(value: ImageGenProvider.novelai, child: Text('💻 NovelAI')),
              DropdownMenuItem(value: ImageGenProvider.latentMoe, child: Text('💻 Latent.moe')),
              DropdownMenuItem(value: ImageGenProvider.automatic1111, child: Text('💻 Stable Diffusion (A1111)')),
              DropdownMenuItem(value: ImageGenProvider.comfyui, child: Text('💻 ComfyUI')),
              DropdownMenuItem(value: ImageGenProvider.localDream, child: Text('💻 Local Dream')),
            ],
            onChanged: (p) {
              if (p != null) {
                ref.read(imageGenSettingsProvider.notifier).setProvider(p);
              }
            },
          ),
        ),
      ],
    );
  }

  bool _isCloudProvider(ImageGenProvider p) =>
      p == ImageGenProvider.openai ||
      p == ImageGenProvider.openaiChat ||
      p == ImageGenProvider.gemini;

  // ========== 云端配置 ==========
  Widget _buildCloudConfig(ImageGenSettings settings, bool isDark) {
    final currentModel = settings.model;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('☁️ 云端服务配置',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
            )),
        const SizedBox(height: 12),
        _buildTextField(
          label: 'Base URL',
          value: settings.effectiveEndpoint,
          hint: settings.provider.defaultEndpoint,
          isDark: isDark,
          onChanged: (v) => ref.read(imageGenSettingsProvider.notifier).setApiEndpoint(v),
        ),
        const SizedBox(height: 12),
        _buildTextField(
          label: 'API Key',
          value: settings.apiKey ?? '',
          hint: 'sk-...',
          obscureText: true,
          isDark: isDark,
          onChanged: (v) => ref.read(imageGenSettingsProvider.notifier).setApiKey(v),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: DesignTokens.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            onPressed: _isFetchingModels ? null : _fetchModels,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isFetchingModels)
                  const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, valueColor: AlwaysStoppedAnimation(DesignTokens.primary)))
                else
                  const Icon(CupertinoIcons.arrow_clockwise, size: 18, color: DesignTokens.primary),
                const SizedBox(width: 8),
                Text(_isFetchingModels ? '拉取中...' : '拉取可用模型',
                    style: const TextStyle(fontSize: 15, color: DesignTokens.primary)),
              ],
            ),
          ),
        ),
        if (currentModel.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('当前模型: $currentModel',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF8C8C8C) : const Color(0xFF8E8E93),
              )),
        ],
        const SizedBox(height: 12),
        _buildTextField(
          label: '或手动输入模型名称',
          value: currentModel,
          hint: 'dall-e-3 / gemini-2.0-flash-image',
          isDark: isDark,
          onChanged: (v) => ref.read(imageGenSettingsProvider.notifier).setModel(v.trim()),
        ),
      ],
    );
  }

  Future<void> _fetchModels() async {
    final settings = ref.read(imageGenSettingsProvider);
    final baseUrl = settings.effectiveEndpoint;
    final apiKey = settings.apiKey;
    if (baseUrl.isEmpty || apiKey == null || apiKey.isEmpty) {
      _showSnackBar('请先填写 Base URL 和 API Key');
      return;
    }
    setState(() => _isFetchingModels = true);
    try {
      final llmProvider = LLMProvider.values.firstWhere(
        (p) => p.name == settings.provider.id,
        orElse: () => LLMProvider.openAICompatible,
      );
      final tempConfig = LLMConfig(
        provider: llmProvider,
        apiKey: apiKey,
        apiUrl: baseUrl,
        model: settings.model,
      );
      final models =
          await ref.read(llmServiceProvider).getAvailableModels(tempConfig);
      if (!mounted) return;
      setState(() => _isFetchingModels = false);
      if (models.isNotEmpty) {
        _showModelSelectDialog(models, settings.model,
            (m) => ref.read(imageGenSettingsProvider.notifier).setModel(m));
      } else {
        _showSnackBar('未拉取到模型，请检查地址和密钥');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isFetchingModels = false);
      _showSnackBar('拉取失败: $e');
    }
  }

  // ===== 模型选择浮窗（居中 Dialog）=====
  void _showModelSelectDialog(
    List<String> models,
    String? currentModel,
    ValueChanged<String> onSelect,
  ) {
    String? selected = models.contains(currentModel) ? currentModel : null;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setState) => Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(ctx).size.width - 64 < 400
                  ? MediaQuery.of(ctx).size.width - 64
                  : 400.0,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.7,
              ),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Theme.of(ctx).brightness == Brightness.dark
                    ? const Color(0xFF1C1C1C)
                    : Colors.white,
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
                          color: Theme.of(ctx).brightness == Brightness.dark
                              ? const Color(0xFF2C2C2C)
                              : const Color(0xFFE0E0E0),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.cube_box_fill,
                            size: 20, color: DesignTokens.primary),
                        const SizedBox(width: 8),
                        Text('选择模型',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(ctx).brightness == Brightness.dark
                                  ? const Color(0xFFF0F0F0)
                                  : const Color(0xFF2C2C2C),
                            )),
                        const Spacer(),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minSize: 0,
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: Icon(CupertinoIcons.xmark_circle_fill,
                              size: 24,
                              color: Theme.of(ctx).brightness == Brightness.dark
                                  ? const Color(0xFF6C6C6C)
                                  : const Color(0xFFBDBDBD)),
                        ),
                      ],
                    ),
                  ),
                  // 模型列表（可滚动）
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: models.map((m) {
                        return ListTile(
                          leading: Icon(
                            selected == m
                                ? CupertinoIcons.checkmark_circle_fill
                                : CupertinoIcons.circle,
                            size: 20,
                            color: selected == m
                                ? DesignTokens.primary
                                : (Theme.of(ctx).brightness == Brightness.dark
                                    ? const Color(0xFF6C6C6C)
                                    : const Color(0xFFBDBDBD)),
                          ),
                          title: Text(m,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: selected == m ? FontWeight.w600 : FontWeight.w500,
                                color: Theme.of(ctx).brightness == Brightness.dark
                                    ? const Color(0xFFF0F0F0)
                                    : const Color(0xFF2C2C2C),
                              )),
                          onTap: () => setState(() => selected = m),
                        );
                      }).toList(),
                    ),
                  ),
                  // 底部按钮
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(ctx).brightness == Brightness.dark
                              ? const Color(0xFF2C2C2C)
                              : const Color(0xFFE0E0E0),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            color: Theme.of(ctx).brightness == Brightness.dark
                                ? const Color(0xFF2C2C2C)
                                : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(10),
                            onPressed: () => Navigator.pop(dialogCtx),
                            child: Text('取消',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Theme.of(ctx).brightness == Brightness.dark
                                      ? const Color(0xFFF0F0F0)
                                      : const Color(0xFF2C2C2C),
                                )),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            color: DesignTokens.primary,
                            borderRadius: BorderRadius.circular(10),
                            onPressed: selected == null
                                ? null
                                : () {
                                    onSelect(selected!);
                                    Navigator.pop(dialogCtx);
                                  },
                            child: const Text('确认',
                                style: TextStyle(fontSize: 15, color: Colors.white)),
                          ),
                        ),
                      ],
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

  // ========== 本地配置 ==========
  Widget _buildLocalConfig(ImageGenSettings settings, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('💻 本地服务配置',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
            )),
        const SizedBox(height: 12),
        // [latent.moe] 专属配置:API key + 可选 Base URL;无模型名(站点 GPU 池固定)
        if (settings.provider == ImageGenProvider.latentMoe) ...[
          _buildTextField(
            label: 'Latent.moe API Key',
            value: settings.apiKey ?? '',
            hint: 'lat_sk_...',
            obscureText: true,
            isDark: isDark,
            onChanged: (v) => ref.read(imageGenSettingsProvider.notifier).setApiKey(v),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            label: 'Base URL（可选）',
            value: settings.effectiveEndpoint,
            hint: settings.provider.defaultEndpoint,
            isDark: isDark,
            onChanged: (v) => ref.read(imageGenSettingsProvider.notifier).setApiEndpoint(v),
          ),
          const SizedBox(height: 12),
          Text('异步队列生图（提交→排队→轮询→拉图），模型固定，steps 8–12，每周额度',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF8C8C8C) : const Color(0xFF8E8E93),
              )),
        ]
        else if (settings.provider == ImageGenProvider.novelai) ...[
          _buildTextField(
            label: 'NovelAI API Key',
            value: settings.apiKey ?? '',
            hint: 'nai_xxx',
            obscureText: true,
            isDark: isDark,
            onChanged: (v) => ref.read(imageGenSettingsProvider.notifier).setApiKey(v),
          ),
          const SizedBox(height: 12),
          Text('模型',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF8C8C8C) : const Color(0xFF8E8E93),
              )),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: settings.provider.defaultModels.contains(settings.model)
                  ? settings.model
                  : settings.provider.defaultModels.first,
              isExpanded: true,
              underline: const SizedBox(),
              items: settings.provider.defaultModels
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (m) {
                if (m != null) ref.read(imageGenSettingsProvider.notifier).setModel(m);
              },
            ),
          ),
        ] else ...[
          _buildTextField(
            label: 'Endpoint 地址',
            value: settings.effectiveEndpoint,
            hint: settings.provider.defaultEndpoint,
            isDark: isDark,
            onChanged: (v) => ref.read(imageGenSettingsProvider.notifier).setApiEndpoint(v),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            label: '模型名称',
            value: settings.model,
            hint: '输入模型名称',
            isDark: isDark,
            onChanged: (v) => ref.read(imageGenSettingsProvider.notifier).setModel(v.trim()),
          ),
        ],
      ],
    );
  }

  // ========== 快速参数 ==========
  Widget _buildQuickParams(ImageGenSettings settings, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('快速参数',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
            )),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildResBtn('512×512', 512, 512, settings, isDark),
            const SizedBox(width: 8),
            _buildResBtn('1024×1024', 1024, 1024, settings, isDark),
            const SizedBox(width: 8),
            _buildResBtn('2048×2048', 2048, 2048, settings, isDark),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('自定义: ', style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF8C8C8C) : const Color(0xFF8E8E93))),
            SizedBox(
              width: 70,
              child: _buildNumField(settings.defaultWidth.toString(), isDark, (v) {
                final w = int.tryParse(v);
                if (w != null && w >= 256 && w <= 2048) {
                  ref.read(imageGenSettingsProvider.notifier).setDefaultWidth(w);
                }
              }),
            ),
            const Text(' × ', style: TextStyle(fontSize: 13)),
            SizedBox(
              width: 70,
              child: _buildNumField(settings.defaultHeight.toString(), isDark, (v) {
                final h = int.tryParse(v);
                if (h != null && h >= 256 && h <= 2048) {
                  ref.read(imageGenSettingsProvider.notifier).setDefaultHeight(h);
                }
              }),
            ),
            const SizedBox(width: 8),
            Text('(${_calcRatio(settings.defaultWidth, settings.defaultHeight)})',
                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF6C6C6C) : const Color(0xFFBDBDBD))),
          ],
        ),
        const SizedBox(height: 16),
        Text('生成步数: ${settings.defaultSteps}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C))),
        Slider(
          value: settings.defaultSteps.toDouble(),
          min: 1, max: 150, divisions: 149,
          activeColor: DesignTokens.primary,
          onChanged: (v) => ref.read(imageGenSettingsProvider.notifier).setDefaultSteps(v.round()),
        ),
        Text('CFG强度: ${settings.defaultCfgScale.toStringAsFixed(1)}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C))),
        Slider(
          value: settings.defaultCfgScale,
          min: 1.0, max: 30.0, divisions: 290,
          activeColor: DesignTokens.primary,
          onChanged: (v) => ref.read(imageGenSettingsProvider.notifier).setDefaultCfgScale(v),
        ),
      ],
    );
  }

  Widget _buildResBtn(String label, int w, int h, ImageGenSettings s, bool isDark) {
    final sel = s.defaultWidth == w && s.defaultHeight == h;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          ref.read(imageGenSettingsProvider.notifier).setDefaultWidth(w);
          ref.read(imageGenSettingsProvider.notifier).setDefaultHeight(h);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel
                ? DesignTokens.primary.withValues(alpha: 0.15)
                : (isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: sel ? DesignTokens.primary : (isDark ? const Color(0xFF3C3C3C) : const Color(0xFFE0E0E0)),
              width: sel ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                color: sel ? DesignTokens.primary : (isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C)),
              )),
        ),
      ),
    );
  }

  String _calcRatio(int w, int h) {
    int gcd(int a, int b) => b == 0 ? a : gcd(b, a % b);
    final d = gcd(w, h);
    return '${w ~/ d}:${h ~/ d}';
  }

  // ========== 折叠区 ==========
  Widget _buildAutoImageSection(ImageGenSettings settings, bool isDark) {
    return _buildCollapse(
      '自动生图设置', _getAutoStatus(settings), _autoImageExpanded,
      () => setState(() => _autoImageExpanded = !_autoImageExpanded),
      Column(
        children: [
          RadioListTile<AutoImageMode>(
            contentPadding: EdgeInsets.zero, dense: true,
            title: const Text('关闭'),
            value: AutoImageMode.off,
            groupValue: settings.autoImageMode,
            onChanged: (v) { if (v != null) ref.read(imageGenSettingsProvider.notifier).setAutoImageMode(v); },
          ),
          RadioListTile<AutoImageMode>(
            contentPadding: EdgeInsets.zero, dense: true,
            title: const Text('仅写提示词'),
            subtitle: const Text('需AI输出<image>标签', style: TextStyle(fontSize: 11)),
            value: AutoImageMode.promptOnly,
            groupValue: settings.autoImageMode,
            onChanged: (v) { if (v != null) ref.read(imageGenSettingsProvider.notifier).setAutoImageMode(v); },
          ),
          RadioListTile<AutoImageMode>(
            contentPadding: EdgeInsets.zero, dense: true,
            title: const Text('全自动生成'),
            subtitle: const Text('AI未写标签时额外调用（消耗额度）', style: TextStyle(fontSize: 11)),
            value: AutoImageMode.auto,
            groupValue: settings.autoImageMode,
            onChanged: (v) { if (v != null) ref.read(imageGenSettingsProvider.notifier).setAutoImageMode(v); },
          ),
        ],
      ),
      isDark,
    );
  }

  String _getAutoStatus(ImageGenSettings s) {
    switch (s.autoImageMode) {
      case AutoImageMode.off: return '(关闭)';
      case AutoImageMode.promptOnly: return '(仅写提示词)';
      case AutoImageMode.auto: return '(全自动)';
    }
  }

  Widget _buildPromptOptSection(ImageGenSettings settings, bool isDark) {
    return _buildCollapse(
      '提示词优化',
      settings.enableAutoPromptGeneration ? '(已启用)' : '(未启用)',
      _promptOptExpanded,
      () => setState(() => _promptOptExpanded = !_promptOptExpanded),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('额外调用AI优化提示词',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
                    )),
              ),
              CupertinoSwitch(
                value: settings.enableAutoPromptGeneration,
                activeColor: DesignTokens.primary,
                onChanged: (v) => ref.read(imageGenSettingsProvider.notifier).setEnableAutoPromptGeneration(v),
              ),
            ],
          ),
          if (settings.enableAutoPromptGeneration) ...[
            const SizedBox(height: 12),
            Text('优化服务配置（独立于生图）:',
                style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF8C8C8C) : const Color(0xFF8E8E93))),
            const SizedBox(height: 8),
            _buildTextField(
              label: 'Base URL',
              value: settings.promptOptBaseUrl ?? 'https://api.openai.com/v1',
              hint: 'https://api.openai.com/v1',
              isDark: isDark,
              onChanged: (v) => ref.read(imageGenSettingsProvider.notifier).setPromptOptBaseUrl(v),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'API Key',
              value: settings.promptOptApiKey ?? '',
              hint: 'sk-...',
              obscureText: true,
              isDark: isDark,
              onChanged: (v) => ref.read(imageGenSettingsProvider.notifier).setPromptOptApiKey(v),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: DesignTokens.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                onPressed: _isFetchingPromptOptModels ? null : _fetchPromptOptModels,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isFetchingPromptOptModels)
                      const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, valueColor: AlwaysStoppedAnimation(DesignTokens.primary)))
                    else
                      const Icon(CupertinoIcons.arrow_clockwise, size: 18, color: DesignTokens.primary),
                    const SizedBox(width: 8),
                    Text(_isFetchingPromptOptModels ? '拉取中...' : '拉取可用模型',
                        style: const TextStyle(fontSize: 15, color: DesignTokens.primary)),
                  ],
                ),
              ),
            ),
            if ((settings.promptOptModel ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('当前模型: ${settings.promptOptModel}',
                  style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF8C8C8C) : const Color(0xFF8E8E93))),
            ],
            const SizedBox(height: 12),
            _buildTextField(
              label: '或手动输入模型名称',
              value: settings.promptOptModel ?? '',
              hint: 'gpt-4o',
              isDark: isDark,
              onChanged: (v) => ref.read(imageGenSettingsProvider.notifier).setPromptOptModel(v.trim()),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: '视觉标签提取指令（高级）',
              value: settings.extractionInstruction ?? '',
              hint: '(留空使用默认指令)',
              maxLines: 4,
              isDark: isDark,
              onChanged: (v) => ref
                  .read(imageGenSettingsProvider.notifier)
                  .setExtractionInstruction(v.isEmpty ? null : v),
            ),
          ],
          const SizedBox(height: 16),
          Text('提示词配置',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
              )),
          const SizedBox(height: 8),
          _buildTextField(
            label: '固定负面提示词',
            value: settings.defaultNegativePrompt ?? '',
            hint: 'lowres, bad anatomy, bad hands...',
            maxLines: 3,
            isDark: isDark,
            onChanged: (v) => ref
                .read(imageGenSettingsProvider.notifier)
                .setDefaultNegativePrompt(v.isEmpty ? null : v),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            label: '正面提示词前缀',
            value: settings.positivePromptPrefix ?? '',
            hint: 'masterpiece, best quality...',
            maxLines: 2,
            isDark: isDark,
            onChanged: (v) => ref
                .read(imageGenSettingsProvider.notifier)
                .setPositivePromptPrefix(v.isEmpty ? null : v),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            label: 'image标签提取指令',
            value: settings.imageTagInstruction ?? '',
            hint: '(留空使用默认指令)',
            maxLines: 3,
            isDark: isDark,
            onChanged: (v) => ref
                .read(imageGenSettingsProvider.notifier)
                .setImageTagInstruction(v.isEmpty ? null : v),
          ),
        ],
      ),
      isDark,
    );
  }

  Future<void> _fetchPromptOptModels() async {
    final settings = ref.read(imageGenSettingsProvider);
    final baseUrl = settings.promptOptBaseUrl ?? 'https://api.openai.com/v1';
    final apiKey = settings.promptOptApiKey;
    if (apiKey == null || apiKey.isEmpty) {
      _showSnackBar('请先填写 Base URL 和 API Key');
      return;
    }
    setState(() => _isFetchingPromptOptModels = true);
    try {
      final tempConfig = LLMConfig(
        provider: LLMProvider.openAICompatible,
        apiKey: apiKey,
        apiUrl: baseUrl,
        model: settings.promptOptModel ?? '',
      );
      final models =
          await ref.read(llmServiceProvider).getAvailableModels(tempConfig);
      if (!mounted) return;
      setState(() => _isFetchingPromptOptModels = false);
      if (models.isNotEmpty) {
        _showModelSelectDialog(models, settings.promptOptModel,
            (m) => ref.read(imageGenSettingsProvider.notifier).setPromptOptModel(m));
      } else {
        _showSnackBar('未拉取到模型，请检查地址和密钥');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isFetchingPromptOptModels = false);
      _showSnackBar('拉取失败: $e');
    }
  }

  Widget _buildAdvancedSection(ImageGenSettings settings, bool isDark) {
    final samplers = ImageGenSampler.forProvider(settings.provider);
    return _buildCollapse(
      '高级参数', '', _advancedExpanded,
      () => setState(() => _advancedExpanded = !_advancedExpanded),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (samplers.isNotEmpty) ...[
            Text('采样器:',
                style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF8C8C8C) : const Color(0xFF8E8E93))),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: samplers.any((s) => s.id == settings.defaultSampler) ? settings.defaultSampler : null,
                isExpanded: true,
                underline: const SizedBox(),
                items: samplers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                onChanged: (v) { if (v != null) ref.read(imageGenSettingsProvider.notifier).setDefaultSampler(v); },
              ),
            ),
          ],
          if (settings.provider == ImageGenProvider.novelai) ...[
            const SizedBox(height: 16),
            Text('── NovelAI 专属 ──',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF8C8C8C) : const Color(0xFF8E8E93),
                )),
            const SizedBox(height: 8),
            _buildSwitch('Anlas守护', '余额不足时拒绝生成', settings.novelaiAnlasGuard,
                (v) => ref.read(imageGenSettingsProvider.notifier).setNovelaiAnlasGuard(v), isDark),
            _buildSwitch('SMEA', '', settings.novelaiSm, (v) {
              ref.read(imageGenSettingsProvider.notifier).setNovelaiSm(v);
              if (!v) ref.read(imageGenSettingsProvider.notifier).setNovelaiSmDyn(false);
            }, isDark),
            if (settings.novelaiSm)
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: _buildSwitch('SM DYN', '需先启用SMEA', settings.novelaiSmDyn,
                    (v) => ref.read(imageGenSettingsProvider.notifier).setNovelaiSmDyn(v), isDark),
              ),
            _buildSwitch('Decrisper', '', settings.novelaiDecrisper,
                (v) => ref.read(imageGenSettingsProvider.notifier).setNovelaiDecrisper(v), isDark),
            _buildSwitch('Variety+', '', settings.novelaiVarietyBoost,
                (v) => ref.read(imageGenSettingsProvider.notifier).setNovelaiVarietyBoost(v), isDark),
          ],
          if (settings.provider == ImageGenProvider.openai && settings.model.contains('dall-e-3')) ...[
            const SizedBox(height: 16),
            Text('── DALL-E 3 专属 ──',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF8C8C8C) : const Color(0xFF8E8E93),
                )),
            const SizedBox(height: 8),
            Text('风格:', style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF8C8C8C) : const Color(0xFF8E8E93))),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _buildRadioBtn('Vivid', settings.openaiStyle == 'vivid',
                    () => ref.read(imageGenSettingsProvider.notifier).setOpenaiStyle('vivid'), isDark)),
                const SizedBox(width: 8),
                Expanded(child: _buildRadioBtn('Natural', settings.openaiStyle == 'natural',
                    () => ref.read(imageGenSettingsProvider.notifier).setOpenaiStyle('natural'), isDark)),
              ],
            ),
            const SizedBox(height: 12),
            Text('质量:', style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF8C8C8C) : const Color(0xFF8E8E93))),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _buildRadioBtn('Standard', settings.openaiQuality == 'standard',
                    () => ref.read(imageGenSettingsProvider.notifier).setOpenaiQuality('standard'), isDark)),
                const SizedBox(width: 8),
                Expanded(child: _buildRadioBtn('HD', settings.openaiQuality == 'hd',
                    () => ref.read(imageGenSettingsProvider.notifier).setOpenaiQuality('hd'), isDark)),
              ],
            ),
          ],
        ],
      ),
      isDark,
    );
  }

  Widget _buildCollapse(String title, String sub, bool exp, VoidCallback toggle, Widget child, bool isDark) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: toggle,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    exp ? CupertinoIcons.chevron_down : CupertinoIcons.chevron_right,
                    size: 16,
                    color: isDark ? const Color(0xFF8C8C8C) : const Color(0xFF8E8E93),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
                        )),
                  ),
                  if (sub.isNotEmpty)
                    Text(sub,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF6C6C6C) : const Color(0xFFBDBDBD),
                        )),
                ],
              ),
            ),
          ),
        ),
        if (exp) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF3C3C3C) : const Color(0xFFE0E0E0),
                width: 0.5,
              ),
            ),
            child: child,
          ),
        ],
      ],
    );
  }

  // ===== 工具组件 =====
  Widget _buildTextField({
    required String label,
    required String value,
    required String hint,
    required bool isDark,
    required ValueChanged<String> onChanged,
    bool obscureText = false,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFF8C8C8C) : const Color(0xFF8E8E93),
            )),
        const SizedBox(height: 6),
        CupertinoTextField(
          controller: TextEditingController(text: value)
            ..selection = TextSelection.collapsed(offset: value.length),
          placeholder: hint,
          obscureText: obscureText,
          maxLines: maxLines,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
          ),
          style: TextStyle(
            fontSize: 14,
            color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildNumField(String value, bool isDark, ValueChanged<String> onChanged) {
    return CupertinoTextField(
      controller: TextEditingController(text: value),
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(6),
      ),
      style: TextStyle(
        fontSize: 13,
        color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildSwitch(String title, String subtitle, bool value, ValueChanged<bool> onChanged, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
                    )),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF6C6C6C) : const Color(0xFFBDBDBD),
                      )),
                ],
              ],
            ),
          ),
          CupertinoSwitch(value: value, activeColor: DesignTokens.primary, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildRadioBtn(String label, bool isSelected, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? DesignTokens.primary.withValues(alpha: 0.15)
              : (isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? DesignTokens.primary : Colors.transparent,
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected
                  ? DesignTokens.primary
                  : (isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C)),
            )),
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
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
      child: SizedBox(
        width: double.infinity,
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(vertical: 12),
          color: DesignTokens.primary,
          borderRadius: BorderRadius.circular(10),
          onPressed: () => Navigator.pop(context),
          child: const Text('完成', style: TextStyle(fontSize: 15, color: Colors.white)),
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}
