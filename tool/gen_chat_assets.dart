// ─────────────────────────────────────────────────────────────────────────────
//  P0-5 一次性资产生成脚本(不接入 app、不被业务引用)
//  1) 生成 assets/chat/chat_stage.html(占位符版,__KIRA_* 三处)
//  2) 生成 assets/chat/chat_bridge.js(kChatBridgeJs raw 原文)
//  3) 自证等价:
//     a) 源字串(占位符→哨兵色 + 桥原文) == 资产装配(chat_stage.html 按 3 个
//        占位符回填) —— 证明占位符/搬迁无损
//     b) 与 P0-2 产物 build/shell_extracted.html(独立代码路径)做标准化比较,
//        差异仅应为 3 处占位符替换行(2 个颜色名替换 + 桥块替换为占位符)
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:io';

void main() {
  const dartFile = 'lib/presentation/screens/chat/webview_chat_stage.dart';
  const bridgeFile = 'lib/presentation/screens/chat/chat_bridge_js.dart';
  const outStage = 'assets/chat/chat_stage.html';
  const outBridge = 'assets/chat/chat_bridge.js';
  const standardP02 = 'build/shell_extracted.html';

  final shellRaw = _extractTripleQuoted(dartFile, 'String _htmlShell() {');
  final bridgeBody = _extractTripleQuoted(bridgeFile, "const String kChatBridgeJs = r'''");

  // ── 占位符版:3 个洞留占位符 ──
  final stageHtml = _unDartPlaceholder(shellRaw);

  // ── 原壳运行时形态(哨兵色 + 桥原文):标准 A ──
  final originalResolved = _unDartResolved(shellRaw, bridgeBody);

  // ── 由资产装配出来的运行时形态:标准 B ──
  final assembledResolved = stageHtml
      .replaceAll('__KIRA_QUOTE_Q_COLOR__', '@SENTQ@')
      .replaceAll('__KIRA_QUOTE_P_COLOR__', '@SENTP@')
      .replaceAll('__KIRA_CHAT_BRIDGE__', bridgeBody);

  final selfPass = identical(originalResolved, assembledResolved) ||
      originalResolved == assembledResolved;

  stdout
      .writeln('[gen] stageHtml bytes=${stageHtml.length}  bridge bytes=${bridgeBody.length}');
  stdout.writeln('[gen] selfCheck(originalResolved == assembledResolved): '
      '${selfPass ? 'PASS' : 'FAIL(lenA=${originalResolved.length} lenB=${assembledResolved.length})'}');

  Directory('assets/chat').createSync(recursive: true);
  File(outStage).writeAsBytesSync(utf8.encode(stageHtml));
  File(outBridge).writeAsBytesSync(utf8.encode(bridgeBody));
  stdout.writeln('[gen] wrote $outStage (${File(outStage).lengthSync()} bytes, 无BOM/UTF-8/LF)');
  stdout.writeln('[gen] wrote $outBridge (${File(outBridge).lengthSync()} bytes, 无BOM/UTF-8/LF)');

  // ── 独立交叉核对:与 P0-2 产物 build/shell_extracted.html 标准化后必须逐字相等 ──
  if (!File(standardP02).existsSync()) {
    stdout.writeln('[gen] skip P0-2 artifact check (not found: $standardP02)');
    return;
  }
  final standard = File(standardP02).readAsStringSync(encoding: utf8);
  // 按行归一化 P0-2 产物 → 占位符形态,与资产逐字比对:
  //   颜色占位名 __DART_INTERP_* -> __KIRA_*;
  //   桥标记块(注释行+内联桥) -> 单行 __KIRA_CHAT_BRIDGE__
  final normLines = standard
      .split('\n')
      .map((l) => l
          .replaceAll('__DART_INTERP_QUOTE_Q_COLOR__', '__KIRA_QUOTE_Q_COLOR__')
          .replaceAll('__DART_INTERP_QUOTE_P_COLOR__', '__KIRA_QUOTE_P_COLOR__'))
      .toList();
  final mA = normLines.indexWhere((l) => l.contains('/* ===== [Dart'));
  final mB = normLines.indexWhere((l) => l.contains('/* ===== [/end'));
  if (mA < 0 || mB < 0 || mB <= mA) {
    stdout.writeln('[gen] crosscheck: marker not found, FAIL');
    return;
  }
  final scriptIdx = normLines.lastIndexWhere((l) => l.trim() == '<script>', mA);
  final varIdx = normLines.indexWhere((l) => l.trim() == 'var __allModels = [];', mB);
  if (scriptIdx < 0 || varIdx < 0) {
    stdout.writeln('[gen] crosscheck: boundary not found, FAIL');
    return;
  }
  final merged = <String>[
    ...normLines.sublist(0, scriptIdx + 1),
    '__KIRA_CHAT_BRIDGE__',
    ...normLines.sublist(varIdx),
  ].join('\n');
  final crossPass = merged == stageHtml;
  stdout.writeln('[gen] crossCheck(normalized shell_extracted.html == chat_stage.html): '
      '${crossPass ? 'PASS' : 'FAIL'}');
  if (!crossPass) {
    final a = merged.split('\n');
    final b = stageHtml.split('\n');
    final lim = a.length < b.length ? a.length : b.length;
    for (var x = 0; x < lim; x++) {
      if (a[x] != b[x]) {
        stdout.writeln('[gen] first differing line ${x + 1}:');
        stdout.writeln('[gen]   merged: ${a[x]}');
        stdout.writeln('[gen]   asset : ${b[x]}');
        break;
      }
    }
    stdout.writeln('[gen] lineCounts: merged=${a.length} asset=${b.length}');
  }
}

