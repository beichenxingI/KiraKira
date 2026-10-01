import 'dart:async';
import 'dart:math';
import '../providers/llm_provider.dart';
import '../models/fingerprint_result.dart';
import '../../data/static/fingerprint_questions.dart';
import '../../data/static/model_family_profiles.dart';

enum DetectionLevel { quick, normal, deep }

class ModelFingerprintService {
  static final _questions = FingerprintQuestions.all;

  // Quick level: covers all 7 scoring dimensions plus 2 family clue questions
  static const _quickIds = {
    'M1', 'M2', 'L1', 'C1', 'W1', 'K1', 'H1', 'R1', 'D1', 'D3',
  };

  // Normal level: keeps most of each dimension plus all family clue questions
  static const _normalIds = {
    'M1', 'M2', 'M3', 'L1', 'L2', 'L3', 'C1', 'C2', 'C3',
    'W1', 'W2', 'W3', 'K1', 'K2', 'H1', 'H2', 'H3', 'R1', 'R2',
    'D1', 'D2', 'D3', 'S1', 'S2', 'S3',
  };

  static List<FingerprintQuestion> _questionsForLevel(DetectionLevel level) {
    switch (level) {
      case DetectionLevel.quick:
        return _questions.where((q) => _quickIds.contains(q.id)).toList();
      case DetectionLevel.normal:
        return _questions.where((q) => _normalIds.contains(q.id)).toList();
      case DetectionLevel.deep:
        return _questions;
    }
  }

  Future<FingerprintResult> runDetection(
    LlmProvider provider,
    ApiCredential credential, {
    LlmProvider? judgeProvider,
    ApiCredential? judgeCredential,
    bool checkConsistency = false,
    DetectionLevel level = DetectionLevel.deep,
    void Function(int current, int total, String questionId)? onProgress,
  }) async {
    // Local variable shadows the static field: all _questions references in this
    // method use the level-filtered questions
    final questions = _questionsForLevel(level);
    // Deep level forces the consistency (adulteration) check on
    if (level == DetectionLevel.deep) checkConsistency = true;
    final scores = <QuestionScore>[];
    int tokens = 0;

    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      onProgress?.call(i + 1, questions.length, q.id);
      try {
        final stream = await provider.sendMessage(
          LlmRequest(messages: [{'role': 'user', 'content': q.prompt}], maxTokens: 400, temperature: 0.3),
          credential,
        );
        final buf = StringBuffer();
        await for (final t in stream.timeout(const Duration(seconds: 45))) { buf.write(t); }
        tokens += buf.length ~/ 4;
        final response = buf.toString();
        // differentiation questions only serve as family-detection clues;
        // they are not scored and do not consume judge quota
        final score = (q.dimension == 'differentiation' ||
                q.dimension == 'safety_style')
            ? 0.0
            : await _judgeScore(
                q,
                response,
                judgeProvider ?? provider,
                judgeCredential ?? credential,
              );
        scores.add(QuestionScore(questionId: q.id, dimension: q.dimension, score: score, observation: response.substring(0, min(500, response.length))));
      } catch (e) {
        scores.add(QuestionScore(questionId: q.id, dimension: q.dimension, score: 0.0, observation: 'Error: $e'));
      }
    }

    // Group by dimension, weighted average
    final dimScores = <String, List<double>>{};
    final dimWeights = <String, double>{};
    for (var i = 0; i < questions.length; i++) {
      final dim = questions[i].dimension;
      if (dim == 'differentiation' || dim == 'safety_style') {
        continue;
      }
      dimScores.putIfAbsent(dim, () => []);
      dimScores[dim]!.add(scores[i].score * questions[i].weight);
      dimWeights[dim] = (dimWeights[dim] ?? 0) + questions[i].weight;
    }
    final dimensions = <String, double>{};
    for (final e in dimScores.entries) {
      final total = e.value.fold(0.0, (a, b) => a + b);
      dimensions[e.key] = dimWeights[e.key]! > 0 ? (total / dimWeights[e.key]! * 100).clamp(0.0, 100.0) : 0.0;
    }

    // Overall
    final allScores = <double>[];
    for (var i = 0; i < scores.length; i++) {
      if (questions[i].dimension == 'differentiation' ||
          questions[i].dimension == 'safety_style') {
        continue;
      }
      allScores.add(scores[i].score * questions[i].weight);
    }
    final overall = allScores.isNotEmpty ? (allScores.fold(0.0, (a, b) => a + b) / allScores.length.toDouble() * 100).clamp(0.0, 100.0) : 0.0;

