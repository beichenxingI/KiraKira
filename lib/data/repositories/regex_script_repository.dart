import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/core/services/initialization_service.dart';
import 'package:kirakira/data/database/database.dart';
import 'package:kirakira/data/models/regex_script.dart';

/// Provider for regex script repository
final regexScriptRepositoryProvider = Provider<RegexScriptRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return RegexScriptRepository(db);
});

/// Robust dual-format parsing: native fromJson first, with SillyTavern's
/// fromSillyTavernJson as fallback. Kept consistent with the migration logic
/// in database.dart; shared by the Repository import methods and the Provider
/// dual-read fallback. Returns null when parsing fails (that entry is skipped
/// without blocking the rest).
RegexScript? parseRegexScriptRobust(
  Map<String, dynamic> raw,
  String characterId,
  int index,
) {
  try {
    final s = RegexScript.fromJson(raw);
    return s.copyWith(
      id: s.id.isEmpty ? '${characterId}_s$index' : s.id,
      characterId: s.characterId ?? characterId,
    );
  } catch (_) {}
  try {
    final s = RegexScript.fromSillyTavernJson(
      raw,
      newId: '${characterId}_migrated_$index',
    );
    return s.copyWith(
      scriptType: RegexScriptType.character,
      characterId: characterId,
    );
  } catch (_) {
    return null;
  }
}

/// Character-scoped row IDs: prefix with the character ID to guarantee
/// cross-character uniqueness. When a card template is reused, different
/// characters can carry the same script.id; using it directly as the primary
/// key causes a PK conflict → transaction abort → all regex scripts lost.
/// Idempotent: returns the ID as-is if it already carries this character's
/// prefix, avoiding prefix stacking.
String scopedRegexRowId(String characterId, String scriptId) {
  if (scriptId.startsWith('${characterId}_')) return scriptId;
  return '${characterId}_$scriptId';
}

/// Repository for regex scripts stored in the dedicated
/// `regex_scripts` table (previously stored in characters.extensionsJson
/// and SharedPreferences, which caused lost-update races and backup gaps).
class RegexScriptRepository {
  final AppDatabase _db;

  RegexScriptRepository(this._db);

  /// Row → model. Row fields take precedence (id/scope/order/disabled/characterId)
  /// with JSON values as fallback; on parse failure returns a disabled empty
  /// rule (prevents total loss instead of throwing).
  RegexScript _fromRow(RegexScriptRow row) {
    try {
      final json = jsonDecode(row.scriptJson) as Map<String, dynamic>;
      final script = RegexScript.fromJson(json);
      return script.copyWith(
        id: row.id,
        order: row.order,
        disabled: row.disabled,
        characterId: row.characterId ?? script.characterId,
      );
    } catch (e) {
      return RegexScript(
        id: row.id,
        scriptName: '解析失败的正则',
        findRegex: '',
        replaceString: '',
        placement: const [RegexPlacement.aiOutput],
        disabled: true,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );
    }
  }

  /// Get character-scoped regex scripts (sorted by order)
  Future<List<RegexScript>> getForCharacter(String characterId) async {
    final rows = await (_db.select(_db.regexScripts)
          ..where((t) =>
              t.scope.equals('character') &
              t.characterId.equals(characterId))
          ..orderBy([(t) => OrderingTerm(expression: t.order)]))
        .get();
    return rows.map(_fromRow).toList();
  }

  /// Get global regex scripts (sorted by order)
  Future<List<RegexScript>> getGlobal() async {
    final rows = await (_db.select(_db.regexScripts)
          ..where((t) => t.scope.equals('global'))
          ..orderBy([(t) => OrderingTerm(expression: t.order)]))
        .get();
    return rows.map(_fromRow).toList();
  }

