// lib/presentation/screens/settings/logit_bias_preset_edit_screen.dart
/// Logit 偏置预设编辑页(D-T1#9:新建/重命名/导入 JSON 三弹窗合并 push 子页)
library;

import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/models/logit_bias.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/providers/logit_bias_providers.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/widgets/common/kira_components.dart';

enum PresetEditMode { create, rename, importJson }

class LogitBiasPresetEditScreen extends ConsumerStatefulWidget {
  /// create:仅名称;rename:仅名称(预填);importJson:JSON 多行
  final PresetEditMode mode;
  final LogitBiasPreset? preset;

  const LogitBiasPresetEditScreen({
    super.key,
    required this.mode,
    this.preset,
  });

  @override
  ConsumerState<LogitBiasPresetEditScreen> createState() =>
      _LogitBiasPresetEditScreenState();
}

class _LogitBiasPresetEditScreenState
    extends ConsumerState<LogitBiasPresetEditScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _jsonController;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.preset?.name ?? '');
    _jsonController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _jsonController.dispose();
    super.dispose();
  }

  String get _title {
    final l10n = AppLocalizations.of(context)!;
    switch (widget.mode) {
      case PresetEditMode.create:
        return l10n.newPreset;
      case PresetEditMode.rename:
        return l10n.editPreset;
      case PresetEditMode.importJson:
        return l10n.importPresetLabel;
    }
  }

  void _save() {
    final l10n = AppLocalizations.of(context)!;
    switch (widget.mode) {
      case PresetEditMode.create:
        final name = _nameController.text.trim();
        if (name.isEmpty) return;
        final preset = LogitBiasPreset.create(name: name);
        ref.read(logitBiasSettingsProvider.notifier).addPreset(preset);
        ref.read(logitBiasSettingsProvider.notifier).setActivePreset(preset.id);
        Navigator.pop(context);
        break;
      case PresetEditMode.rename:
        final name = _nameController.text.trim();
        if (name.isEmpty || widget.preset == null) return;
        ref.read(logitBiasSettingsProvider.notifier).updatePreset(
              widget.preset!.copyWith(name: name),
            );
        Navigator.pop(context);
        break;
      case PresetEditMode.importJson:
        try {
          final json = jsonDecode(_jsonController.text) as Map<String, dynamic>;
          ref.read(logitBiasSettingsProvider.notifier).importPreset(json);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.presetImportedSuccessfully)),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.importPresetFailed(e.toString()))),
          );
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isJson = widget.mode == PresetEditMode.importJson;

    return Scaffold(
      // 编辑/表单深页:小标题返回栏(不进 large)
      appBar: AppBar(
        centerTitle: false,
        title: Text(_title),
      ),
      body: ListView(
        padding: DesignTokens.paddingScreen,
        children: [
          KiraSection.plain(
            title: isJson ? l10n.json : l10n.presetName,
            child: Padding(
              padding: const EdgeInsets.all(DesignTokens.spaceMd),
              child: CupertinoTextField(
                controller: isJson ? _jsonController : _nameController,
                autofocus: true,
                maxLines: isJson ? 8 : 1,
                placeholder: isJson
                    ? l10n.pastePresetJson
                    : l10n.enterPresetName,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusGroupedCard),
                ),
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          Padding(
            padding: DesignTokens.paddingScreen,
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: Text(isJson ? l10n.import : l10n.save),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
