# P3-F 交付报告

日期：2026-08-31

## 1. 基线

HEAD 基线为 `7a43f76`。G2 产品 commit：`25ea329`；G4-C1：`eadeb00`；G4-C2：`1570ba8`。

开工时原始命令输出：

```text
?? DiaoYan/P3/API基线.txt
?? DiaoYan/P3/P3-0_样本解剖.md
?? DiaoYan/P3/P3-B_打.md
?? DiaoYan/P3/P3-C_打.md
?? DiaoYan/P3/P3-D_打.md
?? DiaoYan/P3/P3-E_打.md
?? DiaoYan/P3/P3-诊断_UI脚本去哪了.md
?? DiaoYan/P3/mvu.txt
?? DiaoYan/P3/样本解剖/
?? DiaoYan/P3/诊断/
?? DiaoYan/PiuPiuCard_《道渊》v5.2.json
?? DiaoYan/recover_world_info_screen.dart
?? DiaoYan/ref/
7a43f76 feat(wv): P3-E3c 引擎房_TH.eventEmit加__mvuEvent上行转发——MVU事件经主文档中继__thEvent到card本地总线,补齐事件链路最后一跳
27e31e8 fix(wv): P3-E3b TH中转getVariables也走__thNormVarOption规范化message_id——防字符串iframe id透传Dart致th_getVars查错楼层
665ad3c feat(worldinfo): P3-E/Z 全局世界书入口恢复——捞回WorldInfoScreen/_WorldInfoCard/_WorldInfoDialog三类;路由收窄为仅isGlobal模式(砍characterId歧义分支);仅恢复ai_config设置页一个入口;删零引用死文件world_book_injection_service.dart
0ced887 feat(wv): P3-E2/E3 Mvu数据链接通——主文档接window.Mvu+轮询10s结论;card快照store(__thVars信封)+门控延迟挂Mvu;Mvu facade(getMvuData同步读/replaceMvuData乐观写/事件表);getAllVariables同步化治状态栏无数字;存量快照推送+card广播+MVU事件中继
ff71768 fix(wv): P3-E1 引擎房doc拼接修病灶——1527孤立'<script>'未闭合致块内裸标签SyntaxError、1526/1528重复init删一、1508/1509重复var doc删一;新增extract_engine_room_doc.js拼接产物逐块vm.Script语法检查
6daf71f fix(wv): P3-D3 injectBridge注入分支全改函数形式替换串——防卡文里的替换引用($&/$''/$1-9)被replace吞掉或展开
```

## 2. G1 闸门：通过

测试数据来源：

- 卡 `DiaoYan/PiuPiuCard_《道渊》v5.2.json` 的 `data.character_book.entries` 中 `[initvar] 初始`，字段结构共 430 字符。
- `DiaoYan/P3/run.log` 是 UTF-16LE；其中唯一 `[setVars落]` 行的真实 `stat_data` 已提取至 `DiaoYan/P3/诊断/out/G1_stat_data_real.json`。
- U1 为真实结构、仅将主角可观测值改为：姓名`测试仙尊`、生命`77`、精血`66`、灵力`55`、修为`42`、神识`88`、道心`33`。完整 JSON 在上述文件，原始 initvar YAML 在 `G1_initvar_raw.txt`。

选择器来自 regex_6：`#name-value`、`#hp-value`、`#blood-value`、`#mp-value`、`#exp-value`、`#san-value`、`#daoxin-value`。

### U1：动态投喂

`g1_U1d_host.html`：iframe load 后 300ms 投喂 `{__thVars:true,type:"message",data:{stat_data},floor_idx:3,lastMsgId:3,swipe_id:0}`。

原始结果：

