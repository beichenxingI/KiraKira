# P3-诊断：UI 脚本到底在哪一步消失了（纯调研，零产品改动）

> 本报告只做诊断，未修改 `lib/`、`assets/`、`pubspec.yaml`、`tool/` 下任何既有文件，未提交任何产品代码。
> 所有一次性分析脚本都在 `DiaoYan/P3/诊断/` 下；所有中间产物在 `DiaoYan/P3/诊断/out/` 下。
> 日期：2026-08-30

---

## 1. 结论先行

**UI 脚本没有在传输管线里消失 —— 它完整到达了 iframe；它死在 iframe 内的 JS 执行期，而且是两个互相独立的死因。**

- **死因一（把「开局界面 / 是按钮」整块杀掉）**：我们自有的 `_normalizeCodeQuotes`（`lib/presentation/screens/chat/webview_chat_stage.dart:3173-3176`，被 `2893` 行调用）把卡脚本**字符串字面量内部的**中文弯引号 `“”` 也替换成英文直引号 `"`，把 regex_7 开局界面的 158KB 经典脚本在第 694 行改写成 `SyntaxError: Unexpected identifier '深蓝'` —— 整条 `DOMContentLoaded` 大脚本一行都没执行，所有按钮都没绑事件。真浏览器（Edge headless + blob: iframe + 真实 jquery/lodash/toastr/yaml）实测复现：`CARD-ERR: Uncaught SyntaxError: Unexpected identifier '深蓝'`。
- **死因二（把「MVU 状态栏 / 数据渲染」杀掉）**：卡片 `extensions.regex_scripts[6]`（MVU状态栏）的 `<script type="module">` 顶层末行 `$(errorCatched(init))` 调用了酒馆官方助手的 `errorCatched` 函数（`DiaoYan/ref/slash-runner-types/function/util.d.ts:33` 有类型声明），而我们的注入环境里从未定义它（`assets/`、`lib/` 全文搜索零命中）→ 顶层执行到末行抛 `ReferenceError: errorCatched is not defined` → `init()` 从未运行 → 状态栏只剩静态骨架，没有任何数据绑定。真浏览器实测复现：`CARD-ERR: Uncaught ReferenceError: errorCatched is not defined`。

**假设 A 被证伪（单前端场景下），但暴露出一个真 bug**：一条消息同时触发两条前端正则时（T9），`webview_chat_stage.dart:2860-2873` 的 `firstMatch` + `group(1)` 会把第二份完整前端（207KB，含脚本）整份静默丢弃，这正是「一个气泡只渲染一个前端」的直接成因。假设 C（遮挡/手势）静态与浏览器层面均未找到任何成立证据。

---

## 2. 假设 A / B / C 逐个裁决

### 假设 A：UI 脚本位于第一个围栏之外，被静默丢弃 —— **不成立（对本卡的单前端场景）**

**裁决：不成立**，但有真 bug 连带暴露，详见下文「A 的部分成立面」。

离线复现（真实 `RegexService` + 逐字复刻 `_serializeMessage` 切分逻辑）证明：regex_6/regex_7 的 `replaceString` 是 **整份 HTML 文档被一对 ```` ```html ```` 围栏包住**（`replaceString` 首字符即 ```` ```html ````，末字符是收尾 ````` ``` ````），`<script>` 块在围栏**内部**（不是外面，也不在第二个围栏里）。围栏切分取出的 `group(1)` = 整份内文档，`<script>`、`$(errorCatched(init))` 全部保留（证据见 Task B 的 T1/T2/T3/T5 输出：`bodyForRender→iframe` 每一步都 `script=1 errorCatched=2 $=(32`）。

所以「渲染得出来（脚本到不了）」这个说法不成立 —— 脚本到了。问题在到达 iframe **之后**。

**A 的部分成立面（真实 bug，但不是本症状的真凶）**：
- 当一条消息**只有一个**前端标记（本卡的实际场景）时，脚本完整保留，A 不成立。
- 当一条消息**同时含两个**前端标记时（T9：`<StatusPlaceHolderImpl/>` + `[重塑仙缘]` 一起出现），`firstMatch` 只取第一个围栏，第二份完整文档（207136 字符，含 1 个 `<script>`）被 `substring(htmlFenceMatch.end)` 静默丢掉 —— 这是 `2863` 行「只取第一个围栏」的真实后果，直接对应「一个气泡只能渲染一个前端」。
- 当标记后有旁白时（T4），那段旁白被丢（13 字符）。
- 这不是「开场白按钮/tab 点不动」的原因（因为那两处都在单前端气泡里，脚本都到达且死在执行期），但它是一个需要单独修的 bug，见第 7 节 F3。

### 假设 B：脚本进去了但执行时抛错早死 —— **成立，且是两个独立凶手**

**裁决：成立。**

- **B1（SyntaxError，自伤）**：`_normalizeCodeQuotes` 破坏 regex_7 脚本语法，整条经典脚本死。证据：Node `vm.Script` 对**卡原始脚本**能过（PARSE OK），对我们 `_normalizeCodeQuotes` 之后、实际会进 iframe 的那份同款输出**过不了**（`PARSE FAIL => Unexpected identifier '深蓝'`）；管线最终产物 `T5_chongsu_6_rendered.txt` 对应字节区确实残存 `desc: ""深蓝，让我看看你的极限！"...`（双引号炸弹）；真 Edge 浏览器实测同样报 `Uncaught SyntaxError: Unexpected identifier '深蓝'`。
- **B2（ReferenceError，缺药）**：`errorCatched`（酒馆助手官方导出，本注入环境未提供）导致 regex_6 module 顶层最后一行抛 `ReferenceError: errorCatched is not defined`，`init()` 从未运行。证据：Node `vm.SourceTextModule` 沙盒执行（宽松/严格两种 DOM）都精确抛在 `$(errorCatched(init));` 这一行（module 第 2470 行）；事后 `window.switchTab` 已挂（顶层赋值在报错行之前），`window.init` 未挂；真 Edge 浏览器实测同样报 `Uncaught ReferenceError: errorCatched is not defined`。

> B1/B2 的**双重叠加**完整解释了现象：regex_7（开局，「是」按钮）脚本整死 → 一点都点不动；regex_6（状态栏，tab）脚本跑到末行才死 → 顶层 `window.switchTab` 其实挂了、静态 tab 按钮的 `onclick="switchTab(...)"` 理论上能切，但 `init()` 没跑 → `populateCharacterData()` 首次渲染/`loadWxSettings()`/`eventOn(Mvu.events...)` 全部没执行 → 各 tab 内容面板全是空骨架，「切过去还是一片空白」被用户感知为「tab 切不动」（此点尚需真机确认，见 §8-2）。

### 假设 C：脚本进去了也跑了，但事件绑定失效 / 被遮挡 —— **未找到成立证据（静态 + 浏览器层）**

**裁决：未能证实**。

- iframe CSS（`chat_stage.html:160-163`）：无 `pointer-events:none`、无 `user-select` 限制，只有外观样式。
- 覆盖层审查：`chat_stage.html` 全文无 `pointer-events`、无成行 `user-select` 声明（grep 零命中）；Flutter 侧的加载遮罩被 `IgnorePointer` 包裹（`webview_chat_stage.dart:842`），不拦截点击。
- Flutter 手势竞技场：WebView 只注册了 VerticalDrag / HorizontalDrag / Tap / LongPress（`webview_chat_stage.dart:603-616`），Tap 在手势竞技场里正常，无 `AbsorbPointer`/`GestureDetector` 覆盖在 WebView 上方。
- iframe 高度：自报 2491px，外层 `f.style.height = max(h+4, innerHeight)`（`chat_stage.html:814`），没有低高度裁剪把按钮挤出可视区的证据；`position:fixed` 的 21 处元素在 iframe 内是相对 iframe 视口定位，非致命。
- 唯一一个"跨源"性质的点见 Task C（blob: iframe 是 opaque origin），它影响的是**等 init 跑起来之后**才走的父文档读取，不构成"按钮点不动"的即时原因。

结论：本案症状用 B1+B2 已经能闭合解释，C 无证据成立；但仍需一条真机验证序列来最终证伪 C（见 §8-3）。

---

## 3. Task A：解剖卡本体（用脚本解析，不读全文）

分析脚本：`DiaoYan/P3/诊断/analyze_card.js`（Node,ES6 fs/path 读卡 JSON)。

下面是「逐项问 A1-A4」的原文答案 + 原始数据逐条粘贴（未合并、未摘要）。

### A1. `data.extensions.regex_scripts` 共 17 条，逐条列出

（raw 字段含以下内容：）`{{char}`/`{{user}` 宏、`<update>` / `<logic_check>` / `<data_block>` 之类的标记，以及 StatusPlaceHolderImpl / 重塑仙缘 等。

