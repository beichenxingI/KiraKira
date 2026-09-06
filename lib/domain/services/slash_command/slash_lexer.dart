/// [P6-3] 底层扫描器:字符级原语,语义对齐 ST SlashCommandParser 的 take/testSymbol。
///
/// 宽松转义(ST 默认非 STRICT_ESCAPING):符号前直接跟一个反斜杠时,
/// 反斜杠被跳过、符号按字面处理(`\|` 是字面竖线,不是分隔符)。
class SlashScanner {
  SlashScanner(this.text);

  final String text;
  int index = 0;

  /// 上一次 testSymbol 是否跳过了转义反斜杠(消费首字符时按 ST 语义处理)
  bool jumpedEscapeSequence = false;

  String get char => index < text.length ? text[index] : '';
  bool get endOfText => index >= text.length;
  String get ahead => index + 1 < text.length ? text.substring(index + 1) : '';

  /// 前进并返回经过的字符
  String take() {
    jumpedEscapeSequence = false;
    if (index >= text.length) return '';
    final c = text[index];
    index++;
    return c;
  }

  void discardWhitespace() {
    while (index < text.length && _isWhitespace(text[index])) {
      index++;
      jumpedEscapeSequence = false;
    }
  }

  static bool _isWhitespace(String c) =>
      c == ' ' || c == '\t' || c == '\n' || c == '\r';

  /// 测试接下来是否为指定符号(支持反斜杠宽松转义)。
  /// 对齐 ST testSymbolLooseyGoosey:若符号前紧跟一个反斜杠,
  /// 消费该反斜杠并返回 false(下一次调用即可看到裸符号)。
  bool testSymbol(String sequence, [int offset = 0]) {
    final escapeOffset = jumpedEscapeSequence ? -1 : 0;
    final base = index + offset + escapeOffset;
    final escapes =
        (base < text.length && base >= 0 && text[base] == r'\') ? 1 : 0;
    final testPos = base + escapes;
    if (testPos < 0 || testPos > text.length) return false;
    final rest = text.substring(testPos);
    if (rest.startsWith(sequence)) {
      if (escapes == 0) return true;
      if (!jumpedEscapeSequence && offset == 0) {
        index++;
        jumpedEscapeSequence = true;
      }
      return false;
    }
    return false;
  }

  /// 正则版 testSymbol(用于注释起始等),同样处理转义。
  bool testSymbolRegex(RegExp sequence, [int offset = 0]) {
    final escapeOffset = jumpedEscapeSequence ? -1 : 0;
    final base = index + offset + escapeOffset;
    if (base < 0 || base > text.length) return false;
    final m = sequence.matchAsPrefix(text, base);
    if (m != null) return true;
    // 反斜杠转义:符号在 \' 之后
    final escapes = (base < text.length && text[base] == r'\') ? 1 : 0;
    final testPos = base + escapes;
    if (testPos > text.length) return false;
    if (sequence.matchAsPrefix(text, testPos) != null) {
      if (!jumpedEscapeSequence && offset == 0) {
        index++;
        jumpedEscapeSequence = true;
      }
      return false;
    }
    return false;
  }

  /// 当前位置是否在未闭合的 {{...}} 宏括号内
  /// (宏内容里的 | 不作为命令分隔符,对齐 ST isInsideMacroBraces)。
  bool get insideMacroBraces {
    var depth = 0;
    final behind = text.substring(0, index.clamp(0, text.length));
    var i = 0;
    while (i < behind.length) {
      if (behind[i] == '{' && i + 1 < behind.length && behind[i + 1] == '{') {
        depth++;
        i += 2;
      } else if (behind[i] == '}' &&
          i + 1 < behind.length &&
          behind[i + 1] == '}') {
        if (depth > 0) depth--;
        i += 2;
      } else {
        i++;
      }
    }
    return depth > 0;
  }
}
