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
      const SizedBox(height: 12),
      const Text('以上为行为统计推断，非加密验证，仅供参考。地球上目前不存在 100% 可靠的模型身份验证方法。',
          style: TextStyle(color: Colors.white38, fontSize: 11)),
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