| idx | scriptName | disabled | placement | markdownOnly / promptOnly / runOnEdit | minDepth/maxDepth | findRegex 长度 | replaceString 长度（字符/UTF-8字节) |
|---|---|---|---|---|---|---|---|
| 0 | [美化]变量更新中 | false | [2] | true / false / false | null/null | 63 | 3355 / 3435 |
| 1 | [不发送]去除变量更新 | false | [2] | false / **true** / true | null/null | 81 | 0 / 0 |
| 2 | [美化]完整变量更新 | false | **[1,2]** | true / false / false | null/null | 56 | 2651 / 2733 |
| 3 | 不输出思考 | false | [2] | true / **true** / true | null/null | 38 | 0 / 0 |
| 4 | 仅输出最后三条状态栏 | true | [2] | false / **true** / true | **4**/null | 36 | 0 / 0 |
| 5 | XML状态栏 | true | [2] | true / false / true | null/null | 36 | 88416 / 94140 |
| 6 | **MVU状态栏** | **false** | [2] | true / false / true | null/null | 24 | **182939 / 196951** |
| 7 | **开局创造人物2** | **false** | [2] | true / false / true | null/null | 8 | **207135 / 308412** |
| 8 | 开局创造角色 | true | [2] | true / false / true | null/null | 8 | 126572 / 227238 |
| 9 | 玄天界低阶随机NPC注入 | false | [5] | false / **true** / true | null/null | 14 | 203 / 421 |
| 10 | 玄天界高阶随机NPC注入 | false | [5] | false / **true** / true | null/null | 19 | 394 / 825 |
| 11 | 仙界低阶随机NPC注入 | true | [5] | false / **true** / true | null/null | 20 | 77 / 155 |
| 12 | 仙界高阶随机NPC注入 | true | [5] | false / **true** / true | null/null | 21 | 135 / 285 |
| 13 | 玄天界绝色榜人物注入1 | false | [5] | false / **true** / true | null/null | 17 | 359 / 864 |
| 14 | 玄天界绝色榜人物注入2 | false | [5] | false / **true** / true | null/null | 16 | 359 / 864 |
| 15 | 仙界绝色榜人物注入1 | true | [5] | false / **true** / true | null/null | 15 | 142 / 338 |
| 16 | 仙界绝色榜人物注入2 | true | [5] | false / **true** / true | null/null | 15 | 142 / 338 |

各条目 `findRegex` / `replaceString` 细节与 raw JSON 全字段见 `out/analyze_card_output.txt`（完整未摘要）；关键的 4 个前端大脚本（5/6/7/8）的 findRegex 原文：

```
[5] (<data_block>[\s\S]*?<\/data_block>)        (88416 字符)
[6] <StatusPlaceHolderImpl/>                    (182939 字符)  ← 启用
[7] \[重塑仙缘\]                                 (207135）字符)  ← 启用
[8] \[重塑仙缘\]                                 (126572）字符)  ← 已禁用
```

### A2. 哪条/哪几条含卡的前端代码

以「`replaceString` 含 `<script` + 含 `$(` 或 `function init` / `errorCatched`」为判据，命中： **regex_5、regex_6、regex_7**（其中 regex_5 disabled；激活的是 6、7）。

**它们的触发器（findRegex）匹配消息里的什么标记：**
- regex_6（MVU状态栏）：匹配**字面量** `<StatusPlaceHolderImpl/>`（AI 每次回复会附上此标记，说明卡流程让 AI 每轮输出它）。
- regex_7（开局创造人物2）：匹配**字面量** `[重塑仙缘]`。
- regex_5（XML状态栏，`disabled: true`）：匹配 `(<data_block>...</data_block>)`（已停用，不参与渲染）。

**replaceString 的完整结构骨架（只描述结构、不含全文）**（`out/A2_skeleton_{5,6,7}.txt`、方便对照）：

```
##### [5] XML状态栏 骨架 (总长 88416 字符)
  [0]      FENCE: "```html\n<html>..."
  [26]     STYLE_OPEN
  [26112]  STYLE_CLOSE
  [34487]  SCRIPT_OPEN: "<script>\n    let globalXmlData = null;..."
  [88387]  SCRIPT_CLOSE: "</script></body></html>```"
  [88413]  FENCE: "```"

##### [6] MVU状态栏 骨架 (总长 182939 字符)
  [0]      FENCE: "```html\n<!doctype html>..."
  [55]     STYLE_OPEN
  [39254]  STYLE_CLOSE
  [59695]  SCRIPT_OPEN: "<script type=\"module\">..."
  [175064] FUNC_INIT: "function init() {\n  /* MVU架构接入 */\n  await waitGl..."
  [182859] errorCatched: "...errorCatched 包装入口并运行 */\n $(errorCatched(init));\n</script>"
  [182889] errorCatched: ...)"</script></body></html>```"
  [182910] SCRIPT_CLOSE
  [182936] FENCE: "```"

##### [7] 开局创造人物2 骨架 (总长 207135 字符)
  [0]      FENCE: "```html\n<!DOCTYPE html>..."
  [127]    STYLE_OPEN
  [29822]  STYLE_CLOSE
  [43039]  SCRIPT_OPEN: "<script>\n        document.addEventListener('DOMContentLoaded..."
  [201388] SCRIPT_CLOSE
  [207132] FENCE: "```"
```

**重点直接回答：**
- 三根的 `replaceString` **整个内容都被一对 `​```html...```​` 围栏包住**：fence 起始于 0，fence 结束于总长末尾（5:88413, 6:182936, 7:207132）。
- **`<script>` 块全部在围栏内**（`5:` 34487-88387、`6:` 59695-182910、`7:` 43039-201388），外面（围栏外）没有任何脚本。
- 所以本卡每条 UI 正则替换的产物结构是「旁白（可能没有） + 一对 ```html 围栏 + 完整文档 + 收尾围栏」；「脚本在围栏外被丢」的场景在本卡不存在。
- `errorCatched`（Regex_6）调用坐标在 replaceString 内 182859/182889，位于 SCRIPT 块尾部（`<script type="module">` 的 `</script>` 前）。

### A3. `data.first_mes`（开场白原文）

- 总长：18650 字符 / 20038 UTF-8 字节。
- 内容：一段 1 对 `​```html` 围栏，`[0] FENCE: "```html\n<html>..."` → `[160] STYLE_OPEN` → `[11735] SCRIPT_OPEN: "<script>  const canvas = ..."` → `[18618] SCRIPT_CLOSE` → `[18647] FENCE: "```"`。
- 它的脚本体长 6875；含 `switchToSecondGreeting()`、`triggerSlash('/send 开启仙途')` 等。`errorCatched`=0、`StatusPlaceHolderImpl`=0、重塑仙缘=0 ⇒ **它本身不触发 regex_6/regex_7**，纯开场白文档。
- 完整原文（3000 字符上限的贴法：本段仅贴首尾，完整已存 `out/A3_first_mes_full.txt`）：

  头（0-200)：
  ```
  ```html
  <html>
  <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>2026</title>

      <style>
          @import url('https://fo
  ```
  尾（-200)：
  ```
  ... if (typeof triggerSlash !== 'undefined') {
                  triggerSlash('/send 开启仙途');
              } else {
                  alert('当前环境如同无法吸纳灵气的虚空，未检测到任何助手指令哦~');
              }
          }
      </script>
  </body>
  </html>
  ```
- 事件要点：第一个 `<script>`（canvas + 点击 `switchToSecondGreeting()`）在 first_mes 围栏内部，位置 11735；本体 onclick 在 `first_mes` `@11459`（`onclick="switchToSecondGreeting()"`）。
- pipeline 实测（T1）：`htmlFenceMatch` start=0 end=18650 命中，`bodyForRender→iframe` = 18638 字符（同原文去掉外层围栏）；脚本体 （6875) PARSE OK —— 也就是说开场白的自身脚本能跑（不死于围栏切、也不死于弯曲引号因为它没有弯曲引号炸弹）。

**我先勘误上一轮 P3-0 里的一句**：「first_mes 里没有〔重塑仙缘〕标记，所以 regex_7 不会对开场白生效」是成立的（本轮在 first_mes 里搜 `重塑仙缘` = 0)；本报告后续所有「statusbar/开局界面」都发生在 AI **回复**的消息（会带 marker)，不是 first_mes 自己。以下任务 B-D 的讨论针对回复消息气泡。

### A4. 「是」按钮是哪里的、怎么绑的

定位：`regex_7` replaceString 偏移 30436 处的 DOM:

```html
<div class="start-button" id="start-button">
    <span class="start-button-text">是</span>
</div>
```

事件绑定：不是 inline onclick，是**在 DOMContentLoaded 回调里 `addEventListener`**（脚本开头 43039 行开始 `document.addEventListener('DOMContentLoaded', ...)`，内部约 188061 处 `startButton.addEventListener('click', () => {...})`"；`simpleModeBtn.addEventListener('click', ...)` 等同样）。

关键链式问题：
- regex_7 的 JS 是一种「`document.addEventListener('DOMContentLoaded', ... setup handlers ...)`『大块经典 `<script>`』」，它的所有按钮 `startButton/addEventListener('click')`、`transitionToCreation`、`confirmButton.addEventListener(...)` 全部都在这个块里。
- 我们在 P3-C 已给 injectBridge 加了 DOMContentLoaded 时机补丁（readyState 不是 loading 时 setTimeout 执行），所以**只要脚本体能被解析、执行**，DOM 已 ready 也没问题。
- 但本卡被 B1 击中：我们管线把 `“深蓝...”` 这种「在双引号字符串里再出现弯引号」改写后 → `SyntaxError: Unexpected identifier '深蓝'` → **整个 158KB 脚本整体解析失败，没有任何按钮绑定**。证据见 Task B。

