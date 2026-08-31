# P3-C 施工报告：补齐消息 iframe 运行环境（五刀）

---

## 1. 基线
- **基线 commit**：`77b037c` (fix(wv): P3-B3 空body兜底……)
- **本轮共 6 个 commit**（5 个主 Task + 1 个 Task-2 热修）：
  - `def0f36` T1
  - `53ada76` T2
  - `5d8c3b2` T3
  - `e864f51` T4
  - `5d6c0ce` T5
  - `e30f308` T2b（yaml 资产读取独立 try，不再拖垮 jquery/lodash/toastr）

---

## 2. 每 Task 变更明细（行号以最终文件 `assets/chat/chat_stage.html` / `lib/.../webview_chat_stage.dart` 为准）

### Task 1: 废除猜测式注入，改为无条件注入（主刀） `def0f36`
- **位置**：`chat_stage.html:493-501`
- **改前**：
```js
    try{
      var _needJq=(html.indexOf("$(")>=0)||(html.indexOf("jQuery")>=0);
      var _needLodash=(html.indexOf("_.")>=0);
      var _needToastr=(html.indexOf("toastr.")>=0);
      if(_needJq&&_libs.jquery){_libScript+="<script>"+decodeB64Utf8(_libs.jquery)+"<\/script>";}
      if(_needLodash&&_libs.lodash){_libScript+="<script>"+decodeB64Utf8(_libs.lodash)+"<\/script>";}
      if(_needToastr&&_libs.toastrJs){if(_libs.toastrCss){_libScript+="<style>"+decodeB64Utf8(_libs.toastrCss)+"<\/style>";}_libScript+="<script>"+decodeB64Utf8(_libs.toastrJs)+"<\/script>";}
    }catch(e){parent.postMessage({__thLog:true,text:"[兼容库] 内联失败: "+e},"*");}
```
- **改后**：
```js
    // [P3-C/T1] 无条件注入,与引擎房 createEngineRoom 同一套库同一方式(存在即注入,不再 indexOf 猜)
    try{
      if(_libs.jquery){_libScript+="<script>"+decodeB64Utf8(_libs.jquery)+"<\/script>";}
      if(_libs.lodash){_libScript+="<script>"+decodeB64Utf8(_libs.lodash)+"<\/script>";}
      if(_libs.toastrCss){_libScript+="<style>"+decodeB64Utf8(_libs.toastrCss)+"<\/style>";}
      if(_libs.toastrJs){_libScript+="<script>"+decodeB64Utf8(_libs.toastrJs)+"<\/script>";}
    }catch(e){parent.postMessage({__thLog:true,text:"[兼容库] 内联失败: "+e},"*");}
```
- **原因**：压缩卡片代码中 `$(`/`_. `/`toastr.` 被混淆/拆分导致 `indexOf` 误判为 N，`init()` 从未执行 → UI 无骨架、事件不绑。与引擎房“无条件+存在即注入”完全对齐，治本。

### Task 2: 补全局 `YAML` `53ada76` + `e30f308`（热修）
- **chat_stage.html（card 注入）**：499-500 行
```js
      // [P3-C/T2] yaml v2 IIFE(挂全局 YAML),MVU parseString 与 EJS 模板都引用裸 YAML 全局
      if(_libs.yaml){_libScript+="<script>"+decodeB64Utf8(_libs.yaml)+"<\/script>";}
```
- **chat_stage.html（引擎房注入）**：1467-1468 行
```js
        // [P3-C/T2] 引擎房补 YAML(MVU parseString 解析(initvar) 与 EJS function_call 模板都用裸 YAML 全局)
        + (window.__KIRA_LIBS && window.__KIRA_LIBS.yaml ? '<script>' + decodeB64Utf8(window.__KIRA_LIBS.yaml) + '<\/script>' : '')
```
- **webview_chat_stage.dart**：
  - 141 行：`static String? _yamlB64;`（缓存字段）
  - 176-186 行（_loadCompatLibs，热修后独立 try）：
