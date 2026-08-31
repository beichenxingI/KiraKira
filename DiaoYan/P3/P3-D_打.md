# P3-D 三刀修复交付记录

## 1. 基线

开工前执行：

```text
git status --short
git log --oneline -3
```

基线 HEAD：`e30f308 fix(wv): P3-C2b yaml资产读取独立try...`。

工作区原有改动为 Flutter 生成的插件注册文件，已恢复；`DiaoYan/` 下既有调研资料为未跟踪文件，未纳入本轮 Task commit。

## 2. Task 1：保护 script/style 块内代码

文件：`lib/presentation/screens/chat/webview_chat_stage.dart:3173-3176`，调用点：`webview_chat_stage.dart:2893`。

改前原文：

```dart
String _normalizeCodeQuotes(String html) => html
    .replaceAll(RegExp('[‘’‚‛]'), "'")
    .replaceAll(RegExp('[“”„‟＂]'), '"')
    .replaceAll(RegExp('…+'), '...');
```

改后调用：

```dart
? normalizeCodeQuotes(bodyForRender)
```

改后完整实现：

```dart
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
```

原因：块外保持原有三次替换；完整保留 script/style 标签及内容，避免 JS 字符串内部中文弯引号被改成破坏语法的直引号。

可见性重构：已执行允许的唯一重构，将 widget 私有方法提为同文件顶层 `normalizeCodeQuotes`；调用点同步为 `webview_chat_stage.dart:2893`。影响面仅该调用点和函数位置。

单元测试：`test/normalize_code_quotes_test.dart`，覆盖 script 内字符串、script 外文本、style、多块混排、未闭合 script、ellipsis 块内外、`<\\/script>` 转义和纯文本回归，共 8 项。测试代码为：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kirakira/presentation/screens/chat/webview_chat_stage.dart';

