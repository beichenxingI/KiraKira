import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:kirakira/data/models/regex_script.dart' as models;
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
  /// Whether the user has ever sent a message: once set, never unset.
  /// No flag when leaving the chat page → cascade discard; leftover no-flag
  /// chats are handled by startup cleanup. A persisted flag is used instead
  /// of counting messages(user) in real time to cover the "sent then deleted"
  /// boundary (having ever sent counts).
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
/// Vector documents table - RAG persistence
class VectorDocuments extends Table {
  TextColumn get id => text()();
  TextColumn get collectionId => text()(); // Owning collection, bound by chatId
  TextColumn get content => text()(); // Original message (floor) text content
  TextColumn get embedding => text().withDefault(const Constant('[]'))(); // JSON array of floats (vector)
  TextColumn get metadataJson => text().withDefault(const Constant('{}'))(); // JSON, stores role/messageId etc.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Vector collections table - one per chat
class VectorCollections extends Table {
  TextColumn get id => text()(); // Uses chatId
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  IntColumn get dimensions => integer().withDefault(const Constant(384))(); // bge-small-zh, 384 dimensions
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Chronicle summary task queue for asynchronous processing, polled by a foreground timer
class SummaryTasks extends Table {
  TextColumn get id => text()();
  TextColumn get chatId => text()();
  /// Set of messageIds to summarize (uses messageIds instead of index
  /// numbers, so deletion/reordering does not shift them)
  TextColumn get messageIds => text().withDefault(const Constant('[]'))(); // JSON array
  IntColumn get fromTurn => integer().withDefault(const Constant(0))();
  IntColumn get toTurn => integer().withDefault(const Constant(0))();
  /// pending / running / done / failed
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get resultJson => text().nullable()(); // Raw LLM output (before parsing)
  TextColumn get error => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get finishedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Wiki entries table - core of the warm zone (filled by the Phase 2 pipeline;
/// handled legacy summary migration)
class MemoryEntries extends Table {
  TextColumn get id => text()();
  TextColumn get chatId => text()();
  /// event / state / knowledge
  TextColumn get type => text().withDefault(const Constant('event'))();
  TextColumn get title => text()();
  TextColumn get content => text()();
  IntColumn get importance => integer().withDefault(const Constant(5))(); // 1-10
  BoolColumn get alwaysInject => boolean().withDefault(const Constant(false))();
  BoolColumn get anchor => boolean().withDefault(const Constant(false))(); // Anchor: kept permanently
  BoolColumn get neverEvict => boolean().withDefault(const Constant(false))();
  TextColumn get tags => text().withDefault(const Constant('[]'))(); // JSON array
  TextColumn get entityIds => text().withDefault(const Constant('[]'))(); // JSON array
  /// Source messages of the entry (set of messageIds)
  TextColumn get sourceMessageIds => text().withDefault(const Constant('[]'))(); // JSON array
  IntColumn get turnIndex => integer().withDefault(const Constant(0))();
  BoolColumn get deprecated => boolean().withDefault(const Constant(false))(); // Deprecated but not deleted (keeps history)
  /// Corresponds to VectorDocument.id ('chronicle_<entryId>')
  TextColumn get vectorId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-chat window archive state.
/// Window state lives in this dedicated Drift table (not embedded in
/// Chat.settingsJson); the Chat model field is not persisted through the repo.
class ChronicleStates extends Table {
  TextColumn get chatId => text()();
  /// Set of archived messageIds (JSON array)
  TextColumn get archivedMessageIds => text().withDefault(const Constant('[]'))();
  /// Serialized ChronicleSettings JSON
  TextColumn get settingsJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {chatId};
}

/// Wiki entities table (persons/places/items/concepts)
class MemoryEntities extends Table {
  TextColumn get id => text()();
  TextColumn get chatId => text()();
  TextColumn get name => text()();
  /// person / place / item / concept
  TextColumn get type => text().withDefault(const Constant('person'))();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get currentState => text().withDefault(const Constant(''))();
  TextColumn get aliases => text().withDefault(const Constant('[]'))(); // JSON array
  TextColumn get attributes => text().withDefault(const Constant('{}'))(); // JSON
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Wiki relationships table (between entities)
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

/// Emotion nodes table (roleplay-specific)
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

/// Dedicated regex scripts table (regex no longer stored in extensions JSON,
/// eliminating lost-update races).
/// DataClassName rename: Drift's default singularization of the table name
/// would generate `RegexScript`, which conflicts with the model class in
/// data/models/regex_script.dart, hence RegexScriptRow.
@DataClassName('RegexScriptRow')
class RegexScripts extends Table {
  TextColumn get id => text()();
  /// 'global' or 'character'
  TextColumn get scope => text().withDefault(const Constant('global'))();
  /// Character ID (when scope='character')
  TextColumn get characterId => text().nullable()();
  /// Serialized RegexScript JSON
  TextColumn get scriptJson => text().withDefault(const Constant('{}'))();
  /// Sort order (lower = earlier)
  IntColumn get order => integer().withDefault(const Constant(0))();
  /// Whether disabled
  BoolColumn get disabled => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

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
  RegexScripts,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
   int get schemaVersion => 19;

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
         // Persisted flag for whether a chat ever had a user message; used for
         // discard-on-exit and startup cleanup.
         // Fault tolerance: addColumn throws SqliteException(1) if the column
         // already exists; caught and continued (prevents duplicate migration)
         try {
           await m.addColumn(chats, chats.hasUserMessage);
         } catch (e) {
           // Silently ignore if the column already exists (duplicate column name)
           if (!e.toString().toLowerCase().contains('duplicate')) rethrow;
         }
         // Backfill: existing chats that already have user messages are flagged
         // immediately, otherwise valid legacy chats would be misjudged as empty
         // and purged (backfill is safe even if the column already exists - idempotent)
         await customStatement(
           'UPDATE chats SET has_user_message = 1 WHERE id IN '
           '(SELECT DISTINCT chat_id FROM messages WHERE role = \'user\')',
         );
       }
        if (from < 17) {
          // Super memory: summary task queue + wiki entries + per-chat window state
          await m.createTable(summaryTasks);
          await m.createTable(memoryEntries);
          await m.createTable(chronicleStates);
        }
        if (from < 18) {
          // Wiki system: entities + relationships + emotion nodes
          await m.createTable(memoryEntities);
          await m.createTable(memoryRelationships);
          await m.createTable(emotionNodes);
        }
        if (from < 19) {
          // Create regex_scripts table (dedicated regex table, schema v18→v19)
          await m.createTable(regexScripts);
          debugPrint('[Migration] v18→v19: 创建 regex_scripts 表');

          // Migrate existing character-scoped regex scripts (extensions['regex_scripts'] → table)
          // Legacy data is kept (dual-read fallback); failures do not block startup.
          debugPrint('[Migration] ═══ 开始迁移角色级正则 ═══');
          try {
            final chars = await select(characters).get();
            var migratedCharCount = 0;
            var migratedScriptCount = 0;
            debugPrint('[Migration] 共 ${chars.length} 个角色待检查');
            for (final char in chars) {
              debugPrint('[Migration] 处理角色: ${char.name} (${char.id})');
              try {
                final extensions =
                    jsonDecode(char.extensionsJson) as Map<String, dynamic>;
                final rawList = extensions['regex_scripts'];
                if (rawList is! List || rawList.isEmpty) {
                  debugPrint('[Migration]   无 regex_scripts 字段或为空');
                  continue;
                }
                debugPrint('[Migration]   找到 ${rawList.length} 条正则');
                // Per-entry independent try-catch + ID deduplication:
                // a single PK conflict/parse failure no longer aborts the rest
                // of this character's migration (old code would migrate partially)
                final seenRowIds = <String>{};
                for (var i = 0; i < rawList.length; i++) {
                  final raw = rawList[i];
                  if (raw is! Map) {
                    debugPrint('[Migration]   ⚠️ 第 $i 条非 Map，跳过');
                    continue;
                  }
                  try {
                    final script = _migrateRegexScript(
                      Map<String, dynamic>.from(raw),
                      char.id,
                      i,
                    );
                    if (script == null) {
                      debugPrint('[Migration]   ⚠️ 第 $i 条无法解析，跳过');
                      debugPrint('[Migration]   原始数据: $raw');
                      continue;
                    }
                    var rowId = script.id;
                    if (!seenRowIds.add(rowId)) {
                      rowId =
                          '${char.id}_migrated_dup_${DateTime.now().microsecondsSinceEpoch}_$i';
                      debugPrint('[Migration]   ⚠️ 第 $i 条 id 重复，改用 $rowId');
                    }
                    await into(regexScripts).insert(RegexScriptsCompanion(
                      id: Value(rowId),
                      scope: const Value('character'),
                      characterId: Value(char.id),
                      scriptJson: Value(jsonEncode(script.toJson())),
                      order: Value(i),
                      disabled: Value(script.disabled),
                      createdAt: Value(script.createdAt),
                      updatedAt: Value(script.updatedAt),
                    ));
                    migratedScriptCount++;
                    debugPrint('[Migration]   ✅ 第 $i 条迁移成功 id=$rowId');
                  } catch (scriptError) {
                    debugPrint('[Migration]   ❌ 第 $i 条迁移失败: $scriptError');
                    debugPrint('[Migration]   原始数据: $raw');
                  }
                }
                migratedCharCount++;
              } catch (charError) {
                debugPrint('[Migration]   ❌ 角色 ${char.name} 处理失败: $charError');
                // Continue migrating other characters
              }
            }
            debugPrint(
                '[Migration] ═══ 角色级正则迁移完成: $migratedCharCount/${chars.length} 个角色, $migratedScriptCount 条脚本 ═══');
            debugPrint(
                '[Migration] 全局正则迁移由首启逻辑处理（SharedPreferences → 表）');
          } catch (migrationError, migrationStack) {
            debugPrint('[Migration] ❌ 正则迁移失败: $migrationError');
            debugPrint('[Migration] StackTrace: $migrationStack');
            // Migration failure does not block app startup (legacy extensions
            // data remains, dual-read fallback)
          }
        }
      },
    );
  }
}

/// Single regex script migration: native format first, SillyTavern format as
/// fallback (hard cast to prevent crashes).
/// Returns null when parsing fails (that entry is skipped without blocking
/// the rest of the migration).
models.RegexScript? _migrateRegexScript(
  Map<String, dynamic> raw,
  String characterId,
  int index,
) {
  try {
    final s = models.RegexScript.fromJson(raw);
    // Row ID gets a character prefix (prevents PK conflicts for the same ID
    // across characters, idempotent to avoid prefix stacking);
    // empty IDs fall back to the index
    final resolvedId = s.id.isEmpty
        ? '${characterId}_migrated_$index'
        : (s.id.startsWith('${characterId}_') ? s.id : '${characterId}_${s.id}');
    return s.copyWith(id: resolvedId, characterId: s.characterId ?? characterId);
  } catch (_) {}
  try {
    final s = models.RegexScript.fromSillyTavernJson(
      raw,
      newId: '${characterId}_migrated_$index',
    );
    return s.copyWith(
      scriptType: models.RegexScriptType.character,
      characterId: characterId,
    );
  } catch (_) {
    return null;
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