```dart
      // [P3-C/T2] yaml 单独 try:缺失或损坏只失去 YAML,不拖垮 jquery/lodash/toastr 的既有加载
      final toastrCss = await rootBundle.loadString('assets/libs/toastr.min.css');
      String? yamlJs;
      try {
        yamlJs = await rootBundle.loadString('assets/libs/yaml.min.js');
      } catch (e) {
        KiraLogger().info('兼容库', 'yaml 库读取失败(仅 YAML 全局缺失): $e');
      }
      ...
      _yamlB64 = yamlJs == null ? null : base64Encode(utf8.encode(yamlJs));
```
  - 236 行（_injectCompatLibs 注入 `__KIRA_LIBS.yaml`）：`'yaml:"${_yamlB64 ?? ''}"'`
- **原因**：MVU `parseString` 调用 `YAML.parseDocument(...{merge:true}).toJS()`，EJS 模板用 `YAML.stringify(v,{blockQuote:'literal'})`；上游源码无 `import YAML`，靠 tsconfig `allowUmdGlobalAccess` 当全局 → 必须由宿主挂 `window.YAML`。P3-B 实机报错 `ReferenceError: YAML is not defined` 即此。

### Task 3: `__lastMsgId` 用真实消息 id `5d8c3b2`
- **位置**：`chat_stage.html:663-664`
- **改前**：`'_TH.__lastMsgId=0;' +`
- **改后**：
```js
      // [P3-C/T3] __lastMsgId 用 injectBridge 第二参(该 iframe 所属消息的真实 id,见 setMessages 建 frame 处 m.id),不再恒 0
      '_TH.__lastMsgId=' + JSON.stringify(id) + ';' +
```
- **原因**：卡片会拼斜杠命令 `/cut ${getCurrentMessageId()} | /trigger`，恒为 0 会静默裁剪第 0 条消息。

### Task 4: CARD-ENV 探针加序号 + 3s 后二次探测 `e864f51`
- **位置**：`chat_stage.html:515-528`
- **改前**：
```js
   // [P3-B/T2] 缺失全局探测：只检测不修复，一条日志看清卡缺什么。整段 try，探针本身绝不许抛错。
   var _guardEnv = '<script>(function(){try{' +
       'var _cidenv=' + JSON.stringify(id) + ';' +
       'var _t=function(n){return (typeof n!=="undefined")?"Y":"N";};' +
       'parent.postMessage({__thLog:true,text:"[WV-10] CARD-ENV id="+_cidenv+" $="+_t(window.$)+" _="+_t(window._)+" toastr="+_t(window.toastr)+" z="+_t(window.z)+" YAML="+_t(window.YAML)+" Mvu="+_t(window.Mvu)+" eventOn="+_t(window.eventOn)+" registerVariableSchema="+_t(window.registerVariableSchema)},"*");' +
       '}catch(_){} })();<\/script>';
```
- **改后**：
```js
   // [P3-B/T2] 缺失全局探测：只检测不修复，一条日志看清卡缺什么。整段 try，探针本身绝不许抛错。
   // [P3-C/T4] 探针加自增序号+时间戳:seq 记在主文档 window(随每次 injectBridge 调用+1,
   // iframe 重建必重走 injectBridge → 同 id 多条日志即多次重建的直接证据);
   // 另加 3s 后二次探测 CARD-ENV2,捕获异步加载后的最终态(首探对异步库必误判 N)。
   var _envFields='" $="+_t(window.$)+" _="+_t(window._)+" toastr="+_t(window.toastr)+" z="+_t(window.z)+" YAML="+_t(window.YAML)+" Mvu="+_t(window.Mvu)+" eventOn="+_t(window.eventOn)+" registerVariableSchema="+_t(window.registerVariableSchema)';
   window.__cardEnvSeq=(window.__cardEnvSeq||0)+1;
   var _envSeq=window.__cardEnvSeq;
   var _guardEnv = '<script>(function(){try{' +
       'var _cidenv=' + JSON.stringify(id) + ';' +
       'var _t=function(n){return (typeof n!=="undefined")?"Y":"N";};' +
       'parent.postMessage({__thLog:true,text:"[WV-10] CARD-ENV seq=' + _envSeq + ' t="+Date.now()+" id="+_cidenv+' + _envFields + '},"*");' +
       'setTimeout(function(){try{' +
       'parent.postMessage({__thLog:true,text:"[WV-10] CARD-ENV2 seq=' + _envSeq + ' t="+Date.now()+" id="+_cidenv+' + _envFields + '},"*");' +
       '}catch(_){}},3000);' +
       '}catch(_){} })();<\/script>';
```
- **原因**：
  - 同一 id 出现 7 条 `CARD-ENV` 机制定性：探针脚本随每次 `injectBridge` 注入到**新建文档**中仅执行一次，不可能自重复 → 多条 = 多次重建。代码仅有两个 `injectBridge` 调用点：①setMessages 建卡（1150 行）②虚拟化恢复（978 行）。
  - 首探早于大 patch 脚本（`_TH` 定义 + for-in 挂 window）执行，`eventOn=N` 属时序预期；3s 后 `CARD-ENV2` 捕获异步库加载后的最终态。

