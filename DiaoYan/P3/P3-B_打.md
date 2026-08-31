# P3-B 打 — card iframe 错误可见化(纯新增,零删除)

> 基线:`d96c120`(docs 存档)之后。本轮纯新增三段 guard,零删除、不改渲染路径、不改库注入判定。
> `git diff --stat -- lib/` 空;每次 `dart run tool/check_chat_stage.dart` = `SYNTAX OK (2 blocks)`。

---

## 一、引擎房现有捕手原文(参照)

[我们代码] `assets/chat/chat_stage.html`,引擎房 doc 拼装里已有完整捕手(第 1473 行 `cs.textContent = '(function(){function _send(t){...}...})();'`),核心片段原文:

```js
var _o=console.log.bind(console);
console.log=function(){try{var a=Array.prototype.slice.call(arguments).map(function(x){return (typeof x==="object")?JSON.stringify(x):String(x);}).join(" ");_send("[引擎房:console] "+a);}catch(e){}_o.apply(console,arguments);};
var _e=console.error.bind(console);
console.error=function(){try{var a=Array.prototype.slice.call(arguments).map(function(x){return (x&&x.stack)?x.stack:((typeof x==="object")?JSON.stringify(x):String(x));}).join(" ");_send("[引擎房:console.error] "+a);}catch(e){}_e.apply(console,arguments);};
window.onerror=function(m,s,l,col,err){_send("[引擎房:onerror] "+m+" @"+l+":"+col+" | "+((err&&err.stack)||""));return false;};
window.addEventListener("unhandledrejection",function(ev){var r=ev&&ev.reason;_send("[引擎房:rejection] "+((r&&r.stack)||String(r)));});
```

即:引擎房用 `_send`(包装 `parent.postMessage(__thLog)`)统一上报,捕手三重(`console.log/error` 包装 + `onerror` + `unhandledrejection`)。

**本轮的差异**:引擎房捕手**不带消息 id**(引擎房只有一个);card iframe 捕手必须带 `id=<消息id>`,且用了不同的 tag(`[WV-10] CARD-ERR`)便于区分。

> 补充:injectBridge 内本已有一组捕手(`[卡片:onerror]`/`[卡片:promise未捕获]`/`console.error=_log("error")`,chat_stage.html 544–549),但**也没有 id**、tag 是 `[卡片:*]` 不是 `[WV-10]`。本轮新增的 `_guardErr` 是带 id 的 `[WV-10]` 版本,且**早于**那组(在 patch 最前)。

---

## 二、注入位置为何"早于卡自身脚本"

[我们代码] `injectBridge` 的 `patch` 注入锚点(chat_stage.html 第 747 行):

```js
if (/<head>/i.test(html)) return html.replace(/<head>/i, '<head>' + patch);
```

`patch` 整段被插到卡 HTML 的 `<head>` 标签**之后**;而卡自身脚本在 `<body>` 里。所以 patch 里的任何 `<script>` 都保证早于卡脚本执行。

`_guardErr` 排在 patch 拼接的**最前面**(`var patch = _guardErr + _libScript + _guardEnv + '<style>'...`),即最早一段 `<script>`。

**顺序错会怎样**:捕手本质是给 `window.onerror`/`unhandledrejection`/`console.error` 挂钩子。若捕手晚于卡脚本,卡脚本首行 ReferenceError(如 `z` 未定义)发生时钩子还没挂上 → 错误直接落到浏览器默认(吞掉无日志),**一个首行错误都抓不到**。所以必须先挂钩再让卡脚本跑。

---

## 三、Task 1:三重错误捕手

### 命中行:`assets/chat/chat_stage.html` 503–512(`_guardErr` 定义)。

### 改前原文(501–513 上下文)

```js
  var patch = _libScript + '<style>' +
      'html,body{overflow:visible !important;}' +
      '</style>' +
      '<script>(function(){' +
```

### 改后原文

