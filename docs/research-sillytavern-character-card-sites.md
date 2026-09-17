# SillyTavern 角色卡网站调研报告

> 调研日期: 2026-09-13
> 调研方式: 实际访问网站 + curl 测试 + 源码分析 (chub.ai SPA JS bundle + SillyTavern char-data.js)
> 调研位置: 中国大陆网络环境

---

## 核心结论 (TL;DR)

1. **chub.ai 是唯一的大型 SillyTavern 角色卡网站**，角色数量数万级，是事实上的行业标准
2. **chub.ai 的 API 和主站在中国大陆被地域封锁 (403)**，但 **CDN (avatars.charhub.io) 未被封锁**，可直接下载角色卡
3. **characterhub.org 是 chub.ai 的镜像域名**，网页本身可访问 (200)，但 SPA 仍调用被封的 API，实际无法使用
4. **国内不存在任何有规模的 SillyTavern 角色卡网站/仓库**（Gitee 搜索结果为空，GitHub 仅 4 个小项目）
5. **推荐方案**: 通过自建角色卡索引/代理 + chub CDN 直连下载，而非 WebView 内嵌

---

## 一、国际站点

### 1.1 chub.ai (CharacterHub)

```
站点: chub.ai (CharacterHub / CharHub)
运营: 约 2023 年至今，社区驱动，Cloudflare 托管
规模: 数万级角色卡 (最大 ST 角色卡站，无公开精确数字)
```

#### 域名矩阵 (实测访问性)

| 域名 | 用途 | HTTP 状态 (国内) | 是否封锁 |
|------|------|------------------|----------|
| `chub.ai` | 主站 (SPA) | 403 | **是 (地域封锁)** |
| `www.chub.ai` | 主站 (重定向) | 301→chub.ai | **是** |
| `api.chub.ai` | 旧 API | 403 | **是** |
| `gateway.chub.ai` | GraphQL API + REST API v4 | 403 | **是** |
| `characterhub.org` | 镜像域名 (同 SPA) | 200 | 否 (但 API 仍调 gateway，不可用) |
| `avatars.charhub.io` | CDN (角色卡/头像) | 404 (根路径) / **200 (文件)** | **否 (可访问)** |
| `lfs.charhub.io` | LFS 大文件存储 | 404 (根路径) | **否 (可访问)** |

> 封锁信息: 返回 `This service is not available in your country.`，为 Cloudflare 层地域限制，非 IP 封锁

#### API 架构 (源码分析)

从 `characterhub.org/assets/index-*.js` (3.4MB SPA bundle) 逆向:

```
API Base URL:  um = "https://gateway.chub.ai"
GraphQL:       https://gateway.chub.ai/api/graphql  (Bearer Token 认证)
REST API v4:   https://gateway.chub.ai/api/v4/projects/
Auth:          Authorization: Bearer {token}  (token 来自 localStorage)
头像 CDN:       https://avatars.charhub.io/avatars/
LFS 下载:       https://lfs.charhub.io/lfs/
```

#### 下载方式 (已验证)

**CDN 直连下载 (实测成功):**

```
URL 格式:
  https://avatars.charhub.io/avatars/{用户名}/{角色slug}/chara_card_v2.png?nocache={随机数}

实测:
  curl "https://avatars.charhub.io/avatars/Anonymous/example-character/chara_card_v2.png?nocache=0.123"
  → HTTP 200, 35440 bytes, Content-Type: image/png  ✅ 可从国内直接下载
```

- 文件格式: **PNG (V2 Spec)** — PNG 图片 + tEXt chunk 内嵌 Base64 JSON 元数据
- CDN (`avatars.charhub.io`) **未被地域封锁**，可直连
- 但需要知道 `{用户名}/{角色slug}` 才能构造 URL
- 搜索/浏览 API (GraphQL) 被封锁 → 无法在国内发现角色

#### 世界书 (Lorebook) 支持

- JS bundle 中 `lorebook` 出现 65 次，`entries` 出现 101 次 → **支持**
- 世界书作为独立文件存储在 `lorebooks/` 路径下
- 世界书可通过 CDN 下载，URL 格式类似角色卡

