# P3-E:接通 MVU 数据链(三刀 + 一道甜点)

日期: 2026-08-31 | 基线 commit: `6daf71f`(开工时 `git log --oneline -3` 首行)

---

## 0. 基线确认

```
$ git status --short
 M linux/flutter/generated_plugin_registrant.cc
 M linux/flutter/generated_plugin_registrant.h
 M linux/flutter/generated_plugins.cmake
 M macos/Flutter/GeneratedPluginRegistrant.swift
 M windows/flutter/generated_plugin_registrant.cc
 M windows/flutter/generated_plugin_registrant.h
 M windows/flutter/generated_plugins.cmake
?? DiaoYan/P3/...(前几轮未跟踪交付物)
```
基线 HEAD = `6daf71f`。工作区只有平台生成产物(提交惯例不跟踪)与前几轮 DiaoYan 未跟踪物,干净。

---

## 1. Task E1:引擎房未闭合 `<script>`(commit `ff71768`)

### 1.1 读到的真实结构(1515-1545 改前原文,逐字)

```
1515  + '<script>window.__KIRA_MACRO_VALUES=' + JSON.stringify(macros) + ';<\/script>'
1516  + '<script>window.__KIRA_CHAT_ID=' + JSON.stringify(window.__KIRA_CHAT_ID||'') + ';<\/script>'
1517  + '<script>' + facadeJs + '<\/script>'
1518  + '<script>'
1519  + '  // Trinity: 为 EJS/dist 准备标准 ST 对象'
1520  + '  window.chat = [];'
1521  + '  window.chat_metadata = { variables: {} };'
1522  + '  window.extension_settings = { variables: { global: {} } };'
1523  + '  console.log("[Trinity] 已初始化 chat/chat_metadata/extension_settings");'
1524  + '<\/script>'
1525  + '<script>'
1526  + 'window.__chatMessages=[];'
1527  + '<script>'                 ← 病灶: 块内的裸 <script>
1528  + 'window.__chatMessages=[];' ← 与 1526 完全重复
1529  + 'window.addEventListener("message",function(e){'
...
1539  + '<\/script>'
```

### 1.2 诊断结论

- **1527 是病灶**: 它把 1525 的 `<script>` 块在 HTML 解析层面提前"关"在了一个没有 `</script>` 的地方。
  解析器从 1525 的 `<script>` 起扫到 1539 的 `<\/script>` 才算块结束,因此块内 JS 实际是
  `window.__chatMessages=[];<script>window.__chatMessages=[];window.addEventListener(...)`——
  语句开始处的孤立 `<` 无左操作数 → `Unexpected token '<'`,与真机日志 `@282:18160` 吻合。
  **这一整块(初始化 `__chatMessages` + 注册 `__thEvent` 监听)从未执行** → 引擎房 `__chatMessages` 恒空 → MVU 读聊天记录读到空 → `不存在任何一条消息，退出`。
- **1526/1528 完全重复** → 是同一句被复制了两遍,1528 是多余的。
- 顺带发现 **1508/1509 两行 `var doc = ...` 完全重复**(前者被后者覆盖,死代码,同属拼接混乱)。

### 1.3 改法(3 处删除,共 3 行)

- 删 1527 的 `+ '<script>'`(病灶本体);
- 删 1528 的重复 `window.__chatMessages=[];`(与 1526 重复,保留 1526 即保留语义);
- 删 1509 的重复 `var doc = ...`(死代码,保留 1509 语义不变)。

理由: **删除而非补闭合** —— 补闭合会让一块死 JS 永远留在 doc 里且语义变差;
删除后该块成为语法正确、能执行的整体(初始化一次 `__chatMessages` + 注册监听器),最小改动。

### 1.4 改后产物(引擎房 doc,提取自生产文件,`extract_engine_room_doc.js`)

