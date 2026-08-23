# Block A · 地基(Constitution v2 落地层)

> 依赖:无(首发 Block)。产出被全部后续 Block 引用。
> 全程禁令:不读聊天域。结构重做类 Task 单独 commit(已标 🔧)。
> 验证基线:每个 Task 完成后跑 `dart analyze`,末尾有"需人工真机目测项"清单。

---

## A-T1 🔧 design_tokens.dart 全量重写 🟡高风险(级联面广)

**目标文件**:`lib/presentation/theme/design_tokens.dart`

**改动**:
1. 颜色区(锚点:`// 深色主题` … `static const Color primary`)整体替换为
   宪法 v2 §1.1/1.2/1.3 表内全部值。旧常量名 `darkSurface/darkCard` 保留
   但语义升级(见映射速查);`textPrimary/textSecondary/textMuted` 改名
   `darkTextPrimary/darkTextSecondary/darkTextTertiary`,并新增
   `lightTextPrimary/lightTextSecondary/lightTextTertiary/colorDisabled` 对。
   - **决策**:删除旧名而不是 @Deprecated 保留——全量重写期一次改干净,
     编译器报错即迁移清单。
2. 字阶(锚点:`static const double fontSizeCaption = 10;` 起 9 行):
   按宪法 §二改值;删除 `fontSizeLg`;新增 `fontSizeDisplayLarge = 34`、
   `fontSizeHeadline = 17`(配 `weightSemibold` 注释)。
3. 圆角(锚点:`static const double radiusCard = radiusXl;`):
   `radiusCard` 改指向新值 12(直接写 `= 12;` 并把 radiusXl 语义注释改为
   "旧主卡片值,勿再用");新增 `radiusGroupedCard = 10`;
   `radiusDialog → 14`、`radiusBottomSheet → 14`。
4. 动效(锚点:`static const Curve curveSpring = Curves.elasticOut;`):
   改为 `Curves.easeOutBack`,注释"温和回弹,iOS 性格;elasticOut 禁用"。
5. 阴影:`shadowLevel1/2/3` 保留,但加注释"仅浅色模式 modal/sheet 用;
   深色与所有卡片禁用"。`shadowGlass` 保留给 Block B 底栏参考后删除(见 B-T2)。
6. 状态色:新增 `statusSuccessDark/Light`、`statusWarning = Color(0xFFFF9F0A)`、
   `statusError = Color(0xFFFF453A)` 等,按宪法 §1.3 表。

**结构重做**:是(整个文件语义重排,单独 commit `refactor(tokens): iOS v2 色板/字阶/圆角`)。
**验证**:`dart analyze` 此时会**爆大量错**(旧 token 名引用处)——这是预期,
本 Task 不要求绿,红清单就是后续 Task 的工单;跑 `dart analyze > a1_errors.txt` 存档。
**人工目测**:无(纯常量)。

---

## A-T2 app_theme.dart 双主题重建 🟡

**目标文件**:`lib/presentation/theme/app_theme.dart`

**改动**(锚点:`static ThemeData get darkTheme` / `get lightTheme`):
1. `colorScheme`:dark 用 `surface: darkSurface`、`surfaceContainerHighest: darkCard`;
   light 用 `surface: lightSurface`、`surfaceContainerHighest: lightFillTertiary`。
   文字色:**不要再写死在 colorScheme**,靠 textTheme 统一供。
2. `scaffoldBackgroundColor`:dark → `darkBackground`;light → `lightBackground`。
3. **AppBarTheme 改双模式**(锚点:`appBarTheme: const AppBarTheme(... centerTitle: true)`):
   - `backgroundColor: scaffoldBackground`(Large Title 展开时与页面同色);
   - `surfaceTintColor: Colors.transparent`(M3 滚动染色是质感杀手);
   - `scrolledUnderElevation: 0` + `elevation: 0`;
   - `centerTitle: false`(iOS 左对齐);
   - `titleTextStyle: fontSizeHeadline 17 / w600`(收缩态小标题样式)。
4. **全局去水波纹**(加在 ThemeData 根部):
   `splashFactory: NoSplash.splashFactory, highlightColor: Colors.transparent`。
   > 兜底用;列表行正解是 A-T3 的 KiraPressable。
5. `cardTheme`:`elevation: 0`、radius 用 `radiusCard(12)`、浅深色同;
   **删除浅色的 `elevation: 2`**(锚点:lightTheme 里 `cardTheme: CardThemeData(color…, elevation: 2,`)。
