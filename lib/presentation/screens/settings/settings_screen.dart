// lib/presentation/screens/settings/settings_screen.dart
/// Settings home (application-level settings only — 3 groups fit on one screen; advanced features moved to Core)
library;

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/providers/locale_provider.dart';
import 'package:kirakira/presentation/providers/persona_providers.dart';
import 'package:kirakira/presentation/router/app_router.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/providers/settings_providers.dart';
import 'package:kirakira/presentation/providers/tokenizer_providers.dart';
import 'package:kirakira/presentation/providers/translation_providers.dart';
import 'package:kirakira/presentation/providers/tts_providers.dart';
import 'package:kirakira/presentation/providers/stt_providers.dart';
import 'package:kirakira/presentation/dialogs/tts_settings_dialog.dart';
import 'package:kirakira/presentation/dialogs/stt_settings_dialog.dart';
import 'package:kirakira/presentation/dialogs/translation_settings_dialog.dart';
import 'package:kirakira/presentation/dialogs/statistics_dialog.dart';
import 'package:kirakira/presentation/dialogs/log_viewer_dialog.dart';
import 'package:kirakira/presentation/dialogs/tokenizer_dialog.dart';
import 'package:kirakira/presentation/dialogs/advanced_sampling_dialog.dart';
import 'package:kirakira/presentation/dialogs/logit_bias_dialog.dart';
import 'package:kirakira/presentation/dialogs/ai_preset_dialog.dart';
import 'package:kirakira/presentation/dialogs/regex_system_dialog.dart';
import 'package:kirakira/presentation/dialogs/prompt_manager_dialog.dart';
import 'package:kirakira/presentation/dialogs/cfg_scale_dialog.dart';
import 'package:kirakira/presentation/dialogs/mvu_dialog.dart';
import 'package:kirakira/presentation/dialogs/variables_dialog.dart';
import 'package:kirakira/presentation/dialogs/chronicle_settings_dialog.dart';
import 'package:kirakira/presentation/dialogs/global_worldbook_dialog.dart';
import 'package:kirakira/presentation/dialogs/background_settings_dialog.dart';
import 'package:kirakira/presentation/dialogs/appearance_settings_dialog.dart';
import 'package:kirakira/presentation/dialogs/sprite_settings_dialog.dart';
import 'package:kirakira/presentation/dialogs/persona_settings_dialog.dart';
import 'package:kirakira/presentation/dialogs/core_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kirakira/presentation/providers/theme_providers.dart';
import 'package:kirakira/data/models/app_theme_config.dart';
import 'package:kirakira/presentation/widgets/common/common.dart';
import 'settings_search_index.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: isDark
            ? const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.3, -0.5),
                  radius: 1.0,
                  colors: [
                    Color(0xFF1A1A1A),
                    Color(0xFF0D0D0D),
                  ],
                  stops: [0.0, 0.7],
                ),
              )
            : const BoxDecoration(
                color: Color(0xFFF7F8FA),
              ),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: KiraSearchBar(
                  controller: _searchController,
                  hintText: '搜索设置',
                  onChanged: (q) => setState(() => _query = q.trim()),
                  onClear: () => setState(() => _query = ''),
                ),
              ),
            ),
            ...(_query.isNotEmpty
                ? _searchSlivers()
                : _homeSlivers(context, l10n)),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }

  List<Widget> _homeSlivers(
      BuildContext context, AppLocalizations l10n) {
    return [
      const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(top: 8),
          child: _UserInfoCard(),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: _buildSettingCard(
            icon: CupertinoIcons.gear_alt,
            iconColor: const Color(0xFFAB47BC),
            title: '通用',
            subtitle: '主题、语言和人设',
            children: const [
              _DarkModeTile(),
              _LanguageTile(),
            ],
          ),
        ),
      ),
      // Chat settings
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: _buildSettingCard(
            icon: CupertinoIcons.chat_bubble_2,
            iconColor: const Color(0xFF42A5F5),
            title: '聊天设置',
            subtitle: '流式输出、变量框架与向量检索',
            children: [
              const _StreamOutputTile(),
              const _TokenizerCountTile(),
              KiraGroupedTile(
                icon: Icons.extension,
                iconBg: Colors.transparent,
                iconColor: const Color(0xFFC77DFF),
                title: 'MVU 变量框架',
                subtitle: '自定义提示词与更新模式',
                onTap: () => showMvuDialog(context, ref),
              ),
              KiraGroupedTile(
                icon: Icons.data_object,
                iconBg: Colors.transparent,
                iconColor: const Color(0xFF4CC9F0),
                title: '变量管理',
                subtitle: '全局变量与对话变量 CRUD',
                onTap: () => showVariablesDialog(context, ref),
              ),
              // The "RAG vector storage" entry has been removed:
              // vector capabilities are used internally by Chronicle (worldbook vectorization / topic switch detection),
              // and the manual document-upload knowledge base entry is no longer exposed.
            ],
          ),
        ),
      ),
      // Voice and translation
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: _buildSettingCard(
            icon: CupertinoIcons.speaker_2,
            iconColor: const Color(0xFFFFA726),
            title: '语音与翻译',
            subtitle: 'TTS、STT 和翻译',
            children: const [
              _TtsTile(),
              _SttTile(),
              _TranslationTile(),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: _buildSettingCard(
            icon: CupertinoIcons.paintbrush,
            iconColor: const Color(0xFF26A69A),
            title: '外观',
            subtitle: '背景、主页和精灵图',
            children: [
              KiraGroupedTile(
                icon: CupertinoIcons.photo,
                iconBg: Colors.transparent,
                iconColor: const Color(0xFF26A69A),
                title: l10n.backgrounds,
                onTap: () => showBackgroundSettingsDialog(context, ref),
              ),
              KiraGroupedTile(
                icon: CupertinoIcons.house,
                iconBg: Colors.transparent,
                iconColor: DesignTokens.primary,
                title: '主页外观',
                subtitle: '主页背景与音乐',
                onTap: () => showAppearanceSettingsDialog(context, ref),
              ),
              KiraGroupedTile(
                icon: CupertinoIcons.sparkles,
                iconBg: Colors.transparent,
                iconColor: const Color(0xFFFFCA28),
                title: '精灵图',
                onTap: () => showSpriteSettingsDialog(context, ref),
              ),
            ],
          ),
        ),
      ),
      // Data and diagnostics
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: _buildSettingCard(
            icon: CupertinoIcons.chart_bar,
            iconColor: const Color(0xFF26A69A),
            title: '数据与诊断',
            subtitle: '用量统计与日志',
            children: [
              KiraGroupedTile(
                icon: CupertinoIcons.chart_bar,
                iconBg: Colors.transparent,
                iconColor: const Color(0xFF26A69A),
                title: '用量统计',
                subtitle: '消息、Token 用量与生成性能',
                onTap: () => showStatisticsDialog(context, ref),
              ),
              KiraGroupedTile(
                icon: CupertinoIcons.doc_text,
                iconBg: Colors.transparent,
                iconColor: const Color(0xFF8E8E93),
                title: '日志查看器',
                subtitle: '调试日志导出与清空',
                onTap: () => showLogViewerDialog(context),
              ),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: _buildSettingCard(
            icon: CupertinoIcons.info_circle,
            iconColor: const Color(0xFF8E8E93),
            title: l10n.about,
            children: [
              KiraGroupedTile(
                icon: CupertinoIcons.info_circle,
                iconBg: Colors.transparent,
                iconColor: const Color(0xFF42A5F5),
                title: '关于 KiraKira',
                onTap: () => context.push(AppRoutes.about),
              ),
              KiraGroupedTile(
                icon: CupertinoIcons.heart,
                iconBg: Colors.transparent,
                iconColor: const Color(0xFFEC407A),
                title: '支持 KiraKira',
                subtitle: '免费开源,欢迎赞助支持开发',
                onTap: () => launchUrl(
                  Uri.parse('https://ifdian.net/a/KiraKira-APP'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              const _VersionTile(),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildSettingCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        items.add(const Divider(height: 1, thickness: 0.5, indent: 56));
      }
      items.add(children[i]);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isDark
            ? null
            : Border.all(
                color: Colors.black.withValues(alpha: 0.05),
                width: 0.5,
              ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFF0F0F0)
                              : const Color(0xFF2C2C2C),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFF8C8C8C)
                                : const Color(0xFF8E8E93),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5),
          ...items,
        ],
      ),
    );
  }

  /// Search state: filter the index into a result list
  List<Widget> _searchSlivers() {
    final q = _query.toLowerCase();
    final hits = kSettingsIndex
        .where((e) =>
            e.title.toLowerCase().contains(q) ||
            e.keywords.toLowerCase().contains(q))
        .toList();

    if (hits.isEmpty) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Text(
              '无“$_query”相关设置',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ];
    }

    return [
      SliverToBoxAdapter(
        child: KiraSection(
          title: '搜索结果',
          children: [
            for (final e in hits)
              KiraGroupedTile(
                icon: e.icon,
                iconBg: Colors.transparent,
                iconColor: DesignTokens.primary,
                title: e.title,
                subtitle: e.section,
                onTap: () {
                  if (e.dialog != null) {
                    _openSearchDialog(context, ref, e.dialog!);
                  } else {
                    context.push(e.route);
                  }
                },
              ),
          ],
        ),
      ),
    ];
  }

  /// Search index dialog dispatch: dialog key to the migrated dialog.
  /// Original sub-page routes were removed; search results open dialogs directly.
  void _openSearchDialog(
      BuildContext context, WidgetRef ref, String dialog) {
    switch (dialog) {
      case 'tts':
        showTtsSettingsDialog(context, ref);
      case 'stt':
        showSttSettingsDialog(context, ref);
      case 'translation':
        showTranslationSettingsDialog(context, ref);
      case 'statistics':
        showStatisticsDialog(context, ref);
      case 'logs':
        showLogViewerDialog(context);
      case 'tokenizer':
        showTokenizerDialog(context, ref);
      case 'advancedSampling':
        showAdvancedSamplingDialog(context, ref);
      case 'logitBias':
        showLogitBiasDialog(context, ref);
      case 'aiPresets':
        showAIPresetDialog(context, ref);
      case 'regex':
        showRegexSystemDialog(context, ref);
      case 'promptManager':
        showPromptManagerDialog(context, ref);
      case 'cfgScale':
        showCfgScaleDialog(context, ref);
      case 'mvu':
        showMvuDialog(context, ref);
      case 'variables':
        showVariablesDialog(context, ref);
      case 'chronicle':
        showChronicleSettingsDialog(context, ref);
      case 'globalWorldbook':
        showGlobalWorldbookDialog(context, ref);
      case 'background':
        showBackgroundSettingsDialog(context, ref);
      case 'appearance':
        showAppearanceSettingsDialog(context, ref);
      case 'sprite':
        showSpriteSettingsDialog(context, ref);
      case 'persona':
        showPersonaSettingsDialog(context, ref);
      default:
        coreToast(context, '该设置项暂未开放');
    }
  }
}

