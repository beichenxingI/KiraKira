// ─────────────────────────────────────────────────────────────────────────────
//  一次性提取脚本:读 webview_chat_stage.dart,把 _htmlShell() 的三引号字符串
//  还原成真实文本(处理 Dart 转义 + 替换动态插值),产出:
//    build/shell_extracted.html   ← 整页 HTML(插值已占位)
//    build/shell_extracted.js     ← 从 <script> 内抽出的纯 JS(供 node --check)
//
//  用途:仅用于 P0-2 验证「JS 语法能否在提交前被机器检查」。不接入 app,
//        不被任何业务代码引用,跑完即可删除/保留于 tool/ 下。
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:io';

// ── 常量 ─────────────────────────────────────────────────────────────────────
const dartFile = 'lib/presentation/screens/chat/webview_chat_stage.dart';
const bridgeFile = 'lib/presentation/screens/chat/chat_bridge_js.dart';
const outHtml = 'build/shell_extracted.html';
const outJs = 'build/shell_extracted.js';

// 动态插值的安全占位(颜色类,只落在 <style> 里,不影响 JS 语法检查)
const placeholderQuoteQ = '__DART_INTERP_QUOTE_Q_COLOR__';
const placeholderQuoteP = '__DART_INTERP_QUOTE_P_COLOR__';

void main(List<String> args) {
  // 默认走工作区文件;可选参数覆盖(供对备份分支做同样检查): <dartFile> <bridgeFile> <outHtml> <outJs>
  final src = args.isNotEmpty ? args[0] : dartFile;
  final brg = args.length > 1 ? args[1] : bridgeFile;
  final oHtml = args.length > 2 ? args[2] : outHtml;
  final oJs = args.length > 3 ? args[3] : outJs;

  final shellBody = _extractTripleQuoted(src, 'String _htmlShell() {');
  final bridgeBody = _extractTripleQuoted(brg, 'const String kChatBridgeJs = r\'\'\'');

  final html = _unDart(shellBody, bridgeBody);

  final js = _extractScripts(html);

  File(oHtml).parent.createSync(recursive: true);
  File(oHtml).writeAsStringSync(html, encoding: const Utf8Codec());
  File(oJs).writeAsStringSync(js, encoding: const Utf8Codec());

  stdout.writeln('[extract] html -> $oHtml (${File(oHtml).lengthSync()} bytes)');
  stdout.writeln('[extract] js   -> $oJs (${File(oJs).lengthSync()} bytes)');
  stdout.writeln('[extract] interpolations handled:');
  stdout.writeln('  $placeholderQuoteQ  (quoteColorStateProvider.primaryA)');
  stdout.writeln('  $placeholderQuoteP  (quoteColorStateProvider.primaryB)');
  stdout.writeln('  \$kChatBridgeJs -> inlined ${bridgeBody.length} chars from chat_bridge_js.dart');
}

/// 从指定文件里,锚定 `anchor` 行,取出其后第一个 `return '''`(或 `= r'''`)三引号
/// 字符串体,返回「去掉包裹引号、保留首尾换行」的原始内容(仍含 Dart 转义与插值)。
List<String> _readLines(String path) =>
    File(path).readAsLinesSync().map((l) => l.replaceAll('\r', '')).toList();

String _extractTripleQuoted(String path, String anchor) {
  final lines = _readLines(path);
  final anchorIdx = lines.indexWhere((l) => l.trim() == anchor.trim());
  if (anchorIdx < 0) throw 'anchor not found: $anchor in $path';

  // 找 anchor 之后第一个含三引号的行(return '''/ = r''')
  final openIdx = lines.indexWhere((l) => l.contains('\'\'\''), anchorIdx);
  if (openIdx < 0) throw 'no triple quote open after $anchor';

  // 之后第一个作为「整行只有 ''' + 可选分号」的闭合行
  var closeIdx = -1;
  for (var i = openIdx + 1; i < lines.length; i++) {
    if (lines[i].trim().replaceAll(';', '') == '\'\'\'') {
      closeIdx = i;
      break;
    }
  }
  if (closeIdx < 0) throw 'no triple quote close after $anchor';

  final body = lines.sublist(openIdx + 1, closeIdx);
  return '\n${body.join('\n')}\n';
}

