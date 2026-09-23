import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:kirakira/data/models/chat.dart';
import 'package:kirakira/data/models/chronicle.dart' as models;
import 'package:kirakira/domain/services/llm_service.dart';

/// [CHRONICLE Phase 2] Wiki结构化总结服务。
///
/// 单次LLM调用产出三层输出：
/// ① 事件词条（MemoryEntry）② 实体/关系patch ③ 情感节点
/// JSON解析失败 → 降级纯文本词条（H5：保持与旧总结同等质量，不阻断）。
class ChronicleSummaryService {
  final LLMService _llmService;

  ChronicleSummaryService(this._llmService);

  /// 总结Prompt模板（内置专业记忆提取版本，{custom_suffix}承接用户自定义指令）。
  /// 设计参考：Zep/Graphiti时序知识图谱（时序标记+事实失效）、MemGPT分层记忆、
  /// A-MEM结构化笔记。硬性约束前置+编号列表+正反例，提升中端模型遵循率。
  static const String basePrompt = '''
你是角色扮演记忆整理助手。从新增对话中提取记忆词条，更新现有词条库；没有值得记录的内容就输出空数组，宁缺毋滥。

## 硬性规则
1. 每段对话提炼3-8条词条，按维度分条：事件经过/关系变化/人物状态/世界信息/重要承诺，禁止把不同场景压进同一条
2. content必须以时序标记开头（[第N轮]或[剧情时间点]），全程第三人称+角色名描述，禁止"用户/AI"
3. 单条content为100-500字，写清时间/地点/言行/因果/后果，信息密度优先；超过500字必须拆成多条
4. anchor=true仅限不可逆转折点（初次相遇/死亡/关系确立），alwaysInject=true仅限角色核心身份（姓名/阵营/核心能力），其余一律false
5. 直接跳过不建词条：闲聊、重复日常（同场景第三次出现）、纯环境描写、无情节转折的NSFW动作描写
6. 新词条完全覆盖旧词条内容时，才把旧词条id放入deprecated_ids；不确定是否覆盖就共存

## importance评分标准
9-10：不可逆转折点（初次相遇/死亡/重大背叛/关系确立）
7-8：明显推进剧情（秘密揭露/承诺/立场改变/关系深化）
5-6：有意义的互动（情感表达/重要对话/能力展示）
3-4：日常但有记录价值（习惯/偏好/轻微冲突）
1-2：纯粹闲聊或重复，不建词条

## 输出格式
严格输出JSON，不要任何解释：
{
"upsert_entries": [{"id": "旧词条id（更新）或null（新建）", "type": "event|state|knowledge", "title": "含时序的简短标题", "content": "100-500字描述", "importance": 5, "always_inject": false, "anchor": false, "tags": ["关键词"], "entity_ids": ["关联实体名"]}],
"upsert_entities": [{"name": "实体名", "type": "person|place|item|concept", "description": "身份描述", "current_state": "当前状态", "aliases": ["别名"]}],
"upsert_relationships": [{"from": "实体名", "to": "实体名", "type": "trust|friendship|romantic|hostile|family|mentor", "strength": 0, "description": "关系描述"}],
"upsert_emotions": [{"entity": "实体名", "emotion": "情感类型", "intensity": 5, "trigger": "触发原因", "active": true}],
"deprecated_ids": []
}
正例：
{"type":"event","title":"第12轮：长伊救下墨雨","content":"[第12轮] 墨雨在山崖边被追杀，长伊以御剑术拦截刺客，以一敌三险胜。战后墨雨沉默片刻，第一次正视长伊，低声道谢。此前两人关系处于敌对/戒备阶段，此事件构成关系转折的直接起点。长伊右臂受剑伤，战斗力暂时削弱。","importance":8,"anchor":false,"always_inject":false,"tags":["关系转折","战斗","长伊受伤"]}
❌ 反例（禁止输出此类）：
{"title":"两人交流","content":"长伊和墨雨进行了一次对话，气氛有些紧张。","importance":5,"anchor":true}
反例问题：无时序无细节无信息量、评分随意、日常对话不应标anchor。

## 现有记忆词条（方括号内id供deprecated_ids引用）
{existing_wiki}

## 新增对话（第{from_turn}轮到第{to_turn}轮）
{dialogue}

{custom_suffix}''';

