import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:kirakira/data/models/chat.dart';
import 'package:kirakira/data/models/chronicle.dart' as models;
import 'package:kirakira/data/repositories/chronicle_repository.dart';
import 'package:kirakira/domain/services/chat_summarization_service.dart';
import 'package:kirakira/domain/services/chronicle_summary_service.dart';
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
  final ChronicleSummaryService _chronicleSummaryService;
  final EmbeddingService _embedder;
  final VectorStorageService _vectorStorage;

  /// 运行时设置/LLM配置的只读getter（由Provider接线，避免orchestrator依赖Riverpod）
  final vs.VectorStorageSettings Function() vectorSettingsGetter;
  final LLMConfig Function() llmConfigGetter;
  final models.ChronicleSettings Function() settingsGetter;

  Timer? _pollTimer;
  bool _processing = false; // 单飞守卫：Timer重入保护
  static const _uuid = Uuid();

  ChronicleOrchestrator({
    required ChronicleRepository repo,
    required ChatSummarizationService summarizationService,
    required ChronicleSummaryService chronicleSummaryService,
    required EmbeddingService embedder,
    required VectorStorageService vectorStorage,
    required this.vectorSettingsGetter,
    required this.llmConfigGetter,
    required this.settingsGetter,
  })  : _repo = repo,
        _summarizationService = summarizationService,
        _chronicleSummaryService = chronicleSummaryService,
        _embedder = embedder,
        _vectorStorage = vectorStorage {
    start();
  }

  /// 启动队列轮询（30s一次，幂等）
  void start() {
    // 启动时重置僵尸任务（app被杀后running任务永远卡住队列）
    unawaited(_repo.resetStuckRunningTasks());
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
  /// force=true（Wiki面板手动整理）：跳过轮次/token阈值与失败退避，立即入队。
  Future<bool> checkAndEnqueue({
    required String chatId,
    required List<ChatMessage> messages,
    required LLMConfig llmConfig,
    bool force = false,
  }) async {
    try {
      final settings = settingsGetter();
      if (!settings.enabled) return false;

      final archivedIds = await _repo.getArchivedMessageIds(chatId);
      final unarchived = messages
          .where((m) => !archivedIds.contains(m.id) && !m.isHidden)
          .toList();

      if (unarchived.isEmpty) return true; // 无可归档，但Chronicle已接管

      // 溢出热窗的消息（候选归档集）
      final overflowCount =
          (unarchived.length - settings.hotWindowSize).clamp(0, unarchived.length);

      // 按轮次（user消息数）计，1 user + 1 assistant = 1轮；summaryInterval单位=轮
      final overflowUserTurns = overflowCount > 0
          ? unarchived.sublist(0, overflowCount).where((m) => m.role == MessageRole.user).length
          : 0;
      bool triggerByTurns = overflowUserTurns >= settings.summaryInterval;

      // token压力触发：热窗token ≥ 比例阈值 或 绝对上限（H7双触发）
      bool triggerByTokens = false;
      if (overflowCount > 0) {
        var hotTokens = 0;
        final hot = unarchived.sublist(unarchived.length - settings.hotWindowSize);
        for (final m in hot) {
          hotTokens += (m.content.length / 3.35).ceil();
        }
        triggerByTokens = hotTokens >= llmConfig.contextLength * settings.tokenPressureThreshold ||
            hotTokens >= ChatSummarizationService.absoluteTokenLimit;
      }

      if (!force && !triggerByTurns && !triggerByTokens) return true; // 未达阈值，已接管

      // 待归档消息：溢出热窗的最早一批（调整A：messageId集合）
      final toArchive =
          unarchived.sublist(0, overflowCount).map((m) => m.id).toList();

      // 失败任务退避：超过最大重试次数停止入队，等待用户手动干预（force跳过）
      if (!force) {
        final failedCount = await _repo.getFailedTaskCountForChat(chatId);
        if (failedCount >= settings.maxRetries) {
          debugPrint('[CHRONICLE] 已达最大重试次数($failedCount)，停止入队');
          return true;
        }
      }

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

  /// [Phase 3] 话题切换触发：提前压缩溢出热窗的消息（不管轮次阈值）。
  /// 由召回服务检测到话题切换后异步调用，绝不阻塞对话。
  Future<void> onTopicShift(
      String chatId, List<ChatMessage> messages) async {
    try {
      final settings = settingsGetter();
      if (!settings.enabled) return;
      if (await _repo.hasActiveTaskForChat(chatId)) return; // 已有任务，不重复入队

      final archivedIds = await _repo.getArchivedMessageIds(chatId);
      final unarchived = messages
          .where((m) => !archivedIds.contains(m.id) && !m.isHidden)
          .toList();
      final overflowCount =
          (unarchived.length - settings.hotWindowSize).clamp(0, unarchived.length);
      if (overflowCount <= 0) return; // 热窗未满，无需压缩

      final toArchive =
          unarchived.sublist(0, overflowCount).map((m) => m.id).toList();
      final ok = await _repo.enqueueSummaryTask(
        chatId: chatId,
        messageIds: toArchive,
        fromTurn: 0,
        toTurn: unarchived.length,
      );
      if (ok) {
        debugPrint('[CHRONICLE] 话题切换触发提前总结：${toArchive.length}条消息');
      }
    } catch (e) {
      debugPrint('[CHRONICLE] 话题切换处理失败（不影响对话）: $e');
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

        final settings = settingsGetter();
        final config = llmConfigGetter();
        // [修改三] Chronicle 专属总结模型：三项配置任一非空 → 走专属 openAICompatible
        // 全空则沿用主对话模型（兼容旧 summaryModel 字段）
        final LLMConfig summaryConfig;
        if (settings.summaryUsesMainModel) {
          summaryConfig = config.copyWith(
            temperature: settings.summaryTemperature,
            maxTokens: 16384,
            model: settings.summaryModel.isNotEmpty
                ? settings.summaryModel
                : config.model,
          );
        } else {
          summaryConfig = config.copyWith(
            provider: LLMProvider.openAICompatible,
            apiUrl: settings.summaryBaseUrl.isNotEmpty
                ? settings.summaryBaseUrl
                : config.apiUrl,
            apiKey: settings.summaryApiKey.isNotEmpty
                ? settings.summaryApiKey
                : config.apiKey,
            model: settings.summaryModelName.isNotEmpty
                ? settings.summaryModelName
                : config.model,
            temperature: settings.summaryTemperature,
            maxTokens: 16384,
          );
        }

        // 1. [Phase 2] 结构化JSON抽取（失败降级纯文本，H5）
        final existingWiki = await _buildExistingWikiText(task.chatId);
        // 角色名/用户名（取不到用默认值，不阻断）
        String characterName = 'Char';
        String userName = 'User';
        for (final m in messages) {
          final name = m.characterName;
          if (name == null || name.isEmpty) continue;
          if (m.role == MessageRole.assistant) {
            characterName = name;
          } else if (m.role == MessageRole.user) {
            userName = name;
          }
        }
        final output = await _chronicleSummaryService.summarize(
          messages: messages,
          existingWikiText: existingWiki,
          settings: settings,
          config: summaryConfig,
          fromTurn: task.fromTurn,
          toTurn: task.toTurn,
          characterName: characterName,
          userName: userName,
        );

        // 2. 应用增量patch到Wiki
        final touchedEntries =
            await _applySummary(task.chatId, output, messageIds, task.toTurn);

        // 3. 向量化所有新建/更新词条
        for (final entry in touchedEntries) {
          await _vectorizeEntry(entry);
        }

        // 4. 空输出（LLM判定无变化）跳过归档，任务仍标完成
        if (!output.isEmpty) {
          await _repo.markMessagesArchived(task.chatId, messageIds);
        }
        await _repo.updateTaskStatus(
          task.id,
          'done',
          resultJson: output.fallbackText ?? '${touchedEntries.length}条词条更新',
        );

        debugPrint('[CHRONICLE] 总结任务完成：${messageIds.length}条消息归档，'
            '词条${touchedEntries.length}条，实体${output.entities.length}，'
            '关系${output.relationships.length}，情感${output.emotions.length}');
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

  /// 构建现有Wiki快照文本（喂给总结Prompt，供LLM判断增量）
  Future<String> _buildExistingWikiText(String chatId) async {
    final buffer = StringBuffer();
    final activeEntries = (await _repo.getAllEntries(chatId))
        .where((e) => !e.deprecated)
        .toList();
    // 最近30条即可（控制prompt体积）
    final recent = activeEntries.length > 30
        ? activeEntries.sublist(activeEntries.length - 30)
        : activeEntries;
    for (final e in recent) {
      buffer.writeln('[${e.id}] ${e.title}（重要度${e.importance}${e.anchor ? ',锚点' : ''}）：${e.content}');
    }
    final entities = await _repo.getMainEntities(chatId, limit: 10);
    for (final ent in entities) {
      buffer.writeln('[实体:${ent.name}] ${ent.description} 当前:${ent.currentState}');
    }
    return buffer.toString();
  }

  /// 应用LLM输出的增量patch。返回被新建/更新的词条（待向量化）。
  Future<List<models.MemoryEntry>> _applySummary(
    String chatId,
    models.ChronicleSummaryOutput output,
    List<String> sourceMessageIds,
    int turnIndex,
  ) async {
    final touched = <models.MemoryEntry>[];
    final now = DateTime.now();

    // ① 实体upsert → 名字→id映射
    final entityIdByName = <String, String>{};
    for (final inst in output.entities) {
      if (inst.name.isEmpty) continue;
      final entity = await _repo.upsertEntityByName(chatId, inst);
      entityIdByName[inst.name] = entity.id;
      entityIdByName.putIfAbsent(
          entity.name, () => entity.id);
    }

    // ② 词条upsert
    for (final inst in output.entries) {
      if (inst.title.isEmpty && inst.content.isEmpty) continue;
      final resolvedEntityIds = <String>[];
      for (final name in inst.entityNames) {
        final id = entityIdByName[name];
        if (id != null) {
          resolvedEntityIds.add(id);
        } else {
          // 引用但未在本轮定义的实体 → 尝试按名查找
          final found = await _repo.getEntityByName(chatId, name);
          if (found != null) {
            entityIdByName[name] = found.id;
            resolvedEntityIds.add(found.id);
          }
        }
      }
      // 有id且属于本聊天 → 更新；否则系统兜底查重再决定新建/覆盖
      models.MemoryEntry? existing;
      if (inst.id != null && inst.id!.isNotEmpty) {
        final candidates = await _repo.getEntriesByIds(chatId, [inst.id!]);
        existing = candidates.isEmpty ? null : candidates.first;
      } else if (inst.content.isNotEmpty) {
        // [Part A] 模型没带ID → 向量相似度兜底查重（≥0.92 视为同一件事，复用旧ID覆盖）
        final dupId =
            await _findDuplicateEntry(chatId, inst.content, inst.title);
        if (dupId != null) {
          final candidates = await _repo.getEntriesByIds(chatId, [dupId]);
          existing = candidates.isEmpty ? null : candidates.first;
        }
      }
      final entry = existing?.copyWith(
            type: inst.type,
            title: inst.title.isNotEmpty ? inst.title : existing.title,
            content: inst.content.isNotEmpty ? inst.content : existing.content,
            importance: inst.importance,
            alwaysInject: inst.alwaysInject || existing.alwaysInject,
            anchor: inst.anchor || existing.anchor,
            tags: inst.tags.isNotEmpty ? inst.tags : existing.tags,
            entityIds: resolvedEntityIds.isNotEmpty ? resolvedEntityIds : existing.entityIds,
            sourceMessageIds: [...existing.sourceMessageIds, ...sourceMessageIds],
            turnIndex: turnIndex,
            updatedAt: now,
          ) ??
          models.MemoryEntry(
            id: _uuid.v4(),
            chatId: chatId,
            type: inst.type,
            title: inst.title.isEmpty ? '未命名事件' : inst.title,
            content: inst.content,
            importance: inst.importance,
            alwaysInject: inst.alwaysInject,
            anchor: inst.anchor,
            tags: inst.tags,
            entityIds: resolvedEntityIds,
            sourceMessageIds: sourceMessageIds,
            turnIndex: turnIndex,
            createdAt: now,
            updatedAt: now,
          );
      await _repo.upsertMemoryEntry(entry);
      touched.add(entry);
    }

    // ③ 关系upsert（名字→id解析，缺实体则自动建）
    for (final inst in output.relationships) {
      final fromId = await _resolveEntityId(chatId, inst.fromName, entityIdByName);
      final toId = await _resolveEntityId(chatId, inst.toName, entityIdByName);
      if (fromId == null || toId == null) continue;
      await _repo.upsertRelationship(
        chatId,
        inst,
        fromEntityId: fromId,
        toEntityId: toId,
      );
    }

    // ④ 情感upsert
    for (final inst in output.emotions) {
      final entityId =
          await _resolveEntityId(chatId, inst.entityName, entityIdByName);
      if (entityId == null) continue;
      await _repo.upsertEmotion(chatId, inst,
          entityId: entityId, turnIndex: turnIndex);
    }

    // ⑤ 过时词条标记
    for (final id in output.deprecatedIds) {
      await _repo.deprecateEntry(id);
    }

    // ⑥ H5降级：JSON解析失败 → 纯文本词条（与旧总结同等质量）
    // 固定title"降级总结"便于识别：同一聊天只保留一条fallback词条，upsert覆盖而非新建
    if (output.fallbackText != null && output.fallbackText!.isNotEmpty) {
      final all = await _repo.getAllEntries(chatId);
      models.MemoryEntry? existingFallback;
      for (final e in all) {
        if (e.title == '降级总结' && !e.deprecated) {
          existingFallback = e;
          break;
        }
      }
      final fallback = existingFallback?.copyWith(
            content: output.fallbackText!,
            importance: 5,
            alwaysInject: false,
            anchor: false,
            sourceMessageIds: sourceMessageIds,
            turnIndex: turnIndex,
            updatedAt: now,
          ) ??
          models.MemoryEntry(
            id: _uuid.v4(),
            chatId: chatId,
            type: models.MemoryEntryType.event,
            title: '降级总结',
            content: output.fallbackText!,
            importance: 5,
            alwaysInject: false,
            anchor: false,
            sourceMessageIds: sourceMessageIds,
            turnIndex: turnIndex,
            createdAt: now,
            updatedAt: now,
          );
      await _repo.upsertMemoryEntry(fallback);
      touched.add(fallback);
    }

    return touched;
  }

  /// 名字→实体id；未注册则按名查库，再没有就自动建轻量实体
  Future<String?> _resolveEntityId(
    String chatId,
    String name,
    Map<String, String> entityIdByName,
  ) async {
    if (name.isEmpty) return null;
    final cached = entityIdByName[name];
    if (cached != null) return cached;
    final found = await _repo.getEntityByName(chatId, name);
    if (found != null) {
      entityIdByName[name] = found.id;
      return found.id;
    }
    final created = await _repo.upsertEntityByName(
      chatId,
      models.UpsertEntityInstruction(name: name),
    );
    entityIdByName[name] = created.id;
    return created.id;
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

  /// [Part A] 向量相似度兜底查重：新词条与现有未过时词条比对，
  /// 余弦相似度 ≥ 0.92 视为同一件事，返回旧词条id（供复用覆盖）。
  /// 用于 LLM 未带 id 的新建场景，避免同一事件重复累积词条。
  Future<String?> _findDuplicateEntry(
    String chatId,
    String newContent,
    String newTitle,
  ) async {
    try {
      final newText = '$newTitle\n$newContent';
      if (newText.trim().isEmpty) return null;
      final vsSettings = vectorSettingsGetter();
      final newVector = await _embedder.generateEmbedding(newText, vsSettings);

      final all = await _repo.getAllEntries(chatId);
      final active = all.where((e) => !e.deprecated).toList();
      if (active.isEmpty) return null;

      double bestScore = 0;
      String? bestId;
      for (final entry in active) {
        final docId = entry.vectorId;
        if (docId == null || docId.isEmpty) continue;
        final doc = _vectorStorage.getDocument(chatId, docId);
        if (doc?.embedding == null) continue;
        final score =
            vs.VectorMath.cosineSimilarity(newVector, doc!.embedding!);
        if (score > bestScore) {
          bestScore = score;
          bestId = entry.id;
        }
      }
      return bestScore >= 0.92 ? bestId : null;
    } catch (e) {
      debugPrint('[CHRONICLE] 兜底查重失败（不影响写入）: $e');
      return null;
    }
  }

  /// [Phase 4] MVU桥接：数值型变量重大变化（|delta|≥20）→ 记忆事件词条。
  /// 边界：Chronicle只读MVU数据作为上下文，**绝不回写MVU**（MVU引擎不碰记忆表）。
  Future<void> onMvuVariableUpdated(
    String chatId,
    Map<String, dynamic>? oldStat,
    Map<String, dynamic> newStat,
  ) async {
    try {
      if (oldStat == null || oldStat.isEmpty) return;
      final settings = settingsGetter();
      if (!settings.enabled || !settings.mvuBridgeEnabled) return;

      final changes = <String>[];
      for (final entry in newStat.entries) {
        final nv = entry.value;
        final ov = oldStat[entry.key];
        if (nv is num && ov is num) {
          final delta = (nv.toDouble() - ov.toDouble()).abs();
          if (delta >= 20) {
            changes.add('${entry.key}: $ov→$nv');
          }
        }
      }
      if (changes.isEmpty) return;

      final now = DateTime.now();
      final entry = models.MemoryEntry(
        id: _uuid.v4(),
        chatId: chatId,
        type: models.MemoryEntryType.state,
        title: '关系数值重大变化',
        content: 'MVU状态重大变化：${changes.join('；')}。这标志着角色关系出现显著转折，'
            '后续剧情应体现这一变化的影响。',
        importance: 8,
        alwaysInject: true,
        tags: changes.map((c) => c.split(':')[0]).toList(),
        createdAt: now,
        updatedAt: now,
      );
      await _repo.upsertMemoryEntry(entry);
      await _vectorizeEntry(entry);
      debugPrint('[CHRONICLE] MVU桥接事件已记录：${changes.join('；')}');
    } catch (e) {
      debugPrint('[CHRONICLE] MVU桥接失败（不影响变量更新）: $e');
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
}
