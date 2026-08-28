# 13 webview 聊天渲染现状全图

> 纯调研，零代码改动。代码基线 `34597ca`（WV-1~7 探针 + WV-6 自愈已在）。
> 上一轮 C1 的五个修复 commit 已回档，保留在 `backup/c1-alpha-failed`。
> 所有结论标注【实证 file:line】或【推测】；无法确定的实验值标注「需真机实测」。
> `_htmlShell` 巨型字符串内部一律用**内容锚点**描述位置（行号会漂移），Dart 侧函数名用 `file:line`。

---

## A1 文件与职责清单

| 文件 | 行数 | 职责 | 被谁调用 | 热点 |
|---|---|---|---|---|
| `lib/presentation/screens/chat/webview_chat_stage.dart` | 4754 | 聊天渲染的**绝对核心**：`_htmlShell()` 巨型字符串、`_serializeMessage()`、`_pushMessages()`、`_pushImages()`、桥 handler 注册、引擎房创建、全部 `_pushMessages` 触发点 | `chat_screen.dart` → `_buildMessagesArea` 挂载 | 【最高热点】 |
| `lib/presentation/screens/chat/chat_bridge.dart` | 284 | Dart↔JS 通信总线（出站 `_dispatch`、入站 `_onInbound`、ready 握手、outbox 队列） | webview_chat_stage 初始化 `_bridge` | 高（`_dispatch` 的双层 jsonEncode 是隐患点） |
| `lib/presentation/screens/chat/chat_bridge_js.dart` | 174 | JS 侧总线：`__bridgeDispatch`、`sendToFlutter`、`registerBridgeHandler`、`__sendRequest`（请求-响应 Promise 表） | `_htmlShell` 经 `$kChatBridgeJs` 内插 | 中 |
| `lib/presentation/screens/chat/tavern_helper_facade.dart` | 703 | 生成引擎房共享 TavernHelper 门面 JS（`buildTavernHelperFacadeJs`） | `_injectEngineFacade` 注入 `window.__ENGINE_FACADE_JS` | 中（A5 耦合面） |
| `lib/presentation/widgets/chat/html_webview_widget.dart` | 461 | **遗留**：每消息独立 WebView widget（NativeTavern 老方案） | `message_content_widget.dart:203`（老布局模式路径） | 低（仅老模式） |
| `lib/presentation/widgets/chat/message_content_widget.dart` | ~20KB | 老渲染模式的内容分发（含 `HtmlWebViewWidget` 引用） | `message_bubble.dart`（老模式） | 低 |
| `lib/presentation/screens/chat/chat_layout_mode.dart` | 39 | 布局模式枚举 | 决定走 webview 全屏还是老 Flutter 列表 | 低 |
| `assets/libs/*.js`（jquery/lodash/toastr/ejs_stub/ejs_bundle/mvu_bundle） | — | 第三方库 + EJS/MVU bundle，`rootBundle.loadString` 读入后 base64 内联 | `_loadCompatLibs` / `_loadEjs*` / `_loadMvuBundle` | 中（打包改动敏感） |
| `lib/domain/services/regex_service.dart` | 413+ | 正则替换 `getRegexedString`（string→string，纯函数 + 缓存） | `_serializeMessage` 第一条 pipeline | 高（症状3/4 源头） |
| `lib/data/models/chat.dart` | — | `ChatMessage`（含 `swipes`/`currentSwipeIndex`/`currentReasoning`） | 序列化数据源 | 中 |

**热点总括**：`webview_chat_stage.dart` 是单点汇聚，几乎每次改动都落在这里；其中 `_htmlShell`（约 1600 行字符串）与 `_serializeMessage`/`_pushMessages` 是改动频率最高、风险最高的两处。

---

## A2 完整数据流（双向）

### 正向：DB 原文 → 屏幕像素

```
1. ChatMessage.content (DB 原文)
   ↓ 【实证 _serializeMessage webview_chat_stage.dart:2771】
2. RegexService.getRegexedString(placement=角色, isPrompt:false)
   → 角色卡正则改写文本（症状3/4 的源头之一）
   ↓ replaceAll(<image>…</image> 自动生图占位)  【:2787】
3. 剥 ``` 围栏：^```xx\n(…)\n```$ 整体解包  【:2790】
   ↓