  /// Save character-scoped regex scripts (batch replace within a transaction)
  Future<void> saveForCharacter(
      String characterId, List<RegexScript> scripts) async {
    debugPrint(
        '[RegexRepo] 开始保存角色级: characterId=$characterId, ${scripts.length} 条');
    try {
      await _db.transaction(() async {
        final deleted = await (_db.delete(_db.regexScripts)
              ..where((t) =>
                  t.scope.equals('character') &
                  t.characterId.equals(characterId)))
            .go();
        debugPrint('[RegexRepo] 已删除旧数据: $deleted 条');
        await _insertScripts(scripts, characterId: characterId);
      });
      debugPrint('[RegexRepo] ✅ 保存角色级成功: ${scripts.length} 条');
    } catch (e, stackTrace) {
      debugPrint('[RegexRepo] ❌ 保存角色级失败: $e');
      debugPrint('[RegexRepo] StackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Save global regex scripts (batch replace within a transaction)
  Future<void> saveGlobal(List<RegexScript> scripts) async {
    debugPrint('[RegexRepo] 开始保存全局: ${scripts.length} 条');
    try {
      await _db.transaction(() async {
        final deleted = await (_db.delete(_db.regexScripts)
              ..where((t) => t.scope.equals('global')))
            .go();
        debugPrint('[RegexRepo] 已删除旧全局数据: $deleted 条');
        await _insertScripts(scripts);
      });
      debugPrint('[RegexRepo] ✅ 保存全局成功: ${scripts.length} 条');
    } catch (e, stackTrace) {
      debugPrint('[RegexRepo] ❌ 保存全局失败: $e');
      debugPrint('[RegexRepo] StackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Batch insert: row IDs get a character prefix to prevent cross-character
  /// conflicts; duplicate IDs within a batch (reused card templates / empty
  /// IDs) fall back to timestamp + index to prevent a PK conflict from
  /// aborting the transaction.
  Future<void> _insertScripts(
    List<RegexScript> scripts, {
    String? characterId,
  }) async {
    final seenRowIds = <String>{};
    for (var i = 0; i < scripts.length; i++) {
      final script = scripts[i];
      var rowId = characterId == null
          ? script.id
          : scopedRegexRowId(characterId, script.id);
      if (!seenRowIds.add(rowId)) {
        rowId =
            '${characterId ?? 'global'}_dup_${DateTime.now().microsecondsSinceEpoch}_$i';
        debugPrint('[RegexRepo] ⚠️ 第 $i 条 id 重复，改用兜底 id: $rowId');
      }
      debugPrint(
          '[RegexRepo] 插入第 $i 条: id=$rowId, name=${script.scriptName}');
      await _db.into(_db.regexScripts).insert(RegexScriptsCompanion(
            id: Value(rowId),
            scope: Value(characterId == null ? 'global' : 'character'),
            characterId: Value(characterId),
            scriptJson: Value(jsonEncode(script.toJson())),
            order: Value(i),
            disabled: Value(script.disabled),
            createdAt: Value(script.createdAt),
            updatedAt: Value(script.updatedAt),
          ));
    }
  }

  /// Import path: raw extensions['regex_scripts'] list from a character card →
  /// dedicated table. Dual-format parsing (native first, SillyTavern fallback);
  /// a failed entry is skipped; returns 0 without throwing when all fail (the
  /// original extensions data is preserved, and the Provider dual-read
  /// fallback covers the gap).
  Future<int> importCharacterScriptsFromRaw(
      String characterId, dynamic rawList) async {
    if (rawList is! List || rawList.isEmpty) return 0;
    debugPrint(
        '[RegexRepo] 导入写表开始: characterId=$characterId, ${rawList.length} 条');
    final parsed = <RegexScript>[];
    for (var i = 0; i < rawList.length; i++) {
      final raw = rawList[i];
      if (raw is! Map) {
        debugPrint('[RegexRepo] ❌ 第 $i 条非 Map: ${raw?.runtimeType}');
        continue;
      }
      final s = parseRegexScriptRobust(
        Map<String, dynamic>.from(raw),
        characterId,
        i,
      );
      if (s == null) {
        debugPrint(
            '[RegexRepo] ❌ 第 $i 条解析失败: keys=${raw.keys.take(8).toList()}');
        continue;
      }
      parsed.add(s);
    }
    if (parsed.isEmpty) {
      debugPrint('[RegexRepo] ❌ 导入写表: 0 条解析成功（extensions 原数据保留）');
      return 0;
    }
    await saveForCharacter(characterId, parsed);
    debugPrint(
        '[RegexRepo] ✅ 导入写表完成: ${parsed.length}/${rawList.length} 条');
    return parsed.length;
  }

  /// Migrate global regex scripts on first launch (SharedPreferences → table).
  /// Only migrates when the table is empty; idempotent.
  Future<void> migrateGlobalFromPrefs(List<RegexScript> prefsScripts) async {
    final existing = await getGlobal();
    if (existing.isEmpty && prefsScripts.isNotEmpty) {
      await saveGlobal(prefsScripts);
      debugPrint('[RegexRepo] 迁移全局正则: ${prefsScripts.length} 条');
    }
  }
}
