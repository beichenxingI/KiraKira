import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/database/database.dart' hide Character;
import 'package:kirakira/data/database/database.dart' as db;
import 'package:kirakira/data/models/character.dart' as models;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Provider for character repository
final characterRepositoryProvider = Provider<CharacterRepository>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

/// Repository for managing character data
class CharacterRepository {
  final AppDatabase _db;
  final String _dataPath;
  static const _uuid = Uuid();

  CharacterRepository(this._db, this._dataPath);

  /// Get all characters
  Future<List<models.Character>> getAllCharacters() async {
    final rows = await _db.select(_db.characters).get();
    return rows.map(_characterFromRow).toList();
  }

  /// Get character by ID
  Future<models.Character?> getCharacter(String id) async {
    final row = await (_db.select(_db.characters)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row != null ? _characterFromRow(row) : null;
  }

  /// Search characters by name
  Future<List<models.Character>> searchCharacters(String query) async {
    final rows = await (_db.select(_db.characters)
          ..where((t) => t.name.like('%$query%')))
        .get();
    return rows.map(_characterFromRow).toList();
  }

  /// Get characters by tags
  Future<List<models.Character>> getCharactersByTag(String tag) async {
    final rows = await _db.select(_db.characters).get();
    return rows
        .map(_characterFromRow)
        .where((c) => c.tags.contains(tag))
        .toList();
  }

  /// Get favorite characters
  Future<List<models.Character>> getFavoriteCharacters() async {
    final rows = await (_db.select(_db.characters)
          ..where((t) => t.isFavorite.equals(true)))
        .get();
    return rows.map(_characterFromRow).toList();
  }

  /// Toggle character favorite status
  Future<models.Character> toggleFavorite(String characterId) async {
    final character = await getCharacter(characterId);
    if (character == null) {
      throw Exception('Character not found');
    }
    
    final updatedCharacter = character.copyWith(
      isFavorite: !character.isFavorite,
      modifiedAt: DateTime.now(),
    );
    
    await (_db.update(_db.characters)
          ..where((t) => t.id.equals(characterId)))
        .write(_characterToCompanion(updatedCharacter));
    
    return updatedCharacter;
  }

  /// Set character favorite status
  Future<models.Character> setFavorite(String characterId, bool isFavorite) async {
    final character = await getCharacter(characterId);
    if (character == null) {
      throw Exception('Character not found');
    }
    
    final updatedCharacter = character.copyWith(
      isFavorite: isFavorite,
      modifiedAt: DateTime.now(),
    );
    
    await (_db.update(_db.characters)
          ..where((t) => t.id.equals(characterId)))
        .write(_characterToCompanion(updatedCharacter));
    
    return updatedCharacter;
  }

  Future<models.Character> createCharacter(models.Character character) async {
    final id = character.id.isEmpty ? _uuid.v4() : character.id;
    final now = DateTime.now();

    final newCharacter = character.copyWith(
      id: id,
      createdAt: now,
      modifiedAt: now,
    );

    await _db.into(_db.characters).insert(_characterToCompanion(newCharacter));

    return newCharacter;
  }

  /// Update an existing character
  Future<models.Character> updateCharacter(models.Character character) async {
    final updatedCharacter = character.copyWith(modifiedAt: DateTime.now());
    
    await (_db.update(_db.characters)
          ..where((t) => t.id.equals(character.id)))
        .write(_characterToCompanion(updatedCharacter));
    
    return updatedCharacter;
  }

  /// 置顶/取消置顶（isPinned/pinnedAt 存 extensions，无需 schema 迁移）
  Future<models.Character?> togglePin(String characterId) async {
    final char = await getCharacter(characterId);
    if (char == null) return null;
    final updated = char.withPinned(!char.isPinned);
    await updateCharacter(updated);
    return updated;
  }

  /// Delete a character
  Future<void> deleteCharacter(String id) async {
    // Delete associated messages first (they reference chats)
    final chats = await (_db.select(_db.chats)..where((t) => t.characterId.equals(id))).get();
    for (final chat in chats) {
      await (_db.delete(_db.messages)..where((t) => t.chatId.equals(chat.id))).go();
      await (_db.delete(_db.bookmarks)..where((t) => t.chatId.equals(chat.id))).go();
    }
    
    // Delete associated chats
    await (_db.delete(_db.chats)..where((t) => t.characterId.equals(id))).go();
    
    // Delete associated world infos and their entries (character-specific lorebooks)
    final worldInfos = await (_db.select(_db.worldInfos)..where((t) => t.characterId.equals(id))).get();
    for (final worldInfo in worldInfos) {
      await (_db.delete(_db.worldInfoEntries)..where((t) => t.worldInfoId.equals(worldInfo.id))).go();
    }
    await (_db.delete(_db.worldInfos)..where((t) => t.characterId.equals(id))).go();
    
    // Delete associated character tags
    await (_db.delete(_db.characterTags)..where((t) => t.characterId.equals(id))).go();
    
    // [紧急修复-F] 清理角色级正则（独立表，防幽灵行/同 id 重导 PK 冲突）
    await (_db.delete(_db.regexScripts)
          ..where((t) => t.scope.equals('character') & t.characterId.equals(id)))
        .go();
    
    // Delete the character
    await (_db.delete(_db.characters)..where((t) => t.id.equals(id))).go();
    
    // Delete avatar file if exists
    await _deleteCharacterAvatar(id);
  }

  /// Save character avatar
  Future<String> saveAvatar(String characterId, Uint8List imageData) async {
    final avatarDir = Directory(p.join(_dataPath, 'avatars'));
    if (!await avatarDir.exists()) {
      await avatarDir.create(recursive: true);
    }
    
    final avatarPath = p.join(avatarDir.path, '$characterId.png');
    await File(avatarPath).writeAsBytes(imageData);
    
    // Update character with avatar path
    await (_db.update(_db.characters)
          ..where((t) => t.id.equals(characterId)))
        .write(CharactersCompanion(avatarPath: Value(avatarPath)));
    
    return avatarPath;
  }

  /// Get character count
  Future<int> getCharacterCount() async {
    final count = await _db.select(_db.characters).get();
    return count.length;
  }
  
  /// Parse character card from V1/V2/V3 format JSON
  models.Character _parseCharacterCard(Map<String, dynamic> json, String characterId) {
    String name = '';
    String description = '';
    String personality = '';
    String scenario = '';
    String firstMessage = '';
    String exampleMessages = '';
    String systemPrompt = '';
    String postHistoryInstructions = '';
    String creatorNotes = '';
    List<String> tags = [];
    String creator = '';
    String version = '';
    List<String> alternateGreetings = [];
    Map<String, dynamic> extensions = {};
    models.CharacterBook? characterBook;

    // Check for V3 format
    if (json.containsKey('spec') && json.containsKey('data')) {
      final data = json['data'] as Map<String, dynamic>? ?? {};
      name = data['name'] as String? ?? '';
      description = data['description'] as String? ?? '';
      personality = data['personality'] as String? ?? '';
      scenario = data['scenario'] as String? ?? '';
      firstMessage = data['first_mes'] as String? ?? '';
      exampleMessages = data['mes_example'] as String? ?? '';
      systemPrompt = data['system_prompt'] as String? ?? '';
      postHistoryInstructions = data['post_history_instructions'] as String? ?? '';
      creatorNotes = data['creator_notes'] as String? ?? '';
      tags = (data['tags'] as List<dynamic>?)?.cast<String>() ?? [];
      creator = data['creator'] as String? ?? '';
      version = data['character_version'] as String? ?? '';
      alternateGreetings = (data['alternate_greetings'] as List<dynamic>?)?.cast<String>() ?? [];
      extensions = data['extensions'] as Map<String, dynamic>? ?? {};
      if (data['character_book'] != null) {
        characterBook = models.CharacterBook.fromJson(data['character_book'] as Map<String, dynamic>);
      }
    } 
    // Check for V2 format (has data field but no spec)
    else if (json.containsKey('data')) {
      final data = json['data'] as Map<String, dynamic>? ?? {};
      name = data['name'] as String? ?? json['name'] as String? ?? '';
      description = data['description'] as String? ?? '';
      personality = data['personality'] as String? ?? '';
      scenario = data['scenario'] as String? ?? '';
      firstMessage = data['first_mes'] as String? ?? '';
      exampleMessages = data['mes_example'] as String? ?? '';
      systemPrompt = data['system_prompt'] as String? ?? '';
      postHistoryInstructions = data['post_history_instructions'] as String? ?? '';
      creatorNotes = data['creator_notes'] as String? ?? '';
      tags = (data['tags'] as List<dynamic>?)?.cast<String>() ?? [];
      creator = data['creator'] as String? ?? '';
      version = data['character_version'] as String? ?? '';
      alternateGreetings = (data['alternate_greetings'] as List<dynamic>?)?.cast<String>() ?? [];
      extensions = data['extensions'] as Map<String, dynamic>? ?? {};
      if (data['character_book'] != null) {
        characterBook = models.CharacterBook.fromJson(data['character_book'] as Map<String, dynamic>);
      }
    }
    // V1 format (flat structure)
    else {
      name = json['name'] as String? ?? json['char_name'] as String? ?? '';
      description = json['description'] as String? ?? json['char_persona'] as String? ?? '';
      personality = json['personality'] as String? ?? '';
      scenario = json['scenario'] as String? ?? json['world_scenario'] as String? ?? '';
      firstMessage = json['first_mes'] as String? ?? json['char_greeting'] as String? ?? '';
      exampleMessages = json['mes_example'] as String? ?? json['example_dialogue'] as String? ?? '';
    }
    
    return models.Character(
      id: characterId,
      name: name,
      description: description,
      personality: personality,
      scenario: scenario,
      firstMessage: firstMessage,
      alternateGreetings: alternateGreetings,
      exampleMessages: exampleMessages,
      systemPrompt: systemPrompt,
      postHistoryInstructions: postHistoryInstructions,
      creatorNotes: creatorNotes,
      tags: tags,
      creator: creator,
      version: version,
      characterBook: characterBook,
      extensions: extensions,
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
    );
  }

  /// Import character from JSON data
  Future<models.Character> importFromJson(Map<String, dynamic> json) async {
    final character = _parseCharacterCard(json, _uuid.v4());
    return createCharacter(character);
  }

  /// Export character to JSON (V3 format)
  Map<String, dynamic> exportToJson(models.Character character) {
    return {
      'spec': 'chara_card_v3',
      'spec_version': '3.0',
      'data': {
        'name': character.name,
        'description': character.description,
        'personality': character.personality,
        'scenario': character.scenario,
        'first_mes': character.firstMessage,
        'mes_example': character.exampleMessages,
        'system_prompt': character.systemPrompt,
        'post_history_instructions': character.postHistoryInstructions,
        'creator_notes': character.creatorNotes,
        'tags': character.tags,
        'creator': character.creator,
        'character_version': character.version,
        'extensions': character.extensions,
      },
    };
  }

  // Private helpers
  
  models.Character _characterFromRow(db.Character row) {
    return models.Character(
      id: row.id,
      name: row.name,
      description: row.description,
      personality: row.personality,
      scenario: row.scenario,
      firstMessage: row.firstMessage,
      alternateGreetings: _parseJsonList(row.alternateGreetings),
      exampleMessages: row.exampleDialogue,
      systemPrompt: row.systemPrompt,
      postHistoryInstructions: row.postHistoryInstructions,
      creatorNotes: row.creatorNotes,
      tags: _parseJsonList(row.tags),
      creator: row.creator,
      version: row.characterVersion,
      assets: _parseAssets(row.assetsJson, row.avatarPath),
      characterBook: _parseCharacterBook(row.characterBookJson),
      extensions: _parseJsonMap(row.extensionsJson),
      isFavorite: row.isFavorite,
      createdAt: row.createdAt,
      modifiedAt: row.modifiedAt,
    );
  }
  models.CharacterAssets? _parseAssets(String assetsJson, String? avatarPath) {
    try {
      final map = jsonDecode(assetsJson) as Map<String, dynamic>;
      if (map.isNotEmpty) {
        final assets = models.CharacterAssets.fromJson(map);
        // 兼容：老数据 assetsJson 为空但有独立 avatarPath 列
        if (assets.avatarPath == null && avatarPath != null) {
          return assets.copyWith(avatarPath: avatarPath);
        }
        return assets;
      }
    } catch (_) {}
    // 回退：老角色卡只有 avatarPath 列
    return avatarPath != null
        ? models.CharacterAssets(avatarPath: avatarPath)
        : null;
  }

  CharactersCompanion _characterToCompanion(models.Character character) {
    return CharactersCompanion(
      id: Value(character.id),
      name: Value(character.name),
      description: Value(character.description),
      personality: Value(character.personality),
      scenario: Value(character.scenario),
      firstMessage: Value(character.firstMessage),
      alternateGreetings: Value(jsonEncode(character.alternateGreetings)),
      exampleDialogue: Value(character.exampleMessages),
      systemPrompt: Value(character.systemPrompt),
      postHistoryInstructions: Value(character.postHistoryInstructions),
      creatorNotes: Value(character.creatorNotes),
      tags: Value(jsonEncode(character.tags)),
      creator: Value(character.creator),
      characterVersion: Value(character.version),
      avatarPath: Value(character.assets?.avatarPath),
      assetsJson: Value(character.assets != null ? jsonEncode(character.assets!.toJson()) : '{}'),
      characterBookJson: Value(_serializeCharacterBook(character.characterBook)),
      extensionsJson: Value(jsonEncode(character.extensions)),
      isFavorite: Value(character.isFavorite),
      createdAt: Value(character.createdAt),
      modifiedAt: Value(character.modifiedAt),
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

  Map<String, dynamic> _parseJsonMap(String json) {
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  models.CharacterBook? _parseCharacterBook(String json) {
    if (json.isEmpty) return null;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return models.CharacterBook.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  String _serializeCharacterBook(models.CharacterBook? book) {
    if (book == null) return '';
    return jsonEncode(book.toJson());
  }

  Future<void> _deleteCharacterAvatar(String characterId) async {
    try {
      final avatarPath = p.join(_dataPath, 'avatars', '$characterId.png');
      final file = File(avatarPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Failed to delete avatar: $e');
    }
  }
}