import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kirakira/data/models/chat.dart';
import 'package:kirakira/data/repositories/character_repository.dart';
import 'package:kirakira/data/repositories/chat_repository.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/providers/chat_providers.dart';
import 'package:kirakira/presentation/providers/vector_storage_providers.dart';
import 'package:kirakira/presentation/router/app_router.dart';
import 'package:kirakira/presentation/theme/app_theme.dart';
import 'package:kirakira/presentation/widgets/common/character_avatar_image.dart';
import 'package:kirakira/presentation/widgets/common/kira_components.dart';

/// Home screen showing recent chats
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Refresh chat list when screen is first created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(allChatsProvider);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh chat list when returning to the app
      ref.invalidate(allChatsProvider);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh chat list whenever dependencies change (e.g., when navigating back)
    ref.invalidate(allChatsProvider);
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: '搜索聊天记录...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.appTitle),
            Text(
              '基于 NativeTavern',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeCaption,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).textTheme.bodySmall?.color
                    ?.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
       ),
      body: Column(
        children: [
          _buildSearchBar(context),
          Expanded(
            child: _ChatListView(searchQuery: _searchQuery),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton.extended(
          onPressed: () => context.push(AppRoutes.characters),
          icon: const Icon(Icons.add),
          label: Text(l10n.newChat),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
}

class _ChatListView extends ConsumerWidget {
  final String searchQuery;

  const _ChatListView({this.searchQuery = ''});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final chatsAsync = ref.watch(allChatsProvider);

    return chatsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(l10n.errorLoadingChats(error.toString())),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(allChatsProvider),
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
      data: (chats) {
        if (chats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 80,
                  color: AppTheme.textMuted,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.noChatsYet,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.startNewConversation,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.push(AppRoutes.characters),
                  icon: const Icon(Icons.people),
                  label: Text(l10n.browseCharacters),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(allChatsProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            cacheExtent: 1200,
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              return _ChatListTile(chat: chat);
            },
          ),
        );
      },
    );
  }
}

class _ChatListTile extends ConsumerWidget {
  final Chat chat;

  const _ChatListTile({required this.chat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final characterAsync = ref.watch(_characterForChatProvider(chat.characterId));
    final lastMessageAsync = ref.watch(_lastMessageProvider(chat.id));

    return KiraCard(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      padding: EdgeInsets.zero,
      onTap: () => context.push('/chat/${chat.id}'),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: characterAsync.when(
          loading: () => const CircleAvatar(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (_, __) => const CircleAvatar(child: Icon(Icons.person)),
          data: (character) {
            final avatarPath = character?.assets?.avatarPath;
            final accent = Theme.of(context).colorScheme.primary;
            if (avatarPath != null && avatarPath.isNotEmpty) {
              return CharacterAvatarCircle(
                imagePath: avatarPath,
                errorBuilder: (_, __, ___) => CircleAvatar(
                  backgroundColor: accent.withValues(alpha: 0.2),
                  child: Text(
                    character?.name.isNotEmpty == true ? character!.name[0].toUpperCase() : '?',
                    style: TextStyle(color: accent),
                  ),
                ),
              );
            }
            return CircleAvatar(
              backgroundColor: accent.withValues(alpha: 0.2),
              child: Text(
                character?.name.isNotEmpty == true ? character!.name[0].toUpperCase() : '?',
                style: TextStyle(color: accent),
              ),
            );
          },
        ),
        title: characterAsync.when(
          loading: () => Text(l10n.loading),
          error: (_, __) => Text(chat.title),
          data: (character) => Text(character?.name ?? chat.title),
        ),
        subtitle: lastMessageAsync.when(
          loading: () => const Text('...'),
          error: (_, __) => Text(l10n.noMessages),
          data: (message) => Text(
            message?.content ?? l10n.noMessagesYet,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatTime(context, chat.updatedAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              padding: EdgeInsets.zero,
              onSelected: (value) => _handleMenuAction(context, ref, value),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(l10n.delete, style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(BuildContext context, DateTime dateTime) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays == 0) {
      // Today - show time
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (diff.inDays == 1) {
      return l10n.yesterday;
    } else if (diff.inDays < 7) {
      return l10n.daysAgo(diff.inDays);
    } else {
      // Show date
      return '${dateTime.month}/${dateTime.day}';
    }
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'delete':
        _showDeleteConfirmation(context, ref);
        break;
    }
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteChat),
        content: Text(l10n.deleteChatConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref.read(chatRepositoryProvider).deleteChat(chat.id);
              // RAG：同步清理内存中的向量集合（库已由 deleteChat 删除）
              ref.read(vectorStorageServiceProvider).deleteCollection(chat.id);
              // 刷新集合列表，并在删的正是活跃集合时清空选择，避免下拉框指向幽灵集合
              ref.read(vectorCollectionsProvider.notifier).refresh();
              final vsSettings = ref.read(vectorStorageSettingsProvider);
              if (vsSettings.activeCollectionId == chat.id) {
                ref.read(vectorStorageSettingsProvider.notifier).setActiveCollection(null);
              }
              ref.invalidate(allChatsProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.chatDeleted)),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}

/// Provider to get character for a chat
final _characterForChatProvider = FutureProvider.family((ref, String characterId) async {
  final repo = ref.watch(characterRepositoryProvider);
  return repo.getCharacter(characterId);
});

/// Provider to get last message for a chat
final _lastMessageProvider = FutureProvider.family((ref, String chatId) async {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.getLastMessage(chatId);
});