# 📜 KiraKira iOS化设计宪法 v2(最高法,取代 `_设计宪法.md` v1)

> 本宪法是阶段三全量重写的唯一真相源。允许**重写 `design_tokens.dart`**
> (旧 token 常量名尽量保留以控制 diff,色值/字号值全换)。
> 任何分块手册与本宪法冲突时,以本宪法为准。
> iOS 规范给出处;凭印象的标【待核实】。
> 方向决策已锁定:**B 方案(iOS 骨架 + 星海皮肤)**、全量范围、
> 大标题用 Material `SliverAppBar.large`(不强转 Cupertino)。

---

## 一、色板(B 方案 · iOS 手法 + 星海色相)

### 1.1 深色主题(主战场)

iOS 出处:Apple HIG Color + SarunW《Dark color cheat sheet》
(<https://sarunw.com/posts/dark-color-cheat-sheet/>,iOS 13 实机枚举)。
星海微调:背景带 2-3% 蓝紫,手艺(半透明文字/灰差分层)完全照搬 iOS。

| Token(新名,写入 design_tokens.dart) | 值 | 语义 | iOS 原型 |
|---|---|---|---|
| `darkBackground` | `Color(0xFF0B0B12)` | 页面最底层(grouped 列表背景) | systemBackground `#000000` 加 3% 蓝 |
| `darkSurface` | `Color(0xFF17171E)` | inset-grouped 分组卡/导航栏底 | secondarySystemGroupedBackground `#1C1C1E` 加蓝 |
| `darkCard` | `Color(0xFF26262F)` *(原 darkCard 改三级语义)* | 三级:输入框填充、控件容器、按压高亮 | tertiarySystemBackground `#2C2C2E` 加蓝 |
| `darkSeparator` | `Color(0x99545458)` | 半透明分隔线(iOS 原型值,原样) | separator `#545458@60%` ✅核实 |
| `darkSeparatorOpaque` | `Color(0xFF3A3A44)` | 不透明分隔线(极少用) | opaqueSeparator `#38383A` 加蓝 |
| `darkTextPrimary` | `Color(0xFFFFFFFF)` | 主文字纯白 | label `#FFFFFF` ✅核实 |
| `darkTextSecondary` | `Color(0x99EBEBF5)` | 次要文字=白 60%(**不是灰!**) | secondaryLabel `#EBEBF5@60%` ✅核实 |
| `darkTextTertiary` | `Color(0x4DEBEBF5)` | 说明/占位符 | tertiaryLabel `#EBEBF5@30%` ✅核实 |
| `darkTextDisabled` | `Color(0x29EBEBF5)` | 禁用文字(白 16%) | quaternaryLabel【待核实】 |

> 铁律 1:深色下**禁止实色灰字**(`#9095B8` 作废),一律白 + 透明度。
> 铁律 2:深色下**禁止任何卡片投影**;层次 = `#0B0B12` → `#17171E` → `#26262F` 三级灰差 + `darkSeparator`。
> 铁律 3:深色背景不用纯黑 `#000`,但明度必须压到 ≤ #0B,iOS 的"黑"才出来。

### 1.2 浅色主题

| Token | 值 | iOS 原型 |
|---|---|---|
| `lightBackground` | `Color(0xFFF2F2F7)` | systemGroupedBackground ✅核实 |
| `lightSurface` | `Color(0xFFFFFFFF)` | secondarySystemGroupedBackground ✅核实 |
| `lightCard` | `Color(0xFFFFFFFF)` | 分组卡=纯白,层级靠灰底反衬 |
| `lightFillTertiary` | `Color(0x1F767680)` | tertiarySystemFill `#767680@12%` ✅核实(输入框/控件填充) |
| `lightSeparator` | `Color(0x493C3C43)` | separator `#3C3C43@29%` ✅核实 |
| `lightTextPrimary` | `Color(0xFF000000)` | label ✅核实 |
| `lightTextSecondary` | `Color(0x993C3C43)` | secondaryLabel `#3C3C43@60%` ✅核实 |
| `lightTextTertiary` | `Color(0x4D3C3C43)` | tertiaryLabel `#3C3C43@30%` ✅核实 |
| `lightTextDisabled` | `Color(0x2E3C3C43)` | 【待核实】 |

### 1.3 品牌与状态色(星海皮肤)

| Token | 值 | 语义 |
|---|---|---|
| `primary` | `Color(0xFF7C7BF0)` | 星海紫。**唯一交互强调色**,继承 v1 铁律 |
| `secondary` | `Color(0xFF6C8FF0)` | 图表第二序列/渐变辅助,不单独做交互色 |
| `accent` | `Color(0xFF56D4C8)` | 青。**仅状态正向/数据高亮**(Core 仪表盘正常使用、token 余量) |
| `statusSuccess` | `Color(0xFF30D158)`(深)/`Color(0xFF34C759)`(浅) | iOS systemGreen ✅核实 |
| `statusWarning` | `Color(0xFFFF9F0A)`(深)/`Color(0xFFFF9500)`(浅) | iOS systemOrange ✅核实(收编 geek_dashboard L774 硬编码 `0xFFF5B04C`) |
| `statusError` | `Color(0xFFFF453A)`(深)/`Color(0xFFFF3B30)`(浅) | iOS systemRed ✅核实(收编 L775 `0xFFE5534B`) |

> 收编清单:geek_dashboard 的 `statusWarning/statusError`、ai_config 的
> `0xFF34C759/0xFFFF9F0A/0xFFFF453A/0xFF8E8E93`、log_view 的
> `Colors.redAccent/orangeAccent`、各处 `Colors.red` 删除按钮,一律迁回 token。

### 1.4 聊天气泡(保留,仅微调)

`userBubble #5A58D4`、`assistantBubble` 改指向 `darkSurface #17171E`、
`systemBubble` 改指向 `darkCard #26262F`。(聊天域禁区不动渲染,此处仅 token 指认。)

---

## 二、字阶(对齐 iOS Type Scale,出处 HIG Typography)

| 语义 Token(新) | pt | 字重 | iOS 原型 | 旧 token 迁移 |
|---|---|---|---|---|
| `fontSizeDisplayLarge` | **34** | Bold | Large Title 34/Bold ✅核实 | 新增 |
| `fontSize3xl` | 28 | Bold | Title 1 28 ✅ | 保留 |
| `fontSize2xl` | 24 → **22** | Bold | Title 2 22 ✅ | 改值(野值 24 归位) |
| `fontSizeXl` | 20 | w600 | Title 3 20 ✅ | 保留 |
| `fontSizeLg` | ~~18~~ | — | iOS 无此档 | **删除**,引用处迁 `fontSizeXl`(20)或 `fontSizeHeadline`(17) |
| `fontSizeHeadline` | 17 | w600 | Headline 17/Semibold ✅ | 新增(列表行标题) |
| `fontSizeBodyLarge` | 16 → **17** | Regular | Body 17 ✅(iOS 默认正文) | 改值 |
| `fontSizeBodyMedium` | 14 → **15** | Regular | Subheadline 15 ✅ | 改值 |
| `fontSizeSm` | 13 | Regular | Footnote 13 ✅ | 保留 |
| `fontSizeXs` | 12 | Regular | Caption 1 12 ✅ | 保留 |
| `fontSizeCaption` | 10 → **11** | Regular | Caption 2 11 ✅ | 改值(野值 10 归位) |

> ⚠️ `fontSizeBodyLarge 16→17` 与 `fontSizeBodyMedium 14→15` 是全 App
> 级联变化,Block A 改完必须全量 `dart analyze` + 抽页目测,防止溢出。
> 出现 `RenderFlex overflow` 的行,裁 ellipsis 或减 padding,**不许回退字号**。

---

## 三、圆角(收缩,iOS 实测区间 + continuous corner)

| 语义 Token | 值 | 用途 | 出处 |
|---|---|---|---|
| `radiusGroupedCard` | **10** | inset-grouped 分组卡(新主力) | iOS 设置分组卡实测 10-12【待核实,取 10】 |
| `radiusCard` | 20 → **12** | 独立卡(非分组) | iOS 卡片惯例 10-12【待核实】 |
| `radiusButton` | 12 | 不变 | — |
| `radiusInput` | 12 | 不变(iOS 搜索框实际 10,搜索用 radiusFull 胶囊除外) | — |
| `radiusDialog` | 16 → **14** | AlertDialog | iOS alert 实测 ~14【待核实】 |
| `radiusBottomSheet` | 20 → **14** | 底部 Sheet 顶角 | iOS 13+ sheet 实测 10-14【待核实】 |
| `radiusSm` 8 / `radiusXs` 4 / `radiusFull` 30 | 不变 | — | — |

> **continuous corner**:依赖 `figma_squircle ^0.6.3` 已装(阶段一核实 pubspec)。
> 分组卡/底栏胶囊/大按钮的 shape 用 `SmoothBorderRadius(cornerRadius: …, cornerSmoothing: 1.0)`
> 或 `ClipSmoothRect`。【API 以包内实际导出名称为准,Block A 实施时先 `dart doc` 或看包 example 核实】

---

## 四、动效性格(iOS 手感三件套)

1. **按压 = scale 0.97 + opacity →0.6,120-150ms easeOut,零水波纹**
   (出处:阶段一 §1.4,iOS 13+ 系统列表行/按钮行为)。落地物:新组件
   `KiraPressable`(见 Block A-T3),Material 侧同时 `splashFactory: NoSplash.splashFactory`
   + `highlightColor: transparent` 全局兜底,但正解是替换 InkWell。
2. **页面转场**:Tab 切换维持现有淡入 300ms;**push/pop 改 iOS 侧滑**
   (`CupertinoPageRoute` 或 go_router `CustomTransitionPage` 自写 slide-from-right
   350ms `Curves.easeOutCubic`,带 swipe-back)。【go_router 下 swipe-back
   需要 CupertinoRoute 系,实施时验证,不通则纯侧滑转场亦可接受】
3. **spring 性格**:`curveSpring` 现值 `elasticOut` 过弹,改
   `Curves.easeOutBack`(温和回弹)用于卡片入场/对话框,300-350ms。
   `elasticOut` 禁止再用于页面级。

时长沿用:xs 100 / sm 200 / md 300 / lg 400 / dialog 250,不动。

---

## 五、结构范式(iOS 骨架五条)

1. **Large Title 导航**:一级页与设置二级页用 `CustomScrollView +
   SliverAppBar.large`(**Material 版,已锁定**),`title` 左对齐 34pt,
   收缩后 17pt semibold 居中(Material 默认行为)。编辑/表单类深页保持小标题返回栏。
2. **inset-grouped 分组卡**:`KiraSection` 重构为"**一组一张卡**"——组头 =
   13pt 全大写式小灰字(`darkTextSecondary`),组内多行共享一张
   `radiusGroupedCard(10)` 卡,行间 `darkSeparator` 0.5px 缩进分隔线,
   组间距 `spaceLg`(24)。出处:HIG Managing settings / Lists and tables。
3. **层级 ≤3**:设置树最深 `/settings → 组 → 二级页`,禁止 4 级。
4. **去阴影靠灰底**:深色零阴影;浅色仅 modal/sheet 允许 `shadowLevel2`,
   卡片 elevation 0,层级靠 `lightBackground` 灰底反衬白卡。
5. **控件单点 Cupertino 化**:`Switch/SwitchListTile` 全换
   `CupertinoSwitch`(activeTrackColor = primary);搜索框用
   `CupertinoSearchTextField` 风格改造 `KiraSearchBar`;长按/多选菜单用
   `CupertinoActionSheet`。**不引入第三方 UI 库,只用 SDK 自带 + figma_squircle。**

---

## 六、禁区与保留(继承 + 更新)

- 聊天域禁区不变:`webview_chat_stage.dart`、`widgets/chat/*`、`screens/chat/*`
  连读都禁止。token 色值被它们引用时,只许编译通过,不许进去改。
- `main_page.dart` 是主页欢迎页(非聊天域),只许碰 chrome(背景/状态栏),
  不许动 `_warmupWebView`、公告、协议弹窗逻辑。
- v1 铁律继承:单强调色(紫=点我、青=报状态)、8pt 栅格、层级别靠颜色乱跳。
- v1 §六.3(Core 仪表盘可视化)升级为本宪法 Block F 专项,见分块手册。

---

## 附 · token 文件重写映射速查

| 旧常量 | 新值/去向 |
|---|---|
| `darkBackground #0D1128` | `0xFF0B0B12` |
| `darkSurface #161B3A` | `0xFF17171E` |
| `darkCard #1F264A` | `0xFF26262F`(语义变三级) |
| `darkDivider #2A3057` | `darkSeparator 0x99545458` |
| `textPrimary #E8EAF5` | `darkTextPrimary #FFFFFFFF` |
| `textSecondary #9095B8` | `darkTextSecondary 0x99EBEBF5` |
| `textMuted #6A6F94` | `darkTextTertiary 0x4DEBEBF5` |
| `lightBackground #EEEEF8` | `0xFFF2F2F7` |
| `lightSurface #F5F5FF` | `0xFFFFFFFF` |
| `lightDivider #DDDDEE` | `lightSeparator 0x493C3C43` |
| `radiusCard 20` | 12;新增 `radiusGroupedCard 10` |
| `radiusBottomSheet 20` | 14 |
| `radiusDialog 16` | 14 |
| `fontSizeBodyLarge 16` | 17 |
| `fontSizeBodyMedium 14` | 15 |
| `fontSizeCaption 10` | 11 |
| `fontSizeLg 18` | 删除 |
| `curveSpring = elasticOut` | `easeOutBack` |
| `shadowLevel1/2/3` | 保留仅浅色 modal 用;深色一律 `const []` |
| 新增 | `statusSuccess/statusWarning/statusError` 双色对 |
