import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:kirakira/data/models/chat.dart';
import 'package:kirakira/data/models/chronicle.dart' as models;
import 'package:kirakira/data/repositories/chronicle_repository.dart';
import 'package:kirakira/domain/services/chat_summarization_service.dart';
import 'package:kirakira/domain/services/embedding_service.dart';
import 'package:kirakira/domain/services/llm_service.dart';
import 'package:kirakira/domain/services/vector_storage_service.dart';
import 'package:kirakira/data/models/vector_storage.dart' as vs;
import 'package:uuid/uuid.dart';

/// [CHRONICLE Phase 1] 超级记忆调度器。
///
/// 调整B：前台异步 Timer 轮询消费任务队列，**不使用后台isolate**——
/// database.dart:372 明确"后台isolate写DB会被OS杀导致写丢失"。
/// 所有 DB 读写都发生在主isolate；LLM调用/网络为IO等待不阻塞UI。
class ChronicleOrchestrator {
  final ChronicleRepository _repo;
  final ChatSummarizationService _summarizationService;
  final EmbeddingService _embedder;
  final VectorStorageService _vectorStorage;

  /// 运行时设置/LLM配置的只读getter（由Provider接线，避免orchestrator依赖Riverpod）
  final vs.VectorStorageSettings Function() vectorSettingsGetter;
  final LLMConfig Function() llmConfigGetter;

  Timer? _pollTimer;
  bool _processing = false; // 单飞守卫：Timer重入保护
  static const _uuid = Uuid();

  ChronicleOrchestrator({
    required ChronicleRepository repo,
    required ChatSummarizationService summarizationService,
    required EmbeddingService embedder,
    required VectorStorageService vectorStorage,
    required this.vectorSettingsGetter,
    required this.llmConfigGetter,
  })  : _repo = repo,
        _summarizationService = summarizationService,
        _embedder = embedder,
        _vectorStorage = vectorStorage {
    start();
  }

  /// 启动队列轮询（30s一次，幂等）
  void start() {
    _pollTimer ??= Timer.periodic(
      const Duration(seconds: 30),
      (_) => _processPendingTasks(),
    );
    // 启动时立即跑一轮，消化积压
    unawaited(_processPendingTasks());
  }

  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  // ═══════════════════ 触发检查（发消息后异步调用） ═══════════════════

  /// 检查触发条件并入队。返回 true=Chronicle已接管（调用方跳过旧总结路径）。
  Future<bool> checkAndEnqueue({
    required String chatId,
    required List<ChatMessage> messages,
    required LLMConfig llmConfig,
  }) async {
    try {
      final settings = await _repo.getSettings(chatId);
      if (!settings.enabled) return false;

      final archivedIds = await _repo.getArchivedMessageIds(chatId);
      final unarchived = messages
          .where((m) => !archivedIds.contains(m.id) && !m.isHidden)
          .toList();

      if (unarchived.isEmpty) return true; // 无可归档，但Chronicle已接管

      // 溢出热窗的消息（候选归档集）
      final overflowCount =
          (unarchived.length - settings.hotWindowSize).clamp(0, unarchived.length);

      bool triggerByTurns =
          overflowCount > 0 && unarchived.length >= settings.hotWindowSize + settings.summaryInterval;

      // token压力触发：热窗token ≥ 比例阈值 或 绝对上限（H7双触发）
      bool triggerByTokens = false;
      if (overflowCount > 0) {
        var hotTokens = 0;
        final hot = unarchived.sublist(unarchived.length - settings.hotWindowSize);
        for (final m in hot) {
          hotTokens += (m.content.length / 3.35).ceil();
        }
        triggerByTokens = hotTokens >= llmConfig.contextLength * 0.6 ||
            hotTokens >= ChatSummarizationService.absoluteTokenLimit;
      }

      if (!triggerByTurns && !triggerByTokens) return true; // 未达阈值，已接管

      // 待归档消息：溢出热窗的最早一批（调整A：messageId集合）
      final toArchive =
          unarchived.sublist(0, overflowCount).map((m) => m.id).toList();

      final enqueued = await _repo.enqueueSummaryTask(
        chatId: chatId,
        messageIds: toArchive,
        fromTurn: 0,
        toTurn: unarchived.length,
      );
      if (enqueued) {
        debugPrint('[CHRONICLE] 入队总结任务：${toArchive.length}条消息 '
            '(turns触发=$triggerByTurns, tokens触发=$triggerByTokens)');
      }
      return true;
    } catch (e) {
      debugPrint('[CHRONICLE] checkAndEnqueue 失败（不影响对话）: $e');
      return false; // 失败回落旧路径
    }
  }

  // ═══════════════════ 队列消费 ═══════════════════

