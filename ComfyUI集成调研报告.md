# ComfyUI 集成调研报告

> **项目**：KiraKira（Flutter AI 伴侣 App）
> **路径**：`D:\KKKK\KiraKira`
> **语言/框架**：Dart / Flutter（flutter_riverpod 2.4.9 + dio 5.4.0）
> **调研日期**：2026-09-27
> **ComfyUI 源码基准**：comfyanonymous/ComfyUI master 分支（server.py / samplers.py）
> **性质**：只读调研，未修改任何代码、未新增依赖

---

## 摘要

KiraKira 已具备一套**完整的多后端生图架构**，覆盖 8 种后端（OpenAI / OpenAI-Chat / Gemini / NovelAI / Latent.moe / A1111 / ComfyUI / Local Dream）。其中 **ComfyUI 已完整接入"配置层"**（Provider 枚举、设置页下拉框、Endpoint 配置、模型列表拉取 `_fetchComfyUIModels()`），但**生成层是占位符**——`_generateComfyUI()` 直接 `throw UnimplementedError`。

这意味着集成 ComfyUI 的**唯一核心缺口**是实现这一个方法（`image_generation_service.dart:2003-2007`），外加必要的 workflow 构建逻辑。架构的其余部分（UI 入口、状态管理、聊天自动生图、图片落盘与附件挂载）全部可复用。

ComfyUI 与现有 Latent.moe 后端模式高度相似（提交→轮询→拉图），可参照 `_generateLatentMoe()` 实现。HTTP 轮询方案**零新依赖**（dio + uuid 已有）；WebSocket 实时进度需新增 `web_socket_channel`。

---

## 第一部分：现有架构分析

### 1.1 文件清单（生图相关）

| 类型 | 文件路径 | 行号 | 关键类/函数名 | 说明 |
|------|---------|------|-------------|------|
| **Service** | `lib/domain/services/image_generation_service.dart` | 78-206 | `ImageGenProvider` | 8 后端枚举；ComfyUI 定义于 `:88`（`comfyui('comfyui','ComfyUI','http://127.0.0.1:8188')`） |
| Service | 同上 | 116-120 | `ImageGenProvider.isLocalProvider` | comfyui 属本地后端 |
| Service | 同上 | 143-149 | `ImageGenProvider.supportsFetchingModels` | comfyui=true（支持拉模型列表） |
| Service | 同上 | 152-186 | `ImageGenProvider.defaultModels` | comfyui 返回 `[]`（运行时拉取） |
| Service | 同上 | 240-510 | `ImageGenSettings` | 设置模型；per-provider Map 配置 |
| Service | 同上 | 513-555 | `ImageGenRequest` | 请求参数（prompt/size/steps/cfg/sampler/seed…） |
| Service | 同上 | 558-576 | `ImageGenResult` | 结果（`List<Uint8List> images` + imageUrls + seed） |
| Service | 同上 | 579-620 | `ImageGenSampler` | 采样器枚举（A1111 命名） |
| Service | 同上 | 622-646 | `ImageAspectRatio` | 宽高比预设 |
| Service | 同上 | 649-2203 | `ImageGenerationService` | 主服务类 |
| Service | 同上 | 654-655 | `onProgress` / `onError` | 进度/错误回调（供 UI 绑定） |
| Service | 同上 | 666-694 | `fetchModels()` | 拉取模型列表总入口（switch 分发） |
| Service | 同上 | **824-849** | **`_fetchComfyUIModels()`** | ✅ **已实现**：GET `{endpoint}/object_info/CheckpointLoaderSimple` 解析 `ckpt_name` |
| Service | 同上 | 921-926 | `extractImagePrompt()` | 从 `<image>...</image>` 标签提取 prompt（自动生图用） |
| Service | 同上 | 929-978 | `generate()` | 生成总入口（switch 分发到各后端） |
| Service | 同上 | 1562-1762 | `_generateLatentMoe()` | 异步队列模式（提交→轮询→拉图），ComfyUI 最佳参考 |
| Service | 同上 | 1820-1872 | `_generateAutomatic1111()` | 同步 POST + base64 |
| Service | 同上 | 1874-2001 | `_generateLocalDream()` | NDJSON 流式 |
| Service | 同上 | **2003-2007** | **`_generateComfyUI()`** | ❌ **占位符**：`throw UnimplementedError('ComfyUI generation requires workflow configuration')` |
| Service | 同上 | 2044-2083 | `downloadImage()` | URL→bytes 下载（ComfyUI `/view` 可直接用 dio） |
| Service | 同上 | 2144-2198 | `parseImagineCommand()` | `/imagine` 命令解析 |
| Service | 同上 | 2010-2037 | `extractImageUrls()` | 从文本提取图片 URL |
| **Provider** | `lib/presentation/providers/image_gen_providers.dart` | 9-13 | `imageGenServiceProvider` | 服务单例 Provider |
| Provider | 同上 | 16-18 | `imageGenSettingsProvider` | 设置持久化（SharedPreferences `image_gen_settings` + FlutterSecureStorage 密钥） |
| Provider | 同上 | 21-292 | `ImageGenSettingsNotifier` | 设置读写 + 迁移逻辑；密钥不落明文 |
| Provider | 同上 | 295-323 | `ImageGenState` | 生成状态（isGenerating/progress/result/error） |
| Provider | 同上 | 326-405 | `ImageGenStateNotifier` | 绑定 service.onProgress/onError → state |
| Provider | 同上 | 408-411 | `imageGenStateProvider` | 生成状态 Provider |
| Provider | 同上 | 414-418 | `generateImageProvider` | 生成函数 Provider |
| Provider | 同上 | 444-526 | `FetchedModelsNotifier` | 模型列表拉取状态（loading/models/error） |
| Provider | 同上 | 529-544 | `fetchedModelsProvider` | 仅在 provider/apiKeys/apiEndpoints 变化时重建 |
| Provider | 同上 | 547-558 | `availableModelsProvider` | 合并 fetched + default 模型 |
| **配置对话框** | `lib/presentation/dialogs/image_gen_config_dialog.dart` | 11-17 | `showImageGenConfigDialog()` | 入口函数（从 `ai_config_screen.dart:1832` 调用） |
| 配置对话框 | 同上 | 173-203 | `_buildProviderTypeSelector()` | Provider 下拉，ComfyUI 在 `:201` |
| 配置对话框 | 同上 | 215-218 | `_isCloudProvider()` | ComfyUI 非云端 |
| 配置对话框 | 同上 | 503-600 | `_buildLocalConfig()` | 本地配置；ComfyUI 走通用 else 分支（`:581-597`：Endpoint + 模型名称手动输入） |
| 配置对话框 | 同上 | 603+ | `_buildQuickParams()` | 分辨率/参数快速设置 |
| 配置对话框 | 同上 | 930+ | `_buildAdvancedSection()` | 采样器选择（`forProvider` 过滤） |
| **设置屏幕** | `lib/presentation/screens/settings/image_gen_settings_screen.dart` | 221-294 | 本地/其他提供商 | ComfyUI 在下拉 `:235/:253`；Endpoint 配置 `:264-292` |
| 设置屏幕 | 同上 | 615-618 | `_ImageGenTestWidget` | 测试生成区 |
| 设置屏幕 | 同上 | 1290-1409+ | 测试生成 build | `imageGenStateProvider` 驱动；生成在 `:1339` |
| 设置屏幕 | 同上 | 637-642 | A1111 信息 ListTile | ComfyUI 无对应提示（可扩展） |
| **聊天手动生图** | `lib/presentation/widgets/chat/image_generation_dialog.dart` | 41-48 | `ImageGenerationDialog.show()` | 静态方法打开对话框 |
| 聊天手动生图 | 同上 | 318-383 | `_generate()` | 调 `service.generate()` + 进度回调 |
| 聊天手动生图 | 同上 | 386+ | `_buildModelSelector()` | 用 `availableModelsProvider` |
| 聊天手动生图 | `lib/presentation/screens/chat/chat_images_screen.dart` | 99 | `ImageGenerationDialog.show()` | 相册入口 |
| 聊天手动生图 | `lib/presentation/screens/chat/webview_chat_stage.dart` | 6817,6858 | `_showImageGenerationDialog()` | 占位符点击打开 |
| **自动生图** | `lib/presentation/providers/chat_providers.dart` | 605 | `_maybeAutoGenerateImage` 调用 | AI 回复落库后触发 |
| 自动生图 | 同上 | 626-739 | `_maybeAutoGenerateImage()` | 自动生图主流程 |
| 自动生图 | 同上 | 640 | `extractImagePrompt()` | 提取 `<image>` 标签 |
| 自动生图 | 同上 | 686-733 | `service.generate()` + 附件挂载 | 写文件 `chat_images/{chatId}/ai_auto_{msg.id}_N.png` |
| 自动生图 | 同上 | 758-870 | `_extractVisualTags()` | 二次 LLM 提炼视觉标签 |
| 自动生图 | 同上 | 1486-1580 | `regenerateAutoImage()` | 重新生成（先成功再替换） |
| 自动生图 | 同上 | 1584-1599 | `_buildContext()` 注入 `<image>` 指令 | 教 AI 输出视觉标签 |
| **路由** | `lib/presentation/router/app_router.dart` | 16, 284 | `ImageGenSettingsScreen` | iOS push 注册 |
| **Android 网络** | `android/app/src/main/res/xml/network_security_config.xml` | 1 | cleartext 配置 | ⚠️ **仅允许 `localhost`/`127.0.0.1` 明文**；局域网 IP（如 192.168.x.x）会被阻止 |

