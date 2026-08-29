# P1-A 打 — 纯 Dart 侧故障隔离(零 JS 改动)

> 基线:`266bc22`(P0 全部完成后)。本轮**零 JS/HTML 改动**,`assets/` 一个字节没动。
> `dart run tool/check_chat_stage.dart` 每步都输出完全一致的 `SYNTAX OK (2 blocks)`,作为回归护栏。

---

## 一、`_serializeMessage` 调用点实际数量

先用 grep 全文检索(`_serializeMessage` 与复数 `_serializeMessagesForMvu` 是**两个不同方法**,指令问的是前者):

```
2787: Map<String, dynamic> _serializeMessage(          ← 定义
2910: list.add(_serializeMessage(...))                  ← 调用 1:append(_appendNewMessages)
2961: initialList.add(_serializeMessage(...))           ← 调用 2:initial(_pushMessages 首屏)
3005: batch.add(_serializeMessage(...))                 ← 调用 3:prepend 历史批(_pushMessages)
```

**调用点 = 3 处,与指令预期一致。** 定义 1 处(2787)。另外 `_serializeMessagesForMvu()`(复数)是**另一个**方法(喂给引擎房事件),不属本轮范围,未动。

---

## 二、从 `backup/c1-alpha-failed` 复用了什么、改了什么

| 项 | 来源 | 复用/改动 |
|---|---|---|
| `_safeSerializeMessage` | c1-alpha-failed 里有(2793) | **复用**其结构:try 包裹 + 降级 map。改动:role 从硬编码 `'system'` 改为保留 `m.role.name`;正文从纯 `$e` 改为「此消息序列化失败：$e\n原文(前200字)：$raw」,补充原文前 200 字(与 P0-4 A1 要求一致) |
| `_wvCrashCount` | c1-alpha-failed 里有(81、550-552) | **复用**其上限思路(>3 停止 reload)。改动:c1-alpha 超限只 `return`(静默),本轮**补了 SnackBar 可见提示 + 重新加载按钮**(A5 硬要求"不许静默白屏") |
| `_sendEncodedMessages` | **不在** c1-alpha-failed,在 `backup/p1-failed`(2827) | **复用**其三步结构(批量 try → 逐条降级 → 全失败占位)。改动:占位文案里 `\n` 换成 `</p><p>`(前台不出现跨行),并把 body 里 `...extra()`. |

> 说明:A2 的核心实现 `_sendEncodedMessages` 实际存在 `backup/p1-failed` 而非 c1-alpha-failed。c1-alpha-failed 的 `_safeSerializeMessage` 是一套单条兜底,但**它没有**批量三步接口。指令点名 c1-alpha 是让我复用那两处 Dart 逻辑(它们本身未被证伪);A2 的批量接口我从 p1-failed 取标准实现。两条来源我都读过再动手,报告如实标注。

---

## 三、五个 Task 与五个 commit

### Task A1 — 单条序列化兜底

- **命中行**:定义 2914 `Map<String, dynamic> _safeSerializeMessage(`,三处调用 3020 / 3070 / 3108。
- **锚点**:`String _serializeMessage(` 方法结束后、`/// prev 是否为 next 的前缀` 之前插入新方法;三处 `.add(_serializeMessage(...))` 改为 `.add(_safeSerializeMessage(...))`。

改前(3 处调用之一,append 为例):

```dart
    for (var i = startFrom; i < messages.length; i++) {
      list.add(_serializeMessage(messages[i], i, lastAiIndex, character, scripts));
    }
```

改后:

```dart
    for (var i = startFrom; i < messages.length; i++) {
      list.add(_safeSerializeMessage(messages[i], i, lastAiIndex, character, scripts));
    }
```

新增方法:

