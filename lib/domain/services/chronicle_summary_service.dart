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

  /// 总结Prompt模板（内置高质量版本，{custom_suffix}承接用户自定义指令）
  static const String basePrompt = '''
你是角色扮演记忆整理助手。请基于以下新增对话，更新现有记忆词条。

## 现有记忆词条
{existing_wiki}

## 新增对话（第{from_turn}轮到第{to_turn}轮）
{dialogue}

## 任务规则
- 只输出有变化的内容，没变化的词条不输出
- 用deprecated_ids标记已过时的旧词条id
- 重点关注：关系转折、情感节点、承诺/欠债、秘密揭露、立场改变、重大事件
- 不需要关注：日常闲聊、重复场景、无意义对话
- 词条描述用中文，简洁（单条50-120字）
- 重要度1-10：关系转折/秘密/重大事件=8-10，普通事件=4-6，日常细节=1-3
- 如需永久记住（如初次相遇、重大转折），设anchor=true

## 输出格式
严格输出JSON，不要任何解释：
{
  "upsert_entries": [
    {
      "id": "已有词条id（更新）或null（新建）",
      "type": "event|state|knowledge",
      "title": "简短标题",
      "content": "50-120字描述",
      "importance": 5,
      "always_inject": false,
      "anchor": false,
      "tags": ["关键词"],
      "entity_ids": ["关联实体名"]
    }
  ],
  "upsert_entities": [
    {
      "name": "实体名",
      "type": "person|place|item|concept",
      "description": "身份描述",
      "current_state": "当前状态",
      "aliases": []
    }
  ],
  "upsert_relationships": [
    {
      "from": "实体名",
      "to": "实体名",
      "type": "trust|friendship|romantic|hostile|family|mentor",
      "strength": 0,
      "description": "关系描述"
    }
  ],
  "upsert_emotions": [
    {
      "entity": "实体名",
      "emotion": "情感类型",
      "intensity": 5,
      "trigger": "触发原因",
      "active": true
    }
  ],
  "deprecated_ids": ["过时词条id"]
}

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
        );

        allEntries.addAll(partialOutput.entries);
        allEntities.addAll(partialOutput.entities);
        allRelationships.addAll(partialOutput.relationships);
        allEmotions.addAll(partialOutput.emotions);
        allDeprecatedIds.addAll(partialOutput.deprecatedIds);

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

    final prompt = basePrompt
        .replaceAll('{existing_wiki}', fullWikiContext.toString())
        .replaceAll('{from_turn}', fromTurn.toString())
        .replaceAll('{to_turn}', toTurn.toString())
        .replaceAll('{dialogue}', dialogueBuffer.toString())
        .replaceAll('{custom_suffix}', customSuffix)
        .replaceFirst('## 现有记忆词条', '$progressHint## 现有记忆词条');

    final rawResponse = await _llmService.generate(
      [{'role': 'user', 'content': prompt}],
      config,
    );

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