4. 分流切分（当前基线只产出 prose + 单个 body）  【:2801~2838】
   - 有 ```html 围栏 → 围栏前文字=prose，围栏内=body
   - 否则有 <!DOCTYPE/<html 且起点>0 → 起点前=prose，之后=body
   - looksLikeHtml(<style|<script|<!DOCTYPE|<html|<head|<body)
     true → 源码直渲(_normalizeCodeQuotes)   【源码直渲路径】
     false → markdownToHtml + _highlightQuotes 【markdown 路径】
   ↓
5. 拼接 attachmentsHtml → 返回 map {id,role,prose,html,reasoning,swipe…}
   ↓ 【_pushMessages webview_chat_stage.dart:2918】
6. 序列化最近 batchSize=30 条 → jsonEncode → utf8.encode → base64Encode
   ↓ 桥 _dispatch：jsonEncode({type,payload}) → evaluateJavascript('window.__bridgeDispatch(<json字符串>)')
7. JS setMessages(b64, options)  【shell 内 setMessages 函数体】
   - initial → root.innerHTML='' 全量重建
   - prepend → insertBefore(root.firstChild) 历史前插(20条/批/16ms/无上界)
   - 否则 → appendChild 追加
   每条：prose/reasoning/非富 html 走 innerHTML（<script> 不执行）
         富 html → blob iframe（script 正常执行）
   ↓ history 分批反向发送（Dart 升序发批 × JS 逐条 prepend）
8. 图片走独立通道 _pushImages：每附件 base64 → setImage 逐张推
9. iframe load 后 200/600/1500ms 三连 + ResizeObserver 回传高度
   → 外层 f.style.height = max(contentH+4, window.innerHeight) 【视口地板】
```

**失败模式（每步）**：
- 步2：正则异常（用户脚本崩）→【推测】`getRegexedString` 内部可能吞或抛，抛则整条序列化中断
- 步6：`jsonEncode`/`utf8.encode` 抛（非法 surrogate）→ **整批不发**，见 A8「循环前失败面」
- 步7：`JSON.parse` 失败 / 单条 DOM 构建异常 → 命中外层 catch → `root.innerText='ERR:'`

### 反向：webview 用户操作 → Dart → 是否触发重渲染

```
点击 iframe 内按钮 → 卡片内 JS → parent.postMessage({__thRequest}) / __cardHeight
  → shell 顶层 message 监听 → sendToFlutter('log'/'action'/'th_*')
  → 桥 _onInbound → handler
    · action(点击工具条/swipe/图片) → _handleAction 【:2481】
    · th_getMessages/th_setMessage/… → 各 request handler
      th_setMessage refresh=true → _pushMessages 【:1798】
      MVU swipesData 写回 → _pushMessages 【:1719】
  → 状态变更 → ref.listen(activeChatProvider) → 决定 push/append/diff
  → 非纯追加、结构变化 → _pushMessages（全量重建最近30条）
```

---

## A3 桥协议全清单

### 出站（Flutter → JS，`registerBridgeHandler` 注册的 type）

| type | 载荷 | 时机 | JS 处理 | 幂等 |
|---|---|---|---|---|
| `setMessages` | `{data(b64), initial?, prepend?, avatars?}` | 全量/前插/追加 | `setMessages` | 非幂等（重发=重复渲染，与「多渲染」相关） |
| `appendToken` | `{id, token}` | 流式增量 | `appendToken`（首 token 若无 `.stream-text` 则 `wrap.innerHTML=''`） | 非幂等 |
| `setImage` | `{path,mime,b64}` | 附件 base64 逐张 | 按 `data-att-path` 匹配灌 `img.src` | 半幂等（匹配到即设 src，重发重复解码） |
| `setGenerating` | `{msgId,genId,w,h}` | 自动生图占位 | 插占位节点 | 幂等（同 genId 已存在则跳过） |
| `setGenerateProgress` | `{genId,progress}` | 生图进度 | 更新百分比 | 幂等 |
| `clearGenerating` | `{genId}` | 生图结束/失败 | 移除占位 | 幂等 |
| `scrollToFloor` | `{floor}` | 楼层跳转 | `scrollIntoView` | 幂等 |
| `showModelSheet/hideModelSheet` | `{models,current,configs}` | 模型选择弹层 | 渲染/关闭 | 幂等 |
| `openFunctionPanel/closeFunctionPanel` | `{charId,context…}` | 功能面板 | 渲染/关闭 | 幂等 |
| `th_response` | `{id,ok,result/error}` | 请求-响应回传 | resolve/reject 对应 Promise | 幂等 |

