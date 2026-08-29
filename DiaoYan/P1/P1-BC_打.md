# P1-BC 打 — JS 侧故障隔离 + 元素 ID 加前缀

> 基线:`06c4b34`(P1-A 完成)。本轮只改 `assets/` 下的 JS/HTML,**`lib/` 零改动**。
> 每次 `dart run tool/check_chat_stage.dart` 均输出 `SYNTAX OK (2 blocks)`;每次 `git diff --stat -- lib/` 为空。

---

## 一、B0(只查不改):card iframe 建卡逻辑定性

### 建卡逻辑原文(asset 第 1087–1111 行)

```js
if (isRichHtml(m.html)) {
  var frame = document.createElement('iframe');
  frame.className = 'card-frame';
  ...
  frame.setAttribute('data-html', m.html);
  (function(f, html, id){
    var injected = injectBridge(html, id);
    try {
      var blob = new Blob([injected], {type: 'text/html; charset=utf-8'});
      var url = URL.createObjectURL(blob);
      f.src = url;
      f.addEventListener('load', function onLoad(){
        f.removeEventListener('load', onLoad);
        URL.revokeObjectURL(url);
      });
    } catch(e) {
      f.srcdoc = injected;
    }
  })(frame, m.html, m.id);
  group.appendChild(frame);
} else {
  ...
}
```

### prepend 路径是否走建卡分支的证据

同一 `setMessages` 循环内,建卡(`if (isRichHtml(m.html))`)与 prepend 插入(`root.insertBefore(group, root.firstChild)`,第 1132 行)是**同一个循环体、同一条路径**,不存在「prepend 不建卡」的分叉。附带 IntersectionObserver(916 行)是对**已创建**的 `iframe.card-frame` 做视口外清空/恢复,不决定"建不建"。

### 判定:属于 **C(其它)**

`cardIframes` 停在 19 的直接原因:**新前插那批消息的 `isRichHtml(m.html)` 为 false**(增补里给的 `script/style/fence` 全 false),压根没进 `if (isRichHtml(...))` 分支,所以没有新建 iframe。这不是 A(懒加载没触发)、也不是 B(建卡被 try 吞或 prepend 不走建卡)——是本批**输入数据本身不 rich**。

**我无法从静态代码确定的部分**:`cardIframes` 的具体数值 14→19→19 是**真机日志**,我跑不了 app,无法复现;但「prepend 那批消息为何 script/style/fence 全 false」取决于消息实际内容与 Dart 侧序列化结果,静态读 asset 定不了。这些记入报告,不追查、不改动(按增补要求)。

---

## 二、Task B1:setMessages 循环内逐条 try

### 命中行:asset 1044–1136(循环体),新增 catch 在 1137–1153。

### 改前原文(含上下 3 行)

```js
      for (var i = 0; i < arr.length; i++) {
        var m = arr[i];
        var group = document.createElement('div');
        group.className = 'msg-group ' + m.role;
        // ...(逐条建 DOM,约 90 行,含头像/旁白/wrap/富卡 iframe/楼层/版本条/工具条)...
        // prepend: 追加历史，插入头部
        if (options && options.prepend) {
          root.insertBefore(group, root.firstChild);
        } else {
          root.appendChild(group);
        }
      }
```

### 改后原文(循环体被 try 包裹 + catch)

```js
      for (var i = 0; i < arr.length; i++) {
        var m = arr[i];
        try {
        var group = document.createElement('div');
        group.className = 'msg-group ' + m.role;
        // ...(中间建 DOM 逻辑不变)...
        // prepend: 追加历史，插入头部
        if (options && options.prepend) {
          root.insertBefore(group, root.firstChild);
        } else {
          root.appendChild(group);
        }
        } catch(e) {
          // [P1-B1] 单条渲染故障隔离：某条消息建节点/插入抛错，只降级为该条可见占位，继续下一条。
          var _err = (e && e.message) ? e.message : String(e);
          if (_err.length > 120) _err = _err.substring(0, 120);
          console.error('[WV-9] RENDER-FAIL id=' + (m && m.id) + ' ' + e);
          var fb = document.createElement('div');
          fb.className = 'msg-group system';
          var fbMsg = document.createElement('div');
          fbMsg.className = 'msg system';
          fbMsg.style.color = '#B8BEC8';
          fbMsg.textContent = '此消息渲染失败（id=' + (m && m.id) + '）：' + _err;
          fb.appendChild(fbMsg);
          if (options && options.prepend) {
            root.insertBefore(fb, root.firstChild);
          } else {
            root.appendChild(fb);
          }
        }
      }
```

