# Block C · 主导航 4 页(角色 / 聊天回忆 / API / 设置主页)

> **v2 修订:新增分页/横滑/顶部 tab/C-T6~T9**(依据 `DiaoYan\UI重设计\侦察_结构补充\`
> 两份侦察报告;人类已拍板方向)。
>
> 依赖:Block A/B。本 Block 专注 4 个 tab 页的 Large Title 化,
> **不碰聊天 webview 域**;`main_page.dart` 只碰外壳(见 C-T5)。
> 全部 🔧 结构重做,每页一个 commit。

> ⚠️ v2 侦察勘误:项目**没有 StatefulShellRoute**,router 是普通 `ShellRoute`
> (单 `_shellNavigatorKey`)+ 5 条平级 GoRoute + Fade 转场,AppShell
> 自绘胶囊底栏、**无顶部黑框**(黑框=各页自身 AppBar,正由本 Block 消灭)。

---

## 通用模板(4 页共用,先看这里)

把现有 `Scaffold(appBar: AppBar(...), body: Xxx)` 改成:

```dart
return Scaffold(
  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
  body: CustomScrollView(
    slivers: [
      SliverAppBar.large(
        title: Text('页面大标题', style: Theme.of(context).textTheme.displayLarge)
        // displayLarge=34 由 A-T1/2 提供;SliverAppBar.large 默认会用
        // titleTextStyle,需手动指定大字号,收缩后 Material 自动切 17 w600
      ),
      // 内容区:SliverToBoxAdapter / SliverList / SliverFillRemaining
    ],
  ),
);
```

**注意**:
- 若原 body 是 `Column( 搜索框 + Expanded(ListView) )`,把搜索框塞进
  `SliverPersistentHeader(pinned: true)` 或直接放第二颗 sliver,
  让搜索随滚可收/吸顶。
- Scaffold 的 `floatingActionButton` 在主导航页一律**删除**,动作进大标题
  右上 `actions`(iOS 风格"+")。
- 每页保留 `SafeArea` 现有逻辑,不要乱改。
- Large Title 中文标题仍 34 Bold,letterSpacing 0。

---

## C-T1 角色列表页 🔧 🟡

**目标文件**:`lib/presentation/screens/character/character_list_screen.dart`

### 改动链表

1. **双 AppBar 状态收敛为一颗 SliverAppBar**。
   锚点:`appBar: _selectionMode ? AppBar(...) : AppBar(...)`(build 内)。
   - 常态:`SliverAppBar.large(title: Text(l10n.characters))`,
     actions 放:`IconButton(CupertinoIcons.add)` 替代 FAB 与刷新合流
     (刷新改成下拉刷新,见 3);再一个 `IconButton(CupertinoIcons.checkmark_circle)`
     进选择模式。
   - 选择态:SliverAppBar(非 large)`title: Text('已选 N 个')`,
     leading 关闭,actions 保留导出/删除。**两块状态用同一 CustomScrollView**,
     sliver 切换。
2. **搜索吸顶**。
   锚点:`body: Column(children: [KiraSearchBar(...), Expanded(...)])`。
   - Column 拆掉,搜索框放入 `SliverPersistentHeader(pinned: true, delegate: _SearchHeaderDelegate)`,或简单方案:`SliverToBoxAdapter(KiraSearchBar)` 不吸顶(iOS 设置搜索是吸在大型标题下沿,角色页采用"跟随滚入"即可,**别死磕 pinned**,KISS)。
3. **下拉刷新**。
   - `RefreshIndicator(onRefresh: ref.read(...).refresh())` 包 CustomScrollView,
     替代 AppBar 刷新按钮。iOS 原生即下拉刷新,风格合。
4. **FAB 删除**。
   锚点:`floatingActionButton: Padding(padding: EdgeInsets.only(bottom: _fabBottomClearance), child: FloatingActionButton(... _showFabMenu))`。
   - 删除 FAB 与 `_fabBottomClearance`;`_showFabMenu` 的三个入口
     (导入/ZIP 导入/新建)改为右上 `+` 触发 `CupertinoActionSheet`:
     ```dart
     showCupertinoModalPopup(context, builder: CupertinoActionSheet(
       actions: [导入角色 / 从ZIP批量导入 / 新建角色],
       cancelButton: CupertinoActionSheetAction(child: Text('取消'), ...),
     ));
     ```
   - 风险点:CupertinoActionSheet 在 MaterialApp 下文字色可能走默认主题,
     传 `Theme.of(context).textTheme.bodyLarge`(深色白字)进去兜住。
5. **单位卡去阴影**。
   锚点:阶段一报告指 character_list_screen L737-763 单位卡阴影硬编码。
   - 找到 `_CharacterCard` 或等价卡内 `boxShadow` / `elevation`,删阴影,
     卡色走 `cardColor`(已= darkSurface),边框 0.5px separator。
6. **长按选择模式保留**(iOS 照片也有长按多选),但进选择态的提示条文案
   `'已选 ${_selectedIds.length} 个'` 已有,无需改。

**风险** 🟡(双 AppBar + FAB 路径多)。
**验证**:`dart analyze` 绿;选择态/常态切换;搜索过滤;
下拉刷新拉到触发;`+` 弹 ActionSheet 三项跳对。
**人工目测**:大标题"角色"滚入时收缩动画顺。

---

## C-T2 聊天回忆页 HomeScreen 🔧 🟢

**目标文件**:`lib/presentation/screens/home/home_screen.dart`

### 改动链

1. AppBar 去副标题。
   锚点:`appBar: AppBar(title: Column(children: [Text(l10n.appTitle), Text('基于 NativeTavern', ... caption)]))`
   - 改成 `SliverAppBar.large(title: Text('聊天'))`(大标题用"聊天",不再用 appTitle+副标题堆,副标题"基于 NativeTavern"**删除**,品牌信息移到关于页,Block D 关于组已有)。
2. FAB 收为右上。
   锚点:`floatingActionButton: Padding(padding: EdgeInsets.only(bottom: 80), child: FloatingActionButton.extended(icon: Icons.add, label: l10n.newChat, onPressed: push /characters))`。
   - 删 FAB 与避让 padding 80;
   - `SliverAppBar.large` actions 加 `IconButton(CupertinoIcons.square_pencil, onPressed: () => context.push(AppRoutes.characters))`(iOS 信息"写新信息"语义)。
3. 搜索栏跟滚。
   锚点:`body: Column(children: [_buildSearchBar(context), Expanded(child: _ChatListView(...))])`。
   - `KiraSearchBar` 放 CustomScrollView 第二 sliver(SliverToBoxAdapter),
     底部 `SliverFillRemaining` 包 `_ChatListView`,或更稳:把 `_ChatListView`
     的 ListView 改 sliver 化(`CustomScrollView` 内再嵌 ListView 会有嵌套滚动问题——**必须把聊天条目改成 SliverList/SliverChildBuilderDelegate**)。
   - error/empty 态(`const Icon(Icons.error_outline ...)` 那块)包
     `SliverFillRemaining(child: Center(...))`。
4. `refreshIndicator`:聊天列表已有 invalidate 的生命周期管理,
   不动逻辑,只负责滚结构。

**风险** 🟢(页面小)。**验证**:`dart analyze`;空态/有数据态/搜索;新聊天跳转角色页。
**人工目测**:74 行标题"聊天"在深色下与底栏毛玻璃的呼吸感。

---

## C-T3 AI 配置主页 🔧 🟡(只 iOS 化骨架,功能重排留给 Block G)

**目标文件**:`lib/presentation/screens/ai_config/ai_config_screen.dart`

> 本页 1996 行,**本 Task 只做外壳与组合方式**,内部 QuickSetupCard/状态卡/
> 分区块的 iOS 化细节改造由 Block G 展开。避免单 Task 改太大。

### 改动

1. AppBar → `SliverAppBar.large(title: Text(l10n.aiConfiguration))`,
   actions 保留 `IconButton(Icons.file_download → /ai-presets)`。
   锚点:`AppBar(title: Text(l10n.aiConfiguration), actions: [IconButton(...)])`(L38-44 附近)。
2. body `ListView`(锚点:L47-166 build 的 ListView)改 `CustomScrollView`,
   原 children 转 slivers:
   - `QuickSetupCard` / 激活预设 Banner / 三段 KiraSection 各包
     `SliverToBoxAdapter`,底部 `SliverPadding(padding: EdgeInsets.only(bottom: 96))`
     避底栏。
3. `KiraSection` 此处已用 3 处——Block A 重构后**自动变成 inset-grouped**,
   本 Task 不动。但要检查 KiraSection 的 children 是 tile 则不包裹额外卡片。
4. 预设横幅(锚点:L51-109 的 `activePreset != null` 渐变 Container):
   - 渐变 `LinearGradient` 保留?**否**——iOS 通知横幅是纯深色表面;
     改为 `colorScheme.surfaceContainerHighest`(darkCard)+ 0.5 边框 +
     左侧 3pt 宽 primary 竖条(像 iOS 邮件 VIP 标记)。
   - 行内 `TextButton('change')` 换 `CupertinoButton` 最小尺寸或保留 KiraPressable
     文字按钮,色用 primary。
5. `_ConnectionTestTile` 等状态点硬编码 `Colors.green/red`(锚点:L807-809)
   → `statusSuccess/statusError` token。
6. 死代码**本 Task 不删**(Block G 处理)。

**风险** 🟡(文件大,只许动 build 外层)。
**验证**:`dart analyze`;跑通"改 BaseURL/Key/选模型/测连接"全流程。
**人工目测**:大标题"AI 配置"(按 l10n)收缩;横幅不再"彩虹"。

---

## C-T4 设置主页重构 🔧 🟡(信息架构重排)

**目标文件**:`lib/presentation/screens/settings/settings_screen.dart`

### 改动

1. **大标题**:锚点 `appBar: AppBar(title: Text(l10n.settings))` →
   `SliverAppBar.large(title: Text(l10n.settings))`,body 改 CustomScrollView。
2. **顶部搜索框(占位,真功能在 Block E)**:
   大标题下第一 sliver 放 `KiraSearchBar(hintText: '搜索设置')`,
   `onTap` 触发 Block E 的搜索 overlayAPI;Block E 未做前,先聚焦即有键盘
   但无筛选也可接受,把 TODO 留给 Block E。
3. **信息架构按宪法 §五.2 + 阶段一 §1.3 重排为 6 组**(每组 = 新 KiraSection inset-grouped):

```
[置顶高频组,无组头]
  深色主题        → KiraSwitchTile(现有 _DarkModeTile)
  语言            → KiraGroupedTile(push _showLanguageSelector 保留)
  用户画像        → KiraGroupedTile(→ /personas,复用现有 L181 push)

[外观]
  主题            → /settings/appearance/theme
  聊天背景        → /settings/appearance/background
  主页外观        → /settings/appearance/home
  精灵图          → /settings/appearance/sprites

[模型与生成]
  AI 预设         → /settings/ai/presets
  采样参数        → /settings/ai/advanced
  CFG Scale       → /settings/ai/cfg-scale
  Logit Bias      → /settings/ai/logit-bias
  分词器          → /settings/ai/tokenizer
  提示词管理      → /settings/ai/prompt-manager
  变量框架 MVU    → /settings/ai/mvu

[工具链]
  TTS / STT / 翻译 / 图片生成 / 正则 / 变量 / 向量存储

[数据与诊断]
  日志统计        → /settings/data/statistics
  日志查看器      → /settings/data/logs
  极客 Core       → /advanced (标"高级"角标)

[关于]
  关于 KiraKira   → /about
  版本 1.0.0      → 说明文字行(版本号硬编码 L102 迁入此行)
```

4. 旧 4 组(用户/聊天/高级/关于)且不饱满的两颗 SwitchListTile
   (锚点:`KiraSwitchTile ×2` 附近 L39-157)并入上面 6 组;
   **删除遗留未引用的 `_ConfirmDeleteTile/_AutoSaveTile/_DebugLogTile`**
   (扫描确认未被引用,settings_screen L204/223/242)。
5. push 路径全部用 Block B 二层化后的新常量。

**风险** 🟡(信息架构改动,用户路径记忆变了——这是方向决策已接受的成本)。
**验证**:`dart analyze`;每行点一遍到新路由。
**人工目测**:首页一屏 + 半,组之间 24px 留白,组头小灰字,无大黑条。

---

## C-T5 主页 main_page 只碰外壳 🟢

**目标文件**:`lib/presentation/screens/main_page/main_page.dart`

### 允许动的范围
- 状态栏样式(用 `AnnotatedRegion<SystemUiOverlayStyle>` 包 Scaffold,
  dark 用 `SystemUiOverlayStyle.light`,light 用 `dark`);
- 页面背景若有硬编码色(`0xFF1a1a2e` 旧宪法点名,看 main_page/build 部分
  若有,改 token);
- **不许动** `_warmupWebView` / `_preloadCharacterAvatars` /
  `maybeShowTermsDialog` / 公告弹窗 / 音乐服务初始化。

### 验证
`dart analyze`;启动跑一次看欢迎页 greeting/time 是否正常叠在背景上。

---

# ━━━ v2 新增:角色页专项(C-T6 ~ C-T9)━━━

> 侦察事实依据:`DiaoYan\UI重设计\侦察_结构补充\侦察2_3_角色列表_聊天历史_导航.md`。
> 关键结论:角色数据为 SQLite 全量内存列表(量级几十~小几百,无 LIMIT),
> "分页"实为**内存切片/分批渲染**,无 IO 成本;过滤在 build 层、多选按 ID 存,
> 与页切片天然解耦。聊天历史列表真身在 `home_screen.dart`(可改,非禁区)。

## C-T6 角色页分页显示(每页 N 可调)🔧 🟢

**目标文件**:`lib/presentation/screens/character/character_list_screen.dart`
+ **新建** `lib/presentation/providers/character_grid_provider.dart`(归属 Block C,见契约表)

### 改动链
1. **新 provider**:照抄 `advanced_mode_provider.dart` 模板
   (StateNotifierProvider<int> + SharedPreferences),键名 `character_grid_page_size`。
   - 默认值 **12**(2 列 × 6 行,一屏半;侦察建议 20 但人类封顶 **16**,
     取 12 作为密度与滚动的折中);
   - 可选档位:**4 / 8 / 12 / 16**(持久化存 int)。
2. **分批渲染("每页 N,超出下滑")**:`_CharacterGridView` 的
   GridView(锚点:`SliverGridDelegateWithFixedCrossAxisCount` 处)
   不推翻,只改数据源切片:
   ```dart
   final visibleCount = ref.watch(characterGridPageSizeProvider) * _loadedPages;
   final visible = filtered.take(visibleCount).toList();
   ```
   `ScrollController` 触底(剩余 < 600px)时 `_loadedPages++` 追加下一批;
   搜索词变化 / 卡片总数变化时重置 `_loadedPages = 1`。
   - 这就是人类方案里"分页"的落地:首屏 N 个、下滑自动续批,
     **不做底部翻页条**(iOS 无翻页控件,无限滚动贴边)。
3. **与搜索/多选共存**(侦察方案 1):
   - 过滤仍作用在全量列表得到 `filtered`,分页只对 `filtered` 切片;
   - `_selectedIds` 按 ID 存、与可见切片解耦,跨批多选不清零(现有逻辑已如此);
   - 搜索 onChanged 里 `setState(() { _searchQuery = …; _loadedPages = 1; })`。
4. **设置项入口**(免进设置页,就地可达):
   `SliverAppBar` actions 的"···"或长按…简化为:在 C-T8 分段控件下方的
   工具行右端加一个 `CupertinoIcons.square_grid_2x2` 图标,点击弹
   `CupertinoActionSheet`("每页显示:4 / 8 / 12 / 16",当前档打勾),
   选中即 `ref.read(characterGridPageSizeProvider.notifier).set(n)` 持久化。

**结构重做**:是(commit `feat(characters): paged grid + page size setting`)。
**风险** 🟢(纯切片,逻辑不动)。
**验证**:`dart analyze`;造 20+ 角色,首屏只出 12,滚到底续批;
改档位立即生效且冷启动后保持;搜索时重置为第一批;多选跨批不丢。

---

## C-T7 角色卡改造:缩小 + 名字/作者居中 🟢

**目标文件**:`lib/presentation/screens/character/character_list_screen.dart`
(锚点:`class _CharacterGridCard` L720-901 附近、网格 delegate 参数)

### 改动
1. **尺寸缩小**:网格 `childAspectRatio: 0.72 → 0.80`(卡变矮),
   卡内头像区 `Expanded(flex: 4) → flex: 3`,文字区 padding 不变宽、收紧纵向。
   视觉目标:一屏露出更多卡、头像仍是主角(iOS 照片网格的"缩略图密度感")。
   crossAxisCount 保持 2(头像清晰度优先,不做 3 列)。
2. **名字/作者居中**:文字区 Column `crossAxisAlignment: start → center`,
   角色名 `textAlign: TextAlign.center`、"by {creator}" 同居中;
   字号不动(角色名 fontSizeBodyMedium w600、作者 fontSizeCaption 半透明)。
3. **选中圈标**保持右上叠层,不受居中影响。
4. 错峰动画 `_StaggeredEntrance` 保留;注意分页续批后 index 从批内重新计数,
   延迟用 `index % pageSize` 归一,避免后批入场延迟越滚越长。

**风险** 🟢。**验证**:`dart analyze`;深浅色各截一张;单字名/超长名截断仍优雅;
多选圈标不与居中文字打架。

---

## C-T8 角色页顶部导航重构:Large Title + 分段控件 🔧 🟡

**目标文件**:`lib/presentation/screens/character/character_list_screen.dart`

> 与 C-T1 的 SliverAppBar 改造**叠加执行**(同文件,一次 commit 内分步骤,
> 或紧接 C-T1 之后单独 commit)。侦察确认:黑框就是本页自己的 AppBar,
> 杀掉它 = C-T1 的 SliverAppBar 化 + 本 Task 的分段控件。

### 改动
1. **Large Title "角色"**:常态 `SliverAppBar.large(title: Text(l10n.characters))`
   (沿用 C-T1 配方;选择态仍切普通 SliverAppBar,分段控件在选择态**隐藏**)。
2. **分段控件**:大标题下沿、搜索框之上,加一颗吸顶 sliver
   (`SliverPersistentHeader(pinned: true)` 或 C-T1 的"跟随滚入"简化位;
   建议 pinned,因为它是页面级导航不是过滤):
   ```dart
   CupertinoSlidingSegmentedControl<int>(   // SDK 自带,不引第三方
     groupValue: _tab,                       // 0=我的角色(默认) 1=角色市场
     children: { 0: Text('我的角色'), 1: Text('角色市场') },
     onValueChanged: (v) => setState(() => _tab = v),   // 仅点击切换,不做横滑
   )
   ```
   - 样式:背景 dark `darkCard` / light `lightFillTertiary`,
     thumb 深色 `darkSurface`→实际拇指色用 `lightSurface`【待核实,
     按 iOS 分段控件"白拇指浮灰槽"印象执行,实施时对真机调】。
3. **「角色市场」占位(只此,绝不实现数据)**:
   `body` 按 `_tab` 切换:0 → 现有角色网格;1 → 空态页
   (大号 SF Symbol 风图标 `CupertinoIcons.cloud_download`+ "敬请期待" +
   副文案"角色市场建设中,未来可在线浏览与导入角色"),
   empty 态用 `SliverFillRemaining(child: Center(...))`。
   **禁止**:任何网盘/HTTP/数据获取逻辑;禁止预留假 provider。
4. 分段控件状态不落盘(每次进页回"我的角色";iOS 同类页惯例)。

**风险** 🟡(SliverPersistentHeader 吸顶与 large title 折叠的高度计算需真机调)。
**验证**:`dart analyze`;两段切换;选择模式进入时分段控件消失、
退出恢复;「角色市场」空态显示正常。
**人工目测**:分段控件拇指滑动动画贴合星海紫激活态。

---

## C-T9(可选)角色页 ↔ 聊天回忆页横滑 🟡

**目标文件**:`lib/presentation/widgets/common/app_shell.dart`
(⚠️ 归属 Block B;本 Task 已与契约表同步放宽权限,仅允许包 PageView 一层,
不动 `_KiraNav`/`_calcIndex` 逻辑)

> 侦察结论:**部分兼容,且比预期好做**——项目是普通 ShellRoute(无分支
> Navigator),5 tab 本就是平级整页替换,塞进 PageView 无 "branch Navigator
> 脱离管理" 的坑。**只做双页版(角色 ↔ 聊天回忆)**,五页全横滑跳过
> (与中间凸起聊天按钮、URL 语义 `/` vs `/chats` 冲突,见侦察报告 §3.c)。

### 方案(PageView + 手动 go,侦察方案 1)
1. AppShell body 内,当路由在 `/characters` 或 `/chats` 时,child 外层
   包 `PageView(controller: _pageCtrl)`,两页=CharacterListScreen /
   HomeScreen(当前 router 的 child **不用**,自行实例化并配合
   `AutomaticKeepAliveClientMixin` 保滚动位置);
2. `onPageChanged` → `context.go(target)` 同步 URL 与底栏选中态;
   反向 `_calcIndex` 变化时 `_pageCtrl.animateToPage`(防点击底栏后
   PageView 不同步);
3. 手势冲突排查:角色网格内长按多选(纵向手势为主)与 PageView 横向
   drag 不冲突;`CupertinoSlidingSegmentedControl`(C-T8)是点击控件,
   不吞横向手势;**若实测 any 冲突,本 Task 整案废弃,记入手册,不硬上**。
4. Hero 动画 `character-<id>` 跨 PageView 页不受影响,保留。

**风险** 🟡(keepAlive + URL 双同步是状态机,要防往复抖动)。
**验证**:`dart analyze`;角色↔聊天回忆往返滑 10 次无丢滚动位/无闪烁;
底栏点击与横滑互相同步;聊天列表下拉刷新在 PageView 内可用。
**不做则**:在本节顶部标"已跳过"并用一行注明理由,其余 v2 任务不受影响。

---

# ━━━ v2 修订结束,以下为完工验收(已含 v2 新项)━━━

## Block C 完工验收



1. `dart analyze` 绿。
2. 4 tab 各自能滚出/收回大标题,标题字号 34→17 切换自然。
3. 角色页选择模式/下拉刷新/ZIP 导入/新建全通;无 FAB。
4. 聊天回忆页"写新聊天"右上笔图标,空态/搜索/列表全通。
5. AI 主页测一次连接。
6. 设置主页 6 组一共 20+ 行全部跳到正确二层路由。
7. (v2)角色页:每页档位 4/8/12/16 切换即时生效、冷启动保持;滚到底自动续批;
   搜索重置到第一批;多选跨批不丢。
8. (v2)角色卡矮化(0.80)后名字/作者居中,长名截断不溢。
9. (v2)分段控件「我的角色/角色市场」点击切换;市场页仅"敬请期待"空态,
   无任何网络代码;选择模式下分段控件隐藏。
10. (v2,若做 C-T9)角色↔聊天回忆横滑与底栏点击双同步,滚动位保持。

**必须真机截图页**:角色页(暗)、聊天回忆(暗)、AI 配置(暗+有激活横幅)、
设置主页(暗+亮)、主页欢迎屏(状态栏色)。
