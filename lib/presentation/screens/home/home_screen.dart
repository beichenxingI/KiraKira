import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/presentation/utils/export_delivery.dart';
import 'package:kirakira/presentation/widgets/common/kira_search_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kirakira/data/models/chat.dart';
import 'package:kirakira/data/repositories/character_repository.dart';
import 'package:kirakira/data/models/character.dart';
import 'package:kirakira/data/repositories/chat_repository.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/providers/chat_providers.dart';
import 'package:kirakira/presentation/providers/chat_history_provider.dart';
import 'package:kirakira/presentation/providers/persona_providers.dart';
import 'package:kirakira/presentation/providers/vector_storage_providers.dart';
import 'package:kirakira/data/repositories/chronicle_repository.dart';
import 'package:kirakira/domain/services/chat_export_service.dart';
import 'package:kirakira/presentation/router/app_router.dart';
import 'package:kirakira/presentation/theme/app_theme.dart';
import 'package:kirakira/presentation/widgets/common/character_avatar_image.dart';
import 'package:kirakira/presentation/widgets/common/kira_pressable.dart';

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
    // Use the globally unified KiraSearchBar
    return KiraSearchBar(
      controller: _searchController,
      hintText: '搜索聊天记录...',
      onChanged: (value) => setState(() => _searchQuery = value),
      onClear: () => setState(() => _searchQuery = ''),
    );
  }

  /// Chat page size options (10/20/30/50), persisted as chat_history_page_size.
  void _showPageSizeSheet(BuildContext context) {
    final current = ref.read(chatHistoryPageSizeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetCtx) => CupertinoTheme(
        data: CupertinoThemeData(
          brightness: isDark ? Brightness.dark : Brightness.light,
        ),
        child: CupertinoActionSheet(
          title: const Text('每页显示'),
          actions: [
            for (final n in ChatHistoryPageSizeNotifier.kChoices)
              CupertinoActionSheetAction(
                onPressed: () {
                  ref.read(chatHistoryPageSizeProvider.notifier).set(n);
                  Navigator.pop(sheetCtx);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$n 条'),
                    if (n == current) ...[
                      const SizedBox(width: 6),
                      const Icon(CupertinoIcons.checkmark, size: 16),
                    ],
                  ],
                ),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetCtx),
            child: Text(AppLocalizations.of(context).cancel),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? null
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFF7FA),
                    Color(0xFFF7F8FA),
                  ],
                ),
          color: isDark ? DesignTokens.darkBackground : null,
        ),
        child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allChatsProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // No large title at the top; page-size chip, search and new-chat button sit flush with the top edge
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      _PageSizeChip(
                        currentSize: ref.watch(chatHistoryPageSizeProvider),
                        onTap: () => _showPageSizeSheet(context),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _buildSearchBar(context)),
                      const SizedBox(width: 10),
                      _CircleActionButton(
                        icon: CupertinoIcons.square_pencil,
                        onTap: () => context.push(AppRoutes.characters),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: DesignTokens.spaceXs)),
            _ChatListSliver(searchQuery: _searchQuery),
            // Clearance for the bottom capsule navigation bar
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
      ),
    );
  }
}

/// Chat list sliver section (slivers are required to avoid nested scroll conflicts).
/// Paginated by page size: swipe horizontally in the PageView with a page indicator.
class _ChatListSliver extends ConsumerStatefulWidget {
  final String searchQuery;

  const _ChatListSliver({this.searchQuery = ''});

  @override
  ConsumerState<_ChatListSliver> createState() => _ChatListSliverState();
}

