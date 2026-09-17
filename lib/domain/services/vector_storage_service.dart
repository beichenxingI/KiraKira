import 'dart:async';
import 'dart:convert';
import 'package:kirakira/data/models/vector_storage.dart';
import 'package:kirakira/data/database/database.dart' as db;
import 'package:drift/drift.dart' show Value;

/// Service for vector storage and RAG operations
/// 混合存储：内存 Map 为运行时数据源（读同步），写操作异步持久化到数据库。
class VectorStorageService {
  final db.AppDatabase _db;
  VectorStorageService(this._db);

  /// In-memory storage for collections
  final Map<String, VectorCollection> _collections = {};

  /// 启动时从数据库加载所有集合与文档到内存
  Future<void> load() async {
    try {
      final cols = await _db.select(_db.vectorCollections).get();
      final docs = await _db.select(_db.vectorDocuments).get();
      final docsByCol = <String, List<VectorDocument>>{};
      for (final d in docs) {
        final rawEmb = jsonDecode(d.embedding) as List<dynamic>;
        final emb = rawEmb.map((e) => (e as num).toDouble()).toList();
        docsByCol.putIfAbsent(d.collectionId, () => []).add(VectorDocument(
              id: d.id,
              content: d.content,
              embedding: emb.isEmpty ? null : emb,
              metadata: jsonDecode(d.metadataJson) as Map<String, dynamic>,
              createdAt: d.createdAt,
            ));
      }
      _collections.clear();
      for (final c in cols) {
        _collections[c.id] = VectorCollection(
          id: c.id,
          name: c.name,
          description: c.description,
          dimensions: c.dimensions,
          documents: docsByCol[c.id] ?? [],
          createdAt: c.createdAt,
          updatedAt: c.createdAt,
        );
      }
    } catch (e) {
      // 加载失败保持空内存，不阻断
    }
  }

  // ── 持久化辅助（异步，不阻塞调用方）──
  void _persistCollection(VectorCollection c) {
    unawaited(_db.into(_db.vectorCollections).insertOnConflictUpdate(
          db.VectorCollectionsCompanion.insert(
            id: c.id,
            name: c.name,
            description: Value(c.description),
            dimensions: Value(c.dimensions),
            createdAt: Value(c.createdAt),
          ),
        ));
  }

  void _persistDocument(String collectionId, VectorDocument d) {
    unawaited(_db.into(_db.vectorDocuments).insertOnConflictUpdate(
          db.VectorDocumentsCompanion.insert(
            id: d.id,
            collectionId: collectionId,
            content: d.content,
            embedding: Value(jsonEncode(d.embedding ?? [])),
            metadataJson: Value(jsonEncode(d.metadata)),
            createdAt: Value(d.createdAt),
          ),
        ));
  }

  void _deleteCollectionRows(String collectionId) {
    unawaited((_db.delete(_db.vectorDocuments)
          ..where((t) => t.collectionId.equals(collectionId)))
        .go());
    unawaited((_db.delete(_db.vectorCollections)
          ..where((t) => t.id.equals(collectionId)))
        .go());
  }

  void _deleteDocumentRow(String documentId) {
    unawaited((_db.delete(_db.vectorDocuments)
          ..where((t) => t.id.equals(documentId)))
        .go());
  }

  /// Get all collections
  List<VectorCollection> get collections => _collections.values.toList();

  /// Get a collection by ID
  VectorCollection? getCollection(String id) => _collections[id];

  /// Create a new collection
  VectorCollection createCollection({
    required String name,
    String? description,
    int dimensions = 1536,
  }) {
    final collection = VectorCollection.create(
      name: name,
      description: description,
      dimensions: dimensions,
    );
    _collections[collection.id] = collection;
    _persistCollection(collection);
    return collection;
  }

