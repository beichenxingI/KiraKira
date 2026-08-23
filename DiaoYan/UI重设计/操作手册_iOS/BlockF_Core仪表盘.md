# Block F · Core 整页重做(geek_dashboard_screen)

> **v2 修订:推翻 v1"磨光"方案,整页重做**。
> **v2.1 补洞:CFG Scale / Logit 偏置确认为真开关(侦察表 §二实锤),
> 由"并入未果"升级为 F-T3 可展开功能卡 → 功能组 5 张 → 7 张;
> F-T1 结构图、F-T3 规格、F-T7 清理、完工验收已同步。**
> v1 思路(保留 8 个大格子图标 + 6 张孤立开关卡,只做视觉打磨)被人类否决:
> "八个大格子 + 孤零零开关滑块,简陋、死白多、改个小东西要进三四级页"。
> 本 v2 依侦察报告 `DiaoYan\UI重设计\侦察_结构补充\侦察1_Core八功能数据表.md`
> 的数据现成度定形态,目标对齐 **iOS 健康 App(摘要 + 可展开数据卡)**
> 与 **iOS 设置 App(inset-grouped 行内直改)**。
>
> 依赖:Block A/B。守宪法 v2(零阴影、三级灰差、单强调色、Cupertino 控件事),
> 组件必须复用 Block A 的 KiraSection / KiraGroupedTile / KiraPressable /
> CupertinoSwitch,**不自创平行组件**。

---

## 0. 侦察定形结论(本手册的形态依据)

| 形态分层 | 功能 | 数据来源(现成 provider) |
|---|---|---|
| **可展开功能卡**(总开关 + 高频参数就地调) | 正则、向量 RAG、TTS、STT、翻译、**CFG Scale、Logit 偏置** | `regexSettingsProvider.enabled` / `vectorStorageSettingsProvider.enabled` / `ttsSettingsProvider.enabled` / `sttSettingsProvider.enabled` / `translationSettingsProvider.enabled` / **`cfgScaleSettingsProvider`(`setEnabled`,isCFGActiveProvider 读)** / **`logitBiasSettingsProvider.enabled`(setEnabled)** —— 全部 StateNotifierProvider + SharedPreferences,**不用新造状态** |
| **只读摘要行**(压缩信息 + 点进详情) | API 高级参数、AI 预设、提示词管理 | `llmConfigProvider` / `activeAIPresetProvider` / `enabledPromptSectionsProvider` —— 但**无全局 enable 布尔** |
| Hero 区保留增强 | 生成预算环、功能在线计数 | `llmConfigProvider.maxTokens/contextLength`、现有 6 布尔统计 |

> 铁律:**数据需提取/无的功能禁止做假开关**(点了没反应的开关比现状还糟)。
> 三类功能(API 高级/AI 预设/提示词管理)只做"状态摘要(只读)+ chevron 进详情"。

---

## F-T1 页骨架:大标题 + 三区分屏 🔧 🟡(结构重做)

**目标文件**:`lib/presentation/screens/settings/geek_dashboard_screen.dart`

锚点:`return Scaffold(appBar: AppBar(title: const Text('极客Core'), ...))` + `body: ListView(...)`

### 新页面结构(自上而下)

```
SliverAppBar.large(title: Text('极客Core'))          ← 品牌词保留
├─ ① Hero 摘要条(一行两格,非大卡):生成预算环 + 功能在线     [F-T2]
├─ ② KiraSection(title: '功能')   —— 7 张可展开功能卡        [F-T3]
│    CFG Scale / Logit 偏置 / 正则 / 向量 RAG / TTS / STT / 翻译
├─ ③ KiraSection(title: '配置')   —— 3 行只读摘要 + 跳转     [F-T4]
│    API 高级参数 / AI 预设 / 提示词管理
├─ ④ KiraSection(title: '快捷调整')—— 采样参数滑块组         [F-T5]
└─ ⑤ KiraSection(title: '更多')   —— 剩余入口紧凑列表行     [F-T6]
     图像生成 / 精灵图 / 变量 / 日志统计 / MVU
```

### 改动
1. `body` ListView → CustomScrollView;各 section 包 `SliverToBoxAdapter`,
   底 `SliverPadding(bottom: 96)` 避底栏。
2. `_SectionEntrance` 错峰淡入保留，curve 走 A-T1 的 `curveSpring`(easeOutBack)。
3. **删掉 13 格 4 列 `_EntryTile` 图标网格**(锚点:`class _EntryTile`),
   入口按上表分流进 ②③⑤;网格布局整体退役。
