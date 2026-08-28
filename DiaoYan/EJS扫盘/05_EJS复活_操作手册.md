# 05 · EJS 复活 · 可落地操作手册

> 阶段 B 产出 · 二次读源码核对完毕 · 本手册经人类过目后才施工。
> 承接 00/01/02/03 文档;雷区编号(X1-X10/P1-P20)沿用 02/03 清单。
> tag 基线:`ejs-recon-b-start`。每个 Task 一个 commit,可独立回退。

---

## 0. 结论速览

| 项 | 判定 |
|---|---|
| 路线终裁 | **路线 A'(改良)**:直接调用 dist 自带的纯渲染函数 `EjsTemplate.evalTemplate()`。不修 checkScript、不 emit 新事件、不自建渲染器 |
| 挂点 | **零新增点火**:现有 `_renderEJSInMessages`(llm_service.dart)就是安全挂点,只换它底层的渲染实现 |
| P9 yaml 桩 | **无关,结案**(MVU 自带完整 yaml 库) |
| 高星卡变量不初始化真凶 | **新确诊:facade 缺 `getCharWorldbookNames` 别名**,MVU 调它必 ReferenceError → 开场白 initvar 整个事务中止 |
| P5 丢档炸弹 | 最小修法落点已定,Task 0 先拆 |

---

## 1. 路线终裁:路线 A'(单选)

### 1a. 二次核实的颠覆性事实

【实证】ejs_bundle.js 根本不是酒馆助手 dist,而是 **ST-Prompt-Template 扩展**(尾部自曝:`info:{id:"ST-Prompt-Template",name:"Prompt Template"}`)。它导出 `default/init/exit/info`,被注入引擎房后 **加载即自启**(`$((async()=>{await ig()}))()`,jQuery ready 触发),并挂出全局:

```js
globalThis.EjsTemplate = {
  evalTemplate: async function(template, vars=null, options={}) {
    // isDryRun=false → 取上下文 Hf() → 核心 Xf() 求值
    // 返回渲染后文本 —— 正是"模板+变量→输出"的纯函数
  },
  prepareContext, getSyntaxErrorInfo, setFeatures, resetFeatures,
  allVariables, saveVariables, defines...
}
```

### 1b. 三问三答

**① dist 里有没有可直接调用的"模板+变量→文本"纯函数?——有,就是 `evalTemplate`。**
且该路径不经过 `enabled` 闸门(闸门只在事件处理器 Mv/Nv/Uv/Lv/Rv/Bv 上,默认值也全是 true:settings 表 `{name:"enabled",value:!0}` 等)。模板作用域(Hf/prepareContext)含:variables getter(接 chat[].variables / chat_metadata.variables / extension_settings.variables.global——正是我们 Trinity 镜像喂的三层)、userName/charName、chatId、SillyTavern.getContext()、execute(slash,stub 返回空,非致命)、世界书引用(stub 安全链)。**变量上下文现成可用,不用我们喂第二遍。**

**② 复活 dist 会不会引爆 P8 自嗨/X5 点火链?——不会,因为根本不碰事件总线。**
关键认知:P8 的"顶层自嗨"**今天就在发生**(init 已随每次建引擎房运行;CHAT_CHANGED 我们有发,Rv 世界书预演在跑;MESSAGE_RECEIVED 我们有发,Vv→Nm 只在引擎房镜像里克隆变量,无实害)。而 evalTemplate 是**直调函数,不 emit 任何事件**→ X5 的 generation_started/message_received 频率一个都不变,P4 双发现状原样冻结。唯一要避开的是**不要**为了渲染去补发 GENERATION_AFTER_COMMANDS/CHAT_COMPLETION_SETTINGS_READY:Mv 会摸 `extension_settings.regex`(stub 没有,会抛),且会波及 MVU 共用的本地事件桶(X1/X5)。
顺带破案:**"路 A=修 checkScript"是伪命题**——那段死代码只想从 module 导出挂 `substituteParams`(宏替换),从来给不了真 EJS。阶段 A 的倾向 B 的前提(dist 无纯函数)已被推翻。

**③ 路 B 自建渲染器的代价?——可行但全面劣势,弃。**
lodash `_.template` 改分隔符确能模拟 `<%%>` 语法(lodash 已在引擎房注入,体积为零),但:作用域要自建三层变量 getter、{{user}} 宏与 EJS 双轨维护、和上游卡片的真实语义永远差一截。既然 evalTemplate 现成,**路 B 的全部工作量反而更大**。