/// 单遍扫描:还原 Dart 转义 + 替换动态插值。
/// 规则(已对 1-8 节选行做 hex/编译实证):
///   - `\$` -> `$`(字面美元)
///   - `\\` -> `\`(字面反斜杠)
///   - `\/`、`\{`、`\}`、`\'`、`\"` -> 各自字符本身(Dart 对非特殊转义按字面输出)
///   - `\n`/`\r`/`\t`/`\b`/`\f`/`\v` -> 对应控制字符(本项目 shell 内实测无)
///   - `${expr}` / `$ident` -> 动态插值,按已知表达式替换为安全占位
String _unDart(String raw, String bridgeBody) {
  final sb = StringBuffer();
  var i = 0;
  final n = raw.length;
  while (i < n) {
    final c = raw[i];
    if (c == r'\') {
      if (i + 1 >= n) {
        sb.write(c);
        i++;
        continue;
      }
      final nx = raw[i + 1];
      switch (nx) {
        case 'n':
          sb.write('\n');
          break;
        case 'r':
          sb.write('\r');
          break;
        case 't':
          sb.write('\t');
          break;
        case 'b':
          sb.write('\b');
          break;
        case 'f':
          sb.write('\f');
          break;
        case 'v':
          sb.write('\v');
          break;
        default:
          // \$ -> $ ; \\ -> \ ; \/ -> / ; \{ -> { …(Dart 字节级实证)
          sb.write(nx);
          break;
      }
      i += 2;
    } else if (c == r'$') {
      final rest = raw.substring(i);
      final idRe = RegExp(r'^\$([A-Za-z_][A-Za-z0-9_]*)');
      final mId = idRe.firstMatch(rest);
      if (mId != null) {
        final name = mId.group(1)!;
        if (name == 'kChatBridgeJs') {
          sb.write('\n/* ===== [Dart 插值 \$kChatBridgeJs] inlined from chat_bridge_js.dart ===== */\n');
          sb.write(bridgeBody);
          sb.write('\n/* ===== [/end \$kChatBridgeJs] ===== */\n');
        } else {
          sb.write('__DART_INTERP_\$name__');
        }
        i += mId.group(0)!.length;
        continue;
      }
      if (rest.startsWith(r'${')) {
        // 括号深度计数,读到配对 }
        var depth = 0;
        var closeAt = -1;
        for (var k = i; k < n; k++) {
          if (raw[k] == '{') {
            depth++;
          } else if (raw[k] == '}') {
            depth--;
            if (depth == 0) {
              closeAt = k;
              break;
            }
          }
        }
        final expr = raw.substring(i + 2, closeAt);
        if (expr.contains('primaryA')) {
          sb.write(placeholderQuoteQ);
        } else if (expr.contains('primaryB')) {
          sb.write(placeholderQuoteP);
        } else {
          sb.write('__DART_INTERP_UNKNOWN__');
        }
        i = closeAt + 1;
        continue;
      }
      // 零散 $,原样输出(本 shell 内不存在,防御性保留)
      sb.write(c);
      i++;
    } else {
      sb.write(c);
      i++;
    }
  }
  return sb.toString();
}

/// 从整页 HTML 抽出所有 <script>...</script> 内联块(无 src 的),拼接成一份 JS。
/// JS 字符串里的 <\/script> 带反斜杠,不会被 <\\/script> 错当作闭合标签匹配。
String _extractScripts(String html) {
  final re = RegExp(r'<script>([\s\S]*?)</script>');
  final parts = <String>[];
  var idx = 0;
  for (final m in re.allMatches(html)) {
    idx++;
    parts.add('/* ===== <script> block #$idx ===== */\n${m.group(1)}');
  }
  return parts.join('\n\n');
}