4. **删掉 6 张 `_StatusCard` 大而空的开关卡**(锚点:`class _StatusCard`),
   其布尔按归属并入 ②③:**CFG Scale / Logit 偏置 → 升级为 ② 的可展开功能卡**
   (F-T3,与正则/RAG/TTS/STT/翻译并列);
   向量 RAG → ② 功能卡;
   流式输出/自动摘要 → 挪入 API 高级参数摘要行的展开区(F-T4);
   分词器 `showTokenCount`(非总开关)→ 挪入 F-T6"更多"组一行带 CupertinoSwitch。
5. ⚠️ Block B 二层化后路由常量按新表 push(契约 §二.6,不裸字符串)。

**结构重做**:是(commit `refactor(core): 推翻网格,改 Hero+功能卡结构`)。
**风险** 🟡(页面重排,但所有状态 provider 原样,业务零变动)。
**验证**:`dart analyze`;每个入口 push 到位;7 个功能卡开关真实生效
(写 SharedPreferences 对应键,见侦察表"持久化"列),另有流式/自动摘要/
分词器计数 3 个散开关各翻一次。

---

## F-T2 Hero 摘要条:环保留,卡瘦身 🟢

**锚点**:`class _HeroMetricCard` / `class _RingGauge` / `class _RingPainter`

### 改动
1. **大卡 → 摘要条**:两张 Hero 卡从"各占半行的大卡"压成**一行内的
   inset-grouped 卡**(一张 `radiusGroupedCard(10)` 卡,内部左右两区,
   中间 0.5px 竖分隔线)——参照 iOS 健康 App 摘要行、电池 App 用量条。
2. `_RingGauge`:环宽 6→8、尺寸 56→64,轨道色 dark `darkCard` /
   light `lightFillTertiary`;动画 curve 用 `curveSpring`。
   双环扩展:**不做**(侦察确认"预估消耗比"无现成数据,禁止编数据)。
3. Hero 数字:28→34(`fontSizeDisplayLarge`),语义色保留
   (预算环正常 accent、>0.9 statusWarning、超额 statusError;
   功能在线 N/6,N=0 时 statusError)。
4. 硬编码色迁移:`_HeroMetricCard.statusWarning(0xFFF5B04C)/statusError(0xFFE5534B)`
   → `DesignTokens.statusWarning/statusError`(A-T1 已产)。
5. v1 的"柔光 RadialGradient"方案**取消**——新结构下 Hero 不再是大卡,
   柔光会显得脏;保持干净 inset-grouped 质感。
6. 点按:预算环区 → push 采样参数页;功能区 → 滚动锚到"功能"组
   (或直接无动作,"可读数字不求可点",**禁止假 affordance**)。

**验证**:`dart analyze`;maxTokens 拖 0/半/满/超额看四态色;动画有回弹。
**人工目测**:一行摘要条与上方 Large Title 的密度关系,不空、不挤。

---

## F-T3 功能组:7 张可展开功能卡 🔧 🟡(本 Block 核心)

**锚点**:替换原 `_EntryTile` 网格 + 4 张 `_StatusCard`(CFG Scale / Logit 偏置
/ 向量 RAG 开关合并进来;CFG 与 Logit 依侦察表 §二实锤为真开关,升级入组)。

### 形态规格(iOS 健康 App"数据卡"思路,复用 Block A 件)

每张功能卡 = `KiraPressable` 整卡,`radiusGroupedCard(10)`,深色零阴影:

```
┌──────────────────────────────────────────┐
│ [彩块icon] TTS 合成           [CupertinoSwitch] │ ← 头行:44 高,接地即开关
│ 语速 ●━━━━━━━○━━━ 1.0×                        │ ← 展开态:高频参数就地调
│ 声音:zh-CN-Xiaoxiao   详情 ›                  │ ← 摘要行 + 点"详情"进二级页
└──────────────────────────────────────────┘
```

1. **头行(恒显)**:彩块 icon(`primary.withValues(alpha:0.12)` 26×26,
   圆角 10)+ 功能名(`fontSizeHeadline` 17 w600)+ 右侧真实
   `CupertinoSwitch`(activeTrackColor = primary,直接绑
   F-T0 表里的 enabled provider + setEnabled,**写真实**)。
