# KiraKira EJS 渲染完整链路数据流图

## 概览

本文档记录 EJS 渲染在三条核心路径上的数据流向：
1. **发送消息路径**：`chat_providers.sendMessage` → `llm_service._renderEJSInMessages` → 引擎房 `substituteParams`
2. **展示消息路径**：`webview_chat_stage._serializeMessage` → `setMessages` → DOM/iframe 渲染（缺失 EJS）
3. **引擎房内部**：`dist/index.js` / `ejs_stub.js` / `ejs_bundle.js` / `tavern_helper_facade.dart`

---

## 1. Mermaid 数据流图

```mermaid
flowchart TD
    %% ===== 颜色图例 =====
    classDef green fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;  %% 有 EJS 渲染
    classDef red fill:#ffebee,stroke:#c62828,stroke-width:2px;    %% 缺失 EJS 渲染
    classDef yellow fill:#fff8e1,stroke:#f57f17,stroke-width:2px;  %% 假实现/存根
    classDef blue fill:#e3f2fd,stroke:#1565c0,stroke-width:2px;   %% 正常数据流

    %% ===== 发送消息路径 (绿色: 有 EJS) =====
    SendUser[用户发送消息] --> ChatProvider[chat_providers.sendMessage]
    ChatProvider --> BuildContext[_buildContext 构建上下文]
    BuildContext --> PromptMgr[PromptManager 组装 sections]
    BuildContext --> WorldInfo[WorldInfoMatcher 注入世界书]
    BuildContext --> MacroSvc[MacroService.process 宏替换]
    BuildContext --> VarSvc[VariablesService 变量宏]
    BuildContext --> RAG[RAG 向量检索]
    BuildContext --> Summary[ChatSummarizationService 摘要]
    BuildContext --> ContextMsg[完整 messages 数组]
    
    ContextMsg --> LLMService[LLMService.generateStreamWithReasoning]
    LLMService --> RenderEJS[_renderEJSInMessages]
    RenderEJS -->|遍历每条 message| EJSRenderer[RegistryEJSRenderer.render]
    EJSRenderer -->|ejsRenderRegistry.current| WVLambda[WebViewChatStage._handleRenderEJS]
    WVLambda -->|ChatBridge.onRequest th_renderEJS| JSSubstitute[JS window._TH.substituteParams]
    JSSubstitute -->|EJS Bundle/Stub| EJSEngine[EJS 引擎执行]
    EJSEngine -->|渲染后内容| RenderedMsg[渲染后 messages]
    RenderedMsg --> ProviderAPI[具体 Provider API 调用]
    
    %% ===== 展示消息路径 (红色: 缺失 EJS) =====
    LoadChat[加载聊天/消息变更] --> WVListen[WebViewChatStage ref.listen]
    WVListen --> PushMsg[_pushMessages / _appendNewMessages]
    PushMsg --> SerializeMsg[_serializeMessage]
    SerializeMsg --> RegexSvc[RegexService.getRegexedString]
    SerializeMsg --> Markdown[markdownToHtml]
    SerializeMsg --> Attachments[_buildAttachmentsHtml]
    SerializeMsg --> SerializedMap[序列化 Map{html, prose, ...}]
    SerializedMap --> Base64[base64Encode JSON]
    Base64 --> BridgeSend[ChatBridge.send setMessages]
    BridgeSend --> JSSetMsg[JS setMessages]
    JSSetMsg -->|富文本| CreateIFrame[创建 iframe.card-frame]
    JSSetMsg -->|普通文本| DirectHTML[innerHTML 直渲]
    CreateIFrame --> InjectBridge[injectBridge]
    InjectBridge -->|内联桥接脚本| CardIFrame[卡片 iframe]
    CardIFrame -->|无 EJS 调用| DirectRender[直接 innerHTML]
    
    %% ===== 引擎房组件 =====
    EngineRoom[引擎房 iframe] --> FacadeJS[__ENGINE_FACADE_JS<br/>tavern_helper_facade.dart]
    EngineRoom --> MVUBundle[__KIRA_MVU_BUNDLE<br/>mvu_bundle.js]
    EngineRoom --> EJSBundle[__KIRA_EJS_BUNDLE<br/>ejs_bundle.js]
    EngineRoom --> EJSStub[__KIRA_EJS_STUB<br/>ejs_stub.js]
    EngineRoom --> Libs[__KIRA_LIBS<br/>jq/lodash/toastr]
    EngineRoom --> Trinity[Trinity 初始化<br/>chat/chat_metadata/extension_settings]
    
    FacadeJS --> TH[window._TH TavernHelper]
    TH --> SubstParams[substituteParams 函数]
    SubstParams -->|仅宏替换| MacroOnly[{{user}}/{{char}} 替换]
    SubstParams -.->|应有 EJS 控制流| MissingEJSControl[🔴 缺失: <% %> 控制流]
    
    EJSBundle -.->|应导出 substituteParams| EJSExport[substituteParams 导出?]
    EJSExport -->|有导出| RealEJS[真 EJS 渲染]
    EJSExport -.->|无导出/加载失败| FallbackStub[回退 Stub 版]
    
    EJSStub --> StubSubst[export substituteParams<br/>仅宏替换]
    EJSStub --> StubRegex[getRegexedString 原样返回]
    EJSStub --> StubWI[loadWorldInfo 返回 null]
    EJSStub --> StubYAML[yaml load/dump 空对象]
    
    MVUBundle --> MVUGenerate[generate 空桩<br/>Promise.resolve("")]
    MVUBundle --> MVURegister[registerAsUniqueScript]
    MVUBundle --> MVUInitCheck[initCheck 选主逻辑]
    
    %% ===== 问候语/开场白路径 (红色: 完全无 EJS) =====
    CreateChat[createChat 创建聊天] --> GreetingMacro[MacroService.process 开场白]
    GreetingMacro --> SaveGreeting[存入 ChatMessage.content/swipes]
    SaveGreeting -.->|无 EJS 渲染| GreetingMissing[🔴 缺失: 开场白不走 EJS]
    
    %% ===== 样式 =====
    class SendUser,ChatProvider,BuildContext,PromptMgr,WorldInfo,MacroSvc,VarSvc,RAG,Summary,ContextMsg,LLMService,RenderEJS,EJSRenderer,WVLambda,JSSubstitute,EJSEngine,RenderedMsg,ProviderAPI green;
    class LoadChat,WVListen,PushMsg,SerializeMsg,RegexSvc,Markdown,Attachments,SerializedMap,Base64,BridgeSend,JSSetMsg,CreateIFrame,DirectHTML,InjectBridge,CardIFrame,DirectRender red;
    class EngineRoom,FacadeJS,MVUBundle,EJSBundle,EJSStub,Libs,Trinity,TH,SubstParams,MacroOnly,StubSubst,StubRegex,StubWI,StubYAML,MVUGenerate,MVURegister,MVUInitCheck yellow;
    class MissingEJSControl,EJSExport,RealEJS,FallbackStub,GreetingMacro,SaveGreeting,GreetingMissing red;
```