### Task 5: 桥日志降噪 `5d6c0ce`
- **位置**：`chat_stage.html:905-908`
- **改前**：
```js
    sendToFlutter('log', { text: '[TH中转] 收到iframe请求 method=' + method });
```
- **改后**：
```js
    // [P3-C/T5] 降噪:同 method 只在首次出现打一条,防刷屏淹没 CARD-ENV 探针;
    // 下方成功/失败日志不受影响(失败必须可见是铁律)。
    var _seen = window.__thSeenMethods || (window.__thSeenMethods = {});
    if (!_seen[method]) { _seen[method] = 1; sendToFlutter('log', { text: '[TH中转] 收到iframe请求 method=' + method }); }
```
- **原因**：每次桥请求都打日志刷满屏，淹没 `CARD-ENV` 关键探针。失败日志（959 行）原样保留，必须可见。

---

## 3. Task 1 体积代价与虚拟化内存
| 库 | 体积 |
|---|---|
| jquery.min.js | 87,533 B |
| lodash.min.js | 73,154 B |
| toastr.min.css | 6,454 B |
| toastr.min.js | 5,251 B |
| **四库合计** | **172,392 B (≈ 168.4 KB raw)** |
| yaml.min.js (Task 2) | 104,337 B (≈ 101.9 KB) |

- **每个 card iframe 文档字符串增量**：
  - 对旧启发式从未命中的卡：+172,392 B
  - 实务增量（旧逻辑已命中 jQuery，增量只在 lodash+toastr+css）：84,859 B
- **主文档 `window.__KIRA_LIBS` 常驻 base64**：(172,392 + 104,337) × 4/3 ≈ **368,972 字符** (~360 KB JS 字符串，UTF-16 内存 ≈ 722 KB)。随 iframe 数量**不增长**，但每次重建需重新 decode+解析。
- **虚拟化清空时内存是否释放**：**不确定**。`f.src='about:blank'` 销毁 iframe 文档，其 JS 堆（含各库运行时对象）理论随 document 回收；WebView GC 与 `revokeObjectURL` 实际时机未实测。恢复时重新 decode+重建。

---

