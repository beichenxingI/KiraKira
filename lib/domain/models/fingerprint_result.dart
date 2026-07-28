/// Result of a model fingerprint detection run
class FingerprintResult {
  final Map<String, double> dimensionScores;
  final double overallMatch;
  final ModelFamilyMatch? closestFamily;
  final ConfidenceLevel confidence;
  final List<QuestionScore> questionScores;
  final int totalTokens;
  final String disclaimer;
  final double? consistencyScore; // 掺假检测：多次同问的一致性 0~1，null=未检测
  final bool suspectedMixedPool; // 疑似多模型混池（掺假）
  final String? downgradeNote; // 缩水判定：实测明显低于家族基准时的说明，null=正常

  const FingerprintResult({
    required this.dimensionScores,
    required this.overallMatch,
    this.closestFamily,
    this.confidence = ConfidenceLevel.low,
    this.questionScores = const [],
    this.totalTokens = 0,
    this.disclaimer =
        '以上为行为统计推断，非加密验证，仅供参考。地球上目前不存在 100% 可靠的模型身份验证方法。',
    this.consistencyScore,
    this.suspectedMixedPool = false,
    this.downgradeNote,
  });
}

class ModelFamilyMatch {
  final String familyName;
  final int matchedFeatures;
  final int totalFeatures;
  final ConfidenceLevel confidence;
  final String? sizeEstimate;
  final List<String> evidence; // 判定依据(命中的行为特征),支撑保守措辞

  const ModelFamilyMatch({
    required this.familyName,
    required this.matchedFeatures,
    required this.totalFeatures,
    this.confidence = ConfidenceLevel.low,
    this.sizeEstimate,
    this.evidence = const [],
  });
}
class QuestionScore {
  final String questionId;
  final String dimension;
  final double score;
  final String? observation;
  final bool isStable;

  const QuestionScore({
    required this.questionId,
    required this.dimension,
    required this.score,
    this.observation,
    this.isStable = true,
  });
}

enum ConfidenceLevel { high, medium, low }
