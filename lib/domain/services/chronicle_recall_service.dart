import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:kirakira/data/models/chat.dart';
import 'package:kirakira/data/models/chronicle.dart' as models;
import 'package:kirakira/data/repositories/chronicle_repository.dart';
import 'package:kirakira/domain/services/embedding_service.dart';
import 'package:kirakira/domain/services/vector_storage_service.dart';
import 'package:kirakira/data/models/vector_storage.dart' as vs;

/// [CHRONICLE Phase 3] 混合召回结果
class ChronicleRecallResult {
  /// 召回块文本（空=无召回）
  final String blockText;
  /// 话题切换信号（调用方据此提前触发总结）
  final bool topicShift;
  /// 召回的词条id（去重/日志用）
  final List<String> entryIds;

  const ChronicleRecallResult({
    this.blockText = '',
    this.topicShift = false,
    this.entryIds = const [],
  });
}

/// [CHRONICLE Phase 3] Wiki混合召回服务。
///
/// 混合打分：α·向量相似度(0.5) + β·关键词重合(0.2) + γ·时间衰减(0.1)
///         + δ·情感加成(0.1) + ε·重要度(0.1)。
/// 只搜 metadata.type='chronicle_entry' 的文档（调整D：与RAG原文向量共存分流）。
/// 话题切换检测搭便车：复用已入库的近期user消息向量，零额外embedding。
class ChronicleRecallService {
  final ChronicleRepository _repo;
  final EmbeddingService _embedder;
  final VectorStorageService _vectorStorage;
  final vs.VectorStorageSettings Function() vectorSettingsGetter;

  /// 话题切换判定阈值：与近期user消息平均相似度低于此值 → 切换
  static const double topicShiftThreshold = 0.45;

  ChronicleRecallService({
    required ChronicleRepository repo,
    required EmbeddingService embedder,
    required VectorStorageService vectorStorage,
    required this.vectorSettingsGetter,
  })  : _repo = repo,
        _embedder = embedder,
        _vectorStorage = vectorStorage;

  /// 召回 + 组装注入块 + 话题切换检测（一次调用全完成）。
  Future<ChronicleRecallResult> recallAndBuild({
    required String chatId,
    required String query,
    required List<ChatMessage> allMessages,
    int topK = 5,
    Set<String> excludeEntryIds = const {},
    int tokenBudget = 400, // 调整E：安全裕度400而非500
    bool emotionRecallEnabled = true,
  }) async {
    if (query.trim().isEmpty) return const ChronicleRecallResult();

    try {
      // 快路径：集合无chronicle向量则跳过（省embedding调用）
      if (!_vectorStorage.hasDocumentsWithType(chatId, 'chronicle_entry')) {
        return const ChronicleRecallResult();
      }

      final settings = vectorSettingsGetter();
      final queryVec = await _embedder.generateEmbedding(query, settings);

      // ── 话题切换检测（搭便车：复用已入库消息向量） ──
      final topicShift =
          _detectTopicShift(chatId, query, queryVec, allMessages, settings);

      // ── 向量召回（只取chronicle_entry类型） ──
      final vectorResults = _vectorStorage.search(
        collectionId: chatId,
        queryEmbedding: queryVec,
        topK: topK * 3, // 多取重排
        metadataFilter: {'type': 'chronicle_entry'},
      );
      if (vectorResults.isEmpty) {
        return ChronicleRecallResult(topicShift: topicShift);
      }

      // ── 从DB取对应词条 ──
      final entryIds = vectorResults
          .map((r) => r.document.metadata['entryId'] as String?)
          .whereType<String>()
          .toList();
      final entries = await _repo.getEntriesByIds(chatId, entryIds);
      if (entries.isEmpty) {
        return ChronicleRecallResult(topicShift: topicShift);
      }
      final entryById = {for (final e in entries) e.id: e};

      // ── 混合打分 ──
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
        if (excludeEntryIds.contains(entry.id)) continue; // H6：F-6已注入的跳过

        final semanticScore = vr.similarity; // α
        final keywordScore =
            _keywordOverlap(entry.tags, queryKeywords); // β
        final timeScore = _timeDecay(entry.turnIndex, currentTurn); // γ
        final emotionBoost = activeEmotionIds.any(
                (eid) => entry.entityIds.contains(eid))
            ? 1.0
            : 0.0; // δ
        final importanceScore = entry.importance / 10.0; // ε

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

      // ── 组装注入块（词条摘要 + 关联原文夹带） ──
      final budgetChars = (tokenBudget * 3.35).ceil();
      final buffer = StringBuffer();
      for (final entry in picked) {
        final block = _buildRecallBlock(entry, allMessages);
        if (buffer.isNotEmpty &&
            buffer.length + block.length + 2 > budgetChars) {
          break; // 超预算即停（已按分数降序，尾部是低分）
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

  // ═══════════════════ 话题切换检测 ═══════════════════

  /// 复用RAG已入库的近期user消息向量（documentId=messageId），算与当前query的平均相似度。
  /// 近3条user消息向量有缺失（未开RAG）→ 无法搭便车，返回false（不误判）。
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

      // 排除当前这条（列表第一个是当前消息）
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

  // ═══════════════════ 打分组件 ═══════════════════

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

  /// 中文bigram + 拉丁词 的轻量关键词抽取
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

  // ═══════════════════ 注入块组装 ═══════════════════

  /// 单词条召回块：词条摘要 + 关联原文夹带（1-2条，各截150字）
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