### 1.2 调用链流程图

#### 路径 A：手动生图（聊天）

```
用户点占位符 (webview_chat_stage.dart:6817)
  或相册"+" (chat_images_screen.dart:99)
    → ImageGenerationDialog.show() (image_generation_dialog.dart:41)
    → 填 prompt + 参数 → _generate() (image_generation_dialog.dart:318)
      → service.generate(ImageGenRequest) (image_generation_service.dart:929)
        → switch(_settings.provider) (946-964)
          → _generateXXX(request)  // ComfyUI → _generateComfyUI (2003) ❌
      → onProgress 回调 → setState 进度条
      → ImageGenResult.images[0] → 预览 → 用户点保存 → pop(result)
```

#### 路径 B：自动生图（聊天）

```
AI 回复落库 → _maybeAutoGenerateImage(msg, config) (chat_providers.dart:605/628)
  → 检查 autoImageMode (631)
    off    → return
    promptOnly → 仅提取标签，不出图 (668)
    auto   → 继续
  → extractImagePrompt(msg.content) (640)  // <image> 标签
  → (可选) _extractVisualTags 调 LLM 提炼 (659)
  → 防重生检查 (670-678)
  → state.isGeneratingImage = true (681)
  → service.onProgress = 回调 (688)
  → service.generate(ImageGenRequest) (697)
  → 成功 → 写文件 chat_images/{chatId}/ai_auto_{msg.id}_N.png (710-712)
    → addAttachmentToMessage (714) → 气泡显示
  → finally: service.onProgress = null (728)
```

#### 路径 C：设置页测试生成

```
设置页 _ImageGenTestWidget (image_gen_settings_screen.dart:1290+)
  → imageGenStateProvider.watch (1311)
  → 填 prompt → 生成按钮 (1339)
    → imageGenStateProvider.notifier.generate(ImageGenRequest)
      → ImageGenStateNotifier.generate (image_gen_providers.dart:338)
        → service.generate() → 进度/结果 → state
  → 进度条 (1363) + 结果预览 (1375+)
```

#### 路径 D：模型列表拉取

```
设置页/对话框打开 → fetchedModelsProvider (image_gen_providers.dart:529)
  → FetchedModelsNotifier 初始化 (474)
    → provider.supportsFetchingModels? → fetchModels() (476)
    → service.fetchModels() (500)
      → _fetchComfyUIModels() (825)  // GET /object_info/CheckpointLoaderSimple
  → availableModelsProvider 合并 (547)
  → UI 下拉框 (image_generation_dialog.dart:386 / 配置对话框)
```

### 1.3 数据模型完整定义

#### ImageGenSettings（`image_generation_service.dart:240-510`）

```dart
class ImageGenSettings {
  final bool enabled;                                    // :241
  final ImageGenProvider provider;                        // :242
  final Map<String, String> apiKeys;      // :245 provider.id → apiKey
  final Map<String, String> apiEndpoints; // :246 provider.id → endpoint
  final Map<String, String> models;       // :247 provider.id → model
  // 共享默认参数
  final int defaultWidth;          // :250  默认 1024
  final int defaultHeight;         // :251  默认 1024
  final int defaultSteps;          // :252  默认 20
  final double defaultCfgScale;    // :253  默认 7.0
  final String defaultSampler;     // :254  默认 'euler_a'
  final String defaultScheduler;   // :255  默认 'karras'
  final String? defaultNegativePrompt; // :256
  // 提示词自定义
  final String? positivePromptPrefix;    // :259
  final String? extractionInstruction;  // :260
  final String? imageTagInstruction;     // :261
  // 全自动生图
  final bool enableAutoPromptGeneration;  // :263
  final String? autoPromptConfigId;       // :264
  // 独立提示词优化 API
  final String? promptOptBaseUrl;   // :267
  final String? promptOptApiKey;    // :268
  final String? promptOptModel;     // :269
  // NovelAI 专属
  final bool novelaiAnlasGuard;     // :272
  final bool novelaiSm;             // :273
  final bool novelaiSmDyn;         // :274
  final bool novelaiDecrisper;     // :275
  final bool novelaiVarietyBoost;  // :276
  // OpenAI 专属
  final String openaiStyle;         // :279  vivid|natural
  final String openaiQuality;       // :280  standard|hd
  // 自动生图模式
  final AutoImageMode autoImageMode; // :283
}
```

**ComfyUI 特有配置现状**：无专属字段。ComfyUI 复用通用 `apiEndpoints['comfyui']`（endpoint）和 `models['comfyui']`（checkpoint 名，由下拉框选择）。`requiresApiKey=false`，无需 API Key。