2. **收起摘要(开关 ON 时恒显一行,OFF 时整卡收成头行 + "已停用"灰字)**:
   - CFG Scale:`Scale {value}`(cfgScaleSettingsProvider 的 scale 字段,
     取值范围实施时读模型类定,通常 1.0–2.0【待核实,以代码为准】);
   - Logit 偏置:`已配置 N 条偏置`(logitBiasSettingsProvider 内
     偏置表计数;字段名待核实,实施时读模型类确认,无计数字段则显示
     "已启用"即可,**禁止编数据**);
   - 正则:`启用 N / 共 M 个脚本`(`globalRegexScriptsProvider` 计数);
   - 向量 RAG:`TopK 5 · 阈值 0.75`;
   - TTS:`语速 1.0× · zh-CN-Xiaoxiao`;
   - STT:`语言 zh-CN · 自动发送`;
   - 翻译:`中文 ⇄ 英文 · 入站自动`。
   摘要字号 13(`fontSizeSm`)`darkTextSecondary`。
3. **展开的"就地调节"区**(点卡体非开关区展开,chevron_down/up 指示,
   展开动画 250ms):
   - **CFG Scale**:scale 值滑块(范围读模型类实定【待核实】,
     setter 用 cfgScaleSettingsProvider 对应 update 方法);
   - **Logit 偏置**:只读摘要行(前几条 token→bias 摘要或计数) +
     "管理偏置 ›"进详情(`/logit-bias-settings`),**不做就地编辑器**
     (偏置表结构复杂,就地编辑性价比差);
   - 向量 RAG:TopK 滑块(clamp 1–20,`setTopK`);阈值只读 → 详情;
   - TTS:`rate` 语速滑块(0.5–2.0,`setRate`,slider 天然适配);
   - STT/翻译/正则:展示二级布尔行(autoSend / autoTranslateIncoming /
     逐脚本启停跳详情),**每个布尔必须是真 provider setter,见一项挂一项**。
   - 滑块样式:轨道高 4,值标签 15 w600 primary 右对齐(沿 v1 F-T5 规格)。
4. **进详情**:卡片底部一行 `KiraGroupedTile(title: '高级设置')` 或头行
   右侧"详情 ›"文字按,push 到对应现有路由
   (`/cfg-scale-settings` `/logit-bias-settings` `/regex-settings`
   `/vector-storage-settings` `/tts-settings`
   `/stt-settings` `/translation-settings`;若 Block B 已二层化,用新常量)。
5. 展开状态不写盘,页面级 `setState` 即可。

**结构重做**:是(commit `feat(core): 七张可展开功能卡,就地开关+参数`)。
**风险** 🟡(7 provider 接线多,但全是现成 setter;逐个对照侦察表;
CFG/Logit 的参数字段名标了【待核实】,实施第一步先读对应模型类再动手)。
**验证**:`dart analyze`;7 个开关各翻一次,杀掉 App 重开状态在;
CFG 拖 scale 滑块、TTS 拖语速滑块后重进仍在;OFF 态卡片收起视觉明确
(灰 + 无参数区)。
**人工目测**:深色下一组卡"一眼看清 7 个功能全部状态",死白消灭。

---

## F-T4 配置组:3 行只读摘要 + 详情 🔧 🟢

**锚点**:替换原"API 高级 / AI 预设 / 提示词管理"3 格 `_EntryTile`。

### 改动
一律 `KiraGroupedTile`(必须在 KiraSection 内,<契约束),无开关:

| 行 | 标题 | 副标题(只读摘要,13pt secondary) | push |
|---|---|---|---|
| API 高级参数 | 采样与输出 | `{model} · maxTokens {n}` | `/settings/ai/advanced`(B-T3 新路径) |
| AI 预设 | 预设 | `当前:{预设名} · 共 {n} 套` | `/settings/ai/presets` |
| 提示词管理 | 提示词 | `启用 {n} 段 · 预设:{名}` | `/settings/ai/prompt-manager` |

1. `llmConfigProvider.model` 若为空显示"未选择模型"。
2. **流式输出 / 自动摘要**两个布尔(原孤卡)并到"API 高级参数"行内:
   该 tile 换成可展开行(同 F-T3 头行机制但无总开关),
   展开区放两个真开关 `updateStreamEnabled` / `updateAutoSummarizeEnabled`;
   自动摘要保留 note"长对话会额外消耗 API 额度"(13pt tertiary)。
3. 禁止在此组画任何假开关。

**风险** 🟢。**验证**:三行摘要数字与各自二级页一致;两个开关写入生效。

---

## F-T5 快捷调整组:采样滑块自留地 🟢

**锚点**:`_quickAdjustSection`(`KiraSection(title: '采样参数', …)`)、
`_DashboardSlider`、`_CollapsibleSection`、`_IntInputRow`

