import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirakira/data/models/chat.dart';
import 'package:kirakira/data/models/chronicle.dart' as models;
import 'package:kirakira/data/repositories/chronicle_repository.dart';
import 'package:kirakira/data/repositories/chat_repository.dart';
import 'package:kirakira/domain/services/chronicle_orchestrator.dart';
import 'package:kirakira/domain/services/chronicle_recall_service.dart';
import 'package:kirakira/domain/services/chronicle_summary_service.dart';
import 'package:kirakira/presentation/providers/settings_providers.dart';
import 'package:kirakira/presentation/providers/vector_storage_providers.dart';

/// [CHRONICLE UI整合] Chronicle全局配置。
/// 修复二：设置是全局运行参数（SharedPreferences持久化），
/// 不依赖当前是否有聊天打开；每聊天只保留窗口归档状态（Drift表）。
final chronicleSettingsProvider =
    StateNotifierProvider<ChronicleSettingsNotifier, models.ChronicleSettings>(
        (ref) {
  return ChronicleSettingsNotifier();
});

/// 首次迁移选择：null=未决定，'migrated'=开启并清旧数据，'kept'=保留旧数据暂不开启。
/// 选择后持久化，迁移弹窗不再重复弹出。
final chronicleMigrationChoiceProvider =
    StateNotifierProvider<ChronicleMigrationChoiceNotifier, String?>((ref) {
  return ChronicleMigrationChoiceNotifier();
});

class ChronicleSettingsNotifier
    extends StateNotifier<models.ChronicleSettings> {
  static const _storageKey = 'chronicle_settings';

  ChronicleSettingsNotifier() : super(const models.ChronicleSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_storageKey);
      if (json != null) {
        final decoded =
            models.ChronicleSettings.fromJson(
                (jsonDecode(json) as Map).cast<String, dynamic>());
        state = decoded;
      }
    } catch (_) {
      // 读失败保持默认
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(state.toJson()));
    } catch (_) {
      // 写失败忽略
    }
  }

  void _update(models.ChronicleSettings next) {
    state = next;
    _saveSettings();
  }

  void setEnabled(bool v) => _update(state.copyWith(enabled: v));
  void setSummaryInterval(int v) =>
      _update(state.copyWith(summaryInterval: v));
  void setSummaryModel(String v) => _update(state.copyWith(summaryModel: v));
  void setSummaryBaseUrl(String v) =>
      _update(state.copyWith(summaryBaseUrl: v));
  void setSummaryApiKey(String v) =>
      _update(state.copyWith(summaryApiKey: v));
  void setSummaryModelName(String v) =>
      _update(state.copyWith(summaryModelName: v));
  void setTokenPressureThreshold(double v) =>
      _update(state.copyWith(tokenPressureThreshold: v));
  void setHotWindowSize(int v) => _update(state.copyWith(hotWindowSize: v));
  void setRagTopK(int v) => _update(state.copyWith(ragTopK: v));
  void setCustomPromptSuffix(String v) =>
      _update(state.copyWith(customPromptSuffix: v));
  void setMatureContentSuffix(String v) =>
      _update(state.copyWith(matureContentSuffix: v));
  void setMaxRetries(int v) => _update(state.copyWith(maxRetries: v));
  void setEmotionRecallEnabled(bool v) =>
      _update(state.copyWith(emotionRecallEnabled: v));
  void setMvuBridgeEnabled(bool v) =>
      _update(state.copyWith(mvuBridgeEnabled: v));
  void setSummaryPasses(int v) => _update(state.copyWith(summaryPasses: v));
}

class ChronicleMigrationChoiceNotifier extends StateNotifier<String?> {
  static const _storageKey = 'chronicle_migration_choice';

  ChronicleMigrationChoiceNotifier() : super(null) {
    _load();
  }


  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getString(_storageKey);
    } catch (_) {
      state = null;
    }
  }

  Future<void> _persist(String? v) async {
    state = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (v == null) {
        await prefs.remove(_storageKey);
      } else {
        await prefs.setString(_storageKey, v);
      }
    } catch (_) {}
  }

  /// 用户已做出迁移决定（含"无旧数据无需决定"场景），不再弹窗
  Future<void> setChoice(String v) => _persist(v);
}

/// [CHRONICLE Phase 2] Wiki结构化总结服务
final chronicleSummaryServiceProvider = Provider<ChronicleSummaryService>((ref) {
  return ChronicleSummaryService(ref.watch(llmServiceProvider));
});

/// [CHRONICLE Phase 3] 混合召回服务
final chronicleRecallServiceProvider = Provider<ChronicleRecallService>((ref) {
  return ChronicleRecallService(
    repo: ref.watch(chronicleRepositoryProvider),
    embedder: ref.watch(embeddingServiceProvider),
    vectorStorage: ref.watch(vectorStorageServiceProvider),
    vectorSettingsGetter: () => ref.read(vectorStorageSettingsProvider),
  );
});