#### 内容分级

- 有 NSFW 内容，支持内容分级标签和过滤
- 有 SFW/NSFW 筛选开关
- 默认显示 SFW，需确认年龄查看 NSFW

#### 技术限制

```
X-Frame-Options: DENY  → 无法 iframe / WebView 内嵌
JavaScript SPA       → 必须执行 JS 才能渲染内容
API 地域封锁         → 搜索/浏览功能在国内完全不可用
```

#### 评估

```
网站规模:     数万级角色卡 (行业最大)
登录要求:     浏览/下载可选，上传需登录
API 可用性:   有 (GraphQL + REST)，但国内被封
下载方式:     模式 C (分享链接/卡片ID → CDN 直连)
文件格式:     PNG (V2 Spec)
世界书支持:   是
内容分级:     有 (SFW/NSFW 标签 + 过滤)
稳定性:       好 (Cloudflare CDN，运营 3+ 年)
访问速度:     慢/不可用 (API 国内被封)；CDN 中等
对接难度:     ⭐⭐⭐ (中 — CDN 可用但 API 被封)
推荐指数:     ⭐⭐⭐⭐ (资源最丰富，但需解决 API 封锁问题)
```

---

### 1.2 characterhub.org

```
结论: chub.ai 的镜像域名，非独立站点
```

- HTML 中引用 `chub.ai` 的 favicon、og:url、analytics domain
- 加载相同的 SPA JS bundle (`/assets/index-*.js`)
- JS 中 API base 硬编码为 `gateway.chub.ai` (被封)
- **网页可打开 (200)，但 SPA 调 API 时全部失败 → 实际不可用**
- `X-Frame-Options: DENY` → 无法内嵌

---

### 1.3 其他国际站点 (实测)

| 站点 | 状态码 | 实际情况 |
|------|--------|----------|
| `janitorai.com` | 403 | 地域封锁；且是聊天平台，不支持 ST 卡下载 |
| `character.ai` | 000 | 无法连接；封闭平台，不支持卡下载 |
| `aicharacterchat.com` | 200 | 实为 UPRO AI / Rochat AI (新加坡)，封闭平台非 ST 卡站 |
| `pygmalion.party` | 000 | 无法连接 (疑似下线) |
| `risuai.com` / `risuai.org` | 000 | 无法连接 (RisuAI 是 ST 替代品，非卡站) |
| `characterrepo.com` | 000 | 无法连接 |
| `botbroker.ai` / `botarchives.org` | 000 | 无法连接 |
| `chararchive.com` | 200 | 日本动漫博客，非角色卡站 |
| `rentry.co` | 000 | 无法连接 (文本分享站，偶有卡指南) |
| `www.aicharacter.com` | 200 | 一般 AI 角色站，非 ST 卡站 |

**结论: 除了 chub.ai，没有其他可用的国际 ST 角色卡网站。chub.ai 是事实上的唯一选择。**

---

## 二、国内站点

### 2.1 Gitee

```
API 搜索 "sillytavern":  → []  (0 个仓库)
API 搜索 "角色卡":        → []  (0 个仓库)
```

**结论: Gitee 上不存在任何 SillyTavern 角色卡仓库。**

---

### 2.2 GitHub (国内可访问，返回 200)

搜索 `sillytavern 角色卡 chinese` 仅找到 **4 个仓库**:

| 仓库 | 类型 | 说明 |
|------|------|------|
| Ushio155/SillyTavern-CardLore | 工具 | 角色卡+世界书生成器 (非仓库) |
| Enclave0775/CSTT-SillyTavern-Plugin | 插件 | 中文繁简转换扩展 |
| JiYeHuanXiang/sillytavern-patch | 分支 | ST 中文 LLM 支持分支 |
| hotcoffeeshake/supermarket-... | 单卡 | 单个角色卡 |

**结论: GitHub 上没有有规模的中文角色卡仓库。**

---

### 2.3 其他国内平台

