import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/repositories/chronicle_repository.dart';
import 'package:kirakira/domain/services/chat_export_service.dart';
import 'package:kirakira/presentation/providers/vector_storage_providers.dart';

/// Provider for chat export service
final chatExportServiceProvider = Provider<ChatExportService>((ref) {
  // Injects the Chronicle repo and vector service, enabling file embedding in chat exports
  return ChatExportService(
    chronicleRepo: ref.watch(chronicleRepositoryProvider),
    vectorStorage: ref.watch(vectorStorageServiceProvider),
  );
});