```text
[iframe] [probe-installed] readyState=loading
[host] iframe load
[iframe] [REPORT:onload] Mvu=undefined name-value=(空) hp-value=(空) blood-value=(空) mp-value=(空) exp-value=(空) san-value=(空) daoxin-value=(空) stat_data=null
[host] 已投喂 message 快照 floor_idx=3 lastMsgId=3
[iframe] [Mvu] card(TEST_CARD_0) 快照首次到达(经挂载门控)
[iframe] [Mvu] card(TEST_CARD_0) 已挂 window.Mvu(快照门控通过)
HARVEST_DONE
[REPORT x31, 最后一条] [iframe] [REPORT:ping30] Mvu=object name-value=测试仙尊 hp-value=77/100 blood-value=66/100 mp-value=55/100 exp-value=42/100 san-value=88/100 daoxin-value=33/100 stat_data=HAS(stat_data)
```

CARD-ERR：0。U1 明确通过：动态快照到达后，`window.Mvu` 定义，`getAllVariables()` 同步返回带 `stat_data` 的对象，状态栏出现真实数字。

### U2：完全不投喂

```text
[iframe] [probe-installed] readyState=loading
[host] iframe load
[iframe] [Mvu] getAllVariables 快照未就绪, 返回空 (id=TEST_CARD_0, floor=3)
[iframe] [REPORT:onload] Mvu=undefined name-value=(空) hp-value=(空) blood-value=(空) mp-value=(空) exp-value=(空) san-value=(空) daoxin-value=(空) stat_data=null
HARVEST_DONE
[iframe] [waitGlobalInitialized] 仍在等待 window.Mvu (id=TEST_CARD_0, 已等10s, 不超时)
[REPORT x31, 最后一条] [iframe] [REPORT:ping30] Mvu=undefined name-value=(空) hp-value=(空) blood-value=(空) mp-value=(空) exp-value=(空) san-value=(空) daoxin-value=(空) stat_data=null
```

CARD-ERR：0。`window.Mvu` 始终 undefined；`getAllVariables()` 的空结果被记录一次；init 停在等待；数值节点为空而不是一堆 `0/100`。U2 通过，也证明 G2 的静默口子确实存在。

### U3：5 秒晚到

```text
[iframe] [probe-installed] readyState=loading
[host] iframe load
[iframe] [REPORT:onload] Mvu=undefined name-value=(空) hp-value=(空) blood-value=(空) mp-value=(空) exp-value=(空) san-value=(空) daoxin-value=(空) stat_data=null
[host] 晚到投喂 message 快照 floor_idx=3 lastMsgId=3
[iframe] [Mvu] card(TEST_CARD_0) 快照首次到达(经挂载门控)
[iframe] [Mvu] card(TEST_CARD_0) 已挂 window.Mvu(快照门控通过)
HARVEST_DONE
[REPORT x31, 最后一条] [iframe] [REPORT:ping30] Mvu=object name-value=测试仙尊 hp-value=77/100 blood-value=66/100 mp-value=55/100 exp-value=42/100 san-value=88/100 daoxin-value=33/100 stat_data=HAS(stat_data)
```

CARD-ERR：0。U3 通过；晚到快照仍能使数字出现。

G1 结论：**通过**。

## 3. G2

口子位置：`assets/chat/chat_stage.html:874-889`。

- `__thBuildAllVars()` 原来在 global/chat/message 都无有效数据时直接返回 `{}`。
- `_TH.getVariables()` 原来直接返回空表。
- 新增首次空快照日志，仍返回 `{}`，不改同步性、不返 Promise、不抛错。
- `__thArmMvu()` 与快照监听器增加“快照首次到达”日志，并重置空快照日志节流状态。

G2 commit：`25ea329`。

## 4. G3

设计文件：`DiaoYan/P3/segs_分类设计.md`。

结论：**可安全施工**。规则复用现有 `isRichHtml` 谓词，不设任意长度阈值，不触碰正则管线：