---

## 2. 三条路径对比表

| 维度 | 发送消息路径 (LLM 侧) | 展示消息路径 (UI 侧) | 开场白/问候语路径 |
|------|----------------------|---------------------|------------------|
| **入口** | `chat_providers.sendMessage` → `_buildContext` | `ActiveChatProvider.messages` 变化 → `ref.listen` → `_pushMessages` | `chat_providers.createChat` |
| **EJS 渲染** | ✅ **完整**：`_renderEJSInMessages` → `RegistryEJSRenderer` → `_handleRenderEJS` → `window._TH.substituteParams` | ❌ **完全缺失**：`_serializeMessage` 只做正则+Markdown，无 EJS 调用 | ❌ **完全缺失**：仅 `MacroService.process` 宏替换 |
| **数据流向** | Dart messages → EJS渲染 → 渲染后 messages → LLM API | 数据库 messages → 序列化 → base64 → JS setMessages → DOM/iframe | 角色 first_message → 宏替换 → 存数据库 → 正常展示路径 |
| **引擎房参与** | 是：通过 ChatBridge 请求引擎房 `substituteParams` | 否：JS 侧直接渲染，iframe 走 `injectBridge` 但不调用 EJS | 否 |
| **结果** | LLM 见到完整渲染后的提示词 (含 `<% %>` 控制流) | 用户见到**未渲染**的原始 EJS 语法 (若消息含模板) | 用户见到仅宏替换的开场白，EJS 模板原样显示 |

---

## 3. 发送消息路径详细数据流 (绿色 ✅)

