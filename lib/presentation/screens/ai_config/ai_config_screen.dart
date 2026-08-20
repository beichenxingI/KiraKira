import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:flutter/services.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/instruct_template.dart';
import '../../../domain/services/llm_service.dart';
import '../../../domain/services/region_service.dart';
import '../../providers/ai_preset_providers.dart';
import '../../providers/instruct_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/fingerprint_providers.dart';
import 'fingerprint_result_widget.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import '../../providers/llm_configs_provider.dart';
import 'package:drift/drift.dart' as drift;
import '../../../data/database/database.dart';
import 'package:kirakira/presentation/widgets/common/kira_components.dart';

/// Provider for China region detection
final isChinaRegionProvider = FutureProvider<bool>((ref) async {
  return await RegionService.isChinaRegion();
});

/// AI Configuration screen - top-level entry for all AI-related settings
class AIConfigScreen extends ConsumerWidget {
  const AIConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activePreset = ref.watch(activeAIPresetProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.aiConfiguration),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: AppLocalizations.of(context)!.importPreset,
            onPressed: () => context.push(AppRoutes.aiPresets),
          ),
        ],
      ),
      body: ListView(
        children: [
          const QuickSetupCard(),
          // Active Preset Banner
          if (activePreset != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.activePreset,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                        Text(
                          activePreset.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push(AppRoutes.aiPresets),
                    child: Text(AppLocalizations.of(context)!.change),
                  ),
                ],
              ),
            ),

          // 三个分组卡片平铺（去掉外层大卡，恢复懒加载 + 减嵌套）
          KiraSection(
            title: AppLocalizations.of(context)!.presetsAndTemplates,
            children: [
              KiraListTile(
                icon: Icons.auto_awesome,
                title: AppLocalizations.of(context)!.aiPresets,
                subtitle: activePreset?.name ?? AppLocalizations.of(context)!.noPresetSelected,
                onTap: () => context.push(AppRoutes.aiPresets),
              ),
              const _InstructTemplateTile(),
              KiraListTile(
                icon: Icons.reorder,
                title: AppLocalizations.of(context)!.promptManager,
                subtitle: AppLocalizations.of(context)!.orderAndTogglePromptSections,
                onTap: () => context.push(AppRoutes.promptManager),
              ),
            ],
          ),
          KiraSection(
            title: AppLocalizations.of(context)!.llmConnection,
            children: [
              const _ConnectionTestTile(),
              KiraListTile(
                icon: Icons.fingerprint_rounded,
                title: '极客Probe',
                subtitle: '模型深度检测',
                onTap: () => context.push(AppRoutes.modelDetection),
              ),
              KiraListTile(
                icon: Icons.public,
                title: '全局世界书',
                subtitle: '对所有角色生效的世界书',
                onTap: () => context.push('/world-info?isGlobal=true'),
              ),
            ],
          ),
          KiraSection(
            title: AppLocalizations.of(context)!.generationSettings,
            children: [
              const _ContextLengthTile(),
              const _MaxTokensTile(),
              const _TemperatureTile(),
              const _TopPTile(),
              const _StreamingTile(),
              KiraListTile(
                icon: Icons.tune,
                title: AppLocalizations.of(context)!.advancedSamplerSettings,
                subtitle: AppLocalizations.of(context)!.fullControlOverSampling,
                onTap: () => context.push(AppRoutes.advancedSettings),
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.accentColor,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _InstructTemplateTile extends ConsumerWidget {
  const _InstructTemplateTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTemplate = ref.watch(activeInstructTemplateProvider);
    final allTemplates = ref.watch(allInstructTemplatesProvider);

    return ListTile(
      leading: const Icon(Icons.code),
      title: Text(AppLocalizations.of(context)!.instructTemplate),
      subtitle: Text(activeTemplate.name),
      onTap: () => _showTemplatePicker(context, ref, activeTemplate, allTemplates),
    );
  }

  void _showTemplatePicker(
    BuildContext context,
    WidgetRef ref,
    InstructTemplate activeTemplate,
    List<InstructTemplate> allTemplates,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  AppLocalizations.of(context)!.selectInstructTemplate,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  AppLocalizations.of(context)!.instructTemplateDescription,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: allTemplates.length,
                  itemBuilder: (context, index) {
                    final template = allTemplates[index];
                    final isSelected = template.id == activeTemplate.id;

                    return ListTile(
                      leading: Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: isSelected ? AppTheme.primaryColor : AppTheme.textMuted,
                      ),
                      title: Text(
                        template.name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        template.description,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onTap: () {
                        ref.read(activeInstructTemplateIdProvider.notifier).state =
                            template.id;
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LLMProviderTile extends ConsumerWidget {
  const _LLMProviderTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(llmConfigProvider);
    final providerName = _providerName(config.provider);

    return ListTile(
      leading: const Icon(Icons.cloud),
      title: Text(AppLocalizations.of(context)!.provider),
      subtitle: Text(providerName),
      onTap: () => _showProviderPicker(context, ref, config),
      onLongPress: () => _copyToClipboard(context, providerName),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${AppLocalizations.of(context)!.copiedToClipboard}: $text'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _providerName(LLMProvider provider) {
    switch (provider) {
      case LLMProvider.openai:
        return 'OpenAI';
      case LLMProvider.claude:
        return 'Claude (Anthropic)';
      case LLMProvider.openRouter:
        return 'OpenRouter';
      case LLMProvider.gemini:
        return 'Gemini (Google)';
      case LLMProvider.ollama:
        return 'Ollama (Local)';
      case LLMProvider.koboldCpp:
        return 'KoboldCpp (Local)';
      case LLMProvider.deepSeek:
        return 'DeepSeek';
      case LLMProvider.qwen:
        return 'Qwen (Alibaba)';
      case LLMProvider.openAICompatible:
        return 'OAI Compatible';
    }
  }

  /// Check if OpenAI should be hidden based on region or language setting
  bool _shouldHideOpenAI(BuildContext context, bool isChinaRegion) {
    // Hide if in China region (detected via App Store/SIM)
    if (isChinaRegion) {
      return true;
    }
    
    // Also hide if app language is set to Chinese (zh)
    final locale = Localizations.localeOf(context);
    if (locale.languageCode == 'zh') {
      return true;
    }
    
    return false;
  }

  /// Get filtered list of providers based on region and language
  List<LLMProvider> _getAvailableProviders(BuildContext context, bool isChinaRegion) {
    final hideOpenAI = _shouldHideOpenAI(context, isChinaRegion);
    return LLMProvider.values.where((provider) {
      // Hide OpenAI in China region or when language is Chinese
      if (hideOpenAI && provider == LLMProvider.openai) {
        return false;
      }
      return true;
    }).toList();
  }

  void _showProviderPicker(BuildContext context, WidgetRef ref, LLMConfig config) {
    // Get the China region status from provider
    final isChinaAsync = ref.read(isChinaRegionProvider);
    final isChinaRegion = isChinaAsync.valueOrNull ?? false;
    final availableProviders = _getAvailableProviders(context, isChinaRegion);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  AppLocalizations.of(context)!.selectLlmProvider,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: availableProviders.map((provider) => RadioListTile<LLMProvider>(
                    title: Text(_providerName(provider)),
                    subtitle: Text(_providerDescription(provider)),
                    value: provider,
                    groupValue: config.provider,
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(llmConfigProvider.notifier).updateProvider(value);
                        Navigator.pop(context);
                      }
                    },
                  )).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _providerDescription(LLMProvider provider) {
    switch (provider) {
      case LLMProvider.openai:
        return '5.2';
      case LLMProvider.claude:
        return 'Claude 4.5';
      case LLMProvider.openRouter:
        return 'Multiple providers';
      case LLMProvider.gemini:
        return 'Gemini 3 Pro, Flash';
      case LLMProvider.ollama:
        return 'Local models';
      case LLMProvider.koboldCpp:
        return 'GGUF models';
      case LLMProvider.deepSeek:
        return 'DeepSeek V3.2, DeepSeek R1';
      case LLMProvider.qwen:
        return 'Qwen Plus, Qwen Max';
      case LLMProvider.openAICompatible:
        return 'Custom OAI-compatible API';
    }
  }
}

class _ApiKeyTile extends ConsumerStatefulWidget {
  const _ApiKeyTile();

  @override
  ConsumerState<_ApiKeyTile> createState() => _ApiKeyTileState();
}


class _ApiKeyTileState extends ConsumerState<_ApiKeyTile> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(llmConfigProvider);
    final isLocal =
        config.provider == LLMProvider.ollama || config.provider == LLMProvider.koboldCpp;

    if (isLocal) return const SizedBox.shrink();

    return ListTile(
      leading: const Icon(Icons.key),
      title: Text(AppLocalizations.of(context)!.apiKey),
      subtitle: Text(
        config.apiKey.isEmpty
            ? AppLocalizations.of(context)!.notSet
            : _obscureText
                ? '••••••••${config.apiKey.length > 8 ? config.apiKey.substring(config.apiKey.length - 4) : ''}'
                : config.apiKey,
      ),
      trailing: IconButton(
        icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
        onPressed: () => setState(() => _obscureText = !_obscureText),
      ),
      onTap: () => _showApiKeyDialog(context, ref, config),
      onLongPress: config.apiKey.isNotEmpty ? () => _copyToClipboard(context, config.apiKey) : null,
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.copiedToClipboard),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showApiKeyDialog(BuildContext context, WidgetRef ref, LLMConfig config) {
    final controller = TextEditingController(text: config.apiKey);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.apiKey),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.enterApiKey,
            hintText: 'sk-...',
          ),
          obscureText: true,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              ref.read(llmConfigProvider.notifier).updateApiKey(controller.text);
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
    );
  }
}

class _ApiUrlTile extends ConsumerWidget {
  const _ApiUrlTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(llmConfigProvider);

    return ListTile(
      leading: const Icon(Icons.link),
      title: Text(AppLocalizations.of(context)!.apiUrl),
      subtitle: Text(config.apiUrl),
      onTap: () => _showApiUrlDialog(context, ref, config),
      onLongPress: config.apiUrl.isNotEmpty ? () => _copyToClipboard(context, config.apiUrl) : null,
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${AppLocalizations.of(context)!.copiedToClipboard}: $text'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showApiUrlDialog(BuildContext context, WidgetRef ref, LLMConfig config) {
    final controller = TextEditingController(text: config.apiUrl);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.apiUrl),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.apiEndpointUrl,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              ref.read(llmConfigProvider.notifier).updateApiUrl(controller.text);
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
    );
  }
}

