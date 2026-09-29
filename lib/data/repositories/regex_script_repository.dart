import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/core/services/initialization_service.dart';
import 'package:kirakira/data/database/database.dart';
import 'package:kirakira/data/models/regex_script.dart';

/// [Phase 2.3] Provider for regex script repository
final regexScriptRepositoryProvider = Provider<RegexScriptRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return RegexScriptRepository(db);
});

/// [Phase 2.3] Repository for regex scripts stored in the dedicated
/// `regex_scripts` table (previously stored in characters.extensionsJson
/// and SharedPreferences, which caused lost-update races and backup gaps).
class RegexScriptRepository {
  final AppDatabase _db;

  RegexScriptRepository(this._db);

  /// Row → model。行字段为准（id/scope/order/disabled/characterId），
  /// JSON 内值兜底；解析失败返回禁用空规则（[IMP-7] 防整体丢失，不抛出）。
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

  /// 获取角色级正则（按 order 排序）
  Future<List<RegexScript>> getForCharacter(String characterId) async {
    final rows = await (_db.select(_db.regexScripts)
          ..where((t) =>
              t.scope.equals('character') &
              t.characterId.equals(characterId))
          ..orderBy([(t) => OrderingTerm(expression: t.order)]))
        .get();
    return rows.map(_fromRow).toList();
  }

  /// 获取全局正则（按 order 排序）
  Future<List<RegexScript>> getGlobal() async {
    final rows = await (_db.select(_db.regexScripts)
          ..where((t) => t.scope.equals('global'))
          ..orderBy([(t) => OrderingTerm(expression: t.order)]))
        .get();
    return rows.map(_fromRow).toList();
  }

  /// 保存角色级正则（事务内批量替换）
  Future<void> saveForCharacter(
      String characterId, List<RegexScript> scripts) async {
    await _db.transaction(() async {
      await (_db.delete(_db.regexScripts)
            ..where((t) =>
                t.scope.equals('character') &
                t.characterId.equals(characterId)))
          .go();
      for (var i = 0; i < scripts.length; i++) {
        final script = scripts[i];
        await _db.into(_db.regexScripts).insert(RegexScriptsCompanion(
              id: Value(script.id),
              scope: const Value('character'),
              characterId: Value(characterId),
              scriptJson: Value(jsonEncode(script.toJson())),
              order: Value(i),
              disabled: Value(script.disabled),
              createdAt: Value(script.createdAt),
              updatedAt: Value(script.updatedAt),
            ));
      }
    });
  }

  /// 保存全局正则（事务内批量替换）
  Future<void> saveGlobal(List<RegexScript> scripts) async {
    await _db.transaction(() async {
      await (_db.delete(_db.regexScripts)
            ..where((t) => t.scope.equals('global')))
          .go();
      for (var i = 0; i < scripts.length; i++) {
        final script = scripts[i];
        await _db.into(_db.regexScripts).insert(RegexScriptsCompanion(
              id: Value(script.id),
              scope: const Value('global'),
              scriptJson: Value(jsonEncode(script.toJson())),
              order: Value(i),
              disabled: Value(script.disabled),
              createdAt: Value(script.createdAt),
              updatedAt: Value(script.updatedAt),
            ));
      }
    });
  }

  /// 首启迁移全局正则（SharedPreferences → 表）。仅表为空时迁移，幂等。
  Future<void> migrateGlobalFromPrefs(List<RegexScript> prefsScripts) async {
    final existing = await getGlobal();
    if (existing.isEmpty && prefsScripts.isNotEmpty) {
      await saveGlobal(prefsScripts);
      debugPrint('[RegexRepo] 迁移全局正则: ${prefsScripts.length} 条');
    }
  }
}
