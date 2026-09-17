import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/repositories/chronicle_repository.dart';
import 'package:kirakira/domain/services/chronicle_orchestrator.dart';
import 'package:kirakira/domain/services/chronicle_recall_service.dart';
import 'package:kirakira/domain/services/chronicle_summary_service.dart';
import 'package:kirakira/domain/services/chat_summarization_service.dart';
import 'package:kirakira/presentation/providers/settings_providers.dart';
import 'package:kirakira/presentation/providers/vector_storage_providers.dart';

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
  );
  ref.onDispose(orchestrator.dispose);
  return orchestrator;
});
