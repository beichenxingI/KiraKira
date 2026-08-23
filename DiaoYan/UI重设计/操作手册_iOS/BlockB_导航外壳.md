# Block B · 导航外壳(app_shell + 转场)

> 依赖:Block A。本 Block 决定 App 的"骨架长相",🔧全部结构重做,单独 commit。

---

## B-T1 AppShell 砍固定 AppBar 残留 + 底栏毛玻璃化 🔧 🟡

**目标文件**:`lib/presentation/widgets/common/app_shell.dart`

### 改动 1:修注释 + 布局校正
锚点:`extendBody: false, // 让背景延伸到底栏后面，毛玻璃才有内容可模糊`
- 注释与值相反。改 `extendBody: true` 并把这行注释改成事实
  ("true 才让内容滚到底栏底下,blur 有东西可模糊")。body Stack 保留,
  但 `Scaffold(backgroundColor:)` 不再硬写 `DesignTokens.darkBackground`——
  锚点 `backgroundColor: DesignTokens.darkBackground`,改成
  `Theme.of(context).scaffoldBackgroundColor`(浅色才能对)。

### 改动 2:_KiraNav 毛玻璃胶囊
锚点:`// 胶囊条：只放四项，中间留空` 的 `Container(height: 56, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, …))`
- 换 `KiraGlassBar`(A-T6):
  - dark: `darkSurface.withValues(alpha: 0.72)` + blur 22;
    light: `Colors.white.withValues(alpha: 0.72)` + blur 20;
  - 聊天 tab(`/`-index 2)**关闭 blur**(`enabledBlur: false`,
    半透明 0.92),规避 WebView 兼容(见 A-T6);
  - 描边 0.5px `separator`;圆角 radiusFull 保留;
  - **删 `boxShadow`**(锚点:`boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20 …)]`)。
- 中间凸球 `_centerButton`(锚点:`Positioned(bottom: 14, child: _centerButton())`):
  - 保留凸球结构(品牌识别点),但去 `boxShadow` 紫辉
    (`DesignTokens.primary.withValues(alpha:0.55)` 那组),
    换 1px `Colors.white.withValues(alpha:0.25)` 顶部高光边 + 主色填充即可;
  - 球直径 52 → 48(减强势),按压包 KiraPressable(scale 0.93 档,球缩放可放大一点)。

### 改动 3:_navItem 按压 + 选中态
锚点:`Widget _navItem(...)` 内 GestureDetector + AnimatedContainer。
- GestureDetector 换 KiraPressable(仅 opacity 0.6,关 scale——导航项 scale 过大显廉价);
- 选中态色:`DesignTokens.primary` 保留;未选中:
  dark `darkTextTertiary`、light `lightTextTertiary`(白/黑透明度,非灰);
- label 10 → `fontSizeCaption`(11)。

### 改动 4:_AdvancedFab 处置 🔴决策点
锚点:`if (advanced) Positioned(right: 16, bottom: 100, child: _AdvancedFab())`
- 阶段一建议"收进设置二级",但 Core 的可达性重要(它是极客入口)。
- **本手册决定**:保留悬浮球,但 ① `bottom: 100 → 底栏高度 + 16` 动态算
  (别硬编码 100);② 去紫辉阴影,改 `KiraGlassBar` 壳 + primary 图标;
  ③ 按压包 KiraPressable。
- 防 FAB 与"底栏 4 项 + 中球"同侧拥挤:位置右下角不动。

**结构重做**:是(commit `refactor(shell): glass 底栏 + extendBody 修正`)。
**验证**:`dart analyze` 绿;`flutter run` 五个 tab 各切一次。
**人工目测**:底栏在列表滚动时透出内容模糊(尤其深色);聊天 tab 退化
半透明无模糊也成立;"聊天"凸球按压不反弹失真。

---

## B-T2 push 转场 iOS 侧滑化 🔧 🟡

**目标文件**:`lib/presentation/router/app_router.dart`

### 改动
锚点:所有 `parentNavigatorKey: _rootNavigatorKey` 的 `builder:` GoRoute
(约 30 条,见路由清单 L190-466)。
- 封装辅助 `_buildIosPushPage(LocalKey key, Widget child)`:

```dart
CustomTransitionPage<void>(
  key: key,
  child: child,
  transitionDuration: const Duration(milliseconds: 350),
  reverseTransitionDuration: const Duration(milliseconds: 300),
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
      child: SlideTransition(   // 前页微向左挪 30%,iOS 视差
        position: Tween(begin: Offset.zero, end: const Offset(-0.3, 0))
            .animate(secondaryAnimation),
        child: child,
      ),
    );
  },
)
```