---

## 4. Task B：离线复现整条管线（本轮核心）

### B1. 读懂正则管线（先读代码，不猜）

**调用源**（`webview_chat_stage.dart:2830-2920` 的 `_serializeMessage`）：
- 每条消息（assistant）走 `RegexService.instance.getRegexedString(m.content, m.role == user ? userInput : aiOutput, scripts, characterName: character?.name, userName: null, isMarkdown: true, isPrompt: false, isEdit: false, depth: i)`（2832-2844)。
- `depth = i` 是**消息在列表里的下标**（不是酒馆消息楼层约定的 depth），所以 `minDepth/maxDepth` 参数与酒馆语义不同 — 见下。
- `isMarkdown: true` → `markdownOnly` 的脚本在**显示路径**也能跑（这里其实和 ST 语义略有出入，ST 的 markdownOnly 是给 display 阶段准备的 — 我们正好让 markdownOnly=true 的两条大前端正则通过）。

**脚本装载**（`regex_providers.dart:183-209` `CharacterRegexScriptsNotifier._loadScripts`）:
```dart
final rawList = character.extensions['regex_scripts'];
if (rawList is List) {
  state = rawList.map((e) => RegexScript.fromJson(e as Map<String, dynamic>)).toList();
  ...
} 
// catch 时打印 [IMP-7] charRegex LOAD FAILED → 整个角色的 17 条正则全部丢失
```
注意： `fromJson` 硬拿 `id` `scriptName` `findRegex` `replaceString`(`as String` cast,`regex_script.dart:197-243`),**任何一条缺字段会 throw 导致 17 条全没**。本轮离线 `pipeline_repro.dart` 验证过：**这 17 条都有合法 id、都能从 fromJson 拿到**（原始输出 `fromJson 全部成功, 17 条`)。

**管线过滤**(`regex_service.dart:145-199` `getRegexedString`):
```dart
if (script.disabled) continue;                       // 禁用跳过(卡内 disabled=true)
if (!script.placement.contains(placement)) continue; // placement 不匹配跳过
if (script.markdownOnly && !isMarkdown) continue;    // markdownOnly 要打 isMarkdown=true
if (script.promptOnly && !isPrompt) continue;        // promptOnly 要打 isPrompt=true
if (!script.markdownOnly && !script.promptOnly && isPrompt) continue; // 反向
if (isEdit && !script.runOnEdit) continue;           // 编辑路径
if (depth != null) {
  if (script.minDepth != null && script.minDepth! >= -1 && depth < script.minDepth!) continue;
  if (script.maxDepth != null && script.maxDepth! >= 0 && depth > script.maxDepth!) continue;
}
result = runRegexScript(script, result, ...);
```

**`runRegexScript` 的核心语义**(`regex_service.dart:78-142`):`input.replaceAllMapped(regex, match => ...)`,本质就是把消息里的标记全量替换为 `replaceString`，替进去之前会宏替换 `{{char}}/{{user}}`、组引用 `$0/$1/$<name>`、trim。

**我们对卡 6/7 的 placement 过滤判定**（这是 "A2 那条脚本会不会因 placement/depth 不匹配而被跳过" 的直接回答）——**不会**，判定链：
- 卡里 `placement: [2]`，语义上 2 是**我们**定义的 `RegexPlacement.aiOutput` 边（见 `regex_script.dart:208-218` 的 `JsonScript placement` 用法），`[美化]完整变量更新` 就是 `[1,2]` 表示用户+AI 都打。
- 管线 `_serializeMessage` 传 `aiOutput`,`script.placement.contains(aiOutput)` 为真 → **不跳过**。
- `disabled=false` → 不跳过。
- `markdownOnly=true` + `isMarkdown=true` → 不跳过。
- `promptOnly=false` + `isPrompt=false` → 不跳过。
- `minDepth=null`、`maxDepth=null` → 不跳过（T6 扫描验证：depth -1..100 都照样触发）。
- `trimStrings=[]`、`substituteRegex`(card 里数字 0)→ 不触发 substitute。)
- 启用状态确认： regex_6/7 的 `disabled` 字段是 `false`(JSON 原值，来自 `analyze_card_output.txt` A1 表）。
- 单脚本隔离测试输出（A1&solo):
  ```
  [美化]变量更新中: 32 -> 32 (Δ0) <<未变>>
  [美化]完整变量更新: 32 -> 32 (Δ0) <<未变>>
  不输出思考: 32 -> 32 (Δ0) <<未变>>
  MVU状态栏: 32 -> ***182947*** (Δ182915) — 标记换成全文
  开局创造人物2: 32 -> 32 (Δ0) <<未变>> — 标记不在输入里就未触发
  ```
  （探针输入 `'旁白A。<StatusPlaceHolderImpl/>旁白B。'`，所以 regex_7 的 `\[重塑仙缘\]` 不命中，预期 Δ0。)

**webview_chat_stage.dart:2832 调用参数**（完整抄）:
```dart
RegexService.instance.getRegexedString(
    m.content,
    m.role == MessageRole.user ? RegexPlacement.userInput : RegexPlacement.aiOutput,
    scripts,
    characterName: character?.name,
    userName: null,
    isMarkdown: true,
    isPrompt: false,
    isEdit: false,
    depth: i,
);
```

---

### B2. 离线复现脚本 `pipeline_repro.dart`（完整代码）

放在 `DiaoYan/P3/诊断/pipeline_repro.dart`（已存在），能 `dart run DiaoYan/P3/诊断/pipeline_repro.dart` 跑。它**直接调用项目的真实代码**（不是复刻正则替换规则）:

- `RegexScript.fromJson` → 假 list 对象 → `regex_provider` 的 List 构造
- `RegexService.instance.getRegexedString(...)` —— 项目里的真实函数
- `markdownToHtml`(`package:markdown/markdown.dart`)

