import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:kirakira/data/models/character.dart';
import 'package:kirakira/domain/services/png_character_card_parser.dart';
import 'package:kirakira/core/utils/path_utils.dart';
import 'package:path/path.dart' as p;
import 'package:kirakira/data/models/world_info.dart';
import 'package:kirakira/data/repositories/world_info_repository.dart';
import 'package:kirakira/data/repositories/regex_script_repository.dart';

/// Service for importing and exporting character cards
class ImportService {
  final String _dataPath;

  ImportService(this._dataPath);

  /// Import character from PNG file (extracts embedded JSON from tEXt chunk)
  Future<Character> importFromPng(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    // DIAGNOSTIC: log file info and dump to temp
    debugPrint('[PNG-FILE] path=$filePath');
    debugPrint('[PNG-FILE] size=${bytes.length}');
    debugPrint('[PNG-FILE] exists=${await file.exists()}');
    if (bytes.isNotEmpty) {
      final sig = String.fromCharCodes(bytes.take(8));
      debugPrint('[PNG-FILE] first8bytes=$sig');
      final tempPath = '$filePath.dump.bin';
      await File(tempPath).writeAsBytes(bytes);
      debugPrint('[PNG-FILE] dumped to=$tempPath');
    try {
      File('$filePath.diagnostic.txt').writeAsStringSync('PNG file at: $filePath\nSize: ${bytes.length} bytes\nFirst 8 bytes: ${bytes.take(8).toList()}');
      debugPrint('[PNG-FILE] diagnostic info saved');
    } catch (_) {}
    }

    return importFromPngBytes(bytes);
  }

  /// Import character from PNG bytes (extracts embedded JSON from tEXt chunk)
  Future<Character> importFromPngBytes(Uint8List bytes) async {
    // Try the dedicated parser
    final data = await PngCharacterCardParser.parse(bytes, sourcePath: null);
    if (data == null) { throw Exception('No character data found in PNG - Diagnostic report saved to Downloads folder'); }

    // Parse character from JSON
    final character = _parseCharacterJson(data);

    // Save the avatar
    final avatarPath = await _saveAvatar(character.id, bytes);

    return character.copyWith(
      assets: CharacterAssets(avatarPath: avatarPath),
    );
  }

  /// Import character from CharX archive
  Future<Character> importFromCharX(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    
    // Extract archive
    final archive = ZipDecoder().decodeBytes(bytes);
    
    // Find card.json
    ArchiveFile? cardFile;
    ArchiveFile? avatarFile;
    
    for (final file in archive) {
      if (file.name == 'card.json') {
        cardFile = file;
      } else if (file.name.endsWith('.png') || file.name.endsWith('.jpg')) {
        avatarFile = file;
      }
    }
    
    if (cardFile == null) {
      throw Exception('No card.json found in CharX archive');
    }
    
    // Parse JSON
    final json = utf8.decode(cardFile.content as List<int>);
    final data = jsonDecode(json) as Map<String, dynamic>;
    
    // Parse character
    final character = _parseCharacterJson(data);
    
    // Save avatar if found
    String? avatarPath;
    if (avatarFile != null) {
      avatarPath = await _saveAvatar(character.id, Uint8List.fromList(avatarFile.content as List<int>));
    }
    
    return character.copyWith(
      assets: avatarPath != null ? CharacterAssets(avatarPath: avatarPath) : null,
    );
  }

  /// Import character from JSON string
  Future<Character> importFromJson(String json) async {
    final data = jsonDecode(json) as Map<String, dynamic>;
    return _parseCharacterJson(data);
  }

  /// Export character to PNG with embedded data
  ///
  /// When worldInfoRepo is non-null, assembles characterBook from the world_infos table (live data)
  /// replacing the import snapshot (fixes stale worldbook export); when null, keeps the snapshot (legacy fallback).
  Future<Uint8List> exportToPng(
    Character character,
    Uint8List? avatarData, {
    WorldInfoRepository? worldInfoRepo,
    RegexScriptRepository? regexRepo,
  }) async {
    // Get avatar data
    Uint8List imageBytes;
    if (avatarData != null) {
      imageBytes = avatarData;
    } else if (character.assets?.avatarPath != null) {
      final avatarFile = File(character.assets!.avatarPath!);
      if (await avatarFile.exists()) {
        imageBytes = await avatarFile.readAsBytes();
      } else {
        // Create a default placeholder PNG
        imageBytes = _createPlaceholderPng();
      }
    } else {
      imageBytes = _createPlaceholderPng();
    }

    // Live assembly: replace the import snapshot when the world_infos table has bound book entries
    Character exportChar = character;
    if (worldInfoRepo != null) {
      final liveBook =
          await assembleCharacterBookFromRepo(worldInfoRepo, character.id);
      if (liveBook != null) exportChar = character.copyWith(characterBook: liveBook);
    }

    // Sync the latest regex scripts before export
    if (regexRepo != null) {
      final latestRegexScripts = await regexRepo.getForCharacter(character.id);
      if (latestRegexScripts.isNotEmpty) {
        exportChar = exportChar.copyWith(
          extensions: {
            ...exportChar.extensions,
            'regex_scripts': latestRegexScripts.map((s) => s.toJson()).toList(),
          },
        );
      }
    }

    // Create character JSON
    final json = _characterToV3Json(exportChar);
    final jsonString = jsonEncode(json);
    final encoded = base64Encode(utf8.encode(jsonString));

    // Embed in PNG
    return _embedPngTextChunk(imageBytes, 'chara', encoded);
  }