- 把 root 级 GoRoute 从 `builder:` 改成 `pageBuilder: (c, s) => _buildIosPushPage(s.pageKey, XxxScreen(...))`,**带 query/path 参数的页逐个小心搬**
  (`/characters/:id`、`/cfg-scale-settings`、`/variables-settings`、
  `/character/:id/sprites`、`/chat/:id/statistics` 等)。
- **例外**:Tab 内 `_buildTabPage`(L124-142)不动;
  `webviewStage`、`/chat/:id`(webview)**不动**;
  `splash` 不动。
- 底部 Sheet/弹窗转场:不在本 Block。

**结构重做**:是(commit `feat(router): push 转场 iOS 侧滑化`)。
**验证**:`dart analyze`;逐路由手工跑一遍(用路由清单打勾)。
**人工目测**:push 进设置子页有右侧滑入 + 前页视差;返回顺滑不闪。

---

## B-T3 路由二层化(/settings/xxx 前缀)🔧 🔴

> 与 Block D 强耦合,放 B 是因它先把"门牌号"定下来;Block D 按本节路径
> 写各子页的 push。本 Task 只改路由表与 push 引用,不改页面内部结构。

**目标文件**:`lib/presentation/router/app_router.dart` + 全局 push 调用点(rg)

### 新路径 map(宪法 §五.5 三层上限)

```
/settings                          设置主页(shell tab,不变)
/settings/appearance/theme         ← /theme-settings
/settings/appearance/background    ← /background-settings
/settings/appearance/home          ← /home-appearance
/settings/appearance/sprites       ← /sprite-settings
/settings/ai/presets               ← /ai-presets
/settings/ai/cfg-scale             ← /cfg-scale-settings(保 query 参数)
/settings/ai/logit-bias            ← /logit-bias-settings
/settings/ai/tokenizer             ← /tokenizer-settings
/settings/ai/prompt-manager        ← /prompt-manager
/settings/ai/mvu                   ← /mvu-settings
/settings/ai/advanced              ← /advanced-settings
/settings/tools/tts                ← /tts-settings
/settings/tools/stt                ← /stt-settings
/settings/tools/translation        ← /translation-settings
/settings/tools/image-gen          ← /image-gen-settings
/settings/tools/regex              ← /regex-settings
/settings/tools/variables          ← /variables-settings(保 query)
/settings/tools/vector-storage     ← /vector-storage-settings
/settings/data/statistics          ← /statistics
/settings/data/logs                ← 新增 log_view 注册(原无路由!
                                      log_view_screen.dart 只能直接 push——修掉)
/advanced                          GeekDashboard(Core,不进 /settings 树——
                                   它是独立仪表盘,底栏悬浮球直达)
/logprobs-settings /llm-test /llm-config-list /model-detection  保留原路径
```

### 做法
1. `AppRoutes` 常量加新值(旧常量**改名指向新 path**,编译器红=引用点清单);
2. 路由表逐条改 path;
3. 全局 `rg "('/theme-settings'|'/regex-settings'|…)"` 找到所有 push 点,改新路径;
   已知调用方:geek_dashboard `_entryGridSection`(12 条路由常量)、
   settings_screen、ai_config_screen、character/menus 相关。
4. `log_view_screen.dart` 注册路由 `/settings/data/logs`,
   并把现有 push 点改为 `context.push('/settings/data/logs')`(若有)。
5. `app_shell.dart _calcIndex` 的 `path.startsWith('/settings')` 判断天然
   继续工作(`/settings/*` 会被一眼识别)。注意 `/settings` tab 在 shell 内、
   子页在 root navigator,判断逻辑不变。

**结构重做**:是,**单独 commit `refactor(router): 设置路由二层化`**。
**风险**🔴:push 点漏改=跳 404(errorBuilder 有兜底,会露怯)。
**验证**:`dart analyze`;写一张 25 路由手工打勾表,逐个跳一次;
`rg -- '-settings'` 确认无旧路径残留。
**人工目测**:设置→任意子页→返回,路径栏(debugLogDiagnostics 开着)
能看到 `/settings/ai/cfg-scale` 风格。

---

## B-T4 KiraNav 滚动联动(可选增强,🟢 可砍掉)

- 内容滚动到底部时底栏轻微下沉隐去 8px,向上滚回显。
- 若 12-20h 排期紧,**砍掉本 Task 不影响其余交付**。

---

## Block B 完工验收

1. `dart analyze` 绿。
2. 底栏毛玻璃在 4 个非聊天 tab 生效,聊天 tab 无 blur 也无穿透 bug。
3. 所有 root push 转场为右侧滑入。
4. 25 条路由打勾全过,无旧 `-settings` 路径残留。
5. `_AdvancedFab` 出现在右下角且不遮底栏 C 位球。

**必须真机截图页**:主页(底栏压住滚内容的模糊感)、设置主页、
任一 `/settings/xxx` 深层页 push 来了的那一刻。