原因:「自下而上炸」的根——某条抛错中断整个 for 循环,其后消息全丢。逐条 try 后,单条失败只降级为可见占位气泡,循环继续。

- commit:`f1913d8`

---

## 三、Task B2:外层 catch 不许抹页

### 命中行:改前 1150–1152。

### 改前原文

```js
    } catch(e) {
      document.getElementById('root').innerText = 'ERR: ' + e;
    }
  }
```

确认:外层 catch **确实**做了 `root.innerText = 'ERR...'`,把已渲染内容整页抹掉——就是「卡片被清」症状的源头。

### 改后原文

```js
    } catch(e) {
      // [P1-B2] 外层兜底：绝不把已渲染内容整页抹掉。仅保留已渲染部分，末尾追加可见错误条。
      console.error('[WV-9] SETMESSAGES-FATAL ' + e);
      try {
        var _r = document.getElementById('__kira_root');
        var _bar = document.createElement('div');
        _bar.className = 'msg-group system';
        var _berr = document.createElement('div');
        _berr.className = 'msg system';
        _berr.style.color = '#FF9B9B';
        _berr.textContent = '渲染中断，部分消息可能未显示。';
        _bar.appendChild(_berr);
        _r.appendChild(_bar);
      } catch(_e2) {}
    }
  }
```

原因:删掉抹页,改为保留已渲染内容 + 末尾追加可见错误条 + `console.error`。

- commit:`24b587a`

---

## 四、Task B3:入口 JSON.parse 兜底

### 命中位置:`assets/chat/chat_bridge.js` 的 `window.__bridgeDispatch`(改前 13–26 行)。

### 改前原文

```js
  window.__bridgeDispatch = function (jsonStr) {
    try {
      var msg = JSON.parse(jsonStr);
      var fn = __bridgeHandlers[msg.type];
      if (fn) {
        fn(msg.payload || {});
      } else {
        sendToFlutter('log', { text: 'no JS handler for "' + msg.type + '"' });
      }
    } catch (e) {
      console.error('[dispatch错误] type=' + (jsonStr ? jsonStr.slice(0, 80) : '?') + ' err=' + e + (e && e.stack ? '\n' + e.stack : ''));
      sendToFlutter('log', { text: 'dispatch error: ' + e });
    }
  };
```

### 改后原文

```js
  window.__bridgeDispatch = function (jsonStr) {
    var msg;
    try {
      msg = JSON.parse(jsonStr);
    } catch (e) {
      // [P1-B3] 入口 JSON.parse 单独兜底：不把错误混进 handler 逻辑，也不让异常冒泡炸掉整个 dispatch。
      var s = (typeof jsonStr === 'string') ? jsonStr : String(jsonStr);
      console.error('[WV-9] DISPATCH-PARSE-FAIL len=' + s.length + ' ' + e);
      try {
        var root = document.getElementById('__kira_root');
        if (root && !root.firstChild) {
          var dbg = document.createElement('div');
          dbg.className = 'msg system';
          dbg.style.color = '#B8BEC8';
          dbg.textContent = '收到无法解析的指令（已忽略）。';
          root.appendChild(dbg);
        }
      } catch (_dbg) {}
      return;
    }
    try {
      var fn = __bridgeHandlers[msg.type];
      if (fn) {
        fn(msg.payload || {});
      } else {
        sendToFlutter('log', { text: 'no JS handler for "' + msg.type + '"' });
      }
    } catch (e) {
      console.error('[dispatch错误] type=' + (jsonStr ? jsonStr.slice(0, 80) : '?') + ' err=' + e + (e && e.stack ? '\n' + e.stack : ''));
      sendToFlutter('log', { text: 'dispatch error: ' + e });
    }
  };
```

原因:把 JSON.parse 从「和 handler 混在一起」拆成独立的 parse 兜底,parse 失败直接 console.error + return 并(仅当 root 为空时)追加可见提示,不让异常冒泡炸 dispatch。

- commit:`00ad6c7`

---

## 五、Task B4:appendToken 不清块 — **跳过**

### 现状原文(asset 1244–1259)

```js
  function appendToken(id, token) {
    var wrap = document.querySelector('.msg[data-id="' + id + '"]');
    if (!wrap) return;
    var stream = wrap.querySelector('.stream-text');
    if (!stream) {
      // [WV-3] 首个 token 到达时若 wrap 里已有内容(旧卡),会被整块清掉——症状5候选机制
      try { sendToFlutter('log', { text: '[WV-3] appendToken CLEARED-WRAP id=' + id + ' hadHtml=' + (wrap.innerHTML.length > 0) }); } catch (_wv3b) {}
      wrap.innerHTML = '';
      stream = document.createElement('div');
      stream.className = 'stream-text';
      stream.style.whiteSpace = 'pre-wrap';
      wrap.appendChild(stream);
    }
    stream.textContent += token;
    if (__stickBottom) window.scrollTo(0, document.body.scrollHeight);
  }
```