```
<!DOCTYPE html><html><head><meta charset="utf-8"></head><body><script>window.__KIRA_MACRO_VALUES={"user":"User","char":"Assistant"};</script><script>window.__KIRA_CHAT_ID="test-chat-id";</script><script>  // Trinity: 为 EJS/dist 准备标准 ST 对象  window.chat = [];  window.chat_metadata = { variables: {} };  window.extension_settings = { variables: { global: {} } };  console.log("[Trinity] 已初始化 chat/chat_metadata/extension_settings");</script><script>window.__chatMessages=[];window.addEventListener("message",function(e){if(!e.data||!e.data.__thEvent)return;try{if(e.data.__msgs){window.__chatMessages=e.data.__msgs;if(window.chat){window.chat.length=0;e.data.__msgs.forEach(function(m){window.chat.push(m);});}}if(e.data.type&&window.TavernHelper&&window.TavernHelper.eventEmit){parent.postMessage({__thLog:true,text:"[引擎房] 收到事件 "+e.data.type+", msgs.length="+window.__chatMessages.length},"*");window.TavernHelper.eventEmit(e.data.type,e.data.args||[]);}}catch(err){parent.postMessage({__thLog:true,text:"[引擎房] 事件处理失败: "+err},"*");}});</script><script>setTimeout(function(){try{if(window.TavernHelper&&window.TavernHelper.eventEmit){window.TavernHelper.eventEmit("chat_changed");parent.postMessage({__thLog:true,text:"[引擎房] 自触发 chat_changed"},"*");}}catch(e){parent.postMessage({__thLog:true,text:"[引擎房] chat_changed 失败: "+e},"*");}},300);</script></body></html>
```

### 1.5 E1 验证(新写的拼接产物语法检查,原始输出)

```
$ node DiaoYan/P3/诊断/extract_engine_room_doc.js        (改前)
字面量行取用: 32  跳过(库三元/非字面量): 4  var doc 重置次数: 2
doc 产物长度: 1394
script 块数: 5
block[0] len=62 : PARSE OK
block[1] len=37 : PARSE OK
block[2] len=227 : PARSE OK
block[3] len=620 : PARSE FAIL => Unexpected token '<'   ← 复现真机错误
block[4] len=287 : PARSE OK
ENGINE ROOM DOC: 1 BLOCK(S) FAILED

$ node DiaoYan/P3/诊断/extract_engine_room_doc.js        (改后)
字面量行取用: 29  跳过(库三元/非字面量): 4  var doc 重置次数: 1
doc 产物长度: 1361
script 块数: 5
block[0] len=62 : PARSE OK
block[1] len=37 : PARSE OK
block[2] len=227 : PARSE OK
block[3] len=587 : PARSE OK
block[4] len=287 : PARSE OK
ENGINE ROOM DOC: ALL BLOCKS OK
```

检查链:
```
$ dart run tool/check_chat_stage.dart
── block 1/2  (build/check_block_1.js, 1259 chars)
   OK
── block 2/2  (build/check_block_2.js, 68549 chars)
   OK
SYNTAX OK (2 blocks)
```

**E1 成功判据(日志级):** `Unexpected token '<'` 应消失;`[引擎房] 收到事件` 应出现(1535 行日志原样保留);`不存在任何一条消息，退出` 应消失。E1 之前 `Mvu` 挂了也是空的,现在这块活了,MVU 读聊天记录有数据了。

---

## 2. Task E2:主文档接 `window.Mvu` + card facade(commit `0ced887`)

### 2.1 E2-a:主文档接住 MVU 自挂的全局

`__syncVarsToEngine` 之后新增(主文档):
```js
(function() {
  var _t0 = Date.now();
  var _iv = setInterval(function() {
    if (typeof window.Mvu !== 'undefined') {
      clearInterval(_iv);
      sendToFlutter('log', { text: '[Mvu] 主文档已接到 window.Mvu' });
      return;
    }
    if (Date.now() - _t0 > 10000) {
      clearInterval(_iv);
      sendToFlutter('log', { text: '[Mvu] 等待 window.Mvu 超时(10s), 疑似 should_enable 为假' });
    }
  }, 200);
})();
```
- 依据: 上游 MVU `src/function/global/index.ts` 用 `_.set(window.parent, 'Mvu', mvu)` 自挂到主文档;`initializeGlobal`/`waitGlobalInitialized` 在 beta 源码里不存在(grep 零命中),是 `.d.ts` 描述的新约定,以源码为准。
- MVU 挂在主文档后,这一块日志直接给出**`should_enable` 是否为真的结论**(超时日志本身就是有价值的产出)。

