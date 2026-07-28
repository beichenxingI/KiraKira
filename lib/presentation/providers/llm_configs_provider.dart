import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/database/database.dart';
import 'package:kirakira/data/repositories/llm_config_repository.dart';
import 'package:kirakira/presentation/providers/settings_providers.dart';
import 'package:kirakira/core/services/initialization_service.dart';

final llmConfigRepositoryProvider = Provider<LlmConfigRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return LlmConfigRepository(db);
});

class LlmConfigsState {
  final List<LlmConfig> configs;
  final bool loading;

  const LlmConfigsState({this.configs = const [], this.loading = false});

  LlmConfig? get active {
    for (final c in configs) {
      if (c.isDefault) return c;
    }
    return null;
  }

  LlmConfigsState copyWith({List<LlmConfig>? configs, bool? loading}) {
    return LlmConfigsState(
      configs: configs ?? this.configs,
      loading: loading ?? this.loading,
    );
  }
}

class LlmConfigsNotifier extends StateNotifier<LlmConfigsState> {
  final LlmConfigRepository _repo;
  final Ref _ref;

  LlmConfigsNotifier(this._repo, this._ref)
      : super(const LlmConfigsState(loading: true)) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true);
    final configs = await _repo.getAll();
    state = LlmConfigsState(configs: configs, loading: false);
  }

  Future<void> upsert(LlmConfigsCompanion config) async {
    await _repo.upsert(config);
    await load();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    await load();
  }

  Future<void> setActive(String id) async {
    await _repo.setDefault(id);
    await load();
    await _ref.read(llmConfigProvider.notifier).applyActiveMultiConfig();
  }
}

final llmConfigsProvider =
    StateNotifierProvider<LlmConfigsNotifier, LlmConfigsState>((ref) {
  final repo = ref.watch(llmConfigRepositoryProvider);
  return LlmConfigsNotifier(repo, ref);
});