class _ModelTile extends ConsumerStatefulWidget {
  const _ModelTile();

  @override
  ConsumerState<_ModelTile> createState() => _ModelTileState();
}

class _ModelTileState extends ConsumerState<_ModelTile> {
  @override
  Widget build(BuildContext context) {
    final config = ref.watch(llmConfigProvider);
    final modelFetchState = ref.watch(modelFetchProvider);

    ref.listen<ModelFetchState>(modelFetchProvider, (previous, next) {
      if (next.status == ModelFetchStatus.success && next.models.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showModelListSheet(context, ref, config, next.models);
          }
        });
      } else if (next.status == ModelFetchStatus.error) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(next.errorMessage ?? AppLocalizations.of(context)!.failedToFetchModels),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      }
    });

    return ListTile(
      leading: const Icon(Icons.memory),
      title: Text(AppLocalizations.of(context)!.model),
      subtitle: _buildSubtitle(config, modelFetchState),
      trailing: modelFetchState.status == ModelFetchStatus.loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.arrow_drop_down),
      onTap: modelFetchState.status == ModelFetchStatus.loading
          ? null
          : () => _showModelPicker(context, ref, config, modelFetchState),
    );
  }

  Widget _buildSubtitle(LLMConfig config, ModelFetchState modelFetchState) {
    if (modelFetchState.status == ModelFetchStatus.loading) {
      return Text(AppLocalizations.of(context)!.fetchingModels);
    }
    return Text(config.model.isEmpty ? AppLocalizations.of(context)!.notSet : config.model);
  }

  void _showModelPicker(BuildContext context, WidgetRef ref, LLMConfig config,
      ModelFetchState modelFetchState) {
    if (modelFetchState.status == ModelFetchStatus.success &&
        modelFetchState.models.isNotEmpty) {
      _showModelListSheet(context, ref, config, modelFetchState.models);
    } else {
      _showModelInputDialog(context, ref, config);
    }
  }

  void _showModelListSheet(
      BuildContext context, WidgetRef ref, LLMConfig config, List<String> models) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _ModelSelectionSheet(
        models: models,
        selectedModel: config.model,
        onModelSelected: (model) {
          ref.read(llmConfigProvider.notifier).updateModel(model);
          Navigator.pop(sheetContext);
        },
        onRefresh: () {
          Navigator.pop(sheetContext);
          final currentConfig = ref.read(llmConfigProvider);
          ref.read(modelFetchProvider.notifier).fetchModels(currentConfig);
        },
        onManualEntry: () {
          Navigator.pop(sheetContext);
          final currentConfig = ref.read(llmConfigProvider);
          _showManualInputDialog(context, ref, currentConfig);
        },
      ),
    );
  }

  void _showModelInputDialog(BuildContext context, WidgetRef ref, LLMConfig config) {
    final controller = TextEditingController(text: config.model);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.model),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.modelName,
                hintText: 'e.g., deepseek-3.2',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.cloud_download),
                label: Text(AppLocalizations.of(context)!.fetchAvailableModels),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  final currentConfig = ref.read(llmConfigProvider);
                  ref.read(modelFetchProvider.notifier).fetchModels(currentConfig);
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.fetchModelsDescription,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              ref.read(llmConfigProvider.notifier).updateModel(controller.text);
              Navigator.pop(dialogContext);
            },
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
    );
  }

  void _showManualInputDialog(BuildContext context, WidgetRef ref, LLMConfig config) {
    final controller = TextEditingController(text: config.model);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.enterModelName),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.modelName,
            hintText: 'e.g., deepseek-3.2',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              ref.read(llmConfigProvider.notifier).updateModel(controller.text);
              Navigator.pop(dialogContext);
            },
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
    );
  }
}

