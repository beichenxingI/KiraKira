import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:kirakira/data/models/chat.dart';
import 'package:kirakira/data/models/chronicle.dart' as models;
import 'package:kirakira/data/repositories/chronicle_repository.dart';
import 'package:kirakira/domain/services/embedding_service.dart';
import 'package:kirakira/domain/services/vector_storage_service.dart';
import 'package:kirakira/data/models/vector_storage.dart' as vs;

/// Hybrid recall result
class ChronicleRecallResult {
  /// Recall block text (empty means no recall)
  final String blockText;
  /// Topic shift signal (callers trigger summarization early based on this)
  final bool topicShift;
  /// IDs of recalled entries (for dedup/logging)
  final List<String> entryIds;

  const ChronicleRecallResult({
    this.blockText = '',
    this.topicShift = false,
    this.entryIds = const [],
  });
}

/// Wiki hybrid recall service.
///
/// Hybrid scoring: alpha * vector similarity (0.5) + beta * keyword overlap (0.2)
/// + gamma * time decay (0.1) + delta * emotion boost (0.1) + epsilon * importance (0.1).
/// Only searches documents with metadata.type='chronicle_entry' (kept separate from raw RAG text vectors).
/// Topic shift detection piggybacks on already-stored recent user message vectors, with zero extra embeddings.
class ChronicleRecallService {
  final ChronicleRepository _repo;
  final EmbeddingService _embedder;
  final VectorStorageService _vectorStorage;
  final vs.VectorStorageSettings Function() vectorSettingsGetter;

  /// Topic shift threshold: topic shifts when average similarity with recent user messages falls below this value
  static const double topicShiftThreshold = 0.45;

  ChronicleRecallService({
    required ChronicleRepository repo,
    required EmbeddingService embedder,
    required VectorStorageService vectorStorage,
    required this.vectorSettingsGetter,
  })  : _repo = repo,
        _embedder = embedder,
        _vectorStorage = vectorStorage;

  /// Recall, build the injection block, and detect topic shift in a single call.
  Future<ChronicleRecallResult> recallAndBuild({
    required String chatId,
    required String query,
    required List<ChatMessage> allMessages,
    int topK = 5,
    Set<String> excludeEntryIds = const {},
    int tokenBudget = 400, // Safety margin of 400 instead of 500
    bool emotionRecallEnabled = true,
  }) async {
    if (query.trim().isEmpty) return const ChronicleRecallResult();

    try {
      // Fast path: skip if the collection has no chronicle vectors (saves embedding calls)
      if (!_vectorStorage.hasDocumentsWithType(chatId, 'chronicle_entry')) {
        return const ChronicleRecallResult();
      }

      final settings = vectorSettingsGetter();
      final queryVec = await _embedder.generateEmbedding(query, settings);

      // Topic shift detection (piggybacks on stored message vectors)
      final topicShift =
          _detectTopicShift(chatId, query, queryVec, allMessages, settings);

      // Vector recall (chronicle_entry type only)
      final vectorResults = _vectorStorage.search(
        collectionId: chatId,
        queryEmbedding: queryVec,
        topK: topK * 3, // Fetch extra for reranking
        metadataFilter: {'type': 'chronicle_entry'},
      );
      if (vectorResults.isEmpty) {
        return ChronicleRecallResult(topicShift: topicShift);
      }

      // Fetch matching entries from the DB
      final entryIds = vectorResults
          .map((r) => r.document.metadata['entryId'] as String?)
          .whereType<String>()
          .toList();
      final entries = await _repo.getEntriesByIds(chatId, entryIds);
      if (entries.isEmpty) {
        return ChronicleRecallResult(topicShift: topicShift);
      }
      final entryById = {for (final e in entries) e.id: e};

      // Hybrid scoring
      final queryKeywords = extractKeywords(query);
      final currentTurn = allMessages.length;
      final activeEmotionIds = emotionRecallEnabled
          ? await _repo.getActiveEmotionEntityIds(chatId)
          : const <String>{};

      final scored = <_ScoredEntry>[];
      for (final vr in vectorResults) {
        final id = vr.document.metadata['entryId'] as String?;
        if (id == null) continue;
        final entry = entryById[id];
        if (entry == null || entry.deprecated) continue;
        if (excludeEntryIds.contains(entry.id)) continue; // Skip entries already injected

        final semanticScore = vr.similarity;
        final keywordScore =
            _keywordOverlap(entry.tags, queryKeywords);
        final timeScore = _timeDecay(entry.turnIndex, currentTurn);
        final emotionBoost = activeEmotionIds.any(
                (eid) => entry.entityIds.contains(eid))
            ? 1.0
            : 0.0;
        final importanceScore = entry.importance / 10.0;

        final total = 0.5 * semanticScore +
            0.2 * keywordScore +
            0.1 * timeScore +
            0.1 * emotionBoost +
            0.1 * importanceScore;

        scored.add(_ScoredEntry(entry: entry, score: total));
      }

      scored.sort((a, b) => b.score.compareTo(a.score));
      final picked = scored.take(topK).map((s) => s.entry).toList();
      if (picked.isEmpty) {
        return ChronicleRecallResult(topicShift: topicShift);
      }

      // Build the injection block (entry summaries plus related source excerpts)
      final budgetChars = (tokenBudget * 3.35).ceil();
      final buffer = StringBuffer();
      for (final entry in picked) {
        final block = _buildRecallBlock(entry, allMessages);
        if (buffer.isNotEmpty &&
            buffer.length + block.length + 2 > budgetChars) {
          break; // Stop once over budget (sorted by score descending, tail items are low-scoring)
        }
        if (buffer.isNotEmpty) buffer.write('\n\n');
        buffer.write(block);
      }

      return ChronicleRecallResult(
        blockText: buffer.toString(),
        topicShift: topicShift,
        entryIds: picked.map((e) => e.id).toList(),
      );
    } catch (e) {
      debugPrint('[CHRONICLE] 召回跳过（不影响对话）: $e');
      return const ChronicleRecallResult();
    }
  }

