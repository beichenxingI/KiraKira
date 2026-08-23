# Block G · ai_config 补扫后的 iOS 化

> 依赖:Block A/B/C-T3(外壳已 iOS 化)。本 Block 处理页面**内部**。
> ai_config_screen.dart 1996 行,含约 600 行死代码——**先清死代码再美化**。

---

## G-T1 ai_config_screen 内部重组 🔧 🔴

**目标文件**:`lib/presentation/screens/ai_config/ai_config_screen.dart`

### Step 1:删死代码(单独 commit `chore(ai_config): 删除 QuickSetup 重构遗留死代码`)
以下类/函数经子代理扫描确认**定义但未被 build 引用**,
动手前再 `rg "_LLMProviderTile|_ApiKeyTile|_ApiUrlTile|_ModelTile|_ModelSelectionSheet|_buildSectionHeader"`
二次确认零引用后删除:
- `_buildSectionHeader`(L171 附近,从未调用)
- `_LLMProviderTile`(L279)及其 `_showProviderPicker`
- `_ApiKeyTile`(L434)及其 `_showApiKeyDialog`
- `_ApiUrlTile`(L516)及其 `_showApiUrlDialog`
- `_ModelTile`(L574)+ `_showModelListSheet/_showModelInputDialog/_showManualInputDialog`
- `_ModelSelectionSheet`(L1052)

若二次确认发现被引用→跳过删,该代码段列入"迁移"工单,不强行删。

### Step 2:QuickSetupCard iOS 化(单独 commit `refactor(ai_config): QuickSetupCard 化`)
锚点:`class QuickSetupCard extends ConsumerStatefulWidget`(L1451)

1. 外壳:锚点 `Container(... BoxDecoration(... borderRadius.circular(20)))`
   (L1509-1518 一带)→ `KiraSection.plain(title: '快速接入', …)` 包进去,
   外壳 radius 10、无边框或 0.5 separator、深色 `darkSurface`。
2. 内部控件统一:
   - 方案切换 `Dropdown`(L1561)/ 接口类型 `_buildProviderSelector`(L1777):
     换 `KiraGroupedTile` + trailing 显示当前值,弹 `CupertinoActionSheet`
     选型(iOS 风格 modal)或 `showModalBottomSheet` 列表;
     不再用 Material DropdownMenu(太 Material)。
   - API 地址/密钥 TextField(L1621/1635)→ `CupertinoTextField`,
     填 `darkCard`/light `lightFillTertiary`、radius 10;
   - "拉取模型" `FilledButton`(L1707)→ `KiraButton(filled)`;
     "刷新列表" `OutlinedButton`(L1734)→ `KiraButton(outlined)`;
     "确认并启用" `FilledButton.tonalIcon`(L1753)→ `KiraButton(filled,icon)`;
   - 保存/重命名/删除弹窗(L1863/1921/1970):按 D-T2 规则,
     "保存为新方案/重命名"= 单字段 Sheet;"删除"= CupertinoAlertDialog。
3. 文案:硬编码中文保留但加 `// TODO(i18n)`;'e.g., deepseek-3.2'
   英文 hint 保留(示例 URL 惯例,不强翻)。

### Step 3:_ConnectionStatusCard iOS 化
锚点:`class _ConnectionStatusCard`(L1223)

1. 状态点:L1235-1253 硬编码 `0xFF34C759/0xFFFF9F0A/0xFFFF453A/0xFF8E8E93`
   → `statusSuccess/statusWarning/statusError/textTertiary`。
2. `_MetricCell`(L1416)指标三格:数值 17 w600,单位/标签 12 tertiary;
   格子间 0.5 separator 竖分隔(iOS 电池 App 用法)。
3. 两个手绘 GestureDetector 按钮(L1343-1408,"测试连接"/"深度检测")
   → `KiraButton`(一个 filled、一个 outlined),radius 12。
4. `BorderRadius.circular(14)`(L1357/1387)→ token。

### Step 4:三段 KiraSection 行精修
锚点:L112-163(预设模板/LLM 连接/生成设置三组)

1. 三个段已在 C-T3 时随 Block A 新 KiraSection 自动 inset-grouped;
   本 Task 做的是把每段内的 tile 换成 `KiraGroupedTile`,
   删原 `_InstructTemplateTile/_ConnectionTestTile/_ContextLengthTile/...`
   里手绘的 `ListTile` 样式(vertical padding、icon 色),让组内行间距/分隔线
   由 KiraSection 统一管。
2. `_TemperatureTile`(L984)内嵌 `Slider` → 样式对齐 F-T5
   (track 4 / value 15w600)。
3. `_StreamingTile`(L1032)`SwitchListTile` → `KiraSwitchTile`。

**风险** 🔴(大文件 + 死代码先删,主功能回填需要眼睛)。
**验证**:`dart analyze`;**完整走一遍接入流程**(输入 URL/Key→拉模型→
选模型→测连接→确认启用→横幅出现),全流程无异常。
**人工目测**:页面气质与设置族一致(分组卡、行间分隔、开关紫、无 Material 硬按钮)。