## 4. Task 2 库信息与全局挂载
| 项目 | 详情 |
|---|---|
| **库名** | `yaml` (npm) |
| **版本** | 2.9.0（满足 `^2.8.0` 区间） |
| **来源 URL** | https://registry.npmjs.org/yaml/-/yaml-2.9.0.tgz （本机 npm 镜像配置走 npmmirror：https://registry.npmmirror.com/yaml/-/yaml-2.9.0.tgz） |
| **体积** | 104,337 B (esbuild --bundle --minify --format=iife --global-name=YAML 产物) |
| **许可证** | ISC (Eemeli Aro <eemeli@gmail.com>) |
| **打包工具** | esbuild 0.28.2，入口 `node_modules/yaml/browser/index.js` |
| **显式全局挂载** | 产物顶层 `var YAML=(()=>{...})();`（classic script 顶层 `var` ⇒ `window.YAML`），外加 footer：<br>`if(typeof window!=="undefined"&&typeof window.YAML==="undefined"&&typeof YAML!=="undefined"){window.YAML=YAML;}` 双保险。 |
| **关键 API 验证（vm 沙箱模拟 classic script）** | `window.YAML` = object ✅<br>`parseDocument('a: 1\nb:\n - x\n',{merge:true}).toJS()` → `{"a":1,"b":["x"]}` ✅（merge key `<<` 解析通过）<br>`stringify({a:1,n:'多行\n文本'},{blockQuote:'literal'})` → `|-` 字面块 ✅ |
| **MVU/EJS 实际引用的全局** | `YAML.parse` / `YAML.parseAllDocuments` / `YAML.parseDocument` / `YAML.stringify` — 全部在导出表中（`Object.keys` 实测含有） |
| **pubspec.yaml** | **无需改动**。证据：pubspec 仅声明 `- assets/` 与 `- assets/live2d/`；当前生产包以此方式加载 `assets/chat/chat_stage.html`、`assets/libs/jquery.min.js|lodash|toastr|mvu_bundle.js|ejs_bundle.js`（P3-B 真机 MVU 已执行报错、CARD-ENV 曾见 `_=Y` 证明 lodash b64 已达页面），目录声明在此工具链已递归覆盖子目录，新增 `assets/libs/yaml.min.js` 同路径自然打包。 |

---

## 5. Task 4 结论：多条 `CARD-ENV` 的真实原因
**机制层结论（本轮代码已定死）**：探针脚本随每次 `injectBridge` 注入到**新建 iframe 文档**中，解析执行一次，自身不可能重复发射。同一 id 出现 N 条 ⇔ `injectBridge` 对该 id 被调用 N 次 ⇔ 该消息的 iframe 文档被销毁并重建了 N 次。代码仅有两个调用点：
1. `setMessages` 整表建卡（1150 行）
2. 虚拟化恢复（978 行 `var injected2 = injectBridge(html, f.getAttribute('data-frame-id'))`）

**判读工具已就绪**：
- `seq`：主文档 `window.__cardEnvSeq`，每次 `injectBridge` 调用 +1（全局单调，已实测连续两次调用 seq=1→2）。
- `t`：注入时 `Date.now()`（iframe 内执行）。
- 若 7 条 `t` 彼此间隔秒级以上且伴随滚动 → 虚拟化；若 7 条 `t` 密集扎堆且伴随其它消息渲染日志 → 整表 `setMessages` 重建。

**本轮不修复该重建本身**（属渲染路径改动，须独立一轮），只给判读工具。

---

## 6. 拼接后的预期 JS 片段全文（铁律 3 盲区覆盖）

> 以下为 `injectBridge` 运行时拼接产出的 **iframe HTML 里各 `<script>` 块全文**（`id=42, seq=1` 为例），已在 `verify_patch.js` 端到端跑通 `node --check`（8/8 块 SYNTAX OK），引号配对、`<\/script>` 转义逐字核对无误。

### (a) libs 区（紧随 `_guardErr` 之后，文档顺序）
```html
<script>jquery.min.js 全文</script>
<script>lodash.min.js 全文</script>
<style>toastr.min.css 全文</style>
<script>toastr.min.js 全文</script>
<script>yaml.min.js 全文</script>
```
五库文件均实测**不含** `</script` 与 `<!--`，内联嵌套安全；jquery 内含 2 处 `<script` 字样但无 `<!--` 配合，不触发 script double-escape。

### (b) `__lastMsgId` 片段（Task 3）
```js
_TH.__lastMsgId=42;
```

### (c) 探针块全文（Task 4，harness 实测输出，id=42, seq=1）
```js
(function(){try{var _cidenv=42;var _t=function(n){return (typeof n!=="undefined")?"Y":"N";};parent.postMessage({__thLog:true,text:"[WV-10] CARD-ENV seq=1 t="+Date.now()+" id="+_cidenv+" $="+_t(window.$)+" _="+_t(window._)+" toastr="+_t(window.toastr)+" z="+_t(window.z)+" YAML="+_t(window.YAML)+" Mvu="+_t(window.Mvu)+" eventOn="+_t(window.eventOn)+" registerVariableSchema="+_t(window.registerVariableSchema)},"*");setTimeout(function(){try{parent.postMessage({__thLog:true,text:"[WV-10] CARD-ENV2 seq=1 t="+Date.now()+" id="+_cidenv+" $="+_t(window.$)+" _="+_t(window._)+" toastr="+_t(window.toastr)+" z="+_t(window.z)+" YAML="+_t(window.YAML)+" Mvu="+_t(window.Mvu)+" eventOn="+_t(window.eventOn)+" registerVariableSchema="+_t(window.registerVariableSchema)},"*");}catch(_){}},3000);}catch(_){} })();
```

