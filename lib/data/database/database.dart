import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

/// Characters table
class Characters extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get personality => text().withDefault(const Constant(''))();
  TextColumn get scenario => text().withDefault(const Constant(''))();
  TextColumn get firstMessage => text().withDefault(const Constant(''))();
  TextColumn get alternateGreetings => text().withDefault(const Constant('[]'))(); // JSON array
  TextColumn get exampleDialogue => text().withDefault(const Constant(''))();
  TextColumn get systemPrompt => text().withDefault(const Constant(''))();
  TextColumn get postHistoryInstructions => text().withDefault(const Constant(''))();
  TextColumn get creatorNotes => text().withDefault(const Constant(''))();
  TextColumn get tags => text().withDefault(const Constant('[]'))(); // JSON array
  TextColumn get creator => text().withDefault(const Constant(''))();
  TextColumn get characterVersion => text().withDefault(const Constant(''))();
  TextColumn get avatarPath => text().nullable()();
  TextColumn get assetsJson => text().withDefault(const Constant('{}'))(); // JSON
  TextColumn get characterBookJson => text().withDefault(const Constant(''))(); // JSON for embedded lorebook
  TextColumn get extensionsJson => text().withDefault(const Constant('{}'))(); // JSON
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))(); // Favorite flag
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get modifiedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Chats table
class Chats extends Table {
  TextColumn get id => text()();
  TextColumn get characterId => text().references(Characters, #id)();
  TextColumn get groupId => text().nullable()();
  TextColumn get title => text().withDefault(const Constant('New Chat'))();
  TextColumn get settingsJson => text().withDefault(const Constant('{}'))(); // JSON
  TextColumn get authorNote => text().withDefault(const Constant(''))(); // Author's Note content
  IntColumn get authorNoteDepth => integer().withDefault(const Constant(4))(); // Depth for injection
  BoolColumn get authorNoteEnabled => boolean().withDefault(const Constant(false))(); // Whether enabled
  /// [空会话] 用户是否发过消息:一旦置位永不回退。
  /// 退出聊天页时无标记 → 级联丢弃;启动清扫无标记遗留。
  /// 用持久标记而非实时数 messages(user) 是为了覆盖"发了又删"的边界(发过就算)。
  BoolColumn get hasUserMessage => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Messages table
class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get chatId => text().references(Chats, #id)();
  TextColumn get role => text()(); // user, assistant, system
  TextColumn get content => text()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get swipes => text().withDefault(const Constant('[]'))(); // JSON array of strings
  IntColumn get currentSwipeIndex => integer().withDefault(const Constant(0))();
  BoolColumn get isEdited => boolean().withDefault(const Constant(false))();
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();
  TextColumn get metadataJson => text().withDefault(const Constant('{}'))(); // JSON
  TextColumn get characterId => text().nullable()(); // For group chats - which character sent this
  TextColumn get characterName => text().nullable()(); // Cached character name
  TextColumn get attachmentsJson => text().withDefault(const Constant('[]'))(); // JSON array of attachments
  TextColumn get swipesDataJson => text().withDefault(const Constant('[]'))(); // JSON: per-swipe MvuData

  @override
  Set<Column> get primaryKey => {id};
}

/// World Info table
class WorldInfos extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  BoolColumn get isGlobal => boolean().withDefault(const Constant(false))();
  TextColumn get characterId => text().nullable().references(Characters, #id)();
  TextColumn get scanDepth => text().nullable()(); // Default scan depth for entries
  BoolColumn get caseSensitive => boolean().nullable()(); // Default case sensitivity
  BoolColumn get matchWholeWords => boolean().nullable()(); // Default match whole words
  BoolColumn get useGroupScoring => boolean().nullable()(); // Default group scoring
  IntColumn get recursionDepth => integer().nullable()(); // Max recursion depth
  TextColumn get extensionsJson => text().withDefault(const Constant('{}'))(); // JSON extensions
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get modifiedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// World Info Entries table
class WorldInfoEntries extends Table {
  TextColumn get id => text()();
  TextColumn get worldInfoId => text().references(WorldInfos, #id)();
  TextColumn get keys => text().withDefault(const Constant('[]'))(); // JSON array
  TextColumn get secondaryKeys => text().withDefault(const Constant('[]'))(); // JSON array
  TextColumn get content => text().withDefault(const Constant(''))();
  TextColumn get comment => text().withDefault(const Constant(''))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  BoolColumn get constant => boolean().withDefault(const Constant(false))();
  BoolColumn get selective => boolean().withDefault(const Constant(false))();
  IntColumn get insertionOrder => integer().withDefault(const Constant(0))();
  BoolColumn get caseSensitive => boolean().withDefault(const Constant(false))();
  BoolColumn get matchWholeWords => boolean().withDefault(const Constant(false))();
  BoolColumn get useGroupScoring => boolean().withDefault(const Constant(false))();
  TextColumn get automationId => text().withDefault(const Constant(''))();
  IntColumn get probability => integer().withDefault(const Constant(100))();
  IntColumn get position => integer().withDefault(const Constant(1))();
  IntColumn get depth => integer().withDefault(const Constant(4))();
  TextColumn get group => text().nullable()();
  IntColumn get groupWeight => integer().withDefault(const Constant(100))();
  BoolColumn get preventRecursion => boolean().withDefault(const Constant(false))();
  BoolColumn get delayUntilRecursion => boolean().withDefault(const Constant(false))();
  IntColumn get scanDepth => integer().withDefault(const Constant(1000))();
  TextColumn get extensionsJson => text().withDefault(const Constant('{}'))(); // JSON

  @override
  Set<Column> get primaryKey => {id};
}

/// LLM Configs table
class LlmConfigs extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get provider => text()();
  TextColumn get endpoint => text()();
  TextColumn get apiKey => text().nullable()();
  TextColumn get model => text().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  TextColumn get defaultSettingsJson => text().withDefault(const Constant('{}'))(); // JSON
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get modifiedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Personas table - user profiles for roleplay
class Personas extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get avatarPath => text().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Groups table - multi-character conversations
class Groups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get membersJson => text().withDefault(const Constant('[]'))(); // JSON array of GroupMember
  TextColumn get settingsJson => text().withDefault(const Constant('{}'))(); // JSON GroupSettings
  TextColumn get avatarPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get modifiedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Bookmarks table - chat checkpoints/branches
class Bookmarks extends Table {
  TextColumn get id => text()();
  TextColumn get chatId => text().references(Chats, #id)();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get messageId => text()(); // The message this bookmark points to
  IntColumn get messageIndex => integer()(); // Index in the chat
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tags table - for categorizing characters
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get color => text().nullable()(); // Hex color string
  TextColumn get icon => text().nullable()(); // Icon name or emoji
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Character-Tags junction table
class CharacterTags extends Table {
  TextColumn get characterId => text().references(Characters, #id)();
  TextColumn get tagId => text().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {characterId, tagId};
}

/// Global States table - Key-Value store for app settings, active configs, etc.
/// Replaces SharedPreferences for critical data that needs to be backed up.
class GlobalStates extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()(); // JSON content
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}
/// 向量文档表 · RAG 持久化
class VectorDocuments extends Table {
  TextColumn get id => text()();
  TextColumn get collectionId => text()(); // 归属集合，用 chatId 绑定
  TextColumn get content => text()(); // 原文楼层内容
  TextColumn get embedding => text().withDefault(const Constant('[]'))(); // JSON 数组，float 向量
  TextColumn get metadataJson => text().withDefault(const Constant('{}'))(); // JSON，存 role/messageId 等
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 向量集合表 · 每个 chat 一个
class VectorCollections extends Table {
  TextColumn get id => text()(); // 用 chatId
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  IntColumn get dimensions => integer().withDefault(const Constant(384))(); // bge-small-zh 384维（[CHRONICLE Phase 0] 修正512笔误）
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// [CHRONICLE Phase 1] 总结任务队列 · 异步消费，前台Timer轮询
class SummaryTasks extends Table {
  TextColumn get id => text()();
  TextColumn get chatId => text()();
  /// 待总结消息的 messageId 集合（调整A：不用index序号，删除/重排不漂移）
  TextColumn get messageIds => text().withDefault(const Constant('[]'))(); // JSON数组
  IntColumn get fromTurn => integer().withDefault(const Constant(0))();
  IntColumn get toTurn => integer().withDefault(const Constant(0))();
  /// pending / running / done / failed
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get resultJson => text().nullable()(); // LLM输出原文（解析前）
  TextColumn get error => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get finishedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// [CHRONICLE Phase 1] Wiki词条表 · 温层核心（Phase 2管线填充，Phase 1承接旧摘要迁移）
class MemoryEntries extends Table {
  TextColumn get id => text()();
  TextColumn get chatId => text()();
  /// event / state / knowledge
  TextColumn get type => text().withDefault(const Constant('event'))();
  TextColumn get title => text()();
  TextColumn get content => text()();
  IntColumn get importance => integer().withDefault(const Constant(5))(); // 1-10
  BoolColumn get alwaysInject => boolean().withDefault(const Constant(false))();
  BoolColumn get anchor => boolean().withDefault(const Constant(false))(); // 锚点：永久保留
  BoolColumn get neverEvict => boolean().withDefault(const Constant(false))();
  TextColumn get tags => text().withDefault(const Constant('[]'))(); // JSON数组
  TextColumn get entityIds => text().withDefault(const Constant('[]'))(); // JSON数组
  /// 词条来源消息（调整A：messageId集合）
  TextColumn get sourceMessageIds => text().withDefault(const Constant('[]'))(); // JSON数组
  IntColumn get turnIndex => integer().withDefault(const Constant(0))();
  BoolColumn get deprecated => boolean().withDefault(const Constant(false))(); // 过时不删（保留历史）
  /// 对应 VectorDocument.id（'chronicle_<entryId>'）
  TextColumn get vectorId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// [CHRONICLE Phase 1] 每聊天窗口状态 ·
/// H1修正：Chat模型字段不经repo持久化，窗口状态走独立Drift表（不嵌入Chat.settingsJson）
class ChronicleStates extends Table {
  TextColumn get chatId => text()();
  /// 已归档消息的 messageId 集合（JSON数组）
  TextColumn get archivedMessageIds => text().withDefault(const Constant('[]'))();
  /// ChronicleSettings 序列化JSON
  TextColumn get settingsJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {chatId};
}

/// [CHRONICLE Phase 2] Wiki实体表（人物/地点/物品/概念）
class MemoryEntities extends Table {
  TextColumn get id => text()();
  TextColumn get chatId => text()();
  TextColumn get name => text()();
  /// person / place / item / concept
  TextColumn get type => text().withDefault(const Constant('person'))();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get currentState => text().withDefault(const Constant(''))();
  TextColumn get aliases => text().withDefault(const Constant('[]'))(); // JSON数组
  TextColumn get attributes => text().withDefault(const Constant('{}'))(); // JSON
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// [CHRONICLE Phase 2] Wiki关系表（实体间）
class MemoryRelationships extends Table {
  TextColumn get id => text()();
  TextColumn get chatId => text()();
  TextColumn get fromEntityId => text()();
  TextColumn get toEntityId => text()();
  TextColumn get relationType => text().withDefault(const Constant('trust'))();
  IntColumn get strength => integer().withDefault(const Constant(0))(); // -100~100
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// [CHRONICLE Phase 2] 情感节点表（roleplay专用）
class EmotionNodes extends Table {
  TextColumn get id => text()();
  TextColumn get chatId => text()();
  TextColumn get entityId => text()();
  TextColumn get emotion => text().withDefault(const Constant(''))();
  IntColumn get intensity => integer().withDefault(const Constant(5))(); // 1-10
  TextColumn get trigger => text().withDefault(const Constant(''))();
  IntColumn get turnIndex => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// App database
@DriftDatabase(tables: [
  Characters,
  Chats,
  Messages,
  WorldInfos,
  WorldInfoEntries,
  LlmConfigs,
  Personas,
  Groups,
  Bookmarks,
  Tags,
  CharacterTags,
  GlobalStates,
  VectorCollections,
  VectorDocuments,
  SummaryTasks,
  MemoryEntries,
  ChronicleStates,
  MemoryEntities,
  MemoryRelationships,
  EmotionNodes,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
   int get schemaVersion => 18;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Handle migrations
        if (from < 2) {
          // Add swipes columns to messages
          await m.addColumn(messages, messages.swipes);
          await m.addColumn(messages, messages.currentSwipeIndex);
        }
        if (from < 3) {
          // Add personas table
          await m.createTable(personas);
        }
        if (from < 4) {
          // Add groups and bookmarks tables
          await m.createTable(groups);
          await m.createTable(bookmarks);
        }
        if (from < 5) {
          // Add characterId and characterName to messages for group chats
          await m.addColumn(messages, messages.characterId);
          await m.addColumn(messages, messages.characterName);
        }
        if (from < 6) {
          // Add alternateGreetings and characterBookJson to characters
          await m.addColumn(characters, characters.alternateGreetings);
          await m.addColumn(characters, characters.characterBookJson);
        }
        if (from < 7) {
          // Add Author's Note columns to chats
          await m.addColumn(chats, chats.authorNote);
          await m.addColumn(chats, chats.authorNoteDepth);
          await m.addColumn(chats, chats.authorNoteEnabled);
        }
        if (from < 8) {
          // Add isFavorite column to characters
          await m.addColumn(characters, characters.isFavorite);
        }
        if (from < 9) {
          // Add tags and character_tags tables
          await m.createTable(tags);
          await m.createTable(characterTags);
        }
        if (from < 10) {
          // Add attachmentsJson column to messages for image attachments
          await m.addColumn(messages, messages.attachmentsJson);
        }
        if (from < 11) {
          // Add missing SillyTavern-compatible fields to world info entries
          await m.addColumn(worldInfoEntries, worldInfoEntries.useGroupScoring);
          await m.addColumn(worldInfoEntries, worldInfoEntries.automationId);
          await m.addColumn(worldInfoEntries, worldInfoEntries.delayUntilRecursion);
        }
        if (from < 12) {
          // Add missing SillyTavern-compatible fields to world infos
          await m.addColumn(worldInfos, worldInfos.scanDepth);
          await m.addColumn(worldInfos, worldInfos.caseSensitive);
          await m.addColumn(worldInfos, worldInfos.matchWholeWords);
          await m.addColumn(worldInfos, worldInfos.useGroupScoring);
          await m.addColumn(worldInfos, worldInfos.recursionDepth);
          await m.addColumn(worldInfos, worldInfos.recursionDepth);
          await m.addColumn(worldInfos, worldInfos.extensionsJson);
        }
        if (from < 13) {
          // Add GlobalStates table for settings persistence
          await m.createTable(globalStates);
        }
        if (from < 14) {
          // Add vector storage tables for RAG persistence
          await m.createTable(vectorCollections);
          await m.createTable(vectorDocuments);
        }
        if (from < 15) {
          // per-swipe MVU variable data
          await m.addColumn(messages, messages.swipesDataJson);
        }
        if (from < 16) {
          // [空会话] 用户发过消息的持久标记,用于退出丢弃与启动清扫
          await m.addColumn(chats, chats.hasUserMessage);
          // 回填:存量会话若已有用户消息,立即置位——否则旧有效会话会被误判为空而清除
          await customStatement(
            'UPDATE chats SET has_user_message = 1 WHERE id IN '
            '(SELECT DISTINCT chat_id FROM messages WHERE role = \'user\')',
          );
        }
        if (from < 17) {
          // [CHRONICLE Phase 1] 超级记忆：总结任务队列 + Wiki词条 + 每聊天窗口状态
          await m.createTable(summaryTasks);
          await m.createTable(memoryEntries);
          await m.createTable(chronicleStates);
        }
        if (from < 18) {
          // [CHRONICLE Phase 2] Wiki系统：实体 + 关系 + 情感节点
          await m.createTable(memoryEntities);
          await m.createTable(memoryRelationships);
          await m.createTable(emotionNodes);
        }
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'KiraKira', 'database.sqlite'));
    
    // Ensure directory exists
    await file.parent.create(recursive: true);
    
    // Use foreground database (not background isolate) for reliable writes
    // Background isolate can be killed by OS when app goes to background,
    // causing data loss
    final db = NativeDatabase(
      file,
      setup: (database) {
        // Enable WAL mode for better concurrency
        database.execute('PRAGMA journal_mode=WAL;');
        // Set synchronous mode to FULL to ensure data is written to disk
        database.execute('PRAGMA synchronous=FULL;');
        // Enable foreign keys
        database.execute('PRAGMA foreign_keys=ON;');
      },
    );
    
    return db;
  });
}