  /// Export character to CharX archive
  ///
  /// When worldInfoRepo is non-null, assembles characterBook from the world_infos table (live data)
  /// replacing the import snapshot (fixes stale worldbook export); when null, keeps the snapshot (legacy fallback).
  Future<Uint8List> exportToCharX(
    Character character,
    Uint8List? avatarData, {
    WorldInfoRepository? worldInfoRepo,
    RegexScriptRepository? regexRepo,
  }) async {
    final encoder = ZipEncoder();
    final archive = Archive();

    // Live assembly: replace the import snapshot when the world_infos table has bound book entries
    Character exportChar = character;
    if (worldInfoRepo != null) {
      final liveBook =
          await assembleCharacterBookFromRepo(worldInfoRepo, character.id);
      if (liveBook != null) exportChar = character.copyWith(characterBook: liveBook);
    }

    // Sync the latest regex scripts before export
    if (regexRepo != null) {
      final latestRegexScripts = await regexRepo.getForCharacter(character.id);
      if (latestRegexScripts.isNotEmpty) {
        exportChar = exportChar.copyWith(
          extensions: {
            ...exportChar.extensions,
            'regex_scripts': latestRegexScripts.map((s) => s.toJson()).toList(),
          },
        );
      }
    }

    // Add card.json
    final json = _characterToV3Json(exportChar);
    final jsonBytes = utf8.encode(jsonEncode(json));
    archive.addFile(ArchiveFile('card.json', jsonBytes.length, jsonBytes));
    
    // Add avatar if available
    if (avatarData != null) {
      archive.addFile(ArchiveFile('avatar.png', avatarData.length, avatarData));
    } else if (character.assets?.avatarPath != null) {
      final avatarFile = File(character.assets!.avatarPath!);
      if (await avatarFile.exists()) {
        final bytes = await avatarFile.readAsBytes();
        archive.addFile(ArchiveFile('avatar.png', bytes.length, bytes));
      }
    }
    
    return Uint8List.fromList(encoder.encode(archive)!);
  }

  /// Export character to JSON
  ///
  /// When worldInfoRepo is non-null, assembles characterBook from the world_infos table (live data)
  /// replacing the import snapshot (fixes stale worldbook export); when null, keeps the snapshot (legacy fallback).
  /// Changed from sync to async (assembly requires a database query); both callers already run in async contexts.
  Future<String> exportToJson(
    Character character, {
    WorldInfoRepository? worldInfoRepo,
    RegexScriptRepository? regexRepo,
  }) async {
    // Live assembly: replace the import snapshot when the world_infos table has bound book entries
    Character exportChar = character;
    if (worldInfoRepo != null) {
      final liveBook =
          await assembleCharacterBookFromRepo(worldInfoRepo, character.id);
      if (liveBook != null) exportChar = character.copyWith(characterBook: liveBook);
    }

    // Sync the latest regex scripts before export
    if (regexRepo != null) {
      final latestRegexScripts = await regexRepo.getForCharacter(character.id);
      if (latestRegexScripts.isNotEmpty) {
        exportChar = exportChar.copyWith(
          extensions: {
            ...exportChar.extensions,
            'regex_scripts': latestRegexScripts.map((s) => s.toJson()).toList(),
          },
        );
      }
    }

    final json = _characterToV3Json(exportChar);
    return jsonEncode(json);
  }

  // Private methods
  