---

## G-T2 model_detection_screen 深色定制页收编 🟡

**目标文件**:`lib/presentation/screens/ai_config/model_detection_screen.dart`

特征:它已经是"iOS 深色特化页"(backgroundColor `#000000`+ 透明 AppBar)。
**策略**:保留"沉浸深色"性格,但色值收编到 token 体系:

1. `Scaffold(backgroundColor: Color(0xFF000000))`(L37)→ `darkBackground`
   (#0B0B12,B 方案不禁纯黑,但统一走 token)。
2. AppBar 标题两行结构(L41-61)保留,小标题 '模型深度检测'
   `fontSizeSm` 已 token 化,确认大字 20 → `fontSizeXl` token。
3. 三档渐变 `_gradientFor`(L21-30,`0xFF0A84FF/.../AF52DE`):
   - 这组色是"检测档位品牌色",不是主题色。
   - 迁顶部 const `_kLevelGradients`,注释"档位识别色,豁免 token";
   - 但与 B 板冲突检查:`0xFF0A84FF`(iOS systemBlue 深)与
     `0xFF5856D6` 与 primary 星海紫视觉接近——可改
     一档=accent 青、二档=primary 紫、三档=`Color(0xFFAF52DE)` 保留,
     既保留递进又贴合品牌。**实施时渐变两端成对改,别只改一头。**
4. `borderRadius.circular(20)` 关卡卡(L452)→ `radiusCard(12)`;
   `borderRadius.circular(24)` 底部 Sheet(L217 附近)→ `radiusBottomSheet(14)`。
5. `Colors.white.withOpacity(0.x)` 全量换 `withValues(alpha:)`(lint 顺手)。
6. `_RevealWrapper`(L639 scale 0.96→1)保留,动效已 iOS 化。
7. `ElevatedButton('0xFF007AFF')`(L530 附近)→ `KiraButton(filled)`
   (颜色自动 primary)。
8. `_buildInfoSection` 的 `ExpansionTile`(L107)保留,样式随主题。

**验证**:`dart analyze`;跑一次快档检测看到结果页。
**人工目测**:深色沉浸感保留,但不再是"另一 App"。

---

## G-T3 fingerprint_result_widget 收编 🟢

**目标文件**:`lib/presentation/screens/ai_config/fingerprint_result_widget.dart`

1. 外壳 `Card(color: 0xFF1E1E2E)`(L23)→ `KiraCard`(无边框);
   圆角 `radiusLg` → `radiusCard`。
2. `_buildScoreBars`(L126)三元 `Colors.green/orange/red` →
   `statusSuccess/statusWarning/statusError`。
3. 缩水判定块 `0xFF3a2a1a/0xFFf59e0b/0xFFfbbf24`(L77-91)→
   `statusWarning.withValues(alpha:0.14)` 底 + `statusWarning` 文;
   掺假检测红/绿块(L96-118)同理用 status token + alpha 底。
4. `Colors.white70/54/38` → `darkTextSecondary/Tertiary/Disabled`。
5. '模型能力画像' 等中文 title 保留 + TODO(i18n)。

**验证**:`dart analyze`;看真机一份真实指纹结果渲染。

---

## G-T4 llm_config_list_screen + llm_test_screen 处置 🟢

两个都是**调试/工程页**(英文标题、原生风格)。

**策略:不动外观,只挂新风**——
1. `llm_config_list_screen.dart`:
   - AppBar title `'AI Config Manager'` → 'LLM 配置管理' 或保留,
     但改 SliverAppBar.large;
   - `_ConfigEditorDialog`(L73,4 字段表单)→ push 新"配置编辑页"
     (参考 D-T2 规则 3);
   - `FloatingActionButton` 新建 → 右上 `+`;
   - 条目 Card+ListTile → KiraGroupedTile,inset-grouped 渲染;
   - `_providers = ['custom','deepseek','openai','claude']` 硬编码列表保留。
2. `llm_test_screen.dart`:
   - 标题 `'LLM Test (Temp)'` 已是"临时页"自我声明——**建议删除路由和页**;
   - 决策:**保留**,改 push 入口只从 ai_config 高级菜单进;外观跟随主题即可,
     单独 Sliver 化,不花大力气。
   - 若人类在 Block G 开工前拍板"删",则执行删路由 + 删文件 + 清引用。

**验证**:`dart analyze`;进 llm-config-list 做一次激活/编辑/删除。

---

## Block G 完工验收

1. `dart analyze` 绿;`rg "_LLMProviderTile|_ApiKeyTile|_ApiUrlTile|_ModelTile"`
   应为零(真删了)。
2. ai_config 从头到尾一次接入流程走通。
3. model_detection 跑一次出指纹;fingerprint widget 色彩新状态色。
4. llm-config-list 编辑走子页不走弹窗。

**必须真机截图页**:AI 配置主页(有激活预设横幅)、QuickSetupCard 展开、
连接状态卡(在线/离线双态)、模型检测 idle 态、指纹结果页、LLM 配置管理页。
