import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/path_utils.dart';
import '../../data/models/character.dart';
import '../../data/repositories/character_repository.dart';
import '../../data/repositories/regex_script_repository.dart';
import '../providers/chat_providers.dart';
import '../providers/character_providers.dart';
import '../providers/world_info_providers.dart';
import '../components/kira_dialog_widgets.dart';
import '../components/kira_toast.dart';
import '../screens/import/import_screen.dart' show importServiceProvider;
import '../theme/design_tokens.dart';
import '../components/kira_dialog_theme.dart';
import '../widgets/common/character_avatar_image.dart';
import '../utils/export_delivery.dart';
import 'character_edit_dialog.dart';

/// Lightweight preview dialog entry point (opened by tapping a character card).
void showCharacterPreviewDialog(
    BuildContext context, WidgetRef ref, Character character) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 240),
    transitionBuilder: (context, animation, _, child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: animation.drive(
            Tween(begin: 0.92, end: 1.0)
                .chain(CurveTween(curve: Curves.easeOutBack)),
          ),
          child: child,
        ),
      );
    },
    pageBuilder: (_, __, ___) =>
        _CharacterPreviewDialog(character: character),
  );
}

class _CharacterPreviewDialog extends ConsumerWidget {
  final Character character;

  const _CharacterPreviewDialog({required this.character});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Center(
      child: Material(
        color: Colors.transparent,
          child: Container(
            width: min(screenWidth - 48, 500),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            constraints: BoxConstraints(
              maxHeight: screenHeight * 0.75,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [const Color(0xFF7B5EA7).withValues(alpha: 0.08), const Color(0xFF1A1B2E)]
                    : [const Color(0xFF6C5CE7).withValues(alpha: 0.06), const Color(0xFFF4F3FF)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF7B5EA7).withValues(alpha: 0.25),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                  blurRadius: 48,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cover (16:9)
              _buildCoverImage(context),
              // Pin indicator + character name
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (character.isPinned) ...[
                      const Icon(CupertinoIcons.pin_fill,
                          size: 16, color: Color(0xFFFFA726)),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        character.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: DesignTokens.weightSemibold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Short description (truncated)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _shortDescription(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              // Start chat (full width, Kira purple gradient)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                    onTap: () => _startChat(context, ref),
                    child: Container(
                      height: 46,
                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C5CE7), Color(0xFFA855F7)],
                        ),
                        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.chat_bubble_fill,
                              size: 18, color: Colors.white),
                          SizedBox(width: 8),
                          Text('开始聊天',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Five action buttons (evenly spaced in one row)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: character.isPinned
                            ? CupertinoIcons.pin_fill
                            : CupertinoIcons.pin,
                        label: '置顶',
                        color: const Color(0xFFFFA726),
                        onTap: () => _togglePin(context, ref),
                      ),
                    ),
                    Expanded(
                      child: _ActionButton(
                        icon: CupertinoIcons.pencil,
                        label: '编辑',
                        color: const Color(0xFF66BB6A),
                        onTap: () {
                          Navigator.pop(context);
                          showCharacterEditDialog(context, ref,
                              character: character);
                        },
                      ),
                    ),
                    Expanded(
                      child: _ActionButton(
                        icon: CupertinoIcons.doc_on_doc,
                        label: '复制',
                        color: const Color(0xFF5C6BC0),
                        onTap: () => _duplicate(context, ref),
                      ),
                    ),
                    Expanded(
                      child: _ActionButton(
                        icon: CupertinoIcons.arrow_up_doc,
                        label: '导出',
                        color: const Color(0xFF42A5F5),
                        onTap: () => _export(context, ref),
                      ),
                    ),
                    Expanded(
                      child: _ActionButton(
                        icon: CupertinoIcons.trash,
                        label: '删除',
                        color: const Color(0xFFEF5350),
                        onTap: () => _delete(context, ref),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverImage(BuildContext context) {
    final coverPath =
        character.assets?.coverPath ?? character.assets?.avatarPath;
    if (coverPath != null && coverPath.isNotEmpty) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: SizedBox(
          height: 200,
          width: double.infinity,
          child: CharacterAvatarImage(
            imagePath: coverPath,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildPlaceholder(context),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: _buildPlaceholder(context),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      height: 200,
      width: double.infinity,
      color: const Color(0xFF252640),
        child: Center(
          child: Icon(
            CupertinoIcons.person_crop_circle,
            size: 56,
            color: const Color(0xFF7B5EA7).withValues(alpha: 0.5),
          ),
        ),
      );
  }

  String _shortDescription() {
    final desc = character.description;
    if (desc.isEmpty) return '(暂无简介)';
    if (desc.length <= 100) return desc;
    return '${desc.substring(0, 100)}...';
  }

  void _showSnackBar(BuildContext context, String message,
      {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? DesignTokens.statusError : DesignTokens.statusSuccess,
        duration: Duration(seconds: isError ? 3 : 2),
      ),
    );
  }

  // Start chat
  Future<void> _startChat(BuildContext context, WidgetRef ref) async {
    Navigator.pop(context);
    try {
      final chatId = await ref
          .read(activeChatProvider.notifier)
          .createChat(character.id);
      if (chatId != null && context.mounted) {
        context.push('/chat/$chatId');
      } else if (context.mounted) {
        _showSnackBar(context, '创建会话失败', isError: true);
      }
    } catch (e) {
      if (context.mounted) _showSnackBar(context, '创建会话失败: $e', isError: true);
    }
  }

  // Pin toggle
  Future<void> _togglePin(BuildContext context, WidgetRef ref) async {
    Navigator.pop(context);
    await ref.read(characterRepositoryProvider).togglePin(character.id);
    ref.read(characterListProvider.notifier).refresh();
  }

  // Duplicate
  Future<void> _duplicate(BuildContext context, WidgetRef ref) async {
    Navigator.pop(context);
    try {
      final repo = ref.read(characterRepositoryProvider);
      final newCharacter = character.copyWith(
        id: '',
        name: '${character.name} (copy)',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      );
      final created = await repo.createCharacter(newCharacter);
      // Deep-copy the original character's worldbooks: each copy gets a
      // suffixed name and all entries are copied in full.
      final worldInfos =
          await ref.read(worldInfoRepositoryProvider).getWorldInfosForCharacter(character.id);
      final worldNotifier = ref.read(worldInfoNotifierProvider.notifier);
      for (final w in worldInfos) {
        final copied = await worldNotifier.createWorldInfo(
          name: '${w.name}_副本',
          description: w.description,
          characterId: created.id,
        );
        for (final e in w.entries) {
          await worldNotifier.addEntry(
            worldInfoId: copied.id,
            keys: e.keys,
            content: e.content,
            secondaryKeys: e.secondaryKeys,
            comment: e.comment,
            constant: e.constant,
            selective: e.selective,
            insertionOrder: e.insertionOrder,
          );
        }
      }
      ref.read(characterListProvider.notifier).refresh();
      if (context.mounted) {
        KiraToast.show(context, '角色已复制（含世界书）', type: KiraToastType.success);
      }
    } catch (e) {
      if (context.mounted) _showSnackBar(context, '复制失败: $e', isError: true);
    }
  }

  // Export (choose format, then delivery mode, then close the preview and run)
  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final format = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusBottomSheet),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
                title: const Text('导出为PNG图片卡'), onTap: () => Navigator.pop(ctx, 'png')),
            ListTile(title: const Text('导出为JSON'), onTap: () => Navigator.pop(ctx, 'json')),
            ListTile(
                title: const Text('导出为CharX'), onTap: () => Navigator.pop(ctx, 'charx')),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (format == null || !context.mounted) return;

    // Share / save to file: ask while the context is still valid, then close
    // the preview dialog.
    final mode = await askExportDelivery(context, '导出格式: $format');
    if (mode == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    try {
      final importService = ref.read(importServiceProvider);

final worldInfoRepo = ref.read(worldInfoRepositoryProvider);
final regexRepo = ref.read(regexScriptRepositoryProvider);

final repo = ref.read(characterRepositoryProvider);
final latestCharacter = await repo.getCharacter(character.id);
final exportChar = latestCharacter ?? character;

Uint8List? avatarData;
final rawAvatarPath = exportChar.assets?.avatarPath;
if (rawAvatarPath != null) {
  final absPath = await PathUtils.toAbsolutePath(rawAvatarPath);
  final f = File(absPath);
  if (await f.exists()) avatarData = await f.readAsBytes();
}

final safeName = exportChar.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

final Uint8List bytes;
final String ext;
switch (format) {
  case 'json':
    bytes = utf8.encode(await importService.exportToJson(exportChar, worldInfoRepo: worldInfoRepo, regexRepo: regexRepo));
    ext = 'json';
    break;
  case 'charx':
    bytes = await importService.exportToCharX(exportChar, avatarData, worldInfoRepo: worldInfoRepo, regexRepo: regexRepo);
    ext = 'charx';
    break;
  case 'png':
  default:
    bytes = await importService.exportToPng(exportChar, avatarData, worldInfoRepo: worldInfoRepo, regexRepo: regexRepo);
    ext = 'png';
    break;
}

final savedPath = await deliverExportFile(
  fileName: '$safeName.$ext',
  bytes: bytes,
  subject: exportChar.name,
  ext: ext,
  mode: mode,
);
      if (savedPath != null &&
          mode == ExportDeliveryMode.save) {
        messenger.showSnackBar(SnackBar(content: Text('已保存到: $savedPath')));
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('导出失败: $e'),
          backgroundColor: DesignTokens.statusError,
        ),
      );
    }
  }

  // Delete
  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    // Confirm first, then close the preview dialog (avoids an invalid context
    // after the preview has been popped).
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      useRootNavigator: true,
      builder: (ctx) => _StyledConfirmDialog(
        title: '删除角色',
        message: '确定删除「${character.name}」？相关聊天与世界书将一并删除，此操作不可撤销。',
        confirmText: '删除',
        danger: true,
      ),
    );
    if (confirmed != true) return;
    Navigator.pop(context);
    try {
      await ref.read(characterRepositoryProvider).deleteCharacter(character.id);
      ref.read(characterListProvider.notifier).refresh();
      if (context.mounted) {
        KiraToast.show(context, '已删除「${character.name}」',
            type: KiraToastType.success);
      }
    } catch (e) {
      if (context.mounted) {
        KiraToast.show(context, '删除失败: $e', type: KiraToastType.error);
      }
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Styled confirmation dialog for destructive actions such as deleting a
/// character.
class _StyledConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final bool danger;
  const _StyledConfirmDialog({
    required this.title,
    required this.message,
    this.confirmText = '确认',
    this.danger = false,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        width: 320,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1B2E) : const Color(0xFFF4F3FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF7B5EA7).withValues(alpha: 0.25),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeHeadline,
                    fontWeight: DesignTokens.weightBold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  )),
              const SizedBox(height: DesignTokens.spaceSm),
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeSm,
                    height: 1.5,
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withValues(alpha: 0.7),
                  )),
              const SizedBox(height: DesignTokens.spaceLg),
              KiraDialogActions(
                confirmText: confirmText,
                confirmColor: danger ? Colors.red : KiraDialogTheme.primary,
                onCancel: () => Navigator.pop(context, false),
                onConfirm: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