### (d) 引擎房新增行产物形态（Task 2，紧随 toastrJs 之后）
```html
<script>yaml.min.js 全文</script>
```

### (e) Task 5 非字符串拼接（主文档实码），无盲区，仅贴源码行
```js
var _seen = window.__thSeenMethods || (window.__thSeenMethods = {});
if (!_seen[method]) { _seen[method] = 1; sendToFlutter('log', { text: '[TH中转] 收到iframe请求 method=' + method }); }
```

---

## 7. 每个 commit 的验证命令原始输出（逐条、不合并）

### baseline `77b037c` 前（仅 checker）
```text
── block 1/2  (build/check_block_1.js, 1259 chars)
   OK
── block 2/2  (build/check_block_2.js, 65330 chars)
   OK
SYNTAX OK (2 blocks)
```

### `def0f36` (T1) 提交后
```text
── block 1/2  (build/check_block_1.js, 1259 chars)
   OK
── block 2/2  (build/check_block_2.js, 65205 chars)
   OK
SYNTAX OK (2 blocks)
```
```text
0
exit=2
```
```text
 M linux/flutter/generated_plugin_registrant.cc
 M linux/flutter/generated_plugin_registrant.h
 M linux/flutter/generated_plugins.cmake
 M macos/Flutter/GeneratedPluginRegistrant.swift
 M windows/flutter/generated_plugin_registrant.cc
 M windows/flutter/generated_plugin_registrant.h
 M windows/flutter/generated_plugins.cmake
?? DiaoYan/P3/API基线.txt
?? DiaoYan/P3/P3-0_样本解剖.md
?? DiaoYan/P3/P3-B_打.md
?? DiaoYan/P3/mvu.txt
?? DiaoYan/P3/样本解剖/
?? DiaoYan/PiuPiuCard_《道渊》v5.2.json
?? DiaoYan/ref/
```
> 说明：`dart analyze` 全量跑出 1102 条 issues（info 422 + warning 680），**error=0**；7 个 modified 文件为基线前已存在的 flutter 自动生成插件 registrant，8 个 untracked 为 DiaoYan 资料，非本轮引入。

### `53ada76` (T2) 提交后
```text
── block 1/2  (build/check_block_1.js, 1259 chars)
   OK
── block 2/2  (build/check_block_2.js, 65595 chars)
   OK
SYNTAX OK (2 blocks)
```
```text
0
1102 issues found.
```
```text
 M linux/flutter/generated_plugin_registrant.cc
 ... (同上)
?? DiaoYan/... (同上)
```

### `5d8c3b2` (T3) 提交后
```text
── block 1/2  (build/check_block_1.js, 1259 chars)
   OK
── block 2/2  (build/check_block_2.js, 65726 chars)
   OK
SYNTAX OK (2 blocks)
```
```text
0
1102 issues found.
```
```text
 M linux/flutter/generated_plugin_registrant.cc
 ... (同上)
?? DiaoYan/... (同上)
```

### `e864f51` (T4) 提交后
```text
── block 1/2  (build/check_block_1.js, 1259 chars)
   OK
── block 2/2  (build/check_block_2.js, 66272 chars)
   OK
SYNTAX OK (2 blocks)
```
```text
0
1102 issues found.
```
```text
 M linux/flutter/generated_plugin_registrant.cc
 ... (同上)
?? DiaoYan/... (同上)
```

