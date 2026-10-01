import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/core/services/initialization_service.dart';
import 'package:kirakira/data/database/database.dart' as db;
import 'package:kirakira/data/models/chronicle.dart' as models;
import 'package:kirakira/data/models/chat.dart' as chat_models;
import 'package:uuid/uuid.dart';

/// Provider for chronicle repository
final chronicleRepositoryProvider = Provider<ChronicleRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return ChronicleRepository(database);
});

/// Repository for Chronicle (super memory) data access.
///
/// All DB reads/writes run on the caller's isolate (the main isolate):
/// background isolates writing to the DB get killed by the OS, so the
/// entire Chronicle pipeline runs as a foreground async flow.
class ChronicleRepository {
  final db.AppDatabase _db;
  static const _uuid = Uuid();

  ChronicleRepository(this._db);

  // SummaryTasks

  /// Enqueue a summary task (idempotent: skips if the chat already has a
  /// pending/running task; forceEnqueue=true bypasses this guard, used for
  /// full re-summarization)
  Future<bool> enqueueSummaryTask({
    required String chatId,
    required List<String> messageIds,
    int fromTurn = 0,
    int toTurn = 0,
    bool forceEnqueue = false,
  }) async {
    if (messageIds.isEmpty) return false;
    if (!forceEnqueue && await hasActiveTaskForChat(chatId)) return false;

    await _db.into(_db.summaryTasks).insert(db.SummaryTasksCompanion.insert(
          id: _uuid.v4(),
          chatId: chatId,
          messageIds: Value(jsonEncode(messageIds)),
          fromTurn: Value(fromTurn),
          toTurn: Value(toTurn),
        ));
    return true;
  }

  /// Whether an unfinished task (pending/running) exists for the chat
  Future<bool> hasActiveTaskForChat(String chatId) async {
    final rows = await (_db.select(_db.summaryTasks)
          ..where((t) =>
              t.chatId.equals(chatId) &
              (t.status.equals('pending') | t.status.equals('running'))))
        .get();
    return rows.isNotEmpty;
  }

  /// Number of failed tasks for a chat (for backoff: stop enqueueing after maxRetries)
  Future<int> getFailedTaskCountForChat(String chatId) async {
    final rows = await (_db.select(_db.summaryTasks)
          ..where((t) => t.chatId.equals(chatId) & t.status.equals('failed')))
        .get();
    return rows.length;
  }

