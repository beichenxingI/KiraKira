// lib/presentation/dialogs/translation_settings_dialog.dart
/// 翻译设置浮窗(极客Core迁移 P1)
/// 内容完整迁自 translation_settings_screen.dart,字段一个不少:
/// 通用(启用/译AI回复/译用户消息/显示原文) · 提供商(引擎/API密钥)
/// 语言(源语言/交换/目标语言) · 翻译测试 · 信息说明 · 恢复默认
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/domain/services/translation_service.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/providers/translation_providers.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'core_dialog.dart';

Future<void> showTranslationSettingsDialog(BuildContext context, WidgetRef ref) {
  return showCoreDialog(
    context,
    builder: (_) => const _TranslationSettingsDialog(),
  );
}

class _TranslationSettingsDialog extends ConsumerWidget {
  const _TranslationSettingsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CoreDialogPalette(isDark: isDark);
    final settings = ref.watch(translationSettingsProvider);

    return CoreDialogShell(
      title: '翻译设置',
      icon: CupertinoIcons.globe,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 通用 ──
          CoreSectionLabel(l10n.general),
          const SizedBox(height: 4),
          _Group(
            palette: palette,
            children: [
              CoreSwitchRow(
                title: l10n.enableTranslation,
                subtitle: l10n.translateMessagesAutomatically,
                value: settings.enabled,
                palette: palette,
                onChanged: (v) => ref
                    .read(translationSettingsProvider.notifier)
                    .setEnabled(v),
              ),
              CoreSwitchRow(
                title: l10n.translateAiResponses,
                subtitle: l10n.translateAiResponses,
                value: settings.autoTranslateIncoming,
                palette: palette,
                onChanged: settings.enabled
                    ? (v) => ref
                        .read(translationSettingsProvider.notifier)
                        .setAutoTranslateIncoming(v)
                    : null,
              ),
              CoreSwitchRow(
                title: l10n.translateUserMessages,
                subtitle: l10n.translateUserMessages,
                value: settings.autoTranslateOutgoing,
                palette: palette,
                onChanged: settings.enabled
                    ? (v) => ref
                        .read(translationSettingsProvider.notifier)
                        .setAutoTranslateOutgoing(v)
                    : null,
              ),
              CoreSwitchRow(
                title: '显示原文',
                subtitle: '在翻译旁显示原文',
                value: settings.showOriginal,
                palette: palette,
                onChanged: settings.enabled
                    ? (v) => ref
                        .read(translationSettingsProvider.notifier)
                        .setShowOriginal(v)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── 提供商 ──
          CoreSectionLabel(l10n.provider),
          const SizedBox(height: 4),
          _Group(
            palette: palette,
            children: [
              _DropdownTile(
                palette: palette,
                title: l10n.translationProvider,
                subtitle: settings.provider.displayName,
                child: DropdownButton<TranslationProvider>(
                  value: settings.provider,
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(8),
                  dropdownColor: palette.surface,
                  iconEnabledColor: palette.textSecondary,
                  onChanged: settings.enabled
                      ? (value) {
                          if (value != null) {
                            ref
                                .read(translationSettingsProvider.notifier)
                                .setProvider(value);
                          }
                        }
                      : null,
                  items: TranslationProvider.values.map((provider) {
                    return DropdownMenuItem(
                      value: provider,
                      child: Text(
                        provider.displayName,
                        style: TextStyle(
                            fontSize: 14, color: palette.textPrimary),
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (settings.provider != TranslationProvider.libre)
                CoreTile(
                  title: l10n.apiKey,
                  subtitle: settings.apiKey?.isNotEmpty == true
                      ? '••••••••${settings.apiKey!.substring(settings.apiKey!.length - 4)}'
                      : l10n.notConfigured,
                  onTap: settings.enabled
                      ? () =>
                          _showApiKeySheet(context, ref, settings, palette)
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 20),

          // ── 语言 ──
          CoreSectionLabel(l10n.language),
          const SizedBox(height: 4),
          _Group(
            palette: palette,
            children: [
              _DropdownTile(
                palette: palette,
                title: l10n.sourceLanguage,
                subtitle: TranslationLanguage.fromCode(settings.sourceLanguage)
                        ?.name ??
                    settings.sourceLanguage,
                child: DropdownButton<String>(
                  value: settings.sourceLanguage,
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(8),
                  dropdownColor: palette.surface,
                  iconEnabledColor: palette.textSecondary,
                  onChanged: settings.enabled
                      ? (value) {
                          if (value != null) {
                            ref
                                .read(translationSettingsProvider.notifier)
                                .setSourceLanguage(value);
                          }
                        }
                      : null,
                  items: TranslationLanguage.supportedLanguages.map((lang) {
                    return DropdownMenuItem(
                      value: lang.code,
                      child: Text(
                        lang.name,
                        style: TextStyle(
                            fontSize: 14, color: palette.textPrimary),
                      ),
                    );
                  }).toList(),
                ),
              ),
              CoreTile(
                title: '交换语言',
                subtitle:
                    '${settings.sourceLanguage} ⇄ ${settings.targetLanguage}',
                trailing: const Icon(CupertinoIcons.arrow_up_arrow_down,
                    size: 18, color: DesignTokens.primary),
                onTap: settings.enabled && settings.sourceLanguage != 'auto'
                    ? () => ref
                        .read(translationSettingsProvider.notifier)
                        .swapLanguages()
                    : null,
              ),
              _DropdownTile(
                palette: palette,
                title: l10n.targetLanguage,
                subtitle: TranslationLanguage.fromCode(settings.targetLanguage)
                        ?.name ??
                    settings.targetLanguage,
                child: DropdownButton<String>(
                  value: settings.targetLanguage,
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(8),
                  dropdownColor: palette.surface,
                  iconEnabledColor: palette.textSecondary,
                  onChanged: settings.enabled
                      ? (value) {
                          if (value != null) {
                            ref
                                .read(translationSettingsProvider.notifier)
                                .setTargetLanguage(value);
                          }
                        }
                      : null,
                  items: TranslationLanguage.targetLanguages.map((lang) {
                    return DropdownMenuItem(
                      value: lang.code,
                      child: Text(
                        lang.name,
                        style: TextStyle(
                            fontSize: 14, color: palette.textPrimary),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── 测试 ──
          CoreSectionLabel(l10n.test),
          const SizedBox(height: 8),
          _TranslationTestWidget(palette: palette, enabled: settings.enabled),
          const SizedBox(height: 20),

          // ── 信息 ──
          CoreSectionLabel(l10n.information),
          const SizedBox(height: 4),
          CoreInfoRow(
            icon: CupertinoIcons.info,
            title: '关于翻译',
            text: 'Translation allows you to communicate in different '
                'languages. Messages can be automatically translated or '
                'translated on demand.',
            palette: palette,
          ),
          if (settings.provider == TranslationProvider.google)
            CoreInfoRow(
              icon: CupertinoIcons.cloud,
              title: 'Google Translate',
              text: 'Uses Google Cloud Translation API. '
                  'Requires an API key from Google Cloud Console.',
              palette: palette,
            ),
          if (settings.provider == TranslationProvider.deepl)
            CoreInfoRow(
              icon: CupertinoIcons.cloud,
              title: 'DeepL',
              text: 'High-quality neural machine translation. '
                  'Requires an API key from deepl.com',
              palette: palette,
            ),
          if (settings.provider == TranslationProvider.libre)
            CoreInfoRow(
              icon: CupertinoIcons.globe,
              title: 'LibreTranslate',
              text: 'Free and open-source translation. '
                  'Can be self-hosted or use public instances.',
              palette: palette,
            ),
          const SizedBox(height: 20),

          // ── 恢复默认 ──
          CoreSecondaryButton(
            label: l10n.resetToDefaults,
            icon: CupertinoIcons.arrow_counterclockwise,
            onPressed: () {
              ref.read(translationSettingsProvider.notifier).reset();
              coreToast(context, l10n.settingsResetToDefaults);
            },
          ),
        ],
      ),
    );
  }

  /// API Key 表单 → 底部 Sheet(键盘避让,与原页一致)
  void _showApiKeySheet(
    BuildContext context,
    WidgetRef ref,
    TranslationSettings settings,
    CoreDialogPalette palette,
  ) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: settings.apiKey);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
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
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeHeadline,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
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
                  color: palette.fill,
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusGroupedCard),
                ),
                style: TextStyle(color: palette.textPrimary),
              ),
              const SizedBox(height: DesignTokens.spaceMd),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    ref
                        .read(translationSettingsProvider.notifier)
                        .setApiKey(controller.text);
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

/// 浮窗内分组容器
class _Group extends StatelessWidget {
  const _Group({required this.palette, required this.children});

  final CoreDialogPalette palette;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color:
            palette.fill.withValues(alpha: palette.isDark ? 0.55 : 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: children),
    );
  }
}

/// 带右侧下拉的行
class _DropdownTile extends StatelessWidget {
  const _DropdownTile({
    required this.palette,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final CoreDialogPalette palette;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        TextStyle(fontSize: 15, color: palette.textPrimary)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: TextStyle(
                          fontSize: 12, color: palette.textSecondary)),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// 翻译测试(原 `_TranslationTestWidget` 浮窗形态)
class _TranslationTestWidget extends ConsumerStatefulWidget {
  const _TranslationTestWidget({required this.palette, required this.enabled});

  final CoreDialogPalette palette;
  final bool enabled;

  @override
  ConsumerState<_TranslationTestWidget> createState() =>
      _TranslationTestWidgetState();
}

class _TranslationTestWidgetState
    extends ConsumerState<_TranslationTestWidget> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = widget.palette;
    final translationState = ref.watch(translationStateProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CoreTextField(
          controller: _controller,
          palette: palette,
          hint: l10n.enterTextToTokenize,
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        CorePrimaryButton(
          label: l10n.translation,
          icon: CupertinoIcons.globe,
          onPressed: widget.enabled && _controller.text.isNotEmpty
              ? () {
                  ref
                      .read(translationStateProvider.notifier)
                      .translate(_controller.text);
                }
              : null,
        ),
        if (translationState.result != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.fill,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: DesignTokens.primary),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check,
                        size: 16, color: DesignTokens.primary),
                    const SizedBox(width: 8),
                    Text(
                      '${translationState.result!.sourceLanguage} → '
                      '${translationState.result!.targetLanguage}',
                      style: TextStyle(fontSize: 12, color: palette.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  translationState.result!.translatedText,
                  style: TextStyle(fontSize: 15, color: palette.textPrimary),
                ),
              ],
            ),
          ),
        ],
        if (translationState.error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DesignTokens.statusError.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: DesignTokens.statusError),
            ),
            child: Row(
              children: [
                const Icon(Icons.error,
                    size: 16, color: DesignTokens.statusError),
                const SizedBox(width: 8),
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
    );
  }
}
