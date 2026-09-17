import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/database/database.dart' hide Chat, Message;
import 'package:kirakira/data/database/database.dart' as db;
import 'package:kirakira/data/models/chat.dart' as models;
import 'package:uuid/uuid.dart';

/// Provider for chat repository
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

/// Repository for managing chat data
class ChatRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  ChatRepository(this._db);

  /// Get all chats
  Future<List<models.Chat>> getAllChats() async {
    final rows = await (_db.select(_db.chats)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(_chatFromRow).toList();
  }

  /// Get chats for a specific character
  Future<List<models.Chat>> getChatsForCharacter(String characterId) async {
    final rows = await (_db.select(_db.chats)
          ..where((t) => t.characterId.equals(characterId))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(_chatFromRow).toList();
  }

  /// Get recent chats
  Future<List<models.Chat>> getRecentChats({int limit = 10}) async {
    final rows = await (_db.select(_db.chats)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(limit))
        .get();
    return rows.map(_chatFromRow).toList();
  }

  /// Get chat by ID
  Future<models.Chat?> getChat(String id) async {
    final row = await (_db.select(_db.chats)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row != null ? _chatFromRow(row) : null;
  }

  /// Create a new chat
  Future<models.Chat> createChat(models.Chat chat) async {
    final id = chat.id.isEmpty ? _uuid.v4() : chat.id;
    final now = DateTime.now();
    
    final newChat = models.Chat(
      id: id,
      characterId: chat.characterId,
      groupId: chat.groupId,
      title: chat.title,
      authorNote: chat.authorNote,
      authorNoteDepth: chat.authorNoteDepth,
      authorNoteEnabled: chat.authorNoteEnabled,
      createdAt: now,
      updatedAt: now,
    );

    await _db.into(_db.chats).insert(ChatsCompanion(
      id: Value(newChat.id),
      characterId: Value(newChat.characterId),
      groupId: Value(newChat.groupId),
      title: Value(newChat.title),
      authorNote: Value(newChat.authorNote),
      authorNoteDepth: Value(newChat.authorNoteDepth),
      authorNoteEnabled: Value(newChat.authorNoteEnabled),
      createdAt: Value(newChat.createdAt),
      updatedAt: Value(newChat.updatedAt),
    ));
    
    return newChat;
  }

  /// Update chat
  Future<models.Chat> updateChat(models.Chat chat) async {
    final now = DateTime.now();
    
    await (_db.update(_db.chats)..where((t) => t.id.equals(chat.id)))
        .write(ChatsCompanion(
          title: Value(chat.title),
          authorNote: Value(chat.authorNote),
          authorNoteDepth: Value(chat.authorNoteDepth),
          authorNoteEnabled: Value(chat.authorNoteEnabled),
          updatedAt: Value(now),
        ));
    
    return chat.copyWith(updatedAt: now);
  }

  /// Delete chat and all its messages
  Future<void> deleteChat(String id) async {
    // Delete all messages first
    await (_db.delete(_db.messages)..where((t) => t.chatId.equals(id))).go();
    // RAG：级联删除本聊天的向量集合与所有文档（集合 id == chatId）
    await (_db.delete(_db.vectorDocuments)..where((t) => t.collectionId.equals(id))).go();
    await (_db.delete(_db.vectorCollections)..where((t) => t.id.equals(id))).go();
    // [CHRONICLE] 级联删除超级记忆数据（任务/词条/窗口状态）
    await (_db.delete(_db.summaryTasks)..where((t) => t.chatId.equals(id))).go();
    await (_db.delete(_db.memoryEntries)..where((t) => t.chatId.equals(id))).go();
    await (_db.delete(_db.chronicleStates)..where((t) => t.chatId.equals(id))).go();
    // Delete the chat
    await (_db.delete(_db.chats)..where((t) => t.id.equals(id))).go();
  }

  /// Get messages for a chat
  Future<List<models.ChatMessage>> getMessages(String chatId) async {
    final rows = await (_db.select(_db.messages)
          ..where((t) => t.chatId.equals(chatId))
          ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
        .get();
    return rows.map(_messageFromRow).toList();
  }

  /// Add a message to a chat
  Future<models.ChatMessage> addMessage(models.ChatMessage message) async {
    final id = message.id.isEmpty ? _uuid.v4() : message.id;
    
    final newMessage = message.copyWith(id: id);

    await _db.into(_db.messages).insert(MessagesCompanion(
      id: Value(newMessage.id),
      chatId: Value(newMessage.chatId),
      role: Value(newMessage.role.name),
      content: Value(newMessage.content),
      timestamp: Value(newMessage.timestamp),
      swipes: Value(jsonEncode(newMessage.swipes)),
      currentSwipeIndex: Value(newMessage.currentSwipeIndex),
      characterId: Value(newMessage.characterId),
      characterName: Value(newMessage.characterName),
      attachmentsJson: Value(jsonEncode(newMessage.attachments.map((a) => a.toJson()).toList())),
      swipesDataJson: Value(jsonEncode(newMessage.swipesData)),
    ));
    
    // [空会话] 更新 updatedAt;用户消息同步置位 hasUserMessage(永不回退)。
    // 该标记是"退出丢弃/启动清扫"的判定依据:发过消息的会话即使删光消息也保留。
    await (_db.update(_db.chats)..where((t) => t.id.equals(message.chatId)))
        .write(ChatsCompanion(
      updatedAt: Value(DateTime.now()),
      hasUserMessage: message.role.name == 'user'
          ? const Value(true)
          : const Value.absent(),
    ));

    return newMessage;
  }

  /// [空会话] 该会话是否有过用户消息(读持久标记,不数 messages 表)
  Future<bool> hasUserMessaged(String chatId) async {
    final row = await (_db.select(_db.chats)
          ..where((t) => t.id.equals(chatId)))
        .getSingleOrNull();
    return row?.hasUserMessage ?? false;
  }

  /// [空会话] 启动清扫:删除所有从未有过用户消息的会话(级联消息/向量数据)。
  /// 覆盖:旧版本遗留的空会话、进程被杀时没走退出丢弃的临时会话。
  /// 返回删除的会话数。
  Future<int> purgeEmptyChats() async {
    final emptyIds = await (_db.select(_db.chats)
          ..where((t) => t.hasUserMessage.equals(false)))
        .map((row) => row.id)
        .get();
    for (final id in emptyIds) {
      await deleteChat(id);
    }
    return emptyIds.length;
  }

  /// Update a message
  Future<models.ChatMessage> updateMessage(models.ChatMessage message) async {
    await (_db.update(_db.messages)..where((t) => t.id.equals(message.id)))
        .write(MessagesCompanion(
          content: Value(message.content),
          swipes: Value(jsonEncode(message.swipes)),
          currentSwipeIndex: Value(message.currentSwipeIndex),
          characterId: Value(message.characterId),
          characterName: Value(message.characterName),
          attachmentsJson: Value(jsonEncode(message.attachments.map((a) => a.toJson()).toList())),
          swipesDataJson: Value(jsonEncode(message.swipesData)),
          isHidden: Value(message.isHidden),
        ));
    
    // Update chat's updatedAt
    await (_db.update(_db.chats)..where((t) => t.id.equals(message.chatId)))
        .write(ChatsCompanion(updatedAt: Value(DateTime.now())));
    
    return message;
  }

  /// 清空指定对话的所有消息（导入覆盖时使用）
  Future<void> clearMessages(String chatId) async {
    await (_db.delete(_db.messages)..where((t) => t.chatId.equals(chatId))).go();
  }
  /// Delete a message
  Future<void> deleteMessage(String id) async {
    await (_db.delete(_db.messages)..where((t) => t.id.equals(id))).go();
    // RAG：级联删除该消息对应的向量（document.id == messageId）
    await (_db.delete(_db.vectorDocuments)..where((t) => t.id.equals(id))).go();
  }

  /// Get message count for a chat
  Future<int> getMessageCount(String chatId) async {
    final messages = await (_db.select(_db.messages)
          ..where((t) => t.chatId.equals(chatId)))
        .get();
    return messages.length;
  }

  /// Get last message of a chat
  Future<models.ChatMessage?> getLastMessage(String chatId) async {
    final row = await (_db.select(_db.messages)
          ..where((t) => t.chatId.equals(chatId))
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
          ..limit(1))
        .getSingleOrNull();
    return row != null ? _messageFromRow(row) : null;
  }

  /// Get chats for a group
  Future<List<models.Chat>> getChatsForGroup(String groupId) async {
    final rows = await (_db.select(_db.chats)
          ..where((t) => t.groupId.equals(groupId))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(_chatFromRow).toList();
  }

  // Private helpers
  
  models.Chat _chatFromRow(db.Chat row) {
    return models.Chat(
      id: row.id,
      characterId: row.characterId,
      groupId: row.groupId,
      title: row.title,
      authorNote: row.authorNote,
      authorNoteDepth: row.authorNoteDepth,
      authorNoteEnabled: row.authorNoteEnabled,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  models.ChatMessage _messageFromRow(db.Message row) {
    return models.ChatMessage(
      id: row.id,
      chatId: row.chatId,
      role: models.MessageRole.values.firstWhere(
        (r) => r.name == row.role,
        orElse: () => models.MessageRole.user,
      ),
      content: row.content,
      timestamp: row.timestamp,
      swipes: _parseJsonList(row.swipes),
      currentSwipeIndex: row.currentSwipeIndex,
      characterId: row.characterId,
      characterName: row.characterName,
      attachments: _parseAttachments(row.attachmentsJson),
      swipesData: _parseSwipesData(row.swipesDataJson),
      isHidden: row.isHidden,
    );
  }

  List<String> _parseJsonList(String json) {
    try {
      final list = jsonDecode(json) as List;
      return list.cast<String>();
    } catch (_) {
      return [];
    }
  }
  List<Map<String, dynamic>> _parseSwipesData(String json) {
    try {
      final list = jsonDecode(json) as List;
      return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (_) {
      return [];
    }
  }

  List<models.ChatAttachment> _parseAttachments(String json) {
    try {
      final list = jsonDecode(json) as List;
      return list
          .map((item) => models.ChatAttachment.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}