class _ConnectionTestTile extends ConsumerWidget {
  const _ConnectionTestTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testState = ref.watch(connectionTestProvider);
    final config = ref.watch(llmConfigProvider);

    return ListTile(
      leading: Icon(
        _getStatusIcon(testState.status),
        color: _getStatusColor(testState.status),
      ),
      title: Text(AppLocalizations.of(context)!.testConnection),
      subtitle: Text(_getStatusText(context, testState)),
      trailing: testState.status == ConnectionStatus.testing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: testState.status == ConnectionStatus.testing
          ? null
          : () => ref.read(connectionTestProvider.notifier).testConnection(config),
    );
  }

  IconData _getStatusIcon(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.idle:
        return Icons.help_outline;
      case ConnectionStatus.testing:
        return Icons.sync;
      case ConnectionStatus.success:
        return Icons.check_circle;
      case ConnectionStatus.error:
        return Icons.error;
    }
  }

  Color _getStatusColor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.idle:
        return AppTheme.textMuted;
      case ConnectionStatus.testing:
        return AppTheme.accentColor;
      case ConnectionStatus.success:
        return Colors.green;
      case ConnectionStatus.error:
        return Colors.red;
    }
  }

  String _getStatusText(BuildContext context, ConnectionTestState state) {
    final l10n = AppLocalizations.of(context)!;
    switch (state.status) {
      case ConnectionStatus.idle:
        return l10n.tapToTestConnection;
      case ConnectionStatus.testing:
        return l10n.testing;
      case ConnectionStatus.success:
        return state.message ?? l10n.connected;
      case ConnectionStatus.error:
        return state.message ?? l10n.connectionFailedSimple;
    }
  }
}