6. `textTheme` 按宪法 §二全表重写两份(dark 用 white 系、light 用 black 系
   opacity 色),新增 `displayLarge`(34/Bold)映射到 `headlineLarge` 之上——
   直接定义 `displayLarge: TextStyle(fontSize: 34, fontWeight: w700, letterSpacing: 0.4)`。
7. `dividerTheme` 新增:`DividerThemeData(color: separator, thickness: 0.5, space: 0.5)`。
8. `switchTheme` 不再依赖(见 A-T4),但 `cupertinoOverrideTheme` 建议挂:
   `cupertinoOverrideTheme: CupertinoThemeData(primaryColor: primary, …)`
   让 CupertinoSwitch 默认吃星海紫。
9. `dialogTheme`:`shape` radius 14、`backgroundColor: darkSurface/lightSurface`、
   `elevation: 0`(dark)。

**结构重做**:是(单独 commit `refactor(theme): v2 双主题`)。
**验证**:`dart analyze` 转绿(A-T1 的红应在本 Task 收掉大半,
剩余红=页面层引用,留给后续 Block)。
**人工目测**:首启切深浅色一次,看 scaffold/卡/文字三级是否出层次。

---

## A-T3 KiraPressable 新组件 🟢

**目标文件**:新建 `lib/presentation/widgets/common/kira_pressable.dart`

**规格**(宪法 §四.1):

```dart
class KiraPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;   // 供高亮裁切
  final bool scaleEnabled;            // 默认 true;列表行内部小按钮可关
}
```

- 行为:`onTapDown → setState(pressed=true)`;`AnimatedScale(scale: 0.97)` +
  `AnimatedOpacity(opacity: 0.6)`,`Duration(milliseconds: 120)`,`Curves.easeOut`;
  `onTapUp/onTapCancel → false`。
- 点击用内部 `GestureDetector`(behavior: opaque)。
- **不包 Material/InkWell**,彻底无水波。
- 同时 export 进 `widgets/common/common.dart`。

**风险** 🟢。**验证**:`dart analyze` 绿;写一个 `_KiraPressable` 单位 smoke
(可在临时 main 里跑,不建测试工程)。**人工目测**:按压列表行/按钮的"缩+暗"
是否跟手。

---

## A-T4 Kira 组件库 iOS 化改造 🔧 🟡

**目标文件**:`lib/presentation/widgets/common/kira_components.dart`

### A-T4a KiraCard 简化
锚点:`class KiraCard` 的 `shadows` 三元与 `border: Border.all(...)`。
- 删浅色双层 shadow,深色浅色统一 **零阴影**;
- 边框改发 `colorScheme.outlineVariant`(即 separator)0.5px,深色下可完全无边框;
- 圆角改 `radiusCard(12)`;InkWell 换 `KiraPressable`(A-T3)。

### A-T4b KiraSection 重构为 inset-grouped(**一块一卡**)
锚点:`class KiraSection` 里 `children.map((child) => Padding(... KiraCard(...)))`
——当前是**每个子项一张卡**。
- 新语义:`KiraSection(title, children)` → 组头(13pt `fontSizeSm`、
  `textSecondary`、w600、letterSpacing 0.5,左 padding = 屏幕边距 16 + 12)
  + **一张圆角 10 卡**，卡内 children 竖排，行间插
  `Divider(height: 0.5, indent: 16, endIndent: 0, color: separator)`。
- 新增 `KiraSection.plain(title, child)` 形态:组内自己是一个整体
  (如滑块组),不再自动插分隔线。
- 行间项建议配套新 widget `KiraGroupedTile`(= 无背景透明 ListTile 瘦版,
  minVerticalPadding 收紧),供子页组内用——**新建文件同目录
  `kira_grouped_tile.dart`**:
  - 高 44 起,标题 `fontSizeBodyLarge(17)`,副标题 `fontSizeSm(13)` textSecondary;
  - trailing 默认 `Icon(CupertinoIcons.chevron_forward, size: 16, color: tertiary)`;
  - 整行 KiraPressable。