### 改动(沿 v1 规格,文字微调)
1. 用 `KiraSection.plain(title: '快捷调整', child: …)`(A-T4b)包整块,
   不自动插分隔线。
2. 组名 v1 叫"采样参数",v2 改"快捷调整"以与 F-T4 的"API 高级参数"行
   区分语义;l10n 走现有 key,无 key 就硬编码中文(文件本已硬编码'极客Core')。
3. `_DashboardSlider`:标签 17、值 15 w600 primary、轨道高 4。
4. `_CollapsibleSection` 箭头:`CupertinoIcons.chevron_down/up`,
   色 `darkTextSecondary`(非 primary)。
5. `_IntInputRow` 弹窗 → 单字段底部 Sheet(D-T2 规则 2)。
6. "更多采样参数"→ 行尾 chevron 的 `KiraGroupedTile`,push 新路径(同 F-T4 行1)。

**验证**:滑块可拖、折叠开合、Sheet 滑起。

---

## F-T6 更多组:剩余入口紧凑列表 🟢

**锚点**:原 `_EntryTile` 中剩余 5 入口 + 分词器开关并入。

```
KiraSection(title: '更多')
  ├ 图像生成        → /image-gen-settings(或 B 新路径)
  ├ 精灵图          → /sprite-settings
  ├ 变量管理        → /variables-settings
  ├ 日志统计        → /statistics
  ├ MVU 变量框架    → /mvu-settings
  └ 分词器计数      [CupertinoSwitch]  ← showTokenCount 真开关
```

全部 `KiraGroupedTile`,图标块可选(iconBg 彩块 10 圆角)。
分词器行 trailing 放开关替代 chevron,绑
`tokenizerSettingsProvider.notifier.setShowTokenCount(v)`。

**风险** 🟢。**验证**:5 行跳对;分词器开关持久化。

---

## F-T7 退场清理 🟢

- 删除(扫描确认无引用后):`_StatusCard`、`_EntryTile` 网格、
  4 列网格 delegate、Hero 卡旧 RadialGradient(v1 方案未实施过则无)。
- **CFG Scale / Logit 偏置迁移专项检查**:旧 `_StatusCard` 里这两张卡的
  开关接线(`isCFGActiveProvider` watch / `setEnabled` 调用、
  `logitBiasSettingsProvider.enabled` watch / set 调用)与 onTap 路由
  须整体迁移进 F-T3 新卡,删除后 `rg "cfg|logit" -i` 本文件核对:
  只剩新卡引用,旧卡零残留。
- `rg "Color\(0x"` 本文件清零(状态色全走 token)。
- 本文件与聊天域无关,确认无新增 import 自禁区。

**验证**:`dart analyze` 零 error;`rg "_StatusCard|_EntryTile"` 本文件 0 命中。

---

## 不做的事(守护仪表盘性格,v2 更新)

- ❌ 不做 13 格图标网格(人类否决,本 Block 第一刀);
- ❌ 不做假开关/假滑块(数据无则只读摘要 + chevron);
- ❌ 不把 Hero 环换成 ProgressBar(环是仪表盘签名);
- ❌ 不做双环(无现成数据);
- ❌ 不删 `_SectionEntrance` 错峰入场;
- ❌ 不在本页用 KiraGradientCard;
- ❌ "角色市场"与本页无关,别进(那是 C-T8)。

---

## Block F 完工验收

1. `dart analyze` 绿;`rg "Color\(0x"` 本文件清零。
2. 七个功能卡(CFG Scale / Logit 偏置 / 正则 / 向量 RAG / TTS / STT / 翻译):
   开关真实持久化(SharedPreferences 键见侦察表);
   OFF 态收起、ON 态出摘要;CFG 拖 scale、向量 RAG 拖 TopK、TTS 拖语速就地可调;
   Logit 展开区只读摘要 + "管理偏置 ›"进详情。
2b. 旧 CFG/Logit `_StatusCard` 代码已随 F-T7 清零,无僵尸接线残留。
3. 配置组 3 行摘要与二级页数据一致;流式/自动摘要开关真生效。
4. 预算环四态色(0/半/满/超额)+ 回弹动画。
5. 一屏信息密度目检:不进任何二级页即可看到 8 功能全部状态摘要。
6. 深浅色各整页截图 ×1;功能卡展开态截图 ×1;Sheet 滑起 ×1。

**必须真机截图页**:Core 深色整页(大标题展开/收缩)、功能卡组特写
(TTS 展开)、配置组特写。