### `5d6c0ce` (T5) 提交后
```text
── block 1/2  (build/check_block_1.js, 1259 chars)
   OK
── block 2/2  (build/check_block_2.js, 66479 chars)
   OK
SYNTAX OK (2 blocks)
```
```text
0
1102 issues found.
```
```text
 M linux/flutter/generated_plugin_registrant.cc
 ... (同上)
?? DiaoYan/... (同上)
5d6c0ce fix(wv): P3-C5 [TH中转]请求日志同method只打首次——防刷屏淹没CARD-ENV探针,失败catch日志原样保留
e864f51 fix(wv): P3-C4 CARD-ENV探针加seq+t并增3秒后CARD-ENV2二次探测——seq记主文档window随injectBridge调用递增,多条日志=多次重建的直接证据;二次探测防异步加载误判
5d8c3b2 fix(wv): P3-C3 card _TH.__lastMsgId用真实消息id——injectBridge第二参JSON.stringify内插,替代恒0,getCurrentMessageId不再静默指向第0条
53ada76 fix(wv): P3-C2 补全局YAML——yaml@2.9.0(^2.8.0)浏览器打入IIFE挂window.YAML,注入引擎房与card iframe,治MVU parseString解析(initvar) ReferenceError
def0f36 fix(wv): P3-C1 card iframe库注入废除indexOf猜测改为无条件——jquery/lodash/toastrCss/toastrJs与引擎房同一套同一方式,治压缩卡代码漏判导致的不绑事件
77b037c fix(wv): P3-B3 空body兜底——load后延时检测body无可渲染内容则上报[WV-10]CARD-BLANK并显示可见提示,不用透明空白
```

### `e30f308` (T2b 热修) 提交后
```text
── block 1/2  (build/check_block_1.js, 1259 chars)
   OK
── block 2/2  (build/check_block_2.js, 66479 chars)
   OK
SYNTAX OK (2 blocks)
```
```text
0
1102 issues found.
```
```text
 M linux/flutter/generated_plugin_registrant.cc
 ... (同上)
?? DiaoYan/... (同上)
e30f308 fix(wv): P3-C2b yaml资产读取独立try——资产缺失只失YAML全局,不再拖垮jquery/lodash/toastr的既有加载
5d6c0ce fix(wv): P3-C5 [TH中转]请求日志同method只打首次——防刷屏淹没CARD-ENV探针,失败catch日志原样保留
e864f51 fix(wv): P3-C4 CARD-ENV探针加seq+t并增3秒后CARD-ENV2二次探测——seq记主文档window随injectBridge调用递增,多条日志=多次重建的直接证据;二次探测防异步加载误判
5d8c3b2 fix(wv): P3-C3 card _TH.__lastMsgId用真实消息id——injectBridge第二参JSON.stringify内插,替代恒0,getCurrentMessageId不再静默指向第0条
53ada76 fix(wv): P3-C2 补全局YAML——yaml@2.9.0(^2.8.0)浏览器打入IIFE挂window.YAML,注入引擎房与card iframe,治MVU parseString解析(initvar) ReferenceError
def0f36 fix(wv): P3-C1 card iframe库注入废除indexOf猜测改为无条件——jquery/lodash/toastrCss/toastrJs与引擎房同一套同一方式,治压缩卡代码漏判导致的不绑事件
77b037c fix(wv): P3-B3 空body兜底——load后延时检测body无可渲染内容则上报[WV-10]CARD-BLANK并显示可见提示,不用透明空白
```

### 端到端拼接产物验证（harness `verify_patch.js`，Task 3/4 后）
```text
拼接产物共 8 个 script 块
拼接产物全部 8 块 SYNTAX OK
__lastMsgId 片段: _TH.__lastMsgId=42;
── 探针块全文 ──
(function(){try{var _cidenv=42;var _t=function(n){return (typeof n!=="undefined")?"Y":"N";};parent.postMessage({__thLog:true,text:"[WV-10] CARD-ENV seq=1 t="+Date.now()+" id="+_cidenv+" $="+_t(window.$)+" _="+_t(window._)+" toastr="+_t(window.toastr)+" z="+_t(window.z)+" YAML="+_t(window.YAML)+" Mvu="+_t(window.Mvu)+" eventOn="+_t(window.eventOn)+" registerVariableSchema="+_t(window.registerVariableSchema)},"*");setTimeout(function(){try{parent.postMessage({__thLog:true,text:"[WV-10] CARD-ENV2 seq=1 t="+Date.now()+" id="+_cidenv+" $="+_t(window.$)+" _="+_t(window._)+" toastr="+_t(window.toastr)+" z="+_t(window.z)+" YAML="+_t(window.YAML)+" Mvu="+_t(window.Mvu)+" eventOn="+_t(window.eventOn)+" registerVariableSchema="+_t(window.registerVariableSchema)},"*");}catch(_){}},3000);}catch(_){} })();
── 探针块完 ──
两次调用产生的 seq: 2
含 CARD-ENV2: true
```