class _ChatListSliverState extends ConsumerState<_ChatListSliver> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String _lastQuery = '';

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chatsAsync = ref.watch(allChatsProvider);
    final pageSize = ref.watch(chatHistoryPageSizeProvider);

    // Reset to the first page when the search query changes
    if (widget.searchQuery != _lastQuery) {
      _lastQuery = widget.searchQuery;
      _currentPage = 0;
      if (_pageController.hasClients) _pageController.jumpToPage(0);
    }

    // Each branch returns a list of slivers, merged into one by SliverMainAxisGroup
    return SliverMainAxisGroup(
      slivers: chatsAsync.when(
      loading: () => const [
        SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      error: (error, stack) => [
        SliverFillRemaining(
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
      ],
      data: (chats) {
        // Filter chats by title
        final q = widget.searchQuery.trim().toLowerCase();
        final filtered = q.isEmpty
            ? chats
            : chats
                .where((c) => c.title.toLowerCase().contains(q))
                .toList();

        if (filtered.isEmpty) {
          return [
            SliverFillRemaining(
              child: Center(
                child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
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
          ),
        ];
      }

        // Split into pages of pageSize
        final pageCount = (filtered.length + pageSize - 1) ~/ pageSize;
        if (_currentPage > pageCount - 1) {
          _currentPage = pageCount - 1; // Clamp once the data shrinks
        }

        return [
          // Pagination control
          if (pageCount > 1)
            SliverToBoxAdapter(
              child: _PaginationCard(
                currentPage: _currentPage,
                pageCount: pageCount,
                onPageChange: (page) {
                  setState(() => _currentPage = page);
                  _pageController.jumpToPage(page);
                },
              ),
            ),
          SliverFillRemaining(
            child: PageView.builder(
              controller: _pageController,
              itemCount: pageCount,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, pageIndex) {
                final start = pageIndex * pageSize;
                final pageItems =
                    filtered.skip(start).take(pageSize).toList();
                return ListView.builder(
                  padding: const EdgeInsets.all(DesignTokens.spaceSm),
                  itemCount: pageItems.length,
                  itemBuilder: (context, index) {
                    final chat = pageItems[index];
                    return _StaggeredEntrance(
                      index: index,
                      child: _ChatListTile(chat: chat),
                    );
                  },
                );
              },
            ),
          ),
        ];
      },
      ),
    );
  }
}

class _ChatListTile extends ConsumerWidget {
  final Chat chat;