/// Context Length tile - shows the context window size (input tokens)
class _ContextLengthTile extends ConsumerWidget {
  const _ContextLengthTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(llmConfigProvider);
    final contextValue = '${config.contextLength}';

    return ListTile(
      leading: const Icon(Icons.memory),
      title: Text(AppLocalizations.of(context)!.contextLength),
      subtitle: Text('$contextValue tokens'),
      onTap: () => _showContextLengthDialog(context, ref, config),
      onLongPress: () => _copyToClipboard(context, contextValue),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${AppLocalizations.of(context)!.copiedToClipboard}: $text'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showContextLengthDialog(BuildContext context, WidgetRef ref, LLMConfig config) {
    final controller = TextEditingController(text: config.contextLength.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.contextLength),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.contextWindowSize,
                hintText: '1000000',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.contextLengthDescription,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value > 0) {
                ref.read(llmConfigProvider.notifier).updateContextLength(value);
              }
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
    );
  }
}

/// Max Tokens tile - shows the maximum output tokens
class _MaxTokensTile extends ConsumerWidget {
  const _MaxTokensTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(llmConfigProvider);
    final tokenValue = '${config.maxTokens}';

    return ListTile(
      leading: const Icon(Icons.format_list_numbered),
      title: Text(AppLocalizations.of(context)!.maxTokens),
      subtitle: Text('$tokenValue tokens'),
      onTap: () => _showMaxTokensDialog(context, ref, config),
      onLongPress: () => _copyToClipboard(context, tokenValue),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${AppLocalizations.of(context)!.copiedToClipboard}: $text'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showMaxTokensDialog(BuildContext context, WidgetRef ref, LLMConfig config) {
    final controller = TextEditingController(text: config.maxTokens.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.maxTokens),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.maximumTokensToGenerate,
                hintText: '512',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.maxTokensDescription,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value > 0) {
                ref.read(llmConfigProvider.notifier).updateMaxTokens(value);
              }
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
    );
  }
}

