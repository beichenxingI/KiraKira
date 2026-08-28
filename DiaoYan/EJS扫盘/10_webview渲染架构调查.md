# 10 · webview 消息渲染架构调查

> 调查 C · 零业务改动。探针 commit:`34597ca`(WV-1~7;其中 WV-6 onRenderProcessGone 是唯一功能性新增)。
> 显示域本轮解禁调查;EJS/MVU/bundle/导入链未触碰。

---

## 一、C1 渲染管线全图【实证】

### 1.1 Dart 侧(数据库 → 桥载荷)

```
ChatMessage.content (DB 原文)
 │ ① RegexService.getRegexedString(placement=按角色, isPrompt:false)   ← 角色正则(仅显示向)
 │ ② 剥 <image>…</image>(自动生图占位)
 │ ③ 整消息 ```围栏 解包(^\`\`\`xx\n…\`\`\`$)
 │ ④ 分流切分:
 │    ├─ \`\`\`html 围栏 → 前=旁白(prose) / 内=卡片(body)
 │    └─ <!DOCTYPE|<html 且起点>0 → 前=旁白 / 后=卡片
 │ ⑤ looksLikeHtml(<style|<script|<!DOCTYPE|<html|<head|<body)?
 │    ├─ 是 → 原文直通(_normalizeCodeQuotes)         ←「源码直渲」路
 │    └─ 否 → markdownToHtml + _highlightQuotes      ← Markdown 路
 │ ⑥ 拼 attachmentsHtml → {id,role,prose,html,reasoning,swipe…} → JSON → base64
 ▼
BridgeType.setMessages {data:b64, initial?:true | prepend?:true | 都无=追加}
```

### 1.2 webview 侧(单个 WebView = `_htmlShell()` 巨型字符串经 InAppWebViewInitialData 注入,blob iframe 仅两处:消息卡与隐藏引擎房)

```
setMessages(b64, options):
  initial:true  → root.innerHTML='' 【全量清空】→ 循环重建本次载荷
  prepend:true  → insertBefore(root.firstChild) 【历史前插,20条/批,16ms 间隔,无上界】
  都无          → appendChild 追加新楼层
每条消息:
  prose        → div.innerHTML = m.prose            ← <script> 不执行(HTML5 规范)
  reasoning    → div.innerHTML
  isRichHtml(m.html)(同⑤关键词) == true
               → iframe.card-frame,Blob URL 注入 injectBridge(卡) =
                   条件内联 jquery/lodash/toastr(嗅探 `$(`/`_.`/`toastr.`)
                 + localStorage polyfill + 高度上报桥(__cardHeight) + 动作桥
                 → <script> 在 iframe 内正常执行 ✅
  否           → div.innerHTML = m.html             ← 同样不执行 <script>
appendToken     → wrap.querySelector('.stream-text') 无则 **wrap.innerHTML='' 清块** 再 textContent+=
高度回传        → iframe 内 load 后 200/600/1500ms 三连 + ResizeObserver + 150/500ms debounce
                  → 外层 f.style.height = max(contentH+4, window.innerHeight) ← 视口高度地板
推送时机        → 进入聊天/生成结束/swipe/reroll/编辑/删除/附件变化 ⇒ 一律 _pushMessages()=initial 全量重建
崩溃防护        → onRenderProcessGone 此前【零处理】(本轮已加 WV-6:记日志+自动 reload+重挂消息)
```

## 二、C2 五症状逐条归因

| # | 症状 | 归因 | 级别 |
|---|---|---|---|
| 1 | 重前端会炸 | **无窗口化**:历史 prepend 无上界,DOM 只增不减;**每次交互(含每轮生成结束)全量重建最近30条**,全部富卡 iframe 销毁重建=瞬时创建风暴(解码+脚本重跑+动画重启);**onRenderProcessGone 零处理** → renderer 被 OOM kill 后永久白屏、Flutter 无感知。三者叠加 | 【实证·机制链闭合】 |
| 2 | 旧消息不显示 | ①初始只发最近30条,更早靠后台 prepend 批次——中途 JS 异常/renderer 死亡即中断,**没有重试与断点续传**;②renderer 白屏(同上,WV-6 现已可捕获);③卡片高度地板=max(h,innerHeight) 使长卡互相推挤出视口感 | 【实证】 |
| 3 | 正则后整块消失、源码直出 | **时机错位**:正则(步①)先于围栏/文档识别(步④)。正则改动/破坏 ```html 围栏或外层 ``` 时,卡片 HTML 落入 Markdown 路 → markdown 把失围栏 HTML 当 **fenced code block** → `<pre>` 源码直出("打出源代码");若关键词判定又不过 rich → 双重降级。三条切分路(fence/DOCTYPE/rich 关键词)互斥,正则产物跨路漂移即触发 | 【高嫌疑·机制成立,WV-2 长度轨迹可实锤】 |
| 4 | 多前端无法共存 | 富卡 iframe 本身隔离良好 ✅;破坏来自:①**全量重建把所有运行中的前端同时重启**(状态互踩,观感="互相破坏/某个消失");②非富 HTML 共享主文档 CSS/命名空间(id/class 撞,见 WV-4 dupIds/globalsDelta);③条件库嗅探漏判(`$(`/`_.` 字面量不在卡里但确用)→ 该 iframe ReferenceError;④高度地板互相推挤 | 【实证·多因复合】 |
| 5 | 正则渲染与源码直渲冲突 | 并非两条并行管线,而是**同一管线的分流判定对正则产物敏感**(见#3);真正并行竞争有两处:appendToken 首 token `wrap.innerHTML=''` **整块清掉已渲染卡**(reroll 场景必现,WV-3 CLEARED-WRAP 可抓);setImage 独立通道与主 html 共写 wrap | 【实证】 |

## 三、六个假设的证实/推翻

| 假设 | 判定 |
|---|---|
| A innerHTML 不执行 `<script>` | **证实**。prose/reasoning/非富 html 全走 innerHTML,无任何 script 重注入/eval 补偿;富卡走 blob iframe 才执行 |
| B 转义与正则时机错位 | **变体证实**。无显式 escapeHtml;真身=正则(步①)先于围栏识别(步④),正则破坏围栏 → markdown 把卡片当代码块源码化;"某些路径转义某些不转"的分叉存在(fence/DOCTYPE/rich 三路互斥) |
| C 全局命名空间冲突 | **半证实**。富卡 iframe 隔离 ✅(var/id/CSS 均隔离,localStorage polyfill 也是每 iframe 内存态);冲突集中在**非富 HTML 共享主文档** + **全量重建互踩**;WV-4 dupIds/globalsDelta/onerror 可量化 |
| D DOM 无限增长+不回收→OOM | **证实**。无虚拟化(prepend 无上界);无 renderer 崩溃检测(**本轮已补 WV-6**);生命周期:富卡 iframe 随移除销毁(缓解),主文档 shell 监听器常驻;重建风暴是峰值元凶 |
| E 高度测量失败 | **部分成立**。测量机制本身完备(RO+三连定时+双向防抖);缺陷:①视口高度地板造成长卡推挤;②超过 1.5s 的慢资源且 RO 未触发时滞留;③h≤0/frame 缺失此前静默——WV-7 ABNORMAL 已加。旧消息"不显示"主因是 D 非 E |
| F 两管线共写 DOM | **证实(表述修正)**:正则与直渲是单管线先后分流;实际竞争=appendToken 清块 + setImage 独立通道 + 全量重建互踩,均无幂等保护 |

## 四、C3 耦合面

- **MVU**:不在消息渲染管线内(引擎房镜像+落库)。耦合点只有一个:MVU 写库(updateMessageSwipesData)后调 `_pushMessages()` → 触发全量重建(渲染侧被动)。状态栏=卡片 HTML 走同管线,无特殊通道。
- **角色正则**:管线步①,仅 display 向(`isPrompt:false`);prompt 向正则缺位属提示词侧问题(调查 B 🟢项,不在此)。
- **EJS 显示域接入定位**(只定位不设计):唯一合理介入点=**步⑤之后、JS 注入之前**(即 `_serializeMessage` 组装 m.html 处,渲染文本替代原文),或在卡片 iframe 内直调引擎房 evalTemplate;**不得**走事件总线(调查 B 结论)。
- 时序依赖:MVU 写库→全量重建;正则依赖 scripts provider 就绪(combinedRegexScriptsProvider,已有 ready 门);EJS 直调依赖引擎房就绪(EjsTemplate 挂载)。

## 五、C4 上游(SillyTavern)对照

| 维度 | ST 做法 | 我们能否借 |
|---|---|---|
| script 执行 | 消息块经 jQuery `.html()` 注入——**jQuery 自动提取并执行其中的 script**(这是它前端能跑的关键) | ✅ 思路可借:我们的 blob iframe 已等价达成且更彻底 |
| 多消息 JS/CSS 冲突 | **不做隔离**,同一 document 直接注入;靠社区自觉(IIFE/唯一 id);CSS 互染同样存在 | — 我们无需学它的"不隔离";反而应保持 iframe 沙箱优势 |
| 虚拟化 | 无;长聊照样卡,吃桌面浏览器内存余量 | ❌ 不能照抄:移动 WebView 内存受限,**必须自己做窗口化** |
| 增量更新 | 只 patch 变更楼层的 messageBlock(不整页重建) | ✅ 直接借:diff 定向更新是我们最缺的 |
| 崩溃恢复 | 浏览器 tab 崩了用户自己刷新 | ❌ 必须自建:onRenderProcessGone 自愈(已加)+重挂消息 |

## 六、C5 重构方案(2+1)

### 方案一(推荐):定向 diff 更新 + 消息窗口化 + 崩溃自愈
- **机制**:`setMessages` 改为按 `data-id` diff 的四原语(append/prepend/update/remove),只动变化的楼层;DOM 维持「视口±N」窗口,滚出即摘除(富卡 iframe 随之销毁回收),回滚再重建;swipe/reroll 只重建受影响楼层;appendToken 不再清块(流区追加,富内容保留);保留 WV-6 自愈。
- **对症**:1 ✅(DOM 有界+峰值骤降) / 2 ✅(按需重挂+崩溃自愈) / 4 ✅(不再互相重启) / 5 ✅(流式只动本楼层) / 3 ❌(另行小修,见下)。
- **改动范围**:_htmlShell 内渲染 JS 重写为 diff 引擎 + Dart 推送策略改造(区分首屏/追加/定点);**必然动 _htmlShell**(内容锚点操作);不碰 EJS/MVU/导入。
- **风险**🟡 中;**工作量**:1~2 轮;**渐进性**:✅ diff 失败自动 fallback 全量重建,可开关回退。
- **前置项**:WV-6(已上线);探针数据跑一轮确认主因占比;楼层 id 稳定性(现 data-id=message.id ✅)。

### 方案二:全量卡片 iframe 化(统一沙箱)
- **机制**:所有消息一律走 per-message iframe(轻文本用极简 srcdoc);主文档只剩壳+滚动+楼层 chrome。
- **对症**:3 ✅(不再有 innerHTML/markdown 分叉,统一 blob) / 4 ✅(全面隔离) / 1 部分(配合窗口化) / 2 部分。
- **代价**:每条一个 iframe(必须配窗口化,否则数量爆炸);高度回传机制现成复用;**必动 _htmlShell 渲染分支**;纯文本开销上升。
- **风险**🟡 中;**工作量**:中大;**渐进性**:✅ 把 `isRichHtml` 临时改为恒 true 即可灰度,一键回退。
- 适合作为方案一落地后的第二阶段(先定向更新,再统一沙箱)。

### 方案三(仅记录,不作主案):Shadow DOM/IIFE 作用域化
- CSS 可隔离,但 **Shadow DOM 不隔离 JS 全局**;脚本要手动 eval 才执行;用户手写前端重度依赖 document.getElementById → shadow 内不可达,**兼容风险高**。仅适合未来对非富小卡做局部优化。

**推荐**:方案一骨架先行(直接命中症状 1/2/4/5 主因),症状 3 用独立小修(围栏保护:正则替换后重补 ```html 围栏,或把围栏/文档识别提到正则之前做预标记);方案二作为二期灰度。**前置项只有两个**:WV-6(已上线)+ 探针数据回收。

## 七、探针清单(commit `34597ca`)

| Tag | 位置 | 内容 |
|---|---|---|
| `[WV-1]` | _serializeMessage 出口(Dart print) | id/role/len/script/style/htmlTag/fence/rich —— 分流依据 |
| `[WV-2]` | 同上 | raw→afterRegex→afterUnwrap→body→rendered 长度轨迹(实锤症状3) |
| `[WV-3]` | setMessages 入口(JS→log) | mode=FULL-REBUILD/PREPEND/APPEND + count |
| `[WV-3]` | appendToken 清块分支 | CLEARED-WRAP id/hadHtml(实锤症状5) |
| `[WV-4]` | shell 启动基线+每轮 setMessages 后 | onerror/unhandledrejection 全文;dupIds/globalsDelta |
| `[WV-5]` | 每轮 setMessages 后 | nodes/groups/cardIframes/activeIntervals(增长趋势) |
| `[WV-6]` | InAppWebView.onRenderProcessGone(Flutter) | 崩溃日志 + 自动 reload + 重挂消息(功能性新增) |
| `[WV-7]` | 外层 __cardHeight 处理器 | 每次高度回传值;ABNORMAL(h≤0/frame 缺失) |

## 八、给人类的一句话操作说明

**重启 app(内联 HTML 改动热重载无效!),然后按序复现并 grep `-E "WV-[0-9]"`:**
1. **看增长趋势(症状1/2)**:进入长聊天来回滚动+连续对话 10 轮 → 看 `[WV-5] nodes/groups/cardIframes/activeIntervals` 是否单调上涨不回落;若突然出现 `[WV-6] RENDER PROCESS GONE` → 白屏根因确诊(OOM),且现在会自动恢复了;
2. **看全量重建频率(症状1/4)**:正常聊一轮 → 应看到每轮结束都有一条 `[WV-3] setMessages mode=FULL-REBUILD count≈30`(这就是"所有前端一起重启"的直接证据);
3. **看源码直出(症状3)**:导一张正则会输出 HTML 卡的卡 → 对比该消息 `[WV-2]` 各段长度:若 `body` 长 `rendered` 也长但气泡显示源码 → markdown 代码化实锤;`fence=false rich=false` 但 htmlTag=true 即分流误判;
4. **看重叠冲突(症状4)**:两条富卡同屏 → `[WV-4] dupIds>0` 或 `globalsDelta 异常增大` 或 `[WV-4] onerror` 出现 ReferenceError → 命名空间/库嗅探问题;
5. **看高度(症状2/E)**:出现"消息在但不显示"时 grep `WV-7 ABNORMAL` → h=0/frameFound=false 即高度链断裂;否则量一下该卡 `[WV-7] cardHeight` 值是否被视口地板顶高。
