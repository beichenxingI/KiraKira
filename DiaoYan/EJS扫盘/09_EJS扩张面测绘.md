# 09 · EJS 扩张面测绘(提示词侧之外)

> 调查 B · 零业务改动。探针 commit:`e916272`(EVT-REG/EVT-3/TPL-1,零新增 emit)。
> 显示域已移交调查 C,本报告不评估。基线:EJS 提示词侧端到端通关(zis/CF-OK-SYS/CF-OK-WI)。

---

## Q1 · 三个 emit 逐项风险定价

前置事实:facade eventEmit 为**全桶广播**(单 try/catch 包每个 listener,单个抛错不断链);无法按来源摘除特定监听器(MVU 注册的函数引用拿不到)。

### ① GENERATION_AFTER_COMMANDS —— 结论:不做
| 维度 | 内容 |
|---|---|
| dist 监听 | **两个**:Mv(往 extension_settings.regex 注入剥 EJS 正则——stub 无 regex 字段,**必抛 TypeError**,靠桶级 catch 吞掉留异常日志)+ Nv(generate-before dry-run:翻 `ym.isInPlace/Pv/Ov/Cv` 全局状态机) |
| MVU 是否监听 | 静态判断大概率否(MVU 用 generation_started/message_received)——EVT-REG 差集一锤定音 |
| 解锁能力 | **零渲染**。渲染钩子在 settings_ready/generate_after_data,这个事件只让 dist 进入"生成中"状态 |
| 风险 | 🟡 中:状态污染(dry-run 副作用残留)+ 必现异常噪音;对 MVU 零新增点火面 |
| 撤退 | 单点删 emit 行即回滚 |

### ② CHAT_COMPLETION_SETTINGS_READY —— 结论:不做,冻结至直调失效
| 维度 | 内容 |
|---|---|
| dist 监听 | Uv:`e.messages = await Lv(e.messages)`——**原地改写传入对象**,对象必须活在引擎房 realm |
| MVU 重叠 | 若 MVU 也监听同名事件,拿到同一引用会被一起改写(喂渲染后文本/触发未知分支)——EVT-2 确认前按"有重叠"保守定价 |
| 解锁能力 | 上游完整管线(WI preload/decorator/消息级渲染)。**但直调 evalTemplate 已端到端通关,边际收益 ≈ 0**;且要把 messages 数组搬进引擎房再搬回(realm 序列化往返),纯架构倒退 |
| 风险 | 🔴 高:Lv→ie/Hf/sandbox(kv) 全链首跑深水区;与 MVU 的重叠面未证清 |
| 撤退 | 删 emit + 回直调(直调代码保留着) |

### ③ CHARACTER_MESSAGE_RENDERED —— 结论:现在不做,定价移交调查 C
| 维度 | 内容 |
|---|---|
| dist 监听 | Bv(makeFirst):显示渲染,核心调用 updateMessageBlock(**空桩**)→ emit 了也只是空转;附带的 Nm 变量克隆有 `variables_initialized` 幂等标记,Vv(message_received)路径已在跑 |
| MVU 重叠 | 大概率否;Bv 自身幂等 |
| 解锁能力 | 现在为零(显示空桩);调查 C 做 iframe 显示架构时才可能有意义 |
| 风险 | 🟢 低 |
| 撤退 | 单点删除 |

**定向派发可行性**:三方案全否——假事件名(dist 听不到=白接)/摘 MVU 监听器(引用不可得)/分桶改造(动 facade 核心,X1 雷区)。**替代结论:直调 evalTemplate 本身就是终极定向,无需任何 emit。**

## Q2 · eventSource 优先级语义

