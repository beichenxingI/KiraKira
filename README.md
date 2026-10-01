# KiraKira

⚠️ 本项目处于Beta阶段，部分功能可能与描述存在差异。

<p align="center">
  <a href="README.md">简体中文</a> | <a href="README.en.md">English</a>
</p>

一个原生跨平台 AI 聊天客户端（iOS/Android），基于 [NativeTavern](https://github.com/Bahamutho/NativeTavern) 开发，完全兼容 SillyTavern 数据格式。

## 截图

<p align="center">
  <img src="photo/set.png" width="200" alt="设置界面"/>
  <img src="photo/Character.png" width="200" alt="角色界面"/>
  <img src="photo/AiConfig.png" width="200" alt="AI配置"/>
</p>

<p align="center">
  <img src="photo/AIPreset.png" width="200" alt="AI预设"/>
  <img src="photo/PromptManager.png" width="200" alt="提示词管理"/>
  <img src="photo/Wordbook.png" width="200" alt="世界信息/知识库"/>
</p>

| 聊天 | 角色 | AI配置 |
|:---:|:---:|:---:|
| 实时流式聊天，支持消息操作 | 角色卡片，包含头像和详情 | 多提供商LLM配置 |

| AI预设 | 提示词管理 | 世界信息 |
|:---:|:---:|:---:|
| 导入SillyTavern预设 | 自定义提示词排序 | 基于关键词的上下文注入 |

## 主要功能

### 核心功能
- 📱 **原生应用** - 使用 Flutter 构建，支持 iOS 和 Android
- 🤖 **多提供商支持** - OpenAI、Claude、OpenRouter、Gemini、Ollama、KoboldCpp
- 📦 **SillyTavern 兼容** - 导入/导出 PNG 卡片、CharX、JSON 格式
- 💬 **流式响应** - 支持 SSE 实时流式传输

### Chronicle 超级记忆系统
一个针对长会话失忆和关系混乱问题的实验性解决方案。系统会自动总结对话历史，将内容分层注入到上下文中（冷区/温区/热区/未总结区），并通过向量检索和关键词混合召回相关信息。

- 📝 **自动总结** - 按轮次自动总结对话内容
- 🔍 **智能召回** - 向量语义检索 + 关键词匹配
- 📊 **分层注入** - 根据时间远近分配注意力权重
- 🧠 **实体追踪** - 追踪角色、关系、情绪变化
- 📈 **可视化面板** - 实时查看总结进度和工作状态

### 角色管理
- 📥 **导入格式** - PNG V2/V3、CharX（V3规范）、JSON
- 📤 **导出格式** - PNG V3、带资源的 CharX、JSON
- ✏️ **角色编辑器** - 完整的角色字段编辑
- 🏷️ **标签系统** - 使用标签分类和过滤角色
- 📚 **嵌入式知识库** - 完整的 CharX 知识库支持

### 聊天功能
- 💬 **消息操作** - 编辑、删除、重新生成、在备选项之间滑动
- 🔖 **书签** - 创建检查点和分支对话
- 📝 **作者注释** - 可配置深度的注入
- 🎭 **人设** - 用户档案管理
- 📄 **富文本** - HTML/Markdown 渲染

### 世界信息/知识库
- 🌍 **关键词匹配** - 基于触发器的上下文注入
- 📍 **多个位置** - 系统提示前/后、角色定义、示例对话
- 🔄 **递归支持** - 嵌套关键词扫描
- 📊 **分组评分** - 基于优先级的条目选择

### 提示词管理
- 📋 **提示词排序** - 自定义提示词顺序
- 📥 **预设导入** - 完整支持 SillyTavern 预设
- 🎯 **自定义提示词** - 添加带角色支持的自定义部分
- 📍 **深度注入** - 在特定消息深度插入提示词

### 高级设置
- 🎛️ **采样器控制** - Temperature、Top-P、Top-K、Min-P、Typical-P
- 🔁 **重复惩罚** - 可配置范围
- 🎲 **Mirostat** - Mode、Tau、Eta 设置
- ✂️ **无尾采样** - TFS 和 Top-A 支持
- 🛑 **停止序列** - 自定义停止标记

### 主题
- 🎨 **深色与浅色主题，追求简约风格/


### 思维链支持
- 🧠 **OpenAI o1/o3** - 解析 `reasoning_content` 字段
- 💭 **Claude** - 解析 `thinking` 块
- 🤔 **Gemini 2.0 Flash Thinking** - 解析 `thought` 字段
- 📦 **可折叠UI** - 可展开的推理块
- ⏳ **流式显示** - 实时推理内容

### 文字转语音（TTS）
- 🔊 **多种提供商** - 系统TTS、ElevenLabs、Azure
- 🎭 **角色语音** - 每个角色独立配置
- ▶️ **自动播放** - 自动朗读新消息
- 🎚️ **语音控制** - 速度、音调、音量调节

### 语音转文字（STT）
- 🎤 **语音输入** - 使用语音口述消息
- 🌍 **16种语言** - 支持主要语言
- 🔄 **多种提供商** - 系统STT、Whisper、Azure
- ⚡ **自动发送** - 说完后自动发送

### 翻译
- 🌐 **30+种语言** - 在主要语言之间翻译
- 🔄 **多种提供商** - Google、DeepL、LibreTranslate
- 🔀 **自动翻译** - 接收和发送的消息
- 🔍 **语言检测** - 自动检测源语言

### 图像生成
- 🎨 **多种提供商** - Stable Diffusion、DALL-E、ComfyUI、Automatic1111
- 📐 **尺寸预设** - 512x512、768x768、1024x1024等
- ⚙️ **生成设置** - 步数、CFG比例、采样器选择
- 🚫 **负面提示词** - 排除不需要的元素

### 正则脚本
- 🔍 **查找/替换模式** - 对消息应用正则表达式
- 📝 **脚本管理** - 创建、编辑、删除、重排序脚本
- 🎯 **应用位置** - 用户输入、AI输出、斜杠命令
- 🔄 **导入/导出** - 以JSON格式分享脚本

### 变量系统
- 🌐 **全局变量** - 应用范围的持久存储
- 💬 **本地变量** - 每个聊天的变量存储
- 📝 **变量宏** - `{{getvar}}`、`{{setvar}}`、`{{incvar}}`等
- 🔢 **类型支持** - 数字、字符串、数组、对象

### 聊天备份
- 💾 **自动备份** - 可配置间隔（每小时、每天、每周）
- 📁 **聊天备份** - 单独聊天导出（JSONL）
- 📦 **完整备份** - 完整数据导出（JSON）
- 👁️ **查看/恢复** - 浏览和恢复备份

### 宏系统
支持常用宏，包括：
- `{{user}}`、`{{char}}` - 人设和角色名称
- `{{time}}`、`{{date}}`、`{{day}}` - 日期时间
- `{{random:min:max}}` - 随机数生成
- `{{roll:XdY}}` - 掷骰子
- `{{idle_duration}}` - 距上次消息的时间

### 斜杠命令
- `/continue` - 继续生成
- `/regenerate` - 重新生成最后一条消息
- `/swipe` - 导航滑动
- `/persona` - 切换人设
- `/sys` - 发送系统消息
- `/help` - 显示命令帮助

### 其他功能
- 🖼️ **自定义背景** - 为每个聊天设置背景图片
- ⌨️ **Markdown快捷键** - ⌘B 粗体、⌘I 斜体、⌘U 下划线
- 🔗 **链接支持** - ⌘K 快速插入链接

## 技术栈

| 组件 | 技术 |
|-----------|------------|
| UI框架 | Flutter (Dart) |
| 状态管理 | Riverpod |
| 导航 | go_router |
| 数据库 | SQLite (drift) |
| HTTP客户端 | Dio |

## 开始使用

### 前置要求
- Flutter SDK >= 3.16.0
- Xcode（用于 iOS 开发）
- Android Studio（用于 Android 开发）

### 安装

1. 克隆仓库
   ```bash
   git clone https://github.com/beichenxingI/KiraKira.git
   cd KiraKira
   ```

2. 安装依赖
   ```bash
   flutter pub get
   ```

3. 运行应用
   ```bash
   flutter run
   ```

## SillyTavern 兼容性

### 支持的导入格式

| 格式 | 描述 | 状态 |
|--------|-------------|--------|
| PNG V2 | 带有 `chara` tEXt 块的角色卡片 | ✅ 支持 |
| PNG V3 | 带有 `ccv3` tEXt 块的角色卡片 | ✅ 支持 |
| CharX | 包含 card.json + 资源的 ZIP 归档 | ✅ 支持 |
| JSON | 原始角色 JSON 导出 | ✅ 支持 |
| ST预设 | SillyTavern AI 预设 JSON | ✅ 支持 |

### 支持的导出格式

| 格式 | 描述 | 状态 |
|--------|-------------|--------|
| PNG V3 | 导出为带有嵌入元数据的 PNG | ✅ 支持 |
| CharX | 导出包含所有资源 | ✅ 支持 |
| JSON | 原始导出用于备份 | ✅ 支持 |

## 许可证

本项目采用 AGPL-3.0 许可证 - 详见 [LICENSE](LICENSE) 文件。

## 致谢

- [NativeTavern](https://github.com/Bahamutho/NativeTavern) - 本项目基于 NativeTavern 开发
- [SillyTavern](https://github.com/SillyTavern/SillyTavern) - 提供了功能设计的参考
- [Flutter](https://flutter.dev) - 跨平台 UI 框架
- [Riverpod](https://riverpod.dev) - 状态管理库

## 问题反馈

遇到问题或有建议？欢迎在 [GitHub Issues](https://github.com/beichenxingI/KiraKira/issues) 提交。