  /// Reset zombie tasks: running tasks stay stuck forever after the app is
  /// killed, so timed-out tasks are reset to pending on startup
  Future<void> resetStuckRunningTasks() async {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 10));
    await (_db.update(_db.summaryTasks)
          ..where((t) => t.status.equals('running') & t.createdAt.isSmallerThanValue(cutoff)))
        .write(const db.SummaryTasksCompanion(status: Value('pending')));
  }

  /// Get pending tasks (FIFO)
  Future<List<db.SummaryTask>> getPendingTasks({int limit = 1}) async {
    final query = (_db.select(_db.summaryTasks)
          ..where((t) => t.status.equals('pending'))
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)
          ]))
        ..limit(limit);
    return query.get();
  }

  /// Update task status (including result/error info)
  Future<void> updateTaskStatus(
    String id,
    String status, {
    String? resultJson,
    String? error,
  }) async {
    await (_db.update(_db.summaryTasks)..where((t) => t.id.equals(id)))
        .write(db.SummaryTasksCompanion(
      status: Value(status),
      resultJson: Value(resultJson),
      error: Value(error),
      finishedAt: Value(status == 'done' || status == 'failed'
          ? DateTime.now()
          : null),
    ));
  }

  /// All tasks for a chat (for the Wiki management panel, newest first)
  Future<List<db.SummaryTask>> getTasksForChat(String chatId) async {
    final query = (_db.select(_db.summaryTasks)
          ..where((t) => t.chatId.equals(chatId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]));
    return query.get();
  }

  /// Delete a task record (manual, triggered by the user)
  Future<void> deleteTask(String id) async {
    await (_db.delete(_db.summaryTasks)..where((t) => t.id.equals(id))).go();
  }

  /// Clear all failed tasks for a chat (for the Wiki management panel)
  Future<void> clearFailedTasksForChat(String chatId) async {
    await (_db.delete(_db.summaryTasks)
          ..where((t) => t.chatId.equals(chatId) & t.status.equals('failed')))
        .go();
  }

  /// Delete all task records for a chat (used for full re-summarization)
  Future<void> clearTasksForChat(String chatId) async {
    await (_db.delete(_db.summaryTasks)
          ..where((t) => t.chatId.equals(chatId)))
        .go();
  }

  /// Delete all entries for a chat (used for full re-summarization)
  Future<void> deleteAllEntriesForChat(String chatId) async {
    await (_db.delete(_db.memoryEntries)
          ..where((t) => t.chatId.equals(chatId)))
        .go();
  }

  /// Clear archive state (resets archivedMessageIds to an empty array)
  Future<void> clearArchivedMessageIds(String chatId) async {
    await _saveState(chatId, archivedMessageIds: const <String>[]);
  }

  // MemoryEntries

  /// Insert or update an entry (overwrites by primary key)
  Future<void> upsertMemoryEntry(models.MemoryEntry entry) async {
    await _db.into(_db.memoryEntries).insertOnConflictUpdate(
          db.MemoryEntriesCompanion.insert(
            id: entry.id,
            chatId: entry.chatId,
            type: Value(entry.type.name),
            title: entry.title,
            content: entry.content,
            importance: Value(entry.importance),
            alwaysInject: Value(entry.alwaysInject),
            anchor: Value(entry.anchor),
            neverEvict: Value(entry.neverEvict),
            tags: Value(jsonEncode(entry.tags)),
            entityIds: Value(jsonEncode(entry.entityIds)),
            sourceMessageIds: Value(jsonEncode(entry.sourceMessageIds)),
            turnIndex: Value(entry.turnIndex),
            deprecated: Value(entry.deprecated),
            vectorId: Value(entry.vectorId),
            createdAt: Value(entry.createdAt),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  /// Whether entries already exist (one-time guard for legacy summary migration)
  Future<bool> hasChronicleEntries(String chatId) async {
    final rows = await (_db.select(_db.memoryEntries)
          ..where((t) => t.chatId.equals(chatId))
          ..limit(1))
        .get();
    return rows.isNotEmpty;
  }

  /// All entries (for the Wiki management UI / export)
  Future<List<models.MemoryEntry>> getAllEntries(String chatId) async {
    final rows = await (_db.select(_db.memoryEntries)
          ..where((t) => t.chatId.equals(chatId))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)
          ]))
        .get();
    return rows.map(_entryFromRow).toList();
  }

  /// Fixed-layer candidates: non-deprecated entries with alwaysInject or anchor
  Future<List<models.MemoryEntry>> getFixedLayerEntries(String chatId) async {
    final rows = await (_db.select(_db.memoryEntries)
          ..where((t) =>
              t.chatId.equals(chatId) &
              t.deprecated.equals(false) &
              (t.alwaysInject.equals(true) | t.anchor.equals(true)))
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.importance, mode: OrderingMode.desc)
          ]))
        .get();
    return rows.map(_entryFromRow).toList();
  }

  /// High-importance entries (fixed-layer fill / recall-layer candidates)
  Future<List<models.MemoryEntry>> getImportantEntries(
    String chatId, {
    int minImportance = 8,
    int limit = 10,
  }) async {
    final rows = await ((_db.select(_db.memoryEntries)
          ..where((t) =>
              t.chatId.equals(chatId) &
              t.deprecated.equals(false) &
              t.importance.isBiggerOrEqualValue(minImportance))
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.importance, mode: OrderingMode.desc)
          ]))
        ..limit(limit))
        .get();
    return rows.map(_entryFromRow).toList();
  }

  /// Fetch entries by IDs
  Future<List<models.MemoryEntry>> getEntriesByIds(
      String chatId, List<String> ids) async {
    if (ids.isEmpty) return [];
    final rows = await (_db.select(_db.memoryEntries)
          ..where((t) =>
              t.chatId.equals(chatId) & t.id.isIn(ids)))
        .get();
    return rows.map(_entryFromRow).toList();
  }

  /// Mark as deprecated (keeps history instead of deleting)
  Future<void> deprecateEntry(String id) async {
    await (_db.update(_db.memoryEntries)..where((t) => t.id.equals(id)))
        .write(db.MemoryEntriesCompanion(
      deprecated: const Value(true),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// Delete an entry (manual, triggered by the user)
  Future<void> deleteEntry(String id) async {
    await (_db.delete(_db.memoryEntries)..where((t) => t.id.equals(id))).go();
  }

  /// Entry count (management UI statistics)
  Future<int> countEntries(String chatId) async {
    final rows = await (_db.select(_db.memoryEntries)
          ..where((t) => t.chatId.equals(chatId)))
        .get();
    return rows.length;
  }

  /// Total entry count across all chats (for how-it-works page statistics)
  Future<int> countAllEntries() async {
    final rows = await (_db.select(_db.memoryEntries)).get();
    return rows.length;
  }

  models.MemoryEntry _entryFromRow(db.MemoryEntry row) {
    return models.MemoryEntry(
      id: row.id,
      chatId: row.chatId,
      type: models.MemoryEntryType.fromName(row.type),
      title: row.title,
      content: row.content,
      importance: row.importance,
      alwaysInject: row.alwaysInject,
      anchor: row.anchor,
      neverEvict: row.neverEvict,
      tags: _parseStringList(row.tags),
      entityIds: _parseStringList(row.entityIds),
      sourceMessageIds: _parseStringList(row.sourceMessageIds),
      turnIndex: row.turnIndex,
      deprecated: row.deprecated,
      vectorId: row.vectorId,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  // ChronicleStates (window archive state)
  // ChronicleSettings has moved to global config (SharedPreferences, chronicle_providers.dart).
  // This table only maintains the archivedMessageIds window state; the settingsJson
  // column is kept but no longer read or written.

  /// Set of archived message IDs
  Future<Set<String>> getArchivedMessageIds(String chatId) async {
    final row = await (_db.select(_db.chronicleStates)
          ..where((t) => t.chatId.equals(chatId)))
        .getSingleOrNull();
    if (row == null) return {};
    return _parseStringList(row.archivedMessageIds).toSet();
  }

  /// Mark messages as archived in batch (read-merge-write; safe because the
  /// main isolate is the single writer)
  Future<void> markMessagesArchived(
      String chatId, Iterable<String> messageIds) async {
    if (messageIds.isEmpty) return;
    final existing = await getArchivedMessageIds(chatId);
    existing.addAll(messageIds);
    await _saveState(
      chatId,
      archivedMessageIds: existing.toList(),
    );
  }

  /// Unarchive messages (rollback for edit/regenerate scenarios)
  Future<void> unarchiveMessages(String chatId, Iterable<String> messageIds) async {
    if (messageIds.isEmpty) return;
    final existing = await getArchivedMessageIds(chatId);
    existing.removeAll(messageIds);
    await _saveState(chatId, archivedMessageIds: existing.toList());
  }

  Future<void> _saveState(
    String chatId, {
    List<String>? archivedMessageIds,
  }) async {
    final row = await (_db.select(_db.chronicleStates)
          ..where((t) => t.chatId.equals(chatId)))
        .getSingleOrNull();

    if (row == null) {
      await _db.into(_db.chronicleStates).insert(
          db.ChronicleStatesCompanion.insert(
        chatId: chatId,
        archivedMessageIds:
            Value(jsonEncode(archivedMessageIds ?? const <String>[])),
        updatedAt: Value(DateTime.now()),
      ));
      return;
    }

    await (_db.update(_db.chronicleStates)
          ..where((t) => t.chatId.equals(chatId)))
        .write(db.ChronicleStatesCompanion(
      archivedMessageIds: archivedMessageIds != null
          ? Value(jsonEncode(archivedMessageIds))
          : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    ));
  }

  // MemoryEntities / Relationships / Emotions (Phase 2 Wiki)

  /// Find an entity by name (matches name or alias)
  Future<models.MemoryEntity?> getEntityByName(
      String chatId, String name) async {
    if (name.isEmpty) return null;
    final rows = await (_db.select(_db.memoryEntities)
          ..where((t) => t.chatId.equals(chatId) & t.name.equals(name)))
        .get();
    if (rows.isNotEmpty) return _entityFromRow(rows.first);
    // Fall back to alias matching
    final all = await getAllEntities(chatId);
    for (final e in all) {
      if (e.aliases.contains(name)) return e;
    }
    return null;
  }

  /// Upsert an entity
  Future<models.MemoryEntity> upsertEntity(models.MemoryEntity entity) async {
    await _db.into(_db.memoryEntities).insertOnConflictUpdate(
          db.MemoryEntitiesCompanion.insert(
            id: entity.id,
            chatId: entity.chatId,
            name: entity.name,
            type: Value(entity.type.name),
            description: Value(entity.description),
            currentState: Value(entity.currentState),
            aliases: Value(jsonEncode(entity.aliases)),
            attributes: Value(jsonEncode(entity.attributes)),
            createdAt: Value(entity.createdAt),
            updatedAt: Value(DateTime.now()),
          ),
        );
    return entity;
  }

  /// Create an entity or update an existing one by name, returning the entity (with ID)
  Future<models.MemoryEntity> upsertEntityByName(
      String chatId, models.UpsertEntityInstruction inst) async {
    final existing = await getEntityByName(chatId, inst.name);
    final now = DateTime.now();
    if (existing != null) {
      final mergedAliases = existing.aliases.toSet()..addAll(inst.aliases);
      return upsertEntity(existing.copyWith(
        type: inst.type,
        description:
            inst.description.isNotEmpty ? inst.description : existing.description,
        currentState:
            inst.currentState.isNotEmpty ? inst.currentState : existing.currentState,
        aliases: mergedAliases.toList(),
        updatedAt: now,
      ));
    }
    return upsertEntity(models.MemoryEntity(
      id: _uuid.v4(),
      chatId: chatId,
      name: inst.name,
      type: inst.type,
      description: inst.description,
      currentState: inst.currentState,
      aliases: inst.aliases,
      createdAt: now,
      updatedAt: now,
    ));
  }

  /// All entities
  Future<List<models.MemoryEntity>> getAllEntities(String chatId) async {
    final rows = await (_db.select(_db.memoryEntities)
          ..where((t) => t.chatId.equals(chatId))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)
          ]))
        .get();
    return rows.map(_entityFromRow).toList();
  }

  /// Main entities (F-6 fixed layer: persons first, then most recently updated)
  Future<List<models.MemoryEntity>> getMainEntities(String chatId,
      {int limit = 8}) async {
    final all = await getAllEntities(chatId);
    final persons = all.where((e) => e.type == models.MemoryEntityType.person);
    final others = all.where((e) => e.type != models.MemoryEntityType.person);
    return [...persons, ...others].take(limit).toList();
  }

  /// Find a relationship (from + to + type)
  Future<models.MemoryRelationship?> findRelationship(
      String chatId, String fromId, String toId, String type) async {
    final rows = await (_db.select(_db.memoryRelationships)
          ..where((t) =>
              t.chatId.equals(chatId) &
              t.fromEntityId.equals(fromId) &
              t.toEntityId.equals(toId) &
              t.relationType.equals(type)))
        .get();
    return rows.isEmpty ? null : _relFromRow(rows.first);
  }

  /// Upsert a relationship (updates strength/description if it exists)
  Future<models.MemoryRelationship> upsertRelationship(
      String chatId, models.UpsertRelationshipInstruction inst,
      {required String fromEntityId, required String toEntityId}) async {
    final existing = await findRelationship(
        chatId, fromEntityId, toEntityId, inst.relationType);
    final now = DateTime.now();
    if (existing != null) {
      final updated = models.MemoryRelationship(
        id: existing.id,
        chatId: chatId,
        fromEntityId: fromEntityId,
        toEntityId: toEntityId,
        relationType: inst.relationType,
        strength: inst.strength,
        description:
            inst.description.isNotEmpty ? inst.description : existing.description,
        createdAt: existing.createdAt,
        updatedAt: now,
      );
      await _db.into(_db.memoryRelationships).insertOnConflictUpdate(
            db.MemoryRelationshipsCompanion.insert(
              id: updated.id,
              chatId: updated.chatId,
              fromEntityId: updated.fromEntityId,
              toEntityId: updated.toEntityId,
              relationType: Value(updated.relationType),
              strength: Value(updated.strength),
              description: Value(updated.description),
              createdAt: Value(updated.createdAt),
              updatedAt: Value(now),
            ),
          );
      return updated;
    }
    final rel = models.MemoryRelationship(
      id: _uuid.v4(),
      chatId: chatId,
      fromEntityId: fromEntityId,
      toEntityId: toEntityId,
      relationType: inst.relationType,
      strength: inst.strength,
      description: inst.description,
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_db.memoryRelationships).insert(
          db.MemoryRelationshipsCompanion.insert(
            id: rel.id,
            chatId: rel.chatId,
            fromEntityId: rel.fromEntityId,
            toEntityId: rel.toEntityId,
            relationType: Value(rel.relationType),
            strength: Value(rel.strength),
            description: Value(rel.description),
            createdAt: Value(rel.createdAt),
            updatedAt: Value(now),
          ),
        );
    return rel;
  }

  /// All relationships (for export / management)
  Future<List<models.MemoryRelationship>> getAllRelationships(
      String chatId) async {
    final rows = await (_db.select(_db.memoryRelationships)
          ..where((t) => t.chatId.equals(chatId)))
        .get();
    return rows.map(_relFromRow).toList();
  }

  /// Key relationships (F-6 fixed layer: highest |strength| first)
  Future<List<models.MemoryRelationship>> getKeyRelationships(String chatId,
      {int limit = 6}) async {
    final all = await getAllRelationships(chatId);
    all.sort((a, b) => b.strength.abs().compareTo(a.strength.abs()));
    return all.take(limit).toList();
  }

  /// Find an emotion node (entityId + emotion)
  Future<models.EmotionNode?> findEmotion(
      String chatId, String entityId, String emotion) async {
    final rows = await (_db.select(_db.emotionNodes)
          ..where((t) =>
              t.chatId.equals(chatId) &
              t.entityId.equals(entityId) &
              t.emotion.equals(emotion)))
        .get();
    return rows.isEmpty ? null : _emotionFromRow(rows.first);
  }

  /// Upsert an emotion node
  Future<models.EmotionNode> upsertEmotion(
      String chatId, models.UpsertEmotionInstruction inst,
      {required String entityId, int turnIndex = 0}) async {
    final existing = await findEmotion(chatId, entityId, inst.emotion);
    final now = DateTime.now();
    final node = models.EmotionNode(
      id: existing?.id ?? _uuid.v4(),
      chatId: chatId,
      entityId: entityId,
      emotion: inst.emotion,
      intensity: inst.intensity,
      trigger: inst.trigger.isNotEmpty ? inst.trigger : (existing?.trigger ?? ''),
      turnIndex: turnIndex,
      isActive: inst.active,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _db.into(_db.emotionNodes).insertOnConflictUpdate(
          db.EmotionNodesCompanion.insert(
            id: node.id,
            chatId: node.chatId,
            entityId: node.entityId,
            emotion: Value(node.emotion),
            intensity: Value(node.intensity),
            trigger: Value(node.trigger),
            turnIndex: Value(node.turnIndex),
            isActive: Value(node.isActive),
            createdAt: Value(node.createdAt),
            updatedAt: Value(now),
          ),
        );
    return node;
  }

  /// Active emotions (F-6 fixed layer)
  Future<List<models.EmotionNode>> getActiveEmotions(String chatId,
      {int limit = 8}) async {
    final rows = await ((_db.select(_db.emotionNodes)
          ..where((t) => t.chatId.equals(chatId) & t.isActive.equals(true))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)
          ]))
        ..limit(limit))
        .get();
    return rows.map(_emotionFromRow).toList();
  }

  /// Entity IDs of active emotions (for recall boosting)
  Future<Set<String>> getActiveEmotionEntityIds(String chatId) async {
    final emotions = await getActiveEmotions(chatId, limit: 50);
    return emotions.map((e) => e.entityId).toSet();
  }

  /// All emotions (for export / management)
  Future<List<models.EmotionNode>> getAllEmotions(String chatId) async {
    final rows = await (_db.select(_db.emotionNodes)
          ..where((t) => t.chatId.equals(chatId)))
        .get();
    return rows.map(_emotionFromRow).toList();
  }

  /// Delete an entity (management UI)
  Future<void> deleteEntity(String id) async {
    await (_db.delete(_db.memoryEntities)..where((t) => t.id.equals(id))).go();
  }

  /// Delete a relationship (management UI)
  Future<void> deleteRelationship(String id) async {
    await (_db.delete(_db.memoryRelationships)..where((t) => t.id.equals(id)))
        .go();
  }

  /// Delete an emotion (management UI)
  Future<void> deleteEmotion(String id) async {
    await (_db.delete(_db.emotionNodes)..where((t) => t.id.equals(id))).go();
  }

  models.MemoryEntity _entityFromRow(db.MemoryEntity row) {
    return models.MemoryEntity(
      id: row.id,
      chatId: row.chatId,
      name: row.name,
      type: models.MemoryEntityType.values.firstWhere(
        (t) => t.name == row.type,
        orElse: () => models.MemoryEntityType.person,
      ),
      description: row.description,
      currentState: row.currentState,
      aliases: _parseStringList(row.aliases),
      attributes: _parseAttrs(row.attributes),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  Map<String, dynamic> _parseAttrs(String json) {
    try {
      return Map<String, dynamic>.from(jsonDecode(json) as Map);
    } catch (_) {
      return {};
    }
  }

  models.MemoryRelationship _relFromRow(db.MemoryRelationship row) {
    return models.MemoryRelationship(
      id: row.id,
      chatId: row.chatId,
      fromEntityId: row.fromEntityId,
      toEntityId: row.toEntityId,
      relationType: row.relationType,
      strength: row.strength,
      description: row.description,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  models.EmotionNode _emotionFromRow(db.EmotionNode row) {
    return models.EmotionNode(
      id: row.id,
      chatId: row.chatId,
      entityId: row.entityId,
      emotion: row.emotion,
      intensity: row.intensity,
      trigger: row.trigger,
      turnIndex: row.turnIndex,
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  // Cascade cleanup

  /// Cascade cleanup of all Chronicle data when a chat is deleted
  Future<void> deleteAllForChat(String chatId) async {
    await (_db.delete(_db.summaryTasks)..where((t) => t.chatId.equals(chatId)))
        .go();
    await (_db.delete(_db.memoryEntries)..where((t) => t.chatId.equals(chatId)))
        .go();
    await (_db.delete(_db.chronicleStates)
          ..where((t) => t.chatId.equals(chatId)))
        .go();
    await (_db.delete(_db.memoryEntities)..where((t) => t.chatId.equals(chatId)))
        .go();
    await (_db.delete(_db.memoryRelationships)
          ..where((t) => t.chatId.equals(chatId)))
        .go();
    await (_db.delete(_db.emotionNodes)..where((t) => t.chatId.equals(chatId)))
        .go();
  }

  /// Fetch messages by a set of message IDs (used when consuming tasks; oldest first)
  Future<List<chat_models.ChatMessage>> getMessagesByIds(
      String chatId, List<String> ids) async {
    if (ids.isEmpty) return [];
    final rows = await (_db.select(_db.messages)
          ..where((t) => t.chatId.equals(chatId) & t.id.isIn(ids))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.timestamp, mode: OrderingMode.asc)
          ]))
        .get();
    return rows.map((row) {
      return chat_models.ChatMessage(
        id: row.id,
        chatId: row.chatId,
        role: chat_models.MessageRole.values.firstWhere(
          (r) => r.name == row.role,
          orElse: () => chat_models.MessageRole.user,
        ),
        content: row.content,
        timestamp: row.timestamp,
        characterName: row.characterName,
      );
    }).toList();
  }

  static List<String> _parseStringList(String json) {
    try {
      final list = jsonDecode(json) as List;
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }
}
