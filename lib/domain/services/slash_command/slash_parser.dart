/// Slash command syntax parser: recursive descent, semantics match ST SlashCommandParser.
///
/// Grammar (same as ST):
/// - `|` is the only command separator (newlines are just whitespace inside
///   unnamed arguments); `||` suppresses pipe injection for the next command
/// - Named arguments `key=value`, where the value can be a closure `{:...:}`,
///   a quoted string `"..."`, a list `[...]`, or a bare value
/// - Unnamed arguments: non-split commands swallow up to the command end
///   (pipe / closure end / end of text); split commands split by whitespace
/// - Comments `//...` `/#...` (up to `|`), block comments `/*...*|`
/// - `/:name` is shorthand for /run
/// - Lenient escaping: `\|` and `\"` are literal symbols
library;

import 'slash_ast.dart';
import 'slash_command.dart';
import 'slash_lexer.dart';

class SlashParserException implements Exception {
  SlashParserException(this.message);
  final String message;

  @override
  String toString() => 'SlashParserException: $message';
}

class SlashParser {
  SlashParser(this.text);

  final String text;
  late final SlashScanner _s = SlashScanner(text);

  /// Parses the whole script into a root closure. Lenient mode: unrecognized
  /// constructs are skipped, unclosed closures run to end of text.
  SlashClosureNode parse() {
    return _parseClosure(isRoot: true);
  }

  bool _testClosureEnd({required bool isRoot}) {
    if (isRoot) return _s.endOfText;
    if (_s.endOfText) return true; // tolerate unclosed closure
    return _s.testSymbol(':}');
  }

  bool _testCommandEnd({required bool isRoot}) {
    if (_testClosureEnd(isRoot: isRoot)) return true;
    return _s.testSymbol('|') && !_s.insideMacroBraces;
  }

  SlashClosureNode _parseClosure({required bool isRoot}) {
    final closure = SlashClosureNode();
    if (!isRoot) {
      _s.take();
      _s.take(); // discard "{:"
    }
    final textStart = _s.index;
    _s.discardWhitespace();

    // Closure formal parameters `{: a, b :}`
    while (_testNamedArgument()) {
      closure.argumentList.add(_parseNamedArgument(isRoot: isRoot));
      _s.discardWhitespace();
    }

    var injectPipe = true;
    while (!_testClosureEnd(isRoot: isRoot)) {
      if (_s.testSymbol('/*')) {
        _skipBlockComment();
      } else if (_s.testSymbolRegex(RegExp(r'/[/#]'))) {
        _skipComment();
      } else if (_testRunShorthand()) {
        final cmd = _parseRunShorthand(isRoot: isRoot);
        cmd.injectPipe = injectPipe;
        closure.executorList.add(cmd);
        injectPipe = true;
      } else if (_s.testSymbol('/')) {
        final cmd = _parseCommand(isRoot: isRoot);
        cmd.injectPipe = injectPipe;
        closure.executorList.add(cmd);
        injectPipe = true;
      } else {
        // Plain text / unrecognized content: discard to command end
        while (!_testCommandEnd(isRoot: isRoot) && !_s.endOfText) {
          _s.take();
        }
      }
      _s.discardWhitespace();
      // First | ends the command; second | suppresses pipe injection for the next command
      if (_s.testSymbol('|')) {
        _s.take();
        if (_s.testSymbol('|')) {
          injectPipe = false;
          _s.take();
        }
      }
      _s.discardWhitespace();
    }
    closure.rawText = text.substring(
        textStart.clamp(0, text.length), _s.index.clamp(0, text.length));
    if (!isRoot && !_s.endOfText) {
      _s.take();
      _s.take(); // discard ":}"
    }
    if (_s.testSymbol('()')) {
      _s.take();
      _s.take();
      closure.executeNow = true;
    }
    return closure;
  }

  // Comments

  void _skipComment() {
    // `//` or `/#` runs to `|` or end of text
    while (!_s.endOfText && !_s.testSymbol('|')) {
      _s.take();
    }
  }

  void _skipBlockComment() {
    _s.take();
    _s.take(); // discard "/*"
    while (!_s.endOfText && !_s.testSymbol('*|')) {
      if (_s.testSymbol('/*')) {
        _skipBlockComment(); // nested
        continue;
      }
      _s.take();
    }
    if (!_s.endOfText) {
      _s.take();
      _s.take(); // discard "*|"
    }
  }

  // Commands

