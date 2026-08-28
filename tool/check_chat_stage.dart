// ─────────────────────────────────────────────────────────────────────────────
//  聊天壳 JS 语法检查链(P0 收尾)。
//
//  为什么存在:_htmlShell 的三引号字面量已在 commit 903b20c 迁入 asset,
//  原 tool/extract_shell.dart 的数据源(字面量)已不存在 → 检查链断了。
//  本脚本改读 assets/chat/chat_stage.html,把壳里所有 <script> 块抽出来,
//  逐个交给 node --check,并顺带把桥(assets/chat/chat_bridge.js)也验了。
//
//  只读 assets/,不写 assets/;临时产物写在 build/ 下。
//
//  用法(日常检查命令):
//    dart run tool/check_chat_stage.dart
//  全部 script 块语法合法 → 打印 "SYNTAX OK (N blocks)" 且 exit 0;
//  任一块失败 → 打印出错的块号与 node 原始报错,exit 1。
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:io';

const stagePath = 'assets/chat/chat_stage.html';
const bridgePath = 'assets/chat/chat_bridge.js';
const buildDir = 'build';

void main() {
  final html = File(stagePath).readAsStringSync(encoding: utf8);
  final bridge = File(bridgePath).readAsStringSync(encoding: utf8);

  // 占位符 __KIRA_CHAT_BRIDGE__ 单独一行,不是合法 JS。
  // 检查前按运行时 _htmlShell() 的同一规则,把它替换成桥的真实内容,
  // 这样整段主脚本 + 桥一起被 node --check 覆盖。
  final resolved = html.replaceAll('__KIRA_CHAT_BRIDGE__', bridge);

  final re = RegExp(r'<script>([\s\S]*?)</script>');
  final matches = re.allMatches(resolved).toList();
  if (matches.isEmpty) {
    stderr.writeln('FAIL: 在 $stagePath 里没找到任何 <script> 块');
    exit(1);
  }

  Directory(buildDir).createSync(recursive: true);

  final failures = <int>[];
  for (var i = 0; i < matches.length; i++) {
    final body = matches[i].group(1)!;
    final tmp = '$buildDir/check_block_${i + 1}.js';
    File(tmp).writeAsStringSync(body, encoding: utf8);
    final r = Process.runSync('node', ['--check', tmp]);
    stdout.writeln('── block ${i + 1}/${matches.length}  ($tmp, ${body.length} chars)');
    if (r.exitCode == 0) {
      stdout.writeln('   OK');
    } else {
      failures.add(i + 1);
      stdout.writeln('   FAIL (node exit ${r.exitCode})');
      stdout.writeln('   --- node stdout ---');
      stdout.writeln(r.stdout.toString().trim());
      stdout.writeln('   --- node stderr ---');
      stdout.writeln(r.stderr.toString().trim());
    }
  }

  if (failures.isEmpty) {
    stdout.writeln('SYNTAX OK (${matches.length} blocks)');
    exit(0);
  }
  stderr.writeln('SYNTAX ERROR in block(s): ${failures.join(', ')}');
  exit(1);
}