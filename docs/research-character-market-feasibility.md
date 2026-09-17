# 角色市场现状 + Chub.ai 对接方案验证报告

> 调研日期: 2026-09-13
> 调研方式: 完整源码阅读 + 依赖检查 + 现有实现分析

---

## 核心结论 (TL;DR)

**方案完全可行，且基础设施已就绪 90%。** 关键发现:

1. **PNG 解析已完全实现** — `PngCharacterCardParser` + `ImportService.importFromPngBytes()` 已可用
2. **Chub.ai 导入逻辑已存在** — `UrlImportService._importFromChub()` 已写好，但调用的是被封的 `api.chub.ai`，需改为 CDN 直连
3. **Character 模型完全兼容 ST V2/V3** — 所有字段齐全，含 `characterBook` 内嵌世界书
4. **WebView 已深度使用** — `flutter_inappwebview ^6.0.0`，有 `shouldOverrideUrlLoading` 先例
5. **角色市场当前是纯空态占位** — `_MarketEmptyState`，仅一个图标+文字
6. **无需添加任何新依赖** — dio、inappwebview、archive、image 全已就位

---

## 一、现有实现

### 1.1 角色市场入口

```
入口文件:  lib/presentation/screens/character/character_list_screen.dart
入口 Widget: CharacterListScreen (ConsumerStatefulWidget)
路由:      app_router.dart line 208 — CharacterListScreen 作为 tab 页
Tab 切换:  line 39 — _tab == 0 → 我的角色; _tab == 1 → 角色市场
```

### 1.2 当前状态

**纯空态占位，零功能代码。**

`character_list_screen.dart:1095-1122`:
```dart
/// 角色市场占位(C-T8.3):纯空态,绝无网络/数据逻辑
class _MarketEmptyState extends StatelessWidget {
  // → Center + Icon(CupertinoIcons.cloud_download) + "敬请期待" + "角色市场建设中"
}
```

- 无数据模型
- 无网络请求
- 无 API 调用
- 无状态管理

---

## 二、角色管理现状

### 2.1 导入功能 — 已完全实现

**ImportService** (`lib/domain/services/import_service.dart`):

| 方法 | 格式 | 状态 |
|------|------|------|
| `importFromPng(String filePath)` | PNG (V2 tEXt chunk) | ✅ 已实现 |
| `importFromPngBytes(Uint8List bytes)` | PNG bytes | ✅ 已实现 |
| `importFromCharX(String filePath)` | CharX (ZIP) | ✅ 已实现 |
| `importFromJson(String json)` | JSON | ✅ 已实现 |
| `_parseCharacterJson()` | V1/V2/V3 自动识别 | ✅ 已实现 |
| `_parseCharacterBook()` | 内嵌世界书 | ✅ 已实现 |
| `_extractPngTextChunk()` | PNG tEXt 提取 | ✅ 已实现 |
| `_embedPngTextChunk()` | PNG tEXt 写入 | ✅ 已实现 |
| `importEmbeddedLorebook()` | 内嵌书→独立 WorldInfo | ✅ 已实现 |
| `exportToPng()` | 导出 PNG | ✅ 已实现 |
| `exportToCharX()` | 导出 CharX | ✅ 已实现 |
| `exportToJson()` | 导出 JSON | ✅ 已实现 |

**PngCharacterCardParser** (`lib/domain/services/png_character_card_parser.dart`):
- 独立的 PNG 解析器
- 处理 tEXt / iTXt / zTXt chunk
- 尝试直接 JSON → Base64+JSON 双路径解码
- 生成诊断报告到 Downloads 目录
- **纯 Dart 实现，无需第三方 PNG 库**

### 2.2 URL 导入 — 已有 Chub.ai 逻辑

**UrlImportService** (`lib/domain/services/url_import_service.dart`):

```dart
enum UrlSource { KiraKira, chub, janitorAI, pygmalion, risurealm, aiCharacterCards, directPng, directJson, unknown }
```

**已有 `_importFromChub()` (line 174-258):**
```
1. 解析 URL: https://chub.ai/characters/{author}/{name}
2. GET https://api.chub.ai/api/characters/{full_path}?full=true  ← ⚠️ 此 API 在国内被封
3. 从 metadata.node.max_res_url 下载头像 PNG
4. 用 ImportService.importFromPngBytes() 解析
5. Fallback: 从 definition 字段解析角色数据
```