  /// 生成结构化总结（支持分段渐进式提炼）。
  ///
  /// passes=1: 单次调用；passes>1: 多段渐进，每段产出临时词条供下段参考。
  Future<models.ChronicleSummaryOutput> summarize({
    required List<ChatMessage> messages,
    required String existingWikiText,
    required models.ChronicleSettings settings,
    required LLMConfig config,
    int fromTurn = 0,
    int toTurn = 0,
    String characterName = 'Char',
    String userName = 'User',
    String extraRequirement = '',
  }) async {
    if (messages.isEmpty) return const models.ChronicleSummaryOutput();

    final passes = settings.summaryPasses.clamp(1, 5);

    if (passes == 1) {
      return _summarizeChunk(
        messages: messages,
        existingWikiText: existingWikiText,
        accumulatedTempWiki: '',
        settings: settings,
        config: config,
        fromTurn: fromTurn,
        toTurn: toTurn,
        currentPass: 1,
        totalPasses: 1,
        characterName: characterName,
        userName: userName,
        extraRequirement: extraRequirement,
      );
    }

    final chunkSize = (messages.length / passes).ceil();
    final allEntries = <models.UpsertEntryInstruction>[];
    final allEntities = <models.UpsertEntityInstruction>[];
    final allRelationships = <models.UpsertRelationshipInstruction>[];
    final allEmotions = <models.UpsertEmotionInstruction>[];
    final allDeprecatedIds = <String>[];
    String accumulatedTempWiki = '';

    for (int pass = 0; pass < passes; pass++) {
      final start = pass * chunkSize;
      final end = ((pass + 1) * chunkSize).clamp(0, messages.length);
      if (start >= messages.length) break;

      final chunk = messages.sublist(start, end);

      try {
        final partialOutput = await _summarizeChunk(
          messages: chunk,
          existingWikiText: existingWikiText,
          accumulatedTempWiki: accumulatedTempWiki,
          settings: settings,
          config: config,
          fromTurn: fromTurn + start,
          toTurn: fromTurn + end,
          currentPass: pass + 1,
          totalPasses: passes,
          characterName: characterName,
          userName: userName,
          extraRequirement: extraRequirement,
        );

        allEntries.addAll(partialOutput.entries);
        allEntities.addAll(partialOutput.entities);
        allRelationships.addAll(partialOutput.relationships);
        allEmotions.addAll(partialOutput.emotions);
        allDeprecatedIds.addAll(partialOutput.deprecatedIds);

        // fallback兜底：该段JSON解析失败时，把原文转为词条，不丢弃信息
        if (partialOutput.entries.isEmpty &&
            partialOutput.fallbackText != null &&
            partialOutput.fallbackText!.trim().isNotEmpty) {
          debugPrint('[CHRONICLE] 第${pass + 1}段JSON解析失败，降级为fallback词条');
          allEntries.add(models.UpsertEntryInstruction(
            id: null,
            type: models.MemoryEntryType.event,
            title: '第${fromTurn + pass * chunkSize ~/ 2}轮附近：降级总结',
            content: partialOutput.fallbackText!.trim(),
            importance: 4,
            alwaysInject: false,
            anchor: false,
            tags: const ['降级总结'],
            entityNames: const [],
          ));
        }

        // 把本轮产出拼入临时wiki，供下轮参考
        if (pass < passes - 1) {
          accumulatedTempWiki += '\n\n## 临时词条（第${pass + 1}段产出）\n';
          for (final e in partialOutput.entries) {
            accumulatedTempWiki += '- [词条] ${e.title}: ${e.content}\n';
          }
          for (final e in partialOutput.entities) {
            accumulatedTempWiki += '- [实体] ${e.name}(${e.type.name}): ${e.description}\n';
          }
        }
      } catch (e) {
        debugPrint('[CHRONICLE] 第${pass + 1}段总结失败: $e，跳过该段');
        continue;
      }
    }

    if (allEntries.isEmpty &&
        allEntities.isEmpty &&
        allRelationships.isEmpty &&
        allEmotions.isEmpty &&
        allDeprecatedIds.isEmpty) {
      return const models.ChronicleSummaryOutput();
    }

    return models.ChronicleSummaryOutput(
      entries: allEntries,
      entities: allEntities,
      relationships: allRelationships,
      emotions: allEmotions,
      deprecatedIds: allDeprecatedIds,
    );
  }

  /// 单段总结（内部方法）
  Future<models.ChronicleSummaryOutput> _summarizeChunk({
    required List<ChatMessage> messages,
    required String existingWikiText,
    required String accumulatedTempWiki,
    required models.ChronicleSettings settings,
    required LLMConfig config,
    required int fromTurn,
    required int toTurn,
    required int currentPass,
    required int totalPasses,
    String characterName = 'Char',
    String userName = 'User',
    String extraRequirement = '',
  }) async {
    final dialogueBuffer = StringBuffer();
    for (final msg in messages) {
      final role = msg.role == MessageRole.user ? userName : characterName;
      dialogueBuffer.writeln('$role: ${msg.content}');
    }

    final fullWikiContext = StringBuffer();
    if (existingWikiText.isNotEmpty) {
      fullWikiContext.writeln('### 现有正式词条（已入库）');
      fullWikiContext.writeln(existingWikiText);
    }
    if (accumulatedTempWiki.isNotEmpty) {
      fullWikiContext.writeln(accumulatedTempWiki);
    }

    final progressHint = totalPasses > 1
        ? '\n## 当前处理进度\n这是第 $currentPass/$totalPasses 段对话。'
            '${currentPass > 1 ? '前几段已提炼出临时词条（见上文），本段需保持上下文连贯。' : ''}\n'
        : '';

    // 用户自定义追加 + 成人内容补充指令（独立字段，拼入同一占位符）
    final customSuffix = [
      settings.customPromptSuffix,
      settings.matureContentSuffix,
    ].where((s) => s.trim().isNotEmpty).join('\n\n');

    // 本次额外要求（单条重新总结场景，追加在custom_suffix之后）
    final extraBlock = extraRequirement.trim().isNotEmpty
        ? '\n## 本次额外要求\n${extraRequirement.trim()}\n'
        : '';

    final prompt = basePrompt
        .replaceAll('{existing_wiki}', fullWikiContext.toString())
        .replaceAll('{from_turn}', fromTurn.toString())
        .replaceAll('{to_turn}', toTurn.toString())
        .replaceAll('{dialogue}', dialogueBuffer.toString())
        .replaceAll('{custom_suffix}', customSuffix)
        .replaceFirst('## 现有记忆词条', '$progressHint## 现有记忆词条') +
        extraBlock;

    final rawResponse = await _llmService.generate(
      [{'role': 'user', 'content': prompt}],
      config,
    );

    debugPrint('[CHRONICLE] chunk pass=$currentPass raw=${rawResponse.length}chars preview=${rawResponse.substring(0, rawResponse.length.clamp(0, 100))}');
    return parseSummaryOutput(rawResponse);
  }

