import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirakira/data/models/chronicle.dart' as models;
import 'package:kirakira/data/repositories/chronicle_repository.dart';
import 'package:kirakira/domain/services/chronicle_orchestrator.dart';
import 'package:kirakira/domain/services/chronicle_recall_service.dart';
import 'package:kirakira/domain/services/chronicle_summary_service.dart';
import 'package:kirakira/domain/services/chat_summarization_service.dart';
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
