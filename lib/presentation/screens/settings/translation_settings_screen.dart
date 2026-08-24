import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/domain/services/translation_service.dart';
import 'package:kirakira/presentation/providers/translation_providers.dart';
import 'package:kirakira/presentation/theme/app_theme.dart';
import 'package:kirakira/presentation/widgets/common/common.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';

/// Screen for translation settings
class TranslationSettingsScreen extends ConsumerWidget {
  const TranslationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(translationSettingsProvider);
    final iconBg = Theme.of(context).colorScheme.primary.withValues(alpha: 0.12);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(
              l10n.translationSettings,
              style: Theme.of(context).textTheme.displayLarge,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.restore),
                tooltip: l10n.resetToDefaults,
                onPressed: () {
                  ref.read(translationSettingsProvider.notifier).reset();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.settingsResetToDefaults)),
                  );
                },
              ),
            ],
          ),

          // ── 通用 ──
          SliverToBoxAdapter(
            child: KiraSection(
              title: l10n.general,
              children: [
                KiraSwitchTile(
                  title: l10n.enableTranslation,
                  subtitle: l10n.translateMessagesAutomatically,
                  value: settings.enabled,
                  onChanged: (value) {
                    ref.read(translationSettingsProvider.notifier).setEnabled(value);
                  },
                ),
                KiraSwitchTile(
                  title: l10n.translateAiResponses,
                  subtitle: l10n.translateAiResponses,
                  value: settings.autoTranslateIncoming,
                  onChanged: settings.enabled
                      ? (value) {
                          ref.read(translationSettingsProvider.notifier).setAutoTranslateIncoming(value);
                        }
                      : null,
                ),
                KiraSwitchTile(
                  title: l10n.translateUserMessages,
                  subtitle: l10n.translateUserMessages,
                  value: settings.autoTranslateOutgoing,
                  onChanged: settings.enabled
                      ? (value) {
                          ref.read(translationSettingsProvider.notifier).setAutoTranslateOutgoing(value);
                        }
                      : null,
                ),
                KiraSwitchTile(
                  title: '显示原文',
                  subtitle: '在翻译旁显示原文',
                  value: settings.showOriginal,
                  onChanged: settings.enabled
                      ? (value) {
                          ref.read(translationSettingsProvider.notifier).setShowOriginal(value);
                        }
                      : null,
                ),
              ],
            ),
          ),

          // ── 提供商 ──
          SliverToBoxAdapter(
            child: KiraSection(
              title: l10n.provider,
              children: [
                KiraGroupedTile(
                  title: l10n.translationProvider,
                  subtitle: settings.provider.displayName,
                  trailing: DropdownButton<TranslationProvider>(
                    value: settings.provider,
                    underline: const SizedBox.shrink(),
                    onChanged: settings.enabled
                        ? (value) {
                            if (value != null) {
                              ref.read(translationSettingsProvider.notifier).setProvider(value);
                            }
                          }
                        : null,
                    items: TranslationProvider.values.map((provider) {
                      return DropdownMenuItem(
                        value: provider,
                        child: Text(provider.displayName),
                      );
                    }).toList(),
                  ),
                ),
                if (settings.provider != TranslationProvider.libre)
                  KiraGroupedTile(
                    title: l10n.apiKey,
                    subtitle: settings.apiKey?.isNotEmpty == true
                        ? '••••••••${settings.apiKey!.substring(settings.apiKey!.length - 4)}'
                        : l10n.notConfigured,
                    onTap: settings.enabled
                        ? () => _showApiKeySheet(context, ref, settings)
                        : null,
                  ),
              ],
            ),
          ),

          // ── 语言 ──
          SliverToBoxAdapter(
            child: KiraSection(
              title: l10n.language,
              children: [
                KiraGroupedTile(
                  title: l10n.sourceLanguage,
                  trailing: DropdownButton<String>(
                    value: settings.sourceLanguage,
                    underline: const SizedBox.shrink(),
                    onChanged: settings.enabled
                        ? (value) {
                            if (value != null) {
                              ref.read(translationSettingsProvider.notifier).setSourceLanguage(value);
                            }
                          }
                        : null,
                    items: TranslationLanguage.supportedLanguages.map((lang) {
                      return DropdownMenuItem(
                        value: lang.code,
                        child: Text(lang.name),
                      );
                    }).toList(),
                  ),
                ),
                KiraGroupedTile(
                  icon: CupertinoIcons.arrow_up_arrow_down,
                  iconBg: iconBg,
                  title: '交换语言',
                  onTap: settings.enabled && settings.sourceLanguage != 'auto'
                      ? () {
                          ref.read(translationSettingsProvider.notifier).swapLanguages();
                        }
                      : null,
                ),
                KiraGroupedTile(
                  title: l10n.targetLanguage,
                  trailing: DropdownButton<String>(
                    value: settings.targetLanguage,
                    underline: const SizedBox.shrink(),
                    onChanged: settings.enabled
                        ? (value) {
                            if (value != null) {
                              ref.read(translationSettingsProvider.notifier).setTargetLanguage(value);
                            }
                          }
                        : null,
                    items: TranslationLanguage.targetLanguages.map((lang) {
                      return DropdownMenuItem(
                        value: lang.code,
                        child: Text(lang.name),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // ── 测试 ──
          SliverToBoxAdapter(
            child: KiraSection.plain(
              title: l10n.test,
              child: _TranslationTestWidget(enabled: settings.enabled),
            ),
          ),

          // ── 信息 ──
          SliverToBoxAdapter(
            child: KiraSection.plain(
              title: l10n.information,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceMd,
                  vertical: DesignTokens.spaceSm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _InfoRow(
                      icon: CupertinoIcons.info,
                      title: '关于翻译',
                      text: 'Translation allows you to communicate in different languages. '
                          'Messages can be automatically translated or translated on demand.',
                    ),
                    if (settings.provider == TranslationProvider.google)
                      const _InfoRow(
                        icon: CupertinoIcons.cloud,
                        title: 'Google Translate',
                        text: 'Uses Google Cloud Translation API. '
                            'Requires an API key from Google Cloud Console.',
                      ),
                    if (settings.provider == TranslationProvider.deepl)
                      const _InfoRow(
                        icon: CupertinoIcons.cloud,
                        title: 'DeepL',
                        text: 'High-quality neural machine translation. '
                            'Requires an API key from deepl.com',
                      ),
                    if (settings.provider == TranslationProvider.libre)
                      const _InfoRow(
                        icon: CupertinoIcons.globe,
                        title: 'LibreTranslate',
                        text: 'Free and open-source translation. '
                            'Can be self-hosted or use public instances.',
                      ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: DesignTokens.spaceXl)),
        ],
      ),
    );
  }

  /// API Key 单字段表单 → 底部 Sheet(isScrollControlled + 键盘避让,抄 ai_presets_screen)
  void _showApiKeySheet(BuildContext context, WidgetRef ref, TranslationSettings settings) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: settings.apiKey);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusBottomSheet),
        ),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${settings.provider.displayName} ${l10n.apiKey}',
                style: const TextStyle(
                  fontSize: DesignTokens.fontSizeHeadline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: DesignTokens.spaceMd),
              CupertinoTextField(
                controller: controller,
                autofocus: true,
                obscureText: true,
                placeholder: l10n.enterApiKey,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(sheetCtx).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusGroupedCard),
                ),
              ),
              const SizedBox(height: DesignTokens.spaceMd),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    // 写入逻辑与原 AlertDialog 完全一致
                    ref.read(translationSettingsProvider.notifier).setApiKey(controller.text);
                    Navigator.pop(sheetCtx);
                  },
                  child: Text(l10n.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 信息行:图标 + 标题 + 多行说明(分组卡内,替代原 ListTile)
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: theme.textTheme.bodyMedium?.color),
          const SizedBox(width: DesignTokens.spaceSm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeBodyLarge,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: DesignTokens.spaceXxs),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeSm,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget for testing translation