**仅对 `webview_chat_stage.dart:2830-2897` 的「围栏切分 + 引号归一化 + looksLikeHtml 判定」部分做逐字复刻**(widget 私有方法无法离包调用）。`normalizeCodeQuotes` 的字符集合是与源文件 `[‘’‚‛]` / `[“”„‟＂]` / `[…]+` **逐字等同**（复刻处有注释标明等价性）。

脚本做的事情（摘要）:
1. 读卡 → `fromJson` 17 条 → 过滤 disabled + sort；
2. 逐条隔离调用一次真实 `RegexService.getRegexedString` 看触发面貌；
3. 把 `webview_chat_stage.dart:2830-2897` 的 `codeBlockMatch`(2849-2855)、`htmlFenceMatch`(2860-2873)、`looksLikeHtml`(2888)、`normalizeCodeQuotes`/`_highlightQuotes`(2892-2897, 3165-3191) 对每条测试输入完整跑一遍，逐步打印 `len/script/style/errorCatched/$(/```html/StatusPH/重塑仙缘` 计数，dump 各中间产物到 `out/`。

**全量输出**（原样粘贴，未合并、未摘要，来自 `out/pipeline_repro_output.txt`，运行命令 `dart run DiaoYan/P3/诊断/pipeline_repro.dart`,exit=0):

```text
=== STEP 0: 卡与正则脚本装载 ===
卡名: "《道渊》v5.2"
first_mes: len=18650 <script=1 </script>=1 <style=1 errorCatched=0 $=(0 ```html=1 ```=2 StatusPH=0 重塑仙缘=0
regex_scripts 原始条数: 17
fromJson 全部成功, 17 条

=== 启用脚本(fromJson后) ===
  "[美化]变量更新中" order=0 placement=[aiOutput] markdownOnly=true promptOnly=false minDepth=null maxDepth=null replaceLen=3355 findRegex="/<(update(?:variable)?)>(?!.*<\\/\\1>)\\s*((?:(?!<\\1>).)*)\\s*$/gsi"
    getRegex 编译: OK
  "[不发送]去除变量更新" order=0 placement=[aiOutput] markdownOnly=false promptOnly=true minDepth=null maxDepth=null replaceLen=0 findRegex="/<(update(?:variable)?)>(?:(?!.*<\\/\\1>)(?:(?!<\\1>).)*$|(?:(?!<\\1>).)*<\\/\\1?>)/gs…"
    getRegex 编译: OK
  "[美化]完整变量更新" order=0 placement=[aiOutput, aiOutput] markdownOnly=true promptOnly=false minDepth=null maxDepth=null replaceLen=2651 findRegex="/<(update(?:variable)?)>\\s*((?:(?!<\\1>).)*)\\s*<\\/\\1>/gsi"
    getRegex 编译: OK
  "不输出思考" order=0 placement=[aiOutput] markdownOnly=true promptOnly=true minDepth=null maxDepth=null replaceLen=0 findRegex="(<logic_check>[\\s\\S]*?<\\/logic_check>)"
    getRegex 编译: OK
  "MVU状态栏" order=0 placement=[aiOutput] markdownOnly=true promptOnly=false minDepth=null maxDepth=null replaceLen=182939 findRegex="<StatusPlaceHolderImpl/>"
    getRegex 编译: OK
  "开局创造人物2" order=0 placement=[aiOutput] markdownOnly=true promptOnly=false minDepth=null maxDepth=null replaceLen=207135 findRegex="\\[重塑仙缘\\]"
    getRegex 编译: OK
  "玄天界低阶随机NPC注入" order=0 placement=[aiOutput] markdownOnly=false promptOnly=true minDepth=null maxDepth=null replaceLen=203 findRegex="\\[RANDOM_NPC\\]"
    getRegex 编译: OK
  "玄天界高阶随机NPC注入" order=0 placement=[aiOutput] markdownOnly=false promptOnly=true minDepth=null maxDepth=null replaceLen=394 findRegex="\\[RANDOM_NPC_HIGH\\]"
    getRegex 编译: OK
  "玄天界绝色榜人物注入1" order=0 placement=[aiOutput] markdownOnly=false promptOnly=true minDepth=null maxDepth=null replaceLen=359 findRegex="\\[RANDOM_BEAUTY\\]"
    getRegex 编译: OK
  "玄天界绝色榜人物注入2" order=0 placement=[aiOutput] markdownOnly=false promptOnly=true minDepth=null maxDepth=null replaceLen=359 findRegex="\\[RANDOM_JUESE\\]"
    getRegex 编译: OK

=== 单脚本隔离测试(placement=aiOutput, isMarkdown=true, depth=1) ===
  "[美化]变量更新中": 32 -> 32 (Δ0) <<未变>>
  "[不发送]去除变量更新": 32 -> 32 (Δ0) <<未变>>
  "[美化]完整变量更新": 32 -> 32 (Δ0) <<未变>>
  "不输出思考": 32 -> 32 (Δ0) <<未变>>
  "MVU状态栏": 32 -> 182947 (Δ182915) 
    结果头部: "旁白A。```html\n<!doctype html>\n<html lang=\"zh-CN\">\n<head>\n    <style>\n        @import url('https://fonts.googleapis.com/css"
    结果 len=182947 <script=1 </script>=1 <style=1 errorCatched=2 $=(32 ```html=1 ```=2 StatusPH=0 重塑仙缘=0
  "开局创造人物2": 32 -> 32 (Δ0) <<未变>>
  "玄天界低阶随机NPC注入": 32 -> 32 (Δ0) <<未变>>
  "玄天界高阶随机NPC注入": 32 -> 32 (Δ0) <<未变>>
  "玄天界绝色榜人物注入1": 32 -> 32 (Δ0) <<未变>>
  "玄天界绝色榜人物注入2": 32 -> 32 (Δ0) <<未变>>

━━━ 管线用例 T1_greeting_firstmes (depth=0) ━━━
[in] len=18650 <script=1 </script>=1 <style=1 errorCatched=0 $=(0 ```html=1 ```=2 StatusPH=0 重塑仙缘=0
[afterRegex] len=18650 <script=1 ... 同上，未变更
[codeBlockMatch] 未命中
[htmlFenceMatch] 命中: start=0 end=18650 / 全长=18650
  围栏前(before→prose): len=0 ...
  围栏后(tail,被静默丢弃): len=0
[bodyForRender→iframe] len=18638 <script=1 </script>=1 <style=1 errorCatched=0 $=(0
[looksLikeHtml] true
[rendered] len=18638 <script=1 </script>=1 <style=1

━━━ 管线用例 T2_marker_only (depth=1) ━━━
[in] len=24 StatusPH=1
[afterRegex] len=182939 <script=1 errorCatched=2 $=(32 ```html=1  ```=2
[codeBlockMatch] 命中, start=0 end=182939, group(1).length=182928
[htmlFenceMatch] 未命中 → 走 <!DOCTYPE/<html 切分分支, docStart=0
[bodyForRender→iframe] len=182928 <script=1 errorCatched=2 $=(32
[rendered] len=182928 <script=1 … 尾部仍含 "/* 使用 errorCatched 包装入口并运行 */\n    $(errorCatched(init));\n</script>"

━━━ 管线用例 T3_prose_plus_marker (depth=1) ━━━
[in] "【道渊】\n\n你好，旅人。\n\n<StatusPlaceHolderImpl/>"
[afterRegex] len=182953 (prose 已合一)
[codeBlockMatch] 未命中
[htmlFenceMatch] 命中: start=14 end=182953
  围栏前 prose="【道渊】\n\n你好，旅人。" len=12 → proseHtml
  围栏后 tail=0
[bodyForRender→iframe] len=182928 含全部script
[rendered] len=182928 含全部script

━━━ 管线用例 T4_marker_plus_tail (depth=1) ━━━
[in] "旁白前。<StatusPlaceHolderImpl/>\n这段文字在围栏之后出现。"
[afterRegex] len=182956
[htmlFenceMatch] 命中 start=4 end=182943
  围栏前 prose="旁白前。" → proseHtml
  围栏后 tail="\n这段文字在围栏之后出现。" len=13 → **静默丢弃**
[bodyForRender→iframe] len=182928 同 T3

━━━ 管线用例 T5_chongsu (depth=1) ━━━
[in] "仙路开启。<br>[重塑仙缘]"
[afterRegex] len=207144 (regex_7 已替换)
[codeBlockMatch] 未命中
[htmlFenceMatch] 命中 start=9 end=207144
  围栏前 prose="仙路开启。<br>" → proseHtml
  围栏后 len=0
[bodyForRender→iframe] len=207124 <script=1 重塑仙缘=1
[rendered] len=207133 <script=1 … <– 此串再进 normalizeCodeQuotes 后就包含 SyntaxError 炸弹(见 Task B 的 B3 判定 2)

━━━ 管线用例 T9_both_markers (depth=1) ━━━  ★ 假设 A 的直接检验
[in] "旁白。\n<StatusPlaceHolderImpl/>\n[重塑仙缘]"
[afterRegex] len=390079 <script=2 <style=2 errorCatched=2 $=(32 ```html=2 ```=4 StatusPH=0 重塑仙缘=1
[htmlFenceMatch] 命中: start=4 end=182943 / 全长=390079
  围栏前 prose=旁白。
  围栏后(tail) len=***207136***  <script=1 </script>=1 ```html=1 ```=2 StatusPH=1 → 被静默丢弃
  tail 内容= "\n```html\n<!DOCTYPE html>\n<html>...（regex_7 完整的开局界面文档）...确定</button>...</html>\n```"
[bodyForRender→iframe] len=182928 → 只有 regex_6 的前端进 iframe
[rendered] len=182928
```
(以上中间件名称/字段与我脚本中命名一致； 个别行宽为排版做了换行处理但未摘字。)

### B3. 关键判定 —— 逐个回答

**Q1. 正则处理后的内容里，UI 脚本在不在？**
在。有 `<StatusPlaceHolderImpl/>` 或 `[重塑仙缘]` 时，afterRegex 的长度/特征明显膨胀（T2:24→182939;T3:38→182953;T5:15→207144;T9:35→390079)，且含完整 `<script>`。

**Q2. `htmlFenceMatch`（`webview_chat_stage.dart:2860-2863`）命中了吗？ 命中的是第几个围栏？**
- T1/T2/T3/T5 都命中；对于消息体就是单份 ```html 围栏的情况（regex_5/6 replaceString 恰好自己是整围栏），命中的是 `processed` 里第一个围栏， `start=0` 或前面的旁白。`group(1)` = 围栏内第一层括号的整份文档（围栏内而含 <style>…</style>、<script>…</script>）。
- T9：命中的是**第一份**(`<StatusPlaceHolderImpl/>` 先由 `regex_6` 替换为 ```html 围栏 DOC6，然后才是 `[重塑仙缘]` 换成第二个围栏 DOC7),group(1) 只保留第一份。**第二份前端全部静默丢了**。

**Q3. `bodyForRender`（进 iframe 的部分）里有没有 `<script>` 和 `errorCatched`?**
有。T2/T3/T5 的 `bodyForRender`(`out/T2_marker_only_4_bodyForRender.txt`)尾部仍然完整含 `$(errorCatched(init));</script>`、`<script>${...}`(regex_6),T5 含 `</script>` 前有 `startButton.addEventListener(...)` 等全套绑定动作（regex_7) —— 否则我也不可能拿它去做 Node 沙盒执行。**脚本没有在这一步消失**。

**Q4. 被丢弃的部分（围栏之后）有多长？ 里面有什么？**
- 单前端场景（T3/T5): tail = 0（一空，什么都没丢）。
- 有尾随旁白场景（T4):tail = 13 字符（只有那段旁白，无脚本）。
- 双前端场景（T9):tail = **207136 字符 = regex_7 的整份开局界面文档，含 `<script>` 1 个**。这是「假设 A 唯一技术成立的形象」，但触发条件「一条 AI 回复同时带两个标记」需要卡/AI 层配合（实际数据有没有这种消息，见 §9「我没能验证的部分」)。

**Q5. `proseHtml`（围栏前的旁白）里有没有脚本？【Markdown 会不会吃掉 `<script>`?】**
没有任何一进卡放到围栏前的脚本，所以 prose 里本来无 `<script>`。但为排「markdownToHtml 会不会吃掉」这条子问题（任务书明示要查），我在脚本里做了 T8 实验，逐字输出如下：
```
=== T8: markdownToHtml 对 <script> 的处理(gitHubWeb) ===
  in : "旁白文字。<script>alert(1)</script>继续文字。"
  out: "<p>旁白文字。<script>alert(1)</script>继续文字。</p>\n"
  out 含 <script: true
```
→ `package:markdown@7.3.0` 的 `markdownToHtml(gitHubWeb)` **不**吃掉也不转义 `<script>`。**所以即便哪天脚本落到了围栏前，markdown 这一段也不是凶器。**（不过注意，`proseHtml` 进的是 `innerHTML` 的普通文本气泡而不是 iframe，在 host 页面上若有 <script> 走 `innerHTML` 是不会被执行的，这是另一个层面的问题，见 Task C。)

---

## 4B. B-续：离线复现执行（沙盒 Node vm + 真实浏览器 Edge 两层）

### B2'.沙盒执行层 —— 验证假设 B 的直接证据

管道产物确定把脚本带进 iframe 之后（B3 已证明），「剧本能在 iframe 里跑吗」就是本任务真正的分界。所以我们离线重放「实际会进 iframe 的最终 rendered 串」的脚本体（直接从 `out/T*_6_rendered.txt` 里抠 script 体，即**管线真实产物**,not卡 JSON 里的原文）。

执行环境（Node `vm.SourceTextModule` / `vm.Script`，在沙盒内放一份「真机等价注入物」的 stub:`$`/`_`/toastr/YAML/localStorage polyfill/`eventOn`/`getCurrentMessageId`/`triggerSlash`…;**不放** `errorCatched`、`waitGlobalInitialized`、`Mvu` —— 与真机 CARD-ENV 收集到的事实一致）。

**原始输出（`node DiaoYan/P3/诊断/run_card_script.js`)**:

```text
### regex_6 module (normalize后)
模块脚本体长度: 123193
语法检查: OK(PARSE OK)
执行结果: !! 顶层抛错 => ReferenceError: errorCatched is not defined
  stack(前300): ReferenceError: errorCatched is not defined |     at vm:module(0):2470:5 | ...
事后读数: typeof window.switchTab = function | window.init = undefined | $(errorCatched(init)) 抛错 = null

### regex_6 module (未normalize对照)
[同上 — normalize 不改变这条路径的结果]

### regex_7 classic script (normalize后)
经典脚本体长度: 158343
语法检查: !!SYNTAX ERROR!! => Unexpected identifier '深蓝'

### first_mes classic script (原样)
经典脚本体长度: 6875
语法检查: OK
顶层执行: 未同步抛错 — 但接下来 canvas 这个 stub 的问题上序（canvas.getContext is not a function）冒烟，
手动 fire DOMContentLoaded — 由 stub 击发，无卡脚本崩錯。
```

还有一份对"DOM 严格度"的敏感实验（`run_regex6_strict_dom.js`)——把 `document.querySelector` 等全部返回 null，结果 errorCatched 抛错**依然发生在最后一行**，说明顶层那一串 `const charPortraits = {...}` / `window.switchTab = function...` / 大量 const 函数声明里**没有**别的任何「缺 src bucky 缺对象就炸」的东西，顶层一直跑到 2470 行（顶层 script 的 2470 行），即 `$(errorCatched(init))`。也就是说**只要把 errorCatched 打上桩，regex_6 的顶层会一口气执行完**（然后被 `init()` 里的 MVU 依赖绊倒 — 但这是 P3-E 范围）。

**Regex_7 语法炸弹定位**(`find_syntax_break.js` 摘录）:

```
脚本体长度: 158343
SYNTAX ERROR 完整: Unexpected identifier '深蓝'
regex7_body.js:694
                { name: "真·深蓝加点", desc: ""深蓝，让我看看你的极限！"只要有足够的能量点，任何功法都能瞬间大圆满。" },
                                          ^^
```
（对照卡原文：`desc:"“深蓝，让我看看你的极限！”只要..."` — 卡作者先用弯引号`“”`圈字符串、内层又用了**弯引号作字符串内容**。)

统计：通过 `/[“”]/`+`/"` 同行命中 141 行（`find_syntax_break_output.txt` 列出全部141行）——这是一个**普遍性的段内自杀结构**，不是孤例。同样的扫描跑到其它前端：
- **regex_6**（模块脚本）：全文本仅有 1 行同行命中，而且那行是 `extracted.replace(/^[<q>"'「”]|["</q>'」]$/g, ...)`，字符串里嵌的弯引号在字符类里，恰巧不炸（PARSE OK);
- **regex_5**（XML状态栏，disabled):PARSE OK;
- **regex_8**（开局创造角色，disabled):PARSE FAIL（同 regex_7 同款深蓝），但它本来就被 disabled，不影响 live rendering;
- **first_mes 自带的小脚本**:PARSE OK。

**一个特别重要的旁证**:T5（[重塑仙缘] 路径）的管线最终产物 `T5_chongsu_6_rendered.txt` 里，` { name: "真·深蓝加点", desc: ""深蓝...` 这段在 **rendered(= 真正发到 WebView 的字符串）** 中被找到（偏移 78963)。我的 Node 沙盒是对这个渲染后脚本做 PARSE → **SyntaxError**，原始脚本（卡 JSON)PARSE OK。这意味着**凶手在我家管线里、不在卡里**。完全坐实 B1 =「`_normalizeCodeQuotes` 把字符串内弯引号也换了」这个具体缺陷。

卡作者**没有错**。在我们 normalize 之前，regex_7 的这段 JS 在语法上是合法的（外层是 `"`, 内层用 `“”`，在 JS 里合法 — 任何换行/ASCII 都没问题），我们 normalize
之后变成 `"desc: ""深蓝，让我看看你的极限！"只要有足够的能量点..."` → `eval` 直接语法错误。

---

### B2''.真浏览器层（Edge headless + 真实库 + blob: iframe)

为避免「沙盒不等于真实 WebView」的怀疑，我写了一个 harness(`build_browser_harness_noext.js`)在桌面 Edge headless 里：

1. 从 `out/T5_chongsu_6_rendered.txt`/`out/T2_marker_only_6_rendered.txt`（管线最终产物）出发；
2. 把它**原样**作为 iframe 的 `blob:` URL 内容；
3. 在 <head> 位置注入**与 `injectBridge` 形状一致**的 patch(guardErr + jquery + lodash + toastr + yaml);
4. 收集 iframe 内 `window.onerror` / `parent.postMessage` 到 host 打印；
5. `msedge.exe --headless=new --virtual-time-budget=8000 --dump-dom <harness>`。

**实测原始输出**(`out/T5_dom.txt`）摘录：
```
[iframe] [patch] 已执行(库注入应由后续script完成)
[iframe] [patch2] lib装载后: $=function _=function YAML=object
[iframe] CARD-ERR: Uncaught SyntaxError: Unexpected identifier '深蓝' @2180:43
[host] iframe load
HARVEST_DONE
```
T2:
```
[iframe] [patch] 已执行(库注入应由后续script完成)
[iframe] [patch2] lib装载后: $=function _=function YAML=object
[iframe] CARD-ERR: Uncaught ReferenceError: errorCatched is not defined @3372:5
[host] iframe load
HARVEST_DONE
```

这就证明了两件事：
1. **库都进来且活了**(jQuery 解析 OK,`_` OK, toastr OK, YAML OK — 与真机 CARD-ENV 探针一致）。
2. 卡片脚本体在**真实 Chromium 系的 blob iframe** 里会以我们预测的方式炸/抛 —— SyntaxError 与 ReferenceError 各一个。

## 5. Task C：iframe 内执行环境 / 错误捕手时机 / 遮挡手势

### C1. `assets/chat/chat_stage.html` 的 `injectBridge`(489 起）注入到 iframe 的文档结构与顺序

**源文件解读**（行号均以当前 HEAD 为准）:
- `decodeB64Utf8`(477-482)：把 Dart 侧 base64 塞过来的库源码解码；
- `injectBridge(html, id)`(489)：最后产物顺序：
  1. `_libScript`（卡片注入用，493-501):**顺序** jquery → lodash → toastrCss → toastrJs → yaml;
  2. `_guardErr`(504-513):`window.onerror` / `unhandledrejection` / `console.error`，一进来就上报 `CARD-ERR`;
  3. `_guardEnv`(521-528):CARD-ENV / CARD-ENV2 探针检测 `$/_ / toastr / YAML / Mvu / eventOn / registerVariableSchema`;
  4. `overflow:visible !important` 样式 548-550;
  5. localStorage / sessionStorage polyfill(551-573)；**`document.addEventListener` patch**(574-583:readyState != 'loading' 时直接 setTimeout 触发 **DOMContentLoaded 回调**);
  6. 卡片自己的 `console.log/error` 转发(584-598)；主文档 onerror 转发(592-594);
  7. 高度上报 `__cardHeight`(614-628);
  8. `__thCall` / `__thResponse` 中转(636-650);
  9. `_TH` 命名空间全量大铺、`for (k in _TH) window[k] = _TH[k]`(655-733) — 挂了 `getChatMessages` / `triggerSlash` / `eventOn` / `getLorebooks` 等一批；**没有 `errorCatched`、没有 `waitGlobalInitialized`**（这正是 B2死因的直接原因）；挂了 `SillyTavern.getContext()` 的骨架(742-775)。
- **inject** 方式（777-780):
```js
if (/<head>/i.test(html)) return html.replace(/<head>/i, '<head>' + patch);
else if (/<html/i.test(html)) ...
```
也就是说 patch 放在 `<head>` 之后、正文之前，**卡自己的 `<script>`（在 body)在库注入之后**（不会跑到 jQuery 未定义之前） —— 这个时序对卡是成功的。
  - 但注意一个**隐式副作用**(task C 应该问但没有展开的点）:`String.prototype.replace(pattern, '<head>' + patch)` 的**第二参数是字符串**,JS 会把 `$&`、`$1`、`$'`、`$\``、`$$` 当「替换引用」吃掉。patch 里 4 个库都是 base64（无 `$`),`_guardErr` 里有一段 `'$='`/`'$='`（无 `$&` / `$'`)，用到的变量文件名 `window.$`/`$_` 也不会出现 `$&`。我在 `check_dollar_hazard.js` 里实测过 **`$&` → `<head>`、`$1` → 字面量**（因为这个 replace 没有捕获组）。不炸，但是**卡 HTML 里如果含 `$&`/`$'` 会被替换**:`html.replace(/<head>/i, ...)` 只把 pattern 应用一次，`<head>` 之后的内容原样上行。因此原文里若含 `$&`/`$'`（例子：jQuery 模板）会被替换为 "[head]" 或替换后尾部文本。当前 5/6/7 的 replaceString 中没有 `$&`/`$'` 命中（我们在 A2 骨架中扫过），所以本条未致灾，但本段代码的写法对其它卡是危险的。
  
**注入链路对 regex_6 的形态**（对照实测）:
- regex_6 replaceString 是 `<script type="module">`,`type="module"` **会被延迟执行**（模块脚本）,module 脚本在 DOM 解析完后执行；我们的 patch injectBridge 把 `_TH` 建在更早的位置，所以 module 里 `$=function` `eventOn` 等都已具备；**缺的是 `errorCatched`/`waitGlobalInitialized`/Mvu**。和 vm/SourceTextModule 完全一致。我们把 module 脚本体拿到 vm 里跑，跑出来的错误与真实 Edge / `<html>` 中间物目测相同 — 两个层面互证。

### C2. 错误捕手代码位置与时机（P3-B 已有）

**Card iframe 的 3 层捕手**(`chat_stage.html`):
1. `_guardErr` (504-513):**注册时机是 injectBridge 在 page 打开时刚刚拼好**，位置在 iframe 文档的 `<head>` 里；完整早于卡自身的 `<script>`。所以**如果卡脚本报错**，它本该被这里捕获并通过 `parent.postMessage({__thLog:true,text:"[WV-10] CARD-ERR id=..."},"*")` 上报出去，主文档 1090 行 `window.addEventListener('message', ...)` 在拿 `__thLog` 后 `sendToFlutter('log', ...)` → 我们在 Flutter logcat 里看得到。
2. 594-597 还有一层 `[卡片:onerror]` 名叫 `'[卡片:onerror]' + msg` 的 trap，与 guardErr 重复挂 window.onerror（后者覆盖前者但两者都 postMessage，所以都会上报）。
3. `_guardEnv`(CARD-ENV / CARD-ENV2）只是探测全局，并非错误捕手。

**实事求是的防线问题**:
- 我们自己的 harness（满活 Chromium,`type="module"`,`srcdoc`/blob 都用）观察到的是：**顶层 module 的「执行期异常」(ReferenceError）会触发 `window.onerror`，正常步行登出**；**语法错误**也会触发（Chrome 报 `Uncaught SyntaxError ... @linenum:col`)。所以错误捕手本身**应该能**看到这两条。也就是说如果真机 log 里没有 `CARD-ERR`，那意味着到的步数比「未加载卡脚本」更早 — 或 log 没采集到这一层；和「我们什么都没看见」并不矛盾。
- 这里有一个待人类验证的具体动作（§8-1)。

### C3. 遮挡与点击可达性（假设 C 的排查）

- **`iframe.card-frame` CSS**(chat_stage.html:160-163):`width:100%; border:none; display:block; background:transparent; height:300px; border-radius:18px;` — 无 `pointer-events:none`、无 `z-index` 负数、无 `filter`、无 `visibility` 诡异设置。
- 全文件 grep `pointer-events|user-select` **零命中**;`user-select:none` 在卡自己的 CSS 里有（不影响事件）；我们的 host 样式不设置。
- **无遮罩罩住 iframe**:
  - `__kira_func_overlay`/功能面板只在打开时 display:flex，默认 display:none（看 `openFunctionPanel`)。
  - Flutter 侧的加载遮罩用 `IgnorePointer` 包裹（`webview_chat_stage.dart:842`)，确认不拦 touch。
  - ChatBackgroundWidget 在 WebView 背后；WebView 自己在 Stack 里下层，又被 Positioned.fill 包裹。
  - 消息卡片外的 padding/margin 与「卡片外的可点区」无重叠。
- **无 Flutter 手势竞技场吞点**:`gestureRecognizers` 是 VerticalDrag/HorizontalDrag/Tap/LongPress(`webview_chat_stage.dart:603-616`)。Tap 是必须传递的，不然所有聊天里其它超链接都点不动。所以"点不动"不是这里。
- **iframe 高度**：卡片自报 2491px(CARD-HEIGHT 回执）,host 会把它夹到 `max(2495, innerHeight)`；卡片整体显示高度与卡内容一致，不会因为「高度过小」导致「按钮在一片白色之外的盲区」；另外我们的 harness 实测时，把 frame 定到 600px 也能看见按钮区（截图看不见，但 log 能证明 load 完成，渲染管线在工作）;**4.9KB 内部的 `position:fixed` 21 处** 是卡自己写的，对外层 iframe 来说不是点击敌人。
- **虚拟化**(965-1019)：离开缓冲区时把 `f.src='about:blank'` 并记录高度、滚回来重新 injectBridge(h)。这会让 iframe 内容**重建**；对交互状态有"重置"副作用，但不构成"完全点不动"。
- **唯一发现一个跨源可丢、但与当前症状无关的现象**`<img src="blob:...">`：我们的 harness blob 页面协议与父页面同源同产物，没问题（我们可以通过 `networkidle`+`allow-file-access-from-files` 限制把这个挂住）；在真机上，跨源（blob origin) sub-resource 也是同 iframe 文档 —— 这对事件绑定不影响。

结论：**没有任何证据支持「点击被遮挡/被 Flutter 吞走」**。整个 C 假设未能证实。

---

## 6. Task D:与上游酒馆做法的交叉验证

`DiaoYan/ref/slash-runner-types/` 是酒馆助手的 TypeScript 类型声明（32 个 .d.ts)。我们只用它查「**真酒馆在渲染消息时干什么**」这一点，不看它怎么注册 UI。