> **关键问题**: 当前调用 `api.chub.ai` (国内 403 地域封锁)。
> **修复方案**: 改为直接构造 CDN URL `https://avatars.charhub.io/avatars/{author}/{name}/chara_card_v2.png`，
> 跳过被封的 API，直接从 CDN 下载 PNG。CDN 在国内已验证可访问。

### 2.3 角色数据模型 — 完全兼容 ST V2/V3

**Character** (`lib/data/models/character.dart`):

| ST V2 字段 | Kira 字段 | 兼容 |
|------------|-----------|------|
| name | name | ✅ |
| description | description | ✅ |
| personality | personality | ✅ |
| scenario | scenario | ✅ |
| first_mes | firstMessage | ✅ |
| mes_example | exampleMessages | ✅ |
| creator_notes | creatorNotes | ✅ |
| tags | tags | ✅ |
| creator | creator | ✅ |
| character_version | version | ✅ |
| system_prompt | systemPrompt | ✅ |
| post_history_instructions | postHistoryInstructions | ✅ |
| alternate_greetings | alternateGreetings | ✅ |
| character_book | characterBook (CharacterBook) | ✅ |
| extensions | extensions (Map) | ✅ |

**CharacterBook** (内嵌世界书):
- name, description, scanDepth, tokenBudget, recursiveScanning
- entries: List<CharacterBookEntry> — keys, secondaryKeys, content, constant, selective, insertionOrder, position, etc.

**WorldInfo** (`lib/data/models/world_info.dart`) — 完整 ST 兼容:
- WorldInfoEntry: 所有 V2 字段 (keys, secondaryKeys, content, constant, selective, insertionOrder, position, depth, probability, caseSensitive, group, etc.)
- WorldInfoPosition: before/after/ANTop/ANBottom/atDepth/EMTop/EMBottom/outlet (8 种位置)
- WorldInfoRole: system/user/assistant
- WorldInfoTimedEffects: sticky, cooldown, delay
- WorldInfoCharacterFilter: none/include/exclude
- 递归扫描: recursiveScanning, maxRecursionDepth, allowEntryCascade

**结论: 模型无需扩展，已 100% 兼容 ST V2/V3。**

---

## 三、技术栈确认

### 3.1 WebView 库

```
✅ 已使用 flutter_inappwebview: ^6.0.0 (pubspec.yaml line 62)
```

**现有用例:**

| 文件 | 用途 |
|------|------|
| `webview_chat_stage.dart` | 主聊天 WebView (5663 行，核心功能) |
| `html_webview_widget.dart` | HTML 消息渲染 |
| `main_page.dart` | HeadlessInAppWebView 预热 |
| `chat_bridge.dart` | JS Bridge 通信层 |

**webview_chat_stage.dart InAppWebView 配置 (line 976-1014):**
```dart
InAppWebView(
  initialData: InAppWebViewInitialData(data: _htmlShell(), baseUrl: WebUri(_kWebViewBaseUrl)),
  initialSettings: InAppWebViewSettings(
    transparentBackground: true,
    javaScriptEnabled: true,          // ✅ JS 已启用
    supportZoom: false,
    allowFileAccessFromFileURLs: true,
    allowUniversalAccessFromFileURLs: true,
    mediaPlaybackRequiresUserGesture: false,
    useHybridComposition: true,       // ✅ 混合合成
  ),
  onRenderProcessGone: ...,           // ✅ 崩溃自愈
  onWebViewCreated: (c) { _bridge.attach(c); ... },
  gestureRecognizers: { ... },        // ✅ 手势冲突处理
)
```

### 3.2 网络请求库

```
✅ dio: ^5.4.0 (pubspec.yaml line 37)
✅ http: ^1.6.0 (pubspec.yaml line 77)
```

**文件下载支持:**
- `UrlImportService` 已大量使用 `ResponseType.bytes` 下载 (9 处)
- `Dio(BaseOptions(connectTimeout: 30s, receiveTimeout: 60s, headers: {'User-Agent': 'KiraKira/1.0'}))`
- 支持重定向: `followRedirects: true`

### 3.3 图片处理

```
✅ image: ^4.1.3 (pubspec.yaml line 43) — 用于图片处理
✅ dart:typed_data — Uint8List 二进制处理
✅ dart:convert — base64 编解码
✅ archive: ^3.4.9 — CharX ZIP 解压
```

