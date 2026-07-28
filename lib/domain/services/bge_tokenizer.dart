import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// bge-small-zh-v1.5 专用 WordPiece 分词器（BERT 系）。
///
/// 与界面上那个"数 token 的分词器"完全无关——那个面向用户算预算，
/// 用的是对话模型的 BPE 规则；这个面向机器算向量，喂给本地 ONNX，
/// 用的是 bge 训练时的 WordPiece 规则和词表。两者井水不犯河水。
///
/// 从 assets 的 vocab.txt 加载词表，把中文文字切成 bge 认识的 token ID。
class BgeTokenizer {
  static const _vocabPath = 'assets/models/bge-small-zh/vocab.txt';

  // BERT 中文默认特殊 token
  static const _clsToken = '[CLS]';
  static const _sepToken = '[SEP]';
  static const _unkToken = '[UNK]';
  static const _padToken = '[PAD]';

  Map<String, int> _vocab = {};
  bool _loaded = false;

  int get clsId => _vocab[_clsToken] ?? 101;
  int get sepId => _vocab[_sepToken] ?? 102;
  int get unkId => _vocab[_unkToken] ?? 100;
  int get padId => _vocab[_padToken] ?? 0;

  /// 首次使用时加载词表（幂等）。
  Future<void> load() async {
    if (_loaded) return;
    final raw = await rootBundle.loadString(_vocabPath);
    final lines = const LineSplitter().convert(raw);
    _vocab = {};
    for (var i = 0; i < lines.length; i++) {
      _vocab[lines[i]] = i; // vocab.txt 行号即 token id
    }
    _loaded = true;
  }

  /// 把文字编码成 token id 序列（含 [CLS]/[SEP]，最长 maxLen）。
  List<int> encode(String text, {int maxLen = 512}) {
    final tokens = <int>[clsId];
    for (final word in _basicTokenize(text)) {
      tokens.addAll(_wordpiece(word));
      if (tokens.length >= maxLen - 1) break;
    }
    if (tokens.length > maxLen - 1) {
      tokens.removeRange(maxLen - 1, tokens.length);
    }
    tokens.add(sepId);
    return tokens;
  }

  /// 基础分词：中文按字拆，英文/数字按空格和标点拆，统一小写。
  List<String> _basicTokenize(String text) {
    final out = <String>[];
    final buf = StringBuffer();
    void flush() {
      if (buf.isNotEmpty) {
        out.add(buf.toString().toLowerCase());
        buf.clear();
      }
    }

    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      if (_isCjk(rune)) {
        flush();
        out.add(ch); // 中文单字成词
      } else if (_isWhitespace(ch)) {
        flush();
      } else if (_isPunctuation(ch)) {
        flush();
        out.add(ch); // 标点单独成词
      } else {
        buf.write(ch); // 英文/数字累积
      }
    }
    flush();
    return out;
  }

  /// WordPiece：贪心最长匹配子词，匹配不到用 [UNK]。
  List<int> _wordpiece(String word) {
    if (word.isEmpty) return [];
    // 中文单字或短词直接查
    final directId = _vocab[word];
    if (directId != null) return [directId];

    final ids = <int>[];
    var start = 0;
    final chars = word.split('');
    while (start < chars.length) {
      var end = chars.length;
      String? cur;
      while (start < end) {
        var sub = chars.sublist(start, end).join();
        if (start > 0) sub = '##$sub';
        if (_vocab.containsKey(sub)) {
          cur = sub;
          break;
        }
        end--;
      }
      if (cur == null) {
        return [unkId]; // 任一子词失配，整词标 UNK（BERT 标准行为）
      }
      ids.add(_vocab[cur]!);
      start = end;
    }
    return ids;
  }

  bool _isCjk(int cp) =>
      (cp >= 0x4E00 && cp <= 0x9FFF) ||
      (cp >= 0x3400 && cp <= 0x4DBF) ||
      (cp >= 0x20000 && cp <= 0x2A6DF) ||
      (cp >= 0xF900 && cp <= 0xFAFF);

  bool _isWhitespace(String ch) => ch.trim().isEmpty;

  bool _isPunctuation(String ch) {
    final cp = ch.codeUnitAt(0);
    return (cp >= 33 && cp <= 47) ||
        (cp >= 58 && cp <= 64) ||
        (cp >= 91 && cp <= 96) ||
        (cp >= 123 && cp <= 126) ||
        RegExp(r'[\u3000-\u303F\uFF00-\uFFEF]').hasMatch(ch);
  }
}