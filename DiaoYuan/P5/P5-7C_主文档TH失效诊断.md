# P5-7C：主文档 TH 失效诊断

> 诊断对象：P5-6 报告声称完成的阶段2.1/2.2（commit `4300f54`）为何真机无效。
> 用户症状：① 道渊四报警还在；② 世界书下拉没内容；③ 预设球点击只闪一下、写入失败；④ 日志 `[主环境] __KIRA_MAIN_ENV 注入缺失,降级空对象`。
> 方法：静态链路逐段还原 + git 历史追溯 + 与道渊/双人成行卡脚本（`DiaoYan/scripts/*.pretty.js`）逐调用对照。

## 结论先行

| # | 症状 | 根因 | 性质 |
|---|---|---|---|
| 1 | `[主环境]` 注入缺失日志 | HTML 静态 script 在 `onLoadStop` 之前同步执行 + 骨架闭包只读一次 → `__KIRA_MAIN_ENV` **必然**读不到 | 时序设计缺陷（每次加载必现，非偶发） |
| 2 | 世界书下拉没内容 / 报警2、3 数据链断 | 主文档 TH **把桥 type 字符串当 method 名**传进 `__thCall` → 查共享方法表 miss → 全部 reject。iframe facade 同样犯此错（`503f91f` 引入） | **致命 bug：世界书读/写全断** |
| 3 | 预设球"闪一下" | `renderSections` 的 toggle 按钮发送的是**当前状态**而非**目标状态**（极性反），Dart 永不翻转；球 LED 靠 80ms MutationObserver 回弹 = "闪一下" | 503f91f 引入的极性 bug |
| 4 | 四报警还在 | 报警1/2/4 读的是 **iframe facade**（脚本房 `SillyTavern.extensionSettings`），不是主文档 env；facade 缺 `EjsTemplate` 键与 `通知` 四键 → 恒亮。P5-6 的 env 注入修错了对象 | 修错对象 + 已知遗留 |

**一句话**：P5-6 报告"完成"的代码都在、都执行了，但 (a) `_injectMainEnv` 的消费方（HTML 骨架）在注入前就已定型并降级；(b) 主文档 TH 世界书 API 从上线第一天起就是"查表必 miss"的实现，静态检查不可能发现，真机未测所以报告写了"完成"。

---

## 1. `__KIRA_MAIN_ENV` 注入缺失——时序缺陷

### 证据链

- 定义：`webview_chat_stage.dart:331-354` `_injectMainEnv` → `window.__KIRA_MAIN_ENV={mvu:{...},ejsLoaded:...}`。
- 调用点：`webview_chat_stage.dart:902`，在 `onLoadStop` 回调链中。
- 消费方：`chat_stage.html:1405-1425` SillyTavern 骨架：

```js
(function () {
  if (window.SillyTavern) return;
  var env = window.__KIRA_MAIN_ENV;   // ← 页面加载瞬间执行
  if (!env) {
    env = {};
    try { sendToFlutter('log', { text: '[主环境] __KIRA_MAIN_ENV 注入缺失...' }); } ...
  }
  var mvuSnap = (env && env.mvu) || {};
  window.SillyTavern = {
    getContext: function () {
      return { extensionSettings: {
        mvu_settings: mvuSnap,          // ← 闭包捕获的是降级后的空对象
        EjsTemplate: { enabled: !!(env && env.ejsLoaded) }
      }};
    }, ...
  };
})();
```

### 根因

1. `chat_stage.html` 经 `InAppWebViewInitialData`（`webview_chat_stage.dart:798`）加载，页面 `<script>` 在**文档解析时同步执行**；
2. Dart 侧 `evaluateJavascript` 注入只能在 `onLoadStop`（文档加载完成）之后发生 → **静态 script 执行时 `window.__KIRA_MAIN_ENV` 必为 undefined**；
3. 骨架用 IIFE 闭包**一次性捕获** `env`，即使 Dart 随后成功注入 `window.__KIRA_MAIN_ENV`，`getContext()` 仍永远返回闭包里的空对象。

所以该 warn 日志**每次进聊天页必打一条**，且主文档侧 `mvu_settings` 恒为 `{}`、`EjsTemplate.enabled` 恒为 `false`。注入代码与调用点都在（与 P5-6 报告一致），坏在"注入时机晚于消费定型"。

### 附带验证

- `node --check` / 全脚本 `new Function` 语法均通过（排除语法错误阻断执行）；
- 日志文本证明 HTML 骨架执行了，`sendToFlutter` 桥当时已就绪（桥内联在 HTML 头部 `chat_stage.html:342`）。

---