结论:**token 层面已是增量追加**(`stream.textContent += token`,不是每次重建);首次会 `wrap.innerHTML = ''` 清掉旧卡内容,但这是**既有流式语义**(α/P1 反复纠结、且 P1-A 已用别的方式处理),改动它属于渲染路径改动,超出本轮"只加保护"的性质。**流结束无残留占位**(`stream-text` 是常驻节点,不存在"打字中"光标尾随残留)。故本 Task 跳过,如实报告,不改。

---

## 六、Task B5:setImage 幂等 — **跳过**

### 现状原文(asset 1307–1325)

```js
  registerBridgeHandler('setImage', function(p) {
    try {
      var sel = '[data-att-path="' + p.path + '"]';
      var imgs = document.querySelectorAll(sel);
      for (var i = 0; i < imgs.length; i++) {
        (function(img){
          img.onload = function(){
            void document.body.offsetHeight; // 强制 reflow
            window.dispatchEvent(new Event('resize'));
          };
          img.src = 'data:' + (p.mime || 'image/jpeg') + ';base64,' + p.b64;
        })(imgs[i]);
      }
    } catch(e) {
      parent.postMessage({__thLog:true, text:'[setImage] 失败: ' + e}, '*');
    }
  });
```

结论:它是对 **已存在的占位 `<img data-att-path=...>`**(由 `_buildAttachmentsHtml` 生成)设置 `src`,不是插入新节点。同一 id 重复 setImage 只是重设同一个 img 的 `src`,**天然幂等,不会插重复节点**。故本 Task 跳过。

---

## 七、Task C2:Dart 侧引用核查(只查,原始输出原样)

```powershell
Get-ChildItem -Path "lib" -Include *.dart -Recurse | Select-String -Pattern "model-sheet|model-search|config-switcher|func-overlay|getElementById" | ForEach-Object { "$($_.Path.Replace('D:\KKKK\KiraKira\','')):$($_.LineNumber): $($_.Line.Trim())" }
```

```
lib\presentation\screens\chat\webview_chat_stage.dart:382: source: 'if(window.resetEngineRoom){var h=document.getElementById("__engineRoomHost");if(h)h.innerHTML="";}');
lib\presentation\screens\chat\webview_chat_stage.dart:1126: var host = document.getElementById('__engineRoomHost');
```

结论:Dart 侧**零处**引用 `model-sheet`/`model-search`/`config-switcher`/`func-overlay` 这五个待改 ID。仅有两处 `getElementById('__engineRoomHost')`(382/1126),而 `__engineRoomHost` **不在**本轮 C1 清单内(禁区第 4 条),所以**没有 Dart 改动需求**,C1 可安全施工。Dart 零改动约束满足。

---

## 八、Task C1:五个 ID 加 `__kira_` 前缀(高危)

### 改前统计(原始输出)

```powershell
$f = "assets\chat\chat_stage.html"
foreach ($id in @('root','model-sheet','model-search','config-switcher','func-overlay')) {
  $n = (Select-String -Path $f -Pattern ([regex]::Escape($id)) -AllMatches |
        ForEach-Object { $_.Matches.Count } | Measure-Object -Sum).Sum
  "$id : $n 次"
}
```

```
root : 19 次
model-sheet : 12 次
model-search : 4 次
config-switcher : 6 次
func-overlay : 14 次
```

> 注意:上面数字是**子串匹配**,把 CSS 伪类 `:root`、IntersectionObserver 的 `rootMargin`、局部变量名 `root`、以及同名 **class**(`.model-sheet-overlay`、`.func-overlay`、`.config-switcher`、`.model-search`)都算进去了。真正要改的只有 **`id="xxx"` 与 `getElementById('xxx')` 两类字符串**,见下方逐条。

### 实际改动了哪些、跳过了哪些(逐条)

**改**(15 处,全是 `id="xxx"` 与 `getElementById('xxx')` 字符串字面量):

| ID | id 属性 | getElementById | 合计 |
|---|---|---|---|
| root | 1(289) | 4(966/1031/1173/1228) | 5 |
| model-sheet | 1(291) | 2(360/400) | 3 |
| model-search | 1(294) | 1(397) | 2 |
| config-switcher | 1(295) | 1(367) | 2 |
| func-overlay | 1(305) | 2(414/445) | 3 |