/// User info card (pinned at the top of settings): shows the active persona avatar and name; taps open persona management.
/// Data source is activePersonaProvider (manual selection overrides default), shared with the "persona" row;
/// PersonaNotifier invalidates the provider after a persona edit is saved, so this card refreshes automatically.
class _UserInfoCard extends ConsumerWidget {
  const _UserInfoCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final persona = ref.watch(activePersonaProvider).valueOrNull;

    final name = persona?.name ?? l10n.default_;
    final description = persona?.description ?? '';
    final avatarPath = persona?.avatarPath;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1C1C1C).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showPersonaSettingsDialog(context, ref),
          borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildAvatar(theme, name, avatarPath),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? DesignTokens.darkTextPrimary
                              : DesignTokens.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description.isNotEmpty
                            ? description
                            : '点击查看和编辑人设',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? DesignTokens.darkTextSecondary
                              : DesignTokens.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 18,
                  color: isDark
                      ? DesignTokens.darkTextSecondary
                      : DesignTokens.lightTextSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme, String name, String? avatarPath) {
    if (avatarPath != null && avatarPath.isNotEmpty) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: DesignTokens.primary,
            width: 2.5,
          ),
        ),
        child: CircleAvatar(
          radius: 26,
          backgroundImage: FileImage(File(avatarPath)),
          backgroundColor: Colors.transparent,
        ),
      );
    }
    final initial =
        name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: DesignTokens.primary,
          width: 2.5,
        ),
      ),
      child: CircleAvatar(
        radius: 26,
        backgroundColor: DesignTokens.primary.withValues(alpha: 0.12),
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: DesignTokens.primary,
          ),
        ),
      ),
    );
  }
}

