import 'dart:async';
import 'dart:math';
import '../providers/llm_provider.dart';
import '../models/fingerprint_result.dart';
import '../../data/static/fingerprint_questions.dart';
import '../../data/static/model_family_profiles.dart';

class ModelFingerprintService {
  static final _questions = FingerprintQuestions.all;

  Future<FingerprintResult> runDetection(
    LlmProvider provider,
    ApiCredential credential, {
    void Function(int current, int total, String questionId)? onProgress,
  }) async {
    final scores = <QuestionScore>[];
    int tokens = 0;

    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      onProgress?.call(i + 1, _questions.length, q.id);
      try {
        final stream = await provider.sendMessage(
          LlmRequest(messages: [{'role': 'user', 'content': q.prompt}], maxTokens: 400, temperature: 0.3),
          credential,
        );
        final buf = StringBuffer();
        await for (final t in stream) { buf.write(t); }
        tokens += buf.length ~/ 4;
        final response = buf.toString();
        final score = q.isHard ? _ruleScore(q, response) : _heuristicScore(response);
        scores.add(QuestionScore(questionId: q.id, dimension: q.dimension, score: score, observation: response.substring(0, min(80, response.length))));
      } catch (e) {
        scores.add(QuestionScore(questionId: q.id, dimension: q.dimension, score: 0.0, observation: 'Error: $e'));
      }
    }

    // Group by dimension, weighted average
    final dimScores = <String, List<double>>{};
    final dimWeights = <String, double>{};
    for (var i = 0; i < _questions.length; i++) {
      final dim = _questions[i].dimension;
      dimScores.putIfAbsent(dim, () => []);
      dimScores[dim]!.add(scores[i].score * _questions[i].weight);
      dimWeights[dim] = (dimWeights[dim] ?? 0) + _questions[i].weight;
    }
    final dimensions = <String, double>{};
    for (final e in dimScores.entries) {
      final total = e.value.fold(0.0, (a, b) => a + b);
      dimensions[e.key] = dimWeights[e.key]! > 0 ? (total / dimWeights[e.key]! * 100).clamp(0.0, 100.0) : 0.0;
    }

    // Overall
    final allScores = <double>[];
    for (var i = 0; i < scores.length; i++) { allScores.add(scores[i].score * _questions[i].weight); }
    final overall = allScores.isNotEmpty ? (allScores.fold(0.0, (a, b) => a + b) / (allScores.length as double) * 100).clamp(0.0, 100.0) : 0.0;

    // Family matching
    ModelFamilyMatch? closest;
    double bestMatch = 0;
    for (final family in ModelFamilyProfiles.all) {
      double match = 0;
      int count = 0;
      for (final dim in dimensions.keys) {
        if (family.featureScores.containsKey(dim)) {
          match += 1.0 - ((dimensions[dim]! / 100 - family.featureScores[dim]!).abs());
          count++;
        }
      }
      final avg = count > 0 ? match / count : 0;
      if (avg > bestMatch) { bestMatch = avg; closest = ModelFamilyMatch(familyName: family.name, matchedFeatures: (avg * family.featureScores.length).round(), totalFeatures: family.featureScores.length, confidence: avg > 0.8 ? ConfidenceLevel.medium : ConfidenceLevel.low); }
    }

    return FingerprintResult(dimensionScores: dimensions, overallMatch: overall, closestFamily: closest, confidence: overall > 70 ? ConfidenceLevel.medium : ConfidenceLevel.low, questionScores: scores, totalTokens: tokens);
  }

  double _ruleScore(FingerprintQuestion q, String response) {
    double s = 0.5;
    if (response.length > 50) s += 0.15;
    if (response.length > 150) s += 0.1;
    if (RegExp(r'Step|步骤|1\.|2\.|首先|然后|最后|Therefore|因为|所以').hasMatch(response)) s += 0.15;
    if (response.contains('I cannot') || response.contains('我无法') || response.contains('抱歉')) s -= 0.3;
    return s.clamp(0.0, 1.0);
  }

  double _heuristicScore(String response) {
    double s = 0.5;
    if (response.length > 80) s += 0.1;
    if (response.length > 200) s += 0.1;
    if (response.contains('I cannot') || response.contains('As an AI')) s -= 0.2;
    return s.clamp(0.0, 1.0);
  }

  int estimateTokens() => _questions.length * 200;
  String estimateCost() => '~¥${(_questions.length * 0.003).toStringAsFixed(2)} (est.)';
  int get questionCount => _questions.length;
}