**参数范围（Notifier setter 中的 clamp）**：
- `defaultWidth` / `defaultHeight`：256–2048（`image_gen_providers.dart:170/175`）
- `defaultSteps`：1–150（`:180`）
- `defaultCfgScale`：1.0–30.0（`:185`）

#### ImageGenRequest（`image_generation_service.dart:513-555`）

```dart
class ImageGenRequest {
  final String prompt;              // :514 必填
  final String? negativePrompt;     // :515
  final int width;                  // :516  默认 1024
  final int height;                 // :517  默认 1024
  final int steps;                  // :518  默认 20
  final double cfgScale;            // :519  默认 7.0
  final String sampler;             // :520  默认 'euler_a'（A1111 命名）
  final String? scheduler;          // :521  可空
  final String? model;              // :522  可空（用 settings.model 兜底）
  final int? seed;                  // :523  可空（-1 = 随机）
  final int batchSize;             // :524  默认 1
  final ImageGenMode mode;          // :525  默认 free
}
```

#### ImageGenResult（`image_generation_service.dart:558-576`）

```dart
class ImageGenResult {
  final List<Uint8List> images;       // :559 图片字节（ComfyUI /view 拉的 PNG 直接放这）
  final List<String> imageUrls;       // :560 URL 型结果
  final String prompt;                // :561
  final int seed;                     // :562
  final String format;                // :563 默认 'png'
  final Map<String, dynamic>? metadata; // :564
}
```

### 1.4 当前支持的后端

| # | Provider ID | 显示名 | 默认 Endpoint | 需要 Key | 结果方式 | 实现状态 |
|---|------------|--------|--------------|---------|---------|---------|
| 1 | `openai` | OpenAI | `https://api.openai.com/v1` | ✅ | b64_json/URL | ✅ `_generateOpenAI:981` |
| 2 | `openai_chat` | OpenAI-Chat | `https://api.openai.com/v1` | ✅ | chat content 提取 | ✅ `_generateOpenAIChat:1145` |
| 3 | `gemini` | Gemini | `https://generativelanguage.googleapis.com/v1beta` | ✅ | inlineData base64 | ✅ `_generateGemini:1272` |
| 4 | `novelai` | NovelAI | `https://image.novelai.net` | ✅ | ZIP 解码 PNG | ✅ `_generateNovelAI:1382` |
| 5 | `latent_moe` | Latent.moe | `https://latent.moe` | ✅ | 提交→轮询→拉图 | ✅ `_generateLatentMoe:1562` |
| 6 | `automatic1111` | Automatic1111 | `http://localhost:7860` | ❌ | 同步 base64 | ✅ `_generateAutomatic1111:1820` |
| 7 | **`comfyui`** | **ComfyUI** | **`http://127.0.0.1:8188`** | **❌** | **workflow 提交→轮询→/view** | **❌ 占位符 `:2003`** |
| 8 | `local_dream` | Local Dream | `http://127.0.0.1:8081` | ❌ | NDJSON 流式 | ✅ `_generateLocalDream:1874` |

**配置方式**：per-provider Map（`apiKeys`/`apiEndpoints`/`models`，键为 `provider.id`）。Endpoint 留空用默认值（`effectiveEndpoint = apiEndpoint ?? provider.defaultEndpoint`，`:325`）。设置存 `SharedPreferences`（`image_gen_settings` key），密钥存 `FlutterSecureStorage`。

**参数传递方式**：统一为 POST JSON（NovelAI 同步返回 ZIP 用 `ResponseType.bytes`；Local Dream 用 `dart:io HttpClient` 做 NDJSON 行流）。

**结果处理方式**：全部归一到 `ImageGenResult.images: List<Uint8List>`（字节）。云端可能返回 URL → `downloadImage()` 下载；base64 → `decodeBase64Image()` 解码。Latent.moe 是唯一"提交→轮询→拉图"的异步后端。

**错误处理**：`generate()` 外层 try-catch（`:939-977`），捕获后调 `onError` 回调 + 返回 null。Latent.moe 内部 `validateStatus: (_) => true` 接收所有状态码手动解析错误体（`_latentError:1767`）。超时：Latent.moe 10 分钟轮询上限 + 超时取消（`:1659`）。

### 1.5 扩展点识别（需要改哪些文件）

| 操作 | 文件路径 | 改动类型 | 说明 |
|------|---------|---------|------|
| **核心** | `lib/domain/services/image_generation_service.dart` | 扩展方法 `:2003-2007` | **实现 `_generateComfyUI()`**：构建 workflow → POST /prompt → 轮询 /history → GET /view 拉图 |
| 核心 | 同上 | 新增私有方法 | `_buildTxt2ImgWorkflow(request, model)` 等 workflow 构建器 |
| 核心 | 同上 | 新增私有方法 | ComfyUI 采样器名映射表（A1111→ComfyUI） |
| 可选 | 同上 `:825` | 已实现 `_fetchComfyUIModels` 可保留；或改用 `/models/checkpoints` 更轻量 |
| 可选 | 同上 `:240` ImageGenSettings | 新增字段 | ComfyUI 专属：`workflowTemplate`（txt2img/img2img/upscale 选择）、`comfyuiClientId` |
| 可选 | 同上 `:418` toJson / `:449` fromJson | 同步序列化 | 新增字段的持久化 |
| 可选 | `lib/presentation/providers/image_gen_providers.dart` | 新增 setter | `setWorkflowTemplate` 等（仿 NovelAI setter `:248-275`） |
| 可选 | `lib/presentation/dialogs/image_gen_config_dialog.dart:581` | ComfyUI 专属分支 | 当前 ComfyUI 走通用 else（Endpoint + 模型名）；可加"测试连接"按钮 + workflow 模板选择 |
| 可选 | `lib/presentation/screens/settings/image_gen_settings_screen.dart:637` | 新增 ComfyUI 信息 ListTile | 类比 A1111 的 stableDiffusion 提示 |
| ⚠️ 发现 | `android/app/src/main/res/xml/network_security_config.xml` | 配置问题（不修复） | 仅 `localhost`/`127.0.0.1` 允许明文；用户填局域网 IP 访问远程 ComfyUI 会被 Android 阻止 |

---

## 第二部分：ComfyUI API 文档总结

> 以下接口均从 ComfyUI master `server.py` 源码逐条验证（路由装饰器 `@routes.get/post`）。host 默认 `127.0.0.1:8188`，与项目 `ImageGenProvider.comfyui.defaultEndpoint` 一致。

### 2.1 核心接口完整说明

#### 接口 1：获取节点/模型信息

```
GET http://127.0.0.1:8188/object_info
GET http://127.0.0.1:8188/object_info/{node_class}
```