### 1c. 终裁

**选路线 A':在 `_handleRenderEJS` 里直调引擎房的 `window.EjsTemplate.evalTemplate()`。**
失败回退链:evalTemplate 不存在/抛错 → `_TH.substituteParams`(宏替换,即现状)→ 原文。永不阻断发送。

## 2. 施工步骤(按序执行,每 Task 一 commit)

### Task 0 · 拆 P5 丢档炸弹(清场,独立于 EJS)

- 目标文件:`lib/domain/services/variables_service.dart` + `lib/core/services/initialization_module.dart`
- 锚点:VariablesService 的 `initialize()`/`_loadGlobalVariables`;InitializationModule 的 `create()`
- 改动:
  1. VariablesService 加 `_loaded` 幂等旗,`initialize()` 开头 `if (_loaded) return;` 成功后置位;
  2. `setGlobalVariable/addGlobalVariable/increment/decrement/clearGlobalVariables` 等所有全局写路径开头 `await initialize();`(先加载后写);
  3. InitializationModule.`create()` 里补一行 `await VariablesService.instance.initialize();`(启动即加载)。
- 风险:🟢(纯只读前置化,不改任何写语义)
- 排雷:**X4**——本步就是修 X4 的根(懒加载空表覆盖 SP 存档)。不碰任何 WebView 侧路径。
- 验证:`dart analyze`;真机:冷启→不开设置页→让角色卡写全局变量→设置页里旧变量仍在。
- 回退点:单 commit revert。

### Task 1 · facade 补 `getCharWorldbookNames` 别名(高星卡变量初始化真凶修复)

- 目标文件:`lib/presentation/screens/chat/tavern_helper_facade.dart`
- 锚点:「MVU实际喊的短名 getCharLorebooks」那三行裸挂之后
- 改动(两行):
  ```js
  '_TH.getCharWorldbookNames=function(t){return __thCall("getCharacterLorebooks",[]);};'
  'window.getCharWorldbookNames=_TH.getCharWorldbookNames;'
  ```
- 依据【实证】:mvu_bundle 内 `getCharWorldbookNames('current').primary??'unknown'` 全 bundle 仅此一处调用、零定义;facade 现无此名 → 开场白含 `<initvar>` 的卡必 ReferenceError → Promise.all 整体 reject → `setChatMessages` 中止 → stat_data 算了但没落库。Dart 侧 `_handleWiGetCharLorebooks` 返回 `{primary, additional}`,形状与 MVU 期望完全一致,别名即通。(参数 t 暂忽略:'current' 语义=当前角色,与现 handler 一致。)
- 风险:🟢(新增 API 名,不动既有接口)
- 排雷:**X9**(身份谎报组)——这是给 facade 增名,不改 getScriptId/选主逻辑,MVU 启动前提不受影响。
- 验证:`dart analyze`;真机:用带开场白 initvar 的卡新建聊天→日志看不再出现 ReferenceError、`[setVars落点]`/swipes_data 出现 stat_data。
- 回退点:单 commit revert。

<!-- M2 -->

### Task 2 · 真 EJS 渲染接入(主线)

- 目标文件:`lib/presentation/screens/chat/webview_chat_stage.dart`
- 锚点:`_handleRenderEJS`(注释「EJS 渲染桥:接收文本,发进引擎房跑 dist 的 EJS」——注释终于要变成事实)
- 改动:仅替换该函数体内执行的 JS 片段(仍走 `controller.evaluateJavascript`,外层页面执行),逻辑:
  ```js
  (async function(){
    try{
      var host=document.getElementById('__engineRoomHost');
      var f=host&&host.querySelector('iframe[data-frame-id="engine-room"]');
      var w=f&&f.contentWindow;
      if(w&&w.EjsTemplate&&typeof w.EjsTemplate.evalTemplate==='function'){
        var t=<jsonEncode后的原文>;
        var out=await w.EjsTemplate.evalTemplate(t);   // 真 EJS
        return String(out);
      }
      // 回退1:宏替换(现状行为)
      if(window._TH&&window._TH.substituteParams)return window._TH.substituteParams(t);
      return t;
    }catch(e){
      try{parent.postMessage({__thLog:true,text:'[EJS渲染错误] '+((e&&e.stack)||e)},'*');}catch(_){}
      return t;   // fail-open:渲染失败绝不阻断发送
    }
  })()
  ```
  细节:①先宏后 EJS 不必叠加——evalTemplate 作用域不含 {{user}} 宏替换(stub 的 substituteParams 才管),若卡片混用两种语法,可在 evalTemplate 前先过一遍 `_TH.substituteParams`;②`evaluateJavascript` 对 Promise 的解析在 flutter_inappwebview v6 可用,**需真机确认**(见第 5 节 V2),若返回 null 则启用 Plan B:把该 IIFE 注入引擎房内、经既有 `__thRequest` 通道往返。
