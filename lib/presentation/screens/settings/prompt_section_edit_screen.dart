import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/models/prompt_manager.dart';
import 'package:kirakira/presentation/providers/prompt_manager_providers.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/widgets/common/common.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';

/// 段落编辑页(D-T3):原"段落编辑弹窗"的 push 子页形态(弹窗内含大文本域,改为整页表单)
/// 保存语义与原弹窗完全一致:
/// - 自定义段落 → updateSectionByIndex(同时更新名称+内容)
/// - 内置段落   → updateSectionContent(仅更新内容)
/// 保存成功提示 = 'Updated xxx';返回即放弃修改(与原弹窗"取消"一致)。
class PromptSectionEditScreen extends ConsumerStatefulWidget {
  final PromptSection section;
  final int index;

  const PromptSectionEditScreen({
    super.key,
    required this.section,
    required this.index,
  });

  @override
  ConsumerState<PromptSectionEditScreen> createState() =>
      _PromptSectionEditScreenState();
}

class _PromptSectionEditScreenState
    extends ConsumerState<PromptSectionEditScreen> {
  late final TextEditingController _contentController;
  late final TextEditingController _nameController;

  PromptSection get _section => widget.section;

  String get _displayName => _section.isCustom
      ? _section.name
      : PromptSection.getDisplayName(_section.type);

  String get _description => _section.isCustom
      ? 'Custom prompt from imported preset'
      : PromptSection.getDescription(_section.type);

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(
      text: _section.content ?? PromptSection.getDefaultContent(_section.type),
    );
    _nameController = TextEditingController(text: _section.name);
  }

  @override
  void dispose() {
    _contentController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final newContent = _contentController.text.trim();
    final newName = _nameController.text.trim();

    if (_section.isCustom) {
      // Update custom prompt with new name and content
      ref.read(promptManagerProvider.notifier).updateSectionByIndex(
            widget.index,
            _section.copyWith(
              name: newName.isNotEmpty ? newName : _section.name,
              content: newContent,
            ),
          );
    } else {
      // Update built-in prompt content
      ref.read(promptManagerProvider.notifier).updateSectionContent(
            _section.type,
            newContent,
          );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Updated ${_section.isCustom ? newName : _displayName}'),
      ),
    );
    Navigator.pop(context);
  }

  /// 仅重置输入框内容(不落库),与原弹窗"重置为默认"按钮行为一致
  void _resetToDefault() {
    setState(() {
      _contentController.text = PromptSection.getDefaultContent(_section.type);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textSecondary = theme.textTheme.bodyMedium?.color;
    final textMuted = theme.textTheme.bodySmall?.color;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 编辑/表单深页:pinned 常规标题,保存按钮放右上角(施工模板②)
          SliverAppBar(
            pinned: true,
            title: Text(
              'Edit $_displayName',
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              TextButton(
                onPressed: _save,
                child: Text(
                  AppLocalizations.of(context).save,
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
              ),
            ],
          ),

          // 自定义段落:名称
          if (_section.isCustom)
            SliverToBoxAdapter(
              child: KiraSection(
                title: '提示词名称',
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spaceMd,
                      vertical: DesignTokens.spaceXs,
                    ),
                    child: CupertinoTextField.borderless(
                      controller: _nameController,
                      placeholder: '提示词名称',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),

          // 内容(大文本域)
          SliverToBoxAdapter(
            child: KiraSection.plain(
              title: '内容',
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceMd,
                  vertical: DesignTokens.spaceXs,
                ),
                child: CupertinoTextField.borderless(
                  controller: _contentController,
                  placeholder: '输入提示词内容...',
                  minLines: 8,
                  maxLines: null,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
          ),

          // 元信息 + 宏提示(原弹窗说明文字,逐字保留)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                DesignTokens.spaceMd + 12,
                DesignTokens.spaceSm,
                DesignTokens.spaceMd,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _description,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: DesignTokens.fontSizeXs,
                    ),
                  ),
                  if (_section.identifier != null) ...[
                    const SizedBox(height: DesignTokens.spaceXs),
                    Text(
                      'ID: ${_section.identifier}',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: DesignTokens.fontSizeCaption,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                  if (_section.role != null) ...[
                    const SizedBox(height: DesignTokens.spaceXs),
                    Text(
                      'Role: ${_section.role}',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: DesignTokens.fontSizeCaption,
                      ),
                    ),
                  ],
                  const SizedBox(height: DesignTokens.spaceSm),
                  Text(
                    'Supports macros: {{user}}, {{char}}, {{time}}, {{date}}, etc.',
                    style: TextStyle(
                      color: textMuted,
                      fontSize: DesignTokens.fontSizeCaption,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 内置段落:重置为默认(仅重置输入框,需再点保存才生效——与原弹窗一致)
          if (!_section.isCustom)
            SliverToBoxAdapter(
              child: KiraSection(
                title: '',
                children: [
                  KiraGroupedTile(
                    icon: CupertinoIcons.arrow_counterclockwise,
                    title: '重置为默认',
                    onTap: _resetToDefault,
                    trailing: const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: DesignTokens.spaceXl),
          ),
        ],
      ),
    );
  }
}