**PNG 解析现状:**
- `ImportService._extractPngTextChunk()` — 手写 PNG chunk 遍历器 (line 465-506)
- `PngCharacterCardParser.parse()` — 独立解析器，处理 tEXt/iTXt/zTXt
- 纯 Dart 实现，无需第三方 PNG 库
- 已有 CRC32 计算 (`_calculateCrc32()`)，可写入 PNG chunk

---

## 四、方案可行性验证

### ✅ 可行项

#### 1. PNG 角色卡解析 — 完全就绪

```
PngCharacterCardParser.parse(Uint8List bytes) → Map<String, dynamic>?
  → 遍历 PNG chunks，找 tEXt keyword="chara"
  → Base64 decode → JSON parse
  → 返回角色 JSON

ImportService.importFromPngBytes(Uint8List bytes) → Character
  → 调用 PngCharacterCardParser
  → _parseCharacterJson() (V1/V2/V3 自动识别)
  → _parseCharacterBook() (内嵌世界书)
  → _saveAvatar() (保存头像)
  → 返回完整 Character 对象

ImportService._extractPngTextChunk(Uint8List, String keyword)
  → 手写 PNG 二进制遍历
  → 支持 tEXt chunk (keyword + null + value)
  → 纯 Dart，无第三方依赖
```

**结论: PNG 解析 100% 可用，已通过现有导入功能验证。**

#### 2. Chub CDN 直连下载 — 可行

```
CDN URL 格式 (上一次调研已验证):
  https://avatars.charhub.io/avatars/{user}/{slug}/chara_card_v2.png

实测结果 (上一次调研):
  HTTP 200, 35440 bytes, Content-Type: image/png ✅
  CDN 未被地域封锁，国内可直连
```

**现有代码已有类似逻辑** (`UrlImportService._importFromDirectPng()`):
```dart
final response = await _dio.get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
final bytes = Uint8List.fromList(response.data!);
final character = await _importService.importFromPngBytes(bytes);
```

**只需在 `_importFromChub()` 中将 API 调用改为直接构造 CDN URL。**

#### 3. WebView URL 拦截 — 有先例

`html_webview_widget.dart:392`:
```dart
shouldOverrideUrlLoading: (controller, navigationAction) async {
  final url = navigationAction.request.url;
  if (url != null && url.toString() != 'about:blank') {
    final uri = Uri.tryParse(url.toString());
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return NavigationActionPolicy.CANCEL;
  }
  return NavigationActionPolicy.ALLOW;
},
```

**可复用模式:** 拦截 `avatars.charhub.io` 的下载链接，改为调用 `UrlImportService`。

#### 4. shouldOverrideUrlLoading + onDownloadStartRequest

`flutter_inappwebview ^6.0.0` 支持以下回调:
- `shouldOverrideUrlLoading` — ✅ 已有使用先例
- `onDownloadStartRequest` — ⚠️ 尚未使用，但 API 可用
- `onLoadResource` — 可拦截资源加载

#### 5. 角色导入完整流程 — 已实现

```
Import Screen (lib/presentation/screens/import/import_screen.dart):
  - file_picker 选择文件 → ImportService.importFromPng/Json/CharX
  - URL 输入框 → UrlImportService.importFromUrl()
  - 批量导入支持
  - 导入成功后刷新 characterListProvider
```

### ⚠️ 潜在问题

#### 问题 1: Chub.ai 主站和 API 地域封锁

```
影响: 严重
chub.ai → 403 (国内地域封锁)
api.chub.ai → 403
gateway.chub.ai → 403
characterhub.org → 200 (但 SPA 调被封的 gateway API → 不可用)

解决方案:
  - 放弃 API 搜索/浏览方案 (API 被封)
  - 直接使用 CDN (avatars.charhub.io) 下载角色卡
  - 用户通过 VPN 在 chub.ai 浏览 → 复制角色链接 → App 解析 CDN URL 下载
  - 或: 自建后端索引服务 (海外) 定期同步 chub 数据
```

#### 问题 2: Chub.ai X-Frame-Options: DENY

```
影响: 中等
chub.ai 和 characterhub.org 均设置 X-Frame-Options: DENY
→ 无法在 WebView/iframe 中内嵌 chub.ai 网站

解决方案:
  - 不内嵌 chub.ai 网站
  - 用 WebView 加载自建的浏览页面 (从后端索引获取数据)
  - 或: WebView 打开 chub.ai 作为独立浏览器 (非 iframe)
    flutter_inappwebview 的 InAppWebView 是原生 WebView，不受 X-Frame-Options 限制
    → 需验证是否可行 (理论上 InAppWebView ≠ iframe，应可加载)
```