```dart
  Map<String, dynamic> _safeSerializeMessage(
      ChatMessage m, int i, int lastAiIndex, Character? character, List<RegexScript> scripts) {
    try {
      return _serializeMessage(m, i, lastAiIndex, character, scripts);
    } catch (e) {
      print('[WV-8] SERIALIZE-FAIL id=${m.id} err=$e');
      String raw = m.content;
      if (raw.length > 200) raw = raw.substring(0, 200);
      return {
        'id': m.id,
        'role': m.role.name,
        'prose': '此消息序列化失败：$e\n原文（前200字）：$raw',
        'html': '',
        'reasoning': '',
        'swipeCount': m.swipes.length,
        'swipeIndex': m.currentSwipeIndex,
        'floor': i + 1,
        'isLatestAi': i == lastAiIndex,
      };
    }
  }
```

原因:单条 `_serializeMessage` 抛错不再中断整批,降级为可见占位 + 打日志。

- commit:`73e3e2b`

### Task A2 — 批量序列化兜底(本轮最关键)

- **命中行**:方法 2939 `Future<void> _sendEncodedMessages(`,三处调用 3024 / 3091 / 3115。
- 新增 `_sendEncodedMessages`(复用 p1-failed `_sendEncodedMessages`),三步**:整批 try → 逐条降级(每条 try)→ 全失败发可见占位**。三处发送点(`append`/`initial`/`prepend`)全改成走它。

改前(initial 发送,`_pushMessages` 内):

```dart
    final initialJson = jsonEncode(initialList);
    final initialB64 = base64Encode(utf8.encode(initialJson));
    ...
    _bridge.send(BridgeType.setMessages, {
      'data': initialB64,
      'initial': true,
      'avatars': { ... },
    });
```

改后:

```dart
    await _sendEncodedMessages(initialList, initial: true, avatars: {
      'char': charUri,
      'user': userUri,
      'charName': character?.name ?? 'Assistant',
      'userName': persona?.name ?? 'User',
    });
```

原因:把"批量 encode 三步全裸"收进一个带兜底的方法,杜绝"整批静默不发"。

- commit:`8274310`

### Task A3 — U+2028 / U+2029 注入转义

- **命中行**:`chat_bridge.dart` 247 `void _dispatch(...)`,255 `\u2028`。

改前:

```dart
  void _dispatch(String type, Map<String, dynamic> payload) {
    try {
      onLog?.call('▶ outbound $type');
      final json = jsonEncode({'type': type, 'payload': payload});
      // WebView 侧实现一个全局 dispatch(jsonString) 做出站路由。
      _controller?.evaluateJavascript(
        source: 'window.__bridgeDispatch(${jsonEncode(json)});',
      );
    } catch (e) {
      onLog?.call('✖ outbound error ($type): $e');
    }
  }
```

改后:

```dart
  void _dispatch(String type, Map<String, dynamic> payload) {
    try {
      onLog?.call('▶ outbound $type');
      var json = jsonEncode({'type': type, 'payload': payload});
      // [P1-A3] U+2028/U+2029 在 ES2019 之前的 JS 字符串字面量里非法，
      // 而 dart:convert 的 jsonEncode 默认不转义它们 → 旧 Android WebView 上整条注入 SyntaxError。
      json = json
          .replaceAll('\u2028', r'\u2028')
          .replaceAll('\u2029', r'\u2029');
      _controller?.evaluateJavascript(
        source: 'window.__bridgeDispatch(${jsonEncode(json)});',
      );
    } catch (e) {
      onLog?.call('✖ outbound error ($type): $e');
    }
  }
```

原因:纯防御,把旧 WebView 上非法的行/段分隔符显式转义,不改协议与语义。

- commit:`5ee3432`

### Task A4 — prepend 批内倒序

- **命中行**:3108 批内 `_safeSerializeMessage`,3115 `batch.reversed.toList()`。
- **JS 侧只读确认**(asset,未改):asset 第 1132 行原文:

```js
root.insertBefore(group, root.firstChild);
```

确认 JS 侧 prepend 是逐条反向前插 → Dart 升序发批会倒序 → `batch.reversed` 补偿。

改前:

```dart
            await _sendEncodedMessages(batch, prepend: true);
```

改后:

```dart
            // [P1-A4] JS 侧 prepend 逐条 insertBefore(root.firstChild) 是反向插入，
            // 升序发批会导致批内阅读顺序颠倒 → 发送侧用 batch.reversed 补偿。
            // 这是「补偿 JS 反向插入」的隐式耦合；P2 应改为 JS 侧用固定锚点插入、
            // Dart 保持自然升序，还这块解耦。
            await _sendEncodedMessages(batch.reversed.toList(), prepend: true);
```

