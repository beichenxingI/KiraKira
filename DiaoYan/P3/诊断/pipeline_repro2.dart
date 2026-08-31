// P3-G H1+H2: 离线复现整条显示管线(只读调研工具,非产品代码)
// 从项目根运行: dart run DiaoYan/P3/诊断/pipeline_repro2.dart
import 'dart:convert';
import 'dart:io';
import 'package:kirakira/data/models/regex_script.dart';
import 'package:kirakira/domain/services/regex_service.dart';
import 'package:markdown/markdown.dart' as md;

String normalizeCodeQuotes(String html) {
  String norm(String s) => s
      .replaceAll(RegExp('[''‚‛]'), "'")
      .replaceAll(RegExp('[""„‟＂]'), '"')
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
    '<style=${_count(s, '<style')} DOCTYPE=${_count(s, '<!DOCTYPE')} '
    'html=${_count(s, '<html')} fence3=${_count(s, '```html')} fenceAll=${_count(s, '```')}';

String headTail(String s, [int n = 120]) {
  if (s.length <= 2 * n) return jsonEncode(s);
  return 'HEAD=${jsonEncode(s.substring(0, n))} | TAIL=${jsonEncode(s.substring(s.length - n))}';
}

void dumpFile(String name, String content) {
  final f = File('DiaoYan/P3/诊断/out/$name');
  f.writeAsStringSync(content);
  print('    [dump] ${f.path} (${content.length} chars)');
}

Map<String, dynamic>? _loadCard(String path) {
  try {
    final raw = File(path).readAsStringSync();
    final c = jsonDecode(raw) as Map<String, dynamic>;
    final data = c['data'] as Map<String, dynamic>?;
    if (data == null) return null;
    final extensions = data['extensions'] as Map<String, dynamic>?;
    final rawScripts = extensions?['regex_scripts'];
    List<RegexScript> scripts = [];
    try {
      scripts = (rawScripts as List)
          .map((e) => RegexScript.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {}
    return {
      'name': data['name'] ?? '',
      'first_mes': data['first_mes'] ?? '',
      'scripts': scripts.where((s) => !s.disabled).toList()
        ..sort((a, b) => a.order.compareTo(b.order)),
    };
  } catch (e) {
    return null;
  }
}

void runPipeline(String label, String content, List<RegexScript> scripts,
    String charName, int depth, {String? extra}) {
  print('\n━━━ [$label] depth=$depth ━━━');
  if (extra != null) print('  [extra] $extra');
  print('  [in] ${markers(content)}');

  String rawContent = content.isEmpty
      ? ''
      : RegexService.instance.getRegexedString(
          content, RegexPlacement.aiOutput, scripts,
          characterName: charName, userName: null,
          isMarkdown: true, isPrompt: false, isEdit: false, depth: depth);
  print('  [afterRegex] ${markers(rawContent)}');

  final afterRegexPrePeel = rawContent.length;

  rawContent = rawContent
      .replaceAll(RegExp(r'<image>[\s\S]*?</image>', caseSensitive: false), '')
      .trim();

  final codeBlockMatch = RegExp(
    r'^```[a-zA-Z]*\n([\s\S]*?)```\s*$',
    multiLine: false,
  ).firstMatch(rawContent.trim());
  final codeBlockHit = codeBlockMatch != null;
  if (codeBlockMatch != null) {
    rawContent = codeBlockMatch.group(1) ?? rawContent;
  }
  final processed = rawContent;

  final htmlFenceMatches = RegExp(
    r'```html\s*\n([\s\S]*?)```',
    caseSensitive: false,
  ).allMatches(processed).toList();
  final fenceCount = htmlFenceMatches.length;
  final docCount = RegExp(r'<!DOCTYPE|<html', caseSensitive: false)
      .allMatches(processed)
      .length;

  print('  [codeBlockHit] $codeBlockHit (afterRegexPrePeel=$afterRegexPrePeel processed=${processed.length})');
  print('  [fenceCount(allMatches)] $fenceCount at ${htmlFenceMatches.map((m) => m.start).toList()}');
  print('  [docCount] $docCount at ${RegExp(r'<!DOCTYPE|<html', caseSensitive: false).allMatches(processed).map((m) => m.start).toList()}');

  final htmlFenceMatch = RegExp(r'```html\s*\n([\s\S]*?)```', caseSensitive: false).firstMatch(processed);
  String proseHtml = '';
  String bodyForRender = processed;
  int droppedRaw = 0;

  if (htmlFenceMatch != null) {
    final before = processed.substring(0, htmlFenceMatch.start).trim();
    print('  [fenceMatch] first fence: start=${htmlFenceMatch.start} end=${htmlFenceMatch.end}');
    print('  [before→prose] ${markers(before)}');
    if (before.isNotEmpty) {
      proseHtml = md.markdownToHtml(before, extensionSet: md.ExtensionSet.gitHubWeb);
    }
    bodyForRender = htmlFenceMatch.group(1) ?? '';
    // 尾段被静默丢弃的估算
    droppedRaw = processed.length - bodyForRender.length - htmlFenceMatch.start;
    final tail = processed.substring(htmlFenceMatch.end);
    print('  [tail=DROPPED] len=${tail.length} ${headTail(tail, 80)}');
  } else {
    print('  [fenceMatch] null → 走 docStart 切分');
    final docStart = RegExp(r'<!DOCTYPE|<html', caseSensitive: false).firstMatch(processed);
    print('  [docStart] ${docStart == null ? 'null' : '${docStart.start}(${docStart.group(0)})'}');
    if (docStart != null && docStart.start > 0) {
      final prose = processed.substring(0, docStart.start).trim();
      print('  [prose→markdown] ${markers(prose)}');
      if (prose.isNotEmpty) {
        proseHtml = md.markdownToHtml(prose, extensionSet: md.ExtensionSet.gitHubWeb);
      }
      bodyForRender = processed.substring(docStart.start);
    }
    droppedRaw = 0;
  }

  final looksLikeHtml = RegExp(
    r'<style|<script|<!DOCTYPE|<html|<head|<body',
    caseSensitive: false,
  ).hasMatch(bodyForRender);
  final rendered = looksLikeHtml
      ? normalizeCodeQuotes(bodyForRender)
      : md.markdownToHtml(bodyForRender, extensionSet: md.ExtensionSet.gitHubWeb);

  // segs 路径审计
  List<Map<String, dynamic>>? segs;
  if (fenceCount > 1) {
    segs = <Map<String, dynamic>>[];
    var cursor = 0;
    for (final match in htmlFenceMatches) {
      final gap = processed.substring(cursor, match.start);
      if (gap.trim().isNotEmpty) {
        segs.add({
          'type': 'prose',
          'html': md.markdownToHtml(gap, extensionSet: md.ExtensionSet.gitHubWeb),
        });
      }
      final body = match.group(1) ?? '';
      final rich = RegExp(r'<style|<script|<!DOCTYPE|<html|<head|<body', caseSensitive: false).hasMatch(body);
      segs.add({
        'type': rich ? 'frontend' : 'prose',
        'html': rich ? normalizeCodeQuotes(body) : md.markdownToHtml(body, extensionSet: md.ExtensionSet.gitHubWeb),
      });
      cursor = match.end;
    }
    final tail = processed.substring(cursor);
    if (tail.trim().isNotEmpty) {
      segs.add({'type': 'prose', 'html': md.markdownToHtml(tail, extensionSet: md.ExtensionSet.gitHubWeb)});
    }
  }

  final segSum = segs?.fold<int>(0, (sum, s) => sum + ((s['html'] as String?)?.length ?? 0)) ?? 0;
  final segDropped = segs != null ? processed.length - segSum : null;

  print('  [looksLikeHtml] $looksLikeHtml');
  print('  [bodyForRender] ${markers(bodyForRender)} (len=${bodyForRender.length})');
  print('  [rendered] ${markers(rendered)} (len=${rendered.length})');
  print('  [WV-1-ext] fenceCount=$fenceCount docCount=$docCount codeBlockHit=$codeBlockHit');
  print('  [WV-3] segs=${segs == null ? 'null' : '${segs.length}段'} ${segs != null ? segs.map((s) => '${s['type']}:${(s['html'] as String).length}').join(' ') : ''}');
  final warnDrop = (droppedRaw > 500 || (segDropped != null && segDropped > 500));
  print('  [WV-4] droppedRaw=$droppedRaw segDropped=$segDropped ${warnDrop ? '← WARN!' : ''}');
}

void main() {
  final outDir = Directory('DiaoYan/P3/诊断/out');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);

  // ── Card A ──────────────────────────────────────────────────────────────
  final cardA = _loadCard('DiaoYan/PiuPiuCard_《道渊》v5.2.json');
  if (cardA != null) {
    print('=== Card A: ${cardA['name']} ===');
    final fmA = cardA['first_mes'] as String;
    final scriptsA = cardA['scripts'] as List<RegexScript>;
    final nameA = cardA['name'] as String;

    // A1: 裸标记
    runPipeline('A1', '<StatusPlaceHolderImpl/>', scriptsA, nameA, 1);
    // A2: 重塑仙缘(消息开头即围栏,会触发 codeBlockMatch 剥壳 bug)
    runPipeline('A2', '仙路开启。<br>[重塑仙缘]', scriptsA, nameA, 1);
    // A3: 双标记同现
    runPipeline('A3', '旁白。\n<StatusPlaceHolderImpl/>\n[重塑仙缘]', scriptsA, nameA, 1);
    // A4: 触发 idx 0/2(裸 div 无围栏, looksLikeHtml 侥幸命中)
    runPipeline('A4_probe', '<updatevariable>\n<div style="color:red">test</div>\n</updatevariable>', scriptsA, nameA, 1);
  }

  // ── Card B ──────────────────────────────────────────────────────────────
  final cardBPath = Directory('DiaoYan').listSync().firstWhere(
    (e) => e is File && e.path.contains('Vulgar') && e.path.endsWith('.json'),
    orElse: () => throw StateError('Card B not found'),
  ) as File;
  final cardB = _loadCard(cardBPath.path);
  if (cardB != null) {
    print('\n=== Card B: ${cardB['name']} ===');
    final fmB = cardB['first_mes'] as String;
    final scriptsB = cardB['scripts'] as List<RegexScript>;
    final nameB = cardB['name'] as String;

    // B1: first_mes 原文
    runPipeline('B1', fmB, scriptsB, nameB, 0, extra: 'first_mes原文 67667');
    // B2: 小地图(裸 DOCTYPE 无围栏)
    runPipeline('B2', '查看小地图', scriptsB, nameB, 1);
    // B3: 职业总览(有围栏,无 DOCTYPE,裸 div)
    runPipeline('B3', '查看职业总览', scriptsB, nameB, 1);
    // B4: 大地图+状态栏同现
    runPipeline('B4', '查看大地图', scriptsB, nameB, 1);

    // B1 补充: <intro> 标签结构分析
    print('\n━━━ [B1-intro分析] ━━━');
    print('  <intro> pos=${fmB.indexOf('<intro>')} </intro> pos=${fmB.indexOf('</intro>')}');
    print('  intro_len=${fmB.indexOf('</intro>') - fmB.indexOf('<intro>') + 7}');
    print('  intro内含: fence2.body=${fmB.indexOf('```html', 21995) - 1223} chars之前分析了');
    print('  <intro> 包住了第二块围栏的 body(45661) + 第一块围栏body(20750)之前的一部分?');
    print('  第一块围栏body起点: 1223, 第二块围栏body起点: 21995+11=22006');
    print('  </intro> 在 67655, 所以 <intro> 从 22003 包到 67655, 跨度=${67655-22003}=45652');
    print('  第一块围栏(1223-21973) 不在 <intro> 内');
    print('  → <intro> 只包第二块围栏的 body+script');
    dumpFile('B1_firstmes_raw.txt', fmB);
  }

  print('\nDONE');
}
