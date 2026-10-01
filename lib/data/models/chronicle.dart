import 'dart:convert';

import 'package:kirakira/data/models/chat.dart' show ChatMessage;

/// Chronicle super-memory system data models.
///
/// Archive anchors use messageId sets instead of index numbers.
/// Token budget keeps a safety margin (estimates ±30%).

/// Memory entry type
enum MemoryEntryType {
  event, // Event: something that happened
  state, // State: current situation
  knowledge; // Knowledge: worldbook/setting facts

  static MemoryEntryType fromName(String? name) {
    return MemoryEntryType.values.firstWhere(
      (t) => t.name == name,
      orElse: () => MemoryEntryType.event,
    );
  }
}

/// Wiki entry (warm zone core, maps to the MemoryEntries table)
class MemoryEntry {
  final String id;
  final String chatId;
  final MemoryEntryType type;
  final String title;
  final String content; // 50-120 character concise description
  final int importance; // 1-10
  final bool alwaysInject; // Always inject into the fixed layer
  final bool anchor; // Anchor: never discarded
  final bool neverEvict; // Eviction protection
  final List<String> tags; // Keywords for hybrid retrieval
  final List<String> entityIds; // Linked entities
  final List<String> sourceMessageIds; // Source messages
  final int turnIndex; // Source turn (for time decay)
  final bool deprecated; // Deprecated flag (kept for history, not deleted)
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

  /// Text used for vectorization
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

/// Entity (person/place/item/concept)
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

/// Relationship between entities
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

/// Emotion node (roleplay-specific)
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

/// Summary task status
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

/// Chronicle user settings (global run parameters, persisted in SharedPreferences)
class ChronicleSettings {
  final bool enabled; // Master switch
  final int summaryInterval; // Turn trigger threshold 10-40
  final String summaryModel; // Empty = use main model (legacy field, kept for backward compatibility)
  final String summaryBaseUrl; // Chronicle-specific summary model base URL, empty = use main model
  final String summaryApiKey; // Chronicle-specific summary model API key, empty = use main model
  final String summaryModelName; // Chronicle-specific summary model name, empty = use main model
  final double summaryTemperature; // Default 0.2
  final double tokenPressureThreshold; // Token pressure trigger ratio 0.4-0.8
  final int hotWindowSize; // Hot zone window 10-40
  final int ragTopK; // Recall count 3-10
  final String customPromptSuffix; // User-defined suffix instruction
  final String matureContentSuffix; // Mature content supplementary instruction (separate field, independently toggleable)
  final bool emotionRecallEnabled; // Emotion recall bonus
  final bool mvuBridgeEnabled; // MVU threshold bridging
  final int maxRetries; // Max retries for failed tasks (stop enqueueing when exceeded, wait for user intervention)
  final int summaryPasses; // Summary passes (1-5) to improve distillation quality for long conversations

  const ChronicleSettings({
    this.enabled = true,
    this.summaryInterval = 20,
    this.summaryModel = '',
    this.summaryBaseUrl = '',
    this.summaryApiKey = '',
    this.summaryModelName = '',
    this.summaryTemperature = 0.2,
    this.tokenPressureThreshold = 0.6,
    this.hotWindowSize = 20,
    this.ragTopK = 5,
    this.customPromptSuffix = '',
    this.matureContentSuffix = '',
    this.emotionRecallEnabled = true,
    this.mvuBridgeEnabled = true,
    this.maxRetries = 3,
    this.summaryPasses = 3,
  });

  /// All three dedicated configs empty means the main chat model is used
  bool get summaryUsesMainModel =>
      summaryBaseUrl.isEmpty &&
      summaryApiKey.isEmpty &&
      summaryModelName.isEmpty;

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'summaryInterval': summaryInterval,
        'summaryModel': summaryModel,
        'summaryBaseUrl': summaryBaseUrl,
        'summaryApiKey': summaryApiKey,
        'summaryModelName': summaryModelName,
        'summaryTemperature': summaryTemperature,
        'tokenPressureThreshold': tokenPressureThreshold,
        'hotWindowSize': hotWindowSize,
        'ragTopK': ragTopK,
        'customPromptSuffix': customPromptSuffix,
        'matureContentSuffix': matureContentSuffix,
        'emotionRecallEnabled': emotionRecallEnabled,
        'mvuBridgeEnabled': mvuBridgeEnabled,
        'maxRetries': maxRetries,
        'summaryPasses': summaryPasses,
      };