  Future<void> _processPendingTasks() async {
    if (_processing) return; // 单飞
    _processing = true;
    try {
      final tasks = await _repo.getPendingTasks(limit: 1);
      if (tasks.isEmpty) return;

      final task = tasks.first;
      await _repo.updateTaskStatus(task.id, 'running');

      try {
        final messageIds = _parseIds(task.messageIds);
        final messages =
            await _repo.getMessagesByIds(task.chatId, messageIds);
        if (messages.isEmpty) {
          await _repo.updateTaskStatus(task.id, 'done',
              error: '消息不存在（可能已删除）');
          return;
        }

        // 1. 生成总结（Phase 1: 纯文本；Phase 2升级为结构化JSON抽取）
        final config = llmConfigGetter();
        final summaryConfig = config.copyWith(
          temperature: 0.2,
          maxTokens: 16384,
          model: config.summaryModel.isNotEmpty
              ? config.summaryModel
              : config.model,
        );
        final summaryText = await _generatePlainTextSummary(
          messages: messages,
          config: summaryConfig,
        );

        // 2. 写入Wiki词条
        final entry = models.MemoryEntry(
          id: _uuid.v4(),
          chatId: task.chatId,
          type: models.MemoryEntryType.event,
          title: _deriveTitle(summaryText, messages),
          content: summaryText,
          importance: 5,
          alwaysInject: true, // Phase 1纯文本总结：默认始终注入（Phase 2结构化后由LLM/用户决定）
          tags: const [],
          sourceMessageIds: messageIds,
          turnIndex: task.toTurn,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _repo.upsertMemoryEntry(entry);

        // 3. 向量化入库（失败只跳过，不阻断）
        await _vectorizeEntry(entry);

        // 4. 标记归档 + 任务完成
        await _repo.markMessagesArchived(task.chatId, messageIds);
        await _repo.updateTaskStatus(task.id, 'done', resultJson: summaryText);

        debugPrint('[CHRONICLE] 总结任务完成：${messageIds.length}条消息归档，'
            '词条=${entry.title}');
      } catch (e, st) {
        debugPrint('[CHRONICLE] 总结任务失败: $e\n$st');
        await _repo.updateTaskStatus(task.id, 'failed', error: e.toString());
      }
    } catch (e) {
      debugPrint('[CHRONICLE] 队列消费异常: $e');
    } finally {
      _processing = false;
    }
  }

  /// Phase 1 降级总结：复用现有总结服务（纯文本，与旧系统同等质量）
  Future<String> _generatePlainTextSummary({
    required List<ChatMessage> messages,
    required LLMConfig config,
  }) async {
    final summary = await _summarizationService.generateSummary(
      messages: messages,
      existingSummaries: const [],
      config: config,
    );
    return summary.content;
  }

  /// 词条向量化：embed后写入本聊天向量集合，documentId='chronicle_<entryId>'。
  /// metadata.type='chronicle_entry' 与RAG原文向量共存（调整D）。
  Future<void> _vectorizeEntry(models.MemoryEntry entry) async {
    try {
      final vsSettings = vectorSettingsGetter();
      final collection = _vectorStorage.getCollection(entry.chatId);
      if (collection == null) return; // 集合未建（RAG未开），跳过

      final vector =
          await _embedder.generateEmbedding(entry.vectorText, vsSettings);
      final docId = 'chronicle_${entry.id}';
      await Future.sync(() => _vectorStorage.addDocumentWithId(
            collectionId: entry.chatId,
            documentId: docId,
            content: entry.vectorText,
            embedding: vector,
            metadata: {
              'type': 'chronicle_entry',
              'entryId': entry.id,
              'entryType': entry.type.name,
              'importance': entry.importance,
              'turnIndex': entry.turnIndex,
              'entityIds': entry.entityIds,
              'tags': entry.tags,
            },
          ));
      // 回写vectorId（下次更新时覆盖同id向量）
      await _repo.upsertMemoryEntry(entry.copyWith(vectorId: docId));
    } catch (e) {
      debugPrint('[CHRONICLE] 词条向量化跳过（不影响流程）: $e');
    }
  }

  // ═══════════════════ 旧摘要迁移（一次性） ═══════════════════

  /// 旧 ChatSummary → Chronicle 初始词条。幂等：已有词条的聊天跳过。
  Future<void> migrateOldSummaries(Chat chat) async {
    try {
      if (chat.summaries.isEmpty) return;
      if (await _repo.hasChronicleEntries(chat.id)) return;

      for (final summary in chat.summaries) {
        final content = summary.content.length > 300
            ? '${summary.content.substring(0, 300)}...'
            : summary.content;
        final entry = models.MemoryEntry(
          id: _uuid.v4(),
          chatId: chat.id,
          type: models.MemoryEntryType.event,
          title: '历史总结（迁移自旧版）',
          content: content,
          importance: 7,
          alwaysInject: true, // 旧总结默认始终注入
          anchor: false,
          tags: const [],
          sourceMessageIds: const [],
          turnIndex: summary.endMessageIndex,
          createdAt: summary.createdAt,
          updatedAt: DateTime.now(),
        );
        await _repo.upsertMemoryEntry(entry);
      }
      debugPrint('[CHRONICLE] 旧摘要迁移完成：${chat.summaries.length}条 → 词条');
    } catch (e) {
      debugPrint('[CHRONICLE] 旧摘要迁移失败（不影响聊天）: $e');
    }
  }

  // ═══════════════════ 工具 ═══════════════════

  static List<String> _parseIds(String json) {
    try {
      final list = jsonDecode(json) as List;
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return const [];
    }
  }

  static String _deriveTitle(String summaryText, List<ChatMessage> messages) {
    final firstLine = summaryText.split('\n').firstWhere(
      (l) => l.trim().isNotEmpty,
      orElse: () => '',
    );
    final t = firstLine.trim().replaceAll(RegExp(r'^[#\-*、\s]+'), '');
    return t.length > 30 ? '${t.substring(0, 30)}...' : (t.isEmpty ? '剧情进展' : t);
  }
}
