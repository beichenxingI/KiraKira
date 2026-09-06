/// [P6-3] 斜杠命令语法分析器:递归下降,语义对齐 ST SlashCommandParser。
///
/// 语法(与 ST 一致):
/// - `|` 是唯一命令分隔符(换行只是无名参数内的空白);`||` 抑制下一命令的 pipe 注入
/// - 命名参数 `key=value`,值可为 闭包`{:...:}` / 引号串 `"..."` / 列表`[...]` / 裸值
/// - 无名参数:非 split 命令吞到命令尾(管道/闭包尾/文本尾),split 命令按空白分值
/// - 注释 `//...` `/#...`(到 `|` 止)、块注释 `/*...*|`
/// - `/:name` 是 /run 的简写
/// - 宽松转义:`\|` `\"` 为字面符号
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

  /// 解析整段脚本为根闭包。宽容模式:未知结构跳过,未闭合闭包容忍到文本尾。
  SlashClosureNode parse() {
    return _parseClosure(isRoot: true);
  }

  bool _testClosureEnd({required bool isRoot}) {
    if (isRoot) return _s.endOfText;
    if (_s.endOfText) return true; // 容忍未闭合
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
      _s.take(); // 丢弃 "{:"
    }
    final textStart = _s.index;
    _s.discardWhitespace();

    // 闭包形参 `{: a, b :}`
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
        // 普通文本/无法识别的内容:丢弃到命令尾
        while (!_testCommandEnd(isRoot: isRoot) && !_s.endOfText) {
          _s.take();
        }
      }
      _s.discardWhitespace();
      // 首个 | 结束命令;第二个 | 抑制下一命令的 pipe 注入
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
      _s.take(); // 丢弃 ":}"
    }
    if (_s.testSymbol('()')) {
      _s.take();
      _s.take();
      closure.executeNow = true;
    }
    return closure;
  }

  // ── 注释 ──

  void _skipComment() {
    // `//` 或 `/#` 到 `|` 或文本尾
    while (!_s.endOfText && !_s.testSymbol('|')) {
      _s.take();
    }
  }

  void _skipBlockComment() {
    _s.take();
    _s.take(); // 丢弃 "/*"
    while (!_s.endOfText && !_s.testSymbol('*|')) {
      if (_s.testSymbol('/*')) {
        _skipBlockComment(); // 嵌套
        continue;
      }
      _s.take();
    }
    if (!_s.endOfText) {
      _s.take();
      _s.take(); // 丢弃 "*|"
    }
  }

  // ── 命令 ──

  bool _testRunShorthand() {
    return _s.testSymbol('/:') && !_s.testSymbol(':}', 1);
  }

  SlashExecutorNode _parseRunShorthand({required bool isRoot}) {
    final cmd = SlashExecutorNode(name: 'run', start: _s.index + 1);
    _s.take();
    _s.take(); // 丢弃 "/:"
    // /: 后到空白或命令尾是目标名(可带引号)
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
    _s.take(); // 丢弃 "/"
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
      // 查注册表拿命令的无名参数形态(split),对齐 ST parseCommand
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

  // ── 参数 ──

  bool _testNamedArgument() {
    if (_s.endOfText) return false;
    // 等价 ST 的 /^(\w+)=/ 前缀测试,但直接在原文上扫描,避免整段 ahead 子串
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
    _s.take(); // 丢弃 "="
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

  /// 引号串。容忍转义引号;未闭合则吞到命令尾(ST 宽松模式行为)。
  String _parseQuotedValue({required bool isRoot}) {
    _s.take(); // 丢弃开引号
    final buf = StringBuffer();
    while (true) {
      if (_s.endOfText) break;
      if (_s.testSymbol('"')) break;
      if (!isRoot && _s.testSymbol(':}')) break; // 闭包内容忍未闭合引号
      buf.write(_s.take());
    }
    if (!_s.endOfText) _s.take(); // 丢弃闭引号
    return buf.toString();
  }

  /// 列表值 `[...]`:取原文(含括号),不做项级解析。
  String _parseListValue({required bool isRoot}) {
    final buf = StringBuffer();
    buf.write(_s.take()); // 已测过的 "["
    while (!_s.endOfText && !_s.testSymbol(']')) {
      buf.write(_s.take());
    }
    if (!_s.endOfText) buf.write(_s.take()); // "]"
    return buf.toString();
  }

  /// 裸值:到空白或命令尾。
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

  /// 无名参数(对齐 ST parseUnnamedArgument):
  /// - 非 split:整段吞(引号开头则取整段引号串),内嵌闭包拆为多段
  /// - split:按空白逐值取(引号串/列表/裸值)
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
      // 首/尾字符串段去边缘空白,丢空段(对齐 ST 的 trimStart/trimEnd 行为)
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
        // 值数已达 splitCount:剩余整段为单一值
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

    // 超出 splitCount 的部分并回一个值(引号还原)
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