- **源码**：`server.py:803-822`
- **返回**：JSON，`{node_class: {input: {required: {字段名: [可选值列表]}}, output, output_name, ...}}`
- **用途**：项目 `_fetchComfyUIModels()` 已用 `/object_info/CheckpointLoaderSimple` 拉取 checkpoint 列表（解析 `input.required.ckpt_name[0]`）
- **示例响应**：
```json
{
  "CheckpointLoaderSimple": {
    "input": {
      "required": {
        "ckpt_name": ["v1-5-pruned-emaonly.safetensors", "sdxl_base.safetensors"]
      }
    },
    "output": ["MODEL", "CLIP", "VAE"],
    "output_name": ["MODEL", "CLIP", "VAE"]
  }
}
```
- **注意**：`/object_info`（全量）会遍历所有已安装节点（含自定义节点），响应可能数 MB；拉单一模型用 `/object_info/{node_class}` 更高效。也可用 `GET /models/{folder}`（`server.py:348`）按文件夹拉取（checkpoints/loras/vae/embeddings/controlnet 等），更轻量。

#### 接口 2：提交生图任务

```
POST http://127.0.0.1:8188/prompt
Content-Type: application/json

{
  "prompt": { /* workflow JSON，见 2.2 */ },
  "client_id": "kira-xxxxxxxx-xxxx-...",   // 可选，WS 订阅用
  "prompt_id": null,                       // 可选，省略则服务端生成 UUID；非空必须为 canonical UUID
  "front": false,                          // 可选，true=插队到队首
  "number": 1,                             // 可选，排序号
  "extra_data": {}                         // 可选，透传数据
}
```

- **源码**：`server.py:1075-1147`
- **成功响应**（200）：
```json
{
  "prompt_id": "abc12345-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "number": 1,
  "node_errors": {}
}
```
- **失败响应**（400）：`{"error": {...}, "node_errors": {...}}`（workflow 校验失败、必填输入缺失、节点不存在等）
- **关键**：`prompt_id` 省略时服务端 `uuid.uuid4()` 生成；显式传入必须是 canonical 小写连字符 UUID，否则 400 `invalid_prompt_id`。项目已有 `uuid` 依赖，可生成 clientId/promptId。

#### 接口 3：查询任务状态

```
GET http://127.0.0.1:8188/history/{prompt_id}
GET http://127.0.0.1:8188/history?max_items=N&offset=N
```

- **源码**：`server.py:1048-1065`
- **返回**：`{prompt_id: {prompt, outputs, status}}`
- **⚠️ 关键行为**：**history 只在任务执行完成后才写入记录**。任务排队/运行中查询 `/history/{prompt_id}` 返回 `{}`（空对象）—— 这是轮询判断"是否完成"的方式：**轮询直到该 prompt_id 在 history 中出现且非空**。
- **完成响应示例**：
```json
{
  "abc12345-xxxx": {
    "prompt": [1, { /* 原 workflow */ }, "abc12345-xxxx", {}],
    "outputs": {
      "9": {
        "images": [
          {
            "filename": "kira_00001_.png",
            "subfolder": "",
            "type": "output"
          }
        ]
      }
    },
    "status": {
      "status_str": "success",
      "completed": true,
      "messages": []
    }
  }
}
```
- **outputs 键**是 SaveImage 节点的 ID（上例 `"9"`），`images` 数组含 `filename`/`subfolder`/`type` 三元组。
- 也可用 `GET /queue`（`server.py:1067`）返回 `{queue_running, queue_pending}` 判断是否还在队列中（辅助判断"失败/取消"）。

#### 接口 4：获取生成的图片

```
GET http://127.0.0.1:8188/view?filename={filename}&subfolder={subfolder}&type=output
```

- **源码**：`server.py:516-560`
- **返回**：图片二进制流（`image/png`，默认 PNG；取决于 SaveImage）
- **参数**：`filename`（必填）、`subfolder`（可选，默认空）、`type`（可选，默认 `output`；另可 `temp`/`input`）
- **安全**：禁止 `..` 和绝对路径（`server.py:542-543`）
- **用法**：从接口 3 的 `outputs.{nodeId}.images[].{filename,subfolder,type}` 取三元组拼 URL，用 dio `ResponseType.bytes` 下载得到 `Uint8List`，直接放入 `ImageGenResult.images`。
- **完整 URL 示例**：`http://127.0.0.1:8188/view?filename=kira_00001_.png&subfolder=&type=output`

#### 接口 5（可选）：WebSocket 实时进度

```
WS ws://127.0.0.1:8188/ws?clientId={client_id}
```

- **源码**：`server.py` WebSocket 处理 + `send_sync`/`send_json`（`:1385-1395`）
- **消息格式**：文本帧 JSON `{"type": <event>, "data": {...}}`；二进制帧为 latent preview 图（前 8 字节是 header）
- **关键事件类型**：

| type | data | 含义 |
|------|------|------|
| `status` | `{status: {exec_info: {queue_remaining: N}}}` | 队列状态 |
| `execution_start` | `{prompt_id}` | 开始执行 |
| `executing` | `{node: <id>, prompt_id}` | 正在执行某节点；**`node: null` = 整个 prompt 执行完成** |
| `progress` | `{value, max, prompt_id}` | KSampler 采样步进（value/max = 当前步/总步） |
| `executed` | `{node, output: {images: [...]}, prompt_id}` | 节点输出（含图片信息，可省去 history 轮询） |
| `execution_cached` | `{nodes: [...], prompt_id}` | 命中缓存的节点（未重跑） |
| `execution_error` | `{prompt_id, node_type, node_id, ...}` | 执行出错 |
| `execution_interrupted` | `{prompt_id, ...}` | 被中断 |
| `execution_success` | `{prompt_id}` | 成功完成（新版本） |

- **二进制帧**：latent 预览图（JPEG/PNG），前 8 字节 = 4 字节 event type + 4 字节 image type，其后是图片数据。仅 `--preview-method` 开启时发送。

#### 辅助接口

| 接口 | 方法 | 源码行 | 用途 |
|------|------|--------|------|
| `/` | GET | 329 | 根（健康检查/连上了即在线） |
| `/system_stats` | GET | 689 | VRAM/RAM/设备信息（健康检查 + 资源监控） |
| `/queue` | GET | 1067 | 当前队列 `{queue_running, queue_pending}` |
| `/queue` | POST | 1149 | `{"clear": true}` 清队列 / `{"delete": [id]}` 删项 |
| `/interrupt` | POST | 1163 | 中断当前正在运行的任务 |
| `/free` | POST | 1195 | `{"unload_models": true, "free_memory": true}` 卸载模型释放显存 |
| `/upload/image` | POST | 464 | **multipart 上传图片**（img2img 用），FormData `image` 字段 + `subfolder`/`type`/`overwrite`；返回 `{name, subfolder, type, url}` |
| `/upload/mask` | POST | 470 | 上传 mask（inpainting 用） |
| `/models` | GET | 342 | 所有模型文件夹概览 |
| `/models/{folder}` | GET | 348 | 按文件夹列模型文件（checkpoints/loras/vae/embeddings/controlnet/upscale_models…） |
| `/embeddings` | GET | 337 | embedding 列表 |

### 2.2 Workflow JSON 结构解析

ComfyUI 的 workflow 是一个**节点图**，JSON 顶层是 `Map<String, NodeDef>`，键为节点 ID（字符串），值为节点定义：

```json
{
  "<node_id>": {
    "class_type": "节点类名",
    "inputs": {
      "<输入名>": <标量值> 或 ["<上游node_id>", <输出索引>]
    },
    "_meta": { "title": "显示名" }   // 可选
  }
}
```

