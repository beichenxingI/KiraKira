// P3-D Task 1: normalizeCodeQuotes 单元测试
// 被测对象是 webview_chat_stage.dart 文件尾的顶层函数 normalizeCodeQuotes
// (本轮唯一允许的重构:原 widget 私有方法 _normalizeCodeQuotes 提成顶层函数以便测试)。
import 'package:flutter_test/flutter_test.dart';
import 'package:kirakira/presentation/screens/chat/webview_chat_stage.dart';

void main() {
  group('normalizeCodeQuotes (P3-D: script/style 块内原样保留)', () {
    test('1. <script> 内字符串字面量里的弯引号原样不动', () {
      const input = '<script>var o = { desc: "“深蓝，让我看看你的极限！”只要…" };</script>';
      expect(normalizeCodeQuotes(input), input);
    });

    test('2. <script> 外的弯引号仍被替换为直引号', () {
      const input = '<p title="他说“你好”">‘正文’、…</p>';
      expect(
        normalizeCodeQuotes(input),
        '<p title="他说"你好"">\'正文\'、...</p>',
      );
    });

    test('3. <style> 内容原样不变(含弯引号与省略号)', () {
      const input = '<style>.a::after { content: "“辉光…”"; }</style>';
      expect(normalizeCodeQuotes(input), input);
    });

    test('4. 多个 script 块 + 块间文本混排: 块间替换、块内保留', () {
      const input = '前言“弯”…'
          '<script>var a = "“甲”";</script>'
          '块间“弯”…'
          '<script type="module">var b = "“乙”";</script>'
          '结尾“弯”…';
      const expected = '前言"弯"...'
          '<script>var a = "“甲”";</script>'
          '块间"弯"...'
          '<script type="module">var b = "“乙”";</script>'
          '结尾"弯"...';
      expect(normalizeCodeQuotes(input), expected);
    });

    test('5. <script> 未闭合: 非贪婪匹配不命中, 该段照旧归一化(与旧行为一致, 不构成回归)', () {
      const input = '<script>var a = "“深蓝”";';
      expect(
        normalizeCodeQuotes(input),
        '<script>var a = ""深蓝"";',
      );
    });

    test('6. … 展开只发生在块外: 块内 … 保留, 块外 … 变 ...', () {
      const input = '<script>var s = "未完…";</script>正文待续…';
      expect(
        normalizeCodeQuotes(input),
        '<script>var s = "未完…";</script>正文待续...',
      );
    });

    test('回归: 块内 HTML 字符串里的 <\\/script> 转义写法不被误吞', () {
      // 卡片惯例: JS 字符串里的 </script> 写作 <\/script>, 浏览器与本函数均不误截断
      const input = '<script>var t = "<\\/script>"; var q = "“引”";</script>';
      expect(normalizeCodeQuotes(input), input);
    });

    test('回归: 非 HTML 纯文本整体归一化(旧行为)', () {
      expect(normalizeCodeQuotes('“你好”, ‘世界’…'), '"你好", \'世界\'...');
    });
  });
}