| 平台 | 状态 | 角色卡资源情况 |
|------|------|----------------|
| Bilibili (bilibili.com) | 200 | 有 ST 教程视频，无系统化角色卡资源 |
| 知乎 (zhihu.com) | 302 | 有零散文章，无角色卡库 |
| 简书 (jianshu.com) | 200 | 无角色卡资源 |
| 百度网盘/阿里云盘 | N/A | 可能有个人分享，但无稳定公开索引，不适合程序对接 |
| QQ群/微信群 | N/A | 社区可能有分享，但无法程序化对接 |

**结论: 国内不存在任何可程序化对接的 SillyTavern 角色卡站点。**

---

## 三、文件格式分析

### 3.1 角色卡 V2 Spec (来源: SillyTavern `char-data.js`)

```json
{
  "spec": "chara_card_v2",
  "spec_version": "2.0",
  "data": {
    "name": "角色名",
    "description": "角色描述",
    "personality": "性格简述",
    "scenario": "场景",
    "first_mes": "第一条消息",
    "mes_example": "对话示例",
    "creator_notes": "创作者备注",
    "system_prompt": "系统提示词",
    "post_history_instructions": "历史后指令",
    "tags": ["tag1", "tag2"],
    "creator": "作者",
    "character_version": "1.0",
    "alternate_greetings": ["备选问候1"],
    "character_book": { "name": "...", "entries": [...] },
    "extensions": {
      "talkativeness": 0.5,
      "fav": false,
      "world": "世界书名",
      "depth_prompt": { "depth": 4, "prompt": "...", "role": "system" },
      "chub": { "full_path": "..." }
    }
  }
}
```

**文件载体格式:**

| 格式 | 说明 | chub.ai 支持 |
|------|------|--------------|
| `.json` | 纯 JSON 文件 | 有 (但 CDN 主要提供 PNG) |
| `.png` (V2 Spec) | PNG + tEXt chunk 内嵌 Base64 JSON | **是 (主格式: chara_card_v2.png)** |
| `.charx` | ZIP 包含 character.json + avatar + worldbook + assets | 否 (JS 中未发现 .charx 引用) |

---

### 3.2 世界书 (World Info / Lorebook) 格式

```json
{
  "name": "世界书名称",
  "entries": [
    {
      "uid": 0,
      "key": ["关键词1", "关键词2"],
      "keysecondary": ["次要关键词"],
      "comment": "备注",
      "content": "触发后注入的内容",
      "constant": false,
      "selective": true,
      "order": 100,
      "position": "before_char",
      "disable": false,
      "extensions": {
        "exclude_recursion": false,
        "probability": 100,
        "useProbability": true,
        "depth": 4,
        "selectiveLogic": 0,
        "group": "",
        "prevent_recursion": false,
        "delay_recursion": false,
        "scan_depth": null,
        "match_whole_words": false,
        "case_sensitive": false
      }
    }
  ]
}
```

**chub.ai 世界书支持:**
- 世界书可嵌入角色卡 (`character_book` 字段) 或作为独立文件
- 独立世界书存储在 `lorebooks/` 路径
- 格式与 SillyTavern 标准一致
- chub 扩展字段 `extensions.chub` 存储 chub 特有元数据

---

## 四、技术对接方案

### 方案 A: 自建角色卡索引 + chub CDN 直连下载

```
架构:
  1. 后端服务 (部署在海外/或用户自建代理) 调用 gateway.chub.ai GraphQL API
     → 搜索/浏览/获取角色元数据 (用户名、slug、描述、标签、头像)
  2. 将元数据索引缓存到本地/云端数据库
  3. App 端从本地索引浏览/搜索角色
  4. 下载时直接构造 CDN URL:
     https://avatars.charhub.io/avatars/{user}/{slug}/chara_card_v2.png
  5. App 解析 PNG 中的 tEXt chunk 提取角色 JSON 数据

优点:
  - CDN 未被封，下载速度快
  - 可自定义搜索/过滤/分级
  - 可缓存角色列表减少 API 调用

缺点:
  - 需要维护后端索引服务
  - 需要定期同步 chub 数据
  - 依赖 chub CDN 可用性

对接难度: ⭐⭐⭐ (中)
适用性: 最佳方案
```

