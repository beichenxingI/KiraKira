# Block D · 设置族 21 页批量 iOS 化

> 依赖:Block A/B/C。21 页用**同一套批量模板**,每页一个 commit(或 3 页/批)。
> 路由已是 Block B 二层化后的新路径。全部 🔧(换滚动骨架),风险单页 🟢~🟡,
> 弹窗迁移页 🟡🔴。

---

## D-T0 批量模板(每页照抄的结构)

每页做五件事:

### ① AppBar → SliverAppBar.large
```dart
// 前:
return Scaffold(appBar: AppBar(title: Text(l10n.xxx), actions: [...]), body: ListView(...));
// 后:
return Scaffold(
  body: CustomScrollView(slivers: [
    SliverAppBar.large(title: Text(l10n.xxx), actions: [...]),
    ...内容 slivers,
  ]),
);
```
- 编辑/表单深页(`ai_preset_edit_screen`)**不进 large**,保持小标题
  `SliverAppBar(pinned: true, title: ...)`(iOS 表单页即小标题)。
- actions 图标换 `CupertinoIcons.*`,保留语义。

### ② ListView → Sliver 化分组
- 平铺 ListTile/SwitchListTile 们 → 用 A-T4b 的 `KiraSection` 分组
  (一组一卡,行间自动分隔线)。
- 标题/副标题字号自动随 textTheme 走 17/13;**页内不得再有 `fontSize: 16/18` 字面量**(`rg "fontSize: [0-9]"` 清零,改用 token)。

### ③ Switch / SwitchListTile → CupertinoSwitch
- `Switch(...)` / `SwitchListTile(...)` → `KiraSwitchTile(...)`(内部已是 CupertinoSwitch,A-T4c)。
- 整页 `rg "SwitchListTile|Switch\("` 清零(KiraSwitchTile 里的除外)。

### ④ AlertDialog 分类处置(**本 Block 最大工作量**)
规则:
- **破坏确认类**(删除/清空/重置):保留弹窗,但样式 iOS 化——
  圆角 14(主题已管)、按钮文字色:确认删除 = `statusError`,取消 = 默认;
  两按钮上下排不出错,水平"取消/删除"即可(iOS Alert 样式,
  不引 CupertinoAlertDialog 也可,视觉差不大;**或**直接换
  `CupertinoAlertDialog`,二选一,全 App 统一选一种——**决定:用
  `CupertinoAlertDialog`,iOS 感关键组件**)。
- **表单类**(输入 API Key/整数/预设名):**原则改 push 子页**;量少的页
  (1-2 个表单弹窗)允许原地保留但统一走 `showAppDialog` + 圆角 14 +
  `CupertinoTextField` 内容。多的页见分表标注。
- **信息展示类**(帮助/说明):改成底部 Sheet(`showModalBottomSheet`,
  圆角 14,内容可滚)或 push "关于本功能"页;不保留 AlertDialog 形式。

### ⑤ 硬编码色清零
- `rg "Color\(0x|Colors\.(red|orange|green|blue|white|black)"` 在本页
  结果逐条判:删除红→`statusError`;状态绿→`statusSuccess`;警告橙→
  `statusWarning`;文字→文字 token;背景→surface token。

---

## D-T1 分页工单(按子代理全量扫描 + 路由清单)

> 译名:列表中"表单弹窗"= 内含 TextField 的 AlertDialog;"确认"= 纯确认。
> "Sliver 化"= ①②③;"弹窗迁"= ④;"色清"= ⑤。✅=模板全做,🔵=仅外观顺移。