  const _ChatListTile({required this.chat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final characterAsync = ref.watch(_characterForChatProvider(chat.characterId));
    final lastMessageAsync = ref.watch(_lastMessageProvider(chat.id));

    final cardRadius = BorderRadius.circular(DesignTokens.radiusLg);

    return Container(
      margin: DesignTokens.marginCard,
      decoration: BoxDecoration(
        color: isDark
            ? DesignTokens.darkCard
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: cardRadius,
        border: isDark
            ? Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 0.8,
                ),
              )
            : Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 0.5,
              ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: KiraPressable(
        onTap: () => context.push('/chat/${chat.id}'),
        borderRadius: cardRadius,
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
            _cleanPreview(message?.content),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatTime(context, chat.updatedAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, size: 20),
              padding: EdgeInsets.zero,
              onPressed: () => _showChatActionsSheet(context, ref),
            ),
          ],
        ),
      ),
      ),
    );
  }

  String _cleanPreview(String? raw) {
    if (raw == null || raw.isEmpty) return '(无内容)';
    final text = raw
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '')
        .replaceAll(RegExp(r'\[([^\]]*)\]\([^)]*\)'), r'$1')
        .replaceAll(RegExp(r'[#*`>_~]'), '')
        .trim();
    return text.isEmpty ? '(无内容)' : text;
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

  void _showChatActionsSheet(BuildContext context, WidgetRef ref) {
    final characterAsync = ref.read(_characterForChatProvider(chat.characterId));
    final lastMessageAsync = ref.read(_lastMessageProvider(chat.id));
    final character = characterAsync.asData?.value;
    final lastMessage = lastMessageAsync.asData?.value;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogCtx) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(dialogCtx).size.width - 48 < 400
                ? MediaQuery.of(dialogCtx).size.width - 48
                : 400.0,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Theme.of(dialogCtx).brightness == Brightness.dark
                  ? const Color(0xFF1C1C1C)
                  : Colors.white,
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
                // Cover image
                _buildCoverImage(context, character),
                // Character name
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Text(
                    character?.name ?? chat.title,
                    style: Theme.of(dialogCtx).textTheme.titleLarge?.copyWith(
                          fontWeight: DesignTokens.weightSemibold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 6),
                // Message preview
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    _cleanPreview(lastMessage?.content),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(dialogCtx).textTheme.bodySmall?.copyWith(
                          color: Theme.of(dialogCtx)
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withValues(alpha: 0.7),
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                // Continue chat button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      color: DesignTokens.primary,
                      borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                      onPressed: () {
                        Navigator.pop(dialogCtx);
                        context.push('/chat/${chat.id}');
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.chat_bubble_fill,
                              size: 18, color: Colors.white),
                          SizedBox(width: 8),
                          Text('继续聊天',
                              style: TextStyle(color: Colors.white, fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Action button row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ActionIconButton(
                        icon: CupertinoIcons.arrow_up_doc,
                        label: '导出',
                        color: const Color(0xFF66BB6A),
                        onTap: () {
                          Navigator.pop(dialogCtx);
                          _exportChat(context, ref, character);
                        },
                      ),
                      _ActionIconButton(
                        icon: CupertinoIcons.arrow_down_doc,
                        label: '导入',
                        color: const Color(0xFF42A5F5),
                        onTap: () {
                          Navigator.pop(dialogCtx);
                          _importChatMessages(context, ref);
                        },
                      ),
                      _ActionIconButton(
                        icon: CupertinoIcons.doc_on_doc,
                        label: '复制',
                        color: const Color(0xFF5C6BC0),
                        onTap: () {
                          Navigator.pop(dialogCtx);
                          _duplicateChat(context, ref, character);
                        },
                      ),
                      _ActionIconButton(
                        icon: CupertinoIcons.trash,
                        label: '删除',
                        color: const Color(0xFFEF5350),
                        onTap: () {
                          Navigator.pop(dialogCtx);
                          _showDeleteConfirmation(context, ref);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverImage(BuildContext context, Character? character) {
    final coverPath = character?.assets?.coverPath ?? character?.assets?.avatarPath;
    if (coverPath != null && coverPath.isNotEmpty) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: CharacterAvatarImage(
            imagePath: coverPath,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildCoverPlaceholder(context),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: _buildCoverPlaceholder(context),
    );
  }

  Widget _buildCoverPlaceholder(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: accent.withValues(alpha: 0.15),
        child: Center(
          child: Icon(
            CupertinoIcons.person_crop_circle,
            size: 56,
            color: accent.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Future<void> _importChatMessages(BuildContext context, WidgetRef ref) async {
    // Inject Chronicle capabilities
    final exportService = ChatExportService(
      chronicleRepo: ref.read(chronicleRepositoryProvider),
      vectorStorage: ref.read(vectorStorageServiceProvider),
    );
    final repo = ref.read(chatRepositoryProvider);
    try {
      final result = await exportService.importFromFile();
      if (result == null) {
        if (context.mounted) {
          _showActionResultSnackBar(context, '未选择文件或格式不支持', isError: true);
        }
        return;
      }
      if (result.messages.isEmpty) {
        if (context.mounted) {
          _showActionResultSnackBar(context, '文件中没有消息', isError: true);
        }
        return;
      }
      // Append to the current chat
      for (final msg in result.messages) {
        await repo.addMessage(msg.toChatMessage(chat.id, ''));
      }
      // Restore embedded super-memory
      if (result.chronicleData != null) {
        await exportService.restoreChronicleToChat(chat.id, result.chronicleData!);
      }
      ref.invalidate(allChatsProvider);
      if (context.mounted) {
        _showActionResultSnackBar(
            context, '已导入 ${result.messages.length} 条消息');
      }
    } catch (e) {
      if (context.mounted) {
        _showActionResultSnackBar(context, '导入失败: $e', isError: true);
      }
    }
  }

  Future<void> _exportChat(BuildContext context, WidgetRef ref, Character? character) async {
    if (character == null) {
      _showActionResultSnackBar(context, '角色信息缺失，无法导出', isError: true);
      return;
    }
    // Inject Chronicle capabilities; the export embeds kira_chronicle
    final exportService = ChatExportService(
      chronicleRepo: ref.read(chronicleRepositoryProvider),
      vectorStorage: ref.read(vectorStorageServiceProvider),
    );
    final userName =
        ref.read(activePersonaProvider).valueOrNull?.name ?? 'User';
    try {
      final messages = await ref.read(chatRepositoryProvider).getMessages(chat.id);
      if (context.mounted) {
        _showActionResultSnackBar(context, '正在导出 ${messages.length} 条消息...');
      }
      // Unified export delivery: share or save to file (naming matches exportToFile)
      final content = await exportService.exportToJsonl(
        chat,
        messages,
        character,
        userName: userName,
      );
      await deliverExportFile(
        context: context,
        fileName: '${character.name}_${chat.id}.jsonl',
        bytes: utf8.encode(content),
        subject: 'Chat with ${character.name}',
        ext: 'jsonl',
      );
    } catch (e) {
      if (context.mounted) {
        _showActionResultSnackBar(context, '导出失败: $e', isError: true);
      }
    }
  }

  Future<void> _duplicateChat(
      BuildContext context, WidgetRef ref, Character? character) async {
    final repo = ref.read(chatRepositoryProvider);
    try {
      final messages = await repo.getMessages(chat.id);
      final newChat = await repo.createChat(Chat(
        id: '',
        characterId: chat.characterId,
        groupId: chat.groupId,
        title: '${chat.title} (副本)',
        authorNote: chat.authorNote,
        authorNoteDepth: chat.authorNoteDepth,
        authorNoteEnabled: chat.authorNoteEnabled,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      for (final msg in messages) {
        await repo.addMessage(msg.copyWith(
          id: '',
          chatId: newChat.id,
        ));
      }
      ref.invalidate(allChatsProvider);
      if (context.mounted) {
        _showActionResultSnackBar(context, '已复制（${messages.length} 条消息）');
      }
    } catch (e) {
      if (context.mounted) {
        _showActionResultSnackBar(context, '复制失败: $e', isError: true);
      }
    }
  }

  void _showActionResultSnackBar(BuildContext context, String message,
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
              // RAG: also drop the in-memory vector collection (the underlying store was already deleted by deleteChat)
              ref.read(vectorStorageServiceProvider).deleteCollection(chat.id);
              // Refresh the collection list; clear the active selection when it was the deleted collection so the dropdown never points at a ghost
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
/// List item entrance: staggered fade-in and slide-up with 50ms steps
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
      curve: Interval(delay / total, 1, curve: DesignTokens.curveSpring),
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - t.clamp(0.0, 1.0))),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

// Pagination control
class _PaginationCard extends StatelessWidget {
  final int currentPage;
  final int pageCount;
  final ValueChanged<int> onPageChange;

  const _PaginationCard({
    required this.currentPage,
    required this.pageCount,
    required this.onPageChange,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(DesignTokens.radiusDialog),
          border: isDark
              ? null
              : Border.all(color: theme.dividerColor, width: 0.5),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PaginationButton(
              icon: CupertinoIcons.chevron_left_2,
              enabled: currentPage > 0,
              onTap: () => onPageChange(0),
            ),
            _PaginationButton(
              icon: CupertinoIcons.chevron_left,
              enabled: currentPage > 0,
              onTap: () => onPageChange(currentPage - 1),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '${currentPage + 1}/$pageCount',
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeSm,
                  fontWeight: DesignTokens.weightSemibold,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
            ),
            _PaginationButton(
              icon: CupertinoIcons.chevron_right,
              enabled: currentPage < pageCount - 1,
              onTap: () => onPageChange(currentPage + 1),
            ),
            _PaginationButton(
              icon: CupertinoIcons.chevron_right_2,
              enabled: currentPage < pageCount - 1,
              onTap: () => onPageChange(pageCount - 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaginationButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _PaginationButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CupertinoButton(
      padding: const EdgeInsets.all(8),
      minSize: 32,
      onPressed: enabled ? onTap : null,
      child: Icon(
        icon,
        size: 18,
        color: enabled
            ? theme.textTheme.bodyMedium?.color
            : theme.disabledColor,
      ),
    );
  }
}

// Top bar widgets
class _PageSizeChip extends StatelessWidget {
  final int currentSize;
  final VoidCallback onTap;

  const _PageSizeChip({
    required this.currentSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? DesignTokens.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
          border: isDark
              ? null
              : Border.all(color: theme.dividerColor, width: 0.5),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$currentSize条/页',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeSm,
                fontWeight: DesignTokens.weightMedium,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              CupertinoIcons.chevron_down,
              size: 14,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleActionButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? DesignTokens.darkSurface : Colors.white,
          shape: BoxShape.circle,
          border: isDark
              ? null
              : Border.all(color: theme.dividerColor, width: 0.5),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Icon(
          icon,
          size: 20,
          color: DesignTokens.primary,
        ),
      ),
    );
  }
}

// Round action buttons used by the chat actions dialog
class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionIconButton({
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
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }
}
