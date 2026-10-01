import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import '../../data/models/world_info.dart';
import '../providers/world_info_providers.dart';
import '../screens/world_info/world_info_screen.dart';
import '../theme/design_tokens.dart';

/// Character worldbook management dialog (entry point from the editor dialog).
void showCharacterWorldBookDialog(
  BuildContext context,
  WidgetRef ref, {
  required String characterId,
}) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (_) => _CharacterWorldBookDialog(characterId: characterId),
  );
}

class _CharacterWorldBookDialog extends ConsumerWidget {
  final String characterId;

  const _CharacterWorldBookDialog({required this.characterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final worldBooksAsync = ref.watch(characterWorldInfosProvider(characterId));

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 400,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.book, size: 20, color: DesignTokens.primary),
                    const SizedBox(width: 8),
                    Text('世界书',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: DesignTokens.weightSemibold,
                          color: isDark
                              ? const Color(0xFFF0F0F0)
                              : const Color(0xFF2C2C2C),
                        )),
                    const Spacer(),
                    IconButton(
                      icon: Icon(CupertinoIcons.xmark,
                          size: 22,
                          color: isDark
                              ? const Color(0xFF8C8C8C)
                              : const Color(0xFF8E8E93)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(
                  height: 1,
                  color:
                      isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0)),
              // Worldbook list
              Flexible(
                child: worldBooksAsync.when(
                  loading: () => const Center(
                      child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('${l10n.error}: $e',
                        style: const TextStyle(color: DesignTokens.statusError)),
                  ),
                  data: (worldBooks) {
                    if (worldBooks.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.book,
                                size: 40,
                                color: isDark
                                    ? const Color(0xFF6C6C6C)
                                    : const Color(0xFFBDBDBD)),
                            const SizedBox(height: 8),
                            Text('暂无世界书',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? const Color(0xFF8C8C8C)
                                      : const Color(0xFF8E8E93),
                                )),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: worldBooks.length,
                      itemBuilder: (_, i) =>
                          _bookRow(context, ref, worldBooks[i], isDark, l10n),
                    );
                  },
                ),
              ),
              Divider(
                  height: 1,
                  color:
                      isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0)),
              // Create button
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    color: DesignTokens.primary,
                    borderRadius: BorderRadius.circular(10),
                    onPressed: () =>
                        _showMetaDialog(context, ref, l10n, isDark: isDark),
                    child: const Text('新建世界书',
                        style: TextStyle(fontSize: 15, color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bookRow(BuildContext context, WidgetRef ref, WorldInfo worldBook,
      bool isDark, AppLocalizations l10n) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(CupertinoIcons.book,
          size: 20,
          color: isDark ? const Color(0xFF8C8C8C) : const Color(0xFF8E8E93)),
      title: Text(worldBook.name,
          style: TextStyle(
            fontSize: 14,
            fontWeight: DesignTokens.weightMedium,
            color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
          ),
          overflow: TextOverflow.ellipsis),
      subtitle: Text('${worldBook.entries.length} entries',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? const Color(0xFF8C8C8C) : const Color(0xFF8E8E93),
          )),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(CupertinoIcons.pencil,
                size: 18,
                color: isDark
                    ? const Color(0xFF8C8C8C)
                    : const Color(0xFF8E8E93)),
            onPressed: () => _showMetaDialog(context, ref, l10n,
                isDark: isDark, initial: worldBook),
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.trash,
                size: 18, color: Color(0xFFEF5350)),
            onPressed: () => _confirmDelete(context, ref, worldBook, isDark, l10n),
          ),
        ],
      ),
      onTap: () {
        // Entry editing keeps the existing full-screen page
        // (WorldInfoEntriesScreen).
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
              builder: (_) => WorldInfoEntriesScreen(worldInfo: worldBook)),
        );
      },
    );
  }

  /// Create / rename (name + description).
  void _showMetaDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n, {
    required bool isDark,
    WorldInfo? initial,
  }) {
    final nameCtrl = TextEditingController(text: initial?.name ?? '');
    final descCtrl = TextEditingController(text: initial?.description ?? '');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1C1C) : Colors.white,
        title: Text(initial == null ? '新建世界书' : '编辑世界书',
            style: TextStyle(
              color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
            )),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: TextStyle(
                color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
              ),
              decoration: InputDecoration(
                labelText: l10n.name,
                border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(DesignTokens.radiusInput)),
              ),
            ),
            const SizedBox(height: DesignTokens.spaceMd),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              style: TextStyle(
                color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
              ),
              decoration: InputDecoration(
                labelText: l10n.description,
                border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(DesignTokens.radiusInput)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                messengerShow(context, l10n.nameRequired);
                return;
              }
              final notifier = ref.read(worldInfoNotifierProvider.notifier);
              if (initial == null) {
                await notifier.createWorldInfo(
                    name: name,
                    description:
                        descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                    isGlobal: false,
                    characterId: characterId);
              } else {
                await notifier.updateWorldInfo(initial.copyWith(
                    name: name,
                    description:
                        descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim()));
              }
              ref.invalidate(characterWorldInfosProvider(characterId));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, WorldInfo worldBook,
      bool isDark, AppLocalizations l10n) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1C1C) : Colors.white,
        title: Text(l10n.delete,
            style: TextStyle(
              color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2C),
            )),
        content: Text('删除「${worldBook.name}」及其全部条目？',
            style: TextStyle(
              color: isDark ? const Color(0xFF8C8C8C) : const Color(0xFF8E8E93),
            )),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () async {
              await ref
                  .read(worldInfoNotifierProvider.notifier)
                  .deleteWorldInfo(worldBook.id);
              ref.invalidate(characterWorldInfosProvider(characterId));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}

void messengerShow(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