### 2.2 E2-b:card iframe 的 `Mvu` facade(完整成员表)

| 成员 | 实现 | 同步性 |
|---|---|---|
| `getMvuData(opts)` | 读本地 `window.__thVars` 同步快照(见 E3),message_id 经 `__TH_RESOLVE_MID` 解析 | **同步返对象** |
| `replaceMvuData(data, opts)` | 乐观更新本地快照 + `__thCall("setVariables",[data,opt])` 走桥落库 | Promise(官方同) |
| `events` | 硬编码字面量(官方 typo 原样保留): `VARIABLE_INITIALIZED:"mag_variable_initiailized"` / `VARIABLE_UPDATE_STARTED:"mag_variable_update_started"` / `COMMAND_PARSED:"mag_command_parsed"` / `VARIABLE_UPDATE_ENDED:"mag_variable_update_ended"` / `BEFORE_MESSAGE_UPDATE:"mag_before_message_update"` | — |
| `parseMessage(msg, oldData)` | `__thCall("thMvuParseMessage",...)`,失败 catch 后返 undefined(不抛) | Promise |
| `isDuringExtraAnalysis()` | `return false` | 同步 |

### 2.3 `window.Mvu` 延迟定义的时序(关键)

- facade 对象先放 `window.__TH_MVU_FACADE` **暂存**,不直接挂 `window.Mvu`。
- `window.Mvu` 只在**首份含 `stat_data` 的 message 级 MvuData 快照到达**后由 `__thArmMvu()` 挂载:
  ```
  快照信封 __thVars(type=message, data 含 stat_data) → __thArmMvu() → window.Mvu=__TH_MVU_FACADE
  → __thMvuReady=true → 打日志 [Mvu] card(...) 已挂 window.Mvu → _TH.eventEmit("global_Mvu_initialized")
  ```
- 依据: 卡 `waitGlobalInitialized('Mvu')` resolve 后立刻 `getMvuData()`;若在快照到达前挂窗,卡拿到空对象 → 状态栏渲染全 0 **且不报错**。P3-D 的 `waitGlobalInitialized` 是 100ms 轮询、永不超时放弃,天然容忍"快照晚于 patch 执行"——离线 harness 实证: 无快照时 `window.Mvu === undefined`,快照到达后才出现(T7 断言)。

---

## 3. Task E3:变量快照广播到 card iframe(commit `0ced887` + `27e31e8`)

### 3.1 ① 广播(`__syncVarsToEngine` 改动)

原函数只推引擎房。现函数:
1. 先更新主文档快照 `window.__kiraVarSnap = {message:{floorIdx: MvuData}, chat:{}, global:{}, lastMsgId}`(message/chat/global 各分支);
2. **新增 card 广播**: `querySelectorAll('iframe[data-frame-id]:not([data-frame-id="engine-room"])')` 逐个 `postMessage({__thVars:true, type, data, floor_idx, lastMsgId, swipe_id})`。`floor_idx` 仅 message 级带(Dart `_syncVarsToEngine` 的 `messageId` 已是数字楼层下标);
3. **引擎房路径原样保留**(`__varSync` 信封、顺序、返回值都不动)。

Dart 侧配套:
- `_pushInitialVarSnapshots()`(新): 启动/重建后把最近 30 条消息的 swipesData(当前 swipe)逐条 `_syncVarsToEngine('message', ...)`,再补一发 chat 变量 —— 这是**存量聊天数据的第一口奶**: 之前这些数据只在 EJS 渲染/写回时局部进镜像,从不广播;没有它,老聊天里 card iframe 建好也等不到任何快照。调用点: onLoadStop 后 `await _pushMessages(); await _pushInitialVarSnapshots();`(在 `chat_changed` 点火之前)。
- chat 分支写回 `_syncVarsToEngine('chat', readBack)` 补传 `lastMsgId`(card 的 `latest`/负深度解析依赖它)。