  bool _testRunShorthand() {
    return _s.testSymbol('/:') && !_s.testSymbol(':}', 1);
  }

  SlashExecutorNode _parseRunShorthand({required bool isRoot}) {
    final cmd = SlashExecutorNode(name: 'run', start: _s.index + 1);
    _s.take();
    _s.take(); // discard "/:"
    // After /:, characters up to whitespace or command end form the target name (may be quoted)
    if (_s.testSymbol('"')) {
      cmd.unnamedArgumentList
          .add(SlashArgAssignment(value: _parseQuotedValue(isRoot: isRoot), wasQuoted: true));
    } else {
      var name = '';
      while (!_s.endOfText &&
          !_isWhitespace(_s.char) &&
          !_testCommandEnd(isRoot: isRoot)) {
        name += _s.take();
      }
      if (name.isNotEmpty) {
        cmd.unnamedArgumentList.add(SlashArgAssignment(value: name));
      }
    }
    _s.discardWhitespace();
    while (_testNamedArgument()) {
      cmd.namedArgumentList.add(_parseNamedArgument(isRoot: isRoot));
      _s.discardWhitespace();
    }
    _s.discardWhitespace();
    cmd.end = _s.index;
    return cmd;
  }

  SlashExecutorNode _parseCommand({required bool isRoot}) {
    final cmd = SlashExecutorNode(name: '', start: _s.index + 1);
    _s.take(); // discard "/"
    var name = '';
    while (!_s.endOfText &&
        !_isWhitespace(_s.char) &&
        !_testCommandEnd(isRoot: isRoot)) {
      name += _s.take();
    }
    cmd.name = name;
    _s.discardWhitespace();
    while (_testNamedArgument()) {
      cmd.namedArgumentList.add(_parseNamedArgument(isRoot: isRoot));
      _s.discardWhitespace();
    }
    _s.discardWhitespace();
    if (!_testCommandEnd(isRoot: isRoot)) {
      // Look up the registry for the command's unnamed argument form (split), matching ST parseCommand
      final def = SlashCommandRegistry.get(name);
      cmd.unnamedArgumentList.addAll(_parseUnnamedArguments(
        isRoot: isRoot,
        split: def?.splitUnnamedArgument ?? false,
        splitCount: def?.splitUnnamedArgumentCount,
      ));
    }
    cmd.end = _s.index;
    return cmd;
  }

  // Arguments

  bool _testNamedArgument() {
    if (_s.endOfText) return false;
    // Equivalent to ST's /^(\w+)=/ prefix test, but scans the source directly to avoid a whole ahead substring
    if (!_isWordChar(text[_s.index])) return false;
    var j = _s.index + 1;
    while (j < text.length && _isWordChar(text[j])) {
      j++;
    }
    return j < text.length && text[j] == '=';
  }

  static bool _isWordChar(String c) =>
      (c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39) || // 0-9
      (c.codeUnitAt(0) >= 0x41 && c.codeUnitAt(0) <= 0x5A) || // A-Z
      (c.codeUnitAt(0) >= 0x61 && c.codeUnitAt(0) <= 0x7A) || // a-z
      c == '_';

  SlashArgAssignment _parseNamedArgument({required bool isRoot}) {
    var key = '';
    while (!_s.endOfText && _isWordChar(_s.char)) {
      key += _s.take();
    }
    _s.take(); // discard "="
    Object value = '';
    if (_s.testSymbol('{:')) {
      value = _parseClosure(isRoot: false);
    } else if (_s.testSymbol('"')) {
      value = _parseQuotedValue(isRoot: isRoot);
    } else if (_s.testSymbol('[')) {
      value = _parseListValue(isRoot: isRoot);
    } else if (!_testCommandEnd(isRoot: isRoot)) {
      value = _parseValue(isRoot: isRoot);
    }
    return SlashArgAssignment(name: key, value: value);
  }

  /// Quoted string. Tolerates escaped quotes; if unclosed, consumes to end of
  /// command (ST lenient mode behavior).
  String _parseQuotedValue({required bool isRoot}) {
    _s.take(); // discard opening quote
    final buf = StringBuffer();
    while (true) {
      if (_s.endOfText) break;
      if (_s.testSymbol('"')) break;
      if (!isRoot && _s.testSymbol(':}')) break; // tolerate unclosed quote inside closure
      buf.write(_s.take());
    }
    if (!_s.endOfText) _s.take(); // discard closing quote
    return buf.toString();
  }