| # | 文件(相对 settings/) | 页标题(锚点) | 弹窗存量(表单/确认/信息) | 本页要点 | 风险 |
|---|---|---|---|---|---|
| 1 | advanced_settings_screen | `l10n.advancedSettings` | 4/1/0 | Sliver 化;3 个表单弹窗(整数输入/总结模型/总结提示词/停止序列 4 个)改 push 子页或底部 Sheet 表单。考虑整页改组:mirostat 组/总结组/采样子组 | 🟡 |
| 2 | ai_presets_screen | `l10n.aiPresets` | 1/1/1 | "新建"改成右上 + 直推 `AIPresetEditScreen`(已有 MaterialPageRoute push,锚点 L133-137);删导出确认文案清;`Colors.red` L651 清零 | 🟢 |
| 3 | ai_preset_edit_screen | `'编辑预设'`(硬编码中文) | 0 | **不进 large**;标题改 l10n 或保留中文但统一; actions 的 `TextButton('保存', style: TextStyle(color: AppTheme.primaryColor))` 保留语义,样式用主题 | 🟢 |
| 4 | background_settings_screen | 条件 title 角色/聊天背景 | 1/0/1 | 16 个硬编码引用色卡 `0xFFFFA726...`(L296-299)迁入一个 `_kPresetColors` 顶部常量(不强行 token 化,它们是"可选色板"非"主题色");Sliver 化 | 🟡 |
| 5 | cfg_scale_settings_screen | `l10n.cfgScale` | 0/0/1 | 帮助信息弹窗改 Sheet;Sliver 化 | 🟢 |
| 6 | home_appearance_screen | `'主页外观'`(硬编码) | 0 | 结构简单;Sliver 化 + 标题 i18n 化(若无 key 允许先留中文 TODO 注释) | 🟢 |
| 7 | image_gen_settings_screen | `l10n.imageGeneration` | 2/0/0+1 预览 | API Key/Endpoint 表单 → push 子页;全屏预览 `_showFullScreenImage` 不动;橙色警告/红错误框(L512/L810-821)→ status token | 🟡 |
| 8 | log_view_screen | `'日志查看器'` | 0/1/0 | 新增路由(见 B-T3);`Colors.redAccent/orangeAccent` L69-70 级别色 → `statusError/statusWarning`;3 个 actions 保留 CupertinoIcons | 🟢 |
| 9 | logit_bias_settings_screen | `l10n.logitBias` | 3/1/1 | 5 弹窗量:3 表单(新建/编辑/导入)改 push 一个"LogitBiasPresetEditScreen"子页(新建文件,是新增的页,允许) | 🔴(新增子页) |
| 10 | mvu_settings_screen | `'变量框架'`(硬编码,`centerTitle: false`) | 0/0/1 | 已用 KiraSection×4,Block A 后自动 inset-grouped;Sliver 化 + 标题 i18n TODO | 🟢 |
| 11 | prompt_manager_screen | `l10n.promptManager` | 2/1/2 +1 Sheet | 段落编辑表单(弹窗含大文本域)改 push "段落编辑页";预设选择 Sheet 保留;菜单 actions 改 `CupertinoIcons.ellipsis_circle` | 🟡 |
| 12 | regex_settings_screen | `l10n.regexScripts` + PopupMenu | 0/2/1 +1 Sheet 编辑器 | 脚本编辑器 Sheet(含大表单)改 push "脚本编辑页";红按钮 `ElevatedButton.styleFrom(backgroundColor: Colors.red)` L317/341 → `statusError` 文字色不铺底 | 🟡 |
| 13 | sprite_settings_screen | `'表情精灵图'` / `xxx Sprites` | 0/2/2 +1 Sheet 菜单 | 双 Scaffold(全局/角色)都 Sliver 化;Sheet 菜单改 `CupertinoActionSheet`;Delete/Cancel 英文硬编码改中文/ l10n;`backgroundColor: AppTheme.darkCard` L476 硬编码 → theme.surface | 🟡 |
| 14 | statistics_screen | `'Chat/App Statistics'`(英文硬编码) | 0/1/0 | Sliver 化;标题改中文(应用统计/聊天统计);大数字卡片可走 inset-grouped 卡 | 🟢 |
| 15 | stt_settings_screen | `l10n.speechToText` | 1/0/0 | API Key 表单 → push 子页或 Sheet;权限警告橙横幅 L43-53 → `statusWarning` ;录音红色 → statusError | 🟢 |
| 16 | theme_settings_screen | `l10n.themes` | 1/1/1 | `_ThemeEditorDialog`(新建+编辑共用,表单)改 push "_ThemeEditorScreen"新页;取色器弹窗(选择类)保留但样式统一;GestureDetector 色卡 ×3 包 KiraPressable | 🟡 |
| 17 | tokenizer_settings_screen | `l10n.tokenizerSettings` | 0/0/1 | 帮助改 Sheet;色谱 `Colors.blue/green/orange/purple/teal/pink` L465-470 是"样本条配色"非主题色,迁 `_kSampleColors` 顶部常量并注明豁免 | 🟢 |
| 18 | translation_settings_screen | `l10n.translationSettings` | 1/0/0 | API Key 表单 → 子页/Sheet;红错误框 L410-421 → statusError | 🟢 |
| 19 | tts_settings_screen | `l10n.textToSpeech` | 1/0/0 | API Key 表单迁出;供应商卡片标题硬编码中立(已是产品名词) | 🟢 |
| 20 | variables_settings_screen | 条件 chat 变量/全局变量 | 2/2/0 | 4 弹窗:2 表单(添加/编辑)合并 push 一个"变量编辑页";清空确认 → CupertinoAlertDialog;`Colors.orange` L414 局部标 → statusWarning;红按钮 → statusError | 🟡 |
| 21 | vector_storage_settings_screen | `l10n.vectorStorageRag` | 3/1/2 | 6 弹窗最大户:创建集合/导入集合/添加文档 3 表单 → 各 push 子页;帮助/文档列表信息 → Sheet;删除集合确认 → CupertinoAlertDialog | 🔴 |