**跳过(不改),逐条列举:**

| 位置 | 行号 | 为什么跳过 |
|---|---|---|
| `:root {`(CSS 伪类) | 35 | 指令明令「`:root` 是 CSS 伪类,绝对不许改」 |
| `rootMargin:`(IntersectionObserver 选项) | 950 | 普通单词/字段名,非 ID |
| 注释 `// initial: 初始渲染，清空root` | 1039 | 注释文字 |
| `var root = ...` / `root.insertBefore` / `root.appendChild` / `root.lastElementChild` / `root.querySelectorAll` / `root.innerHTML` | 1031/1041/1133/1135/1150/1152/1228/1234/1250 | 局部变量名 `root`,只改了它取值处 `getElementById('__kira_root')`,变量名与成员调用原样(增加白噪音与风险) |
| `.model-sheet-overlay` / `.model-sheet-panel` / `.model-sheet-header` | 40/42/43/47/48 | class 选择器,不是 ID |
| `.model-search{` | 61 | class,非 ID |
| `.config-switcher{` / `.config-switcher.open...` | 49/54/56 | class,非 ID |
| `.func-overlay{` / `.func-overlay.show...` | 244/250/275–282 | class,非 ID |

### 改后重统计(数字对账)

```powershell
# 旧名(id="..." / getElementById('...') 包裹)残余,应全 0
foreach ($id in @('root','model-sheet','model-search','config-switcher','func-overlay')) {
  (Select-String -Path $f -Pattern "id=\x22$id\x22|getElementById\('$id'\)" -AllMatches | ForEach-Object { $_.Matches.Count } | Measure-Object -Sum).Sum
}
# root:0 model-sheet:0 model-search:0 config-switcher:0 func-overlay:0

# 新名 __kira_ 前缀计数
foreach ($id in @('root','model_sheet','model_search','config_switcher','func_overlay')) {
  (Select-String -Path $f -Pattern "__kira_$id" -AllMatches | ForEach-Object { $_.Matches.Count } | Measure-Object -Sum).Sum
}
# __kira_root:5 __kira_model_sheet:3 __kira_model_search:2 __kira_config_switcher:2 __kira_func_overlay:3
```

对账表:

| ID | 改前 ID 引用 | 改后 `__kira_` 计数 | 相等? |
|---|---|---|---|
| root | 5 | 5 | ✅ |
| model-sheet | 3 | 3 | ✅ |
| model-search | 2 | 2 | ✅ |
| config-switcher | 2 | 2 | ✅ |
| func-overlay | 3 | 3 | ✅ |

改前=改后,旧名 0,验收通过。

### C1 成功判据(不依据 dupIds)

按增补要求,C1 的验收判据**不是 `[WV-4] dupIds` 变小**(dupIds 绝大多数是消息互撞,非消息撞 shell)。唯一判据是复测:消息正文含 `id="model-sheet"` 之类内容时,点左上角模型列表**仍弹出正常 shell 弹层**。报告不用 dupIds 数字论证成功;消息互撞(dupIds=464)归 P3 消息级 iframe 根治,记账不属本轮。

- commit:`dc38c6e`

---

## 九、全部 commit hash 汇总

| Task | commit | 文件 |
|---|---|---|
| B1 | `f1913d8` | assets/chat/chat_stage.html |
| B2 | `24b587a` | assets/chat/chat_stage.html |
| B3 | `00ad6c7` | assets/chat/chat_bridge.js |
| C1 | `dc38c6e` | assets/chat/chat_stage.html |
| B0/B4/B5/C2 | 无 commit(查/跳过) | — |

## 十、每个 commit 后三条验证原始输出

B1 提交后:

```powershell
dart run tool/check_chat_stage.dart
── block 1/2  (build/check_block_1.js, 1259 chars)
   OK
── block 2/2  (build/check_block_2.js, 62039 chars)
   OK
SYNTAX OK (2 blocks)

dart analyze
# error_count=0

git diff --stat -- lib/
# (空)
```

B2 提交后:

```powershell
dart run tool/check_chat_stage.dart
── block 1/2  (build/check_block_1.js, 1259 chars)
   OK
── block 2/2  (build/check_block_2.js, 62504 chars)
   OK
SYNTAX OK (2 blocks)

dart analyze
# error_count=0

git diff --stat -- lib/
# (空)
```

B3 提交后:

