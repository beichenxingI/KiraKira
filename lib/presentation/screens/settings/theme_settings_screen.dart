import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/presentation/widgets/common/kira_pressable.dart';
import '../../../data/models/app_theme_config.dart';
import '../../providers/theme_providers.dart';
import '../../theme/app_theme.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'theme_edit_screen.dart';

/// Screen for managing app themes
class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allThemes = ref.watch(allThemesProvider);
    final activeThemeId = ref.watch(activeThemeIdProvider);
    // ignore: unused_local_variable
    final customThemes = ref.watch(customThemesProvider);

    // Separate built-in and custom themes
    final builtInThemes = allThemes.where((t) => t.isBuiltIn).toList();
    final userThemes = allThemes.where((t) => !t.isBuiltIn).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(
              AppLocalizations.of(context)!.themes,
              style: Theme.of(context).textTheme.displayLarge,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: AppLocalizations.of(context)!.createCustomTheme,
                onPressed: () => _showCreateThemeDialog(context, ref),
              ),
            ],
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.fromLTRB(DesignTokens.spaceMd,
                    DesignTokens.spaceMd, DesignTokens.spaceMd, 0),
                child: _buildSectionHeader(
                    context, AppLocalizations.of(context)!.builtInThemes),
              ),
              Padding(
                padding: DesignTokens.paddingScreen,
                child: _buildThemeGrid(context, ref, builtInThemes, activeThemeId),
              ),
              if (userThemes.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(DesignTokens.spaceMd,
                      24, DesignTokens.spaceMd, 0),
                  child: _buildSectionHeader(context, 'Custom Themes'),
                ),
                Padding(
                  padding: DesignTokens.paddingScreen,
                  child: _buildThemeGrid(context, ref, userThemes, activeThemeId,
                      isCustom: true),
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(DesignTokens.spaceMd,
                    32, DesignTokens.spaceMd, 0),
                child: _buildSectionHeader(context, 'Preview'),
              ),
              Padding(
                padding: DesignTokens.paddingScreen,
                child: _buildThemePreview(context, ref),
              ),
              const SizedBox(height: 32),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: AppTheme.accentColor,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildThemeGrid(
    BuildContext context,
    WidgetRef ref,
    List<AppThemeConfig> themes,
    String activeThemeId, {
    bool isCustom = false,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: themes.length,
      itemBuilder: (context, index) {
        final theme = themes[index];
        final isActive = theme.id == activeThemeId;
        
        return _ThemeCard(
          theme: theme,
          isActive: isActive,
          isCustom: isCustom,
          onTap: () {
            ref.read(activeThemeIdProvider.notifier).setActiveTheme(theme.id);
          },
          onEdit: isCustom ? () => _showEditThemeDialog(context, ref, theme) : null,
          onDelete: isCustom ? () => _showDeleteConfirmation(context, ref, theme) : null,
        );
      },
    );
  }

  Widget _buildThemePreview(BuildContext context, WidgetRef ref) {
    final activeTheme = ref.watch(activeThemeConfigProvider);
    
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        height: 200,
        color: activeTheme.background,
        child: Column(
          children: [
            // App bar preview
            Container(
              padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMd, vertical: 12),
              color: activeTheme.surface,
              child: Row(
                children: [
                  Icon(Icons.arrow_back, color: activeTheme.textPrimary, size: 20),
                  const SizedBox(width: 16),
                  Text(
                    'Chat Preview',
                    style: TextStyle(
                      color: activeTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.more_vert, color: activeTheme.textPrimary, size: 20),
                ],
              ),
            ),
            // Chat preview
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Assistant message
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: DesignTokens.spaceSm),
                      decoration: BoxDecoration(
                        color: activeTheme.card,
                        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                      ),
                      child: Text(
                        'Hello! How can I help you today?',
                        style: TextStyle(color: activeTheme.textPrimary, fontSize: DesignTokens.fontSizeSm),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // User message
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: DesignTokens.spaceSm),
                        decoration: BoxDecoration(
                          color: activeTheme.accent,
                          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                        ),
                        child: const Text(
                          'Tell me a story!',
                          style: TextStyle(color: Colors.white, fontSize: DesignTokens.fontSizeSm),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Input preview
            Container(
              padding: const EdgeInsets.all(12),
              color: activeTheme.card,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: DesignTokens.spaceSm),
                      decoration: BoxDecoration(
                        color: activeTheme.background,
                        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
                      ),
                      child: Text(
                        'Type a message...',
                        style: TextStyle(color: activeTheme.textSecondary, fontSize: DesignTokens.fontSizeSm),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(DesignTokens.spaceSm),
                    decoration: BoxDecoration(
                      color: activeTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// D-T2 规则 3:新建主题(多字段表单)→ push 子页
  void _showCreateThemeDialog(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ThemeEditScreen()),
    );
  }

  /// D-T2 规则 3:编辑主题(多字段表单)→ push 子页
  void _showEditThemeDialog(BuildContext context, WidgetRef ref, AppThemeConfig theme) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ThemeEditScreen(theme: theme)),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, AppThemeConfig theme) {
    // D-T2 规则 1:破坏确认 → CupertinoAlertDialog
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('删除主题'),
        content: Text('确定要删除"${theme.name}"吗？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              final activeId = ref.read(activeThemeIdProvider);
              if (activeId == theme.id) {
                ref.read(activeThemeIdProvider.notifier).setActiveTheme(BuiltInThemes.defaultDark.id);
              }
              ref.read(customThemesProvider.notifier).deleteTheme(theme.id);
              Navigator.pop(dialogCtx);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final AppThemeConfig theme;
  final bool isActive;
  final bool isCustom;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _ThemeCard({
    required this.theme,
    required this.isActive,
    required this.isCustom,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // D-T1#16:色卡按压 → KiraPressable(缩+暗,无水波)
    return KiraPressable(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          border: isActive
              ? Border.all(color: AppTheme.accentColor, width: 3)
              : Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Color preview
            Expanded(
              child: Container(
                color: theme.background,
                child: Column(
                  children: [
                    // Top bar
                    Container(
                      height: 20,
                      color: theme.surface,
                    ),
                    // Content area
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 16,
                              width: 40,
                              decoration: BoxDecoration(
                                color: theme.card,
                                borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
                              ),
                            ),
                            const Spacer(),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                height: 16,
                                width: 30,
                                decoration: BoxDecoration(
                                  color: theme.accent,
                                  borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Bottom bar
                    Container(
                      height: 16,
                      color: theme.card,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            margin: const EdgeInsets.only(right: DesignTokens.spaceXs),
                            decoration: BoxDecoration(
                              color: theme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Name
            Container(
              padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceSm, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      theme.name,
                      style: const TextStyle(fontSize: DesignTokens.fontSizeCaption),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isActive)
                    const Icon(Icons.check_circle, size: 14, color: AppTheme.accentColor),
                  if (isCustom && !isActive)
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      iconSize: 14,
                      icon: const Icon(Icons.more_vert, size: 14),
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        const PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                      onSelected: (value) {
                        if (value == 'edit') onEdit?.call();
                        if (value == 'delete') onDelete?.call();
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
