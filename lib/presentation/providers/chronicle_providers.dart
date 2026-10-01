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

/// Global Chronicle configuration.
/// Settings are global runtime parameters persisted to SharedPreferences and
/// do not depend on whether a chat is open; per-chat state only tracks window
/// archive status (Drift table).
final chronicleSettingsProvider =
    StateNotifierProvider<ChronicleSettingsNotifier, models.ChronicleSettings>(
        (ref) {
  return ChronicleSettingsNotifier();
});

/// First-run migration choice: null = undecided, 'migrated' = enable and clear
/// legacy data, 'kept' = keep legacy data but stay disabled.
/// Persisted after the choice so the migration dialog never reappears.
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
      // Keep defaults when reading fails
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(state.toJson()));
    } catch (_) {
      // Ignore write failures
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

  /// Migration decision recorded (including "no legacy data" case); the dialog
  /// is not shown again.
  Future<void> setChoice(String v) => _persist(v);
}

/// Wiki structured summarization service
final chronicleSummaryServiceProvider = Provider<ChronicleSummaryService>((ref) {
  return ChronicleSummaryService(ref.watch(llmServiceProvider));
});

/// Hybrid recall service
final chronicleRecallServiceProvider = Provider<ChronicleRecallService>((ref) {
  return ChronicleRecallService(
    repo: ref.watch(chronicleRepositoryProvider),
    embedder: ref.watch(embeddingServiceProvider),
    vectorStorage: ref.watch(vectorStorageServiceProvider),
    vectorSettingsGetter: () => ref.read(vectorStorageSettingsProvider),
  );
});

/// Chronicle orchestrator wiring.
/// The queue timer starts on first read (normally triggered by sending the
/// first message).
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

/// Visualized archive zone (hot/warm/cold/frozen).
class ChronicleZone {
  final String key; // 'hot'/'warm'/'cold'/'frozen' (for icon selection)
  final String name; // hot/warm/cold/frozen zone label
  final int startIndex; // starting floor (1-based, matches chat page floors)
  final int endIndex;
  final int messageCount;
  final bool hasOriginalText; // false = original text fully aged out; only summary entries are injected
  const ChronicleZone({
    required this.key,
    required this.name,
    required this.startIndex,
    required this.endIndex,
    required this.messageCount,
    required this.hasOriginalText,
  });
}

/// Visual state data for the Chronicle workspace.
class ChronicleVisualizationData {
  final int unarchivedCount; // total unarchived messages
  final int unarchivedUserTurns; // unarchived turns (counted by user messages; 1 turn = user + AI)
  final int summaryInterval; // summarize threshold (turns)
  final double progress; // archive progress = archived / total message count
  final int totalMessageCount; // total floors (incl. hidden, matches chat page)
  final int unarchivedStartFloor; // first unarchived floor (0 when none)
  final int unarchivedEndFloor; // last unarchived floor
  final List<ChronicleZone> zones; // archived zones (newest to oldest)
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

/// Visualization data: pulls messages plus archive state per chat and splits
/// them into five zones.
/// autoDispose drops the cache when the tab closes, so reopening re-queries and
/// always shows the current state.
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

  // Floor numbers align with the full message index (incl. hidden floors),
  // matching the chat page floor numbering.
  final floorOf = <String, int>{
    for (var i = 0; i < allMessages.length; i++) allMessages[i].id: i + 1,
  };

  // Zone rules: zone size = hotWindowSize turns (user adjustable; 1 turn =
  // user + AI ≈ 2 messages).
  // Newest to oldest: hot, warm, cold zones (original text + entries kept);
  // all archives older than the cold zone merge into a single entries-only
  // zone (no separate frozen tier — original text has fully aged out and only
  // entries are injected).
  final zoneSize = (settings.hotWindowSize * 2).clamp(2, 1 << 30);
  const zoneNames = ['热区', '温区', '冷区'];
  const zoneKeys = ['hot', 'warm', 'cold'];
  final zones = <ChronicleZone>[];

  // Hot/warm/cold: at most 3 zones from newest to oldest, zoneSize each
  for (var batchIndex = 0; batchIndex < 3; batchIndex++) {
    final end = archived.length - batchIndex * zoneSize;
    if (end <= 0) break;
    final start = (end - zoneSize).clamp(0, end);
    if (start >= end) break;
    final batch = archived.sublist(start, end);
    zones.add(ChronicleZone(
      key: zoneKeys[batchIndex],
      name: zoneNames[batchIndex],
      startIndex: floorOf[batch.first.id] ?? start + 1,
      endIndex: floorOf[batch.last.id] ?? end,
      messageCount: batch.length,
      hasOriginalText: true,
    ));
  }

  // Entries-only zone: all archives older than the cold zone (merged into one)
  final onlyEntriesEnd =
      (archived.length - 3 * zoneSize).clamp(0, archived.length);
  if (onlyEntriesEnd > 0) {
    final batch = archived.sublist(0, onlyEntriesEnd);
    zones.add(ChronicleZone(
      key: 'frozen',
      name: '只词条',
      startIndex: floorOf[batch.first.id] ?? 1,
      endIndex: floorOf[batch.last.id] ?? onlyEntriesEnd,
      messageCount: batch.length,
      hasOriginalText: false,
    ));
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