## 2. 世界书下拉没内容——`__thCall` 方法名/type 串错位（致命）

### 证据链

主文档 TH（`chat_stage.html:1304-1342`）：

```js
TH.getWorldbookNames = function () { return __thCallRead('th_wiGetLorebooks', []); };  // 传的是桥 type
TH.getWorldbook = function (name) { return __thCallRead('th_wiGetEntries', [name]); };
TH.replaceWorldbook = function (name, entries) { return __thCall('th_wiSetEntries', [name, entries]); };
```

`__thCall` 的实现（`chat_stage.html:1307-1312`）与共享表 `__TH_METHOD_TO_BRIDGE`（`chat_stage.html:387-407`）：

```js
var type = (window.__TH_METHOD_TO_BRIDGE || {})[method];  // 用 method 查表
if (!type) return Promise.reject(new Error('unknown method: ' + method));
```

而共享表的 key 是 **TH 方法名**（`getLorebooks`、`getLorebookEntries`…），value 才是 `th_wiGetLorebooks` 这类桥 type。

**把 `'th_wiGetLorebooks'` 当 method 查表 → `typeMap['th_wiGetLorebooks'] === undefined` → 必 reject。**

受影响（逐一还原）：

| 主文档 TH 方法 | 实际传入 | 查表结果 | 状态 |
|---|---|---|---|
| `getWorldbookNames` | `'th_wiGetLorebooks'` | miss | ❌ reject |
| `getWorldbook` / `getLorebookEntries` | `'th_wiGetEntries'` | miss | ❌ reject |
| `getCharWorldbookNames` | `'th_wiGetCharLorebooks'` | miss | ❌ reject |
| `getEnabledLorebookList` | `'th_wiGetEnabledList'` | miss | ❌ reject |
| `getLorebookSettings` | `'th_wiGetLorebookSettings'` | miss | ❌ reject |
| `getTavernRegexes` | `'th_getRegexes'` | miss（表里无此键） | ❌ reject |
| `replaceWorldbook` | `'th_wiSetEntries'` | miss | ❌ 写失败 |
| `getScriptTrees` | 纯 JS 读 `__KIRA_PRESET_SCRIPTS` | 不过桥 | ✅ 正常 |

**主文档 TH 的"只读+replaceWorldbook"全家只有 getScriptTrees 活着。** 道渊 `wn()`（下拉填充）调 `getWorldbookNames` → reject → `catch` → 下拉显示"获取失败/没内容"；`b()`/`kn()` 的 `getWorldbook` 同样 reject；报警3 的状态栏计数 `An` 因此算不出、报警2 的 `Ke`（输出格式强调，读 `getWorldbook`）恒 false。

### 同一 bug 在 iframe facade（`tavern_helper_facade.dart`）

`503f91f` 把以下实现引入 facade（git 实证：`503f91f` 之前 facade 无 `getWorldbookNames`）：

```dart
'_TH.getWorldbookNames=function(){return __thCallRead("th_wiGetLorebooks",[])...'
'_TH.getWorldbook=function(name){return __thCallRead("th_wiGetEntries",[name])...'
'_TH.replaceWorldbook=function(...){return __thCall("th_wiSetEntries",[name,entries])...'
```

与主文档同样的问题 → **`unknown method: th_wiGetLorebooks` reject**（本会话用真实 typeMap 逐一核对：`th_wiGetEntries` / `th_wiGetLorebooks` / `th_wiSetEntries` 三处 BROKEN；`getLorebooks` / `getLorebookEntries` / `getEnabledLorebookList` 等以方法名传参的 OK）。

巧合的是 MVU 世界书读走 `getLorebooks`/`getCharLorebooks`（方法名传参）所以没暴露；只有道渊/新代码走的 `getWorldbookNames` 系全断。

### 为什么 P5-6 报"完成"

- 语法检查过（`node --check`），逻辑错不在语法；
- 共享表本身 key/value 完全正确，是**调用方把 value 当 key**；
- 真机验证被顺延（报告白纸黑字"运行时验证未执行"），静态无法发现运行时 miss。

---

## 3. 预设球"闪一下"——toggle 极性反（503f91f 引入）

### 证据链

`chat_stage.html:2270-2286` `renderSections` 的 toggle 按钮：

```js
button.addEventListener('click', function(){
  ...
  window.__sendRequest('th_pmToggleSection', {
    type: s.type, identifier: s.identifier, name: s.name,
    enabled: !li.classList.contains('completion_prompt_manager_prompt_disabled')  // ← 发送当前态
  })...
```

