import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/presentation/providers/advanced_mode_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/providers/locale_provider.dart';
import 'package:kirakira/presentation/providers/persona_providers.dart';
import 'package:kirakira/presentation/router/app_router.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kirakira/presentation/providers/theme_providers.dart';
import 'package:kirakira/data/models/app_theme_config.dart';
import 'package:kirakira/presentation/widgets/common/common.dart';
import 'settings_search_index.dart';


/// 设置主页(C-T4 + E-T2):Large Title + 6 组 inset-grouped + 设置内搜索
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
    final iconBg = Theme.of(context).colorScheme.primary.withValues(alpha: 0.12);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(
              l10n.settings,
              style: Theme.of(context).textTheme.displayLarge,
            ),
          ),
          // ── 设置内搜索(E-T2 落地;C-T4 的占位)──
          SliverToBoxAdapter(
            child: KiraSearchBar(
              controller: _searchController,
              hintText: '搜索设置',
              onChanged: (q) => setState(() => _query = q.trim()),
              onClear: () => setState(() => _query = ''),
            ),
          ),
          ...(_query.isNotEmpty
              ? _searchSlivers()
              : _homeSlivers(context, l10n, iconBg)),
          // 避让底栏
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }

  /// 主页 6 组(C-T4 信息架构,原样)
  List<Widget> _homeSlivers(
      BuildContext context, AppLocalizations l10n, Color iconBg) {
    return [
          // ══ 置顶高频组(无组头)══
          SliverToBoxAdapter(
            child: KiraSection(
              title: '',
              children: [
                _DarkModeTile(),
                _LanguageTile(),
                _PersonaTile(),
              ],
            ),
          ),

          // ══ 外观 ══
          SliverToBoxAdapter(
            child: KiraSection(
              title: '外观',
              children: [
                KiraGroupedTile(
                  icon: CupertinoIcons.paintbrush, iconBg: iconBg,
                  title: '主题',
                  onTap: () => context.push(AppRoutes.themeSettings),
                ),
                KiraGroupedTile(
                  icon: CupertinoIcons.photo, iconBg: iconBg,
                  title: l10n.backgrounds,
                  onTap: () => context.push(AppRoutes.backgroundSettings),
                ),
                KiraGroupedTile(
                  icon: CupertinoIcons.house, iconBg: iconBg,
                  title: '主页外观',
                  subtitle: '主页背景与音乐',
                  onTap: () => context.push(AppRoutes.homeAppearance),
                ),
                KiraGroupedTile(
                  icon: CupertinoIcons.smiley, iconBg: iconBg,
                  title: '精灵图', // TODO(i18n): 待补 l10n key
                  onTap: () => context.push(AppRoutes.spriteSettings),
                ),
              ],
            ),
          ),

          // ══ 模型与生成 ══
          SliverToBoxAdapter(
            child: KiraSection(
              title: '模型与生成',
              children: [
                KiraGroupedTile(
                  icon: CupertinoIcons.star, iconBg: iconBg,
                  title: 'AI 预设',
                  onTap: () => context.push(AppRoutes.aiPresets),
                ),
                KiraGroupedTile(
                  icon: CupertinoIcons.slider_horizontal_3, iconBg: iconBg,
                  title: '采样参数',
                  onTap: () => context.push(AppRoutes.advancedSettings),
                ),
                KiraGroupedTile(
                  icon: CupertinoIcons.speedometer, iconBg: iconBg,
                  title: 'CFG Scale',
                  onTap: () => context.push(AppRoutes.cfgScaleSettings),
                ),
                KiraGroupedTile(
                  icon: CupertinoIcons.line_horizontal_3_decrease, iconBg: iconBg,
                  title: 'Logit Bias',
                  onTap: () => context.push(AppRoutes.logitBiasSettings),
                ),
                KiraGroupedTile(
                  icon: CupertinoIcons.textformat_abc, iconBg: iconBg,
                  title: '分词器',
                  onTap: () => context.push(AppRoutes.tokenizerSettings),
                ),
                KiraGroupedTile(
                  icon: CupertinoIcons.list_bullet, iconBg: iconBg,
                  title: l10n.promptManager,
                  onTap: () => context.push(AppRoutes.promptManager),
                ),
                KiraGroupedTile(
                  icon: CupertinoIcons.cube_box, iconBg: iconBg,
                  title: '变量框架 MVU',
                  onTap: () => context.push(AppRoutes.mvuSettings),
                ),
              ],
            ),
          ),

          // ══ 工具链 ══
          SliverToBoxAdapter(
            child: KiraSection(
              title: '工具链',
              children: [
                KiraGroupedTile(
                  icon: CupertinoIcons.speaker_2, iconBg: iconBg,
                  title: 'TTS 合成',
                  onTap: () => context.push(AppRoutes.ttsSettings),
                ),
                KiraGroupedTile(
                  icon: CupertinoIcons.mic, iconBg: iconBg,
                  title: 'STT 识别',
                  onTap: () => context.push(AppRoutes.sttSettings),
                ),
                KiraGroupedTile(
                  icon: CupertinoIcons.globe, iconBg: iconBg,
                  title: l10n.translationSettings,
                  onTap: () => context.push(AppRoutes.translationSettings),
                ),
                KiraGroupedTile(
                  icon: CupertinoIcons.photo_on_rectangle, iconBg: iconBg,
                  title: '图片生成',
                  onTap: () => context.push(AppRoutes.imageGenSettings),
                ),
                KiraGroupedTile(
                  icon: CupertinoIcons.wand_stars, iconBg: iconBg,
                  title: '正则系统',
                  onTap: () => context.push(AppRoutes.regexSettings),
                ),
                KiraGroupedTile(
                  icon: CupertinoIcons.square_list, iconBg: iconBg,
                  title: '变量管理',
                  onTap: () => context.push(AppRoutes.variablesSettings),
                ),
                KiraGroupedTile(
                  icon: CupertinoIcons.square_stack_3d_up, iconBg: iconBg,
                  title: '向量存储 RAG',
                  onTap: () => context.push(AppRoutes.vectorStorageSettings),
                ),
              ],
            ),
          ),

          // ══ 数据与诊断 ══
          SliverToBoxAdapter(
            child: KiraSection(
              title: '数据与诊断',
              children: [
                KiraGroupedTile(
                  icon: CupertinoIcons.chart_bar, iconBg: iconBg,
                  title: '日志统计',
                  onTap: () => context.push(AppRoutes.statistics),
                ),
                KiraGroupedTile(
                  icon: CupertinoIcons.doc_text, iconBg: iconBg,
                  title: '日志查看器',
                  onTap: () => context.push(AppRoutes.settingsLogs),
                ),
                KiraGroupedTile(
                  icon: CupertinoIcons.command, iconBg: iconBg,
                  title: '极客 Core',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(DesignTokens.radiusSm),
                        ),
                        child: Text(
                          '高级',
                          style: TextStyle(
                            fontSize: DesignTokens.fontSizeXs,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        CupertinoIcons.chevron_forward,
                        size: 16,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ],
                  ),
                  onTap: () => context.push(AppRoutes.advanced),
                ),
              ],
            ),
          ),

          // ══ 关于 ══
          SliverToBoxAdapter(
            child: KiraSection(
              title: l10n.about,
              children: [
                KiraGroupedTile(
                  icon: CupertinoIcons.info_circle, iconBg: iconBg,
                  title: '关于 KiraKira',
                  onTap: () => context.push(AppRoutes.about),
                ),
                KiraGroupedTile(
                  icon: CupertinoIcons.heart, iconBg: iconBg,
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
    ];
  }

  /// E-T2 搜索态:过滤索引出结果列表;空态给文案
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
                iconBg: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.12),
                title: e.title,
                subtitle: e.section,
                onTap: () => context.push(e.route),
              ),
          ],
        ),
      ),
    ];
  }
}

