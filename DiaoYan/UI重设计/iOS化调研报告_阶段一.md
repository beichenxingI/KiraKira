# KiraKira iOS 化设计方向报告 · 阶段一(纯调研)

> 调研基准：第一轮保守重构后的备份副本(2026-08-24)。
> 本报告不改任何代码，仅供人类决策"对不对味"。
> 所有 iOS 色值均经网络核实,出处见各处标注。

---

## 第一部分:iOS 设计语言核心提取(决策层)

### 1.1 明暗双色板(极致调色 KPI)

#### iOS 标准色板 · 深色模式

出处:Apple HIG > Foundations > Color(<https://developer.apple.com/design/human-interface-guidelines/color>);
具体 RGB 值经 SarunW《Dark color cheat sheet》核实(<https://sarunw.com/posts/dark-color-cheat-sheet/>,逐项列出 UIColor 值,与 Apple 官方 UIElement Colors 文档 <https://developer.apple.com/documentation/uikit/uicolor/ui_element_colors> 对应)。

| 语义 | 色值(HEX+Alpha) | 用途 |
|---|---|---|
| systemBackground | `#000000` | 最底层页面背景(分组列表背景深色=纯黑) |
| secondarySystemBackground / secondarySystemGroupedBackground | `#1C1C1E` | 卡片/分隔块/导航栏背景 |
| tertiarySystemBackground | `#2C2C2E` | 三级层级(输入框填充、控件容器) |
| label | `#FFFFFF` | 主文字(纯白!) |
| secondaryLabel | `#EBEBF5` @ 60% | 次要文字(**半透明白,非灰**) |
| tertiaryLabel | `#EBEBF5` @ 30% | 说明文字/占位符 |
| separator | `#545458` @ 60% | 半透明分隔线 |
| opaqueSeparator | `#38383A` | 不透明分隔线 |
| systemBlue(深色) | `#0A84FF` | 交互色(比浅色 #007AFF 更亮) |
| systemGray6(深色) | `#1C1C1E` | 最浅灰容器 |

#### iOS 标准色板 · 浅色模式

| 语义 | 色值 | 用途 |
|---|---|---|
| systemBackground | `#FFFFFF` | 页面再深一级=纯白 |
| systemGroupedBackground | `#F2F2F7` | 设置页"灰底白卡"的灰底 |
| secondarySystemGroupedBackground | `#FFFFFF` | 分组卡片=纯白(**层级靠灰底反衬,不靠阴影**) |
| label | `#000000` | 主文字纯黑 |
| secondaryLabel | `#3C3C43` @ 60% | 次要文字 |
| tertiaryLabel | `#3C3C43` @ 30% | 说明文字 |
| separator | `#3C3C43` @ 29% | 分隔线 |
| opaqueSeparator | `#C6C6C8` | 不透明分隔线 |

**关键洞察:iOS 的"层次感"几乎全部来自 2-3 级灰底差 + 细分隔线,几乎不用投影。**

#### 当前 KiraKira 色板对比(design_tokens.dart L168-L177 实读)

| 当前 Token | 当前值 | iOS 基准值 | 问题 |
|---|---|---|---|
| darkBackground | `#0D1128` | `#000000` | ❌ 偏蓝紫的深灰,iOS 分组列表背景是纯黑;当前像"蓝调 Midnight 风",不是 iOS |
| darkSurface | `#161B3A` | `#1C1C1E` | ❌ 偏蓝;iOS 是中性灰带极微蓝 |
| darkCard | `#1F264A` | `#1C1C1E` | ❌ 明显蓝紫,三层之间色相相同靠明度区分 — 思路对,但色相太"星际"非 iOS |
| darkDivider | `#2A3057` | `#545458`@60% | ❌ iOS 分隔线用半透明,iOS 几乎不画 1px 实线 |
| lightBackground | `#EEEEF8` | `#F2F2F7` | 🟡 接近但偏紫 |
| lightCard | `#FFFFFF` | `#FFFFFF` | ✅ 对齐 |
| textPrimary(深) | `#E8EAF5` | `#FFFFFF` | 🟡 "护眼灰白"是风格选择,iOS 是白+透明度打层次 |
| textSecondary(深) | `#9095B8` | `#EBEBF5`@60% | ❌ **实色灰字 vs iOS 半透明字** — 这是最大的技术差异:iOS 文字直接用白色压透明度,在任意背景上都自带"呼吸" |

**建议替换方案(保守派,保留星海基因):**

| 方案 | 做法 | 理由 |
|---|---|---|
| A. 完全照搬 iOS | background `#000000`,card `#1C1C1E`,文字改白色+透明度 | 最"对味",但丢掉星海品牌 |
| B. **色相微调版**(推荐) | background `#0B0B12`→极深近黑带 3% 蓝;card `#17171E`;secondaryLabel 改 `Color(0xFFEBEBF5).withValues(alpha:0.6)` | 保留 KiraKira 星海气质,但语义色调用方式完全 iOS 化(半透明文字,层级纯灰差) |

> 最终色板决策点:人类在 B 方案中挑一个"深蓝紫浓度",10 分钟可调完试看。

---

### 1.2 大标题导航(砍大黑条方案)

#### iOS Large Title 规范

- 标题样式:`largeTitleTextStyle` = SF Pro Display **34pt / Bold**;收缩后小标题 = 17pt Semibold。
- 滚动行为:列表顶部展开时为超大标题(左对齐),向上滚动时标题折叠进导航栏,**导航栏背景由透明渐变为带 blur 的磨砂**(`CupertinoSliverNavigationBar` 默认行为)。
- 安全区:标题栏顶部自然避开 statusBar/notch,由组件内部处理。
- 出处:Apple HIG > Components > Navigation & Search > Navigation Bars(<https://developer.apple.com/design/human-interface-guidelines/navigation-bars>);Flutter 对应组件 `CupertinoSliverNavigationBar` 或 Material `SliverAppBar.large`(Material 3 已内置大号滚动标题)。

#### 当前 app_shell.dart 分析(实读 L14-L39)

- **现状**: `AppShell` 是 "Stack + 底部悬浮胶囊导航" + 顶部分页标题由各 Screen 自行 Scaffold/AppBar。
- **痛点(实读核实)**:
  - character_list_screen.dart L350-359:固定 Material AppBar(标题+图标),不参与滚动;
  - home_screen.dart L76-93:固定 AppBar + 副标题"基于 NativeTavern",**吃掉了顶部 60px 黄金空间**,但信息不以用户为中心;
  - 底部胶囊导航已有"角色/聊天/设置"Tabs → 顶部标题信息冗余。
  - KiraNav 底栏 L104 padding `EdgeInsets.fromLTRB(16,0,16,12)` + L113 高 56 + L142 中间凸起 52 高度的圆球,**底栏视觉已非常强势**,顶栏再用固定卡条显得双重头重。
- **结论**:痛点不在"顶栏没有大标题",在"顶栏**存在本身**就已过度"。

#### 建议方案(由大到小)

| 量级 | 方案 | 说明 |
|---|---|---|
| 🔴 大改 | **全屏无 AppBar + Large Title Sliver** | 删 Scaffold.AppBar,body 改 CustomScrollView + `SliverAppBar.large`(Material) / `CupertinoSliverNavigationBar`(Cupertino),列表首行即大字号"设置"、"聊天"、"角色"。 |
| 🟡 中改 | 保留 AppBar 但改透明 + 浮动水印式大标题 | 不动结构,只是把 AppBar 高度做成 fade-out 滚动联动。 |
| 🟢 小改 | 维持现状仅收窄 AppBar 高度 | 不推荐,治标不治本。 |

**推荐🔴方案**做在主导航 4 个一级页(角色/聊天/API/设置)+ 高频二级页;详情/编辑类页面保持小标题返回栏(iOS 同样如此)。

---

### 1.3 设置页信息架构重组

#### iOS 设置页范式

- **Inset Grouped List**:整页灰底(`systemGroupedBackground`),每组一张白卡(深色= #1C1C1E),组内多行用半透明分隔线,组间留白 35pt 左右。
- **层级上限 3 级**:iOS 设置 App 几乎不出现 4 级嵌套。
- **顶部搜索框**:iOS 14+ 设置首页顶部固定搜索框,输入即跨层级匹配并直达。
- **组头灰小字**:组标题 = 13pt 灰色(`/3C3C43@60%`),全大写英文风格;中文可写小灰字。
- 出处:Apple HIG > Patterns > Managing settings(<https://developer.apple.com/design/human-interface-guidelines/managing-settings>)+ Components > Layout and organization > Lists and tables(<https://developer.apple.com/design/human-interface-guidelines/lists-and-tables>)。

#### 当前 settings 目录分析(子代理扫描 23 个 dart 文件 / 45 个路由)

**结构现状(实读 settings_screen.dart + 扫描 19 个设置子路由):**

- 设置主页只列 4 组:用户/聊天/高级/关于 — **本身没问题,问题在它"够不到"21 个子页**。
- 19 个设置相关路由**全部根级扁平**(`/theme-settings`、`/regex-settings`、`/mvu-settings`…),不是 `/settings/theme` 层级树 — 深链/导航语义乱。
- 21 个子页仅 3 个用了分组组件 KiraSection,**20 个是 ListView 平铺**。
- 全部 24 个 AppBar(含 sprite 的两个)都是固定 Material AppBar,**0 个** Large Title。
- Dialog 弹窗总数约 **90 处**(vector_storage 12、advanced/logit_bias/prompt_manager 各 10…),大量本可进入子页的编辑都用 AlertDialog 硬塞。

#### 建议重组(3 层结构)

```
设置 (Large Title)
├── 🔝 高频置顶组(无组头,最上面 1 张 inset 卡)
│    ├── 深色主题(开关)
│    ├── 语言(已有,被 kiraComponents 引用但未注册到主页 — 需要重挂)
│    └── 用户画像 Persona
│
├── 🎨 外观与房间 (组)
│    ├── 主题 / 背景 / 主页外观 / 精灵(Live2D 类)
│
├── 🤖 模型与生成 (组)
│    ├── AI 预设 / CFG Scale / Logit Bias / Tokenizer / Mvu / Prompt 管理器
│
├── 🧰 工具链 (组)
│    ├── TTS / STT / 翻译 / 图片生成 / 正则 / 变量框架
│
├── 📊 数据与诊断 (组)
│    ├── 统计 / 向量存储 / 日志查看器 / 高级模式
│
└── ℹ️ 关于 (组)
     └── 版本 / 许可 / 开源 / 赞助
```

配套:
- 路由按 `/settings/appearance/theme`、`/settings/ai/cfg-scale` 二层化(🔴 中改,改 `app_router.dart` 一次到位);
- 设置首页顶部加 `CupertinoSearchTextField`,输入时 overlay 过滤全局扁平索引(🟡 可能性高的"看不懂层级"救星);
- AlertDialog 中**凡是表单类**改成 push 子页,AlertDialog 只保留"确认删除"这类破坏性确认(对应 iOS Alert vs Sheet 分工)。

---

### 1.4 字体/圆角/动效矩阵

#### iOS 标准(出处:HIG > Typography <https://developer.apple.com/design/human-interface-guidelines/typography>)

| 语义 | pt | 字重 | 用途 |
|---|---|---|---|
| Large Title | 34 | Bold | 一级页大标题(带收缩) |
| Title 1 | 28 | Regular | 次级页标题 |
| Title 2 | 22 | Regular | 卡片大标题 |
| Title 3 | 20 | Regular | 组标题等 |
| Headline | 17 | Semibold | 列表行标题 |
| Body | 17 | Regular | 正文(iOS "默认正文是 17") |
| Callout | 16 | Regular | 次要正文 |
| Subheadline | 15 | Regular | 副标题 |
| Footnote | 13 | Regular | 注释 |
| Caption 1 | 12 | Regular | 图注 |
| Caption 2 | 11 | Regular | 最弱级 |

#### KiraKira 现状对比(design_tokens.dart L62-L78 实读)

| Token | 当前值 | iOS 对齐 | 评 |
|---|---|---|---|
| fontSizeCaption 10 | caption 11 | ⚠️ 偏小 1pt | |
| fontSizeXs 12 | caption 12 | ✅ | |
| fontSizeSm 13 | footnote 13 | ✅ | |
| fontSizeBodyMedium 14 | subhead 15 | ⚠️ **比 iOS 小 1 档** | |
| fontSizeBodyLarge 16 | callout 16 | ⚠️ ⚠️ **iOS 主正文是 17!** | 升级建议 |
| fontSizeLg 18 | (iOS 无) | ❌ 野值 | |
| fontSizeXl 20 | title3 20 | ✅ | |
| fontSize2xl 24 | (iOS 无 22→24 还算接近) | 🟡 | |
| fontSize3xl 28 | Title 1 28 | ✅ | |
| **缺少 34pt Large Title** | — | ❌ **缺失** | 需要新增 |

**字体升级建议**:新增 `fontSizeDisplayLarge = 34(semibold)`;`fontSizeBodyLarge` 从 16 → **17**;`fontSizeLg 18` 可移除(改走 Title3 20)。

#### 圆角矩阵

| iOS 惯用 | 当前 KiraKira | 评估 |
|---|---|---|
| inset-grouped 分组卡:10-12 | radiusCard=20 | ⚠️ **当前卡片过圆**,iOS 分组卡实际 10-12,视觉差距最直接 |
| 按钮:8-12 | radiusButton=12 | ✅ |
| Sheet:10-14 | radiusBottomSheet=20 | ⚠️ iOS sheet 圆角其实不大 |
| 连续曲率(continuous rect) | 已有 `figma_squircle` 依赖但 tokens 未用 | 🟢 现成,换个 shape 即可 |

**建议**:radiusCard 20 → **12**;新增语义 `radiusGroupedCard = 10`;弹窗 = 14;Sheet 顶角 = 14。现有 `figma_squircle ^0.6.3` 可直接使用 continuous corners。

#### 动效矩阵

| 场景 | iOS | KiraKira(tokens) | 评 |
|---|---|---|---|
| 页面 push/pop | ~350ms,easeInOut(带 spring) | durationMd 300 / curveStandard easeOutCubic | ✅ |
| 底部 sheet | ~350ms | 未统一 token(默认 showModalBottomSheet) | 🟡 |
| 按压反馈 | **icon 轻微缩放 0.97 + 变灰 100-150ms**,无水花 | InkWell 水波纹 | ❌ **最大的"质感差异"** |
| 页面切换 Hero | iOS 几乎不用 Hero,转场靠缩放 | 无 Hero(好事) | ✅ |

**核心建议(必做)**:全 App 把 `InkWell` 换成自定义 "pressable" (Tap→scale 0.97 + opacity 0.6,150ms),这一步替换=瞬间 iOS 感。

---

### 1.5 三~五个大胆创新点(带量级标注)

#### 🟡 创新点 1:**分组卡(inset-grouped)去阴影、加灰底**

- 灵感:iOS 设置 App / iOS 系统消息列表
- 改动:KiraSection 重构 → 一组一张卡片,行内细分隔线;`scaffoldBackgroundColor = systemGroupedBackground`(#F2F2F7 / #000000);卡 `elevation: 0` + 无 boxShadow
- 预计改动:🟡 1-1.5 天(只动 kira_components + 主题卡规格)
- 痛点命中:"设置页一眼望不到头" + "整体平淡"

#### 🔴 创新点 2:**可收缩 Large Title + 吸顶搜索**

- 灵感:iOS 14+ 设置 / 照片 / 文件 App
- 改动:主导航 4 页 + 全 21 个设置子页改 `CustomScrollView + SliverAppBar.large`(Material) 或 CupertinoSliverNavigationBar;搜索栏塞进 `bottom`/flexibleSpace,随滚动过收缩时吸附 nav bar 下沿
- 预计改动:🔴 2-3 天(涉及全部顶级页面结构 + 路由 map)
- 痛点命中:"大黑条压顶"+"顶部冗余占空间"

#### 🟢 创新点 3:**按压反馈全局去 InkWell 化**

- 灵感:iOS 13+ 系统按钮 / Apple Music 列表行(按下→变灰+缩 0.98)
- 改动:新增 `KiraPressable` 组件统一替代 InkWell;全 App 一键替换(IDE 批量)
- 预计改动:🟢 0.5-1 天
- 痛点命中:整体质感"Android 味"消失

#### 🟡 创新点 4:**设置内全局搜索(直达 21 个子页)**

- 灵感:iOS 14 设置顶部搜索框,能搜"亮度"直接跳深层
- 改动:设置主页顶嵌搜索框;建一份"设置项扁平索引表"(widget 名+关键词);搜索时 overlay 筛选,直达子页
- 预计改动:🟡 1-1.5 天
- 痛点命中:"21 个子页找不到东西"

#### 🟢 创新点 5:**导航胶囊毛玻璃化 + 底部 hero 渐变遮罩**

- 灵感:iOS 系统底部 Home Indicator 区域的背景延伸处理;Apple Music 播放栏毛玻璃
- 改动:`_KiraNav` 当前是**实色胶囊** + 白描边;改为 `BackdropFilter(blur)` + `Color(0xFF1C1C1E).withValues(alpha: 0.72)`(iOS "Material Thin" 质感),列表底部加一个渐变遮罩让滚动内容"没入"底栏
- 预计改动:🟢 0.5 天
- 痛点命中:"底部胶囊太实,压住内容视野";预期:有"呼吸感"
- 备注:已有 glass_theme_extension.dart(需要核实是否充分使用)

> 人类按 🟢→🟡→🔴 顺序挑着做即可,**前任一单独成立都可提升一档**。

---

## 第二部分:当前源码痛点清单(阶段二铺路)

> 已过滤聊天域(webview_chat_stage/widgets/chat 一律未读)。下表为子代理扫描 + 主代理抽读汇总,仅列位置与简述,不给修复方案。

### 2.1 核心组件层

| 文件 | 行号/组件 | 痛点 | iOS 应为 |
|---|---|---|---|
| lib/presentation/theme/design_tokens.dart | L27 `radiusCard = radiusXl(20)` | 卡片过圆 | 分组卡半径 10-12 |
| lib/presentation/theme/design_tokens.dart | L64 `fontSizeCaption=10` | 小 1 档 | iOS caption=11 |
| lib/presentation/theme/design_tokens.dart | L67 `fontSizeBodyMedium=14` | iOS subhead=15 | +1 |
| lib/presentation/theme/design_tokens.dart | L68 `fontSizeBodyLarge=16` | iOS body 应为 17 | 升 17 |
| lib/presentation/theme/design_tokens.dart | (全文) | 缺 34pt Large Title 定位 | 新增 displayLarge 34 |
| lib/presentation/theme/design_tokens.dart | L171-174 divider 实色 | 实色分隔线 | 半透明 separator |
| lib/presentation/theme/app_theme.dart | L46-51 appBarTheme centerTitle | iOS 是左对齐大标题收缩 | Large Title |
| lib/presentation/theme/app_theme.dart | L52-59 cardTheme elevation 0 + darkCard 实色 | 三层灰不切 iOS 语义 | primary/secondary/grouped |
| lib/presentation/widgets/common/kira_components.dart | KiraCard L28-42 | 日间双层 BoxShadow | 去阴影,靠 background 分层 |
| lib/presentation/widgets/common/kira_components.dart | KiraCard 内 InkWell L64 | 水波纹不是 iOS | 按压 scale + opacity |
| lib/presentation/widgets/common/kira_components.dart | KiraSection L98-137 | 每子项一张卡、组头 bold+primary | 一组一张卡,组头灰色小字 |
| lib/presentation/widgets/common/kira_components.dart | KiraListTile L209 图标 primary | 全主题色图标 | iOS 彩色块图标(可做) |
| lib/presentation/widgets/common/kira_components.dart | KiraSwitch L246-279 50×30 硬编码 | 硬编码 | CupertinoSwitch |
| lib/presentation/widgets/common/app_shell.dart | L16 `extendBody:false` 注释与意图相反 | 注释骗人 | 修正注释(true 才有内容可 blur) |
| lib/presentation/widgets/common/app_shell.dart | L113 底栏实色+白描边 | Android 胶囊感 | 毛玻璃 + 浅色高边 |
| lib/presentation/widgets/common/app_shell.dart | L76-84 AdvancedFab 加阴影/底栏占位 | 底部已有主导航,FAB 重复 | 收进设置二级 |

### 2.2 页面层(主导航 4 页)

| 文件 | 行号 | 痛点 | iOS 应为 |
|---|---|---|---|
| screens/home/home_screen.dart | L76-93 | 固定小 AppBar + 副标题"基于 NativeTavern" | 大标题"聊天"收缩 |
| screens/home/home_screen.dart | L102-111 | FAB 启动新聊天、避让 80 | 收为 nav bar 右上加号 |
| screens/character/character_list_screen.dart | L350-359 | 固定 AppBar | Large Title + 内嵌搜索 |
| screens/character/character_list_screen.dart | L362 | 搜索栏放 body 顶部、不随滚动 | Sliver 吸顶搜索 |
| screens/character/character_list_screen.dart | L737-763 | 单位卡阴影硬编码 | 去阴影 |
| screens/character/character_list_screen.dart | L431-493 | FAB→底Sheet→选操作三步 | 右上"+"菜单一步 |
| screens/character/character_list_screen.dart | L324-348 | 长按进选择模式、硬编码"已选N个" | 右上"选择"文字按钮 |
| screens/settings/settings_screen.dart | L31 | 固定 AppBar | Large Title"设置" |
| screens/settings/settings_screen.dart | L39-157 | 4 组仅 4 项,21 子页全靠路由平铺 | 分组重组(见 1.3) |
| screens/settings/ai_presets_screen.dart | L68 | AppBar 固定;新建走列表→对话框→编辑页三步 | "+" 直推编辑页 |
| screens/ai-config/*(未细读) | — | 未扫描,阶段二补 | — |

### 2.3 设置子页群(21 个)

| 共性问题 | 数据 |
|---|---|
| 固定小 AppBar | 24/24(100%) |
| 用了分组组件 KiraSection | 仅 3/23 页(settings_screen 4 处、geek_dashboard 2 处、mvu_settings 4 处) |
| `AlertDialog` 弹窗总数 | 约 90 处(vector_storage 12、advanced/logit_bias/prompt_manager 各 10、sprite/variables 各 8…) |
| 硬编码颜色字面量 | 2 处(geek_dashboard L774-775) |
| 标题写法混用 | l10n / 硬编码中文 / 硬编码英文 / 条件拼接 四类并存 |
| 设置子路由层级 | 19 个全部根级扁平,无 `/settings/xxx` 前缀 |

### 2.4 待阶段二细查

- `screens/ai_config/`(主代理未扫描,本轮跳过)
- `glass_theme_extension.dart`(token 已有广义"glass",是否可承接毛玻璃底栏,第二阶段读)
- hero/转场规则暂未发现滥用,深查再定

---

## 第三部分:执行可行性评估(技术兜底)

### 3.1 依赖审视

| 现有 pubspec 依赖 | 结论 |
|---|---|
| flutter_riverpod 2.4.9 / go_router 13 / drift / … | 已够 |
| **figma_squircle ^0.6.3** | ✅ **已在项目里!iOS continuous corner 不需要引入新依赖** |
| cupertino_icons | 仅 icon 字体,iOS 化视觉用 Flutter SDK 自带 `CupertinoIcons`、`CupertinoSliverNavigationBar`、`CupertinoSwitch`、`CupertinoSearchTextField`、`CupertinoActionSheet` **无需新增** |
| UI 库(GetX/FluentUI) | ❌ 按铁律不引 |

**结论:无需新增任何 UI 库依赖,现有 + SDK 自带 Cupertino 足够。**

### 3.2 深浅色切换机制

- `app_theme.dart` 已提供 `darkTheme` / `lightTheme` 两个 ThemeData;
- `theme_providers.dart` 已实现 `activeThemeConfigProvider` + `isDarkModeProvider`,持久化到 shared_preferences(L1-L114 实读);
- **评估:架构完整,只需把色值本身替换即可,不需要重构。**

### 3.3 Large Title 与现有路由/转场兼容性

| 顾虑点 | 评估 |
|---|---|
| go_router + StatefulShellRoute 下的 CustomScrollView | 支持,go_router 对 body 结构无要求 |
| SliverAppBar.large 与 Hero | Flutter Hero 跟 ScrollView 解耦,无冲突;且项目本身 Hero 用得很克制 |
| 收缩时标题"飞入" nav bar 动画 | Material `SliverAppBar.large` 默认自带,iOS 原生感足够;CupertinoSliverNavigationBar 更贴近但要改整体为 CupertinoPageScaffold |
| Navigator 2.0 触底刷新 | RefreshIndicator + CustomScrollView 兼容 |

**结论:技术上无障碍。建议使用 Material 版 `SliverAppBar.large` 保整体跨端一致,而不是强转成 Cupertino 风格(避免同时踩 Material/Cupertino 两套视觉语言)。**

### 3.4 保守工时预估

| 阶段 | 范围 | 保守工时 |
|---|---|---|
| 阶段三 · 核心 4 页 | 主导航 4 页 iOS 化(大标题+有底glass+分组)+Kira 组件库重构+色/字 token 更新 | **6-8h** |
| 阶段三 · 设置子页 21 个 | 每页统一改 SliverAppBar + KiraSection 分组(可批量) | **每个 15-30 分钟 ≈ 6-8h** |
| 阶段三 · 补充 | 设置搜索索引、路由重组、单位测试 | 3-4h |
| **合计** | | **15-20h** |

**结论:阶段三原定 12 小时不够,建议 18-20h(若砍掉搜索/路由重组,12h 可以完成"看起来 iOS"的前两阶段,得到 80% 效果)。**

---

## 附 · 依据索引

- Apple HIG Color: <https://developer.apple.com/design/human-interface-guidelines/color>
- Apple HIG Typography: <https://developer.apple.com/design/human-interface-guidelines/typography>
- Apple HIG Navigation bars: <https://developer.apple.com/design/human-interface-guidelines/navigation-bars>
- Apple HIG Managing settings: <https://developer.apple.com/design/human-interface-guidelines/managing-settings>
- Apple HIG Lists & tables: <https://developer.apple.com/design/human-interface-guidelines/lists-and-tables>
- Apple HIG Dark Mode: <https://developer.apple.com/design/human-interface-guidelines/dark-mode>
- 色值表核实:SarunW《Dark color cheat sheet》<https://sarunw.com/posts/dark-color-cheat-sheet/>(2025 仍可访问,内容完整)
- Apple UIElement Colors 官方表:<https://developer.apple.com/documentation/uikit/uicolor/ui_element_colors>
- flutter_squircle 库(dart pub):<https://pub.dev/packages/figma_squircle>

> 备注:Apple developer 站需 JS,部分链接直接 fetch 无法读到正文。所有具体 RGB 色值均通过 SarunW 的 iOS 13 实机枚举表核实,而非凭印象。