双人成行悬浮窗（`shuangren_script_0_双人成行悬浮窗.js.pretty.js`）点击链路：球按钮 → `findPromptByButton` 爬 `#completion_prompt_manager_list` 的 `li[data-pm-identifier]` → 对 disabled 的 li 执行原生 `btn.click()`（pretty:956-966）→ 命中上面这段。

**极性错误推演**（li 当前 = OFF，球想开）：

1. li 有 disabled class → `enabled = !true = false` → 发的是"关"；
2. Dart `_handlePmToggleSection`（`webview_chat_stage.dart:1816-1845`）收到 `enabled:false` → `next=false` → `updateSection(enabled:false)` → **状态不变**；
3. 球侧 `setButtonState` 自以为成功 → `btn.classList.add('is-on')`；
4. 80ms 后球的 MutationObserver（pretty:3180-3218）发现 li 仍是 disabled → `initDetectState()` 回弹 → **LED "闪一下"**。

对照 503f91f 删除前的自研球（`503f91f^` 实证）发送的是**目标态**：

```js
checkbox.addEventListener('change', function(){
  ...
  enabled: !!checkbox.checked        // change 后 checked = 新状态 = 目标态
```

`renderSections` 在 503f91f（P5-4 存档）重构时把"发当前态"带进来，P5-6 阶段1.3 只补了首帧推送（`fireImmediately` + 启动拉取），**没修极性，也没真机点过**——而 P5-6 报告在"未完成（运行时）"清单里明确列了"点击翻转 is-on"未验证。

---

## 4. 四报警还在——报警读的是 iframe facade，不是主文档 env

### 证据链（daoyuan_helper.js.pretty.js）

- 道渊脚本本体跑在**脚本房 iframe**；报警轮询 `Ze()`（5s setInterval，pretty:1760-1790）也在 iframe；
- 报警数据源全部是 **iframe 内**的全局：
  - 报警1/2：`Ge() = SillyTavern.extensionSettings.mvu_settings`（pretty:326-327，iframe facade 提供）；
  - 报警4：`SillyTavern?.extensionSettings?.EjsTemplate`（pretty:306-307，iframe facade 提供）；
  - 报警3 计数：经 bp 桥注入主文档调 `TavernHelper.getWorldbook / getTavernRegexes / getScriptTrees`（pretty:57-64）。

而 P5-6 阶段2.2 的 env 注入目标是**主文档** `window.__KIRA_MAIN_ENV` → 主文档 SillyTavern 骨架。**iframe 里跑着的报警根本看不见它**。

facade（`tavern_helper_facade.dart:346-356`）的 `extensionSettings` 只有 `mvu_settings`（烘焙真实 mvu 快照），**没有 `EjsTemplate` 键、没有 `通知` 四键**：

- 报警4：`EjsTemplate` undefined → push"提示词模板未安装" → **恒亮**（主文档 env 补的 EjsTemplate 只救了主文档骨架，救不了 facade）；
- 报警1：`通知` 四键 undefined（MVU zod 默认 `true,true,false,true`，见 `mvu_bundle.js.pretty.js:2988-2993`）→ 恒亮（P5-6 自己标注"留待 3.3 讨论"，如实）；
- 报警2/3：因第 2 节的世界书/regex 桥全部 reject，数据永远读不到。

**修错对象 + 已知遗留的双重结果。** "主文档 env" 只服务于道渊 bp 串里的 `zt()`（把 MVU 配置回填进 ST 设置 UI 的 DOM——本平台没有 `.mvu-section` DOM，实际也是空跑），对四报警无贡献。

---

## 5. 修复方案

### 修复 A：SillyTavern 骨架改惰性读（消除"注入缺失"）

文件：`assets/chat/chat_stage.html:1405-1425`

每次 `getContext()` **现读** `window.__KIRA_MAIN_ENV`，不要 IIFE 闭包捕获；缺失日志只打一次：

```js
window.SillyTavern = {
  getContext: function () {
    var env = window.__KIRA_MAIN_ENV || {};
    if (!env.__logged) { env.__logged = 1; /* 打一次 warn */ }
    return { extensionSettings: {
      mvu_settings: (env && env.mvu) || {},
      EjsTemplate: { enabled: !!(env && env.ejsLoaded) }
    }};
  }, ...
};
```

> 注：骨架闭包需额外保留 `saveSettingsDebounced` / `getCurrentChatId`，仅改 env 读取方式。

### 修复 B：`__thCall` 兼容"直传桥 type"（一处修全部，主文档 + facade）

文件：`assets/chat/chat_stage.html:1307-1312`（主文档 TH 的 `__thCall`）与 `tavern_helper_facade.dart:73-80`（门面 `__thCall`，同一逻辑）