List<String> _readLines(String path) =>
    File(path).readAsLinesSync().map((l) => l.replaceAll('\r', '')).toList();

String _extractTripleQuoted(String path, String anchor) {
  final lines = _readLines(path);
  final anchorIdx = lines.indexWhere((l) => l.trim() == anchor.trim());
  if (anchorIdx < 0) throw 'anchor not found: $anchor in $path';
  final openIdx = lines.indexWhere((l) => l.contains("'''"), anchorIdx);
  if (openIdx < 0) throw 'no triple quote open after $anchor';
  var closeIdx = -1;
  for (var i = openIdx + 1; i < lines.length; i++) {
    if (lines[i].trim().replaceAll(';', '') == "'''") {
      closeIdx = i;
      break;
    }
  }
  if (closeIdx < 0) throw 'no triple quote close after $anchor';
  final body = lines.sublist(openIdx + 1, closeIdx);
  return '\n${body.join('\n')}\n';
}

/// 还原 Dart 转义 + 3 个插值 → __KIRA_* 占位符
String _unDartPlaceholder(String raw) => _scan(raw, (name) {
      if (name == 'kChatBridgeJs') return '__KIRA_CHAT_BRIDGE__';
      return '__KIRA_INTERP_${name}__';
    }, (expr) {
      if (expr.contains('primaryA')) return '__KIRA_QUOTE_Q_COLOR__';
      if (expr.contains('primaryB')) return '__KIRA_QUOTE_P_COLOR__';
      return '__KIRA_INTERP_EXPR_${expr.length}__';
    });

/// 还原 Dart 转义 + 桥插值内联原文 + 颜色 → 哨兵(等价于原 _htmlShell 的返回值)
String _unDartResolved(String raw, String bridgeBody) => _scan(raw, (name) {
      if (name == 'kChatBridgeJs') return bridgeBody;
      return name;
    }, (expr) {
      if (expr.contains('primaryA')) return '@SENTQ@';
      if (expr.contains('primaryB')) return '@SENTP@';
      return expr;
    });

String _scan(String raw, String Function(String) onIdent, String Function(String) onExpr) {
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
          sb.write(nx);
          break;
      }
      i += 2;
    } else if (c == r'$') {
      final rest = raw.substring(i);
      final idRe = RegExp(r'^\$([A-Za-z_][A-Za-z0-9_]*)');
      final mId = idRe.firstMatch(rest);
      if (mId != null) {
        sb.write(onIdent(mId.group(1)!));
        i += mId.group(0)!.length;
        continue;
      }
      if (rest.startsWith(r'${')) {
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
        sb.write(onExpr(expr));
        i = closeAt + 1;
        continue;
      }
      sb.write(c);
      i++;
    } else {
      sb.write(c);
      i++;
    }
  }
  return sb.toString();
}