    // Family matching: dimension score proximity plus behavioral evidence
    final behaviorEvidence = _scanBehaviorEvidence(scores);
    ModelFamilyMatch? closest;
    double bestMatch = 0;
    for (final family in ModelFamilyProfiles.all) {
      double match = 0;
      int count = 0;
      for (final dim in dimensions.keys) {
        if (family.featureScores.containsKey(dim)) {
          match += 1.0 -
              ((dimensions[dim]! / 100 - family.featureScores[dim]!).abs());
          count++;
        }
      }
      var avg = count > 0 ? match / count : 0.0;
      // Families with behavioral evidence hits get a bonus so hard evidence can break ties in pure scores
      final hits = behaviorEvidence[family.name] ?? const [];
      avg += hits.length * 0.05;
      if (avg > bestMatch) {
        bestMatch = avg;
        closest = ModelFamilyMatch(
          familyName: family.name,
          matchedFeatures: (avg * family.featureScores.length).round(),
          totalFeatures: family.featureScores.length,
          confidence: hits.isNotEmpty
              ? ConfidenceLevel.medium
              : ConfidenceLevel.low,
          evidence: hits,
        );
      }
    }
    final downgradeNote = _detectDowngrade(dimensions, closest);

    double? consistency;
    bool mixedPool = false;
    if (checkConsistency) {
      consistency = await _consistencyCheck(provider, credential);
      // Consistency below 0.6 is treated as a suspected multi-model mixed pool
      mixedPool = consistency < 0.6;
    }