```js
function __thCall(method, args) {
  var table = window.__TH_METHOD_TO_BRIDGE || {};
  // 优先方法名查表;以 th_ 开头视为桥 type 直传(历史实现两套并存)
  var type = table[method] || (typeof method === 'string' && method.indexOf('th_') === 0 ? method : null);
  if (!type) return Promise.reject(new Error('unknown method: ' + method));
  return __sendRequest(type, __thBuildPayload(method, args || []));
}
```

修完即恢复：主文档 TH 世界书读/写、`getTavernRegexes`；iframe facade 的 `getWorldbookNames/getWorldbook/replaceWorldbook`。Dart 侧 handler 全部已注册（`webview_chat_stage.dart:868-897`），无需改 Dart。

### 修复 C：renderSections toggle 极性（目标态）

文件：`assets/chat/chat_stage.html:2275`

```js
enabled: li.classList.contains('completion_prompt_manager_prompt_disabled')  // 当前OFF→发true(开)
```

### 修复 D：facade 补 `EjsTemplate` + `通知` 键（四报警数据真实性）

文件：`tavern_helper_facade.dart`

1. `extensionSettings` 增加 `EjsTemplate: { enabled: <ejsLoaded> }`，`buildTavernHelperFacadeJs` 增加 `ejsLoaded` 入参，`_injectEngineFacade`（`webview_chat_stage.dart:317-326`）把静态标志 `_ejsLoaded` 传入 —— 与主文档 env 同源、如实；
2. `通知` 四键：按 MVU zod 默认（`MVU框架加载成功:true, 变量初始化成功:true, 变量更新出错:false, 额外模型解析中:true`，实证 `mvu_bundle.js.pretty.js:2988`）作为**初始默认值**注入 —— 只是把"用户尚未在 UI 配置过"如实表示为 MVU 出厂默认，不是造假状态位（`变量更新出错` 等事件型状态仍由 MVU 自己写）；是否纳入本轮由阶段3.3 契约讨论定，报告如实标注。

> 说明：修复 A/B/C 属本轮诊断直接结论、改动小、可静态验证；D 涉及"默认值即状态"的契约口径，需按 P5-6 报告的 3.3 讨论确认后再动（本报告不擅自改）。

### 验证锚点（真机必做，杜绝再次"报告完成但没生效"）

1. 进聊天页日志**不再出现** `[主环境] __KIRA_MAIN_ENV 注入缺失`；
2. 道渊球下拉出现书名（`-- 获取失败 --` 消失），且 `[bp桥]` 不再报 `unknown method`；
3. console 三连：`TavernHelper.getWorldbookNames()` resolve 数组、`getWorldbook('道渊...')` resolve 307 条、`getTavernRegexes({type:'character'})` resolve 数组；
4. 预设球点击后 `is-on` **保持**（不再 80ms 回弹），Dart 日志 `[PM] toggle payload` 出现且 `enabled` 与点击目标一致；
5. 道渊报警面板重测四条（预期：2/3 变数据驱动；1/4 取决于 D 是否实施）。

## 6. 改动文件清单

| 文件 | 位置 | 改动 |
|---|---|---|
| `assets/chat/chat_stage.html` | 1307-1312 | `__thCall` 加 th_ 直传兼容（修复 B） |
| 同上 | 1405-1425 | SillyTavern 骨架改惰性读 env（修复 A） |
| 同上 | 2270-2275 | toggle 极性改目标态（修复 C） |
| `lib/presentation/screens/chat/tavern_helper_facade.dart` | 73-80 及 317-356 | `__thCall` 兼容 + （可选 D）ejsLoaded 入参与 EjsTemplate/通知键 |
| `lib/presentation/screens/chat/webview_chat_stage.dart` | 317-326 | （随 D）传 `_ejsLoaded` 给 facade |

## 7. 为什么 P5-6 说"完成"但没生效（对报告的反思）

1. **代码全在，但实现级 bug 三个**（th_ 直传错位 ×2 处、toggle 极性反）——全部是"语法正确、运行时必错"，静态验证不可能拦下；
2. **真机验证被顺延**且报告如实标注——本次三症状恰全部落在"未验证清单"里；
3. **修错对象一处**：env 注入给主文档骨架，而四报警消费在 iframe facade —— 架构层认知偏差，单靠跑一遍真机日志（如本会话证据 4）才能暴露；
4. 教训：涉及"查表/命名约定"的 JS 移植，必须至少做一次**运行时 smoke**（本会话用真实 typeMap 复现了全部 miss），不能以 `node --check` 充当验证。
