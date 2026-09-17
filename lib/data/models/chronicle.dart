import 'dart:convert';

import 'package:kirakira/data/models/chat.dart' show ChatMessage;

/// ═══════════════════════════════════════════════════════════
/// [CHRONICLE] 超级记忆系统数据模型
/// 蓝图：DiaoYan/UI_UX/SuperMemory_Architecture.md
/// 调整A：归档锚点用 messageId 集合，不用 index 序号
/// 调整E：token预算留安全裕度（估算±30%）
/// ═══════════════════════════════════════════════════════════

/// 记忆词条类型
enum MemoryEntryType {
  event, // 事件：发生了什么
  state, // 状态：当前情境/处境
  knowledge; // 知识：世界观/设定事实

  static MemoryEntryType fromName(String? name) {
    return MemoryEntryType.values.firstWhere(
      (t) => t.name == name,
      orElse: () => MemoryEntryType.event,
    );
  }
}

/// Wiki词条（温层核心，对应 MemoryEntries 表）
class MemoryEntry {
  final String id;
  final String chatId;
  final MemoryEntryType type;
  final String title;
  final String content; // 50~120字精炼描述
  final int importance; // 1-10
  final bool alwaysInject; // 始终注入固定层
  final bool anchor; // 锚点：永不丢弃
  final bool neverEvict; // 驱逐保护
  final List<String> tags; // 关键词（混合检索用）
  final List<String> entityIds; // 关联实体
  final List<String> sourceMessageIds; // 来源消息（调整A）
  final int turnIndex; // 来源轮次（时间衰减用）
  final bool deprecated; // 过时标记（不删除，保留历史）
  final String? vectorId; // VectorDocument.id
  final DateTime createdAt;
  final DateTime updatedAt;