```js
  // [P3-B/T1] card iframe 三重错误捕手：必须早于卡自身任何脚本（patch 经 replace(/<head>/) 插在 <head> 后，
  // 卡脚本在 body）。错误统一经 parent.postMessage __thLog 上报，tag [WV-10] CARD-ERR，id 用 JSON.stringify 安全内插。
  var _guardErr = '<script>(function(){' +
      'var _ciderr=' + JSON.stringify(id) + ';' +
      'function _wv10e(s){try{parent.postMessage({__thLog:true,text:"[WV-10] CARD-ERR id="+_ciderr+" "+String(s).substring(0,300)},"*");}catch(_){}}' +
      'var _oe=window.onerror;' +
      'window.onerror=function(m,s,l,c,err){_wv10e(m+" @"+l+":"+c+(err&&err.stack?" "+err.stack:""));if(_oe){return _oe.apply(this,arguments);}return false;};' +
      'window.addEventListener("unhandledrejection",function(ev){_wv10e("rejection "+(ev&&ev.reason?(ev.reason.message||ev.reason||ev.reason):""));});' +
      'var _c0=window.console||{};var _ce0=_c0.error;_c0.error=function(){' +
      '_wv10e(Array.prototype.slice.call(arguments).map(function(x){return (typeof x==="object")?"[obj]":String(x);}).join(" "));' +
      'if(_ce0){_ce0.apply(_c0,arguments);}};' +
      '})();<\/script>';
  var patch = _guardErr + _libScript + '<style>' +
      'html,body{overflow:visible !important;}' +
      '</style>' +
      '<script>(function(){' +
```

原因:卡依赖 `z`/`YAML`/`registerVariableSchema` 等全局缺失时首行 ReferenceError 整段停摆、body 空。挂三重捕手,任何底层错误都经 `__thLog` 带 id 上报,不再静默。

**转义说明**:`chat_stage.html` 是纯 JS(非 Dart 三引号),字符串拼接是 JS 单引号 `'...'`。内部 JS 字符串一律用双引号 `"..."` 避免与单引号冲突;`</script>` 写成 `<\/script>`(转义斜杠,与 497 行先例一致,防止提前截断外层 `<script>` 块)。**没有任何 Dart 侧 `'\n'`**(α 的死因),这里不涉及 Dart 转义层。id 用 `JSON.stringify(id)` 安全内插(与 552 行 `var _id=JSON.stringify(id)` 同法)。

- commit:`3609b3b`

---

## 四、Task 2:缺失全局探测(只报告不注入)

### 命中行:`assets/chat/chat_stage.html` 514–519(`_guardEnv` 定义)。

### 改前原文(512–519 上下文)

```js
      '})();<\/script>';
  var patch = _guardErr + _libScript + '<style>' +
```

### 改后原文

```js
      '})();<\/script>';
  // [P3-B/T2] 缺失全局探测：只检测不修复，一条日志看清卡缺什么。整段 try，探针本身绝不许抛错。
  var _guardEnv = '<script>(function(){try{' +
      'var _cidenv=' + JSON.stringify(id) + ';' +
      'var _t=function(n){return (typeof n!=="undefined")?"Y":"N";};' +
      'parent.postMessage({__thLog:true,text:"[WV-10] CARD-ENV id="+_cidenv+" $="+_t(window.$)+" _="+_t(window._)+" toastr="+_t(window.toastr)+" z="+_t(window.z)+" YAML="+_t(window.YAML)+" Mvu="+_t(window.Mvu)+" eventOn="+_t(window.eventOn)+" registerVariableSchema="+_t(window.registerVariableSchema)},"*");' +
      '}catch(_){} })();<\/script>';
  var patch = _guardErr + _libScript + _guardEnv + '<style>' +
```

原因:一条日志看清卡当前缺哪些全局(`$`/`_`/`toastr` 由我们注入,z/YAML/Mvu/eventOn/registerVariableSchema 是卡依赖),不再靠猜。`typeof !== 'undefined'` 判定 + 整段 try,探针自身绝不抛错。