【实证】`eventMakeFirst`=unshift、`eventMakeLast`=push、`eventEmit` 按桶数组序同步执行 → **单事件桶内是真优先级排序,不是纯转发**;与上游 ST 单 eventSource 同构。注意两点:
1. MVU 与 dist **共桶**:执行顺序 = 注册序 + makeFirst/makeLast 插队指令交织。注入顺序是 MVU module 先、dist 后,故 MVU 监听器天然排在前面,除非 dist 用 makeFirst 抢(仅 CHARACTER_MESSAGE_RENDERED 一处)。
2. "EJS 必须排在 MVU 之前"的上游前提在我们这里**不成立也不需要**——我们走直调,不经事件总线。
**补课成本:零(已是真排序)。真正的缺口是跨脚本隔离,而非排序;隔离无需求就不做。**

## Q3 · setvar 落库

| 层 | 上游 | 我们 |
|---|---|---|
| 写入目标 | cacheVars(setter 疑似写回 chat_metadata/chat[].variables + saveSettingsDebounced)**【黑盒,TPL-1 后可验】** | 模板写 → 镜像三层;**镜像→DB 无自动回灌(A 轮实证)** |
| 显式持久化 | saveVariables(Sm) | updateVariablesWith/setVariables(th_setVars) |

- **桥缺段**:「模板内 setvar → 自动落库」这一段我们没有,当前行为=请求内可见、重启即失。
- **冲突分析**:若打通自动落库,EJS(chat/global 层,insertOrAssign 浅合并)与 MVU(message 层,replaceVariables 整份替换)分层写入则互不覆盖;若都碰 message 层,**MVU 后写必胜**(message_received 在 prompt-out 之后),EJS 写入会被整份替换吞掉。
- **时序/优先级建议**:维持现状(EJS 写=镜像态)为安全默认;未来若要持久化,**限定 chat/global 层走 th_setVars,禁止写 message 层**,即可与 MVU 无冲突共存。

## Q4 · Ancestor / Scope 差距

**Ancestor(findLastIndex 向上找变量)**:
- 宿主侧已对齐:MVU 自行遍历 `messages.variables(swipes_data)` 从末尾回溯(isMvuData 要求 stat_data+schema),宿主兜底基座也按 swipeId 落——结构 ✅。
- **差距在 EJS 读侧**:kick 快照只灌「最后一条消息的当前 swipe」→ 模板 `getvar` 读不到历史楼层/其它 swipe 的变量。修法(未做):快照扩为全量楼层×swipe,代价 O(n) 注入体积。

**Scope 四要素对照**:
| 要素 | 上游 | 我们 | 差距 |
|---|---|---|---|
| type(chat/global/message) | ✓ | facade ✓ 三层 | 无 |
| message_id(latest/负数) | ✓ | `__resolveMid` ✓ | 无 |
| index(键/序号切片) | ✓ | Flutter 宏侧 ✓(VariablesService index);WebView getVariables ❌ | WebView 侧无 index 切片 |
| merge | insertOrAssign=浅写;updateVariablesWith=updater | 同名同语义(Object.assign 浅写)✓ | 无实质差距 |
| flags | 【黑盒】 | 未实现 | 待 TPL-1/上游源码核对 |

## Q5 · 模板作用域函数面(静态已知部分,TPL-1 补全)

Hf 已实证挂载:`variables(getter)`、`execute(slash)`、`SillyTavern.getContext()`、`faker`、`userName/assistantName/charName`、`chatId`、`characterId`、`charAvatar/userAvatar(fn)`、`groups/groupId`、`charLoreBook/userLoreBook/chatLoreBook`;另有 qf 基座展开(getvar/setvar 族应在此,**以 TPL-1 dump 为准**)。

| 作用域成员 | 我们的支撑 | 高星卡常用度 |
|---|---|---|
| getvar/setvar 族(qf) | 镜像读写 ✅(getvar 实测通) | ★★★ |
| execute(/slash) | **空桩**(返 {},非管道)→ 模板内命令静默无效 | ★★☆ |
| SillyTavern.getContext() | 骨架(saveChat/saveMetadata/reloadCurrentChat 空 resolve) | ★★☆ |
| faker | 递归代理(任意调用返回 '') | ★☆☆ |
| name1/name2/charName 等 | ✅ 真 | ★★★ |
| chatId | ✅ 真 | ★★☆ |
| charLoreBook | undefined(characters=[] 链断) | ★☆☆ |
| userLoreBook | undefined(power_user={}) | ☆☆☆ |
| groups/groupId | 空 | ☆☆☆ |
| charAvatar/userAvatar | '' | ★☆☆ |
| (qf 其余) | **TPL-1 dump 后回填本表** | ? |