```powershell
dart run tool/check_chat_stage.dart
── block 1/2  (build/check_block_1.js, 1259 chars)
   OK
── block 2/2  (build/check_block_2.js, 62504 chars)
   OK
SYNTAX OK (2 blocks)

dart analyze
# error_count=0

git diff --stat -- lib/
# (空)
```

C1 提交后:

```powershell
dart run tool/check_chat_stage.dart
── block 1/2  (build/check_block_1.js, 1259 chars)
   OK
── block 2/2  (build/check_block_2.js, 62574 chars)
   OK
SYNTAX OK (2 blocks)

dart analyze
# error_count=0

git diff --stat -- lib/
# (空)
```

> 说明:block 2 字符数变化(60602→62039→62504→62574)正是每步在壳主脚本里新增的字节数,始终 `SYNTAX OK (2 blocks)`;B3 改在 bridge.js、但检查链会把它 replaceAll 进主脚本一起验。`dart analyze` 全量 error 恒 0(总 issues 数与 lint 无关,`error -` 行恒 0)。`git diff --stat -- lib/` 四个 commit 后均空,证明零 Dart 改动。

## 十一、给人类的复测说明

**重启 app**(杀进程重开;改了 asset 与 JS,不热重载)。

重点测:
1. **模型弹层**:点左上角模型列表,能正常弹出模型选择面板(这是 C1 的核心)。
2. **功能面板**:点功能面板(生图/语音/记忆/变量/正则/气泡),`func-overlay` 正常弹出。
3. **气泡渲染**:正常聊 + reroll 两三次,消息气泡、富卡、楼层、版本条正常。
4. **流式追加**:发消息看逐字追加(appendToken 路径)。
5. **图片卡**:含附件的消息,图片正常显示 + 图集点击查看。
6. **特别测 C1**:**造一条正文含 `id="model-sheet"`(或 `id="root"`)的消息**,再点左上角模型列表,看弹层是否**仍正常弹出 shell 自身弹层、而不是被消息里的假 ID 污染**。

**成功/失败判定:**
- 成功:以上 1–6 全部正常;弹层/面板/模型列表正常。
- 失败:模型弹层或功能面板**不弹出 / 弹出被污染 / 静默失效**;或出现 `[WV-9] RENDER-FAIL`/`[WV-9] DISPATCH-PARSE-FAIL`/`[WV-9] SETMESSAGES-FATAL`(这些是本轮新增的隔离日志,出现即说明有更深 bug 被触发)。

**失败抓日志给谁看:**
- `[WV-9] RENDER-FAIL` / `[WV-9] SETMESSAGES-FATAL` → 渲染层
- `[WV-9] DISPATCH-PARSE-FAIL` → 桥/注入层
- `[WV-3] setMessages mode=` → 消息推送
- 弹层不弹出却无日志 → 排查 C1 ID 前缀是否漏改(检查链无法覆盖的运行时行为)

## 十二、我没能验证的部分

1. **真机/模拟器运行**:未跑 app。B1/B2/B3 的行为、C1 后弹层是否真不被劫持,都只有 `dart analyze` + 检查链(`node --check`)的语法级验证,不是运行时验证。
2. **C1 的运行时有效性**:改 ID 前缀能防「消息正文同名 id 劫持 shell」是基于 HTML id 唯一性推理;C1 后 shell 内部引用的 `getElementById('__kira_*')` 是否全部对上(`id="__kira_*"`),只能靠上面的对账表(静态)保证,真机弹层行为未验证。
3. **bridge.js 的 B3 改动是否被检查链真正覆盖**:检查链把 bridge 内容 replaceAll 进主脚本再 `node --check`,所以**语法**上 B3 被覆盖;但 B3 的运行时行为(parse 失败时 root 空才追加提示)未验证。
4. **「消息正文含 id= 就会污染」的复现**:P1-C 背景里"真机见过一次"是给定前提,我无法复现;本轮只能用改前缀的方式防,未验证防的彻底性(比如消息里含 `__kira_model_sheet` 仍可能撞,但概率极低,记账)。
5. **dupIds 数值**:增补说的 `dupIds=464`/`groups 210→350`/`cardIframes 14→19` 都是真机日志数字,我无法核验;仅作为背景引用,未用于论证 C1 成功。
6. **B0 判定的输入数据前提**:「新前插那批消息 script/style/fence 全 false」是增补给的真机观察,我据此判为 C;若该观察有误,结论会变。静态代码无法独立确认这一前提。
7. **generated_plugin_registrant 等 7 个文件的 M 状态**:是本轮之前就存在的构建产物改动,非本轮引入,未触碰。