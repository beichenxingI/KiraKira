# P3-F G3：segs 分类设计

日期：2026-08-31

## 1. 现有判定链

### 1.1 正则管线

`lib/domain/services/regex_service.dart:145-199`：

1. `result = input`。
2. 按 `order` 排序脚本。
3. 逐条检查 disabled、placement、markdownOnly/promptOnly、edit、depth。
4. 第 189-195 行把当前 `result` 交给 `runRegexScript`，返回值再次赋给 `result`。
5. 因此后一条正则可以命中前一条正则刚产生的文本；当前 API 只返回最终字符串，不返回替换来源和区间。

真实卡脚本：`DiaoYan/PiuPiuCard_《道渊》v5.2.json` 的 regex_scripts[6]「MVU状态栏」与 [7]「开局创造人物2」均启用、均为 `markdownOnly=true`，替换结果都是完整 HTML 文档并带一对 ` ```html ` 围栏。

### 1.2 Dart 序列化

`lib/presentation/screens/chat/webview_chat_stage.dart:2861-2953`：

| 行号 | 判定/动作 |
|---|---|
| 2863-2877 | 用真实 `RegexService.getRegexedString` 处理消息 |
| 2879-2881 | 删除 `<image>...</image>` |
| 2882-2888 | `codeBlockMatch`：`^```[a-zA-Z]*\\n([\\s\\S]*?)```\\s*$`，全文锚定；只有整条消息是一个围栏时命中，命中后剥掉外层围栏 |
| 2893-2896 | `htmlFenceMatch`：只取第一个 ` ```html` 围栏 |
| 2899-2906 | 围栏前转 Markdown prose，围栏内放入 `bodyForRender`；围栏后没有变量承接，静默丢弃 |
| 2907-2920 | 没有 html 围栏时，找第一个 `<!DOCTYPE` 或 `<html`；前段转 prose，文档起点之后进入 `bodyForRender` |
| 2921-2930 | `looksLikeHtml` 命中 `<style|<script|<!DOCTYPE|<html|<head|<body` 才走 `normalizeCodeQuotes`，否则走 Markdown |
| 2931-2953 | 产出单份 `prose`、单份 `html`，以及附件字段 |

T9 离线真实管线结果：

- `T9_both_markers_1_afterRegex.txt` 长度 390079。
- 两个围栏：第 1 个内容长度 182928，第 2 个内容长度 207124。
- 围栏外碎片为长度 4 的 `旁白。\\n` 与长度 1 的换行。
- 当前 `firstMatch/group(1)` 只保留 182928 字符，207124 字符整份被丢弃。
- 两份文档内部均无嵌套 ```` ``` ````，因此本卡样本可用 `allMatches` 无歧义地配对。

### 1.3 JavaScript 渲染分岔

`assets/chat/chat_stage.html`：

- `isRichHtml`：484-487，正则为 `<style|<script|<!DOCTYPE|<html|<head|<body`。
- `setMessages`：1354-1519。
- 1423-1447：`isRichHtml(m.html)` 为真就创建一个 `iframe.card-frame`，把 `m.html` 存入 `data-html`，并以 `m.id` 调用 `injectBridge`；否则 1448-1455 将 HTML 放进普通气泡的 `innerHTML`。
- 1404-1409：`m.prose` 始终作为普通 prose 气泡插入。
- 1240-1294：IntersectionObserver 以 iframe 为粒度虚拟化；离开缓冲区时记录高度并设 `src='about:blank'`，回来时从 `data-html` 重新 `injectBridge`。
- 615-628：card iframe 单独上报 `__cardHeight`。
- 1001-1014：主文档按 `id` 找对应 iframe、记录 `[WV-7]`、按该 frame 设置高度。

### 1.4 `markdown@7.3.0` 的安全事实

真实管线 T8 输出表明 `md.markdownToHtml`（`ExtensionSet.gitHubWeb`）不会删除或转义 `<script>`；但普通气泡是把结果放入已有 DOM 的 `innerHTML`，不会因 `innerHTML` 赋值而执行其中的 script。进入 card iframe 的 `srcdoc/blob` 路径则会执行 script。因此“是否进 iframe”是执行边界，不能仅凭“含 HTML”决定。

## 2. 可用信号清单

| 信号 | 可靠性 | 成本 | 结论 |
|---|---|---|---|
| 围栏语言为 `html` | 中；AI 也常用 `html` 展示源码 | 极低 | 只能作为候选边界，不能单独判前端 |
| 围栏语言为 `js`/其它 | 高；当前前端替换脚本固定使用 `html` | 极低 | 保留在 prose，让 Markdown 原生显示代码块 |
| `<!DOCTYPE`、`<html` | 中高；本卡两个启用前端均有，完整 HTML 源码也有 | 极低 | 与完整文档结构组合使用 |
| `<head>`、`<body>` | 中高；比单个 `<div>` 更像完整文档 | 极低 | 作为现有 `isRichHtml` 的兼容信号 |
| `<script>` 或 `<style>` | 中；可执行源码也会有 | 极低 | 沿用现有 `isRichHtml`，不能单独当来源证明 |
| 内容长度 | 中高；本卡前端约 18-21 万字符，普通代码通常较短 | 极低 | 只作诊断和置信度，不设硬阈值；硬阈值会误伤小前端和开场白 |
| 是否由正则替换产生 | 理论最高 | 高 | 当前 `getRegexedString` 只返回最终字符串；要获得来源需改变正则服务返回类型/记录区间，触碰禁止区域，不能作为本轮实现信号 |
| 原始消息是否包含该文档 | 中；可辅助判断，但开场白完整前端本来就在原文中 | 低 | 不作为主规则，否则会误判 `first_mes` |
| `markdownOnly`/`promptOnly` | 高，但它们是脚本执行过滤条件，不是最终片段来源 | 低 | 已在正则管线中生效，分类器不重复猜测 |
| 官方 iframe 名称 | 高（API 约定） | 低 | 必须使用官方形状：`TH-message--楼层号--该楼层第几个界面` |

官方依据：`DiaoYan/ref/slash-runner-types/iframe/util.d.ts:32-46`。其中 `getIframeName()` 的注释明确给出 `TH-message--楼层号--前端界面是该楼层第几个界面`，`getCurrentMessageId()` 只能在楼层消息 iframe 中使用。声明文件没有提供“代码块 vs 前端”的额外分类 API。

## 3. 可判定规则表

分类器只负责切出 ` ```html` 围栏；其它 Markdown 围栏不拆，交给 Markdown 原生处理。HTML 围栏体使用与现有 `isRichHtml` 相同的兼容谓词，避免单前端行为改变。