### 批量节奏建议
- 批 1(🟢):2/3/5/6/8/10/14/17/18/19 — 10 页,每页 15-30 分钟。
- 批 2(🟡):1/4/7/11/12/13/15/16/20 — 9 页。
- 批 3(🔴):9/21 — 2 页,每页独立 commit 且人工验收。

---

## D-T2 弹窗迁移通用规则(避免 21 页改出 21 种做法)

1. **确认类** → `showCupertinoDialog(builder: CupertinoAlertDialog(...))`,
   标题简短、正文说清后果、destructive 按钮 `isDestructiveAction: true`。
2. **单字段输入**(API Key/整数)→ `showModalBottomSheet(isScrollControlled: true)`
   + `Padding(padding: MediaQuery.viewInsets)` 让键盘顶起;圆角 14,标题 17 w600,
   输入 `CupertinoTextField`,右下"完成"主色按钮。
3. **多字段表单** → push 新子页,页内 inset-grouped 表单
   (每字段一行 KiraGroupedTile 样式,分组分组排)。
4. **帮助/说明** → 底部 Sheet,半个屏高,标题 + 正文滚动。
5. **预设选择列表** → 保留底部 Sheet,圆角 14,行分隔 separator。

---

## D-T3 英中文案与 i18n 口径

- 已有 l10n key 的标题**不改**;硬编码英文/中文标题本轮**允许留**,
  每处在代码上加 `// TODO(i18n): iOS 化阶段仅改样式,标题待补 l10n key`,
  统一 Block 结束扫一遍汇总给人类。不要顺手去大改 arb(i18n 是另一条线)。

---

## Block D 完工验收

1. `dart analyze` 绿;`rg "SwitchListTile|Switch\("` 在 settings/ 下
   只剩 Kira 内部;`rg "AlertDialog"` 只剩确认类封装;`rg "fontSize: [0-9]"`
   清零;`rg "Colors\.(red|orange|green)"` 清零(token 内部除外)。
2. 21 页每页:大标题展开/收缩、分组卡、行间分隔、CupertinoSwitch 紫色。
3. logit_bias / vector_storage 的新子页确实能 push 进去+保存生效。

**必须真机截图页**:settings主页(再)、advanced、ai_presets、regex、
vector_storage、mvu、log_view、theme_settings、statistics 深色 + 至少 3 页浅色。
