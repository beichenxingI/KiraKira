import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;
import 'package:onnxruntime/onnxruntime.dart';
import 'package:kirakira/domain/services/bge_tokenizer.dart';

/// Local bge-small-zh embedding inference engine (ONNX Runtime).
///
/// Notes for future maintainers:
/// The cloud embedding pain points (inflated relay pricing, heavy users priced
/// out by the bill) end here. Text-to-vector runs entirely on-device: zero token
/// cost, offline, privacy since data never leaves the device.
/// Pipeline: tokenization (BgeTokenizer), then ONNX inference, then CLS pooling,
/// then L2 normalization. bge officially uses CLS pooling (first token), not mean
/// pooling; do not change this.
class LocalEmbedder {
  static const _modelPath = 'assets/models/bge-small-zh/model.onnx';

  final BgeTokenizer _tokenizer = BgeTokenizer();
  OrtSession? _session;
  bool _envInited = false;

  /// Lazy loading: initializes the ORT environment, loads the model and vocabulary on first call.
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

  /// Convert a single text to a normalized vector (384 dims).
  Future<List<double>> embed(String text) async {
    await _ensureReady();

    final ids = _tokenizer.encode(text);
    final seqLen = ids.length;
    final mask = List<int>.filled(seqLen, 1);
    final typeIds = List<int>.filled(seqLen, 0);

    // Shape [1, seqLen]; int elements are read by ORT as int64 (required by bge)
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
      final cls = (hidden.first as List) // CLS = first token vector
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