import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// WordPiece tokenizer for bge-small-zh-v1.5 (BERT family).
///
/// Completely unrelated to the user-facing "token counter" tokenizer — that one
/// estimates budgets for users using chat-model BPE rules; this one computes
/// vectors for the machine, feeding local ONNX, using the WordPiece rules and
/// vocabulary from bge training. The two never mix.
///
/// Loads the vocabulary from assets vocab.txt and converts Chinese text into
/// token IDs that bge understands.
class BgeTokenizer {
  static const _vocabPath = 'assets/models/bge-small-zh/vocab.txt';

  // BERT Chinese default special tokens
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

  /// Load the vocabulary on first use (idempotent).
  Future<void> load() async {
    if (_loaded) return;
    final raw = await rootBundle.loadString(_vocabPath);
    final lines = const LineSplitter().convert(raw);
    _vocab = {};
    for (var i = 0; i < lines.length; i++) {
      _vocab[lines[i]] = i; // vocab.txt line number is the token id
    }
    _loaded = true;
  }

  /// Encode text into a token id sequence (includes [CLS]/[SEP], capped at maxLen).
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

  /// Basic tokenization: split Chinese by character, English/numbers by whitespace
  /// and punctuation, lowercase everything.
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
        out.add(ch); // Each Chinese character becomes a token
      } else if (_isWhitespace(ch)) {
        flush();
      } else if (_isPunctuation(ch)) {
        flush();
        out.add(ch); // Punctuation becomes its own token
      } else {
        buf.write(ch); // Accumulate English/digits
      }
    }
    flush();
    return out;
  }

  /// WordPiece: greedy longest-match subwords; fall back to [UNK] when nothing matches.
  List<int> _wordpiece(String word) {
    if (word.isEmpty) return [];
    // Single Chinese characters or short words are looked up directly
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
        return [unkId]; // Any subword mismatch marks the whole word UNK (standard BERT behavior)
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