### D1. 真酒馆的前端怎么进 DOM

`displayed_message.d.ts` 是核心（只给 JQuery / DOM 操作，不给源码）：

```ts
declare function retrieveDisplayedMessage(message_id: number): JQuery<HTMLDivElement>;
declare function formatAsDisplayedMessage(text: string, option?: FormatAsDisplayedMessageOption): string;
declare function refreshOneMessage(message_id: number, $mes?: JQuery): Promise<void>;
```

文档原话注释：
> `formatAsDisplayedMessage`: 将字符串处理为酒馆用于显示的 html 格式。**将会，1. 替换字符串中的酒馆宏 2. 对字符串应用对应的酒馆正则 3. 将字符串调整为 html 格式**。返回处理结果。

注意：**第三句"将字符串调整为 html 格式"就是 ST 的 messageFormatting**(markdownToHtml + 其它转换）。**没有任何「```html 围栏单独拆出成 iframe」的步骤**。紧接 `refreshOneMessage` 注释证实消息是被**整条放回** DOM 的：
> `refreshOneMessage(0)` 刷新第 0 楼的显示
> 其中用 `$('#chat > .mes[mesid="5"]')` 选中单个消息 DOM

所以官方流程是：
```
原始字符串 → 替换宏 → 跑用户/卡正则（也就是我们的 regex_6/7 此时把 <StatusPlaceHolderImpl/>换成整份围栏文档) → "整篇当 markdown 转 html"
```
进 DOM 之后，SillyTavern 自身对 <script> 是**剥离的**（浏览器原生 innerHTML 不执行脚本），这就是为什么酒馆助手要把"卡片前端"独立出来作为 **Post-Mount 脚本注册** —— 它不从消息 HTML 的 script 开始成长，而是项目框架层面另外有一个生命周期系统来管理脚本。即在酒馆助手里：
- 消息 markdown 渲染（messageFormatting)→ 生成 DOM;
- 另外 `iframe/script.d.ts` 这一族 API(`registerScript`,`getScriptId`,`getScriptName`,`replaceScriptInfo` 等）让卡的作者能注册一个「消息外的辅助脚本/前端界面」，这类脚本被注入到 iframe，里面**由酒馆助手直接挂** jQuery/lodash/toastr/**errorCatched**/`waitGlobalInitialized`/Mvu/z 等（mvu.ts/embedded iframe.ts)，卡的 `regex_scripts[6].replaceString` 里的 `errorCatched/waitGlobalInitialized` 就是在期待这个宿主。

**我们当前实现和酒馆的关键差异**是两条：

1. **把消息里的 ```` ```html 围栏掰成两半**（把围栏前的旁白与围栏内文档分开）；而酒馆是**整条字符串进 messageFormatting**。我们的设计是为了避免"一份完整 HTML 被 markdown 包装之后 iframe 也会被包装"，但代价就是当一条消息里有**多份**围栏时只留第一份 — 与酒馆的"一路到尾"不同，造成 §4 T9 的 207KB 被静默丢弃。
2. **卡的 replaceString 脚本期望一整套 Tavern Helper runtime**(`errorCatched`、`waitGlobalInitialized`、`Mvu`、`getLorebooks`, 甚至 `$` 要能等到 ready)，而我们只注入了**库**(jquery/lodash/toastr/yaml)+ 部分 `_TH` API，但**没有注入这批卡脚本上下文帮手**。所以即便我们把 B1（语法炸弹）修了，regex_6 也会被 `errorCatched` 绊倒，修了 errorCatched 之后会被 `waitGlobalInitialized('Mvu')`(Mvu=z=N 未注入）绊倒。

这是真正的问题画像：**酒馆的作者会期待酒馆助手那一整层 runtime API（不只是库），我们目前只给了一部分**。

### D2. 我们 vs 酒馆 / 直接证据

| 做法 | 酒馆（由 .d.ts 推） | 我们 |
|---|---|---|
| 正则挖出 HTML 后怎么进消息 | `messageFormatting()` 把整篇 markdown→HTML 放消息 DOM | 第一围栏独立成 iframe + 后面丢 |
| 多条前端 | `message_id` 由卡决定是否整个重复出现 … 实际上卡 replaceString 自己把 marker 替换完，由酒馆整条渲染 | 我们只保留第一份 |
| 卡片脚本运行时刻 | 依赖酒馆助手的宿主脚本生命周期（`registerScript` 一类） | 直接内联进 blob iframe |
| 卡片全局 `$`/`errorCatched`/`waitGlobalInitialized` | TavernHelper/EJS 脚本环境自带 | 我们没有挂 |

---

## 7. 修复方案（只出方案，不施工）

**严格按"先修哪个性价比最高"排序。**全部方案都**不**在本轮施工。

### F1. B2 —— 填坑 errorCatched / waitGlobalInitialized（解决"能渲染骨架但全部无响应"，覆盖 regex_6 状态栏）

**锚点**:`assets/chat/chat_stage.html`,`injectBridge` 的 `_TH` 定义段（655-733)，紧邻 `for(var _k in _TH) window[_k]=_TH[_k]` 前后。

