// lib/presentation/screens/about/about_screen.dart
/// 关于页 · 版本号 + 版权 + 开源信息
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/widgets/common/kira_components.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l10n.about)),
      body: ListView(
        padding: DesignTokens.paddingScreen,
        children: [
          const SizedBox(height: DesignTokens.space2xl),
          // 品牌区
          Center(
            child: Column(
              children: [
                // 品牌图标容器:胶囊圆角(本页无独立 logo 资源,用 auto_awesome 符号)
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: DesignTokens.primary.withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(DesignTokens.radiusFull),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 48,
                    color: DesignTokens.primary,
                  ),
                ),
                const SizedBox(height: DesignTokens.spaceLg),
                // 版本号:fontSize3xl w700
                const Text(
                  'KiraKira',
                  style: TextStyle(
                    fontSize: DesignTokens.fontSize3xl,
                    fontWeight: DesignTokens.weightBold,
                    color: DesignTokens.darkTextPrimary,
                  ),
                ),
                const SizedBox(height: DesignTokens.spaceXs),
                const Text(
                  '1.0.0 (Build 1)',
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeBodyMedium,
                    color: DesignTokens.darkTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.space2xl),
          // 开源信息卡
          KiraSection(
            title: l10n.about,
            icon: Icons.info_outline,
            children: [
              KiraListTile(
                icon: Icons.gavel,
                title: l10n.licenses,
                trailing: const Icon(Icons.chevron_right,
                    color: DesignTokens.darkTextTertiary),
                onTap: () => showLicensePage(context: context),
              ),
              KiraListTile(
                icon: Icons.code,
                title: 'GitHub',
                subtitle: 'github.com/beichenxingI/KiraKira',
                trailing: const Icon(Icons.chevron_right,
                    color: DesignTokens.darkTextTertiary),
                onTap: () => launchUrl(
                  Uri.parse('https://github.com/beichenxingI/KiraKira'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          // 版权
          const Center(
            child: Text(
              'AGPL-3.0 License · © 2026 KiraKira\n基于 NativeTavern 修改',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: DesignTokens.fontSizeXs,
                color: DesignTokens.darkTextTertiary,
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.space2xl),
        ],
      ),
    );
  }
}