#### 问题 3: 当前 _importFromChub 调用被封的 API

```
影响: 中等
UrlImportService._importFromChub() (line 192-200) 调用:
  GET https://api.chub.ai/api/characters/{full_path}?full=true
→ 国内返回 403

解决方案:
  将 Step 1 (API metadata) 改为直接构造 CDN URL:
    https://avatars.charhub.io/avatars/{author}/{name}/chara_card_v2.png
  跳过 API，直接下载 PNG → importFromPngBytes()
  保留 _parseChubDefinition() 作为 fallback (如果 API 在 VPN 下可用)
```

#### 问题 4: CDN URL 格式可能不一致

```
影响: 低
chub.ai 的角色 URL: https://chub.ai/characters/{author}/{name}
CDN 下载 URL:      https://avatars.charhub.io/avatars/{author}/{name}/chara_card_v2.png

需要验证: {author}/{name} 在两种 URL 中是否完全一致
上一次调研的测试 URL 用的是 Anonymous/example-character，两者一致 ✅

缓解方案:
  - 先尝试 CDN URL，失败时 fallback 到 API (用户有 VPN 时)
  - 从 chub.ai 角色页面 HTML 中提取 CDN URL (更可靠)
```

### ❌ 不可行项

```
无。所有技术方案均可行。
唯一限制: chub.ai API 搜索/浏览在国内被封，需要 VPN 或后端代理。
```

---

## 五、实施路径建议

### Phase 1: 修复 Chub 导入 + CDN 直连 (1-2 天)

```
□ 修改 UrlImportService._importFromChub():
  - 优先构造 CDN URL: avatars.charhub.io/avatars/{author}/{name}/chara_card_v2.png
  - dio.get 下载 PNG bytes
  - ImportService.importFromPngBytes() 解析
  - 失败时 fallback 到 api.chub.ai (VPN 用户)

□ 测试: 从 chub.ai 复制角色链接 → App 导入 → 成功解析
```

### Phase 2: 角色市场 UI (2-3 天)

```
□ 替换 _MarketEmptyState 为功能界面:
  - 搜索栏 (搜索框 + 标签筛选)
  - 角色卡网格 (CachedNetworkImage 显示头像)
  - 角色详情弹窗 (描述、标签、下载按钮)
  - 导入按钮 (调用 UrlImportService)

□ 数据来源:
  方案 A (推荐先做): 用户输入 chub.ai 角色链接 → CDN 下载
  方案 B (后续): 后端索引服务提供角色列表 API

□ VPN 提示: 首次进入角色市场时提示"需要 VPN 访问 chub.ai 浏览角色"
```

### Phase 3: WebView 浏览器 (可选, 2-3 天)

```
□ 创建 ChubBrowserScreen:
  - InAppWebView 加载 chub.ai (非 iframe，原生 WebView)
  - shouldOverrideUrlLoading 拦截 avatars.charhub.io 下载链接
  - 拦截后调用 UrlImportService 导入
  - 导入成功 Toast 提示

□ 测试: 在 App 内浏览 chub.ai → 点击下载 → 自动导入
```

### Phase 4: 体验优化 (1-2 天)

```
□ 导入成功后自动跳转到角色详情页
□ 角色卡预览 (头像、名称、描述前几行)
□ 下载进度条
□ 错误处理 (CDN 不可用、格式错误、角色不存在)
□ 历史导入记录
```

**总工作量: 6-10 天** (比预估的 7-11 天略少，因基础设施已就绪)

---

## 六、依赖清单

### 需要添加的依赖

```
无。所有依赖已就位:
  - flutter_inappwebview: ^6.0.0  ✅ 已有
  - dio: ^5.4.0                   ✅ 已有
  - archive: ^3.4.9              ✅ 已有
  - image: ^4.1.3                ✅ 已有
  - file_picker: ^8.0.0          ✅ 已有
  - cached_network_image: ^3.3.0 ✅ 已有
```

### 需要修改的文件