  /// Create a collection with a fixed id (用于按 chatId 绑定)
  VectorCollection createCollectionWithId({
    required String id,
    required String name,
    String? description,
    int dimensions = 384, // [CHRONICLE Phase 0] 512→384：本地bge-small-zh实际输出384维
  }) {
    final now = DateTime.now();
    final collection = VectorCollection(
      id: id,
      name: name,
      description: description,
      dimensions: dimensions,
      documents: const [],
      createdAt: now,
      updatedAt: now,
    );
    _collections[id] = collection;
    _persistCollection(collection);
    return collection;
  }

  /// Update a collection
  void updateCollection(VectorCollection collection) {
    _collections[collection.id] = collection;
    _persistCollection(collection);
  }

  /// Delete a collection
  void deleteCollection(String id) {
    _collections.remove(id);
    _deleteCollectionRows(id);
  }

  /// Add a document to a collection
  VectorDocument addDocument({
    required String collectionId,
    required String content,
    List<double>? embedding,
    Map<String, dynamic>? metadata,
  }) {
    final collection = _collections[collectionId];
    if (collection == null) {
      throw Exception('Collection not found: $collectionId');
    }

    final document = VectorDocument.create(
      content: content,
      embedding: embedding,
      metadata: metadata,
    );

    final updatedCollection = collection.copyWith(
      documents: [...collection.documents, document],
    );
    _collections[collectionId] = updatedCollection;
    _persistDocument(collectionId, document);

    return document;
  }
  /// 按指定 id 入库（id 用 messageId）。先删旧再插新 → 同一消息幂等，
  /// swipe/重生成/编辑多少次，向量库里始终只保留最新一条，不堆积。
  VectorDocument addDocumentWithId({
    required String collectionId,
    required String documentId,
    required String content,
    List<double>? embedding,
    Map<String, dynamic>? metadata,
  }) {
    final collection = _collections[collectionId];
    if (collection == null) {
      throw Exception('Collection not found: $collectionId');
    }
    // 先移除同 id 旧文档（内存）
    final pruned =
        collection.documents.where((d) => d.id != documentId).toList();
    final document = VectorDocument(
      id: documentId,
      content: content,
      embedding: embedding,
      metadata: metadata ?? {},
      createdAt: DateTime.now(),
    );
    _collections[collectionId] =
        collection.copyWith(documents: [...pruned, document]);
    // 库层 insertOnConflictUpdate 会按主键覆盖，无需先删
    _persistDocument(collectionId, document);
    return document;
  }

  /// 按 documentId(=messageId) 删除向量，跨所有集合。删单条消息时用。
  void removeDocumentById(String documentId) {
    for (final entry in _collections.entries.toList()) {
      final col = entry.value;
      if (col.documents.any((d) => d.id == documentId)) {
        _collections[entry.key] = col.copyWith(
          documents: col.documents.where((d) => d.id != documentId).toList(),
        );
      }
    }
    _deleteDocumentRow(documentId);
  }

  /// Add multiple documents to a collection
  List<VectorDocument> addDocuments({
    required String collectionId,
    required List<String> contents,
    List<List<double>>? embeddings,
    List<Map<String, dynamic>>? metadataList,
  }) {
    final documents = <VectorDocument>[];
    for (int i = 0; i < contents.length; i++) {
      final doc = addDocument(
        collectionId: collectionId,
        content: contents[i],
        embedding: embeddings != null && i < embeddings.length ? embeddings[i] : null,
        metadata: metadataList != null && i < metadataList.length ? metadataList[i] : null,
      );
      documents.add(doc);
    }
    return documents;
  }

  /// Remove a document from a collection
  void removeDocument(String collectionId, String documentId) {
    final collection = _collections[collectionId];
    if (collection == null) return;

    final updatedDocuments = collection.documents
        .where((d) => d.id != documentId)
        .toList();

    _collections[collectionId] = collection.copyWith(documents: updatedDocuments);
    _deleteDocumentRow(documentId);
  }

  /// Update document embedding
  void updateDocumentEmbedding(
    String collectionId,
    String documentId,
    List<double> embedding,
  ) {
    final collection = _collections[collectionId];
    if (collection == null) return;

    final updatedDocuments = collection.documents.map((d) {
      if (d.id == documentId) {
        return d.copyWith(embedding: embedding);
      }
      return d;
    }).toList();

    _collections[collectionId] = collection.copyWith(documents: updatedDocuments);
    final updated = updatedDocuments.firstWhere((d) => d.id == documentId);
    _persistDocument(collectionId, updated);
  }