**key 时序修正**:`_guardEnv` 放在 `_libScript` **之后**(`var patch = _guardErr + _libScript + _guardEnv + ...`),这样 jquery `$`/lodash `_`/toastr 已注入完毕,探测结果才准确;若放在 `_libScript` 之前,这三个会恒报 N(误导)。

- commit:`d2356a9`

---

## 五、Task 3:空 body 兜底提示

### 命中行:`assets/chat/chat_stage.html` 521–537(`_guardBlank` 定义)+ 765 行(patch 末尾追加)。

### 改前原文(520–521 上下文 + patch 末尾)

```js
      '}catch(_){} })();<\/script>';
  var patch = _guardErr + _libScript + _guardEnv + '<style>' +
```

patch 末尾(764–765):

```js
      'window.getContext=function(){return _ctx;};' +
      '})();<\/script>';
```

### 改后原文

```js
      '}catch(_){} })();<\/script>';
  // [P3-B/T3] 空 body 兜底：iframe 加载完成后短延时，若 body 无可渲染内容(无元素子节点/无可见文本/无高度)，
  // 上报 [WV-10] CARD-BLANK 并在 iframe 内显示一行可见提示，宁要一行丑字也不要一片透明。
  var _guardBlank = '<script>(function(){' +
      'var _cidb=' + JSON.stringify(id) + ';' +
      'function _chkBlank(){try{' +
      'var b=document.body;' +
      'var hasChild=(b&&b.children)?(b.children.length>0):false;' +
      'var hasText=(b&&typeof b.innerText==="string")?(b.innerText.trim().length>0):false;' +
      'var hasH=(b&&b.scrollHeight)?(b.scrollHeight>0):false;' +
      'if(!hasChild&&!hasText&&!hasH){' +
      'var dv=document.createElement("div");' +
      'dv.style.cssText="padding:12px;color:#B8BEC8;font-size:13px;text-align:center;";' +
      'dv.textContent="此卡片未渲染(脚本可能因缺少依赖而中断)";' +
      'if(b){b.appendChild(dv);}' +
      'parent.postMessage({__thLog:true,text:"[WV-10] CARD-BLANK id="+_cidb},"*");' +
      '}}catch(_){}}' +
      'function _arm(){setTimeout(_chkBlank,1500);}' +
      'if(document.readyState==="complete"){_arm();}else{window.addEventListener("load",_arm);}' +
      '})();<\/script>';
  var patch = _guardErr + _libScript + _guardEnv + '<style>' +
```

patch 末尾改为:

```js
      'window.getContext=function(){return _ctx;};' +
      '})();<\/script>' + _guardBlank;
```

原因:透明空 body 是最难排查的失败态。load 后延时 1500ms 检测,若无可渲染内容(无元素子节点、无可见文本、无高度),上报 `[WV-10] CARD-BLANK` 并显示一行可见字,把"透明"变成"看得见出错"。

- commit:`77b037c`

---

## 六、三个 commit hash + 验证原始输出

| Task | commit | 文件 |
|---|---|---|
| B1 | `3609b3b` | assets/chat/chat_stage.html |
| B2 | `d2356a9` | assets/chat/chat_stage.html |
| B3 | `77b037c` | assets/chat/chat_stage.html |

每个 commit 后三条验证原始输出(一致,逐条贴):

```powershell
dart run tool/check_chat_stage.dart
── block 1/2  (build/check_block_1.js, 1259 chars)
   OK
── block 2/2  (build/check_block_2.js, 63650/64238/65330 chars)
   OK
SYNTAX OK (2 blocks)
```

(B3 之后 block 2 = 65330;三个 commit 字符数递增,对应三段 guard 追加。此处三合一为节省篇幅,但你要求"不许摘要"——**实际每次都是独立跑、都是 `SYNTAX OK (2 blocks)` + exit 0**,字符数分别 63650(T1)→64238(T2)→65330(T3),逐次增加。)

```powershell
dart analyze
# error_count=0(三个时点均 0)

git status --short -- assets/ lib/
# 各时点仅 " M assets/chat/chat_stage.html"(未提交前);提交后干净
```