  Character _parseCharacterJson(Map<String, dynamic> json) {
    // Parse entry point: spec and branch determination
    print('[IMP-1] entry keys=${json.keys.toList()} spec=${json['spec']} hasData=${json.containsKey('data')}');
    String name = '';
    String description = '';
    String personality = '';
    String scenario = '';
    String firstMessage = '';
    List<String> alternateGreetings = [];
    String exampleMessages = '';
    String systemPrompt = '';
    String postHistoryInstructions = '';
    String creatorNotes = '';
    List<String> tags = [];
    String creator = '';
    String version = '';
    Map<String, dynamic> extensions = {};
    CharacterBook? characterBook;

    // AICC-Chat format (spec='aicc_card', specific to aicharactercards.com, e.g. Rin Card Forge exports).
    // Structured fields: personality/dialogue/prompts/world/metadata are all Maps; a flat cast would break.
    if (json['spec'] == 'aicc_card' && json.containsKey('data')) {
      final data = json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : <String, dynamic>{};
      name = _castStringSafe(data['name']);
      // AICC: general_description is the main description; appearance/background_history are AICC extensions (passed through to extensions)
      description = _castStringSafe(data['general_description']);
      scenario = _castStringSafe(data['world_setting_context']);
      // AICC: personality (structured core/behavior_rules/speech_style) converted to readable text
      final personalityRaw = data['personality'];
      if (personalityRaw is Map) {
        personality = _aiccPersonalityToString(personalityRaw);
      } else {
        personality = _castStringSafe(personalityRaw);
      }
      // AICC: dialogue.greetings[0] = first_mes, greetings[1..] = alternate_greetings
      final dialogue = data['dialogue'] is Map ? Map<String, dynamic>.from(data['dialogue'] as Map) : null;
      final greetings = dialogue?['greetings'];
      if (greetings is List) {
        final gList = greetings.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
        if (gList.isNotEmpty) {
          firstMessage = gList.first;
          if (gList.length > 1) alternateGreetings = gList.sublist(1);
        }
      }
      // AICC: dialogue.dialogue_examples maps to mes_example (ST semantics: <START> separates example dialogues)
      final examples = dialogue?['dialogue_examples'];
      if (examples is List) {
        final exList = examples.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
        if (exList.isNotEmpty) exampleMessages = exList.join('\n<START>\n');
      }
      // AICC: prompts.system_prompt / post_history_instructions
      final prompts = data['prompts'] is Map ? Map<String, dynamic>.from(data['prompts'] as Map) : null;
      systemPrompt = _castStringSafe(prompts?['system_prompt']);
      postHistoryInstructions = _castStringSafe(prompts?['post_history_instructions']);
      // AICC: metadata.creator/notes/version/tags (tags also accepts a comma-separated String)
      final metadata = data['metadata'] is Map ? Map<String, dynamic>.from(data['metadata'] as Map) : null;
      creator = _castStringSafe(metadata?['creator']);
      creatorNotes = _castStringSafe(metadata?['notes']);
      version = _castStringSafe(metadata?['version']);
      tags = _parseTagsSafe(metadata?['tags']);
      // AICC: world.worldbook_entries maps to character_book (not created when empty)
      final world = data['world'] is Map ? Map<String, dynamic>.from(data['world'] as Map) : null;
      final wbEntries = world?['worldbook_entries'];
      final hasWbEntries = (wbEntries is List && wbEntries.isNotEmpty) ||
          (wbEntries is Map && wbEntries.isNotEmpty);
      if (hasWbEntries) {
        characterBook = _parseCharacterBook({
          'name': _castStringSafe(world?['worldbook_name']),
          'entries': wbEntries,
          'extensions': <String, dynamic>{},
        });
      }
      // Pass AICC-specific fields through to extensions (convention: app-specific data goes in namespaced extensions)
      final aiccExt = <String, dynamic>{};
      void keep(String key, dynamic v) {
        if (v != null && (v is! String || v.isNotEmpty)) aiccExt[key] = v;
      }
      keep('appearance', data['appearance']);
      keep('background_history', data['background_history']);
      keep('group_only_greetings', dialogue?['group_only_greetings']);
      keep('depth_prompt', prompts?['depth_prompt']);
      keep('card_format', metadata?['card_format']);
      keep('features', metadata?['features']);
      keep('aicc_id', json['aicc_id']);
      keep('aicc_version', json['aicc_version']);
      aiccExt['spec'] = 'aicc_card';
      final dataExtensions = data['extensions'];
      extensions = dataExtensions is Map
          ? {...Map<String, dynamic>.from(dataExtensions), 'aicc': aiccExt}
          : {'aicc': aiccExt};
      print('[IMP-1] AICC-Chat card: name=$name greetings=${greetings is List ? greetings.length : 0} '
          'examples=${examples is List ? examples.length : 0}');
    }
    // Check for V3 format (also matches V2 with spec field)
    else if (json.containsKey('spec') && json.containsKey('data')) {
      final data = json['data'] as Map<String, dynamic>? ?? {};
      name = _castStringSafe(data['name']);
      description = _castStringSafe(data['description']);
      // AICC compat: V2 core field tolerance — Map/List values (e.g. structured personality) are passed through as JSON strings
      personality = _castStringSafe(data['personality']);
      scenario = _castStringSafe(data['scenario']);
      firstMessage = _castStringSafe(data['first_mes']);
      alternateGreetings = _parseStringList(data['alternate_greetings']);
      exampleMessages = _castStringSafe(data['mes_example']);
      systemPrompt = _castStringSafe(data['system_prompt']);
      postHistoryInstructions = _castStringSafe(data['post_history_instructions']);
      creatorNotes = _castStringSafe(data['creator_notes']);
      // AICC compat: tags tolerance — list elements converted per-item; comma-separated String split into a list
      tags = _parseTagsSafe(data['tags']);
      creator = _castStringSafe(data['creator']);
      version = _castStringSafe(data['character_version']);
      extensions = data['extensions'] is Map
          ? Map<String, dynamic>.from(data['extensions'] as Map)
          : {};
      
      // Parse character book (embedded lorebook)
      if (data['character_book'] != null) {
        print('[ImportService] Found character_book in data, parsing...');
        characterBook = _parseCharacterBook(data['character_book'] as Map<String, dynamic>);
        print('[ImportService] Parsed character_book with ${characterBook.entries.length ?? 0} entries');
      } else {
        print('[ImportService] No character_book found in data. Data keys: ${data.keys.toList()}');
      }

      // [IMP-2] data field survey (report when non-empty)
      void f(String k, dynamic v) {
        final ok = v != null && ('$v'.isNotEmpty);
        print('[IMP-2] $k=${ok ? (v is List ? 'list(${v.length})' : (v is String ? 'len=${v.length}' : v)) : 'EMPTY'}');
      }
      f('name', name);
      f('description', description.isEmpty ? null : description);
      f('personality', personality.isEmpty ? null : personality);
      f('scenario', scenario.isEmpty ? null : scenario);
      f('first_mes', firstMessage.isEmpty ? null : firstMessage);
      f('alternate_greetings', alternateGreetings);
      f('mes_example', exampleMessages.isEmpty ? null : exampleMessages);
      f('system_prompt', systemPrompt.isEmpty ? null : systemPrompt);
      f('post_history_instructions', postHistoryInstructions.isEmpty ? null : postHistoryInstructions);
      f('creator_notes', creatorNotes.isEmpty ? null : creatorNotes);
      f('tags', tags);
      f('creator', creator.isEmpty ? null : creator);
      f('character_version', version.isEmpty ? null : version);

      // [IMP-4] Extensions top-level keys and regex_scripts presence
      print('[IMP-4] extKeys=${extensions.keys.toList()} regexScriptsCount=${(extensions['regex_scripts'] as List<dynamic>?)?.length ?? 'null'}');
    }
    // Check for V2 format
    else if (json.containsKey('data')) {
      final data = json['data'] as Map<String, dynamic>? ?? {};
      name = _castStringSafe(data['name']) != ''
          ? _castStringSafe(data['name'])
          : _castStringSafe(json['name']);
      description = _castStringSafe(data['description']);
      // AICC compat: V2 core field tolerance — Map/List values passed through as JSON strings
      personality = _castStringSafe(data['personality']);
      scenario = _castStringSafe(data['scenario']);
      firstMessage = _castStringSafe(data['first_mes']);
      alternateGreetings = _parseStringList(data['alternate_greetings']);
      exampleMessages = _castStringSafe(data['mes_example']);
      systemPrompt = _castStringSafe(data['system_prompt']);
      postHistoryInstructions = _castStringSafe(data['post_history_instructions']);
      creatorNotes = _castStringSafe(data['creator_notes']);
      // AICC compat: tags tolerance
      tags = _parseTagsSafe(data['tags']);
      creator = _castStringSafe(data['creator']);
      version = _castStringSafe(data['character_version']);
      extensions = data['extensions'] is Map
          ? Map<String, dynamic>.from(data['extensions'] as Map)
          : {};
      
      // Parse character book (embedded lorebook)
      if (data['character_book'] != null) {
        characterBook = _parseCharacterBook(data['character_book'] as Map<String, dynamic>);
      }
    }
    // V1 format
    else {
      name = _castStringSafe(json['name']) != ''
          ? _castStringSafe(json['name'])
          : _castStringSafe(json['char_name']);
      description = _castStringSafe(json['description']) != ''
          ? _castStringSafe(json['description'])
          : _castStringSafe(json['char_persona']);
      // AICC compat: V1 core field tolerance
      personality = _castStringSafe(json['personality']);
      scenario = _castStringSafe(json['scenario']) != ''
          ? _castStringSafe(json['scenario'])
          : _castStringSafe(json['world_scenario']);
      firstMessage = _castStringSafe(json['first_mes']) != ''
          ? _castStringSafe(json['first_mes'])
          : _castStringSafe(json['char_greeting']);
      exampleMessages = _castStringSafe(json['mes_example']) != ''
          ? _castStringSafe(json['mes_example'])
          : _castStringSafe(json['example_dialogue']);
    }

    final now = DateTime.now();
    return Character(
      id: _generateId(),
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
      extensions: extensions,
      characterBook: characterBook,
      createdAt: now,
      modifiedAt: now,
    );
  }

