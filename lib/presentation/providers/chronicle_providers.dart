import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/repositories/chronicle_repository.dart';
import 'package:kirakira/domain/services/chronicle_orchestrator.dart';
import 'package:kirakira/domain/services/chat_summarization_service.dart';
import 'package:kirakira/presentation/providers/settings_providers.dart';
import 'package:kirakira/presentation/providers/vector_storage_providers.dart';

/// [CHRONICLE Phase 1] 超级记忆调度器接线。
/// 首次读取时启动队列Timer（一般由第一条消息发送触发）。
final chronicleOrchestratorProvider = Provider<ChronicleOrchestrator>((ref) {
  final orchestrator = ChronicleOrchestrator(
    repo: ref.watch(chronicleRepositoryProvider),
    summarizationService: ref.watch(chatSummarizationServiceProvider),
    embedder: ref.watch(embeddingServiceProvider),
    vectorStorage: ref.watch(vectorStorageServiceProvider),
    vectorSettingsGetter: () => ref.read(vectorStorageSettingsProvider),
    llmConfigGetter: () => ref.read(llmConfigProvider),
  );
  ref.onDispose(orchestrator.dispose);
  return orchestrator;
});