**改动思路**（两个方向）:
1. **桩版**:injectBridge 里在 for-in 挂 window 之前，补充
```js
'_TH.errorCatched=function(fn){return function(){try{return fn.apply(this,arguments);}catch(e){console.error("[errorCatched]",e&&e.stack||e);throw e;}};};' +
'_TH.waitGlobalInitialized=function(name){return Promise.resolve(typeof window[name]==="undefined"?undefined:window[name]);};' +
```
（或 `waitGlobalInitialized` 直接 resolve({})). 挂到 window 与 `_TH`。**这就能让 regex_6 的顶层 `$(errorCatched(init))` 通过**,`init()` 真正被调度；之后 `init` 里的 `await waitGlobalInitialized('Mvu')` 会 resolved undefined, 走到 `eventOn(Mvu.events…)`、`Mvu.getMvuData(...)` 会再炸 ReferenceError —— 但它发生在 **init 函数体内**,errorCatched 会捕获并 console.error，状态栏至少**骨架还在、tab 能切(`window.switchTab` 顶层赋值已发生）、旁白无影响**。剩余 MVU 数据填充属 P3-E 范围。
2. **真桥版**：在引擎房（engine room）里已经挂过了 mvu_bundle，直接让 injectBridge 的 `_TH.eventOn` 与 `_TH.getVariables` 这类调用转发到引擎房（现在 _TH.eventOn 是"本地 iframe 内的事件总线",Mvu 事件类型 SYSTEM events 由引擎房持有，需跨 iframe 桥） —— 这个方向工作量大，不合本任务"最小改动"。

**风险**：改动 injectBridge 是对**所有卡**的路径（好消息：凡是 errorCatched 的引用全部是 patch 定义所引起；if 本卡/别的卡没用到 errorCatched，行为不变。若用到，行为是"原本会 ReferenceError 掉的顶层，现在能跑完但他的 catch 捕获 init 错误" — 这更符合酒馆的本来意思）。
**影响范围**：只影响进 iframe 的富 HTML 卡片；普通 markdown 消息不受影响（它们不会被 injectBridge)。