- ` ```html` 围栏体命中 `<style|<script|<!DOCTYPE|<html|<head|<body` → frontend。
- 其它 html 围栏体 → prose/Markdown，内容取围栏体。
- `js/css/json` 等围栏留给 Markdown。
- 围栏外文本全部成为 prose，禁止丢弃。
- 完整 HTML 源码想展示与前端想执行在结构上不可判定；默认保持现状，后续需独立用户开关。

官方命名依据：`DiaoYan/ref/slash-runner-types/iframe/util.d.ts:32-46`，`getIframeName()` 约定 `TH-message--楼层号--该楼层第几个界面`。

## 5. G4

### C1：`eadeb00`

`webview_chat_stage.dart:2861-2999` 增加多 html fence 的 `segs`：每段带 `type` 和已渲染 `html`；旧 `prose/html` 字段保留，单前端旧路径不变。T9 的真实输入被识别为两份完整 frontend，长度分别 182928 与 207124；围栏外两段长度 4、1。

### C2：`1570ba8`

`chat_stage.html:1423` 起增加多 seg 消费：每个 frontend 独立 iframe、独立 `data-html`/高度/虚拟化生命周期；prose 独立插入普通气泡。frame id 使用 `TH-message--<floor>--<index>`，并写入 `__kiraMsgFloorMap`。新增 `getIframeName()`，现有 `getCurrentMessageId()` 保持返回当前 iframe id。原无 segs 分支完全保留。

### C2 验证原始输出

```text
── block 1/2  (build/check_block_1.js, 1259 chars)
   OK
── block 2/2  (build/check_block_2.js, 84183 chars)
   OK
SYNTAX OK (2 blocks)
patch 总长: 18866
script 块数: 1
block[0] len=18740 : PARSE OK
INJECT PATCH: ALL BLOCKS OK
0
```

其中 `0` 为 `dart analyze` 的 error 计数；全量 analyze 输出为：

```text
1210 issues found.
```

C1/C2 commit 均单独可 revert。C2 未改 `createEngineRoom`；injectBridge 拼接产物全文落盘于 `DiaoYan/P3/诊断/out/inject_patch_extracted.html`，由提取器逐块检查通过。

虚拟化与高度无需产品改动：现有 `IntersectionObserver`、`data-html`、`data-last-height`、`__cardHeight` 均按 iframe id 工作；多 frame 自然按流布局累加。已保留 `[WV-7]` 异常高度日志。

## 6. 真机复测说明

1. 确认资产：

```powershell
Get-ChildItem build -Recurse -Filter chat_stage.html
```

逐个检查 build 资产长度与 `assets\chat\chat_stage.html` 一致，并 grep `__thVars`、`快照首次到达`、`getIframeName`。
2. 完全重启 App，禁止热重载。
3. 保存日志：

```powershell
flutter run 2>&1 | Tee-Object -FilePath DiaoYan\P3\run.log
```

4. grep：`Unexpected token '<'` 应消失；`[引擎房] 收到事件` 应出现；`[Mvu] 主文档已接到` 或 10 秒超时应出现；`[Mvu] card`、`快照首次到达`、`getAllVariables 快照未就绪`、`[变量同步] 已广播 card` 应按时序出现；G4 还要看同一消息是否有两个 `TH-message--<floor>--0/1` iframe。
5. 眼睛确认：状态栏显示数字；双前端消息同时出现两个 UI。

## 7. 我没能验证的部分

- 未连接真实 Flutter/WebView 真机；G1 是 Edge headless + 真实 regex_6 文档 + 真实 injectBridge patch 的离线端到端验证。
- G4 的双 iframe `setMessages` 集成 harness、真实滚动触发虚拟化清空/恢复、真实两个 frame 的 `[WV-7]` 高度上报尚未在本轮完成自动浏览器断言；代码路径已按 iframe 粒度实现并通过语法/静态检查。
- build 目录资产重打包尚未执行。
- G1 使用的是 run.log/initvar 的真实字段结构和可辨识测试值，不是当前设备最新一轮变化后的业务状态。

## 8. 记账

以下未动：`th_setVars` merge/replace；世界书 API 命名；normalizeCodeQuotes 块外属性；重复 window.onerror；depth 语义；RegexScript 硬 cast；MVU bundle 版本；klona/z；waitGlobalInitialized 定时器数量；全局世界书 i18n。

发现并保留：官方声明的 `getCurrentMessageId()` 返回数字楼层 id，而当前兼容层历史上返回 iframe 字符串 id；本轮通过 `TH-message--floor--index` 和 floor map 维持现有卡兼容，但这项 API 语义差异仍应独立审计。