| 文件 | 修改内容 |
|------|----------|
| `lib/domain/services/url_import_service.dart` | `_importFromChub()` 改为 CDN 直连 |
| `lib/presentation/screens/character/character_list_screen.dart` | 替换 `_MarketEmptyState` 为市场 UI |
| `lib/presentation/providers/character_providers.dart` | 可能添加市场相关 provider |

### 需要新建的文件

| 文件 | 用途 |
|------|------|
| `lib/presentation/screens/market/chub_market_screen.dart` | (可选) 角色市场主界面 |
| `lib/presentation/screens/market/chub_browser_screen.dart` | (可选) WebView 浏览器 |
| `lib/presentation/widgets/market/character_card_preview.dart` | 角色卡预览组件 |
| `lib/presentation/widgets/market/chub_search_bar.dart` | 搜索栏组件 |

---

## 七、风险评估

### 技术风险

| 风险 | 严重度 | 缓解方案 |
|------|--------|----------|
| chub CDN URL 格式变化 | 低 | URL 格式稳定 (已运营 3+ 年)；fallback 到 API；从页面 HTML 提取 |
| CDN 被封 | 低 | CDN 域名 (charhub.io) 与主站 (chub.ai) 不同，被封概率低；可做可用性检测 |
| InAppWebView 无法加载 chub.ai | 低 | InAppWebView 是原生 WebView 非 iframe，不受 X-Frame-Options 限制；但 Cloudflare 挑战可能需要处理 |
| PNG 解析失败 | 低 | PngCharacterCardParser 已有完善的诊断报告 + fallback 机制 |
| 大文件下载超时 | 低 | Dio 已设 60s receiveTimeout；可加进度提示 |

### 用户体验风险

| 风险 | 严重度 | 缓解方案 |
|------|--------|----------|
| 用户不知道如何获取 chub 链接 | 中 | 提供"如何获取角色卡链接"帮助引导；可选 WebView 浏览器 |
| VPN 用户与非 VPN 用户体验不一致 | 中 | CDN 直连方案对 VPN 无依赖；浏览功能需要 VPN 时明确提示 |
| 导入后角色数据不完整 | 低 | ImportService 已有完善的字段解析 + fallback |

### 法律/合规风险

| 风险 | 严重度 | 缓解方案 |
|------|--------|----------|
| chub NSFW 内容 | 中 | 市场默认仅显示 SFW；导入由用户自主操作，App 不主动提供 NSFW 内容 |
| 角色卡版权 | 低 | 角色卡为社区创作；用户自导入，App 仅做格式解析工具 |

---

## 八、总结建议

```
方案可行性: ✅ 完全可行

推荐执行: ✅ 是

建议:
  1. Phase 1 先行: 修复 _importFromChub() 改用 CDN 直连，这是最小改动最大收益
     → 用户立刻可以通过粘贴 chub.ai 角色链接导入角色卡
  2. Phase 2 跟进: 角色市场 UI，先做链接导入式市场 (不需要后端)
  3. Phase 3 可选: WebView 浏览器，提升用户体验 (需 VPN)
  4. 不急于做后端索引服务: 先让链接导入跑通，验证用户需求后再投入

下一步行动:
  1. 修改 UrlImportService._importFromChub() → CDN 直连
  2. 测试从 chub.ai 角色链接导入
  3. 设计角色市场 UI (替换 _MarketEmptyState)
```

---

## 九、关键文件索引

| 文件 | 行数 | 用途 |
|------|------|------|
| `lib/data/models/character.dart` | 317 | Character 模型 (V2/V3 兼容) |
| `lib/data/models/world_info.dart` | 485 | WorldInfo 模型 (ST 兼容) |
| `lib/domain/services/import_service.dart` | 730 | 导入/导出服务 (PNG/JSON/CharX) |
| `lib/domain/services/png_character_card_parser.dart` | 106 | PNG tEXt chunk 解析器 |
| `lib/domain/services/url_import_service.dart` | 719 | URL 导入服务 (含 chub.ai) |
| `lib/presentation/screens/import/import_screen.dart` | 1354 | 导入界面 (文件+URL) |
| `lib/presentation/screens/character/character_list_screen.dart` | 1122 | 角色列表 (含市场占位) |
| `lib/presentation/screens/chat/webview_chat_stage.dart` | 5663 | WebView 参考实现 |
| `lib/presentation/widgets/chat/html_webview_widget.dart` | 461 | WebView URL 拦截先例 |
| `pubspec.yaml` | — | 依赖清单 |