class _TranslationTestWidget extends ConsumerStatefulWidget {
  final bool enabled;

  const _TranslationTestWidget({required this.enabled});

  @override
  ConsumerState<_TranslationTestWidget> createState() => _TranslationTestWidgetState();
}

class _TranslationTestWidgetState extends ConsumerState<_TranslationTestWidget> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final translationState = ref.watch(translationStateProvider);

    return Padding(
      padding: const EdgeInsets.all(DesignTokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: l10n.enterTextToTokenize,
              hintText: l10n.enterTextToTokenize,
              border: const OutlineInputBorder(),
            ),
            maxLines: 3,
            enabled: widget.enabled,
          ),
          const SizedBox(height: DesignTokens.spaceSm + DesignTokens.spaceXs),
          FilledButton.icon(
            onPressed: widget.enabled && _controller.text.isNotEmpty
                ? () {
                    ref.read(translationStateProvider.notifier).translate(_controller.text);
                  }
                : null,
            icon: translationState.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.translate),
            label: Text(l10n.translation),
          ),
          if (translationState.result != null) ...[
            const SizedBox(height: DesignTokens.spaceMd),
            Container(
              padding: const EdgeInsets.all(DesignTokens.spaceSm + DesignTokens.spaceXs),
              decoration: BoxDecoration(
                color: AppTheme.darkBackground,
                borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                border: Border.all(color: AppTheme.accentColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check, size: 16, color: AppTheme.accentColor),
                      const SizedBox(width: DesignTokens.spaceSm),
                      Text(
                        '${translationState.result!.sourceLanguage} → ${translationState.result!.targetLanguage}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: DesignTokens.spaceSm),
                  Text(
                    translationState.result!.translatedText,
                    style: const TextStyle(fontSize: DesignTokens.fontSizeBodyLarge),
                  ),
                ],
              ),
            ),
          ],
          if (translationState.error != null) ...[
            const SizedBox(height: DesignTokens.spaceMd),
            Container(
              padding: const EdgeInsets.all(DesignTokens.spaceSm + DesignTokens.spaceXs),
              decoration: BoxDecoration(
                color: DesignTokens.statusError.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                border: Border.all(color: DesignTokens.statusError),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, size: 16, color: DesignTokens.statusError),
                  const SizedBox(width: DesignTokens.spaceSm),
                  Expanded(
                    child: Text(
                      translationState.error!,
                      style: const TextStyle(color: DesignTokens.statusError),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Translate button widget for messages
class TranslateButton extends ConsumerWidget {
  final String text;
  final void Function(TranslationResult)? onTranslated;
  final double size;

  const TranslateButton({
    super.key,
    required this.text,
    this.onTranslated,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(translationSettingsProvider);

    if (!settings.enabled) return const SizedBox.shrink();

    return IconButton(
      icon: Icon(Icons.translate, size: size),
      tooltip: '翻译',
      onPressed: () async {
        final result = await ref.read(translateProvider)(text);
        if (result != null && onTranslated != null) {
          onTranslated!(result);
        }
      },
    );
  }
}

/// Inline translation display widget
class TranslationDisplay extends StatelessWidget {
  final TranslationResult result;
  final bool showOriginal;

  const TranslationDisplay({
    super.key,
    required this.result,
    this.showOriginal = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spaceSm),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.translate, size: 14, color: AppTheme.accentColor),
              const SizedBox(width: DesignTokens.spaceXs),
              Text(
                'Translated from ${_getLanguageName(result.sourceLanguage)}',
                style: const TextStyle(
                  fontSize: DesignTokens.fontSizeCaption,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceXs),
          Text(result.translatedText),
          if (showOriginal) ...[
            const SizedBox(height: DesignTokens.spaceSm),
            Text(
              'Original: ${result.originalText}',
              style: const TextStyle(
                fontSize: DesignTokens.fontSizeXs,
                color: AppTheme.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getLanguageName(String code) {
    return TranslationLanguage.fromCode(code)?.name ?? code;
  }
}