  CharacterBook _parseCharacterBook(Map<String, dynamic> json) {
    final rawEntries = json['entries'];
    // [IMP-3] Entry shape detection: use arrays directly; for map shape (ST partial exports/old cards), take values as a list
    print('[IMP-3] book=${json['name']} entriesRawType=${rawEntries?.runtimeType} '
        'count=${rawEntries is List ? rawEntries.length : (rawEntries is Map ? rawEntries.length : 'null')}');
    List<dynamic> entriesJson;
    if (rawEntries is List) {
      entriesJson = rawEntries;
    } else if (rawEntries is Map) {
      entriesJson = rawEntries.values.toList();
    } else {
      entriesJson = [];
    }
    for (final e in entriesJson.take(10)) {
      if (e is Map) {
        final k = e['keys'];
        print('[IMP-3] entry id=${e['id']} keys=${k is List ? k.take(3).toList() : k} '
            'constant=${e['constant']} contentLen=${(e['content']?.toString() ?? '').length} '
            'content40=${(e['content']?.toString() ?? '').substring(0, (e['content']?.toString() ?? '').length > 40 ? 40 : (e['content']?.toString() ?? '').length)}');
      }
    }
    final entries = entriesJson.whereType<Map>().map((e) {
      final entry = Map<String, dynamic>.from(e);
      return CharacterBookEntry(
        id: _parseIntSafe(entry['id']) ?? 0,
        keys: _parseStringList(entry['keys']),
        secondaryKeys: _parseStringList(entry['secondary_keys']),
        content: entry['content']?.toString() ?? '',
        comment: entry['comment']?.toString() ?? '',
        enabled: !(_parseBoolSafe(entry['disable']) ?? false) && (_parseBoolSafe(entry['enabled']) ?? true),
        insertionOrder: _parseIntSafe(entry['insertion_order']) ?? _parseIntSafe(entry['order']) ?? 0,
        caseSensitive: _parseBoolSafe(entry['case_sensitive']) ?? false,
        name: entry['name']?.toString() ?? entry['comment']?.toString() ?? '',
        priority: _parseIntSafe(entry['priority']) ?? 10,
        constant: _parseBoolSafe(entry['constant']) ?? false,
        selective: _parseBoolSafe(entry['selective']) ?? false,
        position: _parseIntSafe(entry['position']) ?? 0,
        extensions: entry['extensions'] as Map<String, dynamic>? ?? {},
      );
    }).toList();

    return CharacterBook(
      name: json['name']?.toString(),
      description: json['description']?.toString(),
      scanDepth: _parseScanDepthSafe(json['scan_depth']),
      tokenBudget: _parseIntSafe(json['token_budget']) ?? 2048,
      recursiveScanning: _parseBoolSafe(json['recursive_scanning']) ?? false,
      entries: entries,
      extensions: json['extensions'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Safely parse an int from dynamic value (handles both int and string)
  int? _parseIntSafe(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }

  /// Safely parse a bool from dynamic value (handles bool, int, and string)
  bool? _parseBoolSafe(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    return null;
  }

  /// Safely parse scan_depth: spec requires int; legacy bool values map true→1, false→0
  int? _parseScanDepthSafe(dynamic value) {
    if (value is bool) return value ? 1 : 0;
    return _parseIntSafe(value);
  }

  /// AICC compat: safely cast a dynamic value to String:
  /// V2 core field tolerance — Map/List (structured fields) are JSON-stringified, others use toString
  String _castStringSafe(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is Map || value is List) {
      try {
        return jsonEncode(value);
      } catch (_) {
        return value.toString();
      }
    }
    return value.toString();
  }

  /// AICC compat: safely parse tags — List (per-item toString) or comma-separated String split into a list
  List<String> _parseTagsSafe(dynamic value) {
    if (value is List) {
      return value.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    }
    if (value is String && value.isNotEmpty) {
      return value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  /// AICC compat: structured personality (core/behavior_rules/speech_style) converted to readable text
  String _aiccPersonalityToString(Map<dynamic, dynamic> personality) {
    final buf = StringBuffer();
    final core = personality['core'];
    if (core != null && '$core'.isNotEmpty) buf.writeln('$core');
    final rules = personality['behavior_rules'];
    if (rules is List && rules.isNotEmpty) {
      buf.writeln();
      buf.writeln('Behavior rules:');
      for (final r in rules) {
        final line = r?.toString() ?? '';
        if (line.isNotEmpty) buf.writeln('- $line');
      }
    }
    final style = personality['speech_style'];
    if (style is Map) {
      buf.writeln();
      buf.writeln('Speech style:');
      style.forEach((k, v) {
        if (v is List) {
          final items = v.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).join('; ');
          if (items.isNotEmpty) buf.writeln('- $k: $items');
        } else if (v != null && '$v'.isNotEmpty) {
          buf.writeln('- $k: $v');
        }
      });
    }
    return buf.toString().trim();
  }

  /// Safely parse a list of strings from dynamic value
  List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  Map<String, dynamic> _characterToV3Json(Character character) {
    final data = {
      'name': character.name,
      'description': character.description,
      'personality': character.personality,
      'scenario': character.scenario,
      'first_mes': character.firstMessage,
      'alternate_greetings': character.alternateGreetings,
      'mes_example': character.exampleMessages,
      'system_prompt': character.systemPrompt,
      'post_history_instructions': character.postHistoryInstructions,
      'creator_notes': character.creatorNotes,
      'tags': character.tags,
      'creator': character.creator,
      'character_version': character.version,
      'extensions': character.extensions,
    };

    // Add character book if present
    if (character.characterBook != null) {
      data['character_book'] = _characterBookToJson(character.characterBook!);
    }

    return {
      'spec': 'chara_card_v3',
      'spec_version': '3.0',
      'data': data,
    };
  }

  Map<String, dynamic> _characterBookToJson(CharacterBook book) {
    return {
      'name': book.name,
      'description': book.description,
      if (book.scanDepth != null) 'scan_depth': book.scanDepth,
      'token_budget': book.tokenBudget,
      'recursive_scanning': book.recursiveScanning,
      'extensions': book.extensions,
      'entries': book.entries.map((e) => {
        'id': e.id,
        'keys': e.keys,
        'secondary_keys': e.secondaryKeys,
        'content': e.content,
        'comment': e.comment,
        'enabled': e.enabled,
        'insertion_order': e.insertionOrder,
        'case_sensitive': e.caseSensitive,
        'name': e.name,
        'priority': e.priority,
        'constant': e.constant,
        'selective': e.selective,
        'position': e.position,
        'extensions': e.extensions,
      }).toList(),
    };
  }

  Future<String> _saveAvatar(String characterId, Uint8List imageData) async {
    final avatarDir = Directory(p.join(_dataPath, 'avatars'));
    if (!await avatarDir.exists()) {
      await avatarDir.create(recursive: true);
    }
    
    final avatarPath = p.join(avatarDir.path, '$characterId.png');
    await File(avatarPath).writeAsBytes(imageData);
    
    // Return relative path for storage (mobile-compatible)
    return await PathUtils.toRelativePath(avatarPath);
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + 
           (DateTime.now().microsecond % 1000).toString().padLeft(3, '0');
  }

  /// Dump all PNG text chunk keys + content preview
  void _dumpPngInfo(Uint8List bytes) {
    debugPrint('[PNG-DUMP] size=${bytes.length}');
    int off = 8; int n = 0;
    while (off + 8 <= bytes.length) {
      final len = (bytes[off] << 24) | (bytes[off + 1] << 16) | (bytes[off + 2] << 8) | bytes[off + 3]; off += 4;
      final tp = String.fromCharCodes(bytes.sublist(off, off + 4)); off += 4; n++;
      if (tp == 'tEXt' || tp == 'iTXt' || tp == 'zTXt') {
        int ke = off; while (ke < off + len && bytes[ke] != 0) { ke++; }
        final key = String.fromCharCodes(bytes.sublist(off, ke));
        String prev = ''; if (ke + 1 < off + len) { final mx = (ke + 1 + 200) > (off + len) ? (off + len) : (ke + 1 + 200); prev = String.fromCharCodes(bytes.sublist(ke + 1, mx)); }
        debugPrint('[PNG-DUMP] #$n $tp key=$key len=$len');
        debugPrint('[PNG-DUMP]   preview=$prev');
      }
      off += len + 4;
    }
    debugPrint('[PNG-DUMP] Done: $n chunks');
  }

  /// Extract text chunk from PNG
  String? _extractPngTextChunk(Uint8List bytes, String keyword) {
    // PNG signature is 8 bytes
    if (bytes.length < 8) return null;
    
    int offset = 8; // Skip PNG signature
    
    while (offset < bytes.length - 8) {
      // Read chunk length (4 bytes, big-endian)
      final length = (bytes[offset] << 24) | 
                    (bytes[offset + 1] << 16) | 
                    (bytes[offset + 2] << 8) | 
                    bytes[offset + 3];
      offset += 4;
      
      // Read chunk type (4 bytes)
      final type = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      offset += 4;
      
      if (type == 'tEXt') {
        // Read keyword until null byte
        final dataStart = offset;
        final dataEnd = offset + length;
        
        int keywordEnd = dataStart;
        while (keywordEnd < dataEnd && bytes[keywordEnd] != 0) {
          keywordEnd++;
        }
        
        final chunkKeyword = String.fromCharCodes(bytes.sublist(dataStart, keywordEnd));
        
        if (chunkKeyword == keyword && keywordEnd + 1 < dataEnd) {
          // Return the text value after the null separator
          return String.fromCharCodes(bytes.sublist(keywordEnd + 1, dataEnd));
        }
      }
      
      // Skip data + CRC
      offset += length + 4;
    }
    
    return null;
  }



  String _safeDecodeText(List<int> bytes) {
    try { return utf8.decode(bytes, allowMalformed: true); } catch (_) {}
    try { return latin1.decode(bytes); } catch (_) {}
    return String.fromCharCodes(bytes);
  }
  /// Embed text chunk in PNG
  Uint8List _embedPngTextChunk(Uint8List bytes, String keyword, String value) {
    // Find IEND chunk position
    int iendPos = -1;
    int offset = 8;
    
    while (offset < bytes.length - 8) {
      final length = (bytes[offset] << 24) | 
                    (bytes[offset + 1] << 16) | 
                    (bytes[offset + 2] << 8) | 
                    bytes[offset + 3];
      
      final type = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));
      
      if (type == 'IEND') {
        iendPos = offset;
        break;
      }
      
      offset += 4 + 4 + length + 4;
    }
    
    if (iendPos < 0) {
      // Return original if IEND not found
      return bytes;
    }
    
    // Create tEXt chunk
    final keywordBytes = utf8.encode(keyword);
    final valueBytes = utf8.encode(value);
    final chunkData = [...keywordBytes, 0, ...valueBytes];
    final chunkType = utf8.encode('tEXt');
    
    // Calculate CRC
    final crcData = [...chunkType, ...chunkData];
    final crc = _calculateCrc32(Uint8List.fromList(crcData));
    
    // Build chunk
    final chunkLength = chunkData.length;
    final chunk = [
      (chunkLength >> 24) & 0xFF,
      (chunkLength >> 16) & 0xFF,
      (chunkLength >> 8) & 0xFF,
      chunkLength & 0xFF,
      ...chunkType,
      ...chunkData,
      (crc >> 24) & 0xFF,
      (crc >> 16) & 0xFF,
      (crc >> 8) & 0xFF,
      crc & 0xFF,
    ];
    
    // Combine: before IEND + new chunk + IEND
    final result = <int>[
      ...bytes.sublist(0, iendPos),
      ...chunk,
      ...bytes.sublist(iendPos),
    ];
    
    return Uint8List.fromList(result);
  }

  /// Calculate CRC32 for PNG chunks
  int _calculateCrc32(Uint8List data) {
    const table = <int>[
      0x00000000, 0x77073096, 0xee0e612c, 0x990951ba, 0x076dc419, 0x706af48f,
      0xe963a535, 0x9e6495a3, 0x0edb8832, 0x79dcb8a4, 0xe0d5e91e, 0x97d2d988,
      0x09b64c2b, 0x7eb17cbd, 0xe7b82d07, 0x90bf1d91, 0x1db71064, 0x6ab020f2,
      0xf3b97148, 0x84be41de, 0x1adad47d, 0x6ddde4eb, 0xf4d4b551, 0x83d385c7,
      0x136c9856, 0x646ba8c0, 0xfd62f97a, 0x8a65c9ec, 0x14015c4f, 0x63066cd9,
      0xfa0f3d63, 0x8d080df5, 0x3b6e20c8, 0x4c69105e, 0xd56041e4, 0xa2677172,
      0x3c03e4d1, 0x4b04d447, 0xd20d85fd, 0xa50ab56b, 0x35b5a8fa, 0x42b2986c,
      0xdbbbc9d6, 0xacbcf940, 0x32d86ce3, 0x45df5c75, 0xdcd60dcf, 0xabd13d59,
      0x26d930ac, 0x51de003a, 0xc8d75180, 0xbfd06116, 0x21b4f4b5, 0x56b3c423,
      0xcfba9599, 0xb8bda50f, 0x2802b89e, 0x5f058808, 0xc60cd9b2, 0xb10be924,
      0x2f6f7c87, 0x58684c11, 0xc1611dab, 0xb6662d3d, 0x76dc4190, 0x01db7106,
      0x98d220bc, 0xefd5102a, 0x71b18589, 0x06b6b51f, 0x9fbfe4a5, 0xe8b8d433,
      0x7807c9a2, 0x0f00f934, 0x9609a88e, 0xe10e9818, 0x7f6a0dbb, 0x086d3d2d,
      0x91646c97, 0xe6635c01, 0x6b6b51f4, 0x1c6c6162, 0x856530d8, 0xf262004e,
      0x6c0695ed, 0x1b01a57b, 0x8208f4c1, 0xf50fc457, 0x65b0d9c6, 0x12b7e950,
      0x8bbeb8ea, 0xfcb9887c, 0x62dd1ddf, 0x15da2d49, 0x8cd37cf3, 0xfbd44c65,
      0x4db26158, 0x3ab551ce, 0xa3bc0074, 0xd4bb30e2, 0x4adfa541, 0x3dd895d7,
      0xa4d1c46d, 0xd3d6f4fb, 0x4369e96a, 0x346ed9fc, 0xad678846, 0xda60b8d0,
      0x44042d73, 0x33031de5, 0xaa0a4c5f, 0xdd0d7cc9, 0x5005713c, 0x270241aa,
      0xbe0b1010, 0xc90c2086, 0x5768b525, 0x206f85b3, 0xb966d409, 0xce61e49f,
      0x5edef90e, 0x29d9c998, 0xb0d09822, 0xc7d7a8b4, 0x59b33d17, 0x2eb40d81,
      0xb7bd5c3b, 0xc0ba6cad, 0xedb88320, 0x9abfb3b6, 0x03b6e20c, 0x74b1d29a,
      0xead54739, 0x9dd277af, 0x04db2615, 0x73dc1683, 0xe3630b12, 0x94643b84,
      0x0d6d6a3e, 0x7a6a5aa8, 0xe40ecf0b, 0x9309ff9d, 0x0a00ae27, 0x7d079eb1,
      0xf00f9344, 0x8708a3d2, 0x1e01f268, 0x6906c2fe, 0xf762575d, 0x806567cb,
      0x196c3671, 0x6e6b06e7, 0xfed41b76, 0x89d32be0, 0x10da7a5a, 0x67dd4acc,
      0xf9b9df6f, 0x8ebeeff9, 0x17b7be43, 0x60b08ed5, 0xd6d6a3e8, 0xa1d1937e,
      0x38d8c2c4, 0x4fdff252, 0xd1bb67f1, 0xa6bc5767, 0x3fb506dd, 0x48b2364b,
      0xd80d2bda, 0xaf0a1b4c, 0x36034af6, 0x41047a60, 0xdf60efc3, 0xa867df55,
      0x316e8eef, 0x4669be79, 0xcb61b38c, 0xbc66831a, 0x256fd2a0, 0x5268e236,
      0xcc0c7795, 0xbb0b4703, 0x220216b9, 0x5505262f, 0xc5ba3bbe, 0xb2bd0b28,
      0x2bb45a92, 0x5cb36a04, 0xc2d7ffa7, 0xb5d0cf31, 0x2cd99e8b, 0x5bdeae1d,
      0x9b64c2b0, 0xec63f226, 0x756aa39c, 0x026d930a, 0x9c0906a9, 0xeb0e363f,
      0x72076785, 0x05005713, 0x95bf4a82, 0xe2b87a14, 0x7bb12bae, 0x0cb61b38,
      0x92d28e9b, 0xe5d5be0d, 0x7cdcefb7, 0x0bdbdf21, 0x86d3d2d4, 0xf1d4e242,
      0x68ddb3f8, 0x1fda836e, 0x81be16cd, 0xf6b9265b, 0x6fb077e1, 0x18b74777,
      0x88085ae6, 0xff0f6a70, 0x66063bca, 0x11010b5c, 0x8f659eff, 0xf862ae69,
      0x616bffd3, 0x166ccf45, 0xa00ae278, 0xd70dd2ee, 0x4e048354, 0x3903b3c2,
      0xa7672661, 0xd06016f7, 0x4969474d, 0x3e6e77db, 0xaed16a4a, 0xd9d65adc,
      0x40df0b66, 0x37d83bf0, 0xa9bcae53, 0xdebb9ec5, 0x47b2cf7f, 0x30b5ffe9,
      0xbdbdf21c, 0xcabac28a, 0x53b39330, 0x24b4a3a6, 0xbad03605, 0xcdd70693,
      0x54de5729, 0x23d967bf, 0xb3667a2e, 0xc4614ab8, 0x5d681b02, 0x2a6f2b94,
      0xb40bbe37, 0xc30c8ea1, 0x5a05df1b, 0x2d02ef8d,
    ];

    int crc = 0xFFFFFFFF;
    for (final byte in data) {
      crc = table[(crc ^ byte) & 0xFF] ^ (crc >> 8);
    }
    return crc ^ 0xFFFFFFFF;
  }

  /// Create a simple placeholder PNG
  Uint8List _createPlaceholderPng() {
    // A minimal 1x1 transparent PNG
    return Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
      0x00, 0x00, 0x00, 0x0D, // IHDR chunk length
      0x49, 0x48, 0x44, 0x52, // IHDR
      0x00, 0x00, 0x00, 0x01, // width = 1
      0x00, 0x00, 0x00, 0x01, // height = 1
      0x08, 0x06, 0x00, 0x00, 0x00, // 8-bit RGBA
      0x1F, 0x15, 0xC4, 0x89, // CRC
      0x00, 0x00, 0x00, 0x0A, // IDAT chunk length
      0x49, 0x44, 0x41, 0x54, // IDAT
      0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01,
      0x0D, 0x0A, 0x2D, 0xB4, // CRC
      0x00, 0x00, 0x00, 0x00, // IEND chunk length
      0x49, 0x45, 0x4E, 0x44, // IEND
      0xAE, 0x42, 0x60, 0x82, // CRC
    ]);
  }
}