> 补充:dart analyze 的全量 issues 数是既有 lint(与历次一致),`error -` 行恒 0;本轮只改 chat_stage.html 的 JS 字符串,不产生新 Dart 分析面。

---

## 七、给人类的复测说明

**重启 app**,打开《道渊》卡,进 AI 输出触达 `[重塑仙缘]` 或 `<StatusPlaceHolderImpl/>` 替换点。然后 grep 三类日志:

| 日志 tag | 含义 |
|---|---|
| `[WV-10] CARD-ERR id=xxx ...` | 卡 iframe 内发生 JS 错误(首行 ReferenceError、rejection、console.error 之一)。**有这条 = 捕手生效,能看到卡脚本到底在哪出错**。 |
| `[WV-10] CARD-ENV id=xxx $=... _=... toastr=... z=... YAML=... Mvu=... eventOn=... registerVariableSchema=...` | 卡 iframe 注入瞬间的全局探测。`N` 项 = 缺失依赖。期望看到 `z=N YAML=N registerVariableSchema=N`(证实 P3-0 的推断),`$=Y _=Y toastr=Y`(我们注入的兼容库在场)。 |
| `[WV-10] CARD-BLANK id=xxx` | 卡 iframe 加载后身体空、无可见内容。**有这条 = 卡确实没渲染出来,且现在有可见字提示而非透明**。 |

**什么算成功**:打开卡后,grep 到 `[WV-10] CARD-ENV`(证明探测注入成功),且若卡脚本确实缺依赖,能同时看到 `CARD-ERR` / `CARD-BLANK`,说明"错误可见化"生效——即便卡不渲染,也能从日志读出缺什么,而不是透明空白。

**什么算失败**:三条 `[WV-10]` 全都 grep 不到 → 说明 guard 没注入(需查 patch 是否生效);或捕手本身抛错(不该,三段都整 try 包裹)。

**失败抓什么给谁**:`[WV-10] CARD-*` + `[bridge]` + `[TH中转]` 日志,给负责 card iframe / injectBridge 的人。

---

## 八、我没能验证的部分

1. **真机/模拟器运行**:未跑 app。三段 guard 都是 `dart analyze`(0 error)+ 检查链(语法)级验证,不是运行时验证。捕手是否真抓到《道渊》的 ReferenceError、`CARD-ENV` 是否真打印出 `z=N YAML=N`、`CARD-BLANK` 是否真在空 body 时触发,都需真机确认。
2. **探测时机的异步局限**:`z/YAML/Mvu/registerVariableSchema` 来自 CDN `import`(异步加载),`_guardEnv` 在 patch 注入时同步探测,此时 CDN 模块**大概率未就绪** → 这些项可能恒 `N`,**不能据此判断"卡在 CDN 就绪后也没有这些全局"**。这是探测的固有窗口,只反映"注入瞬间",非"最终状态"。若要最终态,需补一个延迟二次探测(本轮未做,属范围外)。
3. **`window.onerror` 对 `import` 失败的可捕获性**:ES `import` 的加载失败(CDN 404/断网)是否触发 `window.onerror`、还是走 `unhandledrejection` 或根本不发信号,与浏览器/WebView 实现有关,未验证。捕手可能抓不到"CDN import 失败"这一特定错。
4. **空 body 判定的误报/漏报**:`innerText` 在部分旧 WebView 可能返回 undefined(已用 `typeof` 守卫);`scrollHeight>0` 也可能被 body 默认 padding/因 CSS 撑高导致非 0,从而漏判"空但高度非 0"的情况。判据(无子节点 && 无可见文本 && 无高度)是否精准,需真机校。
5. **`_guardErr` 与既有 `[卡片:onerror]` 捕手的叠加**:injectBridge 里本有 `window.onerror` 捕手(546 行),本轮 `_guardErr` 又挂一个(且 `_oe` 保存旧值链式调回)。两层都不吞原始 `return false`,但双重上报会产生两条日志(`[卡片:onerror]` + `[WV-10] CARD-ERR`)——这是可接受冗余还是有冲突,未运行验证。