### 3.2 ② card 本地快照 store 与 `VariableOption` 映射

store 结构(card 内):
```js
window.__thVars = { message: {floorIdx: MvuData}, chat: {}, global: {}, lastMsgId: -1, swipes: {floorIdx: sid} }
```
`__TH_RESOLVE_MID(option)` 映射(照 `function/variables.d.ts` 的 `VariableOption`):
- `type` 缺省 → `'chat'`; `message_id` 缺省 → `'latest'` → `__thVars.lastMsgId`;
- `message_id` 数字 ≥0 → 直接作 floorIdx;负数 → `lastMsgId+1+mid`(深度索引);
- `message_id === 'latest'` → lastMsgId;
- **扩展**: `message_id === 本 iframe 的字符串 id`(卡的 `getCurrentMessageId()` 返回 `_TH.__lastMsgId`=ifr id)→ 本楼层下标 `__TH_FLOOR_IDX`。这是卡 `syncToMvu` 的实际走法(regex_7 偏移 51786 `const msgId = getCurrentMessageId(); Mvu.getMvuData({type:'message', message_id: msgId})`);
- 解析失败 → 打日志 `[Mvu] getMvuData 解析不到楼层(...), 返回空对象`,返回 `{}`(照指令: 拿不准返空对象而非 undefined)。

`type` 分支:
- `'message'` → `__thVars.message[fi] || {}`; `'chat'/'global'` → 对应表; `'character'` → 无独立快照,回退 chat(带日志);其他 → `__thVars[t] || {}`。

**同步化(本轮关键的额外发现)**: 实测 regex_6 的 `populateCharacterData()` 用的是
`getAllVariables()` + `_.get(all_variables,'stat_data',{})`——不是 `Mvu.getMvuData`!
原 `_TH.getAllVariables` 走 `__thCall`(异步 Promise)→ `_.get(Promise,'stat_data')` 恒空 → **状态栏永远无数字**。
本轮把 card 桥的 `getAllVariables`/`getVariables` 改为读本地快照同步返回(全局→chat→楼层 由近及远叠加,`getAllVariables` 的 message 楼层取 ≤本楼层的最近有效 MvuData,照 MVU `getLastValidVariable` 回溯语义)。离线 harness T3 实证同步返对象且数字在场。

### 3.3 ③ MVU 事件转发链路 + 写回乐观更新

**事件链路(引擎房 → card)**:
```
引擎房 MVU emit → 引擎房 _TH.eventEmit (facade 内)
  → [E3c] 转发点: _TH.eventEmit 内 try{parent.postMessage({__mvuEvent:true,type,args})}catch
  → 主文档 message 监听收到 __mvuEvent → 广播 {__thEvent:true,type,args} 到所有 card iframe(日志 [Mvu] 事件中继 card x<n>)
  → card 端新增 message 监听(__thEvent)→ _TH.eventEmit 本地总线重放 → 卡 eventOn(Mvu.events.VARIABLE_UPDATE_ENDED, ...) 被点火
```
- 无循环风险: card 端的 `_TH.eventEmit` 是 `chat_stage.html` patch 内的另一份实现,**不带** `__mvuEvent` 转发;只有引擎房 facade(tavern_helper_facade.dart)那份带。
- card 侧 store 之后新增 `__thEvent` 监听,事件到达打日志 `[Mvu] card(id) 事件点火 <type> 监听数=<n>`。
离线 harness T6 实证: `eventOn('mag_variable_update_ended', ...)` 注册后,`{__thEvent:true,type:'mag_variable_update_ended'}` 到 card → 监听器被调 x1。