### yaml IIFE 打包与 API 验证
```text
build ok
104337
FINAL-SYNTAX-OK
```
```text
SYNTAX-OK
window.YAML typeof: object
version: undefined
toJS: {"a":1,"list":["x","y"]}
merge test: {"hp":10,"mp":5}
stringify: "a: 1\nn: |-\n  多行\n  文本\n"
```
```text
has parse/parseAllDocuments/parseDocument/stringify: function function function function
```
```text
?. 出现: 79
?? 出现: 54
class 关键字: 14
=> 出现: 239
```

---

## 8. 复测说明（写给人类操作者）

### 8.1 资产已重新打包确认
```powershell
Get-ChildItem build -Recurse -Filter chat_stage.html
```
在找到的文件（应在 `build\...\flutter_assets\assets\chat\chat_stage.html`）中：
```powershell
Select-String -Path <上述文件> -Pattern "CARD-ENV2" -SimpleMatch
# 必须命中
```
```powershell
Get-ChildItem build -Recurse -Filter yaml.min.js
# 必须存在于 flutter_assets\assets\libs\ 下
```
**若未命中 → 测的是旧资产（上一轮曾因此白测一轮），请 `flutter clean && flutter build <target>` 重打。**

### 8.2 必须完全重启 App
**禁止热重载**（热重载不刷新 iframe 内联代码）。杀进程重进。

### 8.3 关键日志 grep 与期望读数
```powershell
# 1. 首次探针（注入即刻，早于 _TH 大 patch 执行）
grep "CARD-ENV " log.txt   # 带空格排除 CARD-ENV2
```
**期望**（每次重建一条，seq 单调递增）：
```
[WV-10] CARD-ENV seq=<n> t=<ms> id=<mid> $=Y _=Y toastr=Y z=N YAML=Y Mvu=N eventOn=N registerVariableSchema=N
```
> 注：首探时大 patch（_TH 定义 + for-in 挂 window）尚未跑 → `eventOn=N` 是**时序预期**；`registerVariableSchema=N` 永远 N（上游安全跳过）；`z=N` 预期（zod 不在 assets）。

```powershell
# 2. 二次探针（注入 3 秒后）
grep "CARD-ENV2" log.txt
```
**期望**：同字段，**eventOn=Y**（大 patch 已跑完，`_TH.eventOn` 已挂上 `window`）。其余同上。若某全局首探 N 而 ENV2=Y，说明该物由卡异步自举（本轮已无条件注入，此情况不应出现）。

```powershell
# 3. 错误捕手
grep "CARD-ERR" log.txt
```
**允许且预期**见到：`Mvu is not defined` / `Cannot read properties of undefined (reading 'events')` 之类（卡片内 `eventOn(Mvu.events.VARIABLE_UPDATE_END...)`，P3-E 未做）。**不应**再看到 jQuery/$/lodash 相关 undefined。

```powershell
# 4. 引擎房
grep "\[引擎房\]" log.txt
```
**预期不再出现** `YAML is not defined`。若出现 `[引擎房] 收到事件 ...` 说明记账#1 疑点不实（更好）；若始终无该日志，记账#1 疑似坐实（引擎房 `__thEvent` 监听未注册，见记账）。

### 8.4 肉眼判定（本轮成功标准）
- 状态栏 UI 骨架**画出来了**
- 开场白那个 **"是" 按钮点得动**
- **tab 切得动**
- 状态栏里的数字是空的/占位的/旧的 —— **这是预期，不是失败**（等 P3-D 同步变量快照、P3-E `window.Mvu`）。

