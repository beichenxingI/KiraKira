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

/// [紧急修复-A] 双格式解析：自家 fromJson 优先，SillyTavern fromSillyTavernJson 兜底。
/// 与 database.dart 迁移逻辑保持一致；供 Repository 导入方法 / Provider 双读降级共用。
/// 返回 null 表示无法解析（跳过该条，不阻断其余）。
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

/// [紧急修复-B] 角色级行 id：加角色前缀保证跨角色唯一。
/// 同卡模板复用时不同角色可能携带相同 script.id，直接作主键会 PK 冲突
/// → 事务炸 → 正则整体丢失。幂等：已带该角色前缀则原样返回，避免前缀叠加。
String scopedRegexRowId(String characterId, String scriptId) {
  if (scriptId.startsWith('${characterId}_')) return scriptId;
  return '${characterId}_$scriptId';
}

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

  /// 保存全局正则（事务内批量替换）
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

  /// [紧急修复-B] 批量插入：行 id 加角色前缀防跨角色冲突；
  /// 同批次内 id 重复（同卡模板复用/空 id）时用时间戳+序号兜底，防 PK 冲突炸事务。
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

  /// [紧急修复-C] 导入链路：角色卡 extensions['regex_scripts'] 原始列表 → 独立表。
  /// 双格式解析（自家优先/ST 兜底），单条失败跳过；全部失败返回 0 不抛出
  /// （extensions 原数据保留，Provider 双读降级兜底）。
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

  /// 首启迁移全局正则（SharedPreferences → 表）。仅表为空时迁移，幂等。
  Future<void> migrateGlobalFromPrefs(List<RegexScript> prefsScripts) async {
    final existing = await getGlobal();
    if (existing.isEmpty && prefsScripts.isNotEmpty) {
      await saveGlobal(prefsScripts);
      debugPrint('[RegexRepo] 迁移全局正则: ${prefsScripts.length} 条');
    }
  }
}