/// 深色主题开关(置顶高频组,真实绑 activeThemeIdProvider)
class _DarkModeTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return KiraSwitchTile(
      icon: CupertinoIcons.moon,
      iconBg: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
      title: '深色主题',
      value: ref.watch(activeThemeConfigProvider).isDark,
      onChanged: (v) {
        ref.read(activeThemeIdProvider.notifier).setActiveTheme(
              v ? BuiltInThemes.defaultDark.id : BuiltInThemes.defaultLight.id,
            );
      },
    );
  }
}

/// 用户画像(置顶高频组,push /personas)
class _PersonaTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final activePersonaAsync = ref.watch(activePersonaProvider);

    return KiraGroupedTile(
      icon: CupertinoIcons.person,
      iconBg: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
      title: l10n.personas,
      subtitle: activePersonaAsync.when(
        loading: () => l10n.loading,
        error: (_, __) => l10n.error,
        data: (persona) => persona?.name ?? l10n.default_,
      ),
      onTap: () => context.push(AppRoutes.personas),
    );
  }
}

/// 语言(置顶高频组,触发语言选择 Sheet)
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
      iconBg: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
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

/// 版本号说明行(不可点,关于组收尾)
class _VersionTile extends StatelessWidget {
  const _VersionTile();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return KiraGroupedTile(
      icon: CupertinoIcons.number,
      iconBg: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
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