原因:批内阅读顺序归正;注释标注隐式耦合 + 记入 P2 待办。

- commit:`73c0a11`

### Task A5 — 崩溃自愈上限 + 可见提示

- **命中行**:88 `_wvCrashCount`,365 `_reloadWebViewAfterCrash`,625-640 `onRenderProcessGone`。

改前:

```dart
                  onRenderProcessGone: (controller, detail) {
                    print('[WV-6] RENDER PROCESS GONE didCrash=${detail.didCrash} -> auto reload');
                    controller.reload();
                    Future.delayed(const Duration(milliseconds: 800), () {
                      if (mounted) {
                        _pushMessages();
                      }
                    });
                  },
```

改后:

```dart
                  onRenderProcessGone: (controller, detail) {
                    _wvCrashCount++;
                    print('[WV-6] RENDER PROCESS GONE didCrash=${detail.didCrash} x=$_wvCrashCount');
                    if (_wvCrashCount > 3) {
                      print('[WV-6] 超过自愈上限(3),停止自动 reload');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('渲染已多次异常,请点击重新加载'),
                            duration: const Duration(seconds: 6),
                            behavior: SnackBarBehavior.floating,
                            action: SnackBarAction(
                              label: '重新加载',
                              onPressed: _reloadWebViewAfterCrash,
                            ),
                          ),
                        );
                      }
                      return;
                    }
                    controller.reload();
                    Future.delayed(const Duration(milliseconds: 800), () {
                      if (mounted) {
                        _pushMessages();
                      }
                    });
                  },
```

新增字段与方法:

```dart
  int _wvCrashCount = 0; // [WV-6/P1-A5] renderer 崩溃自愈次数上限,防"崩→reload→再崩"死循环
  ...
  void _reloadWebViewAfterCrash() {
    _wvCrashCount = 0;
    _controller?.reload();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        _pushMessages();
      }
    });
  }
```

原因:超限停 reload 防死循环;给 SnackBar 可见提示 + 重新加载按钮,不许静默白屏。

- commit:`06c4b34`

---

## 四、五个 commit 的 hash + 各自验证输出

每个 Task 提交后都跑了三条验证:`dart analyze`(零 error)、`dart run tool/check_chat_stage.dart`(SYNTAX OK)、`git diff --stat -- assets/`(空)。

| commit | hash | dart analyze | 检查链 | assets diff |
|---|---|---|---|---|
| A1 | `73e3e2b` | `error_count=0` | `SYNTAX OK (2 blocks)` | 空 |
| A2 | `8274310` | `error_count=0` | `SYNTAX OK (2 blocks)` | 空 |
| A3 | `5ee3432` | `error_count=0` | `SYNTAX OK (2 blocks)` | 空 |
| A4 | `73c0a11` | `error_count=0` | `SYNTAX OK (2 blocks)` | 空 |
| A5 | `06c4b34` | `error_count=0` | `SYNTAX OK (2 blocks)` | 空 |

代表样例(每次输出一致,三次验证原始输出):

```powershell
dart analyze
# (1098→1103 issues,全 warning/info;error_count=0)

dart run tool/check_chat_stage.dart
── block 1/2  (build/check_block_1.js, 1259 chars)
   OK
── block 2/2  (build/check_block_2.js, 60602 chars)
   OK
SYNTAX OK (2 blocks)

git diff --stat -- assets/
# (空)
```

> 注:全量 `dart analyze` 的 issues 数从 1098(A1 后多 1 条 print)→1103(A2 后多 5 条,`_sendEncodedMessages` 里的 `print`)递增,**全部是既有的 `avoid_print` 风格 info 级 lint**,error 恒为 0。指令要求的"零 error"成立;那些 `print` 是 WV-8 探针日志,与现有 `[WV-1..7]` 的 `print` 一脉相承,非本轮引入的新问题类别。

---

## 五、给人类的复测说明