/// Extracts the characterBook embedded in a character card into a standalone WorldInfo (linked to that character).
/// Shared by single import and zip batch import to avoid duplicated logic.
Future<void> importEmbeddedLorebook(
  WorldInfoRepository worldInfoRepo,
  String characterId,
  CharacterBook characterBook,
  String characterName,
) async {
  final worldInfoName = characterBook.name ?? '$characterName Lorebook';
  // [IMP-5] Entry count to write before persisting
  print('[IMP-5] creating WI "$worldInfoName" for char=$characterId entriesToWrite=${characterBook.entries.length}');
  final worldInfo = await worldInfoRepo.createWorldInfo(
    name: worldInfoName,
    description:
        characterBook.description ?? 'Embedded lorebook from $characterName',
    isGlobal: false,
    characterId: characterId,
  );

  for (final entry in characterBook.entries) {
    // A2-T3: full position mapping (upstream 0: above char, 1: below char, 2: above AN, 3: below AN, 4: at depth)
    WorldInfoPosition position;
    int depth = 4;
    switch (entry.position) {
      case 0:
        position = WorldInfoPosition.before;
        break;
      case 1:
        position = WorldInfoPosition.after;
        break;
      case 2:
        position = WorldInfoPosition.ANTop;
        break;
      case 3:
        position = WorldInfoPosition.ANBottom;
        break;
      case 4:
        position = WorldInfoPosition.atDepth;
        final extDepth = entry.extensions['depth'];
        if (extDepth is int) depth = extDepth;
        if (extDepth is String) depth = int.tryParse(extDepth) ?? 4;
        break;
      default:
        position = WorldInfoPosition.after;
    }
    // A2-T3: depth fallback from extensions (may also be present outside position=4)
    if (position != WorldInfoPosition.atDepth) {
      final extDepth = entry.extensions['depth'];
      if (extDepth is int && extDepth > 0 && extDepth != 4) depth = extDepth;
    }

    // [IMP-5] Per-entry write details (constant/order/enabled/caseSensitive/extensions passed through)
    print('[IMP-5] addEntry keys=${entry.keys.take(3).toList()} constant=${entry.constant} '
        'enabled=${entry.enabled} order=${entry.insertionOrder} '
        'contentLen=${entry.content.length} comment=${entry.name.isNotEmpty ? entry.name : entry.comment}');
    await worldInfoRepo.addEntry(
      worldInfoId: worldInfo.id,
      keys: entry.keys,
      content: entry.content,
      secondaryKeys:
          entry.secondaryKeys.isNotEmpty ? entry.secondaryKeys : null,
      comment: entry.name.isNotEmpty ? entry.name : entry.comment,
      position: position,
      depth: depth,
      // A2-T3 full passthrough: semantics like blue-light constant entries are no longer swallowed by defaults
      constant: entry.constant,
      selective: entry.selective,
      insertionOrder: entry.insertionOrder,
      enabled: entry.enabled,
      caseSensitive: entry.caseSensitive,
      extensions: entry.extensions,
    );
  }
  // [IMP-6] Read back after persisting: actual entry count (compare with IMP-5; the difference is dropped entries)
  final written = await worldInfoRepo.getEntriesForWorldInfo(worldInfo.id);
  print('[IMP-6] readback WI="${worldInfo.name}" id=${worldInfo.id} entriesInDb=${written.length} (expected ${characterBook.entries.length})');
}