/// Dark mode toggle (dark = "Star River Dream", light = "Sea and Sky")
class _DarkModeTile extends ConsumerWidget {
  const _DarkModeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(activeThemeConfigProvider).isDark;
    return KiraSwitchTile(
      icon: CupertinoIcons.moon_stars,
      iconBg: Colors.transparent,
      iconColor: const Color(0xFFFFA726),
      title: '深色模式',
      subtitle: isDark ? '星河入梦' : '海天一色',
      value: isDark,
      onChanged: (v) {
        ref.read(activeThemeIdProvider.notifier).setActiveTheme(
              v ? BuiltInThemes.defaultDark.id : BuiltInThemes.defaultLight.id,
            );
      },
    );
  }
}

/// Language (General group, triggers the language selection sheet)
class _LanguageTile extends ConsumerWidget {
  const _LanguageTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final currentLocale = ref.watch(localeProvider);

    String currentLanguage = l10n.systemTheme;
    if (currentLocale != null) {
      final supportedLocale = supportedLocales.where((sl) {
        if (currentLocale.countryCode != null) {
          return sl.locale.languageCode == currentLocale.languageCode &&
              sl.locale.countryCode == currentLocale.countryCode;
        }
        return sl.locale.languageCode == currentLocale.languageCode &&
            sl.locale.countryCode == null;
      }).firstOrNull;
      if (supportedLocale != null) {
        currentLanguage =
            '${supportedLocale.nativeName} (${supportedLocale.displayName})';
      }
    }

