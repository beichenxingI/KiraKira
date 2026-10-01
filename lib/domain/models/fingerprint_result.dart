/// Result of a model fingerprint detection run
class FingerprintResult {
  final Map<String, double> dimensionScores;
  final double overallMatch;
  final ModelFamilyMatch? closestFamily;
  final ConfidenceLevel confidence;
  final List<QuestionScore> questionScores;
  final int totalTokens;
  final String disclaimer;
  final double? consistencyScore; // Adulteration detection: consistency across repeated identical questions, 0-1; null = not tested
  final bool suspectedMixedPool; // Suspected multi-model mixed pool (adulteration)
  final String? downgradeNote; // Downgrade detection: note when measured performance is clearly below the family baseline; null = normal

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
  final List<String> evidence; // Evidence for the verdict (matched behavior features), supporting conservative wording

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