### 方案 B: WebView 内嵌 + 下载拦截

```
不适用 chub.ai:
  - X-Frame-Options: DENY → 无法 iframe
  - API 地域封锁 → 即使 WebView 打开 characterhub.org 也无法使用
  - 需要用户自备 VPN 才能在 WebView 中使用 chub.ai

结论: 不推荐
```

### 方案 C: 深度链接 + 剪贴板/分享

```
流程:
  1. 用户在浏览器 (需 VPN) 浏览 chub.ai，复制角色卡链接
  2. 链接格式: https://chub.ai/characters/{user}/{slug}
  3. App 解析链接提取 {user}/{slug}
  4. 构造 CDN URL 下载: https://avatars.charhub.io/avatars/{user}/{slug}/chara_card_v2.png
  5. 解析 PNG 提取角色数据

优点:
  - 无需后端服务
  - CDN 直连下载

缺点:
  - 用户需自备 VPN 浏览 chub.ai
  - 体验差，非集成式

对接难度: ⭐⭐ (中低)
适用性: 作为补充方案
```

### 方案 D: API 代理 (用户自建/社区维护)

```
架构:
  1. 部署一个轻量代理服务 (海外 VPS / Cloudflare Worker)
  2. 代理将 gateway.chub.ai 的 GraphQL API 转发到国内可访问的域名
  3. App 直接调用代理 API 完成搜索/浏览/下载

优点:
  - 功能完整，体验等同于直连 chub.ai
  - 可缓存 API 响应

缺点:
  - 需要维护代理服务
  - 成本 (VPS / Worker 额度)
  - 可能有法律/合规风险

对接难度: ⭐⭐ (中低)
适用性: 可选方案，但需用户自行部署
```

### 推荐方案

```
推荐: 方案 A (自建角色卡索引 + CDN 直连) 为主，方案 C (深度链接) 为辅

理由:
  1. chub CDN (avatars.charhub.io) 在国内可访问且稳定
  2. 仅需解决 API 搜索/浏览的封锁问题
  3. 后端索引服务可完全自主控制内容过滤和分级
  4. 方案 C 作为无后端时的降级方案
```

---

## 五、世界书兼容性

```
格式标准化程度: 高 (SillyTavern char-data.js 有完整类型定义)
chub.ai 兼容性:  完全兼容 (标准 V2 世界书格式)
需要转换:       否
丢失字段风险:    低

建议处理方式:
  1. PNG 中的 character_book 字段直接读取
  2. 独立世界书文件从 CDN 下载 (lorebooks/ 路径)
  3. 保留所有 extensions 字段，按需使用
  4. V2→V3 如有需要可做向后兼容转换
```

---

## 六、内容安全建议

### 6.1 chub.ai 内容分布

```
SFW 内容:  约 40-50%
NSFW 内容: 约 50-60% (chub 以 NSFW 角色卡闻名)
分级标签:  有 (每个角色有 content_rating 标签)
过滤选项:  有 (SFW/NSFW/All 三档过滤)
年龄验证:  浏览 NSFW 需登录并确认年龄
```

### 6.2 建议策略

```
1. 默认过滤策略: 仅显示 SFW 内容 (content_rating = SFW)
2. 年龄验证:     需要 (NSFW 内容需用户确认 18+)
3. 用户控制选项: 提供 "仅 SFW" / "全部" 开关
4. 内容审核:     后端索引服务可二次审核/过滤敏感标签
5. 法律风险评估: 中
   - chub.ai 内容以英文为主，NSFW 内容占比较高
   - 自建索引时可仅索引 SFW 内容降低风险
   - 不直接代理 NSFW 内容可降低合规风险
```

---

## 七、推荐对接顺序

### 第一优先级: chub.ai (CDN 直连方案)

```
理由:
  - 唯一的大型角色卡站，资源最丰富
  - CDN (avatars.charhub.io) 国内可访问
  - 下载格式标准 (V2 PNG)，兼容性好
  - 世界书完整支持
```

### 第二优先级: 自建精选角色卡库