class _TemperatureTile extends ConsumerWidget {
  const _TemperatureTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(llmConfigProvider);

    return ListTile(
      leading: const Icon(Icons.thermostat),
      title: Text(AppLocalizations.of(context)!.temperature),
      subtitle: Slider(
        value: config.temperature,
        min: 0.0,
        max: 2.0,
        divisions: 40,
        label: config.temperature.toStringAsFixed(2),
        onChanged: (value) {
          ref.read(llmConfigProvider.notifier).updateTemperature(value);
        },
      ),
    );
  }
}

class _TopPTile extends ConsumerWidget {
  const _TopPTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(llmConfigProvider);

    return ListTile(
      leading: const Icon(Icons.pie_chart),
      title: Text(AppLocalizations.of(context)!.topP),
      subtitle: Slider(
        value: config.topP,
        min: 0.0,
        max: 1.0,
        divisions: 20,
        label: config.topP.toStringAsFixed(2),
        onChanged: (value) {
          ref.read(llmConfigProvider.notifier).updateTopP(value);
        },
      ),
    );
  }
}

class _StreamingTile extends ConsumerWidget {
  const _StreamingTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(llmConfigProvider);

    return SwitchListTile(
      secondary: const Icon(Icons.stream),
      title: Text(AppLocalizations.of(context)!.streaming),
      subtitle: Text(AppLocalizations.of(context)!.showResponseAsItGenerates),
      value: config.streamEnabled,
      onChanged: (value) {
        ref.read(llmConfigProvider.notifier).updateStreamEnabled(value);
      },
    );
  }
}

/// Model selection sheet with search functionality
class _ModelSelectionSheet extends StatefulWidget {
  final List<String> models;
  final String selectedModel;
  final void Function(String model) onModelSelected;
  final VoidCallback onRefresh;
  final VoidCallback onManualEntry;

  const _ModelSelectionSheet({
    required this.models,
    required this.selectedModel,
    required this.onModelSelected,
    required this.onRefresh,
    required this.onManualEntry,
  });

  @override
  State<_ModelSelectionSheet> createState() => _ModelSelectionSheetState();
}