- 风险:🟡(改的是唯一 prompt-out 渲染路径;fail-open 兜底使最坏情况=退化为现状)
- 排雷:**X5**(点火链)——本 Task 零新增 emit;不触碰 _sendMessage 与 isGenerating watcher。**X1**(变量镜像)——evalTemplate 只读镜像,模板里的 setvar 类写操作走 dist 自己的 variables setter 落在镜像层,不落库(与上游"prompt 渲染期写变量不持久化"语义一致,可接受);**X7**——不动两份 tavern_events 表。
- 挂点安全性论证(核对 2 正答):调用链 `_sendMessage → notifier.sendMessage → buildMessages(宏) → llm_service.generateStreamWithReasoning → _renderEJSInMessages → registry → 本函数`。挂点位于 **MVU 已点火之后(generation_started 在 sendMessage 前已发)、发给 LLM 之前**,且只读消费消息数组、不发任何事件。X5 硬要求满足。
- 验证:`dart analyze`;真机按第 5 节脚本。
- 回退点:单 commit revert(回退后即现状宏替换,无残留)。

### Task 3 · P2 死代码修正(顺手,任何路线下都成立)

- 目标文件:同上
- 锚点:createEngineRoom 内唯一一处 `checkScript.textContent = ...`(含整段反引号模板)
- 改动:删除 `checkScript.textContent = \`...\`;` 整块(变量从未定义,行必抛 ReferenceError 被 catch,导致「[引擎房] EJS 模块已注入」日志永不出现、「EJS 注入失败」误导排障);删后在 dist 模块 append 之后补一行成功日志。
- 风险:🟢(纯删除永不执行的代码 + 日志纠偏)
- 排雷:**P2/P8**——注意别误删其上方 dist 注入段(`ejsMs.src=distUrl; appendChild` 必须保留)。
- 验证:`dart analyze`;真机:建引擎房后日志出现「[引擎房] EJS 模块已注入」且不再出现「EJS 注入失败: ReferenceError」。
- 回退点:单 commit revert。

<!-- M3 -->

### Task 4 · P6 调试残迹清理

- 目标文件:`lib/presentation/screens/chat/webview_chat_stage.dart`
- 可安全删除清单(锚点均为内容):
  1. `_sendMessage` 开头 `print('🧪 _sendMessage 被调用了,这是测试探针');`
  2. `_serializeMessagesForMvu` 开头整段 `[base定位]` debugPrint 循环(两处,含 `swipesData=jsonEncode(...)` 全量 dump 与「存储A stat_data=」)——长聊天性能拖累+变量内容进日志;
  3. 同函数尾部两个空循环(`for (final r in result) {}` 与 `for (var i = 0; i < messages.length; i++) {}`);
  4. 另一个序列化函数(`_handleGetMessages`)尾部同款空循环 `for (final r in result) {}`;
  5.(可选🟢)facade 内 lodash throttle 探针块(「[探针] typeof _=...」)——纯日志,可留待下轮。
- 风险:🟢(1-4 为零逻辑残迹;删除不影响任何行为)
- 排雷:无(均不触碰 X 系雷区;**不要顺手改这些函数的其它逻辑**)。
- 验证:`dart analyze`;发送一条消息确认无功能异常。
- 回退点:单 commit revert。

---

## 3. 两管线悬案终答(手册覆盖两条路的挂点)

【实证】开场白与 LLM 消息在 **prompt-out 是同一条路**:buildMessages 的 history 组装把全部消息(含第 0 条开场白,原文 content)放进 messages(chat_providers.dart history 段),随后整体过 `_renderEJSInMessages`。→ **Task 2 一个挂点同时覆盖"LLM 消息 EJS"和"开场白 EJS 进 prompt"**,无需第二接线。
**显示路(气泡内所见)本轮不动**:显示域属禁区,开场白里的 `<% %>` 在气泡中仍以原文出现(现状即如此,历史现象「标签能出现」= 原文直出)。如未来要气泡内渲染,须解禁显示域另立 Task,本手册不擅自扩权。

