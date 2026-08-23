import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/presentation/providers/advanced_mode_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/providers/locale_provider.dart';
import 'package:kirakira/presentation/providers/persona_providers.dart';
import 'package:kirakira/presentation/providers/settings_providers.dart';
import 'package:kirakira/presentation/router/app_router.dart';
import 'package:kirakira/presentation/theme/app_theme.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/screens/settings/log_view_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kirakira/presentation/providers/theme_providers.dart';
import 'package:kirakira/data/models/app_theme_config.dart';
import 'package:kirakira/presentation/widgets/common/kira_components.dart';

/// Settings screen - App settings only (AI config is in separate tab)
class SettingsScreen extends ConsumerWidget {
  /// 底部导航避让区(工程尺寸,不进 token)
  static const double _bottomNavClearance = 100;

  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: _bottomNavClearance),
        children: [
          const SizedBox(height: 8),

          KiraSection(
            title: l10n.user,
            icon: Icons.person_outline,
            children: [
              _PersonaTile(),
            ],
          ),

          KiraSection(
            title: l10n.chats,
            icon: Icons.chat_bubble_outline,
            children: [
              KiraListTile(
                icon: Icons.wallpaper,
                title: l10n.backgrounds,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.backgroundSettings),
              ),
              KiraListTile(
                icon: Icons.home_outlined,
                title: '主页外观',
                subtitle: '主页背景与音乐',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.homeAppearance),
              ),
            ],
          ),

          KiraSection(
            title: l10n.advanced,
            icon: Icons.tune,
            children: [
              KiraSwitchTile(
                icon: Icons.auto_awesome,
                title: '极客Core',
                subtitle: 'ROOT模式 · 解锁全部高级功能',
                value: ref.watch(advancedModeProvider),
                onChanged: (v) =>
                    ref.read(advancedModeProvider.notifier).toggle(v),
              ),
              KiraSwitchTile(
                icon: Icons.dark_mode,
                title: '深色主题',
                subtitle: '关闭切换为海天一色亮色',
                value: ref.watch(activeThemeConfigProvider).isDark,
                onChanged: (v) {
                  ref.read(activeThemeIdProvider.notifier).setActiveTheme(
                        v
                            ? BuiltInThemes.defaultDark.id
                            : BuiltInThemes.defaultLight.id,
                      );
                },
              ),
            ],
          ),

          KiraSection(
            title: l10n.about,
            icon: Icons.info_outline,
            children: [
              KiraListTile(
                icon: Icons.info_outline,
                title: l10n.version,
                subtitle: '1.0.0 (Build 1)',
                onTap: () {
                  Clipboard.setData(
                      const ClipboardData(text: '1.0.0 (Build 1)'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '${l10n.copiedToClipboard}: 1.0.0 (Build 1)'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              KiraListTile(
                icon: Icons.description,
                title: l10n.licenses,
                onTap: () => showLicensePage(context: context),
              ),
              KiraListTile(
                icon: Icons.gavel,
                title: '开源许可',
                subtitle:
                    'KiraKira 基于 AGPL-3.0 协议发布。\n'
                    '本程序不提供任何担保，使用风险由用户自行承担。\n'
                    '版权所有 © 2026 北辰星',
              ),
              KiraListTile(
                icon: Icons.code,
                title: '基于开源项目',
                subtitle:
                    '本项目是 NativeTavern 的修改版本，自 2026 年起修改开发。\n'
                    '点击查看 KiraKira 完整源码仓库。',
                onTap: () => launchUrl(
                  Uri.parse('https://github.com/beichenxingI/KiraKira'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              KiraListTile(
                icon: Icons.favorite,
                title: '支持 KiraKira',
                subtitle: 'KiraKira 免费开源，若它对你有帮助，欢迎赞助支持开发 🌟',
                onTap: () => launchUrl(
                  Uri.parse('https://ifdian.net/a/KiraKira-APP'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              KiraListTile(
                // TODO(Block5): About 页路由由 Block5 接管,此处仅占位
                icon: Icons.info_outline,
                title: l10n.about,
                trailing: const Icon(Icons.chevron_right,
                    color: DesignTokens.textMuted),
                onTap: null,
              ),
            ],
          ),

          const SizedBox(height: DesignTokens.spaceLg),
        ],
      ),
    );
  }
}

class _PersonaTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final activePersonaAsync = ref.watch(activePersonaProvider);

    return ListTile(
      leading: const Icon(Icons.person),
      title: Text(l10n.personas),
      subtitle: activePersonaAsync.when(
        loading: () => Text(l10n.loading),
        error: (_, __) => Text(l10n.error),
        data: (persona) => Text(persona?.name ?? l10n.default_),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(AppRoutes.personas),
      onLongPress: () {
        final personaName = activePersonaAsync.valueOrNull?.name ?? l10n.default_;
        Clipboard.setData(ClipboardData(text: personaName));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.copiedToClipboard}: $personaName'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }
}

class _ConfirmDeleteTile extends ConsumerWidget {
  const _ConfirmDeleteTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsProvider);

    return SwitchListTile(
      secondary: const Icon(Icons.delete_forever),
      title: Text(l10n.delete),
      value: settings.confirmBeforeDelete,
      onChanged: (value) {
        ref.read(appSettingsProvider.notifier).updateConfirmBeforeDelete(value);
      },
    );
  }
}

class _AutoSaveTile extends ConsumerWidget {
  const _AutoSaveTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsProvider);

    return SwitchListTile(
      secondary: const Icon(Icons.save),
      title: Text(l10n.save),
      value: settings.autoSaveChats,
      onChanged: (value) {
        ref.read(appSettingsProvider.notifier).updateAutoSaveChats(value);
      },
    );
  }
}

class _DebugLogTile extends ConsumerWidget {
  const _DebugLogTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsProvider);

    return SwitchListTile(
      secondary: const Icon(Icons.bug_report),
      title: Text(l10n.debugLog),
      subtitle: Text(l10n.debugLogDescription),
      value: settings.enableDebugLog,
      onChanged: (value) {
        ref.read(appSettingsProvider.notifier).updateDebugLog(value);
      },
    );
  }
}

class _LanguageTile extends ConsumerWidget {
  const _LanguageTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final currentLocale = ref.watch(localeProvider);
    
    // Find the current locale's display name
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
        currentLanguage = '${supportedLocale.nativeName} (${supportedLocale.displayName})';
      }
    }

    return ListTile(
      leading: const Icon(Icons.language),
      title: Text(l10n.language),
      subtitle: Text(currentLanguage),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showLanguageSelector(context, ref),
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: currentLanguage));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.copiedToClipboard}: $currentLanguage'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }

  void _showLanguageSelector(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final currentLocale = ref.read(localeProvider);
    
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
                  // System default option
                  ListTile(
                    leading: const Icon(Icons.phone_android),
                    title: Text(l10n.systemTheme),
                    trailing: currentLocale == null
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: () {
                      ref.read(localeProvider.notifier).resetToSystem();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.languageChanged),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  // All supported locales
                  ...supportedLocales.map((sl) {
                    final isSelected = currentLocale != null &&
                        currentLocale.languageCode == sl.locale.languageCode &&
                        currentLocale.countryCode == sl.locale.countryCode;
                    
                    return ListTile(
                      title: Text(sl.nativeName),
                      subtitle: Text(sl.displayName),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                      onTap: () {
                        ref.read(localeProvider.notifier).setLocale(sl.locale);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.languageChanged),
                          ),
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