### 入站（JS → Flutter）

| type | 载荷 | 时机 | Dart 处理 |
|---|---|---|---|
| `ready` | `{}` | JS 就绪 | `_onReady` 冲刷 outbox |
| `action` | `{id,action,attPath?}` | 点工具条/swipe/图片 | `_handleAction` |
| `log` | `{text}` | 卡片/探针日志 | `debugPrint` |
| `modelSelected` | `{model}` | 选模型 | 更新 llmConfig |
| `switchConfig` | `{configId}` | 切换方案 | setActive + fetchModels |
| `panelAction` | `{action,…}` | 面板按钮 | `_handleAction` 分支 |
| `panelClosed` | `{}` | 面板关闭 | 同步 `_funcPanelOpen` |
| `th_getMessages/getVars/setMessages/setMessage/setVars/triggerSlash/setInput` | 各异 | 卡片/引擎房请求 | 各 `_handleXxx` request handler |
| `th_wiGetLorebooks/wiGetEntries/wiSetEntries/wiCreateEntries/wiDeleteEntries/wiGetCharLorebooks/wiGetLorebookSettings/wiSetLorebookSettings/wiCreateBook` | 各异 | 世界书 API | 各 `_handleWi*` |
| `th_generateRaw` / `th_renderEJS` | 各异 | 生图原始/EJS 渲染 | 对应 handler |

### 触发 `_pushMessages()` 的全量重建账本（14 处）

| # | file:line | 触发场景 |
|---|---|---|
| 1 | `:404` | 消息结构变化（增删/换聊天） |
| 2 | `:413` | 末条 content 非前缀变化（非流式） |
| 3 | `:422` | swipe 数量/索引变化 |
| 4 | `:440` | 生成结束瞬间 |
| 5 | `:455` | attachments 数量变化（自动生图完成） |
| 6 | `:598` | WV-6 renderer 崩溃自愈 reload 后 800ms |
| 7 | `:728` | onLoadStop 后首次推送 |
| 8 | `:1719` | MVU swipesData 写回 |
| 9 | `:1798` | th_setMessage refresh |
| 10 | `:2143` | 清空聊天 |
| 11 | `:2704` | 编辑消息保存 |
| 12 | `:2737` | 删除单条 |
| 13 | `:2757` | 删除此条及之后 |
| （补） | `:402` 分支 | `_appendNewMessages`（非全量，仅追加） |

> 大白话：进入聊天、生成结束、swipe、reroll、编辑、删除、附件变化，最后都会走「把最近 30 条重新算一遍、重新塞一遍」，这是「自下而上炸」和性能问题的温床。

---

## A4 `_htmlShell` 解剖 + 能否抽成 asset

`_htmlShell()`（Dart `:3065` 至 `:4582`，约 1500 行字符串字面量）内部结构分区：

| 分区（内容锚点） | 大致占比 | 内容 |
|---|---|---|
| `头部 polyfill <script>` | ~2% | `Object.hasOwn / structuredClone / findLast / replaceAll / at` 等老 WebView 兼容垫片 |
| `<style>` 巨型 CSS | ~17% | 气泡 `.msg`、消息组、工具条 `.msg-tools`、swipe bar、楼层 tag、模型弹层、功能面板、思考动画 |
| `<body>` 骨架 | ~3% | `#root`、`#__engineRoomHost`、`#model-sheet`、`#func-overlay` |
| `$kChatBridgeJs` 内插 | 1行（展开内部 174 行） | JS 通信总线 |
| 模型/功能面板交互 JS | ~8% | `__renderModelList` 等 |
| `injectBridge`（卡片 iframe 桥注入） | **~40%** | 巨量 `_TH.*` TavernHelper API + localStorage/sessionStorage polyfill + 高度回传 + 死代码 loretbook 段（注释 `死代码` 自认保留待删） |
| 探针 WV-4/5 + 高度回传监听 + 顶事件中继 | ~8% | `__emitToEngine` / `__syncVarsToEngine` / `__thRequest` 中继 |
| iframe 虚拟化（IntersectionObserver） | ~3% | 离屏 `src='about:blank'` 清空 |
| `setMessages` / `appendToken` / `createEngineRoom` / `resetEngineRoom` | ~14% | 核心渲染 + 引擎房 |
| 楼层/srvpe/滚动/点击委托 | ~5% | 工具条逻辑 |

**结论：能不能抽成独立 asset 文件？**

