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

/// Repository for Chronicle（超级记忆）数据访问。
///
/// 所有方法都在调用方 isolate（主isolate）执行 DB 读写——调整B：
/// 后台isolate写DB会被OS杀，Chronicle全链路前台异步。
class ChronicleRepository {
  final db.AppDatabase _db;
  static const _uuid = Uuid();

  ChronicleRepository(this._db);

  // ═══════════════════ SummaryTasks ═══════════════════

  /// 入队一个总结任务（幂等：同聊天已有 pending/running 任务则跳过）
  Future<bool> enqueueSummaryTask({
    required String chatId,
    required List<String> messageIds,
    int fromTurn = 0,
    int toTurn = 0,
  }) async {
    if (messageIds.isEmpty) return false;
    if (await hasActiveTaskForChat(chatId)) return false;

    await _db.into(_db.summaryTasks).insert(db.SummaryTasksCompanion.insert(
          id: _uuid.v4(),
          chatId: chatId,
          messageIds: Value(jsonEncode(messageIds)),
          fromTurn: Value(fromTurn),
          toTurn: Value(toTurn),
        ));
    return true;
  }

  /// 是否存在未完成任务（pending/running）
  Future<bool> hasActiveTaskForChat(String chatId) async {
    final rows = await (_db.select(_db.summaryTasks)
          ..where((t) =>
              t.chatId.equals(chatId) &
              (t.status.equals('pending') | t.status.equals('running'))))
        .get();
    return rows.isNotEmpty;
  }

  /// 取待处理任务（先进先出）
  Future<List<db.SummaryTask>> getPendingTasks({int limit = 1}) async {
    final query = (_db.select(_db.summaryTasks)
          ..where((t) => t.status.equals('pending'))
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)
          ]))
        ..limit(limit);
    return query.get();
  }

  /// 更新任务状态（含结果/错误信息）
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

  // ═══════════════════ MemoryEntries ═══════════════════

  /// 插入或更新词条（按主键覆盖）
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

  /// 是否已有词条（旧摘要迁移的一次性守卫）
  Future<bool> hasChronicleEntries(String chatId) async {
    final rows = await (_db.select(_db.memoryEntries)
          ..where((t) => t.chatId.equals(chatId))
          ..limit(1))
        .get();
    return rows.isNotEmpty;
  }

  /// 全部词条（Wiki管理界面/导出用）
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

  /// 固定层候选：alwaysInject 或 anchor 的未过时词条
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

  /// 高重要度事件（固定层补位/召回层候选）
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

  /// 按id批量取
  Future<List<models.MemoryEntry>> getEntriesByIds(
      String chatId, List<String> ids) async {
    if (ids.isEmpty) return [];
    final rows = await (_db.select(_db.memoryEntries)
          ..where((t) =>
              t.chatId.equals(chatId) & t.id.isIn(ids)))
        .get();
    return rows.map(_entryFromRow).toList();
  }

  /// 标记过时（保留历史，不删除）
  Future<void> deprecateEntry(String id) async {
    await (_db.update(_db.memoryEntries)..where((t) => t.id.equals(id)))
        .write(db.MemoryEntriesCompanion(
      deprecated: const Value(true),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// 删除词条（用户手动）
  Future<void> deleteEntry(String id) async {
    await (_db.delete(_db.memoryEntries)..where((t) => t.id.equals(id))).go();
  }

  /// 词条数（管理界面统计）
  Future<int> countEntries(String chatId) async {
    final rows = await (_db.select(_db.memoryEntries)
          ..where((t) => t.chatId.equals(chatId)))
        .get();
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

  // ═══════════════════ ChronicleStates（窗口状态+配置） ═══════════════════

  /// 已归档消息id集合
  Future<Set<String>> getArchivedMessageIds(String chatId) async {
    final row = await (_db.select(_db.chronicleStates)
          ..where((t) => t.chatId.equals(chatId)))
        .getSingleOrNull();
    if (row == null) return {};
    return _parseStringList(row.archivedMessageIds).toSet();
  }

  /// 批量标记归档（读-合并-写，主isolate单写者安全）
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

  /// 取消归档（编辑/重生成场景可回滚）
  Future<void> unarchiveMessages(String chatId, Iterable<String> messageIds) async {
    if (messageIds.isEmpty) return;
    final existing = await getArchivedMessageIds(chatId);
    existing.removeAll(messageIds);
    await _saveState(chatId, archivedMessageIds: existing.toList());
  }

  /// 读每聊天配置
  Future<models.ChronicleSettings> getSettings(String chatId) async {
    final row = await (_db.select(_db.chronicleStates)
          ..where((t) => t.chatId.equals(chatId)))
        .getSingleOrNull();
    if (row == null || row.settingsJson.isEmpty) {
      return const models.ChronicleSettings();
    }
    try {
      return models.ChronicleSettings.fromJson(
          jsonDecode(row.settingsJson) as Map<String, dynamic>);
    } catch (_) {
      return const models.ChronicleSettings();
    }
  }

  /// 写每聊天配置
  Future<void> saveSettings(
      String chatId, models.ChronicleSettings settings) async {
    final row = await (_db.select(_db.chronicleStates)
          ..where((t) => t.chatId.equals(chatId)))
        .getSingleOrNull();
    await _saveState(
      chatId,
      archivedMessageIds: row == null
          ? null
          : _parseStringList(row.archivedMessageIds),
      settingsJson: jsonEncode(settings.toJson()),
    );
  }

  Future<void> _saveState(
    String chatId, {
    List<String>? archivedMessageIds,
    String? settingsJson,
  }) async {
    final row = await (_db.select(_db.chronicleStates)
          ..where((t) => t.chatId.equals(chatId)))
        .getSingleOrNull();

    if (row == null) {
      await _db.into(_db.chronicleStates).insert(db.ChronicleStatesCompanion
          .insert(
        chatId: chatId,
        archivedMessageIds:
            Value(jsonEncode(archivedMessageIds ?? const <String>[])),
        settingsJson:
            Value(settingsJson ?? jsonEncode(const models.ChronicleSettings().toJson())),
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
      settingsJson:
          settingsJson != null ? Value(settingsJson) : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    ));
  }

  // ═══════════════════ 级联清理 ═══════════════════

  /// 聊天删除时级联清理所有 Chronicle 数据
  Future<void> deleteAllForChat(String chatId) async {
    await (_db.delete(_db.summaryTasks)..where((t) => t.chatId.equals(chatId)))
        .go();
    await (_db.delete(_db.memoryEntries)..where((t) => t.chatId.equals(chatId)))
        .go();
    await (_db.delete(_db.chronicleStates)
          ..where((t) => t.chatId.equals(chatId)))
        .go();
  }

  /// 按messageId集合取消息（任务消费时用；时间正序）
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