class _ModelSelectionSheetState extends State<_ModelSelectionSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _filteredModels = [];

  @override
  void initState() {
    super.initState();
    _filteredModels = widget.models;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredModels = widget.models;
      } else {
        _filteredModels =
            widget.models.where((model) => model.toLowerCase().contains(query)).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.selectModelCount(widget.models.length),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: AppLocalizations.of(context)!.refreshModels,
                    onPressed: widget.onRefresh,
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: AppLocalizations.of(context)!.enterManually,
                    onPressed: widget.onManualEntry,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.searchModels,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_filteredModels.length} of ${widget.models.length} models',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                  ),
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: _filteredModels.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off, size: 48, color: AppTheme.textMuted),
                          const SizedBox(height: 16),
                          Text(
                            AppLocalizations.of(context)!.noModelsFound,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppTheme.textMuted,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(context)!.tryDifferentSearchTerm,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textMuted,
                                ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _filteredModels.length,
                      itemBuilder: (_, index) {
                        final model = _filteredModels[index];
                        final isSelected = model == widget.selectedModel;
                        return ListTile(
                          title: Text(
                            model,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? AppTheme.accentColor : null,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check, color: AppTheme.accentColor)
                              : null,
                          onTap: () => widget.onModelSelected(model),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
class _ConnectionStatusCard extends ConsumerWidget {
  const _ConnectionStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(llmConfigProvider);
    final metrics = ref.watch(connectionMetricsProvider);

    final Color dotColor;
    final String statusText;
    switch (metrics.status) {
      case MetricsStatus.success:
        dotColor = const Color(0xFF34C759);
        statusText = '已连接';
        break;
      case MetricsStatus.measuring:
        dotColor = const Color(0xFFFF9F0A);
        statusText = '测试中';
        break;
      case MetricsStatus.error:
        dotColor = const Color(0xFFFF453A);
        statusText = '连接失败';
        break;
      case MetricsStatus.idle:
        dotColor = const Color(0xFF8E8E93);
        statusText = '未测试';
        break;
    }

    final modelText = (config.model == null || config.model!.isEmpty)
        ? '未选择模型'
        : config.model!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: GestureDetector(
        onTap: () => context.push(AppRoutes.llmConfigList),
        child: Container(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      config.provider.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right,
                      size: 20,
                      color: Theme.of(context).textTheme.bodySmall?.color),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$modelText  ${config.apiUrl}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 14),
              Divider(
                  height: 1,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
              const SizedBox(height: 14),
              Row(
                children: [
                  _MetricCell(
                    label: '首Token',
                    value: metrics.ttftMs != null ? '${metrics.ttftMs}ms' : '—',
                  ),
                  _MetricCell(
                    label: '速率',
                    value: metrics.charsPerSec != null
                        ? '${metrics.charsPerSec!.toStringAsFixed(1)}字/s'
                        : '—',
                  ),
                  _MetricCell(
                    label: '稳定性',
                    value: metrics.stabilityStatus == MetricsStatus.measuring
                        ? '检测中'
                        : (metrics.stabilityRating ?? '—'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: metrics.status == MetricsStatus.measuring
                    ? null
                    : () => ref
                        .read(connectionMetricsProvider.notifier)
                        .measure(config),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    metrics.status == MetricsStatus.measuring ? '测试中…' : '测试连接',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: metrics.stabilityStatus == MetricsStatus.measuring
                    ? null
                    : () => ref
                        .read(connectionMetricsProvider.notifier)
                        .measureStability(config),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.4),
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    metrics.stabilityStatus == MetricsStatus.measuring
                        ? '深度检测中…'
                        : '深度检测（3次采样）',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '深度检测会发送 3 次测试消息，消耗少量额度',
                style: TextStyle(
                    fontSize: DesignTokens.fontSizeCaption,
                    color: Theme.of(context).textTheme.bodySmall?.color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _MetricCell extends StatelessWidget {
  final String label;
  final String value;
  const _MetricCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.bodyLarge?.color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: DesignTokens.fontSizeCaption,
                color: Theme.of(context).textTheme.bodySmall?.color),
          ),
        ],
      ),
    );
  }
}
/// ══════════════════════════════════════════════════════════
/// 快速接入卡片
/// 面向新手：填 API 地址 + 密钥 → 一键拉取模型 → 下拉选择 → 立即可用。
/// 直接读写 llmConfig（聊天实际使用的配置），每次修改自动持久化，
/// 无需再去"多方案"里新建预设。高级用户仍可使用下方的预设系统。
/// ══════════════════════════════════════════════════════════
class QuickSetupCard extends ConsumerStatefulWidget {
  const QuickSetupCard({super.key});

  @override
  ConsumerState<QuickSetupCard> createState() => _QuickSetupCardState();
}

class _QuickSetupCardState extends ConsumerState<QuickSetupCard> {
  late final TextEditingController _urlController;
  late final TextEditingController _keyController;
  bool _obscureKey = true; // API 密钥默认遮罩

  @override
  void initState() {
    super.initState();
    // 用当前已保存的配置初始化输入框
    final config = ref.read(llmConfigProvider);
    _urlController = TextEditingController(text: config.apiUrl);
    _keyController = TextEditingController(text: config.apiKey);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = ref.watch(llmConfigProvider);
    // 配置异步加载完成 / 切换方案后，同步刷新输入框，避免显示旧的默认值
    ref.listen<LLMConfig>(llmConfigProvider, (prev, next) {
      if (_urlController.text != next.apiUrl) {
        _urlController.text = next.apiUrl;
      }
      if (_keyController.text != next.apiKey) {
        _keyController.text = next.apiKey;
      }
    });
    final fetchState = ref.watch(modelFetchProvider);
    final isLoading = fetchState.status == ModelFetchStatus.loading;

    // 监听拉取结果：成功弹出模型选择，失败提示错误
    ref.listen<ModelFetchState>(modelFetchProvider, (prev, next) {
      if (next.status == ModelFetchStatus.success && next.models.isNotEmpty) {
        _showModelPicker(next.models);
      } else if (next.status == ModelFetchStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('拉取模型失败：${next.errorMessage ?? "请检查地址和密钥"}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题 + 引导语
          Row(
            children: [
              Icon(Icons.rocket_launch, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              const Text('快速接入',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '填入 API 地址和密钥，点击"拉取模型"即可开始使用。',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),

          // ── 快速切换 LLM 方案 ──
          // 读取已保存的多套 API 配置，下拉即可切换当前使用的方案。
          // 仅当保存了至少一套方案时才显示。
          Builder(builder: (context) {
            final llmState = ref.watch(llmConfigsProvider);
            final configs = llmState.configs;
            final activeId = llmState.active?.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  if (configs.isNotEmpty)
                    Row(
                      children: [
                        Expanded(
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: '当前方案',
                              prefixIcon: Icon(Icons.swap_horiz),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: configs.any((c) => c.id == activeId)
                                    ? activeId
                                    : null,
                                hint: const Text('选择方案'),
                                items: configs
                                    .map((c) => DropdownMenuItem(
                                          value: c.id,
                                          child: Text(
                                            c.name.isEmpty
                                                ? '未命名方案'
                                                : c.name,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ))
                                    .toList(),
                                onChanged: (id) {
                                  if (id == null) return;
                                  ref
                                      .read(llmConfigsProvider.notifier)
                                      .setActive(id);
                                },
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon:
                              const Icon(Icons.drive_file_rename_outline),
                          tooltip: '重命名当前方案',
                          onPressed: _renameActiveConfig,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: '删除当前方案',
                          onPressed: activeId == null
                              ? null
                              : () => _confirmDeleteActiveConfig(activeId),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _saveAsNewConfig,
                      icon: const Icon(Icons.add),
                      label: const Text('把当前配置保存为新方案'),
                    ),
                  ),
                ],
              ),
            );
          }),
          // 接口类型选择（大多数第三方中转选"OpenAI 兼容"）
          _buildProviderSelector(config),
          const SizedBox(height: 12),

          // API 地址
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'API 地址',
              hintText: 'https://api.openai.com/v1',
              prefixIcon: Icon(Icons.link),
            ),
            // 失焦即保存
            onChanged: (v) =>
                ref.read(llmConfigProvider.notifier).updateApiUrl(v.trim()),
          ),
          const SizedBox(height: 12),

          // API 密钥
          TextField(
            controller: _keyController,
            obscureText: _obscureKey,
            decoration: InputDecoration(
              labelText: 'API 密钥',
              hintText: 'sk-...',
              prefixIcon: const Icon(Icons.key),
              suffixIcon: IconButton(
                icon: Icon(
                    _obscureKey ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
            ),
            onChanged: (v) =>
                ref.read(llmConfigProvider.notifier).updateApiKey(v.trim()),
          ),
          const SizedBox(height: 12),

          // 当前选中的模型显示（可点击快捷切换）
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
              onTap: () {
                final models = ref.read(modelFetchProvider).models;
                if (models.isNotEmpty) {
                  // 已有拉取结果，直接弹出选择
                  _showModelPicker(models);
                } else {
                  // 尚未拉取，先确保配置写入再拉取
                  final notifier = ref.read(llmConfigProvider.notifier);
                  notifier.updateApiUrl(_urlController.text.trim());
                  notifier.updateApiKey(_keyController.text.trim());
                  ref
                      .read(modelFetchProvider.notifier)
                      .fetchModels(ref.read(llmConfigProvider));
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.memory, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        config.model.isEmpty ? '尚未选择模型（点击选择）' : config.model,
                        style: TextStyle(
                          color: config.model.isEmpty
                              ? theme.textTheme.bodySmall?.color
                              : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.unfold_more, size: 18,
                        color: theme.textTheme.bodySmall?.color),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 拉取模型按钮（核心动作）
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isLoading
                  ? null
                  : () {
                      // 先确保输入框内容已写入配置，再拉取
                      final notifier = ref.read(llmConfigProvider.notifier);
                      notifier.updateApiUrl(_urlController.text.trim());
                      notifier.updateApiKey(_keyController.text.trim());
                      final latest = ref.read(llmConfigProvider);
                      ref
                          .read(modelFetchProvider.notifier)
                          .fetchModels(latest);
                    },
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text(isLoading ? '正在拉取模型…' : '拉取模型并选择'),
            ),
          ),
          const SizedBox(height: 8),
          // 保底：自动拉取失败时，手动重新拉取模型列表
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isLoading
                  ? null
                  : () {
                      final notifier = ref.read(llmConfigProvider.notifier);
                      notifier.updateApiUrl(_urlController.text.trim());
                      notifier.updateApiKey(_keyController.text.trim());
                      ref
                          .read(modelFetchProvider.notifier)
                          .fetchModels(ref.read(llmConfigProvider));
                    },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('刷新模型列表'),
            ),
          ),
          const SizedBox(height: 8),
          // 确认并启用：强制写入当前输入内容 + 明确反馈，消除"是否已生效"的不确定感
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () {
                final notifier = ref.read(llmConfigProvider.notifier);
                notifier.updateApiUrl(_urlController.text.trim());
                notifier.updateApiKey(_keyController.text.trim());
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✓ 配置已保存并启用'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('确认并启用'),
            ),
          ),
          const SizedBox(height: 16),
          const _ConnectionStatusCard(),
        ],
      ),
    );
  }

  /// 接口类型下拉：默认 OpenAI 兼容，覆盖绝大多数第三方中转 API。
  Widget _buildProviderSelector(LLMConfig config) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: '接口类型',
        prefixIcon: Icon(Icons.hub),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<LLMProvider>(
          isExpanded: true,
          value: config.provider,
          items: const [
            DropdownMenuItem(
              value: LLMProvider.openAICompatible,
              child: Text('OpenAI 兼容（推荐，多数中转选这个）'),
            ),
            DropdownMenuItem(
                value: LLMProvider.openai, child: Text('OpenAI 官方')),
            DropdownMenuItem(
                value: LLMProvider.claude, child: Text('Claude')),
            DropdownMenuItem(
                value: LLMProvider.gemini, child: Text('Gemini')),
            DropdownMenuItem(
                value: LLMProvider.deepSeek, child: Text('DeepSeek')),
            DropdownMenuItem(value: LLMProvider.qwen, child: Text('通义千问')),
            DropdownMenuItem(
                value: LLMProvider.ollama, child: Text('Ollama（本地）')),
          ],
          onChanged: (v) {
            if (v != null) {
              ref.read(llmConfigProvider.notifier).updateProvider(v);
            }
          },
        ),
      ),
    );
  }

  /// 弹出底部面板，展示拉取到的模型列表供选择。
  void _showModelPicker(List<String> models) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final current = ref.read(llmConfigProvider).model;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('选择模型',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: models.length,
                  itemBuilder: (_, i) {
                    final m = models[i];
                    return ListTile(
                      title: Text(m),
                      trailing: m == current
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                      onTap: () {
                        ref.read(llmConfigProvider.notifier).updateModel(m);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// 把当前填写的配置保存为一套新的 LLM 方案。
  void _saveAsNewConfig() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('保存为新方案'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '方案名称',
            hintText: '例如：我的中转站',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final config = ref.read(llmConfigProvider);
              final now = DateTime.now();
              final id = now.millisecondsSinceEpoch.toString();
              final companion = LlmConfigsCompanion(
                id: drift.Value(id),
                name: drift.Value(name.isEmpty ? '未命名方案' : name),
                provider: drift.Value(config.provider.name),
                endpoint: drift.Value(config.apiUrl),
                apiKey: drift.Value(config.apiKey),
                model: drift.Value(
                    config.model.isEmpty ? null : config.model),
                createdAt: drift.Value(now),
                modifiedAt: drift.Value(now),
              );
              await ref
                  .read(llmConfigsProvider.notifier)
                  .upsert(companion);
              await ref.read(llmConfigsProvider.notifier).setActive(id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  /// 给当前选中的方案改名。
  void _renameActiveConfig() {
    final state = ref.read(llmConfigsProvider);
    final active = state.active;
    if (active == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择一个方案')),
      );
      return;
    }
    final nameController = TextEditingController(text: active.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名方案'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: '方案名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final companion = LlmConfigsCompanion(
                id: drift.Value(active.id),
                name: drift.Value(name.isEmpty ? '未命名方案' : name),
                provider: drift.Value(active.provider),
                endpoint: drift.Value(active.endpoint),
                apiKey: drift.Value(active.apiKey),
                model: drift.Value(active.model),
                createdAt: drift.Value(active.createdAt),
                modifiedAt: drift.Value(DateTime.now()),
              );
              await ref
                  .read(llmConfigsProvider.notifier)
                  .upsert(companion);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteActiveConfig(String id) {
    final state = ref.read(llmConfigsProvider);
    final active = state.active;
    if (active == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择一个方案')),
      );
      return;
    }
    final name = active.name.isEmpty ? '未命名方案' : active.name;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除方案'),
        content: Text('将删除方案「$name」，此操作不可恢复。确定吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              await ref.read(llmConfigsProvider.notifier).delete(id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已删除方案「$name」')),
                );
              }
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}