### F2. B1 —— 修好 `_normalizeCodeQuotes`，不要再破坏字符串内合法的弯引号（regex_7 开局界面）

**锚点**:`lib/presentation/screens/chat/webview_chat_stage.dart:3173-3176`,被 `2893` 行调用（富路径），即：
```dart
String _normalizeCodeQuotes(String html) => html
    .replaceAll(RegExp('[‘’‚‛]'), "'")
    .replaceAll(RegExp('[“”„‟＂]'), '"')
    .replaceAll(RegExp('…+'), '...');
```

**问题本质**：这是"全文本替换"，不区分引号是**字符串定界符**（要修）还是**字符串内容**（不能动）。

**最小改动的正确方向**：把该函数从 Regex 管路改成**一个简单的单遍状态机**，只在处于「JS 代码解析态」（不在双引号字符串 / 模板字符串 / 注释 / 单引号字符串中间）时才把弯引号换成直引号。状态机跟踪：
- 当前在哪个文本区域（HTML 文本区不受 normalize 影响 — 已 decide 这是 JS 区）；
- JS 内 state: in_string_double/in_string_single/in_template/in_line_comment/in_block_comment/in_regex；弯引号**只在 none-of-the-above 的代码态**（即定界位置）才换，其它原样保留。
- regex_7 的「`desc: "“深蓝...“」], "`"这种用法"，在我们发现"深蓝"处于双引号字符串内部时，里面的弯引号保持不动；而卡作者把弯引号当定界符的写法（""Name"" 类型）才会被修正。

**风险**：手写状态机有边界情形（template literal 里 `${}` 嵌套、regex vs division 歧义）。**所以强烈建议**：给该函数写一组 **TDD 单元测试**（这个仓库已有 test/ 基建）;**要么干脆别修，直接把这函数从 looksLikeHtml 路径上撤下来**（保留它作者最初的意图"卡作者失误会把弯引号写成定界符"，但这种案其实非常少 — 我们只在这张卡上确认过一种正常情况，没看到它修过什么东西。**移除它反而是更小的改动**)。两个方案在 report 给出，由下一轮决定哪个。

**影响范围**：只影响 looksLikeHtml==true 的富 HTML 卡（要走 iframe 路径的）。普通 markdown 消息**不经过** `_normalizeCodeQuotes`（它走 `_highlightQuotes`)，不受影响。

**另一个可选修复方式（更保守）**：先用一个简单规则扫描"是不是发现危险模式 `""...""`”」(2 个紧邻的双引号后跟着他字 + 直引号收尾），只在识别成功时才跳过 normalize；否则照旧。这能做到「修死的卡 vs 修活的卡」分开处理，但要小心评估启发式准确度。

### F3. T9 真 bug —— 多围栏（多前端）同消息的只取第一个围栏问题

**锚点**:`webview_chat_stage.dart:2860-2873`。

**改动思路**(`condition is ''' 存在两个或以上 html 围栏 '''`):
- 用 `allMatches` 收集所有 ```` ```html ```` 围栏；
- 每份围栏对应**一个独立 iframe**（或串在一个气泡里的一串 iframe),prose 在每份围栏前后各取一段（第一份前 / 各份之间 / 最后一份后）;
- 目前消息的 JSON 只有一份 `prose` + `html`，多 iframe 要在 JS 侧函setMessages 里把结构改成数组或在 `html` 发多段。改 invasiveness 偏大；
- **短期最小改动版**：保留单 iframe，但把**围栏之后的全部内容**（包含里面可能带的整份前端）**追加渲染**在 iframe 之后作为一个额外 iframe（而不是处理进当前 iframe)。**这一种最小改法请考虑支持 fallback 路径** —— 但这仍要改 `webview_chat_stage.dart` + `chat_stage.html` 两侧；
- **更简单方案**：这一条消息本来就有可能其实是两条 AI 回复的并合（regex_6 StatusPlaceHolder 和 regex_7[重塑仙缘]) — 应该在**管线被调前**被拆成两条 message。这是更深一层设计问题，建议把 T9 的修复放到下一轮独立处理，而不是夹进 B1/B2。

**风险**：拆墙（现有用户卡只把一条完整 UI 放一份围栏），出多份围栏的卡会遇到这个 bug。本轮先报告不动工，符合任务要求。

### F4. 小但高危 —— `html.replace(/<head>/i, '<head>' + patch)` 的替换引用副作用

**锚点**:`chat_stage.html:777`(injectBridge 的注入动作）。

**问题**:`String.prototype.replace(/<head>/i, '<head>' + patch)` 的 second argument 若含 `$&`(matched substring)/`$'`（后文）/`$\``（前文）/`$1`-`$9`（捕获组），会发生非直接字面替换，导致 injectBridge 注入结果和预期不一致。本次卡里没触发（我们的 `$` 都避开了），但这是一颗雷，**fallback 写法应该改为**:
```js
return html.replace(/<head>/i, function(){ return '<head>' + patch; });
```
函数返回作替换串，永远当作字面量。一行改动，零风险。

