import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;
import 'package:onnxruntime/onnxruntime.dart';
import 'package:kirakira/domain/services/bge_tokenizer.dart';

/// 本地 bge-small-zh embedding 推理器（ONNX Runtime）。
///
/// ── 致未来的你 ──
/// 云端 embedding 的痛点（中转站定价虚高、重度用户被账单劝退）到此为止。
/// 这里文字→向量全程在设备上跑：零 token 费、离线、隐私不出设备。
/// 管线：分词(BgeTokenizer) → ONNX 推理 → CLS pooling → L2 归一化。
/// bge 官方用 CLS pooling（取首 token），不是 mean pooling，别改错。
/// ──
class LocalEmbedder {
  static const _modelPath = 'assets/models/bge-small-zh/model.onnx';

  final BgeTokenizer _tokenizer = BgeTokenizer();
  OrtSession? _session;
  bool _envInited = false;

  /// 懒加载：首次调用时初始化 ORT 环境、加载模型和词表。
  Future<void> _ensureReady() async {
    if (_session != null) return;
    if (!_envInited) {
      OrtEnv.instance.init();
      _envInited = true;
    }
    await _tokenizer.load();
    final raw = await rootBundle.load(_modelPath);
    final bytes = raw.buffer.asUint8List();
    final options = OrtSessionOptions();
    _session = OrtSession.fromBuffer(bytes, options);
  }

  /// 单段文字 → 归一化向量（384维）。
  Future<List<double>> embed(String text) async {
    await _ensureReady();

    final ids = _tokenizer.encode(text);
    final seqLen = ids.length;
    final mask = List<int>.filled(seqLen, 1);
    final typeIds = List<int>.filled(seqLen, 0);

    // shape [1, seqLen]，元素为 int → ORT 识别为 int64（bge 要求）
    final inputIds = OrtValueTensor.createTensorWithDataList(
        [ids], [1, seqLen]);
    final attentionMask = OrtValueTensor.createTensorWithDataList(
        [mask], [1, seqLen]);
    final tokenTypeIds = OrtValueTensor.createTensorWithDataList(
        [typeIds], [1, seqLen]);

    final inputs = {
      'input_ids': inputIds,
      'attention_mask': attentionMask,
      'token_type_ids': tokenTypeIds,
    };

    final runOptions = OrtRunOptions();
    List<OrtValue?>? outputs;
    try {
      outputs = _session!.run(runOptions, inputs);
      // last_hidden_state: [1, seqLen, 384]
      final raw = outputs.first?.value;
      final hidden = (raw as List).first as List; // [seqLen, 384]
      final cls = (hidden.first as List) // CLS = 首 token 向量
          .map((e) => (e as num).toDouble())
          .toList();
      return _l2Normalize(cls);
    } finally {
      inputIds.release();
      attentionMask.release();
      tokenTypeIds.release();
      runOptions.release();
      if (outputs != null) {
        for (final o in outputs) {
          o?.release();
        }
      }
    }
  }

  List<double> _l2Normalize(List<double> v) {
    var sum = 0.0;
    for (final x in v) {
      sum += x * x;
    }
    final norm = math.sqrt(sum);
    if (norm == 0) return v;
    return v.map((x) => x / norm).toList();
  }

  void dispose() {
    _session?.release();
    _session = null;
    if (_envInited) {
      OrtEnv.instance.release();
      _envInited = false;
    }
  }
}