  static models.ChronicleSummaryOutput parseSummaryOutput(String raw) {
    final jsonStr = _extractJson(raw);
    if (jsonStr == null) {
      debugPrint('[CHRONICLE] JSON提取失败，降级纯文本词条');
      return models.ChronicleSummaryOutput(fallbackText: raw);
    }
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      final entries = <models.UpsertEntryInstruction>[];
      for (final e in (data['upsert_entries'] as List? ?? const [])) {
        if (e is! Map) continue;
        entries.add(models.UpsertEntryInstruction(
          id: e['id'] as String?,
          type: models.MemoryEntryType.fromName(e['type'] as String?),
          title: (e['title'] as String?)?.trim() ?? '',
          content: (e['content'] as String?)?.trim() ?? '',
          importance: _clampInt(e['importance'], 1, 10, 5),
          alwaysInject: e['always_inject'] as bool? ?? false,
          anchor: e['anchor'] as bool? ?? false,
          tags: _stringList(e['tags']),
          entityNames: _stringList(e['entity_ids']),
        ));
      }

      final entities = <models.UpsertEntityInstruction>[];
      for (final e in (data['upsert_entities'] as List? ?? const [])) {
        if (e is! Map) continue;
        entities.add(models.UpsertEntityInstruction(
          name: (e['name'] as String?)?.trim() ?? '',
          type: models.MemoryEntityType.values.firstWhere(
            (t) => t.name == e['type'],
            orElse: () => models.MemoryEntityType.person,
          ),
          description: e['description'] as String? ?? '',
          currentState: e['current_state'] as String? ?? '',
          aliases: _stringList(e['aliases']),
        ));
      }

      final relationships = <models.UpsertRelationshipInstruction>[];
      for (final e in (data['upsert_relationships'] as List? ?? const [])) {
        if (e is! Map) continue;
        relationships.add(models.UpsertRelationshipInstruction(
          fromName: (e['from'] as String?)?.trim() ?? '',
          toName: (e['to'] as String?)?.trim() ?? '',
          relationType: e['type'] as String? ?? 'trust',
          strength: _clampInt(e['strength'], -100, 100, 0),
          description: e['description'] as String? ?? '',
        ));
      }

      final emotions = <models.UpsertEmotionInstruction>[];
      for (final e in (data['upsert_emotions'] as List? ?? const [])) {
        if (e is! Map) continue;
        emotions.add(models.UpsertEmotionInstruction(
          entityName: (e['entity'] as String?)?.trim() ?? '',
          emotion: (e['emotion'] as String?)?.trim() ?? '',
          intensity: _clampInt(e['intensity'], 1, 10, 5),
          trigger: e['trigger'] as String? ?? '',
          active: e['active'] as bool? ?? true,
        ));
      }

      final deprecatedIds = _stringList(data['deprecated_ids']);

      if (entries.isEmpty &&
          entities.isEmpty &&
          relationships.isEmpty &&
          emotions.isEmpty &&
          deprecatedIds.isEmpty) {
        return const models.ChronicleSummaryOutput();
      }

      return models.ChronicleSummaryOutput(
        entries: entries,
        entities: entities,
        relationships: relationships,
        emotions: emotions,
        deprecatedIds: deprecatedIds,
      );
    } catch (e) {
      debugPrint('[CHRONICLE] JSON解析失败($e)，降级纯文本词条');
      return models.ChronicleSummaryOutput(fallbackText: raw);
    }
  }

  static String? _extractJson(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text
          .replaceAll(RegExp(r'^```\w*\s*'), '')
          .replaceAll(RegExp(r'\s*```$'), '');
    }
    final start = text.indexOf('{');
    if (start < 0) return null;
    final end = text.lastIndexOf('}');
    if (end <= start) return null;
    return text.substring(start, end + 1);
  }

  static int _clampInt(dynamic v, int min, int max, int fallback) {
    final n = v is num ? v.toInt() : fallback;
    if (n < min) return min;
    if (n > max) return max;
    return n;
  }

  static List<String> _stringList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return const [];
  }
}