**能，且强烈建议——但属于「第二期」，不是第一期。**

收益：
1. 用真正的 JS 工具链（ESLint/Node `--check`）静态发现语法错误——本次调研已用 `node --check` 实测了 shell 抽取后的语法（当前合法），但过程很痛。
2. 行号稳定、可 grep、可 diff，解决「一个三层转义地狱里找 bug」。
3. 消除 Dart 字符串插值 `$` 与 JS `$`/`${}` 的潜在冲突面。

代价：
1. 打包配置：需把 `.html`/`.js` 注册进 `pubspec.yaml` assets，`rootBundle.loadString` 读入。
2. **动态插值怎么处理**：当前 shell 内插了 `$kChatBridgeJs`（静态）、`_colorToCss(ref.watch(quoteColorStateProvider))`（动态颜色）、以及其它少量动态值。抽离后需改为「占位符 + 运行期替换」或「模板变量进 `<head>` 后注入」。颜色值其实已通过 `__KIRA_MACRO_VALUES` 类似机制外置，可沿用。
3. 热重载行为：`rootBundle` 在 debug 下可 reload，但 WebView 已注入的内容不会自动刷新，需重进聊天页——与现状一致，无新增损失。

大白话：现在是「把 1500 行 JS 塞在一个 Dart 字符串里，出语法错只能在真机白屏时才知道」，抽成文件后「写个脚本 `node --check` 就能在提交前发现」，这是可观测性先行的最基础一步。

---

## A5 引擎房耦合面（硬约束）

**引擎房 iframe 挂载点（关键事实）**：
- shell 的 `<body>` 里有个 `<div id="__engineRoomHost" style="display:none;width:0;height:0">`，它是 `#root` 的**兄弟节点**，不是 `#root` 的子节点。
- 引擎房 iframe 由 `createEngineRoom()` 创建后 `host.appendChild(frame)`，`data-frame-id="engine-room"`。

**关键结论（直接影响所有渲染改造方案）**：
- `root.innerHTML = ''`（setMessages initial 全量重建）**不会摧毁引擎房**——因为它在 `#root` 之外。【实证 shell 骨架锚点：`#root` 与 `#__engineRoomHost` 相邻并列】
- **webview `reload()` 会摧毁一切**，包括引擎房。WV-6 自愈路径就是 `controller.reload()`。【实证 :593~600】reload 后 `onLoadStop` 会重新跑一遍 `_inject*` → `createEngineRoom()` → `_pushMessages()`，所以恢复路径是完整的。但 reload 期间引擎房内所有内存态（`__chatMessages`、变量镜像、EJS/MVU 运行时）全部丢失，需重新 `generation_started`/`chat_changed` 点火。

**哪些改动危及引擎房**：
1. 替换整个 `_htmlShell` 骨架（移除 `__engineRoomHost` 或改结构）→ 危险。
2. 在「reload / 重挂 shell」类改动中漏掉 `onLoadStop` 的 `_inject*` + `createEngineRoom` 序列 → 危险。
3. 改 `createEngineRoom` 依赖的 `window.__ENGINE_FACADE_JS` / `__KIRA_MVU_BUNDLE` / `__KIRA_EJS_BUNDLE` / `__KIRA_EJS_STUB` 命名或注入时机 → 危险。

**哪些安全**：
- 只动 `#root` 内的消息渲染（setMessages / appendToken / 消息级 iframe 隔离）。
- 只动 `_serializeMessage` / `_pushMessages` 的 Dart 侧逻辑。
- 只动 `pushMessages` 里对 `#root` 的操作。
- EJS 提示词侧（`bundle/stub/mvu` 注入路径 + `__emitToEngine` 事件）只要不碰 `_inject*` 与 `createEngineRoom` 就安全。

**引擎房的桥调用路径**：
`__emitToEngine(type,args,msgs)`（Dart `evaluateJavascript` 触发）→ `host.querySelector('iframe[data-frame-id="engine-room"]')` → `contentWindow.postMessage({__thEvent,…})` → 引擎房内 `message` 监听 → `TavernHelper.eventEmit`。反向：引擎房内 `TavernHelper.*` → `__thCall` → `parent.postMessage({__thRequest})` → shell 顶层 `__thRequest` 中继 → `sendToFlutter` → Dart request handler。【实证 shell 锚点：`__emitToEngine` / `__thRequest` 中继段】

---

## A6 状态归属矩阵