**写回乐观更新**(`__TH_REPLACE_MVU_DATA`):
```
卡 syncToMvu → Mvu.replaceMvuData(data, {type:'message', message_id})
  → 先写本地 __thVars.message[fi] = data(立刻可读新值)
  → __thCall('setVariables', [data, option]) 走桥落库
```
- message 级写回同时过 `__thArmMvu()` 门控(若 stat_data 在场且尚未挂窗);
- 桥的 option 在 TH 中转层经 `__thNormVarOption` 规范化: 字符串 iframe id → `__kiraMsgFloorMap[id]`(setMessages 时维护 id→floorIdx)→ 数字楼层下标,保证 Dart `_handleSetVariables` 落对消息;'latest'/无法解析 → 删 message_id,走宿主自定位(最后一条)。
- **第二次补丁(E3b, commit `27e31e8`)**: `getVariables` 的 option 同样过 `__thNormVarOption`,防字符串 id 透传 Dart 查错楼层。

---

## 4. `th_setVars` 是 merge 还是 replace 的结论(记账项,不改)

**结论: 现实现是「按 key 逐个合并」(merge),不是官方 `replaceVariables` 的完全替换。**

证据(读 Dart 实现,未改):
- `webview_chat_stage.dart:1518-1577` `_handleSetVariables`:
  - `type=='global'`: `for (entry in vars.entries) await service.setGlobalVariable(entry.key, entry.value)` —— **逐 key 写**,不删旧 key;
  - 默认 chat: `for (entry in vars.entries) service.setLocalVariable(...)` —— **逐 key 写**;
  - `type=='message'`: `newSwipesData[swipeId] = Map<String, dynamic>.from(vars)` —— 整表覆盖消息的 swipesData(这条倒是整份替换,但替换的是"消息这一份 MvuData",不是合并)。
- 语义后果(与指令 §5 记账一致): 若卡期望 `replaceVariables` 删掉不存在的 key(如 `_.unset` 后整表 replace),**删除永不生效、旧 key 永久残留**。regex_6 的 `deleteStatEntry` 走 `_.unset(fullData.stat_data, path)` 后 `replaceMvuData(fullData,...)`——fullData 里已无该 key,但 `setVariables` 逐 key 合并的是 vars 里的 key,所以该 key 不会被写回……实际影响是: 卡读 getMvuData(本地快照)已无该 key,但 Dart 持久层仍残留旧 key;下次快照广播会把残留带回。**这是记账项,本轮不改**(超范围)。

---

## 5. Task Z:全局世界书入口恢复(commit `665ad3c`)

- **删死文件**: `lib/domain/services/world_book_injection_service.dart`(3 字节 BOM,全项目零引用,grep 确认;真正的注入路径在 `chat_providers.dart:1932/1947` 走 prompt_manager)。
- **捞回类**: 用 `git show 3255cec^:...world_info_screen.dart` 提取 `WorldInfoScreen` / `_WorldInfoCard` / `_WorldInfoDialog`(829 行)合并进现有 `world_info_screen.dart`(在 `WorldInfoEntriesScreen` 之前,import 完全一致无需新增)。
- **路由收窄**: `/world-info` 恢复,但 `app_router.dart` 的 GoRoute **只构造 `WorldInfoScreen(isGlobal: true)`,彻底不读 `characterId` query 参数**——双模歧义(两个参数都不传 → 列全部世界书 → 错误列表)被结构性消除。
- **入口**: 只恢复 `ai_config_screen.dart` 一处 `KiraListTile(icon: Icons.public, title: '全局世界书', subtitle: '对所有角色生效的世界书', onTap: () => context.push('/world-info?isGlobal=true'))`;`chat_screen.dart`/`chat_app_bar.dart` 入口**不恢复**(角色维度已有 `character_detail_screen.dart:1161` 与 `character_editor_screen.dart:318` 直达 EntriesScreen)。
- **验证(静态推理,未跑真机)**: `WorldInfoScreen.build` 的 `displayInfos` 在 `isGlobal=true` 时 `infos.where((w) => w.isGlobal)`(现文件 51 行)——从设置页进入即只显示 `isGlobal==true` 的世界书;`WorldInfoScreen` 的 `characterId` 字段路由永远不传(恒 null),因此永远不会走 `characterId != null` 分支。dart analyze 对 `world_info_screen.dart`/`app_router.dart`/`ai_config_screen.dart` 零 error、无新增 warning(与改动前基线 51 条同口径对比)。

