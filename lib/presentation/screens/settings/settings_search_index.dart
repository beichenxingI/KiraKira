// lib/presentation/screens/settings/settings_search_index.dart
/// Global search index for settings.
///
/// Manually maintained (no reflection); one entry per page plus the six high-frequency home groups.
/// keywords must include the Chinese name, the English name, and common synonyms
/// (write every variant), so any contains() match succeeds.
library;

import 'package:flutter/cupertino.dart';
import 'package:kirakira/presentation/router/app_router.dart';

class SettingsIndexEntry {
  const SettingsIndexEntry({
    required this.title,
    required this.keywords,
    required this.route,
    required this.icon,
    required this.section, // group name (shown as subtitle in search results)
    this.dialog,
  });

  final String title;
  final String keywords; // space-separated
  final String route;

  /// Non-null = migrated dialog entry: no route is used; the settings page dispatcher
  /// opens the matching dialog directly (keys are listed in `_openSearchDialog` in settings_screen.dart)
  final String? dialog;
  final IconData icon;
  final String section;
}

const kSettingsIndex = <SettingsIndexEntry>[
  // Pinned high-frequency
  SettingsIndexEntry(
    title: '深色主题',
    keywords: '深色 主题 暗色 黑夜 dark mode theme 夜间',
    route: AppRoutes.settings,
    icon: CupertinoIcons.moon,
    section: '通用',
  ),
  SettingsIndexEntry(
    title: '语言',
    keywords: '语言 中文 英文 language locale 多语言',
    route: AppRoutes.settings,
    icon: CupertinoIcons.globe,
    section: '通用',
  ),
  SettingsIndexEntry(
    title: '用户画像',
    keywords: '用户 画像 persona 身份 头像 名字',
    route: AppRoutes.settings,
    dialog: 'persona',
    icon: CupertinoIcons.person,
    section: '通用',
  ),

  // Appearance
  SettingsIndexEntry(
    title: '聊天背景',
    keywords: '聊天背景 壁纸 背景图 background wallpaper 气泡',
    route: AppRoutes.settings,
    dialog: 'background',
    icon: CupertinoIcons.photo,
    section: '外观',
  ),
  SettingsIndexEntry(
    title: '主页外观',
    keywords: '主页 首页 背景 音乐 欢迎页 home appearance 问候',
    route: AppRoutes.settings,
    dialog: 'appearance',
    icon: CupertinoIcons.house,
    section: '外观',
  ),
  SettingsIndexEntry(
    title: '精灵图',
    keywords: '精灵图 表情 立绘 sprites sprite 情绪 图片',
    route: AppRoutes.settings,
    dialog: 'sprite',
    icon: CupertinoIcons.smiley,
    section: '外观',
  ),

  // Model and generation
  SettingsIndexEntry(
    title: 'AI 预设',
    keywords: '预设 模版 preset 采样 方案 ai preset 配置',
    route: AppRoutes.aiConfig,
    dialog: 'aiPresets',
    icon: CupertinoIcons.star,
    section: '模型与生成',
  ),
  SettingsIndexEntry(
    title: '采样参数',
    keywords: '采样 温度 temperature top_p top_k 高级参数 mirostat 上下文 max tokens',
    route: AppRoutes.aiConfig,
    dialog: 'advancedSampling',
    icon: CupertinoIcons.slider_horizontal_3,
    section: '模型与生成',
  ),
  SettingsIndexEntry(
    title: 'CFG Scale',
    keywords: 'cfg scale 引导 强度 cfgscale 辅助词',
    route: AppRoutes.aiConfig,
    dialog: 'cfgScale',
    icon: CupertinoIcons.speedometer,
    section: '模型与生成',
  ),
  SettingsIndexEntry(
    title: 'Logit Bias',
    keywords: 'logit bias 偏置 惩罚 token 概率 词表',
    route: AppRoutes.aiConfig,
    dialog: 'logitBias',
    icon: CupertinoIcons.line_horizontal_3_decrease,
    section: '模型与生成',
  ),
  SettingsIndexEntry(
    title: '分词器',
    keywords: '分词器 分词 tokenizer token 计数 可视化',
    route: AppRoutes.settings,
    dialog: 'tokenizer',
    icon: CupertinoIcons.textformat_abc,
    section: '模型与生成',
  ),
  SettingsIndexEntry(
    title: '提示词管理',
    keywords: '提示词 prompt 管理 section 段落 提示 prompt manager',
    route: AppRoutes.aiConfig,
    dialog: 'promptManager',
    icon: CupertinoIcons.list_bullet,
    section: '模型与生成',
  ),
  SettingsIndexEntry(
    title: '变量框架 MVU',
    keywords: 'mvu 变量框架 变量 状态 游戏 数值 检定',
    route: AppRoutes.aiConfig,
    dialog: 'mvu',
    icon: CupertinoIcons.cube_box,
    section: '模型与生成',
  ),

  // Chat settings
  SettingsIndexEntry(
    title: '流式输出',
    keywords: '流式 stream streaming 实时 逐字 输出',
    route: AppRoutes.settings,
    icon: CupertinoIcons.bolt,
    section: '聊天设置',
  ),
  SettingsIndexEntry(
    title: '分词器计数',
    keywords: '分词器 计数 token 显示 输入框 tokenizer count',
    route: AppRoutes.settings,
    dialog: 'tokenizer',
    icon: CupertinoIcons.textformat_abc,
    section: '聊天设置',
  ),

  // Voice and translation
  SettingsIndexEntry(
    title: 'TTS 合成',
    keywords: 'tts 语音合成 朗读 有声 配音 voice speech text to speech',
    route: AppRoutes.settings,
    dialog: 'tts',
    icon: CupertinoIcons.speaker_2,
    section: '语音与翻译',
  ),
  SettingsIndexEntry(
    title: 'STT 识别',
    keywords: 'stt 语音识别 语音输入 听写 麦克风 mic speech to text',
    route: AppRoutes.settings,
    dialog: 'stt',
    icon: CupertinoIcons.mic,
    section: '语音与翻译',
  ),
  SettingsIndexEntry(
    title: '翻译',
    keywords: '翻译 中英文翻译 translation 译 translate',
    route: AppRoutes.settings,
    dialog: 'translation',
    icon: CupertinoIcons.globe,
    section: '语音与翻译',
  ),
  SettingsIndexEntry(
    title: '图片生成',
    keywords: '图片生成 出图 绘图 image generation novelai sd 画图',
    route: AppRoutes.imageGenSettings,
    icon: CupertinoIcons.photo_on_rectangle,
    section: '工具链',
  ),
  SettingsIndexEntry(
    title: '正则系统',
    keywords: '正则 脚本 替换 regex 匹配 regular expression',
    route: AppRoutes.aiConfig,
    dialog: 'regex',
    icon: CupertinoIcons.wand_stars,
    section: '工具链',
  ),
  SettingsIndexEntry(
    title: '变量管理',
    keywords: '变量 全局变量 聊天变量 variable getvar setvar 宏',
    route: AppRoutes.aiConfig,
    dialog: 'variables',
    icon: CupertinoIcons.square_list,
    section: '工具链',
  ),
  // The "vector storage RAG" search index entry was removed together with its entry point.
  SettingsIndexEntry(
    title: 'Chronicle 超级记忆',
    keywords: '记忆 chronicle 总结 词条 召回 wiki 上下文压缩 超级记忆',
    route: AppRoutes.aiConfig,
    dialog: 'chronicle',
    icon: CupertinoIcons.book,
    section: '工具链',
  ),

  // Data and diagnostics
  SettingsIndexEntry(
    title: '用量统计',
    keywords: '统计 用量 token 统计 日志统计 statistics 时长',
    route: AppRoutes.settings,
    dialog: 'statistics',
    icon: CupertinoIcons.chart_bar,
    section: '数据与诊断',
  ),
  SettingsIndexEntry(
    title: '日志查看器',
    keywords: '日志 查看 debug 错误 崩溃 log viewer 排错 历史',
    route: AppRoutes.settings,
    dialog: 'logs',
    icon: CupertinoIcons.doc_text,
    section: '数据与诊断',
  ),

  // About
  SettingsIndexEntry(
    title: '关于 KiraKira',
    keywords: '关于 版本 版权 开源 许可 赞助 支持版本号 build',
    route: AppRoutes.about,
    icon: CupertinoIcons.info_circle,
    section: '关于',
  ),
];
