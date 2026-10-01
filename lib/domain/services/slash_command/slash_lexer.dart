/// Low-level scanner: character-level primitives, semantics match the
/// take/testSymbol methods of ST SlashCommandParser.
///
/// Lenient escaping (ST defaults to non-STRICT_ESCAPING): when a symbol is
/// directly preceded by a backslash, the backslash is skipped and the symbol
/// is treated as a literal (`\|` is a literal pipe, not a separator).
class SlashScanner {
  SlashScanner(this.text);

  final String text;
  int index = 0;

  /// Whether the last testSymbol skipped an escape backslash (first-character
  /// consumption follows ST semantics)
  bool jumpedEscapeSequence = false;

  String get char => index < text.length ? text[index] : '';
  bool get endOfText => index >= text.length;
  String get ahead => index + 1 < text.length ? text.substring(index + 1) : '';

  /// Advances and returns the consumed character
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

  /// Tests whether the next characters are the given symbol (with lenient
  /// backslash escaping).
  /// Matches ST testSymbolLooseyGoosey: if the symbol is directly preceded by
  /// a backslash, that backslash is consumed and false is returned (the next
  /// call then sees the bare symbol).
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

  /// Regex version of testSymbol (used for comment starts etc.), handles escapes the same way.
  bool testSymbolRegex(RegExp sequence, [int offset = 0]) {
    final escapeOffset = jumpedEscapeSequence ? -1 : 0;
    final base = index + offset + escapeOffset;
    if (base < 0 || base > text.length) return false;
    final m = sequence.matchAsPrefix(text, base);
    if (m != null) return true;
    // Backslash escape: the symbol follows the backslash
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

  /// Whether the current position is inside unclosed `{{...}}` macro braces
  /// (a `|` inside macro content is not a command separator, matching ST
  /// isInsideMacroBraces).
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