---

## 6. 所有拼接改动的拼接后 JS 全文(铁律 3 盲区自证)

- **引擎房 doc 全文**: 见 §1.4(改后,由 `extract_engine_room_doc.js` 从生产文件提取)。
- **injectBridge patch 全文**(含 E2/E3 新增段): `DiaoYan/P3/诊断/out/inject_patch_extracted.html`(18291 字节,提取自生产文件,包含 `<script>` 内层全量 JS)。核心新段(E2 facade / E3 store)节选:
```js
window.__TH_MVU_FACADE={events:{VARIABLE_INITIALIZED:"mag_variable_initiailized",VARIABLE_UPDATE_STARTED:"mag_variable_update_started",COMMAND_PARSED:"mag_command_parsed",VARIABLE_UPDATE_ENDED:"mag_variable_update_ended",BEFORE_MESSAGE_UPDATE:"mag_before_message_update"},getMvuData:function(option){return __TH_GET_MVU_DATA(option);},replaceMvuData:function(mvu_data,option){return __TH_REPLACE_MVU_DATA(mvu_data,option);},parseMessage:function(message,old_data){return __thCall("thMvuParseMessage",[message,old_data||{}]).catch(function(err){...return undefined;});},isDuringExtraAnalysis:function(){return false;}};
window.__thVars={message:{},chat:{},global:{},lastMsgId:-1,swipes:{}};
function __thArmMvu(){...window.Mvu=window.__TH_MVU_FACADE;...}
window.addEventListener("message",function(e){var d=e.data;if(!d||!d.__thVars)return;...});
__TH_RESOLVE_MID=function(option){...};  __TH_GET_MVU_DATA=function(option){...};  __TH_REPLACE_MVU_DATA=function(mvu_data,option){...乐观更新+__thCall("setVariables",...)...};
function __thBuildAllVars(){..._deep(global)→_deep(chat)→回溯最近有效message...}
_TH.getAllVariables=function(){return __thBuildAllVars();};  _TH.getVariables=function(option){...};
```
- 引擎房 facade(tavern_helper_facade.dart)E3c 改动节选(`_TH.eventEmit` 内, commit `7a43f76`):
```js
// 原有 th_unique_check 强制逻辑后追加:
'try{parent.postMessage({__mvuEvent:true,type:type,args:args},"*");}catch(_fwdE){}'
'var l=(_TH.__events[type]||[]).slice();'
```
该文件是 Dart 单引号字符串拼接(无多行字符串、无 Dart 转义序列表示 JS 换行,铁律 4 合规);`dart analyze lib/presentation/screens/chat/tavern_helper_facade.dart` → `No issues found!`。

---

## 7. 每 commit 的三条验证命令原始输出

### commit `ff71768`(E1)
```
$ dart run tool/check_chat_stage.dart
── block 1/2  (build/check_block_1.js, 1259 chars)
   OK
── block 2/2  (build/check_block_2.js, 68549 chars)
   OK
SYNTAX OK (2 blocks)
$ dart analyze
1211 issues found.   ← 全部 info/warning,0 error(基线 1190-1211 波动,本轮无 error)
$ git status --short
 M assets/chat/chat_stage.html
 M linux/flutter/generated_plugin_registrant.cc  ...(平台产物,惯例不提交)
```
E1 额外:
```
$ node DiaoYan/P3/诊断/extract_engine_room_doc.js
字面量行取用: 29  跳过(库三元/非字面量): 4  var doc 重置次数: 1
doc 产物长度: 1361
script 块数: 5
block[0] len=62 : PARSE OK
block[1] len=37 : PARSE OK
block[2] len=227 : PARSE OK
block[3] len=587 : PARSE OK
block[4] len=287 : PARSE OK
ENGINE ROOM DOC: ALL BLOCKS OK
```