  /// Search for similar documents
  List<VectorSearchResult> search({
    required String collectionId,
    required List<double> queryEmbedding,
    int topK = 5,
    double? similarityThreshold,
    /// [CHRONICLE Phase 3] metadata精确匹配过滤（null=不过滤，搜全部）
    Map<String, dynamic>? metadataFilter,
  }) {
    final collection = _collections[collectionId];
    if (collection == null) return [];

    final results = <VectorSearchResult>[];

    for (final document in collection.documents) {
      if (document.embedding == null) continue;

      // [CHRONICLE Phase 3] metadata过滤：所有键值都匹配才保留
      if (metadataFilter != null) {
        var matched = true;
        for (final entry in metadataFilter.entries) {
          if (document.metadata[entry.key] != entry.value) {
            matched = false;
            break;
          }
        }
        if (!matched) continue;
      }

      final similarity = VectorMath.cosineSimilarity(
        queryEmbedding,
        document.embedding!,
      );

      if (similarityThreshold != null && similarity < similarityThreshold) {
        continue;
      }

      results.add(VectorSearchResult(
        document: document,
        similarity: similarity,
        distance: 1 - similarity,
      ));
    }

    // Sort by similarity (highest first)
    results.sort((a, b) => b.similarity.compareTo(a.similarity));

    return results.take(topK).toList();
  }

  /// [CHRONICLE Phase 3] 按文档id取单个文档（话题切换检测复用已入库的消息向量）
  VectorDocument? getDocument(String collectionId, String documentId) {
    final collection = _collections[collectionId];
    if (collection == null) return null;
    for (final d in collection.documents) {
      if (d.id == documentId) return d;
    }
    return null;
  }

  /// [CHRONICLE Phase 3] 判断集合内是否存在指定metadata类型的文档
  bool hasDocumentsWithType(String collectionId, String type) {
    final collection = _collections[collectionId];
    if (collection == null) return false;
    return collection.documents.any((d) => d.metadata['type'] == type);
  }

  /// Chunk text into smaller pieces
  List<String> chunkText(String text, ChunkingOptions options) {
    switch (options.strategy) {
      case ChunkingStrategy.fixedSize:
        return _chunkByFixedSize(text, options.chunkSize, options.chunkOverlap);
      case ChunkingStrategy.sentence:
        return _chunkBySentence(text, options.chunkSize);
      case ChunkingStrategy.paragraph:
        return _chunkByParagraph(text);
      case ChunkingStrategy.semantic:
        // Semantic chunking would require more sophisticated NLP
        // Fall back to sentence chunking
        return _chunkBySentence(text, options.chunkSize);
    }
  }

  List<String> _chunkByFixedSize(String text, int chunkSize, int overlap) {
    final chunks = <String>[];
    int start = 0;

    while (start < text.length) {
      int end = start + chunkSize;
      if (end > text.length) end = text.length;

      // Try to break at word boundary
      if (end < text.length) {
        final lastSpace = text.lastIndexOf(' ', end);
        if (lastSpace > start) {
          end = lastSpace;
        }
      }

      chunks.add(text.substring(start, end).trim());
      start = end - overlap;
      if (start < 0) start = 0;
      if (start >= text.length) break;
    }

    return chunks.where((c) => c.isNotEmpty).toList();
  }