**节点连接方式**：`["4", 0]` = 节点 `"4"` 的第 `0` 个输出。通过这种引用把节点连成有向图。

**执行规则**（README 确认）：
1. 只有所有输入就绪的节点才会执行；
2. **部分图重执行**：提交相同 workflow 时，只有发生变化的节点及其下游会重跑，其余命中缓存。⚠️ **这意味着相同 workflow+相同 seed 第二次提交会直接缓存返回**——所以每次生图必须随机化 seed（用 `DateTime.now().millisecondsSinceEpoch` 或 uuid）。

### 2.3 常用 Workflow 模板

#### 模板 1：文生图 txt2img（SD1.5，可直接运行）

> 6 节点最小化。`CheckpointLoaderSimple` 输出 [MODEL(0), CLIP(1), VAE(2)]；两个 `CLIPTextEncode` 接 CLIP；`KSampler` denoise=1.0；`SaveImage` filename_prefix 决定输出文件名前缀。

```json
{
  "3": {
    "class_type": "KSampler",
    "inputs": {
      "seed": 1566802087002865,
      "steps": 20,
      "cfg": 7.0,
      "sampler_name": "euler",
      "scheduler": "karras",
      "denoise": 1.0,
      "model": ["4", 0],
      "positive": ["6", 0],
      "negative": ["7", 0],
      "latent_image": ["5", 0]
    }
  },
  "4": {
    "class_type": "CheckpointLoaderSimple",
    "inputs": { "ckpt_name": "v1-5-pruned-emaonly.safetensors" }
  },
  "5": {
    "class_type": "EmptyLatentImage",
    "inputs": { "width": 512, "height": 512, "batch_size": 1 }
  },
  "6": {
    "class_type": "CLIPTextEncode",
    "inputs": { "text": "a beautiful girl, silver hair, garden", "clip": ["4", 1] }
  },
  "7": {
    "class_type": "CLIPTextEncode",
    "inputs": { "text": "lowres, bad anatomy, bad hands", "clip": ["4", 1] }
  },
  "8": {
    "class_type": "VAEDecode",
    "inputs": { "samples": ["3", 0], "vae": ["4", 2] }
  },
  "9": {
    "class_type": "SaveImage",
    "inputs": { "filename_prefix": "kira", "images": ["8", 0] }
  }
}
```

> **提交前**：先用 `GET /object_info/CheckpointLoaderSimple` 拿到真实 `ckpt_name` 替换占位值，否则 400 `node_errors`。

#### 模板 2：图生图 img2img（可直接运行）

> 在 txt2img 基础上：`LoadImage` 加载上传的图片 → `VAEEncode` 编码到潜空间 → `KSampler` denoise<1.0 重绘。**前置**：先 `POST /upload/image` 上传图片得到 `name`，填入 `LoadImage.image`。

```json
{
  "10": {
    "class_type": "LoadImage",
    "inputs": { "image": "input.png" }
  },
  "11": {
    "class_type": "VAEEncode",
    "inputs": { "pixels": ["10", 0], "vae": ["4", 2] }
  },
  "4": {
    "class_type": "CheckpointLoaderSimple",
    "inputs": { "ckpt_name": "v1-5-pruned-emaonly.safetensors" }
  },
  "6": {
    "class_type": "CLIPTextEncode",
    "inputs": { "text": "masterpiece, best quality", "clip": ["4", 1] }
  },
  "7": {
    "class_type": "CLIPTextEncode",
    "inputs": { "text": "lowres, bad anatomy", "clip": ["4", 1] }
  },
  "3": {
    "class_type": "KSampler",
    "inputs": {
      "seed": 42,
      "steps": 20,
      "cfg": 7.0,
      "sampler_name": "euler",
      "scheduler": "karras",
      "denoise": 0.6,
      "model": ["4", 0],
      "positive": ["6", 0],
      "negative": ["7", 0],
      "latent_image": ["11", 0]
    }
  },
  "8": {
    "class_type": "VAEDecode",
    "inputs": { "samples": ["3", 0], "vae": ["4", 2] }
  },
  "9": {
    "class_type": "SaveImage",
    "inputs": { "filename_prefix": "kira_img2img", "images": ["8", 0] }
  }
}
```

**上传图片**（前置请求）：
```
POST http://127.0.0.1:8188/upload/image
Content-Type: multipart/form-data

image: <二进制文件>
overwrite: true
type: input
subfolder: (空)

→ 200 {"name": "input.png", "subfolder": "", "type": "input", "url": "/view?..."}
```

#### 模板 3：放大 upscale（Latent Upscale，可直接运行）

> `LoadImage` → `VAEEncode` → `LatentUpscale`（放大潜空间）→ `KSampler` denoise≈0.5（细化）→ `VAEDecode` → `SaveImage`。

```json
{
  "10": {
    "class_type": "LoadImage",
    "inputs": { "image": "input.png" }
  },
  "4": {
    "class_type": "CheckpointLoaderSimple",
    "inputs": { "ckpt_name": "v1-5-pruned-emaonly.safetensors" }
  },
  "11": {
    "class_type": "VAEEncode",
    "inputs": { "pixels": ["10", 0], "vae": ["4", 2] }
  },
  "12": {
    "class_type": "LatentUpscale",
    "inputs": {
      "upscale_method": "nearest-exact",
      "width": 1024,
      "height": 1024,
      "crop": "disabled",
      "samples": ["11", 0]
    }
  },
  "6": {
    "class_type": "CLIPTextEncode",
    "inputs": { "text": "high quality, detailed", "clip": ["4", 1] }
  },
  "7": {
    "class_type": "CLIPTextEncode",
    "inputs": { "text": "lowres, blurry", "clip": ["4", 1] }
  },
  "3": {
    "class_type": "KSampler",
    "inputs": {
      "seed": 42,
      "steps": 15,
      "cfg": 7.0,
      "sampler_name": "euler",
      "scheduler": "karras",
      "denoise": 0.5,
      "model": ["4", 0],
      "positive": ["6", 0],
      "negative": ["7", 0],
      "latent_image": ["12", 0]
    }
  },
  "8": {
    "class_type": "VAEDecode",
    "inputs": { "samples": ["3", 0], "vae": ["4", 2] }
  },
  "9": {
    "class_type": "SaveImage",
    "inputs": { "filename_prefix": "kira_upscale", "images": ["8", 0] }
  }
}
```

> **图片型无再采样 upscale**（更简单）：`LoadImage` → `ImageUpscaleWithModel`（需 `UpscaleModelLoader` 加载 `4x-UltraSharp.pth`）→ `SaveImage`，无 KSampler、无 denoise。

### 2.4 关键节点说明