## Q6 · 三个空桩的真实需求

| 桩 | 上游语义 | 不实现的后果 | 实现代价 | 依赖 emit |
|---|---|---|---|---|
| getRegexedString | 按 regex_scripts 对文本跑正则(placement 过滤) | dist 内部调用=原样返回。**更大的真差距在宿主侧**:buildMessages 不跑 promptOnly 正则(RegexService 有 isPrompt 参数但组装链没用)——带 promptOnly 正则的高星卡提示词侧静默失效 | 低-中(Dart 组装后过一遍 isPrompt:true) | 无 |
| loadWorldInfo | WI 装饰器/递归激活引擎;dist 的 Rv(CHAT_CHANGED 预演,已在跑)用它评估 preload 条目 | 返 null → 预演静默无效;**initvar 主路径不受影响**(MVU 走 getLorebookEntries);递归激活类高级卡受损 | 大(ST world-info 子集) | 无(CHAT_CHANGED 已在发) |
| SlashCommand 执行期 | executeSlashCommandsWithOptions 管道;Hf.execute 包装给模板 | 模板内 `/send`//trigger 静默无效;开场白按钮类卡常见 | 中:桥接 Flutter 侧现成 slash_command_service 进引擎房,或引擎房实现子集 | 无(直调可达) |

## 探针操作说明(commit e916272)

进聊天发一条含 `<% %>` 的消息,然后 grep `-E "EVT-REG|EVT-3|TPL-1"`:
1. **EVT-REG 序列**:按注册时间排列的 type/bucket 清单。已知 dist 注册集 = {chat_changed(makeLast), generation_after_commands×2, worldinfo_updated, generate_after_data, chatcompletion_settings_ready, message_updated, message_swiped, user_message_rendered, character_message_rendered(makeFirst), js_generation_before_end, message_sent, message_received, message_swipe_deleted, settings_loaded, settings_updated} —— **序列中出现而此集没有的 = MVU 的监听面**(这就是 EVT-2,差集法)。
2. **TPL-1**:一次性 scope keys 全量 dump(type 标注),回填 Q5 矩阵。
3. **EVT-3**:每次 emit 的 listeners 数与执行序(现有 [emit] 行给出 per-listener 细节)。
4. 把三段输出贴回,即可定稿 Q1 重叠面终判与 Q5 完整矩阵。

## 建议实施顺序

| 级别 | 项 | 说明 |
|---|---|---|
| 🟢 | promptOnly 正则接入 buildMessages | 复用现成 RegexService(isPrompt:true),补提示词侧正则缺口,独立无依赖 |
| 🟢 | EJS setvar 显式持久化开关 | 限定 chat/global 层走 th_setVars,禁 message 层(与 MVU 无冲突,Q3 结论) |
| 🟢 | EVT/TPL 探针数据回收 | 人类跑一轮贴日志,定稿重叠面+函数面 |
| 🟡 | SlashCommand 执行期 | 桥 slash_command_service 进引擎房;需人类确认高星卡需求优先级 |
| 🟡 | Ancestor 全量快照 | 历史楼层变量灌镜像;体积换能力 |
| 🔴 | 三个 emit | 定价完毕:**全部不做**(①零收益 ②架构倒退 ③归调查 C) |
| 🔴 | loadWorldInfo 引擎 | 收益窄代价大,建议放弃;出现具体卡案例再驱动 |
| 🔴 | 显示域渲染(Bv/CHARACTER_MESSAGE_RENDERED 相关) | 移交调查 C |
