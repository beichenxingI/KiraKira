# 侦察1 Core八功能数据表

侦察范围:Core 仪表盘(lib/presentation/screens/settings/geek_dashboard_screen.dart)上 8 个功能入口。
所有结论均以源代码读取证,未修改任何 lib/ 文件。

## 一、八功能主表

| 功能 | 总开关可读?(provider + 路径 + 持久化) | 高频参数(1-2 个) | 数据现成度 | 对应路由 |
|---|---|---|---|---|
| API 高级参数 | 无独立布尔总开关。`llmConfigProvider`(StateNotifierProvider,lib/presentation/providers/settings_providers.dart:536),SharedPreferences 键 `llm_config`(:54)。仪表盘已直接复用其 streamEnabled 等字段 | `model`(当前模型名,updateModel :335)、`maxTokens` / `contextLength`(Hero 环已在用) | 现成(但无总开关语义,只能做摘要卡) | `/advanced-settings`(advanced_settings_screen.dart) |
| AI 预设 | 无(预设本身无 enable 概念) | `activeAIPresetProvider`(当前预设名,lib/presentation/providers/ai_preset_providers.dart:127)、`allAIPresetsProvider` 列表计数(:94);持久化键 `ai_active_preset_id` / `ai_custom_presets` | 现成(只读摘要:当前预设名 + 预设数) | `/ai-presets`(ai_presets_screen.dart) |
| 提示词管理 | 无单一全局 enabled;启用态在 `promptManagerProvider` 的每个 PromptSection 上(lib/presentation/providers/prompt_manager_providers.dart:136;键 `prompt_manager_config`) | `enabledPromptSectionsProvider`(:142)计数/列表;`activePresetProvider`(:266)当前提示词预设名,键 `prompt_manager_active_preset_id` | 现成(计数/预设名现成;"全局开关"需自行定义,如一键禁用所有 section) | `/prompt-manager`(prompt_manager_screen.dart) |
| 正则系统 | 有:`regexSettingsProvider` → `RegexSettings.enabled`(默认 true),lib/presentation/providers/regex_providers.dart:281 / setEnabled :374;SharedPreferences 键 `regex_settings`(:344) | `globalRegexScriptsProvider`(:19)全局脚本列表计数(启用数 = `where(!disabled)`),键 `global_regex_scripts` | 现成(总开关 + 计数全现成,可直接做可展开卡) | `/regex-settings`(regex_settings_screen.dart) |
| 向量 RAG | 有:`vectorStorageSettingsProvider` → `.enabled`,lib/presentation/providers/vector_storage_providers.dart:25(setEnabled 同文件);键 `vector_storage_settings`(:26)。仪表盘 _StatusCard 已在用 | `topK`(setTopK :70,clamp 1–20)、`similarityThreshold`(:77)、`embeddingProvider` | 现成(仪表盘已挂开关,可直接升级为可展开卡) | `/vector-storage-settings`(vector_storage_settings_screen.dart) |
| TTS 合成 | 有:`ttsSettingsProvider` → `TTSSettings.enabled`,lib/presentation/providers/tts_providers.dart:14(setEnabled :52);键 `tts_settings`(:20) | `rate`(语速 :67,0.5–2.0 滑块天然适配)、`provider`(TTSProvider)/`voiceId`;`autoPlay`(:82) | 现成(tts_service.dart:100 TTSSettings 字段全,notifier setter 齐) | `/tts-settings`(tts_settings_screen.dart) |
| STT 识别 | 有:`sttSettingsProvider` → `STTSettings.enabled`,lib/presentation/providers/stt_providers.dart:14(setEnabled :52);键 `stt_settings`(:20) | `language`(:62)、`autoSend`(:72)或 `continuousListening`(:67) | 现成 | `/stt-settings`(stt_settings_screen.dart) |
| 翻译 | 有:`translationSettingsProvider` → `TranslationSettings.enabled`,lib/presentation/providers/translation_providers.dart:12(setEnabled :50);键 `translation_settings`(:18) | `sourceLanguage`→`targetLanguage`(:60,:65)、`autoTranslateIncoming`/`autoTranslateOutgoing`(:70,:75) | 现成 | `/translation-settings`(translation_settings_screen.dart) |

补充:全部 8 个功能的状态均为现成的 Riverpod StateNotifierProvider,无一埋在子页 Widget State / 私有字段中。唯一例外是"API 高级参数"与"AI 预设"没有 enable 布尔(属于配置型功能,语义上不需要总开关);提示词管理的开关粒度在 section 级而非全局。

## 二、geek_dashboard_screen.dart 现状摘要

### _StatusCard 6 个开关(读文件确认,:322–417)

| 卡片 | 开关状态 | 写入动作 | onTap 路由 |
|---|---|---|---|
| CFG Scale | `isCFGActiveProvider`(cfg_scale_providers.dart) | `cfgScaleSettingsProvider.notifier.setEnabled(v)` | `/cfg-scale-settings` |
| 向量 RAG | `vectorStorageSettingsProvider.enabled` | `.setEnabled(v)` | `/vector-storage-settings` |
| 流式输出 | `llmConfigProvider.streamEnabled` | `updateStreamEnabled(v)` | 无(纯开关) |
| 自动摘要 | `llmConfigProvider.autoSummarizeEnabled` | `updateAutoSummarizeEnabled(v)`,附 note"长对话会额外消耗 API 额度" | 无(纯开关) |
| Logit 偏置 | `logitBiasSettingsProvider.enabled` | `.setEnabled(v)` | `/logit-bias-settings` |
| 分词器 | `tokenizerSettingsProvider.showTokenCount` | `.setShowTokenCount(v)`,副标题"已启用计数/计数关闭"(非功能总开关) | `/tokenizer-settings` |

### Hero 指标卡数据来源(:53–154)

- 生成预算(环形):`llmConfigProvider` 的 `maxTokens / contextLength` 比值(clamp 0–1),>0.9 变警告黄;大数字显示 maxTokens,单位 "tokens / 次"。
- 功能在线(大数字 + 胶囊条):统计 6 个布尔里 true 的个数 —— `isCFGActiveProvider`、`vectorStorageSettingsProvider.enabled`、`streamEnabled`、`autoSummarizeEnabled`、`logitBiasSettingsProvider.enabled`、`tokenizerSettingsProvider.showTokenCount`,显示 "N / 6 项启用",进度 = N/6,为 0 时变红色。

### _EntryTile 入口路由清单(:421–435,共 13 格,4 列网格)

API 高级 `/advanced-settings`、AI 预设 `/ai-presets`、提示词管理 `/prompt-manager`、正则系统 `/regex-settings`、向量 RAG `/vector-storage-settings`、TTS 合成 `/tts-settings`、STT 识别 `/stt-settings`、翻译 `/translation-settings`、图像生成 `/image-gen-settings`、精灵图 `/sprite-settings`、变量管理 `/variables-settings`、日志统计 `/statistics`、MVU 变量框架 `/mvu-settings`。(8 个目标功能在其中,另含 5 个附加入口。)

## 三、结论

8 个功能中 **5 个数据现成且有总开关**(正则 / 向量 RAG / TTS / STT / 翻译),可直接做"开关 + 高频参数就地调节"的可展开功能卡;**3 个只有只读摘要**(API 高级参数、AI 预设、提示词管理 —— 后者虽有 section 计数与预设名,但无全局总开关,且 tip 切换到子页操作更合理),适合做只读摘要行 + 跳转。
