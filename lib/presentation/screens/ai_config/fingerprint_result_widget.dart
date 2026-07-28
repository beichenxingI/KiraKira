import 'package:flutter/material.dart';
import '../../../domain/models/fingerprint_result.dart';

class FingerprintResultWidget extends StatelessWidget {
  final FingerprintResult? result;
  final bool isLoading;
  final int currentQuestion;
  final int totalQuestions;
  final VoidCallback? onClose;

  const FingerprintResultWidget({
    super.key,
    this.result,
    this.isLoading = false,
    this.currentQuestion = 0,
    this.totalQuestions = 0,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E1E2E),
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: isLoading ? _buildLoading() : result != null ? _buildResult(context) : _buildEmpty(),
      ),
    );
  }

  Widget _buildLoading() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const CircularProgressIndicator(),
      const SizedBox(height: 16),
      Text('检测中... $currentQuestion/$totalQuestions', style: const TextStyle(color: Colors.white70)),
      LinearProgressIndicator(value: totalQuestions > 0 ? currentQuestion / totalQuestions : 0),
    ]);
  }

  Widget _buildEmpty() {
    return const Center(child: Text('点击"深度检测"开始', style: TextStyle(color: Colors.white54)));
  }

  Widget _buildResult(BuildContext context) {
    final r = result!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        const Text('模型能力画像', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const Spacer(),
        if (onClose != null) IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: onClose),
      ]),
      const SizedBox(height: 12),
      _buildScoreBars(r.dimensionScores),
      const SizedBox(height: 16),
      Text('整体能力匹配度：${r.overallMatch.toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white, fontSize: 16)),
      if (r.closestFamily != null) ...[
        const SizedBox(height: 8),
        Text('行为特征最接近：${r.closestFamily!.familyName} 家族 (${r.closestFamily!.confidence.name}置信度)',
            style: const TextStyle(color: Color(0xFFa78bfa), fontSize: 14)),
      ],
      // 家族命中证据（为什么判成这个家族）
      if (r.closestFamily != null && r.closestFamily!.evidence.isNotEmpty) ...[
        const SizedBox(height: 10),
        const Text('判定依据：', style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 4),
        ...r.closestFamily!.evidence.map((e) => Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Text('· $e', style: const TextStyle(color: Colors.white60, fontSize: 12)),
            )),
      ],
      // 缩水判定
      if (r.downgradeNote != null) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF3a2a1a),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.trending_down, color: Color(0xFFf59e0b), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(r.downgradeNote!,
                  style: const TextStyle(color: Color(0xFFfbbf24), fontSize: 12)),
            ),
          ]),
        ),
      ],
      // 掺假检测结果（仅在做过一致性检测时显示）
      if (r.consistencyScore != null) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: r.suspectedMixedPool ? const Color(0xFF3a1a1a) : const Color(0xFF1a2a1a),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(r.suspectedMixedPool ? Icons.warning_amber : Icons.verified,
                color: r.suspectedMixedPool ? const Color(0xFFef4444) : const Color(0xFF22c55e),
                size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                r.suspectedMixedPool
                    ? '疑似多模型混池（掺假）：多次同问回答一致性仅 ${(r.consistencyScore! * 100).round()}%，背后可能不是同一个模型。'
                    : '一致性检测通过：多次同问回答一致性 ${(r.consistencyScore! * 100).round()}%，未发现明显掺假迹象。',
                style: TextStyle(
                    color: r.suspectedMixedPool ? const Color(0xFFfca5a5) : const Color(0xFF86efac),
                    fontSize: 12),
              ),
            ),
          ]),
        ),
      ],
      const SizedBox(height: 12),
      Text(r.disclaimer,
          style: const TextStyle(color: Colors.white38, fontSize: 11)),
    ]);
  }

  Widget _buildScoreBars(Map<String, double> scores) {
    final labels = {'math':'推理','logic':'逻辑','code':'代码','chinese':'中文','creative':'创意','cross_cultural':'跨文化','humanities':'人文','roleplay':'角色扮演','differentiation':'区分度'};
    return Wrap(spacing: 8, runSpacing: 8, children: scores.entries.map((e) {
      final label = labels[e.key] ?? e.key;
      final val = e.value;
      final color = val > 80 ? Colors.green : val > 50 ? Colors.orange : Colors.red;
      return SizedBox(width: 100, child: Column(children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Stack(children: [
          Container(height: 6, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(3))),
          FractionallySizedBox(widthFactor: val / 100, child: Container(height: 6, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)))),
        ]),
        Text('${val.round()}分', style: TextStyle(color: Colors.white, fontSize: 11)),
      ]));
    }).toList());
  }
}