| 状态 | Dart | webview JS | 风险 |
|---|---|---|---|
| 消息列表（权威源） | ✅ `activeChatProvider` | ❌（只读镜像 `__chatMessages`） | 低 |
| 滚动位置 / stickBottom | ❌ | ✅ `__stickBottom` / `__programScroll` | 中（全量重建后 scroll 状态需重算） |
| 流式缓冲 | ✅ content 全量 + delta 计算 | ✅ `.stream-text` 文本累积 | **高**（双持：reroll 时旧流式文本残留 →「多渲染」） |
| swipe 状态 | ✅ `currentSwipeIndex` | ✅ swipe bar 显示 | 中（重建时同步） |
| 图片加载态 | ✅ `_attachmentB64Cache` | ✅ `img.onload` / `data-img-loaded` | 中（缓存键不一致风险） |
| iframe 高度 | ❌ | ✅ `data-last-height` + 三连回传 | 高（视口地板 + 虚拟化摘除后恢复） |
| 展开/折叠态（工具条） | ❌ | ✅ `.msg-tools.open` class | **高**（全量重建丢展开态） |
| 选中态 | ❌ | ✅ DOM class / 临时 | 高（重建即丢） |

> 大白话：凡是「两边都记一份」的（流式文本、展开态、图片已灌状态），一旦某次全量重建 or 部分 diff 没对齐，就会出现「多渲染/少渲染/状态丢失」。A6 标记的三处「高」正是改造时要重点收敛的。

---

## A7 生命周期

- **webview 创建**：`_webViewMounted=true` 且 `InAppWebView` 构建（`:559`）；`onWebViewCreated` 挂控制器 + 注册 handler。
- **webview 销毁**：`dispose()` / pop 时 `_webViewMounted=false` 从树卸载；`PopScope.onPopInvokedWithResult` 先 `pause()` 再 `setState` 卸载、延迟 32ms pop。【:522~534】
- **iframe 创建**：卡片 iframe 在 `setMessages` 里 `createElement('iframe')` + blob `URL.createObjectURL`（异常回退 `srcdoc`）；引擎房 iframe 在 `createEngineRoom()`。
- **iframe 销毁**：卡片 iframe 被全量 `root.innerHTML=''` 清除；离屏时虚拟化把 `src='about:blank'`（**并未删除节点**，仍占 DOM）。
- **消息节点移除**：`root.innerHTML=''`（全量）；`clearChat` → `_pushMessages` → initial 重建空列表。
- **setInterval/rAF/监听器清理责任**：**现状几乎不清理**。shell 内 `setInterval`（卡片 iframe 内的 `__thPending` 超时、Virtualization 的 IntersectionObserver/MutationObserver、滚动监听）挂在 webview/iframe 生命周期上，随节点销毁被动释放；但 `window.__wvActiveIntervals` 探针显示卡片内遗留 interval **不会**被主动 clear。**改造时需为「消息级 iframe」补充 onDetach 清理。**

### onRenderProcessGone 之后的完整恢复路径

```
1. onRenderProcessGone(:593) → controller.reload()
2. reload 触发 onLoadStop → 重新 _injectCompatLibs/MacroValues/EngineFacade/Mvu/EjsStub/EjsBundle
3. → c.evaluateJavascript('if(window.createEngineRoom)window.createEngineRoom()')  重建引擎房
4. → 2 秒保险 markReadyIfMissing + 350ms 延迟 → _pushMessages() 重灌消息
5. → 500ms×2 → mask 淡出
```
> 注意：本恢复路径依赖「reload 后 onLoadStop 一定会重跑注入+创建」。若渲染改造改变了 shell 或 `onLoadStop` 序列，此自愈即失效。

---

## A8 失败面清单（本轮重点）