/// [CHRONICLE Phase 1] 超级记忆调度器接线。
/// 首次读取时启动队列Timer（一般由第一条消息发送触发）。
final chronicleOrchestratorProvider = Provider<ChronicleOrchestrator>((ref) {
  final orchestrator = ChronicleOrchestrator(
    repo: ref.watch(chronicleRepositoryProvider),
    summarizationService: ref.watch(chatSummarizationServiceProvider),
    chronicleSummaryService: ref.watch(chronicleSummaryServiceProvider),
    embedder: ref.watch(embeddingServiceProvider),
    vectorStorage: ref.watch(vectorStorageServiceProvider),
    vectorSettingsGetter: () => ref.read(vectorStorageSettingsProvider),
    llmConfigGetter: () => ref.read(llmConfigProvider),
    settingsGetter: () => ref.read(chronicleSettingsProvider),
  );
  ref.onDispose(orchestrator.dispose);
  return orchestrator;
});

/// [改进4] 可视化分区（热/温/冷/超冷）。
class ChronicleZone {
  final String key; // 'hot'/'warm'/'cold'/'frozen'（图标选择用）
  final String name; // 热区/温区/冷区/超冷区
  final int startIndex; // 起始楼层（1-based，对齐聊天页楼层号）
  final int endIndex;
  final int messageCount;
  final bool hasOriginalText; // false = 原文已彻底淡出，只注入总结词条
  const ChronicleZone({
    required this.key,
    required this.name,
    required this.startIndex,
    required this.endIndex,
    required this.messageCount,
    required this.hasOriginalText,
  });
}

/// [改进4] 超级记忆工作状态可视化数据。
class ChronicleVisualizationData {
  final int unarchivedCount; // 未归档消息总数
  final int unarchivedUserTurns; // 未归档轮数（user消息计，1轮=user+AI）
  final int summaryInterval; // 总结阈值（轮）
  final double progress; // 归档进度 = 已归档 / 总楼层（archived / totalMessageCount）
  final int totalMessageCount; // 总楼层数（含隐藏楼层，与聊天页楼层总数一致）
  final int unarchivedStartFloor; // 首条未归档楼层（无未归档时 0）
  final int unarchivedEndFloor; // 末条未归档楼层
  final List<ChronicleZone> zones; // 已归档分区（新→旧）
  const ChronicleVisualizationData({
    required this.unarchivedCount,
    required this.unarchivedUserTurns,
    required this.summaryInterval,
    required this.progress,
    required this.totalMessageCount,
    required this.unarchivedStartFloor,
    required this.unarchivedEndFloor,
    required this.zones,
  });
}

/// [改进4] 可视化数据：按聊天拉取消息+归档状态，切五区。
/// autoDispose：状态 tab 关闭即销毁缓存，重进必重查，保证展示的是当前状态。
final chronicleVisualizationProvider = FutureProvider.autoDispose
    .family<ChronicleVisualizationData, String>((ref, chatId) async {
  final chatRepo = ref.watch(chatRepositoryProvider);
  final chronicleRepo = ref.watch(chronicleRepositoryProvider);
  final settings = ref.watch(chronicleSettingsProvider);

  final allMessages = await chatRepo.getMessages(chatId);
  final archivedIds = await chronicleRepo.getArchivedMessageIds(chatId);

  final unarchived = allMessages
      .where((m) => !archivedIds.contains(m.id) && !m.isHidden)
      .toList();
  final archived = allMessages
      .where((m) => archivedIds.contains(m.id) && !m.isHidden)
      .toList();
  final unarchivedUserTurns =
      unarchived.where((m) => m.role == MessageRole.user).length;

  // 楼层号对齐全消息序号（含隐藏楼层，与聊天页楼层一致）
  final floorOf = <String, int>{
    for (var i = 0; i < allMessages.length; i++) allMessages[i].id: i + 1,
  };

  // 分区：已归档集从新到旧按"一代归档"（summaryInterval 轮，1轮=user+AI≈2条消息）
  // 分批，与触发逻辑的归档批次一致：第0批=热区、第1批=温区、第2批=冷区
  // （原文+词条），更早=超冷区（只注入词条，原文已淡出）。
  final generationSize = (settings.summaryInterval * 2).clamp(2, 1 << 30);
  final zones = <ChronicleZone>[];
  var batchIndex = 0;
  for (var end = archived.length; end > 0; end -= generationSize) {
    final start = (end - generationSize).clamp(0, archived.length);
    final batch = archived.sublist(start, end);
    final name = switch (batchIndex) {
      0 => '热区',
      1 => '温区',
      2 => '冷区',
      _ => '超冷区',
    };
    final key = switch (batchIndex) {
      0 => 'hot',
      1 => 'warm',
      2 => 'cold',
      _ => 'frozen',
    };
    zones.add(ChronicleZone(
      key: key,
      name: name,
      startIndex: floorOf[batch.first.id] ?? start + 1,
      endIndex: floorOf[batch.last.id] ?? end,
      messageCount: batch.length,
      hasOriginalText: batchIndex <= 2,
    ));
    batchIndex++;
  }

  return ChronicleVisualizationData(
    unarchivedCount: unarchived.length,
    unarchivedUserTurns: unarchivedUserTurns,
    summaryInterval: settings.summaryInterval,
    progress: allMessages.isNotEmpty
        ? archived.length / allMessages.length
        : 0.0,
    totalMessageCount: allMessages.length,
    unarchivedStartFloor:
        unarchived.isEmpty ? 0 : (floorOf[unarchived.first.id] ?? 0),
    unarchivedEndFloor:
        unarchived.isEmpty ? 0 : (floorOf[unarchived.last.id] ?? 0),
    zones: zones,
  );
});