  /// List value `[...]`: takes raw text (including brackets), no per-item parsing.
  String _parseListValue({required bool isRoot}) {
    final buf = StringBuffer();
    buf.write(_s.take()); // already-tested "["
    while (!_s.endOfText && !_s.testSymbol(']')) {
      buf.write(_s.take());
    }
    if (!_s.endOfText) buf.write(_s.take()); // "]"
    return buf.toString();
  }

  /// Bare value: up to whitespace or command end.
  String _parseValue({required bool isRoot}) {
    final buf = StringBuffer();
    if (_s.jumpedEscapeSequence) {
      buf.write(_s.take());
    }
    while (!_s.endOfText && !_isWhitespace(_s.char)) {
      if (_testCommandEnd(isRoot: isRoot)) break;
      buf.write(_s.take());
    }
    return buf.toString();
  }

  /// Unnamed arguments (matching ST parseUnnamedArgument):
  /// - non-split: swallow the whole segment (take a full quoted string if it
  ///   starts with a quote); embedded closures split it into multiple parts
  /// - split: take values one by one by whitespace (quoted string / list / bare value)
  List<SlashArgAssignment> _parseUnnamedArguments({
    required bool isRoot,
    bool split = false,
    int? splitCount,
  }) {
    final wasSplit = split;
    final parts = <SlashArgAssignment>[];

    if (!split && _s.testSymbol('"')) {
      parts.add(SlashArgAssignment(
          value: _parseQuotedValue(isRoot: isRoot), wasQuoted: true));
    }

    var buf = '';
    void flushFirstLastTrim() {
      // Trim edge whitespace of the first/last string parts and drop empty parts (matches ST trimStart/trimEnd behavior)
      if (parts.isNotEmpty && parts.first.value is String && !parts.first.wasQuoted) {
        final t = (parts.first.value as String).trimLeft();
        if (t.isEmpty) {
          parts.removeAt(0);
        } else {
          parts[0] = SlashArgAssignment(
              name: '', value: t, wasQuoted: parts.first.wasQuoted);
        }
      }
      if (parts.isNotEmpty && parts.last.value is String && !parts.last.wasQuoted) {
        final t = (parts.last.value as String).trimRight();
        if (t.isEmpty) {
          parts.removeLast();
        } else {
          parts[parts.length - 1] = SlashArgAssignment(
              name: '', value: t, wasQuoted: parts.last.wasQuoted);
        }
      }
    }

    while (!_testCommandEnd(isRoot: isRoot)) {
      if (split && splitCount != null && parts.length >= splitCount) {
        // Reached splitCount values: the rest is consumed as a single value
        split = false;
      }
      if (_s.testSymbol('{:')) {
        if (buf.isNotEmpty) {
          parts.add(SlashArgAssignment(value: buf));
          buf = '';
        }
        parts.add(SlashArgAssignment(value: _parseClosure(isRoot: false)));
        if (split) _s.discardWhitespace();
      } else if (split) {
        if (_s.testSymbol('"')) {
          parts.add(SlashArgAssignment(
              value: _parseQuotedValue(isRoot: isRoot), wasQuoted: true));
          _s.discardWhitespace();
        } else if (_s.testSymbol('[')) {
          parts.add(SlashArgAssignment(value: _parseListValue(isRoot: isRoot)));
          _s.discardWhitespace();
        } else if (!_testCommandEnd(isRoot: isRoot)) {
          parts.add(SlashArgAssignment(value: _parseValue(isRoot: isRoot)));
          _s.discardWhitespace();
        } else {
          break;
        }
      } else {
        buf += _s.take();
      }
    }
    if (buf.isNotEmpty || parts.isEmpty) {
      parts.add(SlashArgAssignment(value: buf));
    }
    flushFirstLastTrim();

    // Parts beyond splitCount are joined back into one value (quotes restored)
    if (wasSplit && splitCount != null && parts.length > splitCount + 1) {
      final joined = StringBuffer();
      for (var i = splitCount; i < parts.length; i++) {
        if (parts[i].wasQuoted) {
          joined.write('"${parts[i].value}"');
        } else {
          joined.write(parts[i].value);
        }
      }
      parts.removeRange(splitCount, parts.length);
      parts.add(SlashArgAssignment(value: joined.toString()));
    }
    return parts;
  }

  static bool _isWhitespace(String c) =>
      c == ' ' || c == '\t' || c == '\n' || c == '\r';
}
