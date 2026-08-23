# 操作手册_iOS · 总入口

> 阶段二交付物全集。阶段三(12-20h 全量重写)按本目录施工。
> 基础规则:只按手册执行,不现场发明;iOS 规范引用见宪法 v2 与阶段一报告。

## 读法顺序

| 序 | 文档 | 用途 |
|---|---|---|
| 0 | `00_iOS化设计宪法v2.md` | **最高法**。色/字/圆角/动效/结构范式 + 与宪法 v1 的映射 |
| 1 | `BlockA_地基.md` | tokens/主题/KiraPressable/KiraSection inset-grouped/CupertinoSwitch/glass |
| 2 | `BlockB_导航外壳.md` | AppShell + 毛玻璃底栏 + push 转场 + 设置路由二层化 |
| 3 | `BlockC_主导航4页.md` | 角色/聊天回忆/AI/设置主页 Large Title 化(含 C-T0 通用模板) |
| 4 | `BlockD_设置族21页.md` | D-T0 批量模板 + D-T1 逐页工单 + D-T2 弹窗三分类 |
| 5 | `BlockE_设置内搜索.md` | 扁平索引 + CupertinoSearchTextField + overlay 直达 |
| 6 | `BlockF_Core仪表盘.md` | 阶段一盲区 2:不削仪表盘,健康/电池 App 手法强化 |
| 7 | `BlockG_ai_config.md` | 阶段一盲区 1:先清 600 行死代码,再统一外壳与 4 个兄弟页 |
| ★ | `契约与冲突面表.md` | 文件归属 + 跨块 API 契约 + 10 大已知冲突解法 |
| ★ | `阶段三挂机注意事项.md` | 突发规则 + 新"视觉验收"层 + 回退节 |

## 已锁方向(不再动摇)

1. 色板 = B 方案(iOS 骨架 + 星海皮肤):近黑带微蓝 `#0B0B12` 底,白文字+透明度分层,
   半透明分隔线,层级靠三级灰差,无阴影。
2. 全量范围:搜索/路由重组/全部子页/Core/ai_config 全拿。
3. Large Title 用 Material `SliverAppBar.large`,不强转 Cupertino;
   Switch/SearchTextField/ActionSheet 单点 Cupertino 化。

## 两盲区的处理结论(速览)

- **ai_config**:5 文件页面清单与痛点已纳入 Block G;
  ai_config_screen 存在约 600 行死代码,先删再改。
- **Core 仪表盘**:Block F 专项——环形图加粗至 8pt/64px、曲线换 easeOutBack
  (iOS 健身闭环感)、状态色收编 token、Hero 卡加法定的单一柔光,
  **不**做"分组卡化"降级。

## 风险地图(速览)

- 🔴:B-T3 路由二层化、D 批 3(logit_bias/vector_storage 新子页)、G-T1。
- 🟡:A-T1 级联、A-T4 KiraSection 语义变化、C-T1 角色页双 AppBar 并进 sliver、
  G-T2 model_detection 渐变映射。
- 🟢:其余。

## 监控与回退

- 每 Task commit,每 Block 打 tag(`ios-block-a`…`ios-block-g`);
- 结构重做 Block(B/C/D)完工**必须暂停**交真机截图给人类;
- dart analyze 只扛编译,视觉对不对全靠 §挂机注意事项 2.1 截图清单。