```
┌─────────────────────────────────────────────────────────────────────┐
│ 1. chat_providers.dart: sendMessage()                              │
│    └─> _buildContext() 返回 List<Map<String, dynamic>> messages    │
│         包含: system prompt, persona, character desc, chat history │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 2. llm_service.dart: generateStreamWithReasoning() / generate()   │
│    └─> _renderEJSInMessages(messages)                              │
│         for msg in messages:                                       │
│           if msg.content is String:                                │
│             rendered = await _ejsRenderer.render(msg.content)      │
│             output.add({'role': msg.role, 'content': rendered})    │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 3. RegistryEJSRenderer.render(text)                                │
│    └─> ejsRenderRegistry.current (WebViewChatStage 注册的 lambda)  │
│         调用 _handleRenderEJS({text})                              │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 4. webview_chat_stage.dart: _handleRenderEJS(payload)              │
│    └─> 构造 JS: window._TH.substituteParams(text)                  │
│         通过 ChatBridge.onRequest('th_renderEJS') 发送             │
│         等待 JS 返回 Promise 结果                                  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 5. 引擎房 JS: window._TH.substituteParams(text)                    │
│    ├─ tavern_helper_facade.dart 生成的 _TH.substitudeMacros        │
│    │   └─ 仅做 {{user}}/{{char}} 宏替换 (同步)                     │
│    └─ 期望: EJS Bundle 导出的真 substituteParams                   │
│         └─ 支持 <% if %>, <%= %>, <% %> 等控制流                   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 6. 验证脚本 (createEngineRoom 内 setTimeout 1000ms)                │
│    └─ 尝试从 EJS Module 导出挂载 substituteParams                  │
│         if (ejsModule.substituteParams)                             │
│           window._TH.substituteParams = ejsModule.substituteParams │
│    └─ 失败则保留 facade 版 (仅宏替换)                               │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 4. 展示消息路径详细数据流 (红色 ❌ 缺失 EJS)

```
┌─────────────────────────────────────────────────────────────────────┐
│ 1. webview_chat_stage.dart: ref.listen(activeChatProvider)         │
│    └─> 检测消息变化 → _pushMessages() / _appendNewMessages()       │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 2. _serializeMessage(ChatMessage m, ...)                           │
│    └─> rawContent = m.content                                      │
│    └─> RegexService.getRegexedString(rawContent, placement, scripts)│
│    └─> 移除 <image> 标签                                           │
│    └─> markdownToHtml() → HTML                                     │
│    └─> 富文本检测 → 拆分 prose + bodyForRender                     │
│    └─> 返回 {html, prose, reasoning, swipeCount...}               │
│    ⚠️ 关键缺失: 无任何 EJS 渲染调用!                               │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 3. _pushMessages: base64Encode(JSON.stringify(list))               │
│    └─> ChatBridge.send(BridgeType.setMessages, {data: b64})       │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 4. JS setMessages(b64, options)                                    │
│    └─> 解析数组 → 遍历创建 DOM                                     │
│         if isRichHtml(m.html):                                     │
│           创建 iframe.card-frame                                   │
│           injectBridge(m.html, id) → iframe srcdoc                 │
│         else:                                                      │
│           innerHTML = m.html  (普通文本)                          │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 5. injectBridge(html, frameId)                                     │
│    ├─ 按需内联 jQuery/lodash/toastr                                │
│    ├─ 注入 polyfill (localStorage/sessionStorage/console)         │
│    ├─ 注入 __thCall 通信桥 (frameId 路由)                          │
│    ├─ 注入高度上报 (ResizeObserver)                                │
│    └─ ⚠️ 关键缺失: 不调用 window._TH.substituteParams(html)       │
│         卡片 HTML 直接 innerHTML，EJS 模板原样渲染                 │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 5. 引擎房组件能力矩阵

| 组件 | 来源 | `substituteParams` 能力 | 备注 |
|------|------|------------------------|------|
| **tavern_helper_facade.dart** | Dart 生成 JS 字符串 | ⚠️ **仅宏替换** `{{user}}`/`{{char}}` | `_TH.substitudeMacros` 同步函数，无 EJS 解析器 |
| **ejs_stub.js** | 静态资源 | ⚠️ **仅宏替换** (export substituteParams) | 存根实现，`getRegexedString` 原样返回，`loadWorldInfo` 返回 null |
| **ejs_bundle.js** | 静态资源 (webpack 打包) | ✅ **完整 EJS** (若正确导出) | 包含 acorn 解析器、EJS 编译器、完整运行时 |
| **mvu_bundle.js** | 静态资源 | ❌ 无 | MVU UI 框架，依赖 stub 提供 `substituteParams` |
| **验证脚本** | `createEngineRoom` 内联 | 🔧 **桥接尝试** | `setTimeout 1000ms` 尝试从 EJS Module 导出挂载到 `_TH` |