| 片段特征 | 判为 | 依据 | 置信度 |
|---|---|---|---|
| 无 ` ```html` 围栏，且保留现有 docStart 分支 | 按旧路径 | 单前端回归的硬约束 | 高 |
| ` ```html` 围栏体命中 `<style|<script|<!DOCTYPE|<html|<head|<body` | frontend | 与现有 `looksLikeHtml` 和 `isRichHtml` 完全一致；当前卡的两个前端均满足 | 高 |
| ` ```html` 围栏体不命中上述谓词 | prose/Markdown 片段，内容取围栏体 | 复刻旧 `htmlFenceMatch.group(1)` 后走 Markdown 的行为；不执行 script | 中高 |
| ` ```js`、` ```css`、` ```json` 或无语言围栏 | prose/Markdown | 非当前前端替换格式，Markdown 原生代码块行为保留 | 高 |
| 两个 html 前端之间的普通文本 | prose/Markdown | 不再丢弃围栏后的文本 | 高 |
| 完整 HTML 文档直接出现在无围栏消息中 | 旧 docStart 路径 | 保持现有行为 | 高 |
| 未被正则替换的 `<StatusPlaceHolderImpl/>` 等普通标记 | prose/Markdown | 只有正则命中后才形成前端文档 | 高 |

### 3.1 无法判定的情况

“AI 输出完整 HTML 源码只是想让用户阅读”与“AI 输出完整 HTML 前端希望执行”在文本结构上不可区分：二者都可能是 ` ```html`、都可能包含完整文档、script、style，长度也没有可靠上限。当前系统本来就会把这类完整文档送入 iframe 执行；本轮不凭空增加来源推断，也不改变这类单前端行为。

兜底策略：

1. 按现有兼容谓词判为 frontend，保持已工作的开场白和卡前端。
2. 任何无法识别为 frontend 的围栏保留为 prose，不执行其中脚本。
3. G4 对被切出的每个片段打可见诊断日志（至少包含消息 id、段序号、类型），禁止静默丢弃。
4. 后续若需要安全的“显示源码/作为前端运行”用户开关，应作为独立任务设计；不能在本轮用长度阈值偷偷改变行为。

## 4. 切段算法伪码

```text
serialize(message):
    processed = existing_regex_image_strip_code_unwrap(message)

    if processed contains no ```html fence:
        return existing_docStart_and_looksLikeHtml_path(processed)

    segs = []
    cursor = 0
    for each match in allMatches(```html\s*\n([\s\S]*?)```):
        gap = processed[cursor : match.start]
        if trim(gap) != '':
            segs.append(Prose(markdown(gap)))

        body = match.group(1)
        if isRichHtml(body):
            segs.append(Frontend(normalizeCodeQuotes(body)))
        else:
            segs.append(Prose(markdown(body)))
        cursor = match.end

    tail = processed[cursor:]
    if trim(tail) != '':
        segs.append(Prose(markdown(tail)))

    return segs
```