### commit `0ced887`(E2/E3)
```
$ dart run tool/check_chat_stage.dart
── block 1/2  (build/check_block_1.js, 1259 chars)
   OK
── block 2/2  (build/check_block_2.js, 81056 chars)
   OK
SYNTAX OK (2 blocks)
$ dart analyze
1190 issues found.   ← 0 error
$ git status --short
 M assets/chat/chat_stage.html
 M lib/presentation/screens/chat/webview_chat_stage.dart
 M linux/flutter/generated_plugin_registrant.cc  ...(平台产物)
```
E2/E3 额外:
```
$ node DiaoYan/P3/诊断/extract_inject_bridge_patch.js
patch 总长: 18073
script 块数: 1
block[0] len=17947 : PARSE OK
INJECT PATCH: ALL BLOCKS OK
$ node DiaoYan/P3/诊断/harness_e2_e3_offline.js   (19 断言)
[T1] PASS window.Mvu 已定义 / events.VARIABLE_UPDATE_ENDED / events.VARIABLE_INITIALIZED 保留官方 typo
[T2] PASS 同步返对象(非 Promise) / stat_data.主角.生命 === 87 / 'latest' → lastMsgId=3 / -1 深度索引 / type=chat
[T3] PASS getAllVariables 同步返对象 / 叠加 stat_data / chat 变量在场
[T4] PASS replaceMvuData 返 Promise / 乐观更新立刻可读 生命=99 / 桥请求 setVariables 已发 / option.message_id=3
[T5] PASS waitGlobalInitialized resolve 出 facade
[T6] PASS eventOn 注册的监听被点火 x1
[T7] PASS 无快照 → Mvu 保持 undefined / 仅 chat 快照(无 stat_data) → Mvu 仍 undefined
==== ALL 19 ASSERTS PASSED ====
```

### commit `665ad3c`(Task Z)
```
$ dart analyze
1210 issues found.   ← 0 error
$ git status --short
 D lib/domain/services/world_book_injection_service.dart
 M lib/presentation/router/app_router.dart
 M lib/presentation/screens/ai_config/ai_config_screen.dart
 M lib/presentation/screens/world_info/world_info_screen.dart
```

### commit `27e31e8`(E3b)
```
$ dart run tool/check_chat_stage.dart
── block 1/2  (build/check_block_1.js, 1259 chars)
   OK
── block 2/2  (build/check_block_2.js, 81069 chars)
   OK
SYNTAX OK (2 blocks)
$ node DiaoYan/P3/诊断/harness_e2_e3_offline.js  →  ALL 19 ASSERTS PASSED
$ dart analyze  →  1210 issues found. 0 error
```

### commit `7a43f76`(E3c)
```
$ dart run tool/check_chat_stage.dart
── block 1/2  (build/check_block_1.js, 1259 chars)
   OK
── block 2/2  (build/check_block_2.js, 81069 chars)
   OK
SYNTAX OK (2 blocks)
$ dart analyze  →  1210 issues found. 0 error
$ dart analyze lib/presentation/screens/chat/tavern_helper_facade.dart
Analyzing tavern_helper_facade.dart...
No issues found!
```

---

## 7.5 commit 总览

```
$ git log --oneline -5 --no-decorate
27e31e8 fix(wv): P3-E3b TH中转getVariables也走__thNormVarOption规范化message_id
665ad3c feat(worldinfo): P3-E/Z 全局世界书入口恢复
0ced887 feat(wv): P3-E2/E3 Mvu数据链接通
ff71768 fix(wv): P3-E1 引擎房doc拼接修病灶
6daf71f fix(wv): P3-D3 ...(基线)
```

---

## 8. 真机复测说明(写给人类)

1. **确认资产重打包**: 
   ```
   Get-ChildItem build -Recurse -Filter chat_stage.html
   ```
   文件长度必须与 `assets\chat\chat_stage.html` 一致,且能 grep 到本轮新标记(如 `__thVars`、`__TH_MVU_FACADE`、`[Mvu] 主文档已接到`)。**曾因资产未更新白测一轮。**