| 节点 class_type | 输入 | 输出 | 作用 |
|----------------|------|------|------|
| `CheckpointLoaderSimple` | `ckpt_name` | MODEL(0), CLIP(1), VAE(2) | 加载整模型（含三件套） |
| `CLIPTextEncode` | `text`, `clip` | CONDITIONING(0) | 编码正/负面 prompt |
| `EmptyLatentImage` | `width`,`height`,`batch_size` | LATENT(0) | 初始化空白潜空间（txt2img 用） |
| `KSampler` | `seed`,`steps`,`cfg`,`sampler_name`,`scheduler`,`denoise`,`model`,`positive`,`negative`,`latent_image` | LATENT(0) | **核心采样器**。txt2img denoise=1.0；img2img denoise<1.0 |
| `VAEDecode` | `samples`(LATENT), `vae` | IMAGE(0) | 潜空间→图片 |
| `VAEEncode` | `pixels`(IMAGE), `vae` | LATENT(0) | 图片→潜空间（img2img/upscale 用） |
| `SaveImage` | `filename_prefix`,`images` | （保存到 output 目录） | 输出图片，结果出现在 `/history` 的 `outputs.{id}.images[]` |
| `LoadImage` | `image`(文件名) | IMAGE(0), MASK(1) | 加载已上传图片（需先 `/upload/image`） |
| `LatentUpscale` | `upscale_method`,`width`,`height`,`crop`,`samples` | LATENT(0) | 潜空间放大（配合低 denoise 细化） |
| `UpscaleModelLoader` | `model_name` | UPSCALE_MODEL(0) | 加载 ESRGAN 等放大模型 |
| `ImageUpscaleWithModel` | `upscale_model`,`image` | IMAGE(0) | 像素级放大（无再采样） |
| `PreviewImage` | `images` | （存到 temp） | 预览图（用 `type=temp` 取） |

> **Flux / SD3 等新模型节点不同**：Flux 用 `UNETLoader` + 双 `CLIPLoader`（t5/clip）+ `VAELoader` 分离加载，而非 `CheckpointLoaderSimple`。集成时若支持 Flux 需单独模板。

### 2.5 采样器/调度器枚举（源码验证）

**ComfyUI `SAMPLER_NAMES`**（`comfy/samplers.py:971-975 + 1356`）：
```
euler, euler_cfg_pp, euler_ancestral, euler_ancestral_cfg_pp, heun, heunpp2,
exp_heun_2_x0, exp_heun_2_x0_sde, dpm_2, dpm_2_ancestral, lms, dpm_fast,
dpm_adaptive, dpmpp_2s_ancestral, dpmpp_2s_ancestral_cfg_pp, dpmpp_sde,
dpmpp_sde_gpu, dpmpp_2m, dpmpp_2m_cfg_pp, dpmpp_2m_sde, dpmpp_2m_sde_gpu,
dpmpp_2m_sde_heun, dpmpp_2m_sde_heun_gpu, dpmpp_3m_sde, dpmpp_3m_sde_gpu,
ddpm, lcm, ipndm, ipndm_v, deis, cfgpp_ud10_ab, res_multistep,
res_multistep_cfg_pp, res_multistep_ancestral, res_multistep_ancestral_cfg_pp,
gradient_estimation, gradient_estimation_cfg_pp, er_sde, seeds_2, seeds_3,
sa_solver, sa_solver_pece,
ddim, uni_pc, uni_pc_bh2
```

**ComfyUI `SCHEDULER_NAMES`**（`comfy/samplers.py:1365-1374`）：
```
simple, sgm_uniform, karras, exponential, ddim_uniform, beta, normal,
linear_quadratic, kl_optimal
```

**项目→ComfyUI 采样器映射表**（项目 `ImageGenSampler` 用 A1111 命名，`:585-606`）：

| 项目 ID（A1111） | ComfyUI sampler_name | 说明 |
|------------------|---------------------|------|
| `euler` | `euler` | ✅ 直接用 |
| `euler_a` | `euler_ancestral` | ⚠️ 需映射 |
| `heun` | `heun` | ✅ |
| `dpm_2` | `dpm_2` | ✅ |
| `dpm_2_a` | `dpm_2_ancestral` | ⚠️ 需映射 |
| `lms` | `lms` | ✅ |
| `dpm_fast` | `dpm_fast` | ✅ |
| `dpm_adaptive` | `dpm_adaptive` | ✅ |
| `dpmpp_2s_a` | `dpmpp_2s_ancestral` | ⚠️ 需映射 |
| `dpmpp_sde` | `dpmpp_sde` | ✅ |
| `dpmpp_2m` | `dpmpp_2m` | ✅ |
| `ddim` | `ddim` | ✅ |
| `plms` | ❌ 不存在 | 映射到 `dpmpp_2m` 或 `uni_pc`（A1111 遗留，ComfyUI 移除） |
| `uni_pc` | `uni_pc` | ✅ |
| `k_euler` 等（NovelAI） | 去 `k_` 前缀 | `k_euler_ancestral`→`euler_ancestral` |

**调度器**：项目默认 `karras` ✅ ComfyUI 兼容；项目 `defaultScheduler` 默认 `karras`（`:296`）。

---

## 第三部分：集成方案设计

### 3.1 分阶段实现路线

#### Phase 1：基础版（固定 txt2img + 模型下拉 + 轮询）—— **2-3 天**

**目标**：让 ComfyUI 能跑通"选模型→填 prompt→出图"。

**改动**：
1. 实现 `_generateComfyUI()`（`image_generation_service.dart:2003`）：
   - `_buildTxt2ImgWorkflow(request, model)`：用 2.3 模板 1，注入 `prompt`/`negativePrompt`/`width`/`height`/`steps`/`cfg`/`seed`/`ckpt_name`，**seed 随机化**（防缓存）；
   - 采样器名映射表（A1111→ComfyUI，见 2.5）；
   - `POST /prompt`（body: `{prompt, client_id}`），拿 `prompt_id`；
   - 轮询 `GET /history/{prompt_id}` 直到非空（仿 `_generateLatentMoe` 的 `while + Future.delayed`，间隔 1-2s，超时 5-10 分钟）；
   - 从 `outputs.{nodeId}.images[0]` 取 `{filename, subfolder, type}`；
   - `GET /view?...`（dio `ResponseType.bytes`）拉 PNG → `Uint8List`；
   - `onProgress` 映射：提交 0.1、轮询中 0.2-0.9、完成 1.0；
   - 返回 `ImageGenResult(images: [bytes], prompt, seed, format:'png', metadata:{provider:'comfyui', prompt_id, model})`。
2. 模型下拉框：`_fetchComfyUIModels()`（`:825`）**已实现**，直接复用 `fetchedModelsProvider`。
3. 错误处理：`validateStatus: (_)=>true` 手动解析 400 `node_errors` 给清晰提示（仿 `_latentError:1767`）。

**验证**：设置页选 ComfyUI → 选模型 → 测试生成区出图 ✅；聊天 `/imagine` 出图 ✅。

#### Phase 2：进阶版（img2img + 参数完整 + 多模板）—— **4-5 天**

**目标**：支持图生图、放大、完整采样器/调度器、SDXL/Flux 模板。

