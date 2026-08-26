import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/services/llm_service.dart';
import '../../../domain/services/region_service.dart';
import '../../providers/ai_preset_providers.dart';
import '../../providers/settings_providers.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import '../../providers/llm_configs_provider.dart';
import 'package:drift/drift.dart' as drift;
import '../../../data/database/database.dart';
import 'package:kirakira/presentation/widgets/common/kira_components.dart';
import 'package:kirakira/presentation/widgets/common/kira_button.dart';
import 'package:kirakira/presentation/widgets/common/kira_grouped_tile.dart';

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
      body: CustomScrollView(
        slivers: [
          // 返工条目2:砍顶部大标题;importPreset 挪进 AI预设 组头;
          // 内容上移,首个区块由 QuickSetup 承担(SafeArea)
          const SliverToBoxAdapter(
              child: SafeArea(bottom: false, child: QuickSetupCard())),
          // Active Preset Banner:iOS 化——纯色面 + 左侧 3pt primary VIP 竖条
          if (activePreset != null)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                    width: 0.5,
                  ),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      // 左侧 3pt primary 竖条(iOS 邮件 VIP 标记感)
                      Container(
                        width: 3,
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Icon(
                        Icons.auto_awesome,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.activePreset,
                              style: TextStyle(
                                fontSize: DesignTokens.fontSizeSm,
                                color: Theme.of(context).textTheme.bodyMedium?.color,
                              ),
                            ),
                            Text(
                              activePreset.name,
                              style: const TextStyle(
                                fontSize: DesignTokens.fontSizeHeadline,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                            horizontal: DesignTokens.spaceMd),
                        minSize: 32,
                        onPressed: () => context.push(AppRoutes.aiPresets),
                        child: Text(AppLocalizations.of(context)!.change),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 返工条目8:极限压缩——预设/提示词/生成参数已归 Core,此处只留
          // 连接三件套(测试/Probe/世界书),配合 QuickSetup ≈ 一屏
          SliverToBoxAdapter(
            child: KiraSection(
              title: AppLocalizations.of(context)!.llmConnection,
              children: [
                const _ConnectionTestTile(),
                KiraListTile(
                  icon: Icons.fingerprint_rounded,
                  title: '极客Probe', // TODO(i18n): 待补 l10n key
                  subtitle: '模型深度检测',
                  onTap: () => context.push(AppRoutes.modelDetection),
                ),
                // A3-T4: 全局世界书入口已随 NativeTavern 列表页删除
              ],
            ),
          ),

          // 避让底栏
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
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
        return DesignTokens.darkTextTertiary;
      case ConnectionStatus.testing:
        return AppTheme.accentColor;
      case ConnectionStatus.success:
        return DesignTokens.statusSuccess;
      case ConnectionStatus.error:
        return DesignTokens.statusError;
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
/// Model selection sheet with search functionality
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
        dotColor = DesignTokens.statusSuccess;
        statusText = '已连接';
        break;
      case MetricsStatus.measuring:
        dotColor = DesignTokens.statusWarning;
        statusText = '测试中';
        break;
      case MetricsStatus.error:
        dotColor = DesignTokens.statusError;
        statusText = '连接失败';
        break;
      case MetricsStatus.idle:
        dotColor = DesignTokens.darkTextTertiary;
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
              // G-T1 Step3:手绘按钮 → KiraButton(填实)
              KiraButton(
                onPressed: metrics.status == MetricsStatus.measuring
                    ? null
                    : () => ref
                        .read(connectionMetricsProvider.notifier)
                        .measure(config),
                child: Text(
                  metrics.status == MetricsStatus.measuring ? '测试中…' : '测试连接',
                ),
              ),
              const SizedBox(height: 10),
              // 深度检测 → KiraButton(描边)
              KiraButton(
                variant: KiraButtonVariant.outlined,
                onPressed: metrics.stabilityStatus == MetricsStatus.measuring
                    ? null
                    : () => ref
                        .read(connectionMetricsProvider.notifier)
                        .measureStability(config),
                child: Text(
                  metrics.stabilityStatus == MetricsStatus.measuring
                      ? '深度检测中…'
                      : '深度检测(3次采样)',
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
            backgroundColor: DesignTokens.statusError,
          ),
        );
      }
    });

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        border: Border.all(color: theme.dividerColor, width: 0.5),
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

  /// 接口类型:G-T1 Step2 → KiraGroupedTile 行 + CupertinoActionSheet 选型
  Widget _buildProviderSelector(LLMConfig config) {
    final theme = Theme.of(context);
    const options = <LLMProvider, String>{
      LLMProvider.openAICompatible: 'OpenAI 兼容(推荐,多数中转选这个)',
      LLMProvider.openai: 'OpenAI 官方',
      LLMProvider.claude: 'Claude',
      LLMProvider.gemini: 'Gemini',
      LLMProvider.deepSeek: 'DeepSeek',
      LLMProvider.qwen: '通义千问',
      LLMProvider.ollama: 'Ollama(本地)',
    };
    final current = options[config.provider] ?? 'OpenAI 兼容';
    final isDark = theme.brightness == Brightness.dark;

    return KiraGroupedTile(
      icon: CupertinoIcons.link,
      iconBg: theme.colorScheme.primary.withValues(alpha: 0.12),
      title: '接口类型',
      subtitle: current,
      onTap: () {
        showCupertinoModalPopup<void>(
          context: context,
          builder: (sheetCtx) => CupertinoTheme(
            data: CupertinoThemeData(
              brightness: isDark ? Brightness.dark : Brightness.light,
            ),
            child: CupertinoActionSheet(
              title: const Text('接口类型'),
              actions: [
                for (final e in options.entries)
                  CupertinoActionSheetAction(
                    onPressed: () {
                      ref
                          .read(llmConfigProvider.notifier)
                          .updateProvider(e.key);
                      Navigator.pop(sheetCtx);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(child: Text(e.value)),
                        if (e.key == config.provider) ...[
                          const SizedBox(width: 6),
                          const Icon(CupertinoIcons.checkmark, size: 16),
                        ],
                      ],
                    ),
                  ),
              ],
              cancelButton: CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(sheetCtx),
                child: const Text('取消'),
              ),
            ),
          ),
        );
      },
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
                          ? const Icon(Icons.check, color: DesignTokens.statusSuccess)
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