    return KiraGroupedTile(
      icon: CupertinoIcons.globe,
      iconBg: Colors.transparent,
      iconColor: const Color(0xFF42A5F5),
      title: l10n.language,
      subtitle: currentLanguage,
      onTap: () => _showLanguageSelector(context, ref),
    );
  }

  void _showLanguageSelector(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final currentLocale = ref.read(localeProvider);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusBottomSheet),
        ),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    l10n.selectLanguage,
                    style: const TextStyle(
                      fontSize: DesignTokens.fontSizeXl,
                      fontWeight: DesignTokens.weightSemibold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  ListTile(
                    leading: const Icon(Icons.phone_android),
                    title: Text(l10n.systemTheme),
                    trailing: currentLocale == null
                        ? Icon(Icons.check,
                            color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () {
                      ref.read(localeProvider.notifier).resetToSystem();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.languageChanged)),
                      );
                    },
                  ),
                  const Divider(),
                  ...supportedLocales.map((sl) {
                    final isSelected = currentLocale != null &&
                        currentLocale.languageCode == sl.locale.languageCode &&
                        currentLocale.countryCode == sl.locale.countryCode;

                    return ListTile(
                      title: Text(sl.nativeName),
                      subtitle: Text(sl.displayName),
                      trailing: isSelected
                          ? Icon(Icons.check,
                              color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () {
                        ref.read(localeProvider.notifier).setLocale(sl.locale);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.languageChanged)),
                        );
                      },
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Version row (not tappable, closes the About group)
class _VersionTile extends StatelessWidget {
  const _VersionTile();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return KiraGroupedTile(
      icon: CupertinoIcons.number,
      iconBg: Colors.transparent,
      iconColor: const Color(0xFF8E8E93),
      title: l10n.version,
      subtitle: '1.0.0 (Build 1)',
      trailing: IconButton(
        icon: const Icon(CupertinoIcons.doc_on_clipboard, size: 18),
        tooltip: l10n.copiedToClipboard,
        onPressed: () {
          Clipboard.setData(const ClipboardData(text: '1.0.0 (Build 1)'));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${l10n.copiedToClipboard}: 1.0.0 (Build 1)'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }
}

// Chat settings / voice and translation group rows

/// Stream output (chat settings group, sourced from llmConfigProvider.streamEnabled, same source as the API screen)
class _StreamOutputTile extends ConsumerWidget {
  const _StreamOutputTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(llmConfigProvider);
    return KiraGroupedTile(
      icon: CupertinoIcons.bolt,
      iconBg: Colors.transparent,
      iconColor: const Color(0xFF42A5F5),
      title: '流式输出',
      subtitle: config.streamEnabled ? '实时显示生成内容' : '整段返回后显示',
      trailing: CupertinoSwitch(
        value: config.streamEnabled,
        onChanged: (v) => ref
            .read(llmConfigProvider.notifier)
            .updateStreamEnabled(v),
        activeTrackColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

/// Tokenizer count (chat settings group, sourced from tokenizerSettingsProvider.showTokenCount)
class _TokenizerCountTile extends ConsumerWidget {
  const _TokenizerCountTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTokenCount =
        ref.watch(tokenizerSettingsProvider).showTokenCount;
    return KiraGroupedTile(
      icon: CupertinoIcons.textformat_abc,
      iconBg: Colors.transparent,
      iconColor: DesignTokens.primary,
      title: '分词器计数',
      subtitle: showTokenCount ? '输入框旁显示' : '已停用',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoSwitch(
            value: showTokenCount,
            onChanged: (v) => ref
                .read(tokenizerSettingsProvider.notifier)
                .setShowTokenCount(v),
            activeTrackColor: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Icon(
            CupertinoIcons.chevron_forward,
            size: 16,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ],
      ),
      onTap: () => showTokenizerDialog(context, ref),
    );
  }
}

/// TTS synthesis (voice and translation group: inline switch, chevron opens the full config dialog)
class _TtsTile extends ConsumerWidget {
  const _TtsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tts = ref.watch(ttsSettingsProvider);
    return KiraGroupedTile(
      icon: CupertinoIcons.speaker_2,
      iconBg: Colors.transparent,
      iconColor: const Color(0xFFFFA726),
      title: 'TTS 合成',
      subtitle: tts.enabled
          ? '${tts.rate.toStringAsFixed(1)}× ${tts.voiceId ?? '默认'}'
          : '已停用',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoSwitch(
            value: tts.enabled,
            onChanged: (v) =>
                ref.read(ttsSettingsProvider.notifier).setEnabled(v),
            activeTrackColor: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Icon(
            CupertinoIcons.chevron_forward,
            size: 16,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ],
      ),
      onTap: () => showTtsSettingsDialog(context, ref),
    );
  }
}

/// STT recognition (voice and translation group)
class _SttTile extends ConsumerWidget {
  const _SttTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stt = ref.watch(sttSettingsProvider);
    return KiraGroupedTile(
      icon: CupertinoIcons.mic,
      iconBg: Colors.transparent,
      iconColor: const Color(0xFFEC407A),
      title: 'STT 识别',
      subtitle: stt.enabled
          ? '${stt.language} · ${stt.autoSend ? '自动发送' : '手动'}'
          : '已停用',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoSwitch(
            value: stt.enabled,
            onChanged: (v) =>
                ref.read(sttSettingsProvider.notifier).setEnabled(v),
            activeTrackColor: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Icon(
            CupertinoIcons.chevron_forward,
            size: 16,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ],
      ),
      onTap: () => showSttSettingsDialog(context, ref),
    );
  }
}

/// Translation (voice and translation group)
class _TranslationTile extends ConsumerWidget {
  const _TranslationTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trans = ref.watch(translationSettingsProvider);
    return KiraGroupedTile(
      icon: CupertinoIcons.globe,
      iconBg: Colors.transparent,
      iconColor: DesignTokens.primary,
      title: '翻译',
      subtitle: trans.enabled
          ? '${trans.sourceLanguage}⇄${trans.targetLanguage}${trans.autoTranslateIncoming ? ' · 入站' : ''}'
          : '已停用',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoSwitch(
            value: trans.enabled,
            onChanged: (v) => ref
                .read(translationSettingsProvider.notifier)
                .setEnabled(v),
            activeTrackColor: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Icon(
            CupertinoIcons.chevron_forward,
            size: 16,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ],
      ),
      onTap: () => showTranslationSettingsDialog(context, ref),
    );
  }
}