**改动**：
1. `_buildImg2ImgWorkflow()`：先 `POST /upload/image`（multipart）上传用户选的图 → 得 `name` → 套 2.3 模板 2；
2. `_buildUpscaleWorkflow()`：套 2.3 模板 3（latent upscale 或 ESRGAN）；
3. `ImageGenSettings` 新增 `comfyuiWorkflowTemplate` 枚举字段（txt2img/img2img/upscale）+ 持久化；
4. `image_gen_config_dialog.dart:581` ComfyUI 专属分支：模板选择 + 输入图选择器（img2img 时）；
5. SDXL 模板（`EmptySD3LatentImage` 或 SDXL 专用节点）/ Flux 模板（`UNETLoader`+双`CLIPLoader`+`VAELoader`）；
6. 完整采样器映射 + UI 下拉用 `ImageGenSampler.forProvider(comfyui)` 过滤（`forProvider` 当前 default 分支返回全部，可细化）。

#### Phase 3：完整版（WebSocket 进度 + 取消 + 自定义 workflow）—— **6-7 天**

**目标**：实时步进进度、取消任务、用户自定义 workflow JSON。

**改动**：
1. 新增依赖 `web_socket_channel: ^3.x`（pubspec.yaml）；
2. `_generateComfyUI` 可选 WS 模式：连 `ws://{host}:8188/ws?clientId={client_id}`，监听 `progress`（value/max→onProgress）、`executing`(node=null→完成)、`execution_error`、`executed`（直接拿 output.images，省去 history 轮询）；
3. `POST /interrupt` 取消当前任务（设置页"停止"按钮）；
4. 自定义 workflow JSON 编辑器（`TextField` 多行 + JSON 校验 + 占位符替换 `${prompt}`/`${width}` 等）。

### 3.2 需要修改/新增的文件列表

| 阶段 | 操作 | 文件 | 说明 |
|------|------|------|------|
| P1 | **修改** | `lib/domain/services/image_generation_service.dart` | 实现 `_generateComfyUI` + `_buildTxt2ImgWorkflow` + 采样器映射 |
| P1 | 验证 | 无新文件 | 现有 UI/Provider/路由全部可复用 |
| P2 | 修改 | 同上 service | + `_buildImg2ImgWorkflow` / `_buildUpscaleWorkflow` + upload |
| P2 | 修改 | `image_generation_service.dart:240` ImageGenSettings | + `comfyuiWorkflowTemplate` 字段 + `toJson/fromJson` |
| P2 | 修改 | `image_gen_providers.dart` | + `setWorkflowTemplate` setter |
| P2 | 修改 | `image_gen_config_dialog.dart:581` | ComfyUI 专属配置分支 |
| P3 | 修改 | `pubspec.yaml` | + `web_socket_channel: ^3.x` |
| P3 | 修改 | service `_generateComfyUI` | WS 进度模式 |
| P3 | 新增（可选） | `lib/data/models/comfyui_workflow.dart` | workflow 数据模型 + 模板注册表（可选，也可内联在 service） |

### 3.3 依赖清单

| 依赖 | 是否需要 | 用途 | 现状 |
|------|---------|------|------|
| `dio` | ✅ 已有 | HTTP（提交/轮询/拉图） | pubspec `^5.4.0` |
| `http` | ✅ 已有 | 备用 | pubspec `^1.6.0` |
| `uuid` | ✅ 已有 | 生成 client_id | pubspec `^4.2.1` |
| `archive` | ✅ 已有 | （ComfyUI 不需要，仅 NovelAI 用） | — |
| `image` | ✅ 已有 | 图片处理（如需转码） | pubspec `^4.1.3` |
| `dart:convert` | ✅ 内置 | JSON | — |
| `web_socket_channel` | ⚠️ P3 才需 | WebSocket 实时进度 | **当前无**，需新增 |

**结论**：Phase 1/2 **零新依赖**。仅 Phase 3 WebSocket 需新增 `web_socket_channel`。

### 3.4 风险评估

| 维度 | 难度 | 风险/原因 |
|------|:----:|----------|
| 拉取模型列表 | ⭐ | ✅ 已实现 `_fetchComfyUIModels`；`/object_info` 全量响应大时改 `/object_info/CheckpointLoaderSimple` 或 `/models/checkpoints` 更优 |
| 构建简单 workflow | ⭐⭐ | 固定模板替换几个标量参数即可；注意节点 ID 连接 `["4",0]` 格式易错 |
| 提交+轮询结果 | ⭐⭐ | 仿 `_generateLatentMoe` 成熟模式；**关键坑**：history 未完成返回 `{}`，需轮询到非空；超时保护 |
| seed 随机化 | ⭐ | ⚠️ **ComfyUI 缓存机制**：相同 workflow+seed 第二次直接缓存返回不出新图。必须每次随机 seed |
| 图片下载 | ⭐ | `/view` 需 filename/subfolder/type 三元组（不能直接拼 prompt_id） |
| 采样器名映射 | ⭐⭐ | A1111 `euler_a`→ComfyUI `euler_ancestral`；`plms` 不存在需兜底 |
| 动态 UI（模型下拉） | ⭐⭐ | `fetchedModelsProvider` 已支持异步加载+状态管理，直接复用 |
| img2img 上传 | ⭐⭐⭐ | multipart FormData 上传 + LoadImage 文件名引用；需处理图片选择器 |
| 多种 workflow（SDXL/Flux） | ⭐⭐⭐⭐ | 不同模型族节点结构差异大（Flux 用 UNETLoader+双 CLIP）；需多模板维护 |
| WebSocket 实时进度 | ⭐⭐⭐⭐ | 异步消息流 + 二进制帧解析；需处理连接断开/重连；新增依赖 |
| 自定义 workflow JSON | ⭐⭐⭐⭐⭐ | 需 JSON 编辑器 + 占位符替换 + 节点连接校验；用户门槛高 |

**额外风险（非技术）**：
- **用户门槛**：需本地跑 ComfyUI（需 GPU + Python 环境 + 模型文件，通常几 GB），门槛高于云端 API。可引导用桌面版/便携版。
- **明文 HTTP / Android 网络**：`network_security_config.xml` 当前只允许 `localhost`/`127.0.0.1` 明文。若用户在另一台机器跑 ComfyUI（填局域网 IP 如 `192.168.x.x:8188`），Android 会阻止明文流量。**建议**：扩展 cleartext 域名或加 `base-config cleartextTrafficPermitted="true"`（需人工决策，本次不修改）。
- **iOS**：iOS 模拟器 `localhost` 可达宿主机 ComfyUI；真机需局域网 IP + 同一 Wi-Fi + 防火墙放行 8188。
- **维护成本**：workflow 模板随模型演进（SD1.5→SDXL→SD3→Flux）节点结构变化，模板需持续维护。

---

## 第四部分：UI 设计建议

### 4.1 配置界面布局

**现状**（`image_gen_config_dialog.dart:581-597`）：ComfyUI 走通用 else 分支——Endpoint 地址 + 模型名称手动输入。**建议**改为 ComfyUI 专属分支：