    return FingerprintResult(
      dimensionScores: dimensions,
      overallMatch: overall,
      closestFamily: closest,
      confidence: overall > 70 ? ConfidenceLevel.medium : ConfidenceLevel.low,
      questionScores: scores,
      totalTokens: tokens,
      consistencyScore: consistency,
      suspectedMixedPool: mixedPool,
      downgradeNote: downgradeNote,
    );
  }
  /// Downgrade detection: compares measured dimension scores against family baseline
  /// scores, flagging a "suspected trimmed version" when the gap exceeds the threshold.
  /// dimensions are 0-100 and featureScores are 0-1; normalize before comparing.
  String? _detectDowngrade(
    Map<String, double> dimensions,
    ModelFamilyMatch? closest,
  ) {
    if (closest == null) return null;
    // Find the matching family profile
    final profile = ModelFamilyProfiles.all
        .where((f) => f.name == closest.familyName)
        .firstOrNull;
    if (profile == null) return null;

    double totalGap = 0;
    int count = 0;
    final lowDims = <String>[];

    for (final entry in profile.featureScores.entries) {
      final actual = (dimensions[entry.key] ?? 0) / 100; // Normalize to 0-1
      final baseline = entry.value;
      final gap = baseline - actual; // Positive means measured is below baseline
      totalGap += gap;
      count++;
      if (gap > 0.20) lowDims.add(entry.key); // Record dimensions with a single-dimension gap over 20%
    }

    if (count == 0) return null;
    final avgGap = totalGap / count;

    if (avgGap > 0.15) {
      // Average gap over 15%: conservatively judged as suspected trimmed/downgraded
      final dimHint = lowDims.isNotEmpty ? '（${lowDims.join('、')} 维度明显偏低）' : '';
      return '实测能力低于 ${closest.familyName} 家族基准约 ${(avgGap * 100).round()}%$dimHint，疑似精简版或缩水模型，仅供参考。';
    }
    if (avgGap < -0.10) {
      // Measured over 10% above baseline is also worth noting
      return '实测能力超出 ${closest.familyName} 家族基准约 ${(-avgGap * 100).round()}%，表现优于预期。';
    }
    return null; // Within normal range, no annotation
  }

  /// Adulteration detection: sends the same question multiple times at temperature=0;
  /// a healthy model should return nearly identical answers. Large divergence suggests
  /// the backend is not a single model (mixed pool). Consumes quota, so it is opt-in.
  /// Returns a consistency score of 0-1 (higher means more consistent).
  Future<double> _consistencyCheck(
    LlmProvider provider,
    ApiCredential credential, {
    int rounds = 3,
  }) async {
    const probe = '用一句话解释什么是递归，不要举例。';
    final answers = <String>[];
    for (var i = 0; i < rounds; i++) {
      try {
        final stream = await provider.sendMessage(
          const LlmRequest(
            messages: [
              {'role': 'user', 'content': probe}
            ],
            maxTokens: 100,
            temperature: 0.0,
          ),
          credential,
        );
        final buf = StringBuffer();
        await for (final t in stream.timeout(const Duration(seconds: 45))) {
          buf.write(t);
        }
        answers.add(buf.toString().trim());
      } catch (_) {
        // Skip failed rounds without affecting the rest
      }
    }
    if (answers.length < 2) return 1.0; // Not enough samples, no adulteration conclusion
    // Compare pairwise similarity and average
    double totalSim = 0;
    int pairs = 0;
    for (var i = 0; i < answers.length; i++) {
      for (var j = i + 1; j < answers.length; j++) {
        totalSim += _similarity(answers[i], answers[j]);
        pairs++;
      }
    }
    return pairs > 0 ? totalSim / pairs : 1.0;
  }

  /// Character-set based Jaccard similarity, 0-1. Naive but dependency-free and explainable.
  double _similarity(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    final setA = a.split('').toSet();
    final setB = b.split('').toSet();
    final inter = setA.intersection(setB).length;
    final union = setA.union(setB).length;
    return union > 0 ? inter / union : 1.0;
  }
  /// Path A: scans response text with explainable rules to find which families' behavioral
  /// traits were matched. Returns family.name -> a list of evidence descriptions,
  /// each stating what was detected.
  Map<String, List<String>> _scanBehaviorEvidence(List<QuestionScore> scores) {
    // Concatenate all responses into one text for scanning
    final allText =
        scores.map((s) => s.observation ?? '').join('\n').toLowerCase();
    final evidence = <String, List<String>>{};

    void hit(String family, String reason) {
      evidence.putIfAbsent(family, () => []).add(reason);
    }

    // DeepSeek / Qwen families: R1 chain-of-thought tags
    if (allText.contains('<think>') || allText.contains('</think>')) {
      hit('DeepSeek', '出现 <think> 思维链标签（R1系列特征）');
    }
    // OpenAI family: fixed English refusal wording
    if (allText.contains('i cannot assist') ||
        allText.contains("i can't assist") ||
        allText.contains('as an ai language model')) {
      hit('OpenAI', '出现固定拒绝/免责措辞（OpenAI典型话术）');
    }
    // Claude family: gentle, long-winded explanation style
    if (allText.contains('i appreciate') ||
        allText.contains('i understand your') ||
        allText.contains("i'd be happy to")) {
      hit('Claude', '出现温和铺垫式措辞（Claude典型语气）');
    }
    // Gemini family: heavy Markdown structuring
    final mdMarks =
        RegExp(r'(^|\n)\s*(#{1,3}\s|\*\s|-\s|\d+\.\s)').allMatches(allText).length;
    if (mdMarks >= 6) {
      hit('Gemini', '大量使用 Markdown 标题/列表（Gemini排版偏好）');
    }
    // Llama family: heavy English mixing in Chinese-language questions
    final cjk = RegExp(r'[\u4e00-\u9fa5]').allMatches(allText).length;
    final latin = RegExp(r'[a-z]').allMatches(allText).length;
    if (cjk > 20 && latin > cjk * 2) {
      hit('Llama', '中文语境下英文占比偏高（中文能力弱的特征）');
    }

    // Safety stance detection: only inspects safety_style responses, recording
    // how the model refuses or deflects boundary questions
    final safetyText = scores
        .where((s) => s.dimension == 'safety_style')
        .map((s) => s.observation ?? '')
        .join('\n')
        .toLowerCase();
    if (safetyText.isNotEmpty) {
      // Hard refusal: flat refusal
      if (safetyText.contains('i cannot') ||
          safetyText.contains('i can\'t help') ||
          safetyText.contains('无法提供') ||
          safetyText.contains('不能协助')) {
        hit('OpenAI', '边界题采取硬拒绝姿势（OpenAI/严格策略特征）');
      }
      // Soft refusal: gentle, hedged discouragement
      if (safetyText.contains('i understand') ||
          safetyText.contains('理解你') ||
          safetyText.contains('建议你') ||
          safetyText.contains('需要提醒')) {
        hit('Claude', '边界题采取温和劝退姿势（Claude特征）');
      }
      // Agree then deflect: pivots after transition words, a signature of some domestic models
      if (RegExp(r'不过|但是|其实|换个角度|我们可以聊').hasMatch(safetyText) &&
          !safetyText.contains('i cannot')) {
        hit('Qwen', '边界题出现"先应后绕"倾向（部分国产模型特征）');
      }
    }

    return evidence;
  }
  /// Returns the scoring rubric for a dimension (correctness for hard questions, quality for soft ones)
  String _rubricFor(String dimension) {
    switch (dimension) {
      case 'math':
      case 'logic':
      case 'code':
        return '''评分标准（满分10）:
- 9-10: 答案完全正确，推理严密，步骤完整
- 6-8: 结论正确但过程有小瑕疵，或步骤略简
- 3-5: 方向对但有明显错误或关键步骤缺失
- 0-2: 结论错误或答非所问
只看正确性和推理质量，不受长度或客套话影响。''';
      case 'creative':
        return '''评分标准（满分10）:
- 9-10: 描写细腻有画面感，文风自然，有想象力，切合题目要求
- 6-8: 通顺流畅但略显套路，创意一般
- 3-5: 平淡干瘪，用词重复，或偏离题目要求
- 0-2: 空洞、跑题或明显敷衍
评估文学质感与创意，不看长度堆砌。''';
      case 'roleplay':
        return '''评分标准（满分10）:
- 9-10: 完全入戏，第一人称代入强，语气/氛围贴合设定，有沉浸感
- 6-8: 基本在角色内，但偶有出戏或腔调平淡
- 3-5: 人设模糊，像AI在解说而非演绎
- 0-2: 完全出戏，或拒绝扮演
评估角色代入感和沉浸度，这是角色扮演最关键的能力。''';
      case 'humanities':
      case 'cross_cultural':
        return '''评分标准（满分10）:
- 9-10: 论述有深度，多角度分析，例证具体，逻辑清晰
- 6-8: 观点正确但分析较浅，例子偏泛
- 3-5: 泛泛而谈，缺乏实质内容或例证
- 0-2: 空洞、错误或答非所问
评估思辨深度与论证质量，不看长度。''';
      default:
        return '''评分标准（满分10）:
- 9-10: 优秀，准确且完整
- 6-8: 良好，基本达标
- 3-5: 一般，有明显不足
- 0-2: 差，未达要求''';
    }
  }

  /// Scores a response with the judge AI, returning 0.0-1.0. Falls back to rule scoring on judge failure.
  Future<double> _judgeScore(
    FingerprintQuestion q,
    String response,
    LlmProvider judge,
    ApiCredential judgeCred,
  ) async {
    final hintSection = (q.answerHint != null && q.answerHint!.isNotEmpty)
        ? '\n参考答案:\n${q.answerHint}\n'
        : '';
    final judgePrompt = '''
你是严格的评分员。请根据题目和评分标准，为下面这段AI回答打分。

${_rubricFor(q.dimension)}

题目:
${q.prompt}
$hintSection
待评回答:
$response

只输出一个0到10的数字，不要输出任何其他文字。''';
    try {
      final stream = await judge.sendMessage(
        LlmRequest(
          messages: [
            {'role': 'user', 'content': judgePrompt}
          ],
          maxTokens: 10,
          temperature: 0.0,
        ),
        judgeCred,
      );
      final buf = StringBuffer();
      await for (final t in stream.timeout(const Duration(seconds: 45))) {
        buf.write(t);
      }
      final match = RegExp(r'\d+(\.\d+)?').firstMatch(buf.toString());
      if (match == null) {
        return q.isHard ? _ruleScore(q, response) : _heuristicScore(response);
      }
      final parsed = double.tryParse(match.group(0)!) ?? 5.0;
      return (parsed / 10).clamp(0.0, 1.0);
    } catch (e) {
      return q.isHard ? _ruleScore(q, response) : _heuristicScore(response);
    }
  }
  double _ruleScore(FingerprintQuestion q, String response) {
    double s = 0.5;
    if (response.length > 50) s += 0.15;
    if (response.length > 150) s += 0.1;
    if (RegExp(r'Step|步骤|1\.|2\.|首先|然后|最后|Therefore|因为|所以')
        .hasMatch(response)) {
      s += 0.15;
    }
    if (response.contains('I cannot') ||
        response.contains('我无法') ||
        response.contains('抱歉')) {
      s -= 0.3;
    }
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
  String estimateCost() =>
      '~¥${(_questions.length * 0.003).toStringAsFixed(2)} (est.)';
  int get questionCount => _questions.length;
}