  List<String> _chunkBySentence(String text, int maxChunkSize) {
    // Simple sentence splitting
    final sentencePattern = RegExp(r'[.!?]+\s+');
    final sentences = text.split(sentencePattern);
    
    final chunks = <String>[];
    var currentChunk = StringBuffer();

    for (final sentence in sentences) {
      if (currentChunk.length + sentence.length > maxChunkSize && currentChunk.isNotEmpty) {
        chunks.add(currentChunk.toString().trim());
        currentChunk = StringBuffer();
      }
      currentChunk.write('$sentence. ');
    }

    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk.toString().trim());
    }

    return chunks.where((c) => c.isNotEmpty).toList();
  }

  List<String> _chunkByParagraph(String text) {
    return text
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
  }

  /// Generate context string from search results
  String generateContext(
    List<VectorSearchResult> results, {
    String separator = '\n\n---\n\n',
    int? maxLength,
  }) {
    final buffer = StringBuffer();
    
    for (int i = 0; i < results.length; i++) {
      if (i > 0) buffer.write(separator);
      
      final content = results[i].document.content;
      if (maxLength != null && buffer.length + content.length > maxLength) {
        // Truncate if exceeding max length
        final remaining = maxLength - buffer.length;
        if (remaining > 100) {
          buffer.write(content.substring(0, remaining - 3));
          buffer.write('...');
        }
        break;
      }
      
      buffer.write(content);
    }

    return buffer.toString();
  }

  /// Format context using template
  String formatContextWithTemplate(
    List<VectorSearchResult> results,
    String template,
  ) {
    final context = generateContext(results);
    return template.replaceAll('{{context}}', context);
  }

  /// Export collection to JSON
  String exportCollection(String collectionId) {
    final collection = _collections[collectionId];
    if (collection == null) {
      throw Exception('Collection not found');
    }
    return const JsonEncoder.withIndent('  ').convert(collection.toJson());
  }

  /// Import collection from JSON
  VectorCollection importCollection(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final collection = VectorCollection.fromJson(data);
    _collections[collection.id] = collection;
    _persistCollection(collection);
    for (final d in collection.documents) {
      _persistDocument(collection.id, d);
    }
    return collection;
  }

  /// Get statistics for a collection
  CollectionStatistics getStatistics(String collectionId) {
    final collection = _collections[collectionId];
    if (collection == null) {
      return const CollectionStatistics(
        documentCount: 0,
        embeddedCount: 0,
        totalCharacters: 0,
        avgDocumentLength: 0,
      );
    }

    int embeddedCount = 0;
    int totalChars = 0;

    for (final doc in collection.documents) {
      if (doc.embedding != null) embeddedCount++;
      totalChars += doc.content.length;
    }

    return CollectionStatistics(
      documentCount: collection.documentCount,
      embeddedCount: embeddedCount,
      totalCharacters: totalChars,
      avgDocumentLength: collection.documentCount > 0
          ? totalChars / collection.documentCount
          : 0,
    );
  }

  /// Clear all collections
  void clearAll() {
    _collections.clear();
    unawaited((_db.delete(_db.vectorDocuments)).go());
    unawaited((_db.delete(_db.vectorCollections)).go());
  }

  /// Get help text
  String getHelpText() {
    return '''
**Vector Storage / RAG** (Retrieval-Augmented Generation) enhances AI responses with relevant context from your knowledge base.

**How it works:**
1. **Add documents** to a collection
2. **Generate embeddings** for each document
3. **Search** for relevant documents based on your query
4. **Inject context** into the AI prompt

**Key Concepts:**
- **Embeddings**: Numerical representations of text that capture meaning
- **Similarity**: How closely two pieces of text relate
- **Chunking**: Breaking large documents into smaller pieces

**Use Cases:**
- Character lore and backstory
- World-building information
- Reference documents
- FAQ and knowledge bases

**Tips:**
- Keep chunks focused on single topics
- Use descriptive metadata for filtering
- Adjust similarity threshold based on results
- Higher topK = more context but more tokens
''';
  }
}

/// Statistics for a collection
class CollectionStatistics {
  final int documentCount;
  final int embeddedCount;
  final int totalCharacters;
  final double avgDocumentLength;

  const CollectionStatistics({
    required this.documentCount,
    required this.embeddedCount,
    required this.totalCharacters,
    required this.avgDocumentLength,
  });

  double get embeddingCoverage {
    if (documentCount == 0) return 0;
    return embeddedCount / documentCount;
  }

  String get embeddingCoveragePercent => '${(embeddingCoverage * 100).toStringAsFixed(1)}%';
}