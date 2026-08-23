# Block E · 设置内全局搜索(置顶框 + overlay 直达)

> 依赖:Block C-T4(设置主页骨架) + Block D 分页清单(搜索索引的数据源)。
> 风险 🟢~🟡,结构独立,一个 commit。

---

## E-T1 扁平索引表 🔵纯新增

**目标文件(新建)**:`lib/presentation/screens/settings/settings_search_index.dart`

```dart
class SettingsIndexEntry {
  final String title;       // 显示名(中文)
  final String keywords;    // 空格分隔的中英关键词,如 '代理 proxy api key 密钥'
  final String route;       // Block B 二层化后的新路由
  final IconData icon;
}

const kSettingsIndex = <SettingsIndexEntry>[
  SettingsIndexEntry(title: '主题', keywords: '主题 theme 深色 浅色 外观',
      route: '/settings/appearance/theme', icon: CupertinoIcons.paintbrush),
  SettingsIndexEntry(title: '聊天背景', keywords: '背景 壁纸 background 图片',
      route: '/settings/appearance/background', icon: CupertinoIcons.photo),
  // ... 按 Block D 21 页 + C-T4 主页 6 组全量登记,预计 ~25 条
];
```

- 数据**手工登记**(不反射), Block D 每页完工即补其 entry。
- `keywords` 必须含:中文名、英文名、常见同义(用户打"密匙"也要命中
  api-key——把"密钥 密匙 key 钥匙"都写上)。

**风险** 🟢。**验证**:`dart analyze`。

---

## E-T2 搜索 overlay + CupertinoSearchTextField 🟡

**目标文件**:`lib/presentation/screens/settings/settings_screen.dart`(改)

### 改动
1. 大标题下第一 sliver 处的搜索框( C-T4 占位)**功能落地**:
   - 实现换 `CupertinoSearchTextField`(iOS 原生控件,含麦克风图标语义,
     不需要麦克风就不 enabled)。
   - onChanged:把查询写到本地 state `_query`。
2. **结果区置换**:当 `_query.isNotEmpty` 时,内容 slivers 不再是 6 组,
   而是一个 `SliverList` 渲染过滤后的 `kSettingsIndex`:
   - 过滤规则:`title.contains(q) || keywords.toLowerCase().contains(q.toLowerCase())`;
   - 每条 `KiraGroupedTile`:icon(圆形浅紫底)、title、副标题=所属组名,
     trailing chevron;
   - 点击 `context.push(entry.route)`,**搜出来进去返回后应回到有 query 的
     设置主页**(state 保留即可,别在返回时清 query)。
3. 空结果态:`SliverFillRemaining(Center(Text('无“xx”相关设置', style: tertiary)))`。
4. 键盘:搜索框聚焦时下方内容不能顶出 overflow——结果区本身是 sliver,
   天然可滚;但 `Scaffold(resizeToAvoidBottomInset:)` 保持默认 true,不额外设。

### 不做的事(防止超范围)
- 不做全局搜索(角色/聊天记录不在本 Block);
- 不做拼音分词/模糊匹配;`contains` 足够。
- 不做搜索历史。

**风险** 🟡(设置主页 build 二元分支,逻辑要隔离清楚)。
**验证**:`dart analyze`;输入"代理""key""背景""tts"各应命中;
空结果页不炸;返回保留 query。

---

## E-T3 索引表覆盖审计 🟢

- `rg "SettingsIndexEntry"` 数条数,目标 ≥ 24;
- 与人类确认:要不要把"主页壁纸/音乐"放进索引(是,放);
- 路由打通测试:脚本式手点——每个 entry 跳一次(或写 debug 用
  一键遍历页,【可选,费 30 分钟,不做也可】)。

---

## Block E 完工验收

1. `dart analyze` 绿。
2. 设置主页搜"key"能出 APIKey 相关项(如果有 entry)。
3. 搜"背景"出"聊天背景"和"主页外观"。
4. 返回时 query 保留。

**必须真机截图页**:设置主页搜索中(有结果)、搜索中(无结果)。