```
┌─ ComfyUI 配置 ─────────────────────────────┐
│ Endpoint 地址  [http://127.0.0.1:8188     ] │  ← 保留，留空用默认
│                                              │
│ [🔍 测试连接]   ✅ 在线 / VRAM 12.3GB        │  ← 新增：GET /system_stats
│                                              │
│ 模型 (Checkpoint)                           │
│ [v1-5-pruned-emaonly.safetensors         ▼] │  ← 复用 fetchedModelsProvider
│  (从 /object_info/CheckpointLoaderSimple 拉) │
│                                              │
│ Workflow 模板 (P2)                          │
│ (•) 文生图 txt2img                           │
│ ( ) 图生图 img2img  [选择图片...]            │
│ ( ) 放大 upscale                            │
│                                              │
│ ☐ 启用 ComfyUI                              │  ← enabled toggle（已有）
└──────────────────────────────────────────────┘
```

设置页 `image_gen_settings_screen.dart:264-292` 的 Endpoint 编辑也保留；新增"测试连接"按钮调 `GET /system_stats` 显示 VRAM。

### 4.2 生成界面

**现状**：`ImageGenerationDialog`（聊天手动生图）和设置页测试区已有 prompt + 参数 + 进度条 + 结果预览，**ComfyUI 实现后直接复用，无需改 UI**。`_generate()`（`image_generation_dialog.dart:318`）已通过 `service.generate()` 统一入口分发，ComfyUI 自动生效。

### 4.3 进度显示

| 方案 | 阶段 | 精度 | 实现 |
|------|------|------|------|
| **轮询** | P1 | 粗（0.1 提交 / 0.2-0.9 轮询 / 1.0 完成） | 仿 `_generateLatentMoe`，`onProgress` 回调驱动 `LinearProgressIndicator` |
| **WebSocket** | P3 | 细（KSampler 每步 value/max） | 监听 `progress` 事件 → `onProgress(value/max)`；`executing(node=null)` → 1.0 |

现有 UI 进度组件（`image_gen_settings_screen.dart:1363` `LinearProgressIndicator(value: genState.progress)` + 百分比文本）两种方案都兼容。

---

## 第五部分：与现有代码的整合方案

### 5.1 复用现有 Service 架构

ComfyUI **完美契合**现有架构，无需新增 Service 层抽象：
- `generate()`（`:929`）的 switch-case 已为 ComfyUI 预留分支（`:960-961` → `_generateComfyUI`）；
- 只需把 `:2003` 的 `throw UnimplementedError` 替换为真实实现；
- `ImageGenRequest`（prompt/size/steps/cfg/sampler/seed/model）字段足够支撑 txt2img/img2img，无需扩展请求模型；
- `ImageGenResult(images: [Uint8List])` 已统一，`/view` 拉的 PNG 字节直接放入；
- `onProgress`/`onError` 回调机制已就绪，UI 自动响应。

**最佳参考**：`_generateLatentMoe()`（`:1562-1762`）——同为"提交→轮询→拉图"异步模式，其轮询循环（`:1663-1706`）、超时取消（`:1707-1713`）、错误解析（`_latentError:1767`）、进度映射（`:1693-1697`）可直接套用到 ComfyUI。

### 5.2 扩展配置对话框

`image_gen_config_dialog.dart` 的 `_buildLocalConfig`（`:503`）当前用 `if/else if/else` 区分 latentMoe/novelai/通用。ComfyUI 走通用 else（Endpoint + 模型名手动输入）。

**扩展方式**（P2）：在 `_buildLocalConfig` 增加 `else if (settings.provider == ImageGenProvider.comfyui)` 分支，提供：
1. Endpoint TextField（复用 `_buildTextField`）；
2. "测试连接"按钮；
3. 模型下拉（复用 `availableModelsProvider`，而非手动输入——当前 else 分支是手动输入模型名，ComfyUI 应改为下拉，因为 `_fetchComfyUIModels` 已能拉列表）；
4. Workflow 模板选择（P2）。

> 注意：`image_gen_settings_screen.dart:264-292` 的 Endpoint 配置也需同步（ComfyUI 的 `requiresApiKey=false`，走 `_showEndpointDialog`）。

### 5.3 统一不同后端的接口

现有架构**已经是统一接口**，ComfyUI 实现后自动统一：

```
统一入口: service.generate(ImageGenRequest)  // :929
   │
   ├─ openai      → _generateOpenAI      (同步, b64/URL)
   ├─ openaiChat  → _generateOpenAIChat  (同步, chat 提取)
   ├─ gemini      → _generateGemini      (同步, inlineData)
   ├─ novelai     → _generateNovelAI     (同步, ZIP)
   ├─ latentMoe   → _generateLatentMoe   (异步, 提交→轮询→拉图)
   ├─ automatic1111 → _generateAutomatic1111 (同步, base64)
   ├─ comfyui     → _generateComfyUI    (异步, workflow→提交→轮询→/view)  ← 待实现
   └─ localDream  → _generateLocalDream  (流式, NDJSON)
```

**统一契约**：
- **输入**：`ImageGenRequest`（所有后端共用）
- **输出**：`ImageGenResult(images: List<Uint8List>)`（所有后端归一到字节）
- **副作用**：`onProgress(double)` / `onError(String)` 回调（所有后端共用）
- **异常**：抛出 Exception，由 `generate()` 外层 catch → `onError` + 返回 null

**ComfyUI vs 其他后端的差异**：
- 唯一需要"workflow JSON 构建"步骤——其他后端直接发 prompt；ComfyUI 需把 prompt 注入节点图。可通过私有 `_buildXxxWorkflow()` 封装，对 `generate()` 透明。
- 图片获取需三元组（filename/subfolder/type）而非直接 URL——但最终都归一到 `Uint8List`，对上层透明。

**结论**：实现 `_generateComfyUI()` 后，**聊天手动生图、自动生图、设置页测试**三个入口**零改动**即可支持 ComfyUI（它们都走 `service.generate()`）。这是现有架构的最大优势。

---

## 附录：关键代码定位速查

| 需求 | 文件:行 |
|------|---------|
| ComfyUI Provider 定义 | `image_generation_service.dart:88` |
| ComfyUI 模型拉取（已实现） | `image_generation_service.dart:824-849` |
| **ComfyUI 生成（占位符，待实现）** | `image_generation_service.dart:2003-2007` |
| 异步轮询参考实现 | `image_generation_service.dart:1562-1762`（`_generateLatentMoe`） |
| 错误体解析参考 | `image_generation_service.dart:1767-1802`（`_latentError`） |
| 生成总入口（switch 分发） | `image_generation_service.dart:929-978` |
| 服务单例 Provider | `image_gen_providers.dart:9-13` |
| 设置持久化 | `image_gen_providers.dart:37-132` |
| 生成状态 Provider | `image_gen_providers.dart:408-411` |
| 模型列表 Provider | `image_gen_providers.dart:529-544` |
| 聊天手动生图对话框 | `image_generation_dialog.dart:41/318` |
| 聊天自动生图 | `chat_providers.dart:626-739` |
| 设置页 ComfyUI 下拉 | `image_gen_settings_screen.dart:235/253` |
| 配置对话框 ComfyUI 分支 | `image_gen_config_dialog.dart:581-597` |
| Android 明文 HTTP 配置 | `android/app/src/main/res/xml/network_security_config.xml` |

---

*调研结束。本报告为只读调研产物，未修改任何代码、未新增依赖。等待人工决策后实施。*