## 4. 战场二存量雷基线(本轮不修、仅记录;施工期自爆则据实处理)

| 雷 | 判定 | 本轮处置 |
|---|---|---|
| P4 generation_started/chat_changed 双发 | 【确诊】MVU initCheck 每轮跑两次 | 冻结原状;Task 2 明确不新增任何 fire |
| P9 yaml 空桩致 initvar 失败 | **无关,结案**(MVU 自带 yaml 库:Parser/parseDocument/stringify 全套实证);真凶已升级为 Task 1(getCharWorldbookNames 缺失,静态确诊) | Task 1 修复 |
| P10 getLorebookSettings 返回空全局书单 | 【疑似】全局世界书 initvar 不触发 | 记录;若真机验证仍缺全局书变量再立项 |
| P13 swipesData 并发写无锁 | 【疑似】读-改-写竞态丢变量 | 记录;出现丢变量个案时再加单飞锁 |
| 附:mvu_bundle.js 内含前次施工留下的 `[MVU探针]` console.error 日志 | 【实证·资产层残迹】 | 本轮不动产物;日志通道反而可复用于验证 |

## 5. 人类真机验证脚本(渲染结果只有真机能看)

准备:一张**带变量条件的高星卡**(开场白或世界书含 `<initvar>`,AI 回复模板含 `<% if (getvar(...) ...) %>♪<% } %>` 类分支;没有现成卡就手写一条 system 世界书条目:`测试 <% if (1+1===2) { %>EJS活了<% } %>`)。

- **V0 · Task 0/1 回归**:冷启 app → 直接进聊天发一条消息 → 打开设置页变量页:全局旧变量未丢;新建带 initvar 开场白的聊天 → 日志搜 `ReferenceError`(应为 0 条)、搜 `setVars落点`(应见 stat_data)。
- **V1 · 引擎房健康**:进聊天页 → 日志应出现「[引擎房] EJS 模块已注入」(Task 3 后),不再出现「EJS 注入失败: ReferenceError」。
- **V2 · evalTemplate 通路**:发一条普通消息 → 日志无 `[EJS渲染错误]`;若接了临时日志,确认走的是 evalTemplate 分支而非回退。**若渲染结果恒等于原文且无错误日志,优先怀疑 evaluateJavascript 未 resolve Promise → 启用 Plan B(引擎房内注入 + __thRequest 往返)。**
- **V3 · 控制流真活**(核心验收):让 AI 回复含 `<% if %>` 分支的文本,或临时在世界书/system 注入 `测试 <% if (1+1===2) { %>EJS活了<% } %>`:
  - prompt-out 验证:开 LLM 请求日志(llm_service 已有完整请求 dump),在发给模型的 messages 里找到该条 content——应显示「测试 EJS活了」而不是原始 `<%` 标签;
  - 变量条件验证:先用宏/setvar 把某变量设为已知值,再让模板按它分支,确认分支走向随值变化。
- **V4 · MVU 共存回归**:同一轮对话确认 MVU 状态栏/变量更新仍正常(message_received 点火链未受扰):日志有 `[点火] message_received`、`[setVars落点]`;变量面板数字照常累加。
- **V5 · 失败回退**:把模板故意写错(如 `<% if( %>`)→ 发消息不炸、正常收到回复、日志出现 `[EJS渲染错误]`,内容为原文直出。

## 6. 施工顺序与回退总策略

```
Task 0(P5拆弹)→ Task 1(initvar真凶)→ Task 2(EJS主线)→ Task 3(P2死代码)→ Task 4(残迹)
```
- 每 Task 独立 commit,出问题单点 revert;
- Task 2 是唯一 🟡,其 fail-open 设计保证 revert 前的最坏情况也只是"退化成现状";
- 全程零新增事件 emit:X5/P4 状态冻结;两份 tavern_events 表(X7)不动;
- assets/libs 两个 bundle 文件本轮**一个字节都不改**(含其中已有的 [MVU探针] 残迹,留作观测通道)。

## 7. 本手册的证据边界

- 【实证】均来自阶段 A/B 两轮只读源码比对(bundle 反查 + facade/Dart 全链);
- 【需真机】仅三项:evaluateJavascript 对 Promise 的解析(V2)、evalTemplate 在真实卡片模板上的行为(V3)、initvar 修复后的端到端落库(V0/V4);
- dist/mvu_bundle 为压缩产物,函数名(Mv/Nv/Uv/Hf/Xf 等)是 minified 别名,语义依据调用上下文判定,施工时以日志实测为准。