| # | 失败点 | 影响范围 | 是否捕获 | 可观测日志 |
|---|---|---|---|---|
| 1 | `_pushMessages` 里 `jsonEncode(initialList)` / `utf8.encode` / `base64Encode` 抛（非法 lone surrogate 等） | **整批（连 JS 侧都收不到）** | 否（无 try） | **无（循环前失败面，WV-8 打不出）** |
| 2 | `_bridge._dispatch` 双层 jsonEncode 抛，`evaluateJavascript` 注入语法错 | **整批** | 桥内 try-catch 但仅 onLog | bridge 日志 |
| 3 | shell 内 `setMessages` 顶层 `JSON.parse(decodeB64Utf8(b64))` 抛 | **整批** | 外层 catch | 外层 catch（但会抹页） |
| 4 | 单条 DOM 构建抛（`buildActions`/`injectBridge`/插 iframe） | **单条**（如外层 catch 未拦截） | T1 曾打算加，**基线无逐条 try** | 无（基线） |
| 5 | `setMessages` 外层 catch：`root.innerText='ERR:'` | **整页抹掉已渲染前半** | 有 catch 但处理方式是「抹页」 | 无日志（静默抹页） |
| 6 | `createEngineRoom` 内 `var doc` 重复声明 + `<script>` 未闭合再开（shell 基线自带）【实证 :4445/4460~4463】 | 引擎房内部语法/运行时 | 部分 | 【推测】不稳定，未正式暴露 |
| 7 | `appendToken` 首 token `wrap.innerHTML=''` | **单条旧卡被清** | 有标记但不清块 | WV-3 CLEARED-WRAP |
| 8 | 高度回传 `f.style.height=max(h,innerHeight)` 视口地板 | 单条撑满屏 | 无 | WV-7 仅观测 |
| 9 | 正则替换（步2）异常/围栏被正则破坏降级为代码块 | 单条（降级为源码直出） | 无 | WV-1/WV-2 仅观测长度 |
| 10 | 历史 prepend 批内倒序（基线未倒序） | 历史顺序错 | 无 | 无 |

**特别点名「循环前失败面」**（上一轮全灭的直接嫌疑，WV-8 完全打不出）：
- **A8#1**：`_serializeMessage` 单条被 `_safeSerializeMessage` 包裹（α 分支），但 `jsonEncode(initialList)` / `utf8.encode` 是**批量**操作，未包裹。异常来自任意一条消息的字符串时，**整批不发、JS 侧连 WV-3 都收不到**。
- **A8#2**：`_dispatch` 的 `window.__bridgeDispatch(${jsonEncode(json)})` 若 `json` 含未转义的 `U+2028/U+2029`（已用 `dart run` 探针实测：Dart `jsonEncode` 默认**不转义**这两个字符），旧 Chromium（<74）会 `SyntaxError`，**整条 JS 注入失败**。现代 WebView（Chromium 90+）因 ES2019 JSON-superset 已合法，故为新老兼容隐患。

> 大白话：α 全灭时，最可能不是「渲染到第 50 条才炸」，而是「第一批 30 条还没发出就死在 Dart 侧批量序列化里」，所以连探针都来不及打。这也解释了为什么「一行 WV-8 都没有」。

---

## A9 已知缺陷登记表

| 缺陷 | 位置 | 症状编号 | 修复难度 | 可独立修 |
|---|---|---|---|---|
| 批量序列化无兜底（jsonEncode/utf8 抛整批死） | `_pushMessages` :2946~2947 | 1/2（放大） | 低 | ✅ 可独立（包裹 try） |
| 外层 catch 抹页：`root.innerText='ERR:'` | shell `setMessages` 末尾 catch | 6（自下而上炸） | 低 | ✅ 可独立 |
| 无逐条错误边界（单条失败中断整批） | shell `setMessages` for 内无 try | 6 | 低 | ✅ 可独立 |
| 视口高度地板 `max(h,innerHeight)` | shell 高度回传监听 | 7（小状态栏撑满屏） | 低 | ✅ 可独立（需配合消息级 iframe） |
| `appendToken` 首 token 清块 `wrap.innerHTML=''` | shell `appendToken` | 5（已渲染卡被清） | 中 | ✅ 可独立（需防 reroll 残留） |
| 正则先于围栏识别 → 围栏被正则破坏降级源码直出 | `_serializeMessage` :2771 顺序 | 3 | 中 | ⚠️ 需连带围栏保护，见 B2 |
| 多前端无法共存（只支持单一 body） | `_serializeMessage` :2801~2838 | 4/7 | 高 | ❌ 需切段器 + 开关，独立成期 |
| 历史 prepend 批内倒序 | `_pushMessages` :2986~2992 | 2（旧消息顺序） | 低 | ✅ 可独立 |
| 每次交互全量重建最近 30 条（性能/状态丢失） | `_pushMessages` 触发账本 A3 | 1/2（放大） | 高 | ❌ 需 diff 更新，独立成期 |
| `#root` 无 DOM 窗口化（百条消息全在 DOM） | shell 无可视化（仅 iframe 虚拟化） | 1（重前端炸） | 高 | ❌ 独立成期 |
| `var doc` 重复声明 + `<script>` 嵌套（引擎房） | shell `createEngineRoom` :4445/4460 | 潜在 | 低 | ✅ 可独立（改引擎房创建 DOc 字符串） |