  const MemoryEntry({
    required this.id,
    required this.chatId,
    this.type = MemoryEntryType.event,
    required this.title,
    required this.content,
    this.importance = 5,
    this.alwaysInject = false,
    this.anchor = false,
    this.neverEvict = false,
    this.tags = const [],
    this.entityIds = const [],
    this.sourceMessageIds = const [],
    this.turnIndex = 0,
    this.deprecated = false,
    this.vectorId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'chatId': chatId,
        'type': type.name,
        'title': title,
        'content': content,
        'importance': importance,
        'alwaysInject': alwaysInject,
        'anchor': anchor,
        'neverEvict': neverEvict,
        'tags': tags,
        'entityIds': entityIds,
        'sourceMessageIds': sourceMessageIds,
        'turnIndex': turnIndex,
        'deprecated': deprecated,
        'vectorId': vectorId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory MemoryEntry.fromJson(Map<String, dynamic> json) => MemoryEntry(
        id: json['id'] as String,
        chatId: json['chatId'] as String? ?? '',
        type: MemoryEntryType.fromName(json['type'] as String?),
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        importance: (json['importance'] as num?)?.toInt() ?? 5,
        alwaysInject: json['alwaysInject'] as bool? ?? false,
        anchor: json['anchor'] as bool? ?? false,
        neverEvict: json['neverEvict'] as bool? ?? false,
        tags: _parseStringList(json['tags']),
        entityIds: _parseStringList(json['entityIds']),
        sourceMessageIds: _parseStringList(json['sourceMessageIds']),
        turnIndex: (json['turnIndex'] as num?)?.toInt() ?? 0,
        deprecated: json['deprecated'] as bool? ?? false,
        vectorId: json['vectorId'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : DateTime.now(),
      );

  /// 供向量化的文本
  String get vectorText => '$title\n$content\n${tags.join(' ')}';

  MemoryEntry copyWith({
    String? id,
    String? chatId,
    MemoryEntryType? type,
    String? title,
    String? content,
    int? importance,
    bool? alwaysInject,
    bool? anchor,
    bool? neverEvict,
    List<String>? tags,
    List<String>? entityIds,
    List<String>? sourceMessageIds,
    int? turnIndex,
    bool? deprecated,
    String? vectorId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MemoryEntry(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      importance: importance ?? this.importance,
      alwaysInject: alwaysInject ?? this.alwaysInject,
      anchor: anchor ?? this.anchor,
      neverEvict: neverEvict ?? this.neverEvict,
      tags: tags ?? this.tags,
      entityIds: entityIds ?? this.entityIds,
      sourceMessageIds: sourceMessageIds ?? this.sourceMessageIds,
      turnIndex: turnIndex ?? this.turnIndex,
      deprecated: deprecated ?? this.deprecated,
      vectorId: vectorId ?? this.vectorId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 实体（人物/地点/物品/概念）
enum MemoryEntityType { person, place, item, concept }

class MemoryEntity {
  final String id;
  final String chatId;
  final String name;
  final MemoryEntityType type;
  final String description;
  final String currentState;
  final List<String> aliases;
  final Map<String, dynamic> attributes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MemoryEntity({
    required this.id,
    required this.chatId,
    required this.name,
    this.type = MemoryEntityType.person,
    this.description = '',
    this.currentState = '',
    this.aliases = const [],
    this.attributes = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'chatId': chatId,
        'name': name,
        'type': type.name,
        'description': description,
        'currentState': currentState,
        'aliases': aliases,
        'attributes': attributes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory MemoryEntity.fromJson(Map<String, dynamic> json) => MemoryEntity(
        id: json['id'] as String,
        chatId: json['chatId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        type: MemoryEntityType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => MemoryEntityType.person,
        ),
        description: json['description'] as String? ?? '',
        currentState: json['currentState'] as String? ?? '',
        aliases: _parseStringList(json['aliases']),
        attributes: json['attributes'] is Map
            ? Map<String, dynamic>.from(json['attributes'] as Map)
            : {},
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : DateTime.now(),
      );

  MemoryEntity copyWith({
    String? id,
    String? chatId,
    String? name,
    MemoryEntityType? type,
    String? description,
    String? currentState,
    List<String>? aliases,
    Map<String, dynamic>? attributes,
    DateTime? updatedAt,
  }) {
    return MemoryEntity(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      name: name ?? this.name,
      type: type ?? this.type,
      description: description ?? this.description,
      currentState: currentState ?? this.currentState,
      aliases: aliases ?? this.aliases,
      attributes: attributes ?? this.attributes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 关系（实体间）
class MemoryRelationship {
  final String id;
  final String chatId;
  final String fromEntityId;
  final String toEntityId;
  final String relationType; // trust/friendship/romantic/hostile/family/mentor
  final int strength; // -100 ~ 100
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MemoryRelationship({
    required this.id,
    required this.chatId,
    required this.fromEntityId,
    required this.toEntityId,
    this.relationType = 'trust',
    this.strength = 0,
    this.description = '',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'chatId': chatId,
        'fromEntityId': fromEntityId,
        'toEntityId': toEntityId,
        'relationType': relationType,
        'strength': strength,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory MemoryRelationship.fromJson(Map<String, dynamic> json) =>
      MemoryRelationship(
        id: json['id'] as String,
        chatId: json['chatId'] as String? ?? '',
        fromEntityId: json['fromEntityId'] as String? ?? '',
        toEntityId: json['toEntityId'] as String? ?? '',
        relationType: json['relationType'] as String? ?? 'trust',
        strength: (json['strength'] as num?)?.toInt() ?? 0,
        description: json['description'] as String? ?? '',
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : DateTime.now(),
      );
}

/// 情感节点（roleplay专用）
class EmotionNode {
  final String id;
  final String chatId;
  final String entityId;
  final String emotion;
  final int intensity; // 1-10
  final String trigger;
  final int turnIndex;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EmotionNode({
    required this.id,
    required this.chatId,
    required this.entityId,
    this.emotion = '',
    this.intensity = 5,
    this.trigger = '',
    this.turnIndex = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'chatId': chatId,
        'entityId': entityId,
        'emotion': emotion,
        'intensity': intensity,
        'trigger': trigger,
        'turnIndex': turnIndex,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory EmotionNode.fromJson(Map<String, dynamic> json) => EmotionNode(
        id: json['id'] as String,
        chatId: json['chatId'] as String? ?? '',
        entityId: json['entityId'] as String? ?? '',
        emotion: json['emotion'] as String? ?? '',
        intensity: (json['intensity'] as num?)?.toInt() ?? 5,
        trigger: json['trigger'] as String? ?? '',
        turnIndex: (json['turnIndex'] as num?)?.toInt() ?? 0,
        isActive: json['isActive'] as bool? ?? true,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : DateTime.now(),
      );
}

/// 总结任务状态
enum SummaryTaskStatus {
  pending,
  running,
  done,
  failed;

  static SummaryTaskStatus fromName(String? name) {
    return SummaryTaskStatus.values.firstWhere(
      (s) => s.name == name,
      orElse: () => SummaryTaskStatus.pending,
    );
  }
}

/// Chronicle 用户配置（存 ChronicleStates.settingsJson）
class ChronicleSettings {
  final bool enabled; // 总开关
  final int summaryInterval; // 轮次触发阈值 10-40
  final String summaryModel; // 空=沿用主模型
  final double summaryTemperature; // 默认0.2
  final int hotWindowSize; // 热区窗口 10-40
  final int ragTopK; // 召回数量 3-10
  final String customPromptSuffix; // 用户自定义追加指令
  final bool emotionRecallEnabled; // 情感召回加成
  final bool mvuBridgeEnabled; // MVU阈值桥接

  const ChronicleSettings({
    this.enabled = true,
    this.summaryInterval = 20,
    this.summaryModel = '',
    this.summaryTemperature = 0.2,
    this.hotWindowSize = 20,
    this.ragTopK = 5,
    this.customPromptSuffix = '',
    this.emotionRecallEnabled = true,
    this.mvuBridgeEnabled = true,
  });

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'summaryInterval': summaryInterval,
        'summaryModel': summaryModel,
        'summaryTemperature': summaryTemperature,
        'hotWindowSize': hotWindowSize,
        'ragTopK': ragTopK,
        'customPromptSuffix': customPromptSuffix,
        'emotionRecallEnabled': emotionRecallEnabled,
        'mvuBridgeEnabled': mvuBridgeEnabled,
      };

  factory ChronicleSettings.fromJson(Map<String, dynamic> json) =>
      ChronicleSettings(
        enabled: json['enabled'] as bool? ?? true,
        summaryInterval: (json['summaryInterval'] as num?)?.toInt() ?? 20,
        summaryModel: json['summaryModel'] as String? ?? '',
        summaryTemperature:
            (json['summaryTemperature'] as num?)?.toDouble() ?? 0.2,
        hotWindowSize: (json['hotWindowSize'] as num?)?.toInt() ?? 20,
        ragTopK: (json['ragTopK'] as num?)?.toInt() ?? 5,
        customPromptSuffix: json['customPromptSuffix'] as String? ?? '',
        emotionRecallEnabled: json['emotionRecallEnabled'] as bool? ?? true,
        mvuBridgeEnabled: json['mvuBridgeEnabled'] as bool? ?? true,
      );

  ChronicleSettings copyWith({
    bool? enabled,
    int? summaryInterval,
    String? summaryModel,
    double? summaryTemperature,
    int? hotWindowSize,
    int? ragTopK,
    String? customPromptSuffix,
    bool? emotionRecallEnabled,
    bool? mvuBridgeEnabled,
  }) {
    return ChronicleSettings(
      enabled: enabled ?? this.enabled,
      summaryInterval: summaryInterval ?? this.summaryInterval,
      summaryModel: summaryModel ?? this.summaryModel,
      summaryTemperature: summaryTemperature ?? this.summaryTemperature,
      hotWindowSize: hotWindowSize ?? this.hotWindowSize,
      ragTopK: ragTopK ?? this.ragTopK,
      customPromptSuffix: customPromptSuffix ?? this.customPromptSuffix,
      emotionRecallEnabled: emotionRecallEnabled ?? this.emotionRecallEnabled,
      mvuBridgeEnabled: mvuBridgeEnabled ?? this.mvuBridgeEnabled,
    );
  }
}

/// 三窗口切分结果（Lost in the Middle利用：冷→温→热注入）
class WindowedMessages {
  /// 冷区：最早一批已归档（低注意力，注入在中间靠前）
  final List<ChatMessage> cold;
  /// 温区：最近一批已归档（渐进淡出中间带）
  final List<ChatMessage> warm;
  /// 热区：最近未归档（高注意力，注入在末尾）
  final List<ChatMessage> hot;

  const WindowedMessages({
    this.cold = const [],
    this.warm = const [],
    this.hot = const [],
  });

  /// 注入顺序：冷 → 温 → 热（越靠近末尾注意力越高）
  List<ChatMessage> get injectionOrder => [...cold, ...warm, ...hot];
}

/// ═══════════════════════════════════════════════════════════
/// LLM 结构化输出（Phase 2 总结管线 JSON 协议）
/// ═══════════════════════════════════════════════════════════

class UpsertEntryInstruction {
  final String? id; // 有id=更新，null=新建
  final MemoryEntryType type;
  final String title;
  final String content;
  final int importance;
  final bool alwaysInject;
  final bool anchor;
  final List<String> tags;
  final List<String> entityNames;

  const UpsertEntryInstruction({
    this.id,
    this.type = MemoryEntryType.event,
    required this.title,
    required this.content,
    this.importance = 5,
    this.alwaysInject = false,
    this.anchor = false,
    this.tags = const [],
    this.entityNames = const [],
  });
}

class UpsertEntityInstruction {
  final String name;
  final MemoryEntityType type;
  final String description;
  final String currentState;
  final List<String> aliases;

  const UpsertEntityInstruction({
    required this.name,
    this.type = MemoryEntityType.person,
    this.description = '',
    this.currentState = '',
    this.aliases = const [],
  });
}

class UpsertRelationshipInstruction {
  final String fromName;
  final String toName;
  final String relationType;
  final int strength;
  final String description;

  const UpsertRelationshipInstruction({
    this.fromName = '',
    this.toName = '',
    this.relationType = 'trust',
    this.strength = 0,
    this.description = '',
  });
}

class UpsertEmotionInstruction {
  final String entityName;
  final String emotion;
  final int intensity;
  final String trigger;
  final bool active;

  const UpsertEmotionInstruction({
    this.entityName = '',
    required this.emotion,
    this.intensity = 5,
    this.trigger = '',
    this.active = true,
  });
}

/// LLM 总结输出的完整解析结果
class ChronicleSummaryOutput {
  final List<UpsertEntryInstruction> entries;
  final List<UpsertEntityInstruction> entities;
  final List<UpsertRelationshipInstruction> relationships;
  final List<UpsertEmotionInstruction> emotions;
  final List<String> deprecatedIds;
  /// 解析失败时的降级纯文本（保持与旧总结同等质量，不阻断）
  final String? fallbackText;

  const ChronicleSummaryOutput({
    this.entries = const [],
    this.entities = const [],
    this.relationships = const [],
    this.emotions = const [],
    this.deprecatedIds = const [],
    this.fallbackText,
  });

  bool get isEmpty =>
      entries.isEmpty &&
      entities.isEmpty &&
      relationships.isEmpty &&
      emotions.isEmpty &&
      deprecatedIds.isEmpty &&
      fallbackText == null;
}

/// ═══════════════════════════════════════════════════════════
/// 工具函数
/// ═══════════════════════════════════════════════════════════

List<String> _parseStringList(dynamic json) {
  if (json is List) {
    return json.map((e) => e.toString()).toList();
  }
  if (json is String && json.isNotEmpty) {
    try {
      final list = jsonDecode(json) as List;
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }
  return [];
}
