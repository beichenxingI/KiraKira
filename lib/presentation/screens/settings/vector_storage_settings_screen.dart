import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/models/vector_storage.dart';
import 'package:kirakira/domain/services/vector_storage_service.dart';
import 'package:kirakira/presentation/providers/vector_storage_providers.dart';
import 'package:kirakira/presentation/theme/app_theme.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';

/// Settings screen for Vector Storage / RAG
class VectorStorageSettingsScreen extends ConsumerWidget {
  const VectorStorageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(vectorStorageSettingsProvider);
    final collections = ref.watch(vectorCollectionsProvider);
    final service = ref.watch(vectorStorageServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.vectorStorageRag),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context, service),
            tooltip: '帮助',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Enable toggle
          SwitchListTile(
            title: const Text('启用 RAG'),
            subtitle: const Text('检索增强生成'),
            value: settings.enabled,
            onChanged: (value) {
              ref.read(vectorStorageSettingsProvider.notifier).setEnabled(value);
            },
          ),
          const Divider(height: 32),

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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
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
                    style: TextStyle(fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '推荐配置（流畅运行）：\n'
                    '· 骁龙 8 Gen 1 / 870 及以上\n'
                    '· 天玑 8100 / 9000 及以上\n'
                    '· 三星 Exynos 2200 及以上\n'
                    '配置较低的设备仍可使用，但速度较慢、发热较明显。',
                    style: TextStyle(
                      fontSize: 12,
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
                      fontSize: 11,
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
          SwitchListTile(
            title: const Text('包含在提示词中'),
            subtitle: const Text('自动向 AI 提示词添加上下文'),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('\u5411\u91cf\u68c0\u7d22\u5e2e\u52a9'),
        content: SingleChildScrollView(
          child: Text(service.getHelpText()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showCreateCollectionDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final settings = ref.read(vectorStorageSettingsProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建集合'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: '输入集合名称',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                final collection = ref.read(vectorCollectionsProvider.notifier).createCollection(
                  name: nameController.text.trim(),
                  description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                  dimensions: settings.embeddingProvider.defaultDimensions,
                );
                ref.read(vectorStorageSettingsProvider.notifier).setActiveCollection(collection.id);
                Navigator.pop(context);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCollection(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除集合'),
        content: const Text('确定要删除此集合吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(vectorCollectionsProvider.notifier).deleteCollection(id);
              final settings = ref.read(vectorStorageSettingsProvider);
              if (settings.activeCollectionId == id) {
                ref.read(vectorStorageSettingsProvider.notifier).setActiveCollection(null);
              }
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入集合'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'JSON',
            hintText: '在此粘贴集合 JSON',
          ),
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              try {
                ref.read(vectorCollectionsProvider.notifier).importCollection(controller.text);
                Navigator.pop(context);
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
        ],
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
        padding: const EdgeInsets.all(16),
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
                      color: Colors.red,
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加文档'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '内容',
            hintText: '输入文档内容',
          ),
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              try {
                await ref.read(vectorCollectionsProvider.notifier).addDocument(
                      collectionId: collectionId,
                      content: controller.text.trim(),
                    );
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('文档已添加')),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('添加失败（检查Embedding配置）: $e')),
                );
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showDocumentsDialog(BuildContext context, WidgetRef ref, VectorCollection collection) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('文档 (${collection.documentCount})'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: collection.documents.isEmpty
              ? const Center(child: Text('没有文档'))
              : ListView.builder(
                  itemCount: collection.documents.length,
                  itemBuilder: (context, index) {
                    final doc = collection.documents[index];
                    return Card(
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
                          icon: const Icon(Icons.delete, size: 20),
                          onPressed: () {
                            ref.read(vectorCollectionsProvider.notifier).removeDocument(
                              collectionId,
                              doc.id,
                            );
                            Navigator.pop(context);
                            _showDocumentsDialog(context, ref, 
                              ref.read(vectorCollectionsProvider).firstWhere((c) => c.id == collectionId));
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
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