  factory ChronicleSettings.fromJson(Map<String, dynamic> json) =>
      ChronicleSettings(
        enabled: json['enabled'] as bool? ?? true,
        summaryInterval: (json['summaryInterval'] as num?)?.toInt() ?? 20,
        summaryModel: json['summaryModel'] as String? ?? '',
        summaryBaseUrl: json['summaryBaseUrl'] as String? ?? '',
        summaryApiKey: json['summaryApiKey'] as String? ?? '',
        summaryModelName: json['summaryModelName'] as String? ?? '',
        summaryTemperature:
            (json['summaryTemperature'] as num?)?.toDouble() ?? 0.2,
        tokenPressureThreshold:
            (json['tokenPressureThreshold'] as num?)?.toDouble() ?? 0.6,
        hotWindowSize: (json['hotWindowSize'] as num?)?.toInt() ?? 20,
        ragTopK: (json['ragTopK'] as num?)?.toInt() ?? 5,
        customPromptSuffix: json['customPromptSuffix'] as String? ?? '',
        matureContentSuffix: json['matureContentSuffix'] as String? ?? '',
        emotionRecallEnabled: json['emotionRecallEnabled'] as bool? ?? true,
        mvuBridgeEnabled: json['mvuBridgeEnabled'] as bool? ?? true,
        maxRetries: (json['maxRetries'] as num?)?.toInt() ?? 3,
        summaryPasses: (json['summaryPasses'] as num?)?.toInt() ?? 3,
      );

  ChronicleSettings copyWith({
    bool? enabled,
    int? summaryInterval,
    String? summaryModel,
    String? summaryBaseUrl,
    String? summaryApiKey,
    String? summaryModelName,
    double? summaryTemperature,
    double? tokenPressureThreshold,
    int? hotWindowSize,
    int? ragTopK,
    String? customPromptSuffix,
    String? matureContentSuffix,
    bool? emotionRecallEnabled,
    bool? mvuBridgeEnabled,
    int? maxRetries,
    int? summaryPasses,
  }) {
    return ChronicleSettings(
      enabled: enabled ?? this.enabled,
      summaryInterval: summaryInterval ?? this.summaryInterval,
      summaryModel: summaryModel ?? this.summaryModel,
      summaryBaseUrl: summaryBaseUrl ?? this.summaryBaseUrl,
      summaryApiKey: summaryApiKey ?? this.summaryApiKey,
      summaryModelName: summaryModelName ?? this.summaryModelName,
      summaryTemperature: summaryTemperature ?? this.summaryTemperature,
      tokenPressureThreshold:
          tokenPressureThreshold ?? this.tokenPressureThreshold,
      hotWindowSize: hotWindowSize ?? this.hotWindowSize,
      ragTopK: ragTopK ?? this.ragTopK,
      customPromptSuffix: customPromptSuffix ?? this.customPromptSuffix,
      matureContentSuffix: matureContentSuffix ?? this.matureContentSuffix,
      emotionRecallEnabled: emotionRecallEnabled ?? this.emotionRecallEnabled,
      mvuBridgeEnabled: mvuBridgeEnabled ?? this.mvuBridgeEnabled,
      maxRetries: maxRetries ?? this.maxRetries,
      summaryPasses: summaryPasses ?? this.summaryPasses,
    );
  }
}

/// Four-window split result (Lost in the Middle: inject cold, warm, hot, then unarchived)
class WindowedMessages {
  /// Cold zone: windowSize turns before that are archived (low attention, injected near the middle-front)
  final List<ChatMessage> cold;
  /// Warm zone: previous windowSize turns archived (medium attention)
  final List<ChatMessage> warm;
  /// Hot zone: most recent windowSize turns archived (high attention)
  final List<ChatMessage> hot;
  /// Unarchived zone: all unarchived turns (highest attention, injected at the end)
  final List<ChatMessage> unarchived;

  const WindowedMessages({
    this.cold = const [],
    this.warm = const [],
    this.hot = const [],
    this.unarchived = const [],
  });

  /// Injection order: cold, warm, hot, then unarchived (attention increases toward the end)
  List<ChatMessage> get injectionOrder =>
      [...cold, ...warm, ...hot, ...unarchived];
}

/// LLM structured output (summary pipeline JSON protocol)

class UpsertEntryInstruction {
  final String? id; // Non-null id = update, null = create
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

/// Full parsed result of the LLM summary output
class ChronicleSummaryOutput {
  final List<UpsertEntryInstruction> entries;
  final List<UpsertEntityInstruction> entities;
  final List<UpsertRelationshipInstruction> relationships;
  final List<UpsertEmotionInstruction> emotions;
  final List<String> deprecatedIds;
  /// Fallback plain text when parsing fails (same quality as legacy summaries, non-blocking)
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

/// Utility functions

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
