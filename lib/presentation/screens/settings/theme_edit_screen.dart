import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/models/app_theme_config.dart';
import 'package:kirakira/presentation/providers/theme_providers.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/widgets/common/common.dart';
import 'package:uuid/uuid.dart';

/// 主题编辑页(D-T2:_ThemeEditorDialog 新建/编辑共用表单弹窗 → push 子页)
///
/// [theme] 为空 = 新建;非空 = 编辑既有自定义主题。
class ThemeEditScreen extends ConsumerStatefulWidget {
  final AppThemeConfig? theme;

  const ThemeEditScreen({super.key, this.theme});

  @override
  ConsumerState<ThemeEditScreen> createState() => _ThemeEditScreenState();
}

class _ThemeEditScreenState extends ConsumerState<ThemeEditScreen> {
  late TextEditingController _nameController;
  late bool _isDark;
  late String _primaryColor;
  late String _accentColor;
  late String _backgroundColor;
  late String _surfaceColor;
  late String _cardColor;

  bool get _isEditing => widget.theme != null;

  @override
  void initState() {
    super.initState();
    final theme = widget.theme ?? BuiltInThemes.defaultDark;
    _nameController = TextEditingController(text: widget.theme?.name ?? 'My Theme');
    _isDark = theme.isDark;
    _primaryColor = theme.primaryColor;
    _accentColor = theme.accentColor;
    _backgroundColor = theme.backgroundColor;
    _surfaceColor = theme.surfaceColor;
    _cardColor = theme.cardColor;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// 组装 + 落库逻辑与原 _ThemeEditorDialog 完全一致(新建顺带激活)
  void _save() {
    final theme = AppThemeConfig(
      id: widget.theme?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      isDark: _isDark,
      primaryColor: _primaryColor,
      accentColor: _accentColor,
      backgroundColor: _backgroundColor,
      surfaceColor: _surfaceColor,
      cardColor: _cardColor,
      textPrimaryColor: _isDark ? '#FFFFFF' : '#171717',
      textSecondaryColor: _isDark ? '#A3A3A3' : '#737373',
      dividerColor: _isDark ? '#404040' : '#E5E5E5',
      isBuiltIn: false,
    );
    if (_isEditing) {
      ref.read(customThemesProvider.notifier).updateTheme(theme);
    } else {
      ref.read(customThemesProvider.notifier).addTheme(theme);
      ref.read(activeThemeIdProvider.notifier).setActiveTheme(theme.id);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 表单深页:pinned 常规标题(施工模板①例外)
          SliverAppBar(
            pinned: true,
            title: Text(_isEditing ? '编辑主题' : '新建主题'),
            actions: [
              TextButton(
                onPressed: _save,
                child: Text(
                  '保存',
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
              ),
            ],
          ),

          // 基本信息
          SliverToBoxAdapter(
            child: KiraSection(
              title: '基本信息',
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceMd,
                    vertical: DesignTokens.spaceXs,
                  ),
                  child: CupertinoTextField.borderless(
                    controller: _nameController,
                    placeholder: '主题名称',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                KiraSwitchTile(
                  title: '深色模式',
                  value: _isDark,
                  onChanged: (value) => setState(() => _isDark = value),
                ),
              ],
            ),
          ),

          // 颜色
          SliverToBoxAdapter(
            child: KiraSection(
              title: '颜色',
              children: [
                _ColorPickerTile(
                  label: 'Primary Color',
                  color: _primaryColor,
                  onChanged: (color) => setState(() => _primaryColor = color),
                ),
                _ColorPickerTile(
                  label: 'Accent Color',
                  color: _accentColor,
                  onChanged: (color) => setState(() => _accentColor = color),
                ),
                _ColorPickerTile(
                  label: 'Background',
                  color: _backgroundColor,
                  onChanged: (color) => setState(() => _backgroundColor = color),
                ),
                _ColorPickerTile(
                  label: 'Surface',
                  color: _surfaceColor,
                  onChanged: (color) => setState(() => _surfaceColor = color),
                ),
                _ColorPickerTile(
                  label: 'Card',
                  color: _cardColor,
                  onChanged: (color) => setState(() => _cardColor = color),
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

/// 颜色行:整行可点,尾部当前色卡(KiraGroupedTile 自带 KiraPressable)
class _ColorPickerTile extends StatelessWidget {
  final String label;
  final String color;
  final void Function(String) onChanged;

  const _ColorPickerTile({
    required this.label,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KiraGroupedTile(
      title: label,
      subtitle: color,
      onTap: () => _showColorPicker(context),
      trailing: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppThemeConfig.hexToColor(color),
          borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
          border: Border.all(color: theme.dividerColor, width: 0.5),
        ),
      ),
    );
  }

  /// 取色器属"选择类"弹窗保留,样式统一圆角 14(radiusDialog)
  void _showColorPicker(BuildContext context) {
    final controller = TextEditingController(text: color);

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        final theme = Theme.of(dialogCtx);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusDialog),
          ),
          title: Text('选择 $label'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: '十六进制色值',
                  hintText: '#RRGGBB',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: DesignTokens.spaceMd),
              Wrap(
                spacing: DesignTokens.spaceSm,
                runSpacing: DesignTokens.spaceSm,
                children: [
                  for (final c in const [
                    '#6366F1', '#8B5CF6', '#EC4899', '#EF4444',
                    '#F97316', '#EAB308', '#22C55E', '#06B6D4',
                    '#3B82F6', '#000000', '#1A1A1A', '#FFFFFF',
                  ])
                    KiraPressable(
                      onTap: () => controller.text = c,
                      borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppThemeConfig.hexToColor(c),
                          borderRadius:
                              BorderRadius.circular(DesignTokens.radiusXs),
                          border: Border.all(
                            color: theme.dividerColor,
                            width: 0.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                onChanged(controller.text);
                Navigator.pop(dialogCtx);
              },
              child: const Text('应用'),
            ),
          ],
        );
      },
    );
  }
}