void main() {
  group('normalizeCodeQuotes (P3-D: script/style 块内原样保留)', () {
    test('script 内字符串弯引号原样不动', () {
      const input = '<script>var o = { desc: "“深蓝，让我看看你的极限！”只要…" };</script>';
      expect(normalizeCodeQuotes(input), input);
    });
    test('script 外弯引号替换', () {
      const input = '<p title="他说“你好”">‘正文’、…</p>';
      expect(normalizeCodeQuotes(input), '<p title="他说"你好"">\'正文\'、...</p>');
    });
    test('style 内容原样不变', () {
      const input = '<style>.a::after { content: "“辉光…”"; }</style>';
      expect(normalizeCodeQuotes(input), input);
    });
    test('多个 script 块与块间文本混排', () {
      const input = '前言“弯”…<script>var a = "“甲”";</script>块间“弯”…<script type="module">var b = "“乙”";</script>结尾“弯”…';
      const expected = '前言"弯"...<script>var a = "“甲”";</script>块间"弯"...<script type="module">var b = "“乙”";</script>结尾"弯"...';
      expect(normalizeCodeQuotes(input), expected);
    });
    test('未闭合 script 与旧行为一致', () {
      expect(normalizeCodeQuotes('<script>var a = "“深蓝”";'), '<script>var a = ""深蓝"";');
    });
    test('ellipsis 只在块外展开', () {
      expect(normalizeCodeQuotes('<script>var s = "未完…";</script>正文待续…'), '<script>var s = "未完…";</script>正文待续...');
    });
    test('转义 script 结束标签不误截断', () {
      const input = '<script>var t = "<\\/script>"; var q = "“引”";</script>';
      expect(normalizeCodeQuotes(input), input);
    });
    test('纯文本回归', () {
      expect(normalizeCodeQuotes('“你好”, ‘世界’…'), '"你好", \'世界\'...');
    });
  });
}
```

测试原始输出：

```text
00:00 +0: loading test/normalize_code_quotes_test.dart
00:00 +1: normalizeCodeQuotes ... script 内字符串字面量里的弯引号原样不动
00:00 +2: normalizeCodeQuotes ... script 外的弯引号仍被替换为直引号
00:00 +3: normalizeCodeQuotes ... style 内容原样不变(含弯引号与省略号)
00:00 +4: normalizeCodeQuotes ... 多个 script 块 + 块间文本混排: 块间替换、块内保留
00:00 +5: normalizeCodeQuotes ... script 未闭合: ...
00:00 +6: normalizeCodeQuotes ... … 展开只发生在块外: ...
00:00 +7: normalizeCodeQuotes ... 块内 HTML 字符串里的 <\/script> 转义写法不被误吞
00:00 +8: normalizeCodeQuotes ... 非 HTML 纯文本整体归一化(旧行为)
00:00 +8: All tests passed!
```

边界：未闭合 `<script>` 不匹配块正则，整段按旧逻辑归一化；畸形嵌套或 JS 字符串中的真实 `</script>` 按 HTML 解析器同样的首个结束标签规则处理，卡片正常惯例使用 `<\\/script>`。多个块按正则从左至右切分。

离线复现：`regex_7` 脚本体由 `PARSE FAIL: Unexpected identifier '深蓝'` 变为 `PARSE OK`；T5 rendered 脚本体长度 `158341`，Node VM `PARSE OK`。卡源静态含弯引号行仍为 141，这是原卡内容计数；改后这些行位于 script 块内，全部原样保留，危险改写数为 0。

Task 1 commit：`72e70f5`。

## 3. Task 2：补 errorCatched 与 waitGlobalInitialized

文件：`assets/chat/chat_stage.html:731-775`，位置在 `_TH` 定义之后、`for(var _k in _TH)` 挂窗之前。

原位置关键代码：

```js
for(var _k in _TH){if(_TH.hasOwnProperty(_k)){window[_k]=_TH[_k];}}
```

改后关键代码：

```js
var _EC_RETHROW=false;
function _ecReport(e){try{if(window.toastr&&toastr.error)toastr.error(String((e&&e.message)||e),"脚本错误");}catch(_e1){}console.error("[errorCatched]",e&&e.stack||e);}
_TH.errorCatched=function(fn){return function(){try{var r=fn.apply(this,arguments);if(r&&typeof r.then==="function"){return Promise.resolve(r).then(function(v){return v;},function(e){_ecReport(e);if(_EC_RETHROW)throw e;});}return r;}catch(e){_ecReport(e);if(_EC_RETHROW)throw e;}};};
_TH.waitGlobalInitialized=function(name){if(typeof window[name]!=="undefined")return Promise.resolve(window[name]);return new Promise(function(resolve){var _waited=0,_warned=false;var _t=setInterval(function(){if(typeof window[name]!=="undefined"){clearInterval(_t);resolve(window[name]);return;}_waited+=100;if(!_warned&&_waited>=10000){_warned=true;parent.postMessage({__thLog:true,text:"[waitGlobalInitialized] 仍在等待 window."+name+" (id="+_id+", 已等10秒, 不超时)"},"*");}},100);});};
```

拼接后的实际 JS 全文见 `DiaoYan/P3/诊断/out/p3d_patch_extracted.js`，内容即上方四行拼接结果。提取器原样 eval 生产文件的单引号字符串，再用 `vm.Script` 检查，输出：

```text
提取字符串字面量行数: 4
拼接后 JS 长度: 949
P3-D patch 拼接产物: PARSE OK
已写入 DiaoYan/P3/诊断/out/p3d_patch_extracted.js
```

`_EC_RETHROW` 位于 `chat_stage.html:737`，本轮设为 `false`。官方 d.ts 未规定是否重抛；不重抛是本轮判断，避免异常冒到 jQuery ready 队列。同步异常由 try/catch 捕获；thenable 路径使用 `Promise.resolve(r).then(success, rejection)`，因此 async 函数 Promise 和只有 then 的对象都覆盖。错误同时送 `toastr.error` 和 `console.error`。

`waitGlobalInitialized`：已有全局立即 resolve；不存在时每 100ms 轮询；永不 reject、永不放弃；超过 10 秒只发一次包含 global 名和 `_id` 的 `parent.postMessage` 日志。iframe 销毁后其 interval 随执行环境终止，这是本轮接受的有界泄漏。T2/T5 中 init 均按预期停在等待 `window.Mvu`，状态栏仍为骨架是预期结果。

Task 2 commit：`a7e6df0`。

## 4. Task 3：String.replace 字面量替换引用

文件：`assets/chat/chat_stage.html`。

改前：

```js
if (/<head>/i.test(html)) return html.replace(/<head>/i, '<head>' + patch);
if (/<html/i.test(html)) return html.replace(/<html[^>]*>/, function(m){ return m + patch; });
if (/<\\/body>/i.test(html)) return html.replace(/<\\/body>/i, patch + '</body>');
return html + patch;
```

改后：

```js
if (/<head>/i.test(html)) return html.replace(/<head>/i, function(){ return '<head>' + patch; });
if (/<html/i.test(html)) return html.replace(/<html[^>]*>/, function(m){ return m + patch; });
if (/<\\/body>/i.test(html)) return html.replace(/<\\/body>/i, function(){ return patch + '</body>'; });
return html + patch;
```

共检查 4 个分支：`<head>` 已改；`<html>` 原本就是函数形式，保持并确认；`</body>` 已改；else 是字符串拼接，不调用 replace，不存在替换引用解释。

Task 3 commit：`6daf71f`。

## 5. 离线验证对拍表

| 项 | 改前 | 改后 |
|---|---|---|
| regex_7 脚本体 PARSE | FAIL: Unexpected identifier '深蓝' | PARSE OK |
| 同行危险命中数 | 141 | 卡源静态计数仍 141；产物中 0 行被破坏，全部块内原样保留 |
| T5 harness CARD-ERR | Uncaught SyntaxError | 无 CARD-ERR |
| T2 harness CARD-ERR | errorCatched is not defined | 无 CARD-ERR |
| 下一个错误是什么 | — | 无新异常；日志显示等待 `window.Mvu`，这是 P3-E 坐标 |

T5 harness 原始结果关键行：

```text
[iframe] [patch3] _TH已挂窗: errorCatched=function waitGlobalInitialized=function
[iframe] [waitGlobalInitialized] 仍在等待 window.Mvu (id=T5_noext, 已等10秒, 不超时)
[iframe] [host] iframe load
[iframe] HARVEST_DONE
```

T2 harness 原始结果关键行：

```text
[iframe] [patch3] _TH已挂窗: errorCatched=function waitGlobalInitialized=function
[iframe] [waitGlobalInitialized] 仍在等待 window.Mvu (id=T2_noext, 已等10秒, 不超时)
[iframe] [host] iframe load
[iframe] HARVEST_DONE
```

两组均没有 `CARD-ERR`，T2 不再出现 `errorCatched is not defined`。`initMvu()` 为 fire-and-forget，按钮绑定代码不会被等待 Mvu 阻塞；但 Mvu 到来以前，状态栏数字不出现是预期。

## 6. harness 与真 injectBridge 一致性

`build_browser_harness_noext.js` 不再手写两个函数的实现。它 require `extract_inject_patch.js`；提取器直接从生产 `chat_stage.html` 起止标记之间取得单引号字符串字面量，逐个 eval 后拼接。因此 harness 的 errorCatched/waitGlobalInitialized JS 与真注入逐字同源。harness 只额外提供真实 patch 所需的 `_TH={}`、`_id` 和 `for-in` 挂窗骨架，并将 `__thLog` 接入日志显示。

局限：harness 不是完整真实 `_TH` 环境，其余桥方法仍未仿制；本轮验证的是语法、两个新增官方函数、regex_6 调度和等待行为。

## 7. 每个 commit 的验证

### `72e70f5`

```text
dart run tool/check_chat_stage.dart
SYNTAX OK (2 blocks)
```

```text
dart analyze
1146 issues found.
```

本次 analyze 输出中 error 级诊断为 0；1146 条为既有 info/warning 级输出。

```text
git status --short
```

无本轮 tracked 修改；仅有既有未跟踪 `DiaoYan/` 调研资料。

### `a7e6df0`

```text
dart run tool/check_chat_stage.dart
SYNTAX OK (2 blocks)
```

```text
dart analyze
1146 issues found.
```

```text
git status --short
```

无本轮 tracked 修改；仅有既有未跟踪 `DiaoYan/` 调研资料。

### `6daf71f`

```text
dart run tool/check_chat_stage.dart
SYNTAX OK (2 blocks)
```

```text
dart analyze
1146 issues found.
```

```text
git status --short
```

无本轮 tracked 修改；仅有既有未跟踪 `DiaoYan/` 调研资料。

Task 1 另行执行 `flutter test test/normalize_code_quotes_test.dart`，8 项全部通过。Task 1 另行执行 `dart run DiaoYan/P3/诊断/pipeline_repro.dart` 与 `node DiaoYan/P3/诊断/find_syntax_break.js`，regex_7 均为 `PARSE OK`。Task 2+3 另行执行 `node DiaoYan/P3/诊断/build_browser_harness_noext.js`，T2/T5 均无 CARD-ERR。

## 8. 给人类的真机复测说明

1. 先确认资产重打包：

```powershell
Get-ChildItem build -Recurse -Filter chat_stage.html
```

找到的文件必须含本轮标记 `_EC_RETHROW`、`waitGlobalInitialized`，否则测到的是旧资产。
2. 完全重启 App，禁止热重载；热重载不会刷新 iframe 内联代码。
3. 保存日志：

```powershell
flutter run 2>&1 | Tee-Object -FilePath DiaoYan/P3/run.log
```

4. 检查：

```powershell
Select-String -Path DiaoYan/P3/run.log -Pattern 'CARD-ERR'
```

期望不再有 `SyntaxError` 与 `errorCatched is not defined`。
5. 观察可见行为：开局界面的“是”按钮应可点；状态栏仍只有骨架、没有数字属于预期，因为 `window.Mvu` 尚未由 P3-E 注入。

## 9. 我没能验证的部分

- 未在真实 Android/iOS WebView 和完整 App 内进行真机复测。
- 未验证 toastr 的实际视觉弹窗效果。
- 未翻转 `_EC_RETHROW=true` 验证重抛分支。
- 未验证 P3-E 注入 `window.Mvu` 后 init 的后续逻辑。
- 离线 harness 没有完整真实 `_TH` 方法集合，因此不能替代真注入环境对所有桥调用的验证。
- “是”按钮在离线环境中通过脚本解析、DOMContentLoaded 完成且无 CARD-ERR 间接证明绑定链可运行；实际人工点击仍需按上节真机步骤确认。