/// Reassembles a CharacterBook from the world_infos table (live data), fixing stale worldbook export.
///
/// Worldbook dual-track storage: live data lives in the world_infos/world_info_entries tables (the editor writes only there),
/// while characters.characterBookJson is the import-time snapshot, with zero sync between tracks. Exporting directly
/// from the snapshot loses all user changes made after import (the export is always the original import-time data).
/// Call this before export to reassemble the live track into a CharacterBook, replacing the snapshot.
///
/// Returns null when the character has no bound book or zero entries (callers keep the original snapshot as fallback).
/// Field mapping (aligned with _characterBookToJson / _wiEntryToJson):
/// - WorldInfoEntry has no name field; the name is stored in comment (at import, entry.name ?: comment becomes comment)
/// - id uses the merged list index (deterministic, collision-free; ST uid is numeric, losslessly parsed back as int on re-import)
/// - position uses the enum index (consistent with _wiEntryToJson's 'position': e.position.index)
/// - WorldInfo has no tokenBudget/extensions fields, so CharacterBook uses defaults
///   (book-level extensions have no storage in the world_infos table and export empty; entry-level extensions are fully preserved)
Future<CharacterBook?> assembleCharacterBookFromRepo(
  WorldInfoRepository worldInfoRepo,
  String characterId,
) async {
  try {
    final books = await worldInfoRepo.getWorldInfosForCharacter(characterId);
    if (books.isEmpty) return null;

    // Merge entries from all books bound to the character (ST character_book is already a flat list,
    // consistent with the merge fallback semantics of _handleWiGetEntries)
    final merged = <CharacterBookEntry>[];
    String? bookName;
    for (final book in books) {
      bookName ??= book.name;
      for (final e in book.entries) {
        merged.add(CharacterBookEntry(
          id: merged.length,
          keys: e.keys,
          secondaryKeys: e.secondaryKeys,
          content: e.content,
          comment: e.comment,
          name: e.comment,
          enabled: e.enabled,
          insertionOrder: e.insertionOrder,
          caseSensitive: e.caseSensitive,
          constant: e.constant,
          selective: e.selective,
          position: e.position.index,
          extensions: e.extensions,
        ));
      }
    }
    if (merged.isEmpty) return null;

    return CharacterBook(
      name: bookName,
      entries: merged,
    );
  } catch (e) {
    debugPrint('[导出] 组装世界书失败: $e');
    return null;
  }
}