// lib/presentation/dialogs/stt_settings_dialog.dart
/// STT 识别设置浮窗(极客Core迁移 P1)
/// 内容完整迁自 stt_settings_screen.dart,字段一个不少:
/// 可用性警告 · 通用(启用/自动发送/持续监听/显示中间结果)
/// 提供商(引擎/API密钥) · 识别语言 · 测试试听 · 信息说明 · 恢复默认
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/domain/services/stt_service.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/providers/stt_providers.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'core_dialog.dart';

Future<void> showSttSettingsDialog(BuildContext context, WidgetRef ref) {
  return showCoreDialog(
    context,
    builder: (_) => const _SttSettingsDialog(),
  );
}

class _SttSettingsDialog extends ConsumerWidget {
  const _SttSettingsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = CoreDialogPalette(isDark: isDark);
    final settings = ref.watch(sttSettingsProvider);
    final isListening = ref.watch(sttListeningProvider);
    final availableAsync = ref.watch(sttAvailableProvider);

    return CoreDialogShell(
      title: 'STT 识别设置',
      icon: CupertinoIcons.mic,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 可用性警告 ──
          availableAsync.when(
            data: (available) => available
                ? const SizedBox.shrink()
                : Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: DesignTokens.statusWarning.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: DesignTokens.statusWarning
                            .withValues(alpha: 0.5),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_rounded,
                            color: DesignTokens.statusWarning),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.speechRecognitionNotAvailable,
                            style: const TextStyle(
                                color: DesignTokens.statusWarning),
                          ),
                        ),
                      ],
                    ),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // ── 通用 ──
          CoreSectionLabel(l10n.general),
          const SizedBox(height: 4),
          _Group(
            palette: palette,
            children: [
              CoreSwitchRow(
                title: l10n.enableStt,
                subtitle: l10n.useVoiceInputForMessages,
                value: settings.enabled,
                palette: palette,
                onChanged: (v) =>
                    ref.read(sttSettingsProvider.notifier).setEnabled(v),
              ),
              CoreSwitchRow(
                title: l10n.autoSendStt,
                subtitle: l10n.automaticallySendAfterSpeaking,
                value: settings.autoSend,
                palette: palette,
                onChanged: settings.enabled
                    ? (v) =>
                        ref.read(sttSettingsProvider.notifier).setAutoSend(v)
                    : null,
              ),
              CoreSwitchRow(
                title: l10n.continuousListening,
                subtitle: l10n.keepListeningAfterPhrase,
                value: settings.continuousListening,
                palette: palette,
                onChanged: settings.enabled
                    ? (v) => ref
                        .read(sttSettingsProvider.notifier)
                        .setContinuousListening(v)
                    : null,
              ),
              CoreSwitchRow(
                title: l10n.showPartialResults,
                subtitle: l10n.displayTextAsYouSpeak,
                value: settings.showPartialResults,
                palette: palette,
                onChanged: settings.enabled
                    ? (v) => ref
                        .read(sttSettingsProvider.notifier)
                        .setShowPartialResults(v)
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
                title: l10n.sttProvider,
                subtitle: settings.provider.displayName,
                child: DropdownButton<STTProvider>(
                  value: settings.provider,
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(8),
                  dropdownColor: palette.surface,
                  iconEnabledColor: palette.textSecondary,
                  onChanged: settings.enabled
                      ? (value) {
                          if (value != null) {
                            ref
                                .read(sttSettingsProvider.notifier)
                                .setProvider(value);
                          }
                        }
                      : null,
                  items: STTProvider.values.map((provider) {
                    return DropdownMenuItem(
                      value: provider,
                      child: Text(
                        provider.displayName,
                        style:
                            TextStyle(fontSize: 14, color: palette.textPrimary),
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (settings.provider == STTProvider.whisper ||
                  settings.provider == STTProvider.azure)
                CoreTile(
                  title: l10n.apiKey,
                  subtitle: settings.apiKey?.isNotEmpty == true
                      ? '••••••••${settings.apiKey!.substring(settings.apiKey!.length - 4)}'
                      : l10n.notConfigured,
                  trailing: const Icon(Icons.edit,
                      size: 18, color: DesignTokens.primary),
                  onTap: settings.enabled
                      ? () =>
                          _showApiKeySheet(context, ref, settings, palette)
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 20),

          // ── 识别语言 ──
          CoreSectionLabel(l10n.language),
          const SizedBox(height: 4),
          _Group(
            palette: palette,
            children: [
              _DropdownTile(
                palette: palette,
                title: l10n.recognitionLanguage,
                subtitle:
                    STTLanguage.fromCode(settings.language)?.name ??
                        settings.language,
                child: DropdownButton<String>(
                  value: settings.language,
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(8),
                  dropdownColor: palette.surface,
                  iconEnabledColor: palette.textSecondary,
                  onChanged: settings.enabled
                      ? (value) {
                          if (value != null) {
                            ref
                                .read(sttSettingsProvider.notifier)
                                .setLanguage(value);
                          }
                        }
                      : null,
                  items: STTLanguage.supportedLanguages.map((lang) {
                    return DropdownMenuItem(
                      value: lang.code,
                      child: Text(
                        lang.name,
                        style:
                            TextStyle(fontSize: 14, color: palette.textPrimary),
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
          CoreSecondaryButton(
            label: isListening ? l10n.stopListening : l10n.testVoiceInput,
            icon: isListening ? CupertinoIcons.mic : CupertinoIcons.mic,
            iconColor: isListening
                ? DesignTokens.statusError
                : DesignTokens.primary,
            onPressed: settings.enabled
                ? () async {
                    await ref.read(sttToggleListeningProvider)();
                  }
                : null,
          ),
          Consumer(
            builder: (context, ref, _) {
              final result = ref.watch(sttResultProvider);
              if (result == null) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: result.isFinal
                        ? DesignTokens.primary
                        : palette.textSecondary,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          result.isFinal ? Icons.check : Icons.more_horiz,
                          size: 16,
                          color: result.isFinal
                              ? DesignTokens.primary
                              : palette.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          result.isFinal ? l10n.final_ : l10n.listening,
                          style: TextStyle(
                            fontSize: 12,
                            color: result.isFinal
                                ? DesignTokens.primary
                                : palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      result.text.isEmpty ? '...' : result.text,
                      style:
                          TextStyle(fontSize: 15, color: palette.textPrimary),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // ── 信息 ──
          CoreSectionLabel(l10n.information),
          const SizedBox(height: 4),
          CoreInfoRow(
            icon: CupertinoIcons.info,
            title: '关于语音识别',
            text: '在聊天输入框旁按住麦克风按钮说话，松开后识别结果自动填入'
                '输入框。当前内置模型仅支持中文。',
            palette: palette,
          ),
          if (settings.provider == STTProvider.sherpa)
            CoreInfoRow(
              icon: CupertinoIcons.lock_fill,
              title: '本地离线识别',
              text: '基于 sherpa-onnx 流式 Zipformer 中文模型，识别在设备'
                  '本地完成，无需联网，音频不会上传。',
              palette: palette,
            ),
          if (settings.provider == STTProvider.system)
            CoreInfoRow(
              icon: CupertinoIcons.device_phone_portrait,
              title: '系统语音识别',
              text: 'Using your device\'s built-in speech recognition. '
                  'Accuracy depends on your system settings.',
              palette: palette,
            ),
          if (settings.provider == STTProvider.whisper)
            CoreInfoRow(
              icon: CupertinoIcons.cloud,
              title: 'Whisper',
              text: 'OA Compatible\'s Whisper model for high-accuracy '
                  'transcription. Requires an API key.',
              palette: palette,
            ),
          const SizedBox(height: 20),

          // ── 恢复默认 ──
          CoreSecondaryButton(
            label: l10n.resetToDefaults,
            icon: CupertinoIcons.arrow_counterclockwise,
            onPressed: () {
              ref.read(sttSettingsProvider.notifier).reset();
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
    STTSettings settings,
    CoreDialogPalette palette,
  ) {
    final l10n = AppLocalizations.of(context)!;
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
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                placeholder: l10n.enterApiKey,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.fill,
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusGroupedCard),
                ),
                style: TextStyle(color: palette.textPrimary),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    ref
                        .read(sttSettingsProvider.notifier)
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