### A-T4c KiraSwitch 换芯
锚点:`class KiraSwitch` 整段手绘 AnimatedContainer(50×30 硬编码)。
- 直接改为薄封装:`CupertinoSwitch(value, onChanged, activeTrackColor: colorScheme.primary)`,
  删全部手绘轨道代码。`KiraSwitchTile` 保持 API 不动，内部换 CupertinoSwitch;
  并新增 `KiraCupertinoSwitchTile` 不需要——保持原名即可。

### A-T4d KiraListTile 去主色图标执念
锚点:`Icon(icon, color: theme.colorScheme.primary)`。
- 改为 `color: theme.textTheme.bodySmall?.color`(次级文字色),
  主色只留给真正"可点主行动"的按钮。iOS 分组行图标若要彩块,
  走 A-T4b 的 `KiraGroupedTile(iconBg:…)` 可选参数实现,不强推。

### A-T4e KiraGradientCard 处置
- 保留但**只在主页欢迎/营销位**允许用;设置族禁用渐变卡(在 Block D 手册提醒)。
- 改圆角≥12 且去浅色阴影,深色只留顶部高光边。

**结构重做**:是(commit `refactor(kira): inset-grouped + CupertinoSwitch + pressable`)。
**验证**:`dart analyze` 绿(引用方若因 API 变红,记入下一 Block 工单);
**人工目测**:设置主页(settings_screen 已用 KiraSection×4)应立刻
变成"一组一张卡 + 半透明分隔"的 iOS 设置长相——这是 Block A 的及格画面。

---

## A-T5 KiraSearchBar Cupertino 化 🟢

**目标文件**:`lib/presentation/widgets/common/kira_search_bar.dart`

- 内容不换名,实现换:
  - 前缀 `Icon(CupertinoIcons.search, size: 18, color: tertiary)`;
  - 圆角改 10(iOS 搜索框不是全胶囊!iOS 13+ 实测 10)【待核实,按 10 执行】;
  - 填充色:dark `darkCard`、light `lightFillTertiary`;
  - 高 36(iOS 搜索栏实测 36)【待核实,现行 44 过胖】;
  - 清除按钮换 `CupertinoIcons.clear_circled_solid`;
  - focusedBorder 取消 primary 描边(iOS 搜索聚焦无边框,光标显示即可)。
- 让 padding 参数化 (`padding` 可空),为 Block B/C 吸顶排版让路。

**验证**:`dart analyze`。**人工目测**:角色页/聊天列表搜索框在深浅色下观感。

---

## A-T6 glass 底栏组件预备 🟢

**目标文件**:`lib/presentation/theme/glass_theme_extension.dart` +
`lib/presentation/widgets/common/glass_container.dart`(已存在,做接入)

- 检查 `glass_container.dart` 与 `glass_widgets.dart` 现 API(若已有毛玻璃容器),
  定一个统一入口 `KiraGlassBar`:
  - `ClipRRect` + `BackdropFilter(ImageFilter.blur(sigmaX: 22, sigmaY: 22))` +
    `color: darkSurface.withValues(alpha: 0.72)`(iOS Material Thin 语感,
    阶段一创新点 5);
  - ⚠️ **WebView 平台视图与 BackdropFilter 冲突风险**:glass_theme_extension
    L47 注释已写明"不使用 BackdropFilter(WebView 平台视图渲染失败)"。
    因此 `KiraGlassBar` **只在非聊天 tab 页生效**;聊天 tab(home/MainPage)
    退化为 `darkSurface @ 0.92` 半透明无 blur。
    → 需要给 `KiraGlassBar` 一个 `enabledBlur` 参数默认 true,Block B 按 tab 传值。
- 若 glass_container/glass_widgets 已有实现,直接在其上包薄壳,不重复造。

**验证**:`dart analyze`。**人工目测**:Block B 用上了再验收。

---

## Block A 完工验收(9 验)

1. `dart analyze` 零 error(允许 info)。
2. 真机/模拟器跑一次,录屏:深色设置主页(分组卡/分隔线/字级)。
3. 浅色同页。
4. 按压手感抽查 3 处(KiraCard、KiraGroupedTile、设置主页行)。
5. CupertinoSwitch 颜色 = primary。
6. AppBar 背色=scaffold 同色,滚动无 tint 染色。
7. 无 `fontSizeLg` 残留(`rg fontSizeLg` 应为 0)。
8. 无 `elasticOut` 残留。
9. 状态色 token 已存在并可 import。

**必须真机截图页**:设置主页(暗)、设置主页(亮)、任一用 KiraSection 的子页(如 mvu_settings)。
