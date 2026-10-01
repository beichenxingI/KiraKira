import 'dart:typed_data';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/domain/services/image_generation_service.dart';
import 'package:kirakira/domain/services/llm_service.dart';
import 'package:kirakira/presentation/providers/image_gen_providers.dart';
import 'package:kirakira/presentation/providers/llm_configs_provider.dart';
import 'package:kirakira/presentation/providers/settings_providers.dart';
import 'package:kirakira/presentation/theme/app_theme.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/widgets/common/kira_components.dart';

/// Screen for image generation settings
class ImageGenSettingsScreen extends ConsumerWidget {
  const ImageGenSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(imageGenSettingsProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(
              AppLocalizations.of(context).imageGeneration,
              style: Theme.of(context).textTheme.displayLarge,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.restore),
                tooltip: AppLocalizations.of(context).resetToDefaults,
                onPressed: () {
                  ref.read(imageGenSettingsProvider.notifier).reset();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context).settingsResetToDefaults)),
                  );
                },
              ),
            ],
          ),
          SliverList(
            delegate: SliverChildListDelegate([
          // Enable/Disable toggle
          _buildSection(
            context: context,
            title: AppLocalizations.of(context).general,
            children: [
              KiraSwitchTile(
                  title: AppLocalizations.of(context).enableImageGeneration,
                  subtitle: AppLocalizations.of(context).generateImagesUsingAi,
                  value: settings.enabled,
                onChanged: (value) {
                  ref.read(imageGenSettingsProvider.notifier).setEnabled(value);
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Auto image generation: three-way mode selector
          _buildSection(
            context: context,
            title: '自动生图',
            children: [
              RadioListTile<AutoImageMode>(
                title: const Text('关闭'),
                subtitle: const Text('AI 回复不自动配图，仅可手动生成'),
                value: AutoImageMode.off,
                groupValue: settings.autoImageMode,
                onChanged: settings.enabled
                    ? (v) {
                        if (v != null) {
                          ref
                              .read(imageGenSettingsProvider.notifier)
                              .setAutoImageMode(v);
                        }
                      }
                    : null,
              ),
              RadioListTile<AutoImageMode>(
                title: const Text('仅写提示词'),
                subtitle: const Text('让 AI 输出画面描述，但不自动出图'),
                value: AutoImageMode.promptOnly,
                groupValue: settings.autoImageMode,
                onChanged: settings.enabled
                    ? (v) {
                        if (v != null) {
                          ref
                              .read(imageGenSettingsProvider.notifier)
                              .setAutoImageMode(v);
                        }
                      }
                    : null,
              ),
              RadioListTile<AutoImageMode>(
                title: const Text('全自动生成'),
                subtitle: const Text(
                  'AI 描述画面后自动生成图片，存入会话相册。\n'
                  '⚠ 当 AI 未输出画面标签时，会额外调用一次 AI 提炼画面描述，'
                  '产生额外的额度消耗。',
                ),
                value: AutoImageMode.auto,
                groupValue: settings.autoImageMode,
                onChanged: settings.enabled
                    ? (v) {
                        if (v != null) {
                          ref
                              .read(imageGenSettingsProvider.notifier)
                              .setAutoImageMode(v);
                        }
                      }
                    : null,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Prompt configuration: three fields combined (negative prompt + positive prefix + image tag instruction)
          _buildSection(
            context: context,
            title: '提示词配置',
            children: [
              Padding(
                padding: const EdgeInsets.all(DesignTokens.spaceMd),
                child: TextField(
                  controller: TextEditingController(text: settings.defaultNegativePrompt),
                  decoration: const InputDecoration(
                    labelText: '固定负面提示词',
                    hintText: 'low quality, blurry, bad anatomy, watermark',
                    helperText: '每次生图都自动带上,用来排除不想要的元素',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  enabled: settings.enabled,
                  onChanged: (value) {
                    ref.read(imageGenSettingsProvider.notifier).setDefaultNegativePrompt(value);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(DesignTokens.spaceMd),
                child: TextField(
                  controller: TextEditingController(text: settings.positivePromptPrefix),
                  decoration: const InputDecoration(
                    labelText: '正面提示词前缀',
                    hintText: 'masterpiece, best quality, ',
                    helperText: 'AI 生成的提示词前面会自动加上这段,用来固定画风',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  enabled: settings.enabled,
                  onChanged: (value) {
                    ref.read(imageGenSettingsProvider.notifier).setPositivePromptPrefix(value);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(DesignTokens.spaceMd),
                child: TextField(
                  controller: TextEditingController(text: settings.imageTagInstruction),
                  decoration: const InputDecoration(
                    labelText: '告诉 AI 怎么写生图标签',
                    hintText: '留空使用默认指令',
                    helperText: '加到 AI 系统提示词里,告诉它什么情况下输出 <image> 标签、标签里写什么',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 5,
                  enabled: settings.enabled,
                  onChanged: (value) {
                    ref.read(imageGenSettingsProvider.notifier).setImageTagInstruction(value);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Fully automatic generation: optional extra AI prompt optimization + model selection (reuses API service config)
          _buildSection(
            context: context,
            title: '全自动生图提示词优化',
            children: [
              KiraSwitchTile(
                title: '额外调用 AI 优化提示词',
                subtitle: 'AI 没写 <image> 标签时,额外调一次 AI 从对话提炼画面描述(更准但多一次 API 调用)',
                value: settings.enableAutoPromptGeneration,
                onChanged: settings.enabled
                    ? (value) {
                        ref.read(imageGenSettingsProvider.notifier).setEnableAutoPromptGeneration(value);
                      }
                    : null,
              ),
              if (settings.enableAutoPromptGeneration && settings.enabled)
                _buildAutoPromptConfigSelector(context, ref, settings),
            ],
          ),

          const SizedBox(height: 16),

          // Cloud image generation — cards select an API service (read from llmConfigsProvider, no manual entry)
          _buildSection(
            context: context,
            title: '☁️ 云端生图',
            children: [
              ..._buildCloudApiCards(context, ref, settings),
              // Model selection (after a card is chosen, fetch that service's image models)
              _buildModelSelector(context, ref, settings),
            ],
          ),

          const SizedBox(height: 16),

          // Local/other image generation — NovelAI, A1111, ComfyUI, LocalDream
          _buildSection(
            context: context,
            title: '💻 本地 / 其他',
            children: [
              ListTile(
                title: const Text('提供商'),
                subtitle: Text(settings.provider.displayName),
                trailing: DropdownButton<ImageGenProvider>(
                  // After a cloud card is selected, provider=openai/gemini is not in this dropdown;
                  // value must be present in items or null, otherwise the assert crashes
                  value: [
                    ImageGenProvider.novelai,
                    ImageGenProvider.latentMoe,
                    ImageGenProvider.automatic1111,
                    ImageGenProvider.comfyui,
                    ImageGenProvider.localDream,
                  ].contains(settings.provider)
                      ? settings.provider
                      : null,
                  hint: const Text('选择本地/其他提供商'),
                  onChanged: settings.enabled
                      ? (value) {
                          if (value != null) {
                            ref.read(imageGenSettingsProvider.notifier).setProvider(value);
                          }
                        }
                      : null,
                  // Only non-cloud providers are listed (openai/gemini use the cards)
                  items: [
                    ImageGenProvider.novelai,
                    ImageGenProvider.latentMoe,
                    ImageGenProvider.automatic1111,
                    ImageGenProvider.comfyui,
                    ImageGenProvider.localDream,
                  ].map((provider) {
                    return DropdownMenuItem(
                      value: provider,
                      child: provider == ImageGenProvider.comfyui
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(provider.displayName),
                                Text('（仅支持 SD1.5/SDXL）',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context).hintColor)),
                              ],
                            )
                          : Text(provider.displayName),
                    );
                  }).toList(),
                ),
              ),
              // Local/other providers require a manually configured endpoint
              if (settings.provider == ImageGenProvider.novelai ||
                  settings.provider == ImageGenProvider.latentMoe ||
                  settings.provider == ImageGenProvider.automatic1111 ||
                  settings.provider == ImageGenProvider.comfyui ||
                  settings.provider == ImageGenProvider.localDream)
                ListTile(
                  title: Text(settings.provider.requiresApiKey
                      ? AppLocalizations.of(context).apiKey
                      : AppLocalizations.of(context).apiEndpoint),
                  subtitle: Text(
                    settings.provider.requiresApiKey
                        ? (settings.apiKey?.isNotEmpty == true
                            ? '••••${settings.apiKey!.substring(settings.apiKey!.length - 4)}'
                            : AppLocalizations.of(context).notConfigured)
                        : (settings.apiEndpoint?.isNotEmpty == true
                            ? settings.apiEndpoint!
                            : settings.provider.defaultEndpoint),
                  ),
                  trailing: const Icon(Icons.edit),
                  onTap: settings.enabled
                      ? () {
                          if (settings.provider.requiresApiKey) {
                            _showApiKeyDialog(context, ref, settings);
                          } else {
                            _showEndpointDialog(context, ref, settings);
                          }
                        }
                      : null,
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Default parameters
          _buildSection(
            context: context,
            title: AppLocalizations.of(context).defaultParameters,
            children: [
              // Resolution: quick buttons + custom input
              Padding(
                padding: const EdgeInsets.all(DesignTokens.spaceMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('图像分辨率', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    // Quick selection
                    Row(
                      children: [
                        _buildResQuickBtn(context, ref, settings, '512×512', 512, 512),
                        const SizedBox(width: 8),
                        _buildResQuickBtn(context, ref, settings, '768×768', 768, 768),
                        const SizedBox(width: 8),
                        _buildResQuickBtn(context, ref, settings, '1024×1024', 1024, 1024),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Custom width/height
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: TextEditingController(text: settings.defaultWidth.toString()),
                            decoration: const InputDecoration(
                              labelText: '宽度',
                              suffixText: 'px',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            enabled: settings.enabled,
                            onChanged: (value) {
                              final w = int.tryParse(value);
                              if (w != null && w >= 256 && w <= 2048) {
                                ref.read(imageGenSettingsProvider.notifier).setDefaultWidth(w);
                              }
                            },
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(Icons.close, size: 16, color: Colors.grey),
                        ),
                        Expanded(
                          child: TextField(
                            controller: TextEditingController(text: settings.defaultHeight.toString()),
                            decoration: const InputDecoration(
                              labelText: '高度',
                              suffixText: 'px',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            enabled: settings.enabled,
                            onChanged: (value) {
                              final h = int.tryParse(value);
                              if (h != null && h >= 256 && h <= 2048) {
                                ref.read(imageGenSettingsProvider.notifier).setDefaultHeight(h);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Current aspect ratio
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.aspect_ratio, size: 14, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            '${settings.defaultWidth} × ${settings.defaultHeight} (${_aspectRatio(settings.defaultWidth, settings.defaultHeight)})',
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Steps slider
              ListTile(
                title: Text(AppLocalizations.of(context).steps),
                subtitle: Slider(
                  value: settings.defaultSteps.toDouble(),
                  min: 1,
                  max: 150,
                  divisions: 149,
                  label: '${settings.defaultSteps}',
                  onChanged: settings.enabled
                      ? (value) {
                          ref.read(imageGenSettingsProvider.notifier).setDefaultSteps(value.round());
                        }
                      : null,
                ),
                trailing: Text(
                  '${settings.defaultSteps}',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),

              // CFG Scale slider
              ListTile(
                title: Text(AppLocalizations.of(context).cfgScale),
                subtitle: Slider(
                  value: settings.defaultCfgScale,
                  min: 1.0,
                  max: 30.0,
                  divisions: 58,
                  label: settings.defaultCfgScale.toStringAsFixed(1),
                  onChanged: settings.enabled
                      ? (value) {
                          ref.read(imageGenSettingsProvider.notifier).setDefaultCfgScale(value);
                        }
                      : null,
                ),
                trailing: Text(
                  settings.defaultCfgScale.toStringAsFixed(1),
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),

              // Sampler dropdown
              ListTile(
                title: Text(AppLocalizations.of(context).sampler),
                subtitle: Text(
                  ImageGenSampler.samplers
                      .firstWhere(
                        (s) => s.id == settings.defaultSampler,
                        orElse: () => ImageGenSampler.samplers.first,
                      )
                      .name,
                ),
                trailing: DropdownButton<String>(
                  value: settings.defaultSampler,
                  onChanged: settings.enabled
                      ? (value) {
                          if (value != null) {
                            ref.read(imageGenSettingsProvider.notifier).setDefaultSampler(value);
                          }
                        }
                      : null,
                  items: ImageGenSampler.samplers.map((sampler) {
                    return DropdownMenuItem(
                      value: sampler.id,
                      child: Text(sampler.name),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // NovelAI specific settings
          if (settings.provider == ImageGenProvider.novelai) ...[
            const SizedBox(height: 16),
            _buildSection(
              context: context,
              title: 'NovelAI 设置',
              children: [
                KiraSwitchTile(
                    title: 'Anlas 保护',
                    subtitle: '限制图片尺寸和步数以降低成本',
                    value: settings.novelaiAnlasGuard,
                  onChanged: settings.enabled
                      ? (value) {
                          ref.read(imageGenSettingsProvider.notifier).setNovelaiAnlasGuard(value);
                        }
                      : null,
                ),
                KiraSwitchTile(
                    title: 'SM (SMEA)',
                    subtitle: '增强采样以获得更好细节',
                    value: settings.novelaiSm,
                  onChanged: settings.enabled
                      ? (value) {
                          ref.read(imageGenSettingsProvider.notifier).setNovelaiSm(value);
                        }
                      : null,
                ),
                if (settings.novelaiSm)
                  KiraSwitchTile(
                      title: 'SM DYN',
                      subtitle: '动态 SMEA（更富创意）',
                      value: settings.novelaiSmDyn,
                    onChanged: settings.enabled
                        ? (value) {
                            ref.read(imageGenSettingsProvider.notifier).setNovelaiSmDyn(value);
                          }
                        : null,
                  ),
                KiraSwitchTile(
                    title: 'Decrisper',
                    subtitle: '减少图片过度饱和',
                    value: settings.novelaiDecrisper,
                  onChanged: settings.enabled
                      ? (value) {
                          ref.read(imageGenSettingsProvider.notifier).setNovelaiDecrisper(value);
                        }
                      : null,
                ),
                KiraSwitchTile(
                    title: 'Variety+',
                    subtitle: '生成图片的更高多样性',
                    value: settings.novelaiVarietyBoost,
                  onChanged: settings.enabled
                      ? (value) {
                          ref.read(imageGenSettingsProvider.notifier).setNovelaiVarietyBoost(value);
                        }
                      : null,
                ),
              ],
            ),
          ],

          // Latent.moe-specific info (async queued generation, no NovelAI-specific parameters)
          if (settings.provider == ImageGenProvider.latentMoe) ...[
            const SizedBox(height: 16),
            _buildSection(
              context: context,
              title: 'Latent.moe 说明',
              children: [
                const Padding(
                  padding: EdgeInsets.all(DesignTokens.spaceMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• 异步队列生图：提交 → 排队 → 轮询 → 拉取图片（可能需等待数分钟）',
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      SizedBox(height: 6),
                      Text('• 模型由站点 GPU 池决定，无法选择',
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      SizedBox(height: 6),
                      Text('• steps 限制 8–12，分辨率仅三档（方/竖/横），会自动映射',
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      SizedBox(height: 6),
                      Text('• 每周生图额度 + 并发任务上限；429/409 报错即额度或并发用尽',
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ],

          // OpenAI specific settings
          if (settings.provider == ImageGenProvider.openai && settings.model.contains('dall-e-3')) ...[
            const SizedBox(height: 16),
            _buildSection(
              context: context,
              title: 'DALL-E 3 设置',
              children: [
                ListTile(
                  title: const Text('风格'),
                  subtitle: Text(settings.openaiStyle == 'vivid' 
                      ? 'Vivid - Hyper-real and dramatic' 
                      : 'Natural - More natural, less hyper-real'),
                  trailing: DropdownButton<String>(
                    value: settings.openaiStyle,
                    onChanged: settings.enabled
                        ? (value) {
                            if (value != null) {
                              ref.read(imageGenSettingsProvider.notifier).setOpenaiStyle(value);
                            }
                          }
                        : null,
                    items: const [
                      DropdownMenuItem(value: 'vivid', child: Text('鲜明')),
                      DropdownMenuItem(value: 'natural', child: Text('自然')),
                    ],
                  ),
                ),
                ListTile(
                  title: const Text('质量'),
                  subtitle: Text(settings.openaiQuality == 'hd' 
                      ? 'HD - Higher detail and consistency' 
                      : 'Standard - Faster, lower cost'),
                  trailing: DropdownButton<String>(
                    value: settings.openaiQuality,
                    onChanged: settings.enabled
                        ? (value) {
                            if (value != null) {
                              ref.read(imageGenSettingsProvider.notifier).setOpenaiQuality(value);
                            }
                          }
                        : null,
                    items: const [
                      DropdownMenuItem(value: 'standard', child: Text('标准')),
                      DropdownMenuItem(value: 'hd', child: Text('高清')),
                    ],
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Test section
          _buildSection(
            context: context,
            title: AppLocalizations.of(context).test,
            children: [
              _ImageGenTestWidget(enabled: settings.enabled),
            ],
          ),

          const SizedBox(height: 16),

          // Info section
          _buildSection(
            context: context,
            title: AppLocalizations.of(context).information,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline, color: AppTheme.accentColor),
                title: Text(AppLocalizations.of(context).aboutImageGeneration),
                subtitle: Text(AppLocalizations.of(context).aboutImageGenerationDescription),
              ),
              ListTile(
                leading: const Icon(Icons.terminal, color: AppTheme.textMuted),
                title: Text(AppLocalizations.of(context).imagineCommand),
                subtitle: Text(AppLocalizations.of(context).imagineCommandUsage),
              ),
              if (settings.provider == ImageGenProvider.automatic1111)
                ListTile(
                  leading: const Icon(Icons.computer, color: AppTheme.textMuted),
                  title: Text(AppLocalizations.of(context).stableDiffusion),
                  subtitle: Text(AppLocalizations.of(context).stableDiffusionDescription),
                ),
              if (settings.provider == ImageGenProvider.openai)
                ListTile(
                  leading: const Icon(Icons.cloud, color: AppTheme.textMuted),
                  title: Text(AppLocalizations.of(context).dalle),
                  subtitle: Text(AppLocalizations.of(context).dalleDescription),
                ),
              if (settings.provider == ImageGenProvider.openaiChat)
                const ListTile(
                  leading: Icon(Icons.chat, color: AppTheme.textMuted),
                  title: Text('OpenAI-Chat'),
                  subtitle: Text('使用 chat/completions API 生成图像。适用于通过聊天格式返回图像的兼容 API。'),
                ),
            ],
          ),
        ]),
          ),
          // Root-pushed subpage with no capsule tab bar; keep the breathing space
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required List<Widget> children,
  }) {
    // Inset-grouped: one card per section
    return KiraSection(title: title, children: children);
  }

  // Cloud image generation: API service cards

  List<Widget> _buildCloudApiCards(
      BuildContext context, WidgetRef ref, ImageGenSettings settings) {
    final configs = ref.watch(llmConfigsProvider).configs;
    final theme = Theme.of(context);

    // Show all API configs (proxies/OpenAI/Gemini etc. are OpenAI-compatible endpoints that can all call /images/generations)
    if (configs.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.cloud_off, size: 36, color: Colors.grey),
              const SizedBox(height: 8),
              const Text('还没有配置 API 服务'),
              const SizedBox(height: 4),
              Text('请在顶栏点击模型名 → 添加 API 配置',
                  style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
            ],
          ),
        ),
      ];
    }

    return configs.map((config) {
      final isSelected = settings.apiKey == config.apiKey &&
          settings.effectiveEndpoint == config.endpoint;
      final icon = _getServiceIcon(config.provider);
      final color = _getServiceColor(config.provider);

      return GestureDetector(
        onTap: settings.enabled
            ? () {
                final imgProvider = _mapConfigToImageProvider(config.provider);
                if (imgProvider != null) {
                  ref.read(imageGenSettingsProvider.notifier).setProvider(imgProvider);
                }
                ref
                    .read(imageGenSettingsProvider.notifier)
                    .setApiKey(config.apiKey);
                ref
                    .read(imageGenSettingsProvider.notifier)
                    .setApiEndpoint(config.endpoint);
                if (config.model != null && config.model!.isNotEmpty) {
                  ref
                      .read(imageGenSettingsProvider.notifier)
                      .setModel(config.model!);
                }
                // Fetch models via modelFetchProvider (same fetcher as the API service, no hardcoded fallback)
                // Must override the provider enum; otherwise the active chat's provider is used, and
                //   when the active chat is Claude the claude branch returns a hardcoded list
                //   without ever hitting the proxy
                final activeConfig = ref.read(llmConfigProvider);
                final llmProvider = LLMProvider.values.firstWhere(
                  (p) => p.name == config.provider,
                  orElse: () => LLMProvider.openAICompatible,
                );
                ref.read(modelFetchProvider.notifier).fetchModels(
                  activeConfig.copyWith(
                    provider: llmProvider,
                    apiKey: config.apiKey ?? activeConfig.apiKey,
                    apiUrl: config.endpoint,
                    model: config.model ?? activeConfig.model,
                  ),
                );
              }
            : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
              width: isSelected ? 2 : 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: Text(icon, style: const TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(config.name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(config.model ?? '未设置模型',
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodySmall?.color)),
                    const SizedBox(height: 1),
                    Text(config.endpoint,
                        style: TextStyle(
                            fontSize: 10,
                            color: theme.textTheme.bodySmall?.color),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle,
                    color: theme.colorScheme.primary, size: 22),
            ],
          ),
        ),
      );
    }).toList();
  }

  String _getServiceIcon(String provider) {
    switch (provider.toLowerCase()) {
      case 'openai':
        return '⚡';
      case 'claude':
      case 'anthropic':
        return '🤖';
      case 'gemini':
      case 'google':
        return '💎';
      case 'deepseek':
        return '🐳';
      case 'qwen':
        return '🔮';
      default:
        return '🌐';
    }
  }

  Color _getServiceColor(String provider) {
    switch (provider.toLowerCase()) {
      case 'openai':
        return const Color(0xFF10A37F);
      case 'claude':
      case 'anthropic':
        return const Color(0xFFD97757);
      case 'gemini':
      case 'google':
        return const Color(0xFF4285F4);
      case 'deepseek':
        return const Color(0xFF4D6BFE);
      case 'qwen':
        return const Color(0xFF615CED);
      default:
        return Colors.blue;
    }
  }

  ImageGenProvider? _mapConfigToImageProvider(String provider) {
    // Proxy/OpenAI-compatible/OpenRouter use the OpenAI image API (/images/generations)
    // Gemini uses the Gemini image API
    // Others (claude/deepseek/qwen/ollama, etc.) also default to OpenAI-compatible (most common for proxies)
    switch (provider.toLowerCase()) {
      case 'gemini':
      case 'google':
        return ImageGenProvider.gemini;
      default:
        return ImageGenProvider.openai; // openai/openAICompatible/openRouter/others map to OpenAI-compatible
    }
  }

  // Resolution quick-select buttons

  Widget _buildResQuickBtn(
      BuildContext context, WidgetRef ref, ImageGenSettings settings,
      String label, int w, int h) {
    final isSelected =
        settings.defaultWidth == w && settings.defaultHeight == h;
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: settings.enabled
            ? () {
                ref.read(imageGenSettingsProvider.notifier).setDefaultWidth(w);
                ref.read(imageGenSettingsProvider.notifier).setDefaultHeight(h);
              }
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.15)
                : theme.cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
              width: isSelected ? 2 : 0.5,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? theme.colorScheme.primary : null,
            ),
          ),
        ),
      ),
    );
  }

  String _aspectRatio(int w, int h) {
    int gcd(int a, int b) {
      while (b != 0) { final t = b; b = a % b; a = t; }
      return a;
    }
    final d = gcd(w, h);
    return '${w ~/ d}:${h ~/ d}';
  }

  /// Select which API config (from llmConfigsProvider) is used to call the LLM for prompt extraction
  Widget _buildAutoPromptConfigSelector(
      BuildContext context, WidgetRef ref, ImageGenSettings settings) {
    final configsState = ref.watch(llmConfigsProvider);
    final configs = configsState.configs;

    return Column(
      children: [
        ListTile(
          title: const Text('提示词生成用的 API 服务'),
          subtitle: Text(
            settings.autoPromptConfigId != null
                ? (configs
                        .where((c) => c.id == settings.autoPromptConfigId)
                        .firstOrNull?.name ??
                    '已删除的配置')
                : '使用当前活跃配置',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            if (configs.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请先在 API 服务中添加配置')),
              );
              return;
            }
            // Write the selection back to autoPromptConfigId; null = use the active config
            showModalBottomSheet<String>(
              context: context,
              builder: (sheetCtx) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text('使用当前活跃配置'),
                      trailing: settings.autoPromptConfigId == null
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => Navigator.pop(sheetCtx, ''),
                    ),
                    const Divider(height: 1),
                    ...configs.map((c) => ListTile(
                          title: Text(c.name),
                          subtitle: Text(c.model ?? '未设置模型'),
                          trailing: settings.autoPromptConfigId == c.id
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () => Navigator.pop(sheetCtx, c.id),
                        )),
                  ],
                ),
              ),
            ).then((selectedId) {
              if (selectedId != null) {
                ref.read(imageGenSettingsProvider.notifier).setAutoPromptConfigId(
                    selectedId.isEmpty ? null : selectedId);
              }
            });
          },
        ),
        // Extraction instruction (advanced): only takes effect when the extra AI call is enabled
        Padding(
          padding: const EdgeInsets.all(DesignTokens.spaceMd),
          child: TextField(
            controller: TextEditingController(text: settings.extractionInstruction),
            decoration: const InputDecoration(
              labelText: '视觉标签提取指令（高级）',
              hintText: '留空使用默认。这段 system 指令给 AI,让它从对话正文提炼英文视觉标签',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 4,
            onChanged: (value) {
              ref.read(imageGenSettingsProvider.notifier).setExtractionInstruction(value);
            },
          ),
        ),
      ],
    );
  }

  /// Improved model detection: broader keywords + exclusion of chat/multimodal models
  bool _isImageModel(String modelId) {
    final lower = modelId.toLowerCase();
    // Image-model keywords (broad coverage)
    final imageKeywords = [
      'dall-e', 'dalle', 'gpt-image',
      'stable-diffusion', 'sdxl', 'sd3', 'sd1', 'sd2',
      'flux', 'midjourney', 'mj-',
      'imagen', 'firefly', 'kolors', 'playground', 'pixart', 'cogview',
    ];
    final hasImageKeyword = imageKeywords.any((kw) => lower.contains(kw));
    // Exclude multimodal chat models (IDs with these suffixes/prefixes are usually not image models)
    final isVisionChat = lower.contains('-vision') || lower.contains('-vl') ||
        lower.contains('gpt-4o') ||
        (lower.contains('qwen-') && lower.contains('image'));
    return hasImageKeyword && !isVisionChat;
  }

  Widget _buildModelSelector(BuildContext context, WidgetRef ref, ImageGenSettings settings) {
    final fetchState = ref.watch(modelFetchProvider);
    final currentModel = settings.model.isNotEmpty ? settings.model : '';

    // Filter with _isImageModel (broadened keywords + exclusions)
    final imageModels = fetchState.models.where(_isImageModel).toSet().toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title + refresh button
        Row(
          children: [
            Text(AppLocalizations.of(context).model,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const Spacer(),
            IconButton(
              icon: fetchState.status == ModelFetchStatus.loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh, size: 20),
              tooltip: '刷新模型列表',
              onPressed: settings.enabled && fetchState.status != ModelFetchStatus.loading
                  ? () {
                      final activeConfig = ref.read(llmConfigProvider);
                      // Refresh must also override the provider
                      final llmProvider = LLMProvider.values.firstWhere(
                        (p) => p.name == settings.provider.id,
                        orElse: () => LLMProvider.openAICompatible,
                      );
                      ref.read(modelFetchProvider.notifier).fetchModels(
                        activeConfig.copyWith(
                          provider: llmProvider,
                          apiKey: settings.apiKey ?? activeConfig.apiKey,
                          apiUrl: settings.effectiveEndpoint,
                          model: settings.model,
                        ),
                      );
                    }
                  : null,
            ),
          ],
        ),

        // Loading
        if (fetchState.status == ModelFetchStatus.loading)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
          ),

        // Image models found: show dropdown (real API response, no hardcoding)
        if (fetchState.status != ModelFetchStatus.loading && imageModels.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text('从 API 拉取到 ${imageModels.length} 个生图模型',
                style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
          ),
          DropdownButtonFormField<String>(
            value: imageModels.contains(currentModel) ? currentModel : null,
            hint: Text(currentModel.isNotEmpty ? currentModel : '选择模型'),
            decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.palette)),
            onChanged: settings.enabled
                ? (value) { if (value != null) ref.read(imageGenSettingsProvider.notifier).setModel(value); }
                : null,
            items: imageModels.map((model) {
              return DropdownMenuItem(value: model, child: Text(model, overflow: TextOverflow.ellipsis));
            }).toList(),
          ),
          const SizedBox(height: 16),
          // "Or" divider
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('或者', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Hint when no image models matched (fetch succeeded but nothing matched)
        if (fetchState.status == ModelFetchStatus.success &&
            imageModels.isEmpty && fetchState.models.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text('该 API 返回了 ${fetchState.models.length} 个模型,但未识别出生图模型',
                style: const TextStyle(color: DesignTokens.statusWarning, fontSize: 12)),
          ),
        ],

        // Fetch failure hint
        if (fetchState.status == ModelFetchStatus.error && fetchState.errorMessage != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text('模型列表拉取失败: ${fetchState.errorMessage}',
                style: const TextStyle(color: DesignTokens.statusWarning, fontSize: 12)),
          ),
        ],

        // Custom model input — always available regardless of fetch results
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: TextField(
            controller: TextEditingController(text: currentModel),
            decoration: const InputDecoration(
              labelText: '模型名称(可手动输入)',
              hintText: 'dall-e-3, flux-1-schnell, sd3-medium...',
              helperText: '中转站/OpenAI 兼容接口直接输入模型名即可',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.edit),
            ),
            enabled: settings.enabled,
            onChanged: (value) {
              ref.read(imageGenSettingsProvider.notifier).setModel(value.trim());
            },
          ),
        ),

        const SizedBox(height: 12),

        // Common image models quick selection
        const Text('常用模型', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8, runSpacing: 4,
          children: [
            'dall-e-3', 'dall-e-2', 'gpt-image-1',
            'flux-1-schnell', 'stable-diffusion-xl', 'sd3-medium',
          ].map((id) {
            return FilterChip(
              label: Text(id),
              selected: currentModel == id,
              onSelected: settings.enabled
                  ? (v) => ref.read(imageGenSettingsProvider.notifier).setModel(id)
                  : null,
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showApiKeyDialog(BuildContext context, WidgetRef ref, ImageGenSettings settings) {
    final controller = TextEditingController(text: settings.apiKey);
    final l10n = AppLocalizations.of(context);

    // Single-field input uses a bottom sheet (keyboard-resized)
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusBottomSheet),
        ),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.apiKey,
                style: const TextStyle(
                  fontSize: DesignTokens.fontSizeHeadline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                placeholder: l10n.enterApiKey,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(sheetCtx).colorScheme.surfaceContainerHighest,
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusGroupedCard),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    ref
                        .read(imageGenSettingsProvider.notifier)
                        .setApiKey(controller.text);
                    Navigator.pop(sheetCtx);
                  },
                  child: Text(l10n.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEndpointDialog(BuildContext context, WidgetRef ref, ImageGenSettings settings) {
    final controller = TextEditingController(text: settings.apiEndpoint);
    final l10n = AppLocalizations.of(context);

    // Single-field input uses a bottom sheet
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusBottomSheet),
        ),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.apiEndpoint,
                style: const TextStyle(
                  fontSize: DesignTokens.fontSizeHeadline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: controller,
                autofocus: true,
                placeholder: _getEndpointHint(settings.provider),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(sheetCtx).colorScheme.surfaceContainerHighest,
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusGroupedCard),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    ref
                        .read(imageGenSettingsProvider.notifier)
                        .setApiEndpoint(controller.text);
                    Navigator.pop(sheetCtx);
                  },
                  child: Text(l10n.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getEndpointHint(ImageGenProvider provider) {
    // Just return the provider's default endpoint
    return provider.defaultEndpoint;
  }
}

/// Widget for testing image generation
class _ImageGenTestWidget extends ConsumerStatefulWidget {
  final bool enabled;

  const _ImageGenTestWidget({required this.enabled});

  @override
  ConsumerState<_ImageGenTestWidget> createState() => _ImageGenTestWidgetState();
}

class _ImageGenTestWidgetState extends ConsumerState<_ImageGenTestWidget> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final genState = ref.watch(imageGenStateProvider);

    return Padding(
      padding: const EdgeInsets.all(DesignTokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).prompt,
              hintText: AppLocalizations.of(context).enterPromptToGenerate,
              border: const OutlineInputBorder(),
            ),
            maxLines: 3,
            enabled: widget.enabled && !genState.isGenerating,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: widget.enabled && _controller.text.isNotEmpty && !genState.isGenerating
                ? () {
                    final settings = ref.read(imageGenSettingsProvider);
                    // Manual tests also prepend the positive prompt prefix
                    final prefix = settings.positivePromptPrefix;
                    final raw = _controller.text;
                    final finalPrompt = (prefix != null && prefix.isNotEmpty)
                        ? '$prefix${raw.trim()}'
                        : raw;
                    ref.read(imageGenStateProvider.notifier).generate(
                      ImageGenRequest(
                        prompt: finalPrompt,
                        negativePrompt: settings.defaultNegativePrompt,
                        width: settings.defaultWidth,
                        height: settings.defaultHeight,
                        steps: settings.defaultSteps,
                        cfgScale: settings.defaultCfgScale,
                        sampler: settings.defaultSampler,
                      ),
                    );
                  }
                : null,
            icon: genState.isGenerating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.image),
            label: Text(genState.isGenerating ? AppLocalizations.of(context).generating : AppLocalizations.of(context).generate),
          ),
          
          // Progress bar
          if (genState.isGenerating) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: genState.progress),
            const SizedBox(height: 8),
            Text(
              '${(genState.progress * 100).round()}%',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ],

          // Result
          if (genState.result != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.darkBackground,
                borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                border: Border.all(color: AppTheme.accentColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check, size: 16, color: AppTheme.accentColor),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context).generationComplete,
                        style: const TextStyle(
                          fontSize: DesignTokens.fontSizeXs,
                          color: AppTheme.accentColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Prompt: ${genState.result!.prompt}'),
                  Text(
                    'Seed: ${genState.result!.seed}',
                    style: const TextStyle(
                      fontSize: DesignTokens.fontSizeXs,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  if (genState.result!.images.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${genState.result!.images.length} image(s) generated',
                      style: const TextStyle(
                        fontSize: DesignTokens.fontSizeXs,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Display generated images
                    SizedBox(
                      height: 250,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: genState.result!.images.length,
                        itemBuilder: (context, index) {
                          final imageData = genState.result!.images[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: DesignTokens.spaceSm),
                            child: GestureDetector(
                              onTap: () => _showFullScreenImage(context, imageData),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                                child: Image.memory(
                                  imageData,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const SizedBox(
                                      width: 200,
                                      height: 200,
                                      child: Center(
                                        child: Icon(Icons.broken_image, color: AppTheme.textMuted),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Error
          if (genState.error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DesignTokens.statusError.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                border: Border.all(color: DesignTokens.statusError.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, size: 16, color: DesignTokens.statusError),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      genState.error!,
                      style: const TextStyle(color: DesignTokens.statusError),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, Uint8List imageData) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Dismiss on tap background
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(color: Colors.black87),
            ),
            // Image with zoom
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.memory(
                  imageData,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}