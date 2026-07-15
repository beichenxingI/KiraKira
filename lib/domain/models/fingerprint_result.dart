/// Result of a model fingerprint detection run
class FingerprintResult {
  final Map<String, double> dimensionScores;
  final double overallMatch;
  final ModelFamilyMatch? closestFamily;
  final ConfidenceLevel confidence;
  final List<QuestionScore> questionScores;
  final int totalTokens;
  final String disclaimer;

  const FingerprintResult({
    required this.dimensionScores,
    required this.overallMatch,
    this.closestFamily,
    this.confidence = ConfidenceLevel.low,
    this.questionScores = const [],
    this.totalTokens = 0,
    this.disclaimer = '以上为行为统计推断，非加密验证，仅供参考。地球上目前不存在 100% 可靠的模型身份验证方法。',
  });
}

class ModelFamilyMatch {
  final String familyName;
  final int matchedFeatures;
  final int totalFeatures;
  final ConfidenceLevel confidence;
  final String? sizeEstimate;

  const ModelFamilyMatch({
    required this.familyName,
    required this.matchedFeatures,
    required this.totalFeatures,
    this.confidence = ConfidenceLevel.low,
    this.sizeEstimate,
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
