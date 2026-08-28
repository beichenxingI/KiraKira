// P0-5 commit-2 一次性手术脚本(不接入 app)。
// 对 webview_chat_stage.dart 做 3a/3b/3c,对 chat_bridge_js.dart 加一行注释(修正3)。
// 保留原文件 BOM 与换行风格(CRLF/LF),逐行精确手术,不做任何格式化/缩进改动。
import 'dart:convert';
import 'dart:io';

const stagePath = 'lib/presentation/screens/chat/webview_chat_stage.dart';
const bridgePath = 'lib/presentation/screens/chat/chat_bridge_js.dart';

const block3a = r'''
  // 聊天壳 asset:初始 HTML(带占位符)+ 桥 JS;读一次,失败走显性错误页
  static String? _chatStageHtml;
  static String? _chatBridgeJs;
  static bool _chatStageLoaded = false;

  /// 读取聊天壳资产(html + 桥 js)。成功后才置 _chatStageLoaded=true,
  /// 失败保持 false 以便下次重试,_htmlShell() 会走显性错误页而不是白屏。
  static Future<void> _loadChatStageAssets() async {
    if (_chatStageLoaded) return;
    try {
      _chatStageHtml = await rootBundle.loadString('assets/chat/chat_stage.html');
      _chatBridgeJs = await rootBundle.loadString('assets/chat/chat_bridge.js');
      _chatStageLoaded = true;
    } catch (e) {
      KiraLogger().error('聊天壳', '聊天壳资产读取失败: $e');
    }
  }''';

const block3b = r'''  String _chatStageErrorPage(String reason) {
    // 显性失败页:asset 缺失/读取异常让用户立刻看到"哪里坏了",而不是白屏。
    return '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>聊天壳加载失败</title></head>'
        '<body style="margin:24px;background:#14161C;color:#F5F7FA;'
        'font-family:-apple-system,BlinkMacSystemFont,sans-serif;">'
        '<div style="max-width:560px;margin:20vh auto 0;padding:24px;'
        'background:#231B1B;border:1px solid rgba(255,107,107,.4);'
        'border-radius:14px;">'
        '<div style="font-size:18px;font-weight:600;color:#FF9B9B;margin-bottom:8px;">聊天壳加载失败</div>'
        '<div style="font-size:14px;line-height:1.6;color:#E0E0E0;">'
        'assets/chat/ 下的聊天壳资源未就绪或读取失败。'
        '</div>'
        '<div style="font-size:13px;color:#B8BEC8;margin-top:10px;word-break:break-word;">'
        '$reason'
        '</div>'
        '<div style="font-size:12px;color:#8A8A8A;margin-top:14px;">'
        '请确认安装包完整;如问题持续,请联系开发。'
        '</div>'
        '</div></body></html>';
  }

  String _htmlShell() {
    final html = _chatStageHtml;
    final bridge = _chatBridgeJs;
    if (html == null || bridge == null) {
      return _chatStageErrorPage('缺少聊天壳资源(_chatStageHtml / _chatBridgeJs 为空)');
    }
    return html
        .replaceAll('__KIRA_QUOTE_Q_COLOR__', _colorToCss(ref.watch(quoteColorStateProvider).primaryA))
        .replaceAll('__KIRA_QUOTE_P_COLOR__', _colorToCss(ref.watch(quoteColorStateProvider).primaryB))
        .replaceAll('__KIRA_CHAT_BRIDGE__', bridge);
  }''';

const line3c = '      await _loadChatStageAssets();';

const bridgeComment = '// 运行时已改用 assets/chat/chat_bridge.js;此常量不再生效,修改此处无效。';

void main() {
  _surgeryStage();
  _surgeryBridge();
}

// 读取并返回 (body 文本, 是否带 BOM, 换行风格)
(String, bool, String) _read(String path) {
  final raw = File(path).readAsBytesSync();
  final hasBOM = raw.length >= 3 && raw[0] == 0xEF && raw[1] == 0xBB && raw[2] == 0xBF;
  final text = hasBOM ? utf8.decode(raw.sublist(3)) : utf8.decode(raw);
  final eol = text.contains('\r\n') ? '\r\n' : '\n';
  return (text, hasBOM, eol);
}

List<String> _toLines(String text) =>
    text.split('\n').map((l) => l.endsWith('\r') ? l.substring(0, l.length - 1) : l).toList();

void _write(String path, String text, bool hasBOM) {
  File(path).writeAsStringSync(hasBOM ? '\uFEFF$text' : text, encoding: Utf8Codec());
}

void _surgeryStage() {
  final (text, hasBOM, eol) = _read(stagePath);
  final origCount = _toLines(text).length;
  final lines = _toLines(text);

  // 3a: 在 "  static bool _ejsStubLoaded = false;" 之后插入
  final aIdx = lines.indexWhere((l) =>
      l.trim() == 'static bool _ejsStubLoaded = false;' && l.startsWith('  '));
  if (aIdx < 0) throw '3a anchor not found';
  lines.insertAll(aIdx + 1, block3a.split('\n'));

  // 3b: 替换 _htmlShell 函数(定位 "  String _htmlShell() {" 到匹配的 "''';" 后的 "  }")
  final sIdx = lines.indexWhere((l) => l.trim() == 'String _htmlShell() {');
  if (sIdx < 0) throw '3b start not found';
  var eIdx = -1;
  for (var i = sIdx + 1; i < lines.length; i++) {
    if (lines[i].trim() == "''';") {
      // 下一行应是 "  }"
      eIdx = i + 1;
      break;
    }
  }
  if (eIdx < 0 || lines[eIdx].trim() != '}') throw '3b end not found';
  lines.replaceRange(sIdx, eIdx + 1, block3b.split('\n'));

  // 3c: 在 "      await _loadCompatLibs();" 之前插入
  final cIdx = lines.indexWhere((l) => l == '      await _loadCompatLibs();');
  if (cIdx < 0) throw '3c anchor not found';
  lines.insert(cIdx, line3c);

  final out = lines.join(eol);
  final newCount = _toLines(out).length;
  _write(stagePath, out, hasBOM);
  stdout.writeln('[stage] lines: $origCount -> $newCount (eol=${eol == '\r\n' ? 'CRLF' : 'LF'}, BOM=$hasBOM)');
  // 确认 3 个占位符各出现 1 次(replaceAll 行)
  final hit = [
    '__KIRA_QUOTE_Q_COLOR__',
    '__KIRA_QUOTE_P_COLOR__',
    '__KIRA_CHAT_BRIDGE__',
  ].map((p) => p).toList();
  for (final p in hit) {
    final n = RegExp(RegExp.escape(p)).allMatches(out).length;
    stdout.writeln('[stage] placeholder "$p" occurrences=$n');
  }
}

void _surgeryBridge() {
  final (text, hasBOM, eol) = _read(bridgePath);
  final idx = text.indexOf('const String kChatBridgeJs = r');
  if (idx < 0) throw 'bridge anchor not found';
  // 找到该行行首,在其上方插一行注释
  final lineStart = text.lastIndexOf('\n', idx - 1) + 1;
  final out = text.substring(0, lineStart) + bridgeComment + '\n' + text.substring(lineStart);
  _write(bridgePath, out, hasBOM);
  stdout.writeln('[bridge] comment inserted, eol=${eol == '\r\n' ? 'CRLF' : 'LF'}, BOM=$hasBOM');
}