---

## 6. 关键偏差：设计意图 vs 实际实现

| 设计意图 | 实际实现 | 影响 |
|---------|---------|------|
| **统一 EJS 渲染**：所有模板字符串 (system prompt, character desc, world info, chat history, 开场白) 发给 LLM 前、展示给用户前、引擎房跑 MVU 前，统一走 `substituteParams` | **仅 LLM 发送侧走 EJS**；展示侧、开场白侧完全跳过 | 1. 用户看到原始 `<% %>` 语法<br>2. 开场白无法用 EJS 控制流<br>3. MVU 读取的 `window.chat` 内容未渲染 |
| **引擎房提供完整 `substituteParams`** | **双版本并存**：facade 版(仅宏) + EJS Bundle 版(完整，但加载不确定) | 验证脚本兜底，但存在竞态：MVU 启动时可能尚未挂载完整版 |
| **正则脚本在 EJS 前跑** | **Dart 侧 `_serializeMessage` 已跑正则**；JS 侧 `injectBridge` 的 `getRegexedString` 是存根 | 双轨制不一致：展示层已正则，引擎房/EJS 层未正则 |
| **Trinity 对象应反映真实状态** | `createEngineRoom` 初始化为空对象，靠 `chat_changed` 事件同步 | 早期 MVU 读取 `window.chat` 为空，需 `initCheck` 重跑 |

---

## 7. 缺失 EJS 渲染的具体场景 (红色清单)

| 场景 | 当前路径 | 缺失环节 | 预期修复 |
|------|---------|---------|---------|
| **角色开场白** | `createChat` → `MacroService.process` → 存 DB → `_pushMessages` → `setMessages` | 无 EJS 渲染 | `_serializeMessage` 或 `createChat` 时接入 `_handleRenderEJS` |
| **备选开场白** | 同主开场白，存 `swipes` 数组 | 无 EJS 渲染 | swipe 切换时渲染当前版本 |
| **历史消息展示** | `_pushMessages` → `_serializeMessage` → `setMessages` | 无 EJS 渲染 | `_serializeMessage` 增加 EJS 渲染步骤 |
| **世界书条目注入** | `_buildContext` → `processMacros(entry.content)` → 加入 messages | 仅宏替换，无 EJS | WorldInfo 注入前走 EJS |
| **作者注释** | `_buildContext` → `_processAuthorNoteMacros` → 加入 messages | 仅宏替换，无 EJS | 注入前走 EJS |
| **人设描述** | `_buildContext` → `processMacros(persona.description)` | 仅宏替换，无 EJS | 注入前走 EJS |
| **卡片/富文本消息** | `setMessages` → `injectBridge` → iframe `innerHTML` | 无 EJS 渲染 | `injectBridge` 调用 `substituteParams` |
| **MVU 读取消息** | `th_getMessages` → `_handleGetMessages` → 返回原始 content | 返回未渲染内容 | 返回前渲染或 MVU 侧渲染 |

---

## 8. 假实现/存根清单 (黄色清单)

| 组件 | 函数/导出 | 现状 | 风险 |
|------|-----------|------|------|
| `tavern_helper_facade.dart` | `_TH.generate` | `Promise.resolve("")` 空桩 | MVU 额外模型改走 `generateRaw` 绕过，暂无影响 |
| `tavern_helper_facade.dart` | `_TH.substitudeMacros` | 仅 `{{user}}`/`{{char}}` 替换 | 非完整 EJS，控制流不支持 |
| `ejs_stub.js` | `substituteParams` | 仅宏替换 | 作为兜底存在，EJS Bundle 未导出时生效 |
| `ejs_stub.js` | `getRegexedString` | `(s)=>s` 原样返回 | 正则引擎未接入，MVU/EJS 侧正则失效 |
| `ejs_stub.js` | `loadWorldInfo` | `async()=>null` | 世界书未接入，高星卡依赖此功能会失效 |
| `ejs_stub.js` | `yaml.load/dump` | 空对象 | 变量 YAML 解析失效，`initvar` 可能失败 |
| `ejs_stub.js` | `executeSlashCommandsWithOptions` | `async()=>({})` | Slash 命令未接入 |
| `injectBridge` | 世界书 API (`_TH.getLorebookEntries` 等) | 死代码 (注释标注已迁移) | 无实际调用，但污染命名空间 |

---

*生成时间: 2026-08-19*  
*基于代码静态分析，重点标注 EJS 渲染缺失路径 (红色) 与存根实现 (黄色)*