**重启 app**(杀进程重开;本轮改了 Dart 运行时逻辑,不能热重载)。

1. **正常聊一轮**:发几条消息,看 AI 回复、流式逐字追加、气泡/楼层/版本切换条正常。
2. **reroll 两三次**:看改动后消息渲染正常、无"全灭"、无空白。
3. **百条长聊滚到底**:从顶滚到底,看历史消息(prepend 批)阅读顺序**正序**、无倒置、无跳漏。

**grep 哪些 tag、各结果意味着什么、什么算失败**:

| grep tag | 正常(成功) | 异常(失败) |
|---|---|---|
| `[WV-8] SERIALIZE-FAIL` | **从不出现** | 出现 = 某条消息序列化失败走了降级占位(需看 err 定位) |
| `[WV-8] BATCH-ENCODE-FAIL` / `ITEM-ENCODE-FAIL` / `PLACEHOLDER-ENCODE-FAIL` | 从不出现 | 出现 = 批量/逐条编码层出了问题(这是兜底被触发的信号,说明有更深的 bug) |
| `[WV-6] RENDER PROCESS GONE ... x=` | 只出现 1~3 次且后来自动恢复 | 出现 `超过自愈上限(3)` = 连续崩溃,应有 SnackBar 提示 |
| `[WV-3] setMessages mode=` | FULL-REBUILD(首屏)/APPEND(追加)/PREPEND(历史前插)交替,计数正常 | 完全没这条 = 消息根本没进 JS 侧 |
| `[bridge]` / `[TH中转]` | 桥往返正常 | `no JS handler` / `[dispatch错误]` = 桥断了 |
| 引号/方括号颜色 | 跟随主题 | 固定不动 = 颜色占位没替换(本轮不该出,因零 JS 改动) |

**什么算失败**:出现任何 `[WV-8]` 系列错误日志;`[WV-3]` 计数异常或完全缺失;reroll 后消息错乱;百条长聊 prepend 顺序倒置;崩溃超 3 次后**没有** SnackBar 提示(白屏)。

**失败抓日志给谁**:WV-8 系列 → 串序列化/编码的人;WV-6 → 渲染进程/崩溃的人;WV-3 → 消息推送管线的;`[bridge]` → 桥的人。

---

## 六、我没能验证的部分

1. **真机/模拟器运行**:未跑 app。A1/A2/A4/A5 的行为改变(尤其是 U+2028 在旧 Android WebView 的实际表现、崩溃自愈上限的触发、prepend 顺序归正)都只做了静态推导 + `dart analyze`/检查链,不是运行时验证。
2. **`SnackBar` 在 `onRenderProcessGone` 上下文里是否稳定弹出**:用了文件内既有的 `ScaffoldMessenger.of(context).showSnackBar` 模式(4 处先例),但「renderer 崩溃」这个特殊时机下 context 是否还可用、SnackBar 是否来得及显示,未验证。
3. **`batch.reversed.toList()` 是否真能还原阅读顺序**:只确认了 JS 侧 `insertBefore(root.firstChild)` 是反向插入(asset 1132 行),并做了逻辑推导;真机上几十条历史从顶滚到底的顺序未验证。
4. **U+2028/U+2029 转义的运行时正确性**:`r'\u2028'` 是 Dart raw 字符串(输出字面 `\u2028` 六个字符,再被 `jsonEncode(json)` 二次转义成 JS 可读的 `\\u2028`),字符串层面的拼接正确性可推,但最终在旧 WebView 的注入结果未验证。
5. **`_wvCrashCount` 之外是否还有别的"崩→reload"路径**:本轮只加这一个自愈入口;p1-failed 里 `_reloadWebViewAfterCrash` 与之配合;其它潜在崩溃源未排查(记账,不属本轮范围)。
6. **`avoid_print` info 级 lint 增加**:A1/A2 新增了若干 `print`(WV-8 探针),与现有 `[WV-1..7]` 风格一致,但确实让 `dart analyze` 的 info 数上涨(1097→1103)。这是探针日志的既有模式,非 error;未改用 KiraLogger(那会是超出指令范围的风格改造)。