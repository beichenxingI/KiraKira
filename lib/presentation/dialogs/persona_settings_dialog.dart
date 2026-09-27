// lib/presentation/dialogs/persona_settings_dialog.dart
/// 人设管理浮窗(问题三)
/// 内容完整迁自 personas_screen.dart 的 PersonasScreen:
/// 人设列表(头像/名称/描述/默认徽标/激活徽标/设为默认/编辑/删除)
/// + 新建/编辑(经 PersonaEditorScreen) + 删除确认 + 空状态。
/// 设置页只保留一个人设入口(_UserInfoCard),改为触发本浮窗。
library;

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/models/persona.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/providers/persona_providers.dart';
import 'package:kirakira/presentation/screens/personas/persona_editor_screen.dart';
import 'package:kirakira/presentation/theme/app_theme.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/utils/kira_dialog.dart';
import 'core_dialog.dart';

Future<void> showPersonaSettingsDialog(BuildContext context, WidgetRef ref) {
  return showKiraDialog(
    context: context,
    dialog: const _PersonaSettingsDialog(),
  );
}

class _PersonaSettingsDialog extends ConsumerWidget {
  const _PersonaSettingsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final personasAsync = ref.watch(personaNotifierProvider);
    final activePersonaAsync = ref.watch(activePersonaProvider);

    return CoreDialogShell(
      title: l10n.personas,
      icon: CupertinoIcons.person_crop_circle,
      maxWidth: 550,
      trailing: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minSize: 0,
        onPressed: () => _showCreatePersonaDialog(context, ref),
        child: Icon(CupertinoIcons.add_circled,
            size: 22, color: DesignTokens.primary),
      ),
      body: personasAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(personaNotifierProvider.notifier).refresh(),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (personas) {
          if (personas.isEmpty) {
            return _buildEmptyState(context, ref);
          }
          final activePersona = activePersonaAsync.valueOrNull;
          return Column(
            children: [
              for (final persona in personas)
                _PersonaCard(
                  persona: persona,
                  isActive: activePersona?.id == persona.id,
                  onTap: () => _setActivePersona(ref, persona.id),
                  onEdit: () => _showEditPersonaDialog(context, ref, persona),
                  onDelete: persona.isDefault
                      ? null
                      : () => _showDeleteConfirmation(context, ref, persona),
                  onSetDefault: persona.isDefault
                      ? null
                      : () => _setDefaultPersona(ref, persona.id),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_outline,
                size: 64, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text(
              l10n.noPersonasYet,
              style: const TextStyle(
                  fontSize: 18, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.createPersonaDescription,
              style: const TextStyle(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showCreatePersonaDialog(context, ref),
              icon: const Icon(Icons.add),
              label: Text(l10n.createPersona),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePersonaDialog(BuildContext context, WidgetRef ref) {
    // [问题5] 编辑浮窗化:全屏页 → 居中浮窗(编辑器内容包 CoreDialogShell)
    showKiraDialog(
      context: context,
      dialog: const PersonaEditorScreen(),
    );
  }

  void _showEditPersonaDialog(
      BuildContext context, WidgetRef ref, Persona persona) {
    showKiraDialog(
      context: context,
      dialog: PersonaEditorScreen(persona: persona),
    );
  }

  void _showDeleteConfirmation(
      BuildContext context, WidgetRef ref, Persona persona) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n.deletePersona),
        content: Text(l10n.deletePersonaConfirmation(persona.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              ref.read(personaNotifierProvider.notifier).deletePersona(persona.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  void _setActivePersona(WidgetRef ref, String id) {
    ref.read(personaNotifierProvider.notifier).setActivePersona(id);
  }

  void _setDefaultPersona(WidgetRef ref, String id) {
    ref.read(personaNotifierProvider.notifier).setDefaultPersona(id);
  }
}

/// 人设卡(原 _PersonaCard 浮窗形态,信息与操作全保留)
class _PersonaCard extends StatelessWidget {
  final Persona persona;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onSetDefault;

  const _PersonaCard({
    required this.persona,
    required this.isActive,
    required this.onTap,
    required this.onEdit,
    this.onDelete,
    this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.primaryColor.withValues(alpha: 0.15)
            : AppTheme.darkCard,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        border: isActive
            ? Border.all(color: AppTheme.primaryColor, width: 2)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildAvatar(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              persona.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (persona.isDefault)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.accentColor
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Default',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.accentColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (isActive && !persona.isDefault)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Active',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (persona.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          persona.description,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      color: AppTheme.textMuted),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit();
                      case 'delete':
                        onDelete?.call();
                      case 'default':
                        onSetDefault?.call();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: const Icon(Icons.edit),
                        title: Text(AppLocalizations.of(context)!.edit),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (onSetDefault != null)
                      PopupMenuItem(
                        value: 'default',
                        child: ListTile(
                          leading: const Icon(Icons.star),
                          title: Text(
                              AppLocalizations.of(context)!.setAsDefault),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    if (onDelete != null)
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: const Icon(Icons.delete, color: Colors.red),
                          title: Text(AppLocalizations.of(context)!.delete,
                              style: const TextStyle(color: Colors.red)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (persona.avatarPath != null) {
      return CircleAvatar(
        radius: 28,
        backgroundImage: FileImage(File(persona.avatarPath!)),
      );
    }
    return CircleAvatar(
      radius: 28,
      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
      child: Text(
        persona.name.isNotEmpty ? persona.name[0].toUpperCase() : 'U',
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }
}