### 8.5 日志噪声
`[TH中转] 收到iframe请求 method=X` 每个 method 全文日志**只应出现一次**；失败行 `[TH中转] X 失败:` 不受限。

---

## 9. 我没能验证的部分（必须有此节）
1. **未在真机/模拟器跑 App**；所有结论基于：语法检查链、`verify_patch.js` 拼接产物 `node --check`、vm 沙箱模拟 classic script、`dart analyze` 零 error。
2. **yaml IIFE 在真 WebView 内执行未实测**。esbuild 默认 `target=esnext`，产物含 `?.`×79、`??`×54、`class`×14、`=>`×239 → 需 WebView ≥ Chrome 80 / iOS 13.4+。间接证据：MVU bundle (1.2 MB webpack 产物) 已在这台真机上执行过（P3-B 报错日志即证据），该机型语法门槛已过，但 yaml 库本身的真机执行未实测。
3. **`window.YAML` 挂载在 vm 沙箱验证过（typeof object），真机未验**。
4. **虚拟化内存释放：不确定**（理论+未实测）。
5. **同一 id 多条 CARD-ENV 的具体来源路径（虚拟化 vs 整表重建）**：给出判读方法但未实测。
6. **"卡片按钮点得动/tab 切得动"是本轮成功判据，但我无法操作真机** —— 需人类按 8.2/8.4 执行。
7. `dart analyze` info/warning 1102 条为基线既有（未在基线单独统计；仅核对 error=0 且我的改动文件无新增 error；总数在 T1 与 T2b 两次全量计数均为 1102）。
8. **esbuild target 未降级**；如需覆盖更老 WebView（Android 7 等），需显式 `target: 'chrome80'` 重建 yaml.min.js。

---

## 10. 记账（过程发现、本轮不修、留待后续）
1. **引擎房事件监听块结构性缺陷**（`chat_stage.html:1479-1493`）  
   第一段 `<script>` 后紧接第二个 `<script>` 而中间无 `</script>` 闭合：  
   ```js
   + '<script>' + 'window.__chatMessages=[];' + '<script>' + 'window.__chatMessages=[];' + 'window.addEventListener(...)' + '<\/script>'
   ```
   产生的 script 文本为 `window.__chatMessages=[];<script>window.__chatMessages=[];window.addEventListener(...)…` → JS 解析器看到 `<` 后无左操作数，**ParseError / ReferenceError: script is not defined**（取决于实现），整个块**从未执行** → `__thEvent` 监听（接收外层 `__emitToEngine` 中继的 `message_received` 等事件、同步 `__chatMessages`）从未注册。  
   真机验证点：日志里**从未见过** `[引擎房] 收到事件 ...`（若始终无 → 此判断坐实）。  
   属"禁止触碰 createEngineRoom"，**不动**，建议单列一轮（P3-E/F 前置依赖）。

2. **`[iframe] 调用 method` 日志（642 行，注入串内）** 同样每次调用打一条，与 908 行构成双倍刷屏；任务书只点名 894（现 908），未动。

3. `var doc = ...` 相邻重复声明两行（1462/1463）——无害冗余，未动。

4. 新增主文档全局：`window.__cardEnvSeq`、`window.__thSeenMethods` —— 均用 `__` 前缀非官方名，不构成"挂官方 API"。

5. card 注入的 jQuery 版本固定为 assets 内版本；若卡自带更高版本且 CDN 可达，卡脚本在 body 后执行会覆盖 `window.$`（与酒馆宿主语义一致），未做版本协调。

6. 旧逻辑 `_needToastr` 要求 `toastrJs` 命中才注 CSS；新逻辑 CSS 无条件 → 体积含 CSS 6,454 B。

7. **generated plugin registrant 七文件在基线前已 dirty**，全程未提交（保持原样）。

8. `yaml.min.js` 含 ES2020 语法（见 9.2），未对老 WebView 做降级。

---

> 报告完。所有数据、命令输出、片段均为本轮施工过程实测原样粘贴，无摘要、无合并、无"输出略"。