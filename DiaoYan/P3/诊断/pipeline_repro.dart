// P3-诊断 Task B: 离线复现整条显示管线(只读调研工具,非产品代码)
// 从项目根运行: dart run DiaoYan/P3/诊断/pipeline_repro.dart
//
// 关键: 正则处理直接调用项目真实 RegexService(lib/domain/services/regex_service.dart)
//       脚本解析直接调用项目真实 RegexScript.fromJson(lib/data/models/regex_script.dart)
//       —— 与 CharacterRegexScriptsNotifier._loadScripts 用同一个工厂。
// 仅 2845-2897 的切分/归一化逻辑为逐字复刻(函数是 widget 私有方法,无法离包调用),
// 复刻语句旁均标注源行号。
import 'dart:convert';
import 'dart:io';
import 'package:kirakira/data/models/regex_script.dart';
import 'package:kirakira/domain/services/regex_service.dart';
import 'package:markdown/markdown.dart' as md;

// ─── 逐字复刻 webview_chat_stage.dart 文件尾顶层函数 normalizeCodeQuotes ───
// P3-D Task 1 后已更新为"块外归一化、块内原样保留"版本,与生产实现逐字等价
// (源文件函数体逐字摘抄,字符类用字面字符书写,等价于源文件的同一字符集合)。
String normalizeCodeQuotes(String html) {
  String norm(String s) => s
      .replaceAll(RegExp('[‘’‚‛]'), "'")
      .replaceAll(RegExp('[“”„‟＂]'), '"')
      .replaceAll(RegExp('…+'), '...');
  final blocks = RegExp(
    r'<script[^>]*>[\s\S]*?</script>|<style[^>]*>[\s\S]*?</style>',
    caseSensitive: false,
  ).allMatches(html);
  final buf = StringBuffer();
  var last = 0;
  for (final m in blocks) {
    buf.write(norm(html.substring(last, m.start)));
    buf.write(html.substring(m.start, m.end));
    last = m.end;
  }
  buf.write(norm(html.substring(last)));
  return buf.toString();
}

int _count(String s, String needle) {
  var n = 0, i = 0;
  while (true) {
    i = s.indexOf(needle, i);
    if (i < 0) break;
    n++;
    i += needle.length;
  }
  return n;
}

