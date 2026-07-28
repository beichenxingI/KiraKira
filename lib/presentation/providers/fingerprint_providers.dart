import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/fingerprint_result.dart';
import '../../domain/providers/llm_provider.dart';
import '../../domain/services/llm_service_adapter.dart';
import '../../domain/services/model_fingerprint_service.dart';
import 'settings_providers.dart';
import 'llm_configs_provider.dart';

/// 极客Probe 服务实例
/// 裁判模型配置id：从配置列表里选中的那个。null = 被测模型自评（可信度低）。
final judgeConfigIdProvider = StateProvider<String?>((ref) => null);
final judgeModelProvider = StateProvider<String?>((ref) => null);

/// 按存储配置 id 拉取该配置下可用的模型列表（供裁判二级选择）
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

/// 检测状态：管理 idle → running → done/error 的整个流程
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

  /// 开始检测。checkConsistency 为 true 时额外做掺假检测（费额度）。
  Future<void> start({
    DetectionLevel level = DetectionLevel.deep,
    bool checkConsistency = false,
  }) async {
    if (state.isRunning) return; // 防止重复触发

    state = const FingerprintState(isRunning: true);

    try {
      final service = _ref.read(fingerprintServiceProvider);
      final config = _ref.read(llmConfigProvider);
      final llmService = _ref.read(llmServiceProvider);

      // 被测模型
      final provider = LlmServiceAdapter(llmService, config);
      final credential = ApiCredential(
        baseUrl: config.apiUrl,
        apiKey: config.apiKey,
      );

      // 裁判模型（可选）：从配置列表里选中的那个当"尺子"
      LlmProvider? judgeProvider;
      ApiCredential? judgeCredential;
      final judgeId = _ref.read(judgeConfigIdProvider);
      if (judgeId != null) {
        final matches =
            _ref.read(llmConfigsProvider).configs.where((c) => c.id == judgeId);
        if (matches.isNotEmpty) {
          final judgeStored = matches.first;
          // 裁判专属模型优先，其次配置自带模型，最后回退被测模型
          final judgeModelOverride = _ref.read(judgeModelProvider);
          final resolvedJudgeModel = (judgeModelOverride != null &&
                  judgeModelOverride.isNotEmpty)
              ? judgeModelOverride
              : (judgeStored.model == null || judgeStored.model!.isEmpty)
                  ? config.model
                  : judgeStored.model!;
          // 以当前运行时配置为底，只覆盖裁判的连接信息（url/key/model）
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

  /// 清空结果，回到初始状态
  void reset() {
    state = const FingerprintState();
  }
}

final fingerprintProvider =
    StateNotifierProvider<FingerprintNotifier, FingerprintState>((ref) {
  return FingerprintNotifier(ref);
});