  // Topic shift detection

  /// Reuses recent user message vectors already stored by RAG (documentId=messageId)
  /// to compute average similarity with the current query.
  /// If vectors for the last user messages are missing (RAG disabled), piggybacking
  /// is impossible and it returns false to avoid false positives.
  bool _detectTopicShift(
    String chatId,
    String query,
    List<double> queryVec,
    List<ChatMessage> allMessages,
    vs.VectorStorageSettings settings,
  ) {
    try {
      final recentUserMsgs = allMessages.reversed
          .where((m) => m.role == MessageRole.user && !m.isHidden)
          .take(4)
          .toList();
      if (recentUserMsgs.length < 2) return false;

      // Exclude the current message (first in the list)
      final previous = recentUserMsgs.sublist(1).take(3).toList();
      if (previous.isEmpty) return false;

      var sum = 0.0;
      var count = 0;
      for (final msg in previous) {
        final doc = _vectorStorage.getDocument(chatId, msg.id);
        if (doc?.embedding == null) continue;
        sum += vs.VectorMath.cosineSimilarity(queryVec, doc!.embedding!);
        count++;
      }
      if (count == 0) return false;

      final avg = sum / count;
      final shifted = avg < topicShiftThreshold;
      if (shifted) {
        debugPrint('[CHRONICLE] 话题切换检测：avg相似度${avg.toStringAsFixed(2)} < $topicShiftThreshold');
      }
      return shifted;
    } catch (_) {
      return false;
    }
  }

  // Scoring components

  static double _timeDecay(int entryTurn, int currentTurn) {
    final delta = (currentTurn - entryTurn).clamp(0, 1 << 30);
    return math.exp(-0.05 * delta).clamp(0.0, 1.0);
  }

  static double _keywordOverlap(List<String> tags, List<String> queryKeywords) {
    if (tags.isEmpty || queryKeywords.isEmpty) return 0.0;
    final tagSet = tags.toSet();
    final inter =
        queryKeywords.where((k) => tagSet.contains(k)).length;
    return inter / math.max(tags.length, math.min(queryKeywords.length, 20));
  }

  /// Lightweight keyword extraction using Chinese bigrams and Latin words
  static List<String> extractKeywords(String text) {
    final tokens = <String>[];
    for (final m in RegExp(r'[a-zA-Z]{2,}').allMatches(text)) {
      tokens.add(m.group(0)!.toLowerCase());
    }
    for (final m in RegExp(r'[\u4e00-\u9fff]+').allMatches(text)) {
      final s = m.group(0)!;
      if (s.length == 1) {
        tokens.add(s);
        continue;
      }
      for (var i = 0; i < s.length - 1; i++) {
        tokens.add(s.substring(i, i + 2));
      }
    }
    return tokens;
  }

  // Injection block assembly

  /// Single-entry recall block: entry summary plus 1-2 related source excerpts, each truncated to 150 chars
  String _buildRecallBlock(models.MemoryEntry entry, List<ChatMessage> allMessages) {
    final buffer = StringBuffer();
    buffer.writeln('[Memory · ${entry.title}]');
    buffer.write(entry.content);

    if (entry.sourceMessageIds.isNotEmpty) {
      final related = allMessages
          .where((m) => entry.sourceMessageIds.contains(m.id))
          .take(2)
          .toList();
      for (final msg in related) {
        final role = msg.role == MessageRole.user ? '玩家' : '角色';
        final content = msg.content.length > 150
            ? '${msg.content.substring(0, 150)}...'
            : msg.content;
        buffer.write('\n[原文·$role] $content');
      }
    }

    return buffer.toString().trim();
  }
}

class _ScoredEntry {
  final models.MemoryEntry entry;
  final double score;
  const _ScoredEntry({required this.entry, required this.score});
}