2. **必须完全重启 App,禁止热重载**(热重载不刷新 iframe 内联代码)。
3. 存日志: `flutter run 2>&1 | Tee-Object -FilePath DiaoYan\P3\run.log`
4. grep `引擎房`: 期望
   - `Unexpected token '<'` **消失**(E1);
   - `[引擎房] 收到事件` **出现**(E1 的块活了);
   - `不存在任何一条消息，退出` **消失或减少**;
   - `[引擎房] 变量同步 chat/message` 仍正常(引擎房路径未被改坏)。
5. grep `Mvu`: 期望
   - `[Mvu] 主文档已接到 window.Mvu`(**E2-a 成功**);
   - 或 `[Mvu] 等待 window.Mvu 超时(10s), 疑似 should_enable 为假` —— 那也是有效结论,下一轮查选主逻辑;
   - card 侧 `[Mvu] card(<id>) 已挂 window.Mvu(快照门控通过)`(每个状态栏 iframe 一条);
   - `[Mvu] getMvuData 解析不到楼层` 出现说明某卡传了无法解析的 message_id(可查,不致命);
   - `[变量同步] 已广播 card x<n>` 出现说明广播路径活。
6. grep `CARD-ERR`: 报出还剩什么错。
7. **看眼睛能看的**: 状态栏里有没有数字(好感度、生命/灵力/修为进度条数值)。

---

## 9. 我没能验证的部分(如实)

1. **真机未跑**: 所有验证都是离线节点(拼接产物语法检查 + vm 沙箱断言)。引擎房→主文档→card 的 MVU 事件链路三跳都已实现(E3c 补齐最后一跳),但**端到端只验到"card 端能点火"**(harness T6),引擎房真实 MVU bundle 发出事件后的全链路未实测。
2. **`window.Mvu` 是否真的出现未实测**: 取决于 MVU bundle 的 `store.should_enable`/选主逻辑,日志会给出结论(E2-a 的 10s 超时日志就是为此设计的)。
3. **Dart 侧 `th_setVars` 的 merge/replace 结论是静态阅读**——未做真机删除-回读验证。
4. **Task Z 未跑真机**: 设置页进全局世界书只做了静态推理(§5)。
5. **存量快照推送时机**: `_pushInitialVarSnapshots` 在 onLoadStop 的 `_pushMessages` 之后调用,但 Dart 的 evaluateJavascript 与 setMessages 的 base64 桥是并行的——极端时序下 card 的 `__thRequestSnap` 索要可能先于快照推送。已用"广播本身也到 card"兜底,但未实测竞态。
6. **harness 未跑卡的真实 `init()` 全流程**: 离线沙箱只验了桥面断言,没有把 regex_6 整个 183KB 脚本灌进去跑(需要 DOM/后端桥更完整的桩,留给下一轮)。

---

## 10. 记账(发现但不动手)

- **MVU 事件端到端**(§9.1): 三跳代码全在,但依赖 E1 后引擎房监听活、E2-a 后 MVU 真的初始化(should_enable),真机日志 grep `[Mvu] 事件中继 card x` 与 `[Mvu] card(...) 事件点火` 可定位断点。
- **th_setVars 是 merge**(§4): `_.unset` 删除永不生效(持久层残留),官方语义是 replace。待独立成轮改 `_handleSetVariables` 为"message 级整表替换 + chat/global 合并"(或按官方 replace 语义)。
- `_handleSetVariables` 的 message_id 语义: 数字楼层下标,但若卡传 `'latest'`(宿主自定位)会落到**最后一条消息**,与 MVU `getLastValidVariable` 的"从末尾回溯"读取语义基本一致,但 `'latest'` 显式指向时落最后一条与官方"最新消息楼层"有细微差异(官方 latest = 真正最新有变量的一楼)。
- 多围栏丢弃 / 世界书 API 命名对齐 / `_normalizeCodeQuotes` 块外属性 / `window.onerror` 双挂 / `depth: i` 语义 / `RegexScript.fromJson` 硬 cast / mvu_bundle 版本差异 / `klona`/`z` 未确认 —— 照抄指令 §5,均未动。
- 设置页入口的 `'全局世界书'` 无 i18n key(TODO(i18n) 照原样恢复)。