---

## A10 回档分支失败样本分析（backup/c1-alpha-failed）

五个 commit 的 diff 已逐字核对。结论如下：

### T1 `ed53b33` 单条隔离（**正确，可保留**）
- `_safeSerializeMessage` 包裹单条序列化：方向正确（A8#1 的**批量**完全没保护仍是缺口，但单条保护本身对）。
- JS 循环内逐条 try + 降级占位 `<details>`：**正确**，命中「外层 catch 不抹页」的理念一部分。
- 外层 catch 从 `root.innerText='ERR:'` 改为只 log 保留已渲染：**正确**（对症 6）。
- prepend 批内 `batch.reversed`：**正确**（JS 逐条 `insertBefore(firstChild)`，倒序发才还原正确阅读序）。
- **保留**：T1 的四点应全部捡回。

### T2 `4ad4097` 方案α（**错，是嫌疑主凶**）
- 引入 `segs` 顺序切段：思想对（消息级多段），但**实现有致命副作用**：
  - **JS 侧 `_segsHtml` 一旦非空，纯文本消息也走 blob iframe 分支**（每个文本段被塞进 `_parts`，`_segsHtml` 恒非空）→ **每一条消息（含纯文字）都变成一个带完整 TavernHelper 注入的 blob iframe**，资源暴涨。
  - 若文本内容含 `$(...` 或 `jQuery` 等子串，`injectBridge` 会按需内联 87KB jQuery，进一步放大。
  - `'html'` 兼容字段逻辑在 `segs` 为空/全文本时的 fallback 有歧义。
- **全灭根因（技术判断，排名）**：
  1. 【最可能】批量 `jsonEncode(url.encode)` 的循环前失败（A8#1）被 `segs` 大幅放大体积/new 字符串后触发，第一批没发出 → 无任何 WV 日志。**T1 只保了单条，没保批量。**
  2. 【次可能】每条消息变 iframe 后，视口地板 `max(h,innerHeight)` 让每屏只显示一条且 blob 大批量创建在老 WebView 上静默失败，呈现「完全不渲染」。
  3. 【低】`_segsHtml` 用固定 `<div style="height:10px">` 分隔，把 HTML 段与文本段塞进同一 `data-html` 属性再 `setAttribute`，若内容含 `"` 会截断属性 → iframe 源损坏。
- **错的**：整体不要。多前端必须「消息级 iframe」但要挂在开关后、独立成期，且文本段不该进 iframe。

### T3 `1ed9490` 围栏保护（**方向对，实现有隐患**）
- 用 `\u0001KF<idx>\u0001` 占位把 ```html 围栏先摘后还，保证正则不再破坏围栏：**思路正确**。
- 隐患：若正则把占位符 `\u0001KF0\u0001` 改写（如删掉 `\u0001`），`replaceFirst('\u0001KF$ki\u0001', …)` 找不到占位，围栏内容就**丢失/残留控制字符**。控制字符本身经 jsonEncode 会转义安全，但内容会漏。
- 副作用（用户已问）：摘出保护后**正则再也改不到卡片内 HTML**，而高星卡存在「专门美化状态栏 HTML」的正则。此代价是否可接受见 B2 专门小节。
- **保留**：围栏保护思路可保留，但要点改为「用不可能被正则命中的占位符 + 归还后校验」。

### T4 `03795b9` 流式不清块（**正确，但需补防残留**）
- `appendToken` 不再 `wrap.innerHTML=''`，改为追加独立 `.stream-text` 区：**正确**（对症 5）。
- 缺：reroll 时旧流式文本残留 → 两次回复叠加（「多渲染」）。需在生成结束全量刷新时清掉 `.stream-text`（或按 id 判定）。
- `setImage` 加 `data-img-loaded` 幂等保护：**正确**。

### T5 `9beb998` 自愈上限（**正确**）
- `_wvCrashCount` 会话级 3 次上限，防「崩→reload→再崩」死循环：**正确**。

> 一句话总结：T1/T4/T5 基本可整体捡回；T3 思路可捡但实现要改；T2 是方案错 + 实现放大祸根，舍弃重做。

---

**文档完。**