String markers(String s) =>
    'len=${s.length} <script=${_count(s, '<script')} </script>=${_count(s, '</script>')} '
    '<style=${_count(s, '<style')} errorCatched=${_count(s, 'errorCatched')} '
    r'$=(' '${_count(s, r'$(')} ```html=${_count(s, '```html')} ```=${_count(s, '```')} '
    'StatusPH=${_count(s, 'StatusPlaceHolderImpl')} 重塑仙缘=${_count(s, '重塑仙缘')}';

String headTail(String s, [int n = 200]) {
  if (s.length <= 2 * n) return jsonEncode(s);
  return 'HEAD=${jsonEncode(s.substring(0, n))} | TAIL=${jsonEncode(s.substring(s.length - n))}';
}

void dumpFile(String name, String content) {
  final f = File('DiaoYan/P3/诊断/out/$name');
  f.writeAsStringSync(content);
  print('    [dump] ${f.path} (${content.length} chars)');
}

void main() {
  final outDir = Directory('DiaoYan/P3/诊断/out');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);

  final cardRaw = File('DiaoYan/PiuPiuCard_《道渊》v5.2.json').readAsStringSync();
  final card = jsonDecode(cardRaw);
  final data = card['data'] as Map<String, dynamic>;
  final charName = data['name'] as String? ?? '';
  final firstMes = data['first_mes'] as String? ?? '';
  final extensions = data['extensions'] as Map<String, dynamic>? ?? {};
  final rawScripts = extensions['regex_scripts'];

  print('=== STEP 0: 卡与正则脚本装载 ===');
  print('卡名: ${jsonEncode(charName)}');
  print('first_mes: ${markers(firstMes)}');
  print('regex_scripts 原始条数: ${rawScripts is List ? rawScripts.length : 'null'}');

  // —— 复刻 regex_providers.dart:193-197: RegexScript.fromJson 逐条硬转,任一 throw 全丢 ——
  List<RegexScript>? charScripts;
  try {
    charScripts = (rawScripts as List)
        .map((e) => RegexScript.fromJson(e as Map<String, dynamic>))
        .toList();
    print('fromJson 全部成功, ${charScripts.length} 条');
  } catch (e) {
    print('!!! fromJson 失败(=真机 [IMP-7] charRegex LOAD FAILED 分支): $e');
    charScripts = [];
  }

  // —— 复刻 regex_providers.dart:270-273: 过滤 disabled + sort by order ——
  final scripts = charScripts.where((s) => !s.disabled).toList()
    ..sort((a, b) => a.order.compareTo(b.order));

  print('\n=== 启用脚本(fromJson后) ===');
  for (final s in scripts) {
    print('  "${s.scriptName}" order=${s.order} placement=${s.placement.map((p) => p.name).toList()} '
        'markdownOnly=${s.markdownOnly} promptOnly=${s.promptOnly} minDepth=${s.minDepth} maxDepth=${s.maxDepth} '
        'replaceLen=${s.replaceString.length} findRegex=${jsonEncode(s.findRegex.length > 80 ? s.findRegex.substring(0, 80) + '…' : s.findRegex)}');
    final compiled = RegexService.instance.getRegex(s.findRegex);
    print('    getRegex 编译: ${compiled == null ? '!!! null(脚本将被静默跳过, regex_service.dart:97-99)' : 'OK'}');
  }

  // —— 逐条单跑定位每条脚本的实际行为(仍走真实 getRegexedString,脚本列表只放一条) ——
  print('\n=== 单脚本隔离测试(placement=aiOutput, isMarkdown=true, depth=1) ===');
  final probeInput = '旁白A。<StatusPlaceHolderImpl/>旁白B。';
  for (final s in scripts) {
    final before = probeInput;
    final after = RegexService.instance.getRegexedString(
      before, RegexPlacement.aiOutput, [s],
      characterName: charName, userName: null,
      isMarkdown: true, isPrompt: false, isEdit: false, depth: 1,
    );
    final delta = after.length - before.length;
    print('  "${s.scriptName}": ${before.length} -> ${after.length} (Δ$delta) '
        '${identical(before, after) || before == after ? '<<未变>>' : ''}');
    if (delta > 1000) {
      print('    结果头部: ${jsonEncode(after.substring(0, 120))}');
      print('    结果 ${markers(after)}');
    }
  }

  // ─── 管线复刻: 逐字复刻 webview_chat_stage.dart:2830-2897 ───
  void runPipeline(String label, String content, int depth) {
    print('\n━━━ 管线用例 $label (depth=$depth) ━━━');
    print('[in] ${markers(content)}');
    dumpFile('${label}_0_raw.txt', content);

    // L2830-2844: getRegexedString(真实调用)
    String rawContent = content.isEmpty
        ? ''
        : RegexService.instance.getRegexedString(
            content, RegexPlacement.aiOutput, scripts,
            characterName: charName, userName: null,
            isMarkdown: true, isPrompt: false, isEdit: false, depth: depth);
    print('[afterRegex] ${markers(rawContent)}');
    dumpFile('${label}_1_afterRegex.txt', rawContent);

    // L2846-2848: 剥离 <image>
    rawContent = rawContent
        .replaceAll(RegExp(r'<image>[\s\S]*?</image>', caseSensitive: false), '')
        .trim();
    print('[afterImageStrip] ${markers(rawContent)}');

    // L2849-2855: codeBlockMatch 整带围栏拆壳
    final codeBlockMatch = RegExp(
      r'^```[a-zA-Z]*\n([\s\S]*?)```\s*$',
      multiLine: false,
    ).firstMatch(rawContent.trim());
    print('[codeBlockMatch] ${codeBlockMatch != null ? '命中, start=${codeBlockMatch.start} end=${codeBlockMatch.end}, group(1).length=${codeBlockMatch.group(1)?.length}' : '未命中'}');
    if (codeBlockMatch != null) {
      rawContent = codeBlockMatch.group(1) ?? rawContent;
    }
    final processed = rawContent;
    print('[processed] ${markers(processed)}');
    dumpFile('${label}_2_processed.txt', processed);

    // L2860-2887: ```html 围栏切分 / <!DOCTYPE 切分
    final htmlFenceMatch = RegExp(
      r'```html\s*\n([\s\S]*?)```',
      caseSensitive: false,
    ).firstMatch(processed);
    String proseHtml = '';
    String bodyForRender = processed;
    if (htmlFenceMatch != null) {
      print('[htmlFenceMatch] 命中: start=${htmlFenceMatch.start} end=${htmlFenceMatch.end} / 全长=${processed.length}');
      final before = processed.substring(0, htmlFenceMatch.start).trim();
      print('  围栏前(before→prose): ${markers(before)}');
      if (before.isNotEmpty) {
        proseHtml = md.markdownToHtml(before, extensionSet: md.ExtensionSet.gitHubWeb);
      }
      bodyForRender = htmlFenceMatch.group(1) ?? '';
      final tail = processed.substring(htmlFenceMatch.end);
      print('  围栏后(tail,被静默丢弃): ${markers(tail)}');
      print('  tail 内容: ${headTail(tail, 300)}');
      dumpFile('${label}_3_tail_DROPPED.txt', tail);
    } else {
      print('[htmlFenceMatch] 未命中 → 走 <!DOCTYPE/<html 切分分支');
      final docStart = RegExp(r'<!DOCTYPE|<html', caseSensitive: false).firstMatch(processed);
      print('  docStart=${docStart == null ? 'null' : '${docStart.start} (${jsonEncode(docStart.group(0))})'}');
      if (docStart != null && docStart.start > 0) {
        final prose = processed.substring(0, docStart.start).trim();
        print('  prose(→markdown): ${markers(prose)}');
        if (prose.isNotEmpty) {
          proseHtml = md.markdownToHtml(prose, extensionSet: md.ExtensionSet.gitHubWeb);
        }
        bodyForRender = processed.substring(docStart.start);
      }
    }
    print('[bodyForRender→iframe] ${markers(bodyForRender)}');
    print('[proseHtml→markdown气泡] ${markers(proseHtml)}');
    dumpFile('${label}_4_bodyForRender.txt', bodyForRender);
    dumpFile('${label}_5_proseHtml.txt', proseHtml);

    // L2888-2897: looksLikeHtml 判定 + 归一化/渲染
    final looksLikeHtml = RegExp(
      r'<style|<script|<!DOCTYPE|<html|<head|<body',
      caseSensitive: false,
    ).hasMatch(bodyForRender);
    final rendered = looksLikeHtml
        ? normalizeCodeQuotes(bodyForRender)
        : md.markdownToHtml(bodyForRender, extensionSet: md.ExtensionSet.gitHubWeb);
    print('[looksLikeHtml] $looksLikeHtml');
    print('[rendered(最终进iframe/气泡_HTML)] ${markers(rendered)}');
    print('  rendered头尾: ${headTail(rendered, 150)}');
    dumpFile('${label}_6_rendered.txt', rendered);
  }

  // T1: 开场白原文(真实 first_mes)
  runPipeline('T1_greeting_firstmes', firstMes, 0);
  // T2: 裸标记(无旁白)
  runPipeline('T2_marker_only', '<StatusPlaceHolderImpl/>', 1);
  // T3: 旁白+标记(最像真机 AI 回复)
  runPipeline('T3_prose_plus_marker', '【道渊】\n\n你好，旅人。\n\n<StatusPlaceHolderImpl/>', 1);
  // T4: 旁白+标记+围栏后的旁白(假设A的直接检验)
  runPipeline('T4_marker_plus_tail', '旁白前。<StatusPlaceHolderImpl/>\n这段文字在围栏之后出现。', 1);
  // T5: 重塑仙缘标记(regex_7 开局界面 + "是"按钮)
  runPipeline('T5_chongsu', '仙路开启。<br>[重塑仙缘]', 1);
  // T9: 一条消息同时含两个标记(状态栏+开局界面) —— 检验"只取第一个围栏"对第二份的处置
  runPipeline('T9_both_markers', '旁白。\n<StatusPlaceHolderImpl/>\n[重塑仙缘]', 1);
  // T6: 深度扫描 —— depth 过滤是否可能跳过 regex_6
  print('\n=== T6: depth 扫描(first_mes, 只报 afterRegex 长度) ===');
  for (final d in [-1, 0, 1, 2, 5, 10, 100]) {
    final r = RegexService.instance.getRegexedString(
      firstMes, RegexPlacement.aiOutput, scripts,
      characterName: charName, userName: null,
      isMarkdown: true, isPrompt: false, isEdit: false, depth: d);
    print('  depth=$d -> ${r.length} ${r.length == firstMes.length ? '(=原文,无替换发生)' : '(有替换)'}');
  }

  // T7: userInput placement(用户消息路径)对照
  print('\n=== T7: placement=userInput 对照(first_mes) ===');
  final rUser = RegexService.instance.getRegexedString(
    firstMes, RegexPlacement.userInput, scripts,
    characterName: charName, userName: null,
    isMarkdown: true, isPrompt: false, isEdit: false, depth: 0);
  print('  userInput -> ${rUser.length} (原 ${firstMes.length})');

  // T8: markdown 渲染器对 <script> 的处理(旁白路径的安全性)
  print('\n=== T8: markdownToHtml 对 <script> 的处理(gitHubWeb) ===');
  final mdIn = '旁白文字。<script>alert(1)</script>继续文字。';
  final mdOut = md.markdownToHtml(mdIn, extensionSet: md.ExtensionSet.gitHubWeb);
  print('  in : ${jsonEncode(mdIn)}');
  print('  out: ${jsonEncode(mdOut)}');
  print('  out 含 <script: ${mdOut.contains('<script')}');

  print('\nDONE');
}
