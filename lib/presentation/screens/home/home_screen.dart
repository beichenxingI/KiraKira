import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/widgets/common/kira_search_bar.dart';
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
    // 宪法 §六.4:全局统一 KiraSearchBar
    return KiraSearchBar(
      controller: _searchController,
      hintText: '搜索聊天记录...',
      onChanged: (value) => setState(() => _searchQuery = value),
      onClear: () => setState(() => _searchQuery = ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allChatsProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 返工条目2:砍顶部大标题"聊天",搜索+新写按钮接顶
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    Expanded(child: _buildSearchBar(context)),
                    IconButton(
                      icon: const Icon(CupertinoIcons.square_pencil),
                      tooltip: l10n.newChat,
                      onPressed: () => context.push(AppRoutes.characters),
                    ),
                    const SizedBox(width: DesignTokens.spaceSm),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: DesignTokens.spaceXs)),
            _ChatListSliver(searchQuery: _searchQuery),
            // 避让底部胶囊导航
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }
}

/// 聊天列表 sliver 段(C-T2:嵌套滚动问题 → 必须 sliver 化)
class _ChatListSliver extends ConsumerWidget {
  final String searchQuery;

  const _ChatListSliver({this.searchQuery = ''});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final chatsAsync = ref.watch(allChatsProvider);

    return chatsAsync.when(
      loading: () => const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: DesignTokens.statusError),
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
      ),
      data: (chats) {
        // 修复死参:搜索词真正生效(标题过滤)
        final q = searchQuery.trim().toLowerCase();
        final filtered = q.isEmpty
            ? chats
            : chats
                .where((c) => c.title.toLowerCase().contains(q))
                .toList();

        if (filtered.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 80,
                    color: AppTheme.darkTextTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noChatsYet,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppTheme.darkTextSecondary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.startNewConversation,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.darkTextTertiary,
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
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.all(DesignTokens.spaceSm),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final chat = filtered[index];
                return _StaggeredEntrance(
                  index: index,
                  child: _ChatListTile(chat: chat),
                );
              },
              childCount: filtered.length,
            ),
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
      margin: DesignTokens.marginCard,
      padding: EdgeInsets.zero,
      onTap: () => context.push('/chat/${chat.id}'),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceMd,
          vertical: DesignTokens.spaceXs,
        ),
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
                      const Icon(Icons.delete, color: DesignTokens.statusError),
                      const SizedBox(width: 8),
                      Text(l10n.delete,
                          style: const TextStyle(color: DesignTokens.statusError)),
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
            style: TextButton.styleFrom(foregroundColor: DesignTokens.statusError),
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
/// 列表项进场:错峰 50ms 淡入上移(宪法 §五)
class _StaggeredEntrance extends StatelessWidget {
  final int index;
  final Widget child;

  const _StaggeredEntrance({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    const duration = DesignTokens.durationMd;
    final delay = index.clamp(0, 12) * 50;
    final total = duration + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: DesignTokens.curveDecelerate),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
