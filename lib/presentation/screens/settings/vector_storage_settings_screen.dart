import 'dart:convert';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/models/vector_storage.dart';
import 'package:kirakira/domain/services/vector_storage_service.dart';
import 'package:kirakira/presentation/providers/vector_storage_providers.dart';
import 'package:kirakira/presentation/theme/app_theme.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/widgets/common/kira_components.dart';

/// Settings screen for Vector Storage / RAG
class VectorStorageSettingsScreen extends ConsumerWidget {
  const VectorStorageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(vectorStorageSettingsProvider);
    final collections = ref.watch(vectorCollectionsProvider);
    final service = ref.watch(vectorStorageServiceProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(
              AppLocalizations.of(context)!.vectorStorageRag,
              style: Theme.of(context).textTheme.displayLarge,
            ),
            actions: [
              IconButton(
                icon: const Icon(CupertinoIcons.question_circle),
                onPressed: () => _showHelpDialog(context, service),
                tooltip: '帮助',
              ),
            ],
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              // Enable toggle
              KiraSection(
                title: '',
                children: [
                  KiraSwitchTile(
                    title: '启用 RAG',
                    subtitle: '检索增强生成',
                    value: settings.enabled,
                    onChanged: (value) {
                      ref
                          .read(vectorStorageSettingsProvider.notifier)
                          .setEnabled(value);
                    },
                  ),
                ],
              ),
          // Collections section
          _buildSectionHeader(context, 'Collections'),
          const SizedBox(height: 8),
          _CollectionsSection(
            collections: collections,
            activeCollectionId: settings.activeCollectionId,
            enabled: settings.enabled,
            onCollectionSelected: (id) {
              ref.read(vectorStorageSettingsProvider.notifier).setActiveCollection(id);
            },
            onCreateCollection: () => _showCreateCollectionDialog(context, ref),
            onDeleteCollection: (id) => _confirmDeleteCollection(context, ref, id),
            onExportCollection: (id) => _exportCollection(context, ref, id),
            onImportCollection: () => _importCollection(context, ref),
          ),

          const Divider(height: 32),

          // Search settings
          _buildSectionHeader(context, 'Search Settings'),
          const SizedBox(height: 16),
          
          // Top K slider
          ListTile(
            title: const Text('Top K 结果数'),
            subtitle: Text('Return top ${settings.topK} most similar documents'),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: settings.topK.toDouble(),
                min: 1,
                max: 20,
                divisions: 19,
                label: settings.topK.toString(),
                onChanged: settings.enabled
                    ? (value) {
                        ref.read(vectorStorageSettingsProvider.notifier).setTopK(value.round());
                      }
                    : null,
              ),
            ),
          ),

          // Similarity threshold slider
          ListTile(
            title: const Text('相似度阈值'),
            subtitle: Text('Minimum: ${(settings.similarityThreshold * 100).toStringAsFixed(0)}%'),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: settings.similarityThreshold,
                min: 0,
                max: 1,
                divisions: 20,
                label: '${(settings.similarityThreshold * 100).toStringAsFixed(0)}%',
                onChanged: settings.enabled
                    ? (value) {
                        ref.read(vectorStorageSettingsProvider.notifier).setSimilarityThreshold(value);
                      }
                    : null,
              ),
            ),
          ),

          const Divider(height: 32),

          // Embedding settings
          _buildSectionHeader(context, 'Embedding Provider'),
          const SizedBox(height: 8),
          DropdownButtonFormField<EmbeddingProvider>(
            value: settings.embeddingProvider,
            decoration: const InputDecoration(
              labelText: '提供者',
              border: OutlineInputBorder(),
            ),
            items: EmbeddingProvider.values.map((provider) {
              return DropdownMenuItem(
                value: provider,
                child: Text(provider.displayName),
              );
            }).toList(),
            onChanged: settings.enabled
                ? (provider) {
                    if (provider != null) {
                      ref.read(vectorStorageSettingsProvider.notifier).setEmbeddingProvider(provider);
                    }
                  }
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: settings.embeddingModel ?? settings.embeddingProvider.defaultModel,
            decoration: const InputDecoration(
              labelText: '模型',
              border: OutlineInputBorder(),
            ),
            enabled: settings.enabled,
            onChanged: (value) {
              ref.read(vectorStorageSettingsProvider.notifier).setEmbeddingModel(value);
            },
          ),

          // Embedding API 配置（local 模式用本地模型，无需填）
          if (settings.embeddingProvider != EmbeddingProvider.local) ...[
            const SizedBox(height: 12),
            TextFormField(
              initialValue: settings.embeddingApiUrl ?? '',
              decoration: const InputDecoration(
                labelText: 'API 地址',
                hintText: 'https://api.openai.com/v1',
                helperText: '留空则用 OpenAI 官方地址；中转站 embedding 定价可能虚高',
                border: OutlineInputBorder(),
              ),
              enabled: settings.enabled,
              onChanged: (v) => ref
                  .read(vectorStorageSettingsProvider.notifier)
                  .setEmbeddingApiUrl(v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: settings.embeddingApiKey ?? '',
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'API 密钥',
                hintText: 'sk-...',
                border: OutlineInputBorder(),
              ),
              enabled: settings.enabled,
              onChanged: (v) => ref
                  .read(vectorStorageSettingsProvider.notifier)
                  .setEmbeddingApiKey(v),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(DesignTokens.spaceMd),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.offline_bolt,
                          color: AppTheme.primaryColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '本地模型 · 离线免费',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '使用设备本地的 bge-small-zh 模型生成向量，无需 API、'
                    '不花费任何 token、聊天内容不出设备。首次使用会加载模型（约24MB），稍有延迟。',
                    style: TextStyle(fontSize: DesignTokens.fontSizeSm, height: 1.5),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '推荐配置（流畅运行）：\n'
                    '· 骁龙 8 Gen 1 / 870 及以上\n'
                    '· 天玑 8100 / 9000 及以上\n'
                    '· 三星 Exynos 2200 及以上\n'
                    '配置较低的设备仍可使用，但速度较慢、发热较明显。',
                    style: TextStyle(
                      fontSize: DesignTokens.fontSizeXs,
                      height: 1.5,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'KiraKira 致力于让每个人都能用上安全、免费的 AI 聊天体验。',
                    style: TextStyle(
                      fontSize: DesignTokens.fontSizeCaption,
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Divider(height: 32),

          // Prompt settings
          _buildSectionHeader(context, 'Prompt Integration'),
          const SizedBox(height: 8),
          KiraSwitchTile(
            title: '包含在提示词中',
            subtitle: '自动向 AI 提示词添加上下文',
            value: settings.includeInPrompt,
            onChanged: settings.enabled
                ? (value) {
                    ref.read(vectorStorageSettingsProvider.notifier).setIncludeInPrompt(value);
                  }
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
              initialValue: settings.promptTemplate,
              decoration: const InputDecoration(
                labelText: '提示词模板',
                hintText: '使用 {{context}} 表示检索内容',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
              enabled: settings.enabled && settings.includeInPrompt,
              onChanged: (value) {
                ref.read(vectorStorageSettingsProvider.notifier).setPromptTemplate(value);
              },
            ),

          const SizedBox(height: 32),
        ]),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.accentColor,
            fontWeight: FontWeight.bold,
          ),
    );
  }

  void _showHelpDialog(BuildContext context, VectorStorageService service) {
    // D-T2 规则 4:帮助 → 底部 Sheet(可滚)
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusBottomSheet),
        ),
      ),
      builder: (sheetCtx) => SafeArea(
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollCtrl) => Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(DesignTokens.spaceMd),
                child: Text(
                  '向量检索帮助',
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeHeadline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Divider(height: 0.5),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(DesignTokens.spaceMd),
                  child: Text(service.getHelpText()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(DesignTokens.spaceMd),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetCtx),
                    child: Text(AppLocalizations.of(context)!.close),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateCollectionDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final settings = ref.read(vectorStorageSettingsProvider);

    // D-T2:双字段表单 → 底部 Sheet(键盘顶起)
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
              const Text(
                '创建集合',
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeHeadline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: nameController,
                autofocus: true,
                placeholder: '集合名称',
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      Theme.of(sheetCtx).colorScheme.surfaceContainerHighest,
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusGroupedCard),
                ),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: descController,
                placeholder: '描述(可选)',
                maxLines: 2,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      Theme.of(sheetCtx).colorScheme.surfaceContainerHighest,
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusGroupedCard),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (nameController.text.trim().isNotEmpty) {
                      final collection = ref
                          .read(vectorCollectionsProvider.notifier)
                          .createCollection(
                            name: nameController.text.trim(),
                            description:
                                descController.text.trim().isEmpty
                                    ? null
                                    : descController.text.trim(),
                            dimensions: settings
                                .embeddingProvider.defaultDimensions,
                          );
                      ref
                          .read(vectorStorageSettingsProvider.notifier)
                          .setActiveCollection(collection.id);
                      Navigator.pop(sheetCtx);
                    }
                  },
                  child: const Text('创建'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteCollection(BuildContext context, WidgetRef ref, String id) {
    // D-T2 规则 1:破坏确认 → CupertinoAlertDialog
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('删除集合'),
        content: const Text('确定要删除此集合吗？此操作不可撤销。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              ref.read(vectorCollectionsProvider.notifier).deleteCollection(id);
              final settings = ref.read(vectorStorageSettingsProvider);
              if (settings.activeCollectionId == id) {
                ref.read(vectorStorageSettingsProvider.notifier).setActiveCollection(null);
              }
              Navigator.pop(dialogCtx);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _exportCollection(BuildContext context, WidgetRef ref, String id) {
    try {
      final json = ref.read(vectorCollectionsProvider.notifier).exportCollection(id);
      Clipboard.setData(ClipboardData(text: json));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('集合已导出到剪贴板')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  void _importCollection(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    // D-T2:JSON 多行导入 → 底部 Sheet
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
              const Text(
                '导入集合',
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeHeadline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: controller,
                placeholder: '粘贴集合 JSON',
                maxLines: 6,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      Theme.of(sheetCtx).colorScheme.surfaceContainerHighest,
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusGroupedCard),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    try {
                      ref
                          .read(vectorCollectionsProvider.notifier)
                          .importCollection(controller.text);
                      Navigator.pop(sheetCtx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('集合导入成功')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Import failed: $e')),
                      );
                    }
                  },
                  child: const Text('导入'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section for managing collections
class _CollectionsSection extends StatelessWidget {
  final List<VectorCollection> collections;
  final String? activeCollectionId;
  final bool enabled;
  final ValueChanged<String?> onCollectionSelected;
  final VoidCallback onCreateCollection;
  final ValueChanged<String> onDeleteCollection;
  final ValueChanged<String> onExportCollection;
  final VoidCallback onImportCollection;

  const _CollectionsSection({
    required this.collections,
    required this.activeCollectionId,
    required this.enabled,
    required this.onCollectionSelected,
    required this.onCreateCollection,
    required this.onDeleteCollection,
    required this.onExportCollection,
    required this.onImportCollection,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: collections.any((c) => c.id == activeCollectionId)
                    ? activeCollectionId
                    : null,
                decoration: const InputDecoration(
                  labelText: '活跃集合',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('无'),
                  ),
                  ...collections.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text('${c.name} (${c.documentCount} docs)'),
                      )),
                ],
                onChanged: enabled ? onCollectionSelected : null,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: enabled ? onCreateCollection : null,
              tooltip: '创建集合',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              enabled: enabled,
              onSelected: (action) {
                switch (action) {
                  case 'import':
                    onImportCollection();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'import',
                  child: ListTile(
                    leading: Icon(Icons.file_download),
                    title: Text('导入集合'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
        if (activeCollectionId != null &&
            collections.any((c) => c.id == activeCollectionId)) ...[
          const SizedBox(height: 8),
          _CollectionDetails(
            collectionId: activeCollectionId!,
            onExport: () => onExportCollection(activeCollectionId!),
            onDelete: () => onDeleteCollection(activeCollectionId!),
          ),
        ],
      ],
    );
  }
}

/// Details view for a collection
class _CollectionDetails extends ConsumerWidget {
  final String collectionId;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  const _CollectionDetails({
    required this.collectionId,
    required this.onExport,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(collectionStatisticsProvider(collectionId));
    final collections = ref.watch(vectorCollectionsProvider);
    final collection = collections.firstWhere(
      (c) => c.id == collectionId,
      orElse: () => VectorCollection.create(name: 'Unknown'),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  collection.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.file_upload, size: 20),
                      onPressed: onExport,
                      tooltip: 'Export',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: onDelete,
                      tooltip: 'Delete',
                      color: DesignTokens.statusError,
                    ),
                  ],
                ),
              ],
            ),
            if (collection.description != null) ...[
              const SizedBox(height: 4),
              Text(
                collection.description!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _StatChip(
                  icon: Icons.description,
                  label: '${stats.documentCount} docs',
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon: Icons.memory,
                  label: '${stats.embeddingCoveragePercent} embedded',
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon: Icons.text_fields,
                  label: '${stats.totalCharacters} chars',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('添加文档'),
                    onPressed: () => _showAddDocumentDialog(context, ref),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.list, size: 18),
                    label: const Text('查看文档'),
                    onPressed: () => _showDocumentsDialog(context, ref, collection),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDocumentDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    // D-T2:文档多行输入 → 底部 Sheet
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
              const Text(
                '添加文档',
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeHeadline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: controller,
                placeholder: '输入文档内容',
                maxLines: 6,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      Theme.of(sheetCtx).colorScheme.surfaceContainerHighest,
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusGroupedCard),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (controller.text.trim().isEmpty) return;
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(sheetCtx);
                    try {
                      await ref
                          .read(vectorCollectionsProvider.notifier)
                          .addDocument(
                            collectionId: collectionId,
                            content: controller.text.trim(),
                          );
                      navigator.pop();
                      messenger.showSnackBar(
                        const SnackBar(content: Text('文档已添加')),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('添加失败(检查Embedding配置): $e')),
                      );
                    }
                  },
                  child: const Text('添加'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDocumentsDialog(BuildContext context, WidgetRef ref, VectorCollection collection) {
    // D-T2 规则 5:文档列表 → 底部 Sheet(可滚)
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusBottomSheet),
        ),
      ),
      builder: (sheetCtx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetCtx).height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(DesignTokens.spaceMd),
                child: Text(
                  '文档 (${collection.documentCount})',
                  style: const TextStyle(
                    fontSize: DesignTokens.fontSizeHeadline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Divider(height: 0.5),
              Expanded(
                child: collection.documents.isEmpty
                    ? const Center(child: Text('没有文档'))
                    : ListView.builder(
                        itemCount: collection.documents.length,
                        itemBuilder: (context, index) {
                          final doc = collection.documents[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DesignTokens.spaceMd,
                              vertical: DesignTokens.spaceXs,
                            ),
                            child: Card(
                              child: ListTile(
                                title: Text(
                                  doc.content.length > 100
                                      ? '${doc.content.substring(0, 100)}...'
                                      : doc.content,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${doc.content.length} chars • ${doc.embedding != null ? "Embedded" : "Not embedded"}',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      size: 20,
                                      color: DesignTokens.statusError),
                                  onPressed: () {
                                    ref
                                        .read(vectorCollectionsProvider
                                            .notifier)
                                        .removeDocument(
                                          collectionId,
                                          doc.id,
                                        );
                                    Navigator.pop(sheetCtx);
                                    _showDocumentsDialog(
                                        context,
                                        ref,
                                        ref
                                            .read(vectorCollectionsProvider)
                                            .firstWhere(
                                                (c) => c.id == collectionId));
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(DesignTokens.spaceMd),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetCtx),
                    child: const Text('关闭'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small stat chip widget
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceSm, vertical: DesignTokens.spaceXs),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}