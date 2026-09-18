import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/repositories/chronicle_repository.dart';
import 'package:kirakira/domain/services/chat_export_service.dart';
import 'package:kirakira/presentation/providers/vector_storage_providers.dart';

/// Provider for chat export service
final chatExportServiceProvider = Provider<ChatExportService>((ref) {
  // [CHRONICLE Phase 2] 注入Chronicle repo与向量服务，启用聊天文件内嵌
  return ChatExportService(
    chronicleRepo: ref.watch(chronicleRepositoryProvider),
    vectorStorage: ref.watch(vectorStorageServiceProvider),
  );
});
