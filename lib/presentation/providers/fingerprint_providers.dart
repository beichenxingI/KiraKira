import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/fingerprint_result.dart';
import '../../domain/providers/llm_provider.dart';
import '../../domain/services/llm_service_adapter.dart';
import '../../domain/services/model_fingerprint_service.dart';
import 'settings_providers.dart';
import 'llm_configs_provider.dart';

/// GeekProbe service instance
/// Judge model config id: the entry selected from the config list; null = self-evaluation by the tested model (low confidence).
final judgeConfigIdProvider = StateProvider<String?>((ref) => null);
final judgeModelProvider = StateProvider<String?>((ref) => null);

/// Lists the models available under the stored config id (for the judge model selector)
final judgeModelsProvider =
    FutureProvider.family<List<String>, String>((ref, configId) async {
  final baseConfig = ref.read(llmConfigProvider);
  final llmService = ref.read(llmServiceProvider);
  final matches =
      ref.read(llmConfigsProvider).configs.where((c) => c.id == configId);
  if (matches.isEmpty) return const [];
  final stored = matches.first;
  final probeConfig = baseConfig.copyWith(
    apiUrl: stored.endpoint,
    apiKey: stored.apiKey ?? '',
  );
  return llmService.getAvailableModels(probeConfig);
});

final fingerprintServiceProvider = Provider<ModelFingerprintService>((ref) {
  return ModelFingerprintService();
});

/// Detection state covering the idle, running, and done/error phases
class FingerprintState {
  final bool isRunning;
  final int current;
  final int total;
  final FingerprintResult? result;
  final String? error;

  const FingerprintState({
    this.isRunning = false,
    this.current = 0,
    this.total = 0,
    this.result,
    this.error,
  });

  FingerprintState copyWith({
    bool? isRunning,
    int? current,
    int? total,
    FingerprintResult? result,
    String? error,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return FingerprintState(
      isRunning: isRunning ?? this.isRunning,
      current: current ?? this.current,
      total: total ?? this.total,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class FingerprintNotifier extends StateNotifier<FingerprintState> {
  final Ref _ref;

  FingerprintNotifier(this._ref) : super(const FingerprintState());

  /// Starts detection. With checkConsistency = true, additionally runs the consistency check (costs extra quota).
  Future<void> start({
    DetectionLevel level = DetectionLevel.deep,
    bool checkConsistency = false,
  }) async {
    if (state.isRunning) return; // Guard against duplicate runs

    state = const FingerprintState(isRunning: true);

    try {
      final service = _ref.read(fingerprintServiceProvider);
      final config = _ref.read(llmConfigProvider);
      final llmService = _ref.read(llmServiceProvider);

      // Model under test
      final provider = LlmServiceAdapter(llmService, config);
      final credential = ApiCredential(
        baseUrl: config.apiUrl,
        apiKey: config.apiKey,
      );

      // Judge model (optional): the selected config acts as the reference baseline
      LlmProvider? judgeProvider;
      ApiCredential? judgeCredential;
      final judgeId = _ref.read(judgeConfigIdProvider);
      if (judgeId != null) {
        final matches =
            _ref.read(llmConfigsProvider).configs.where((c) => c.id == judgeId);
        if (matches.isNotEmpty) {
          final judgeStored = matches.first;
          // Priority: judge-specific model, then the config's own model, finally the model under test
          final judgeModelOverride = _ref.read(judgeModelProvider);
          final resolvedJudgeModel = (judgeModelOverride != null &&
                  judgeModelOverride.isNotEmpty)
              ? judgeModelOverride
              : (judgeStored.model == null || judgeStored.model!.isEmpty)
                  ? config.model
                  : judgeStored.model!;
          // Base on the current runtime config; override only the judge's connection details (URL/key/model)
          final judgeConfig = config.copyWith(
            apiUrl: judgeStored.endpoint,
            apiKey: judgeStored.apiKey ?? '',
            model: resolvedJudgeModel,
          );
          judgeProvider = LlmServiceAdapter(llmService, judgeConfig);
          judgeCredential = ApiCredential(
            baseUrl: judgeConfig.apiUrl,
            apiKey: judgeConfig.apiKey,
          );
        }
      }

      final result = await service.runDetection(
        provider,
        credential,
        judgeProvider: judgeProvider,
        judgeCredential: judgeCredential,
        level: level,
        checkConsistency: checkConsistency,
        onProgress: (current, total, questionId) {
          state = state.copyWith(current: current, total: total);
        },
      );

      state = state.copyWith(isRunning: false, result: result);
    } catch (e) {
      state = state.copyWith(isRunning: false, error: e.toString());
    }
  }

  /// Clears the result and returns to the initial state
  void reset() {
    state = const FingerprintState();
  }
}

final fingerprintProvider =
    StateNotifierProvider<FingerprintNotifier, FingerprintState>((ref) {
  return FingerprintNotifier(ref);
});