实现时必须保留单前端旧字段和旧路径：只有检测到多个可拆分片段时才启用新 `segs` 消费路径；单前端的 `prose`、`html` 应逐字对拍旧输出。

## 5. 数据结构与改动面

### 5.1 Dart

- `webview_chat_stage.dart:2861-2953`：增加 `segs` 字段和切段结果。
- `webview_chat_stage.dart:2957-2977`：序列化失败占位需提供可见 prose；必要时给 `segs` 一个 prose 兜底。
- 旧 `prose`/`html` 字段继续保留，供单前端和旧消息兼容。
- 附件不能静默丢：若消息存在 attachments，应作为最后一个普通 HTML/prose 片段，或在兼容字段中按旧顺序保留。

### 5.2 主文档 setMessages

- `chat_stage.html:1354-1519`：若有 `segs`，按顺序创建 prose 节点和 iframe；没有 `segs` 时走原路径。
- 每个 frontend frame 需要独立 `data-html`、`data-frame-id`、`data-floor`。
- 推荐 id：`TH-message--<floor>--<index>`，index 为该楼层前端出现顺序；非 frontend prose 不占 index。
- `__kiraMsgFloorMap`（1366-1373）要为每个 frame id 映射到同一 `floor-1`，使 `getVariables/setVariables` 的字符串 message_id 规范化不丢楼层。
- `getIframeName()` 当前没有实现，G4 需要增加并返回当前 frame id；`getCurrentMessageId()` 现有返回值是 frame id，需确保其字符串 id 能由本地规范化映射回数字楼层。

### 5.3 变量广播与 MVU

`chat_stage.html:970-1014`、`1045-1109` 已按 iframe 粒度广播/接收。多 frame 只要都带 `data-frame-id` 且排除 engine-room，就会收到同一楼层快照；同一消息的多个前端共享同一 `floor_idx`，符合 MVU 消息级变量语义。

### 5.4 虚拟化

`chat_stage.html:1240-1294` 已按 iframe 粒度工作。每个 frame 自己保存 `data-html` 和 `data-last-height`，清空与恢复无需按消息组重写；施工时必须验证多 frame 都能独立恢复。

### 5.5 高度

card 侧 `chat_stage.html:615-628` 每个 iframe 独立上报 `__cardHeight`；主文档 `1001-1014` 以 frame id 设置高度。气泡容器是普通流式布局，多个 frame 的总高度由 DOM 流布局自然累加，不应人为取最大值或覆盖前一个 frame 高度。必须保留 `h<=0` 的 `[WV-7]` 可见日志。

## 6. 单前端回归保证

1. 单 html 前端（包括《道渊》开场白）继续使用旧 `prose`/`html` 字段和旧 iframe 创建代码。
2. `pipeline_repro.dart` 对 T1、T2、T3、T5 做改前/改后逐字对拍：`bodyForRender`、`proseHtml`、`rendered` 均相同。
3. 多前端只新增 `segs` 字段和新消费路径；旧字段仍保留，便于快速回退。
4. 多前端的每个 frontend seg 用原有 `injectBridge`，不改变库注入、桥字段和 `_TH` 现有实现。

## 7. Commit 与验证拆分

### G4-C1：Dart 切段与兼容字段

- 只改 Dart 序列化；JS 暂不消费 `segs`。
- 验证 T1/T2/T3/T5 逐字对拍、T9 两段长度、`dart analyze`。

### G4-C2：JS 多 frame 消费与命名

- 消费 `segs`，按段创建多个 frame；新增 `getIframeName`；维护 floor map。
- 单前端无 `segs` 或单段继续旧路径。
- 验证 `check_chat_stage.dart`、injectBridge 提取器、单前端 harness、双前端 harness、`dart analyze`。

### G4-C3：虚拟化/高度与诊断

- 若前两步暴露必要改动，再独立修改；否则只做离线验证不产生产品改动。
- 验证双 frame 清空/恢复、两个独立高度上报、无 0 高度压扁。

每个产品 commit 都必须运行：

```text
dart run tool/check_chat_stage.dart
dart analyze
git status --short
```

涉及拼接 JS 的 commit 额外运行：

```text
node DiaoYan/P3/诊断/extract_inject_bridge_patch.js
node DiaoYan/P3/诊断/extract_engine_room_doc.js
```

## 8. 是否安全施工

**可以安全施工，但只允许以兼容路径施工。** 规则直接复用现有 `isRichHtml`，不使用未经验证的长度阈值或正则来源猜测；单前端保持旧字段/旧渲染路径；多前端每段显式保留，围栏后内容不再静默丢弃。G4 的主要风险集中在 JS 的多 frame DOM、命名、floor map 和高度回归，可由双前端 harness 分步验收。