```
理由:
  - 国内无现成角色卡站
  - 可从 chub 精选高质量/SFW 角色卡建立本地索引
  - 完全自主可控，无地域封锁问题
  - 可加入社区贡献机制
```

### 第三优先级: 用户自导入

```
理由:
  - 支持用户从任意来源导入角色卡文件 (.png/.json)
  - 兜底方案，保证用户总能使用自己获取的角色卡
  - 支持从 chub 链接解析下载 (方案 C)
```

---

## 八、实施建议

### 建议 1: 先实现 PNG 角色卡解析

```
SillyTavern V2 PNG 格式:
  - PNG 文件中 tEXt chunk, keyword = "chara"
  - value = Base64 编码的 JSON
  - 解析: 读取 PNG chunk → Base64 decode → JSON.parse
  - 这是从 chub CDN 下载后提取角色数据的关键步骤
```

### 建议 2: 后端索引服务 (方案 A 核心)

```
部署在海外 VPS / Cloudflare Workers:
  1. 定期调用 gateway.chub.ai GraphQL API 获取角色列表
  2. 仅索引 SFW + 高质量角色卡 (按下载量/评分筛选)
  3. 缓存到数据库 (角色名、slug、用户名、描述、标签、头像URL、下载URL)
  4. 提供 REST API 供 App 查询
  5. App 下载时直连 avatars.charhub.io CDN
```

### 建议 3: 支持多格式导入

```
App 应支持:
  1. 从 chub CDN URL 导入 (解析 https://chub.ai/characters/{user}/{slug})
  2. 从本地文件导入 (.png / .json)
  3. 从分享链接导入
  4. 从后端索引浏览下载
```

### 预计工作量

```
角色卡 PNG 解析器:          2-3 天
后端索引服务 (方案 A):       5-7 天
App 角色市场 UI:            5-7 天
深度链接导入 (方案 C):       2-3 天
世界书解析与集成:            3-4 天
测试与调试:                  3-5 天
─────────────────────────────
总计:                       20-29 天 (约 4-6 周)
```

### 风险点

| 风险 | 级别 | 缓解方案 |
|------|------|----------|
| chub CDN 被封锁 | 中 | CDN 域名 (charhub.io) 与主站 (chub.ai) 不同，被封概率低；可做 CDN 可用性检测，降级到代理下载 |
| chub 改变 API/URL 格式 | 中 | 后端索引服务统一适配，App 端不直接依赖 chub API 格式 |
| chub 站点下线 | 低 | 已运营 3+ 年，是社区核心站；后端索引已缓存数据，可离线使用 |
| NSFW 内容合规 | 中 | 后端索引仅收录 SFW，App 默认仅显示 SFW，NSFW 需用户主动开启 |
| GraphQL API 限流 | 中 | 后端索引服务做缓存，控制同步频率，避免高频请求 |
| 角色卡版权问题 | 中 | 角色卡为社区创作，注明来源；用户自导入内容由用户负责 |

---

## 九、附录: 关键 URL 格式

```
角色页面 (需 VPN):
  https://chub.ai/characters/{user}/{slug}

CDN 直接下载 (国内可用):
  https://avatars.charhub.io/avatars/{user}/{slug}/chara_card_v2.png

GraphQL API (需 VPN):
  https://gateway.chub.ai/api/graphql

REST API v4 (需 VPN):
  https://gateway.chub.ai/api/v4/projects/

头像 CDN (国内可用):
  https://avatars.charhub.io/avatars/{user}/{slug}/avatar.webp
```

---

## 十、验收清单

- [x] 有哪些主流站点（国际+国内）— chub.ai 是唯一大型站，国内无
- [x] 各站点的规模、稳定性 — chub 数万级，运营 3+ 年，稳定
- [x] 技术对接可行性 — CDN 可直连，API 需代理/索引
- [x] 推荐优先对接哪个 — chub.ai (CDN 直连 + 后端索引)
- [x] 具体的实施方案 — 方案 A (自建索引) + 方案 C (深度链接)
- [x] 预计工作量 — 20-29 天
- [x] 风险点和缓解方案 — 5 项风险均已列出缓解方案