### F5. 局面建议；不推荐继续在本任务塞入 E/F 层

Mvu/z variables / yaml/substitudeMacro / getAllVariables/getChatMessages semantics / Mvu data 填充都属于 P3-E 范围，不该在这里做。

---

## 8. 需要人类配合的验证项

必要前置：**全新对话+冷启动**（不要热重载）,`flutter clean && flutter build` 重打之后测，抓取 logcat 全量。

### 8-1. CARD-ERR 捕手是否在真机上能拿到（对应假设 B 的最后一道实证）

操作：
1. 走"开局界面"那条故事线（AI 回来含 `[重塑仙缘]` 的气泡）;
2. `adb logcat | grep "CARD-ERR"`<br>(或你们的日志通道）

期望读到：
```
[WV-10] CARD-ERR id=<...> Uncaught ReferenceError: errorCatched is not defined @<line>:5
```
或 `Uncaught SyntaxError: Unexpected identifier '深蓝'`
- **读到** → B1/B2 在真机完全坐实，本报告 B 链全完成；
- **没读到** → 说明捕手链故障（几乎不可能，因为已经在桌面 Edge 验证过），按 §9「我没能验证的部分」回滚讨论。

### 8-2. 状态栏 tab「切不动」的语义确认（假设 B2 的残余语义）

用 DevTools 或对 KiraLogger 增加一个定向可观测点（允许本轮不动 product 代码，但需要一条新日志探针，会属于下一轮）- 或者真机上点到 tab 稍后观察 `[WV-7] cardHeight` 序列是否变化，或从 CARD-ENV2 探针附近的画面截图看 frame 是否渲染静态骨架 + panel 空白。如果面板上**切换了 active 但 panel 空白** → 说明 switchTab 活着但 populateCharacterData 没跑（B2 结论完全坐实）；如果点击毫无 vkbd 回馈 / 连续 tap 无 visual change，那说明还有点击被拦截 —— 此时 C 复活，需要再单独离线复现。

###
- 8-3_pic1~picN: 横幅截图 + DevTools inspect iframe.document.querySelector('#start-button').__listeners （在真实 Edge / Chrome inspect)。

### 8-3. 假设 C 的最终证伪（人手）

操作：
1. 原 app 不做任何修改，打开会话，把消息滚到「开局界面」气泡完全在视口内；
2. 直接轻点一下气泡中的静态文本（不是按钮），看是否触发 swipe / 楼层号 / debug print(WV-5 等）;
3. 再轻点「是」按钮（确实在可视区域内）。

期望读数：
- 普通静态区点击：无意外 → 说明点击能进 WebView;
- 「是」按钮：什么都无 → 即使点击到了 iframe，iframe 内也没有 listener → 这把所有遮罩/手势层的假设都排除了(=假设 C 否决);
- 如果静态区点击也没反应 → WebView 完全为死 → 新方向：往 flutter_inappwebview 的 webview 创建参数查（例如 useHybridComposition 导致 WebView 上方被合成层吃掉触摸 — 不太可能因为其它地方 ListWheelScroll 等能滚）。

### 8-4. tail 丢弃（T9）在真机是否出现过

预期 grep `[WV-2] id=... afterRegex=<long> body=<shorter>`, `afterRegex - body ≈ 第二个前端的长度`。抓几条真实与道渊的回复，比较 afterRegex 与 body 的差距趋势。如果差距≈ regex_7 长度（207K)，就说明真实流量确实命中了 T9 双标记场景。

---

## 9. 我没能验证的部分（如实清单）

1. **未在真机/模拟器里跑 App**。本报告的一切结论都基于：(1) 对 Dart 代码的静态阅读；(2) 在线下用项目自己的 `RegexService`/`RegexScript.fromJson`/`markdownToHtml` 跑同一输入（这一步与真管线完全同源）;(3) 沙盒 (Node vm) 执行卡/管线产物；(4) 真实 Edge headless（**注意，不是 Android WebView**）里面灌入库与卡文。**Android 版 WebView 与桌面 Edge 在 `blob:` iframe + `<script type=module>` 的行为上有极小差异的可能**（实际上这里 Android WebView 也是 Chromium，理论一致，但场所不同）。
2. **真机日志读数没有采集**。§8-1 是预设期望，没有抓到就没有最终证据；本报告在 §4 中把 CARD-ERR 的 expected text 写明，等待人工配合。
3. **T9 双标记场景是否真实存在于实际聊天** — 我只人造了这个输入来复现丢弃行为，没有真消息数据证明 AI 会同时输出状态栏标记和开局标记（虽然 regex_5 XML状态栏 hint AI 会枚举两个；我们的 grep 也看到 regex_6/regex_7 同时都在 enabled，按卡作者的意图 `<StatusPlaceHolderImpl/>` 是 **每条回复都给**，而 `[重塑仙缘]` 只在开局发一次 → **真实场景 regex_7 消息很可能**同时也会带 StatusPlaceHolderImpl — T9 情况确实会出现，但没实测）。
4. **regex_6 的「OK 后能不能 populate 出数字」**:B2 是「当前必然炸」;**修好 errorCatched 后**会不会再绊在 `Mvu`/`waitGlobalInitialized` 的后续 await、或卡片里设置的 getLorebooks/triggerSlash 的 await 上 - 我没有模拟那么多层；我把 init 的 trace 读出来（`check_init_order.js`)，知道 init 的**第 2 行**就是 `await waitGlobalInitialized('Mvu')`，这个在我们挂了桩之后**如果 Mvu 还是没进来，会在这里会停**。已按「最小改动让骨架活、MVU 留到 P3-E」的口径写进 F1/F2。
5. **`_handleTriggerSlash`/`_handleGetMessages` 的 bridge 语义与真机行为一致性** — 卡里的 `switchToSecondGreeting()` 和 regex_7 的"/trigger/next"流都依赖这条 channel；这条 channel 的 Dart/JS 实现没有在离线被我跑到（我只能读代码+题注）。实际发 `/send 开启仙途` 的时候，`_handleTriggerSlash` 会不会把「开启仙途」当成正常 sendText 发给后端然后触发 AI 重新发回 → 这里面没有测过，见 P3-C 的 Task 3 & bridge 日志。  
6. **regex_6 状态栏 ROI 与 container 高 2491px 的关系** — 没真机拿 screenshot, just logical inference (harness 报告 cardHeight 至少一次 2491+24=2495)。
7. **first_mes 的「点击这里」第二问候**(first_mes 里有 `switchToSecondGreeting`)，我测过 first_mes 的脚本体 PARSE OK 且不会落 SyntaxError，但它的实际运行（需要 `getChatMessages` 和 `setChatMessage` 的 bridge 真的 work）未测 — 它们是 _TH 的 bridge，离线 no-op 不代表真机行为。
8. **`.card-frame` 上 tap 的 real webview 触摸分发** — 静态证明点击物理上没有被挡，但 flutter_inappwebview6 + hybrid composition + scrollView + iframe 的触摸坐标映射存在历史小坑，没到真机上无法完全确认。
9. **我们 _normalizeCodeQuotes 的回归影响面** — 没去翻所有现存用户卡与所有项目自带 test fixture，不知道有多少卡片曾在旧逻辑下靠它工作，这里面类数量没统计。F2 的 nobrainer 对策（修状态机或下线）下面的风险评估没有数据。
10. **regex_8（禁用版）同款 SyntaxError 炸弹是否在历史上曾经炸过 / 是否曾经被开启过** — 当前它 disabled，不影响 live rendering；但如果哪天有人 enable 它，会走 Regex_7 同样的死路。这条没有 concrete test，写在这里是为了告知。

---

## 附录：本轮新增的一次性调研脚本（都在 `DiaoYan/P3/诊断/` 下）

| 文件 | 作用 |
|---|---|
| `analyze_card.js` | Task A：读卡 → 脚本清单 / 骨架 / first_mes / 按钮搜索 |
| `pipeline_repro.dart` | Task B：用真实 RegexService 复现 `webview_chat_stage.dart:2830-2897`，逐步 dump 到 `out/T*_{0..6}_*.txt` |
| `run_card_script.js` | B2'：Node vm 执行 module/classic，抓顶层错误与 snapshot |
| `run_regex6_strict_dom.js` | regex_6 在严格 DOM(null 版）的重复验证 |
| `find_syntax_break.js` | 定位SyntaxError 行号 + 同行撞出来的所有危险行 |
| `check_t1_rendered.js` / `check_t2_module.js` / `check_raw_vs_norm.js` | 各产物的 PARSE OK vs PARSE FAIL 对拍 |
| `check_dollar_hazard.js` | 验证 `String.replace` 替换引用 `$&`/`$1` 对 patch 内库文件的实际副作用 |
| `build_browser_harness_noext.js` / `build_browser_harness.js` | 把 rendered 产物 + 真库包装成 blob iframe，扔给 Edge headless 跑 |
| `out/` | 上面每次 dump 的全量产物（未经摘要） |

> 完。报告完。

