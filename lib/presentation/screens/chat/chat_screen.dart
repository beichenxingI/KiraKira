import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kirakira/core/logger/logger.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kirakira/data/models/character.dart';
import 'package:kirakira/data/models/chat.dart';
import 'package:kirakira/data/models/chat_background.dart';
import 'package:kirakira/domain/services/chat_export_service.dart';
import 'package:kirakira/domain/services/llm_service.dart';
import 'package:kirakira/domain/services/markdown_hotkey_service.dart';
import 'package:kirakira/domain/services/slash_command_service.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/providers/bookmark_providers.dart';
import 'package:kirakira/presentation/providers/background_providers.dart';
import 'package:kirakira/presentation/providers/chat_providers.dart';
import 'package:kirakira/presentation/providers/persona_providers.dart';
import 'package:kirakira/presentation/providers/quick_reply_providers.dart';
import 'package:kirakira/presentation/providers/settings_providers.dart';
import 'package:kirakira/presentation/theme/app_theme.dart';
import 'package:kirakira/presentation/widgets/chat/author_note_dialog.dart';
import 'package:kirakira/presentation/widgets/chat/bookmark_dialog.dart';
import 'package:kirakira/presentation/widgets/chat/chat_background_widget.dart';
import 'package:kirakira/presentation/widgets/chat/message_content_widget.dart';
import 'package:kirakira/presentation/widgets/chat/quick_reply_bar.dart';
import 'package:kirakira/presentation/widgets/chat/markdown_input_field.dart';
import 'package:kirakira/presentation/widgets/chat/reasoning_widget.dart';
import 'package:kirakira/presentation/widgets/chat/slash_command_suggestions.dart';
import 'package:kirakira/presentation/widgets/chat/context_usage_indicator.dart';
import 'package:kirakira/presentation/providers/context_usage_providers.dart';
import 'package:kirakira/presentation/providers/image_gen_providers.dart';
import 'package:kirakira/presentation/widgets/chat/image_generation_dialog.dart';
import 'package:kirakira/presentation/widgets/common/character_avatar_image.dart';
import 'package:kirakira/domain/services/image_generation_service.dart';
import 'package:kirakira/presentation/screens/chat/chat_layout_mode.dart';
import 'package:kirakira/presentation/widgets/chat/visual_novel_message_view.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:kirakira/presentation/widgets/chat/typing_indicator.dart';
import 'package:kirakira/presentation/widgets/chat/input_menu_button.dart';
import 'package:kirakira/presentation/widgets/chat/model_selector_dialog.dart';
import 'package:kirakira/presentation/widgets/chat/message_bubble.dart';


import 'package:kirakira/presentation/screens/chat/widgets/chat_app_bar.dart';
import 'package:kirakira/presentation/widgets/kira_menu.dart';
import 'package:kirakira/presentation/models/kira_menu_item.dart';
import 'package:kirakira/presentation/screens/world_info/world_info_screen.dart';



/// Provider for chat export service
final chatExportServiceProvider = Provider<ChatExportService>((ref) {
  return ChatExportService();
});

/// Chat screen for conversations
class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;

  const ChatScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _showSlashSuggestions = false;
  bool _showInputMenu = false; // 控制输入框左侧菜单的显示
  final List<ChatAttachment> _pendingAttachments = [];
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Load chat and bookmarks when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeChatProvider.notifier).loadChat(widget.chatId);
      ref.read(bookmarkNotifierProvider.notifier).loadBookmarks(widget.chatId);
      // Refresh context usage to ensure fresh calculation
      // This handles cases where world info was updated while not in chat
      refreshContextUsageProviders(ref);
    });

    // Listen for text changes to show/hide slash command suggestions
    _messageController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final text = _messageController.text;
    final shouldShow = text.startsWith('/') && !text.contains(' ');
    if (shouldShow != _showSlashSuggestions) {
      setState(() => _showSlashSuggestions = shouldShow);
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Scroll to bottom with animation (for new messages)
  /// With reverse: true ListView, position 0 is the bottom (newest messages)
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0, // With reverse: true, position 0 is the bottom
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Scroll to bottom immediately without animation (for initial load)
  /// With reverse: true ListView, position 0 is the bottom (newest messages)
  void _scrollToBottomImmediate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController
            .jumpTo(0); // With reverse: true, position 0 is the bottom
      }
    });
  }

  /// Check if API is properly configured
  bool _isApiConfigured(LLMConfig config) {
    // Local providers (Ollama, KoboldCpp) don't need API key
    if (config.provider == LLMProvider.ollama ||
        config.provider == LLMProvider.koboldCpp) {
      return config.apiUrl.isNotEmpty;
    }
    // Cloud providers need API key
    return config.apiKey.isNotEmpty && config.apiUrl.isNotEmpty;
  }

  /// Show dialog to guide user to configure API
  void _showApiConfigurationDialog() {
    final parentContext = context;
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.settings, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(l10n.apiNotConfigured),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.apiNotConfiguredMessage),
            const SizedBox(height: 16),
            Text(
              l10n.supportedProviders,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('�?${l10n.claude} (Anthropic)'),
            Text('�?${l10n.openRouter}'),
            Text('�?${l10n.gemini} (Google)'),
            Text('�?${l10n.ollama} (${l10n.local})'),
            Text('�?${l10n.koboldCpp} (${l10n.local})'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.later),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              // Use go instead of push because /ai-config is inside ShellRoute
              parentContext.go('/ai-config');
            },
            icon: const Icon(Icons.settings),
            label: Text(l10n.configureNow),
          ),
        ],
      ),
    );
  }

  /// Show model selector dialog
  void _showModelSelector() async {
    final l10n = AppLocalizations.of(context);
    final llmConfig = ref.read(llmConfigProvider);
    final llmService = ref.read(llmServiceProvider);

    // Show loading dialog while fetching models
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(l10n.loadingModels),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Fetch available models
      final models = await llmService.getAvailableModels(llmConfig);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (models.isEmpty) {
        _showSnackBar(l10n.noModelsAvailable);
        return;
      }

      // Show model selection dialog
      final selectedModel = await showDialog<String>(
        context: context,
        builder: (context) => ModelSelectorDialog(
          models: models,
          currentModel: llmConfig.model,
          providerName: llmConfig.provider.name,
        ),
      );

      if (selectedModel != null && selectedModel != llmConfig.model) {
        ref.read(llmConfigProvider.notifier).updateModel(selectedModel);
        _showSnackBar(l10n.modelChangedTo(selectedModel));
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      _showSnackBar(l10n.failedToLoadModels(e.toString()));
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    final hasAttachments = _pendingAttachments.isNotEmpty;

    // Allow sending if there's content OR attachments
    if (content.isEmpty && !hasAttachments) return;

    // Check if it's a slash command (only if no attachments)
    if (content.startsWith('/') && !hasAttachments) {
      await _handleSlashCommand(content);
      return;
    }

    final config = ref.read(llmConfigProvider);
    final prefs = await SharedPreferences.getInstance();
    final responseLen = prefs.getInt('response_length_${widget.chatId}');
    final finalConfig = responseLen != null ? config.copyWith(maxTokens: responseLen) : config;

    // Check if API is configured
    if (!_isApiConfigured(config)) {
      _showApiConfigurationDialog();
      return;
    }

    // Capture attachments before clearing
    final attachments = List<ChatAttachment>.from(_pendingAttachments);

    _messageController.clear();
    setState(() {
      _showSlashSuggestions = false;
      _pendingAttachments.clear();
    });

    // Hide keyboard on mobile platforms
    _focusNode.unfocus();

    await ref.read(activeChatProvider.notifier).sendMessage(
          content,
          finalConfig,
          attachments: attachments,
        );
    _scrollToBottom();
  }

  Future<void> _handleSlashCommand(String input) async {
    final slashService = ref.read(slashCommandServiceProvider);
    final result = slashService.parse(input);

    if (!result.isCommand) {
      // Not a command, send as regular message
      final config = ref.read(llmConfigProvider);
      if (!_isApiConfigured(config)) {
        _showApiConfigurationDialog();
        return;
      }
      _messageController.clear();
      setState(() => _showSlashSuggestions = false);

      // Hide keyboard on mobile platforms
      _focusNode.unfocus();

      await ref.read(activeChatProvider.notifier).sendMessage(input, config);
      _scrollToBottom();
      return;
    }

    if (result.error != null) {
      _showCommandError(result.error!);
      return;
    }

    final command = result.command!;
    final argument = result.argument;

    _messageController.clear();
    setState(() => _showSlashSuggestions = false);

    // Hide keyboard on mobile platforms
    _focusNode.unfocus();

    await _executeCommand(command, argument);
  }

  Future<void> _executeCommand(SlashCommand command, String? argument) async {
    final config = ref.read(llmConfigProvider);
    final chatNotifier = ref.read(activeChatProvider.notifier);
    final chatState = ref.read(activeChatProvider);

    switch (command.name) {
      case 'continue':
        if (!_isApiConfigured(config)) {
          _showApiConfigurationDialog();
          return;
        }
        await chatNotifier.continueGeneration(config);
        _scrollToBottom();
        break;

      case 'regenerate':
        if (!_isApiConfigured(config)) {
          _showApiConfigurationDialog();
          return;
        }
        await chatNotifier.regenerateLastMessage(config);
        _scrollToBottom();
        break;

      case 'swipe':
        _handleSwipeCommand(argument);
        break;

      case 'persona':
        context.go('/personas');
        break;

      case 'sys':
        if (argument != null && argument.isNotEmpty) {
          // Send as system/narrator message
          _showSystemMessage(argument);
        }
        break;

      case 'bg':
        // TODO: Implement background change
        _showSnackBar('Background feature coming soon');
        break;

      case 'help':
        _showHelpDialog(argument);
        break;

      case 'clear':
        _showClearConfirmation();
        break;

      case 'edit':
        if (argument != null &&
            argument.isNotEmpty &&
            chatState.messages.isNotEmpty) {
          final lastMessage = chatState.messages.last;
          await chatNotifier.editMessage(lastMessage.id, argument);
        }
        break;

      case 'delete':
        if (chatState.messages.isNotEmpty) {
          final count = int.tryParse(argument ?? '1') ?? 1;
          for (var i = 0; i < count && chatState.messages.isNotEmpty; i++) {
            final lastMessage = ref.read(activeChatProvider).messages.last;
            await chatNotifier.deleteMessage(lastMessage.id);
          }
        }
        break;

      case 'bookmark':
        if (chatState.messages.isNotEmpty) {
          final lastMessage = chatState.messages.last;
          final lastIndex = chatState.messages.length - 1;
          _showCreateBookmarkDialog(lastMessage.id, lastIndex);
        }
        break;

      case 'note':
        if (argument != null && argument.isNotEmpty) {
          await chatNotifier.updateAuthorNote(argument);
          await chatNotifier.toggleAuthorNote(true);
          _showSnackBar('Author\'s note updated');
        } else {
          showAuthorNoteDialog(context);
        }
        break;
    }
  }

  void _handleSwipeCommand(String? argument) {
    final l10n = AppLocalizations.of(context);
    final chatState = ref.read(activeChatProvider);
    if (chatState.messages.isEmpty) return;

    final lastMessage = chatState.messages.last;
    if (lastMessage.swipes.length <= 1) {
      _showSnackBar(l10n.noSwipesAvailable);
      return;
    }

    int newIndex = lastMessage.currentSwipeIndex;

    if (argument == null || argument.isEmpty || argument == 'right') {
      newIndex = (newIndex + 1) % lastMessage.swipes.length;
    } else if (argument == 'left') {
      newIndex = (newIndex - 1 + lastMessage.swipes.length) %
          lastMessage.swipes.length;
    } else {
      final parsed = int.tryParse(argument);
      if (parsed != null &&
          parsed >= 1 &&
          parsed <= lastMessage.swipes.length) {
        newIndex = parsed - 1;
      }
    }

    ref
        .read(activeChatProvider.notifier)
        .swipeMessage(lastMessage.id, newIndex);
  }

  void _showSystemMessage(String content) {
    final l10n = AppLocalizations.of(context);
    // For now, just show a snackbar. In the future, this could inject a system message
    _showSnackBar('${l10n.system}: $content');
  }

  void _showHelpDialog(String? commandName) {
    if (commandName != null && commandName.isNotEmpty) {
      final slashService = ref.read(slashCommandServiceProvider);
      final l10n = AppLocalizations.of(context);
      final help = slashService.getCommandHelp(commandName);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('/$commandName'),
          content: Text(help),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.close),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => const SlashCommandHelpDialog(),
      );
    }
  }

  void _showCommandError(String error) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text(l10n.commandError),
          ],
        ),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _onSlashCommandSelected(SlashCommand command) {
    // Fill in the command with a space for argument
    _messageController.text = '/${command.name} ';
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
    setState(() => _showSlashSuggestions = false);
    _focusNode.requestFocus();
  }

  Future<void> _regenerateMessage() async {
    final config = ref.read(llmConfigProvider);

    // Check if API is configured
    if (!_isApiConfigured(config)) {
      _showApiConfigurationDialog();
      return;
    }

    await ref.read(activeChatProvider.notifier).regenerateLastMessage(config);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(activeChatProvider);
    final llmConfig = ref.watch(llmConfigProvider);
    final isConfigured = _isApiConfigured(llmConfig);

    // Scroll to bottom when new messages arrive or when chat finishes loading
    ref.listen(activeChatProvider, (previous, next) {
      // Scroll to bottom when:
      // 1. New messages are added during conversation
      // 2. Chat finishes loading (transitions from loading to loaded with messages)
      final messageCountChanged =
          previous?.messages.length != next.messages.length;
      final loadingFinished = previous?.isLoading == true &&
          next.isLoading == false &&
          next.messages.isNotEmpty;

      if (messageCountChanged || loadingFinished) {
        _scrollToBottomImmediate();
      }
    });

    return Scaffold(
      appBar: ChatAppBar(onAuthorNotes:()=>showAuthorNoteDialog(context),onWorldInfo:()=>context.push('/world-info'),onExportChat:()=>_showExportDialog(),onResponseLength:()=>_showResponseLengthDialog(),onClearChat:()=>_showClearConfirmationDialog()),
      body: ChatBackgroundWidget(
        characterId: chatState.character?.id,
        child: Column(
          children: [
            // API not configured banner
            if (!isConfigured) _buildApiConfigBanner(),

            // Error banner
            if (chatState.error != null)
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.red.withValues(alpha: 0.2),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        chatState.error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () {
                        // Clear error
                      },
                    ),
                  ],
                ),
              ),

            // Messages list
            Expanded(
              child: chatState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : chatState.messages.isEmpty
                      ? _buildEmptyState()
                      : _buildMessagesArea(chatState),
            ),

            // Slash command suggestions
            if (_showSlashSuggestions)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SlashCommandSuggestions(
                  input: _messageController.text,
                  onSelect: _onSlashCommandSelected,
                  onDismiss: () =>
                      setState(() => _showSlashSuggestions = false),
                ),
              ),

            // Input area
            _buildInputArea(chatState),
          ],
        ),
      ),
    );
  }

  Widget _buildApiConfigBanner() {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppTheme.primaryColor.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.apiNotConfigured,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  l10n.configureApiProvider,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            // Use go instead of push because /ai-config is inside ShellRoute
            onPressed: () => context.go('/ai-config'),
            child: Text(l10n.configure),
          ),
        ],
      ),
    );
  }




  Future<void> _showChatMenu() async {
    final id = await showKiraMenu(
      context: context,
      title: '聊天菜单',
      items: _buildChatMenuItems(),
    );
    if (id == null || !mounted) return;
    _handleMenuSelection(id);
  }

  List<KiraMenuItem> _buildChatMenuItems() {
    return [
      KiraMenuItem(
        id: 'role',
        label: '角色',
        icon: Icons.person,
        children: [
          KiraMenuItem(id: 'char_edit', label: '角色设定', icon: Icons.edit),
          KiraMenuItem(id: 'author_note', label: '作者注释', icon: Icons.note_alt),
        ],
      ),
      KiraMenuItem(
        id: 'regex',
        label: '正则',
        icon: Icons.code,
        children: [
          KiraMenuItem(id: 'global_regex', label: '全局正则', icon: Icons.public),
          KiraMenuItem(id: 'char_regex', label: '角色正则', icon: Icons.person_outline),
        ],
      ),
      KiraMenuItem(id: 'world', label: '世界书', icon: Icons.menu_book),
      KiraMenuItem(
        id: 'tools',
        label: '工具',
        icon: Icons.build,
        children: [
          KiraMenuItem(id: 'response_len', label: '回复字数', icon: Icons.format_size),
          KiraMenuItem(id: 'clear_chat', label: '清空聊天', icon: Icons.delete, isDestructive: true),
          KiraMenuItem(id: 'export_chat', label: '导出聊天', icon: Icons.share),
        ],
      ),
      KiraMenuItem(id: 'search', label: '搜索聊天', icon: Icons.search),
      KiraMenuItem(id: 'image_gen', label: '生图设置', icon: Icons.image),
    ];
  }

  Future<void> _handleMenuSelection(String id) async {
    switch (id) {
      case 'author_note':
        await showAuthorNoteDialog(context);
        break;
      case 'export_chat':
        _showExportDialog();
        break;
      case 'image_gen':
        context.push('/image-gen-settings');
        break;
      case 'world':
        KiraLogger().info('MENU', '菜单点击：世界书 - 准备导航到 /world-info');
        context.push('/world-info');
        KiraLogger().info('MENU', '菜单点击：世界书 - push 已执行');
        break;
      default:
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('功能开发中：$id')),
          );
        }
    }
  }


  double _pendingResponseLength = 200;

  void _showResponseLengthDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'response_length_${widget.chatId}';
    final current = prefs.getInt(key) ?? 200;
    _pendingResponseLength = current.toDouble();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('回复字数'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('当前值：${_pendingResponseLength.round()} 字'),
              const SizedBox(height: 8),
              Slider(
                value: _pendingResponseLength,
                min: 50,
                max: 5000,
                divisions: 99,
                label: _pendingResponseLength.round().toString(),
                onChanged: (v) => setDialogState(() => _pendingResponseLength = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                prefs.setInt(key, _pendingResponseLength.round());
                Navigator.pop(ctx);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearConfirmationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空聊天'),
        content: const Text('确认清空所有聊天记录？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final notifier = ref.read(activeChatProvider.notifier);
              final chatState = ref.read(activeChatProvider);
              for (final msg in chatState.messages) {
                notifier.deleteMessage(msg.id);
              }
              notifier.clearChat();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('确认清空'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context);
    final character = ref.read(activeChatProvider).character;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (character?.assets?.avatarPath != null)
            CharacterAvatarCircle(
              imagePath: character!.assets!.avatarPath!,
              radius: 50,
              errorBuilder: (_, __, ___) => const CircleAvatar(
                radius: 50,
                child: Icon(Icons.person, size: 50),
              ),
            )
          else
            const CircleAvatar(
              radius: 50,
              child: Icon(Icons.person, size: 50),
            ),
          const SizedBox(height: 16),
          Text(
            character?.name ?? l10n.chat,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.startConversation,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesArea(ActiveChatState chatState) {
    final layoutMode =
        ref.watch(appSettingsProvider.select((s) => s.chatLayoutMode));
    final backgroundAsync =
        ref.watch(effectiveBackgroundProvider(chatState.character?.id));
    final background = backgroundAsync.valueOrNull ?? ChatBackground.none;
    final hasBackground = background.type == BackgroundType.image;

    // Only use visual novel mode when there's an image background
    if (layoutMode == 'visualNovel' && hasBackground) {
      return _buildVisualNovelView(chatState);
    }

    return _buildMessageList(chatState);
  }

  Widget _buildVisualNovelView(ActiveChatState chatState) {
    return Column(
      children: [
        // Upper area - shows the background (empty space)
        const Expanded(child: SizedBox.shrink()),
        // Bottom area - message overlay
        VisualNovelMessageView(
          messages: chatState.messages,
          character: chatState.character,
          isGenerating: chatState.isGenerating,
          onLongPress: (message) =>
              _showMessageOptionsForVisualNovel(context, message, chatState),
          onSwipe: (swipeIndex, messageId) {
            ref
                .read(activeChatProvider.notifier)
                .swipeMessage(messageId, swipeIndex);
          },
        ),
      ],
    );
  }

  void _showMessageOptionsForVisualNovel(
      BuildContext context, ChatMessage message, ActiveChatState chatState) {
    final l10n = AppLocalizations.of(context);
    final config = ref.read(llmConfigProvider);
    final isAssistant = message.role == MessageRole.assistant;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(l10n.copy),
              onTap: () {
                Navigator.pop(context);
                // Copy to clipboard
                final content = message.content;
                if (content.isNotEmpty) {
                  // Implement copy
                }
              },
            ),
            if (isAssistant)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: Text(l10n.regenerate),
                onTap: () {
                  Navigator.pop(context);
                  ref
                      .read(activeChatProvider.notifier)
                      .regenerateMessage(message.id, config);
                },
              ),
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: Text(l10n.continueFromHere),
              onTap: () {
                Navigator.pop(context);
                ref
                    .read(activeChatProvider.notifier)
                    .continueFromMessage(message.id, config);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title:
                  Text(l10n.delete, style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(message.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(ActiveChatState chatState) {
    final config = ref.read(llmConfigProvider);
    final backgroundAsync =
        ref.watch(effectiveBackgroundProvider(chatState.character?.id));
    final background = backgroundAsync.valueOrNull ?? ChatBackground.none;
    final hasBackground = background.type != BackgroundType.none;

    return ListView.builder(
      controller: _scrollController,
      reverse:
          true, // Build from bottom up - newest messages at bottom, always visible
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: chatState.messages.length,
      itemBuilder: (context, index) {
        // With reverse: true, we need to reverse the index to maintain correct message order
        // index 0 in reversed list = last message (newest) = should be at bottom
        final actualIndex = chatState.messages.length - 1 - index;
        final message = chatState.messages[actualIndex];
        final isLast = actualIndex == chatState.messages.length - 1;

        final layoutMode =
            ref.watch(appSettingsProvider.select((s) => s.chatLayoutMode));

        return MessageBubble(
          key: ValueKey(message.id),
          message: message,
          messageIndex:
              actualIndex, // Use actual index for bookmarks and other features
          chatId: widget.chatId,
          character: chatState.character,
          isGenerating: isLast && chatState.isGenerating,
          isLast: isLast,
          hasBackground: hasBackground,
          bubbleOpacity: background.bubbleOpacity,
          layoutMode: layoutMode,
          onSwipe: (swipeIndex) {
            ref.read(activeChatProvider.notifier).swipeMessage(
                  message.id,
                  swipeIndex,
                );
          },
          onEdit: (newContent) {
            ref.read(activeChatProvider.notifier).editMessage(
                  message.id,
                  newContent,
                );
          },
          onDelete: () {
            _showDeleteConfirmation(message.id);
          },
          onRegenerate: message.role == MessageRole.assistant
              ? () {
                  ref.read(activeChatProvider.notifier).regenerateMessage(
                        message.id,
                        config,
                      );
                }
              : null,
          onContinueFromHere: () {
            ref.read(activeChatProvider.notifier).continueFromMessage(
                  message.id,
                  config,
                );
          },
          onDeleteAndAfter: () {
            _showDeleteAndAfterConfirmation(message.id);
          },
          onCreateBookmark: () {
            _showCreateBookmarkDialog(message.id, actualIndex);
          },
          onGenerateImage: ref.read(imageGenSettingsProvider).enabled
              ? () {
                  _showImageGenerationDialog(message, chatState.character);
                }
              : null,
        );
      },
    );
  }

  void _showBookmarksDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => BookmarksListDialog(chatId: widget.chatId),
    );
  }

  void _showImageGenerationDialog(
      ChatMessage message, Character? character) async {
    final result = await ImageGenerationDialog.show(
      context,
      basePrompt: message.content,
      characterName: character?.name,
      mode: message.role == MessageRole.assistant
          ? ImageGenMode.lastMessage
          : ImageGenMode.free,
    );

    if (result != null && result.images.isNotEmpty && mounted) {
      final l10n = AppLocalizations.of(context);

      // Save each image to local storage and add as attachment to the message
      try {
        final appDocDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory(p.join(appDocDir.path, 'chat_images'));
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }

        for (int i = 0; i < result.images.length; i++) {
          final imageBytes = result.images[i];
          final imageId = const Uuid().v4();
          final fileName = '${imageId}.${result.format}';
          final filePath = p.join(imagesDir.path, fileName);

          // Save image to file
          final file = File(filePath);
          await file.writeAsBytes(imageBytes);

          // Create attachment
          final attachment = ChatAttachment(
            id: imageId,
            path: filePath,
            mimeType: 'image/${result.format}',
            sizeBytes: imageBytes.length,
          );

          // Add attachment to message
          await ref.read(activeChatProvider.notifier).addAttachmentToMessage(
                message.id,
                attachment,
              );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${l10n.generationComplete} - ${result.images.length} image(s) added')),
        );
      } catch (e) {
        debugPrint('Failed to save generated image: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save image: $e')),
        );
      }
    }
  }

  void _showCreateBookmarkDialog(String messageId, int messageIndex) async {
    final result = await showDialog<dynamic>(
      context: context,
      builder: (context) => CreateBookmarkDialog(
        chatId: widget.chatId,
        messageId: messageId,
        messageIndex: messageIndex,
      ),
    );

    if (result != null && mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.bookmarkCreated)),
      );
    }
  }

  void _showDeleteConfirmation(String messageId) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteMessage),
        content: Text(l10n.deleteMessageConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(activeChatProvider.notifier).deleteMessage(messageId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  void _showDeleteAndAfterConfirmation(String messageId) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteMessages),
        content: Text(l10n.deleteMessagesConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(activeChatProvider.notifier)
                  .deleteMessageAndAfter(messageId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.deleteAll),
          ),
        ],
      ),
    );
  }


  void _handleQuickReply(String message, bool autoSend) {
    final config = ref.read(llmConfigProvider);

    // Check if API is configured
    if (!_isApiConfigured(config)) {
      _showApiConfigurationDialog();
      return;
    }

    if (message.isEmpty) {
      // Empty message means "continue" - just generate without user message
      _focusNode.unfocus(); // Hide keyboard
      ref.read(activeChatProvider.notifier).continueGeneration(config);
      _scrollToBottom();
    } else if (autoSend) {
      // Auto-send: send the message immediately
      _focusNode.unfocus(); // Hide keyboard
      ref.read(activeChatProvider.notifier).sendMessage(message, config);
      _scrollToBottom();
    } else {
      // Fill input field
      _messageController.text = message;
      _focusNode.requestFocus();
    }
  }

  Widget _buildInputArea(ActiveChatState chatState) {
    final quickReplyConfig = ref.watch(quickReplyConfigProvider);
    final enabledReplies = ref.watch(enabledQuickRepliesProvider);
    final showQuickReplies = quickReplyConfig.showQuickReplies &&
        enabledReplies.isNotEmpty &&
        !chatState.isGenerating;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        border: Border(
          top: BorderSide(color: AppTheme.darkDivider),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pending attachments preview
            if (_pendingAttachments.isNotEmpty) _buildAttachmentsPreview(),
            // Menu panel (when expanded)
            if (_showInputMenu)
              _buildInputMenuPanel(showQuickReplies, chatState),
            // Input row with menu button
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Menu button
                IconButton(
                  icon: Icon(
                    _showInputMenu ? Icons.close : Icons.menu,
                    size: 24,
                    color: _showInputMenu
                        ? AppTheme.primaryColor
                        : AppTheme.textMuted,
                  ),
                  onPressed: () =>
                      setState(() => _showInputMenu = !_showInputMenu),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
                const SizedBox(width: 4),
                // Input field
                Expanded(
                  child: MarkdownInputField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    maxLines: 5,
                    minLines: 1,
                    hintText: AppLocalizations.of(context).typeMessage,
                    onSubmitted: (_) => _sendMessage(),
                    textInputAction: TextInputAction.send,
                    showToolbar: false,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context).typeMessage,
                      filled: true,
                      fillColor: AppTheme.darkBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Show stop button when generating, send button otherwise
                if (chatState.isGenerating)
                  IconButton.filled(
                    onPressed: () => ref
                        .read(activeChatProvider.notifier)
                        .cancelGeneration(),
                    icon: const Icon(Icons.stop_circle),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    tooltip: '停止生成',
                  )
                else
                  IconButton.filled(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build the expandable menu panel above the input field
  Widget _buildInputMenuPanel(
      bool showQuickReplies, ActiveChatState chatState) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.darkDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Core tools
          Row(
            children: [
              // Image attachment
              InputMenuButton(
                icon: Icons.image,
                label: AppLocalizations.of(context).attachImage,
                onTap: () {
                  _showAttachmentOptions();
                  setState(() => _showInputMenu = false);
                },
              ),
              const SizedBox(width: 8),
              // Markdown formatting
              InputMenuButton(
                icon: Icons.text_format,
                label: AppLocalizations.of(context).formatting,
                onTap: () => _showFormattingMenu(),
              ),
              const SizedBox(width: 8),
              // Context usage indicator
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.analytics_outlined,
                          size: 18, color: AppTheme.textMuted),
                      const SizedBox(width: 8),
                      const Expanded(child: ContextUsageIndicator()),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Row 2: Quick replies (if enabled)
          if (showQuickReplies) ...[
            const SizedBox(height: 12),
            _buildQuickRepliesInMenu(),
          ],
        ],
      ),
    );
  }

  /// Build quick replies inside the menu panel
  Widget _buildQuickRepliesInMenu() {
    final enabledReplies = ref.watch(enabledQuickRepliesProvider);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: enabledReplies
          .map((reply) => InkWell(
                onTap: () {
                  _handleQuickReply(reply.message, reply.autoSend);
                  setState(() => _showInputMenu = false);
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.darkDivider),
                  ),
                  child: Text(
                    reply.label,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  /// Show markdown formatting popup menu
  void _showFormattingMenu() {
    // Get the size of the screen
    final screenSize = MediaQuery.of(context).size;

    // Position the menu above the input area (near the bottom of the screen)
    showMenu<MarkdownFormat>(
      context: context,
      position: RelativeRect.fromLTRB(
        16, // left padding
        screenSize.height - 350, // show above input area
        16, // right padding
        100, // bottom padding
      ),
      items: [
        _buildFormattingMenuItem(MarkdownFormat.bold, Icons.format_bold, null),
        _buildFormattingMenuItem(
            MarkdownFormat.italic, Icons.format_italic, null),
        _buildFormattingMenuItem(
            MarkdownFormat.underline, Icons.format_underline, null),
        _buildFormattingMenuItem(
            MarkdownFormat.strikethrough, Icons.strikethrough_s, null),
        const PopupMenuDivider(),
        _buildFormattingMenuItem(MarkdownFormat.inlineCode, Icons.code, null),
        _buildFormattingMenuItem(
            MarkdownFormat.codeBlock, Icons.integration_instructions, null),
        const PopupMenuDivider(),
        _buildFormattingMenuItem(MarkdownFormat.link, Icons.link, null),
        _buildFormattingMenuItem(
            MarkdownFormat.quote, Icons.format_quote, null),
        const PopupMenuDivider(),
        _buildFormattingMenuItem(
            MarkdownFormat.bulletList, Icons.format_list_bulleted, null),
        _buildFormattingMenuItem(
            MarkdownFormat.numberedList, Icons.format_list_numbered, null),
      ],
    ).then((format) {
      if (format != null) {
        _applyMarkdownFormat(format);
      }
    });
  }

  PopupMenuItem<MarkdownFormat> _buildFormattingMenuItem(
      MarkdownFormat format, IconData icon, String? shortcut) {
    return PopupMenuItem<MarkdownFormat>(
      value: format,
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 12),
          Text(format.displayName),
          if (shortcut != null) ...[
            const Spacer(),
            Text(
              shortcut,
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Apply markdown formatting to the input field
  void _applyMarkdownFormat(MarkdownFormat format) {
    var currentValue = _messageController.value;
    if (!currentValue.selection.isValid) {
      currentValue = currentValue.copyWith(
        selection: TextSelection.collapsed(offset: currentValue.text.length),
      );
      _messageController.value = currentValue;
    }

    final newValue = MarkdownHotkeyService.applyFormat(
      value: currentValue,
      format: format,
    );
    _messageController.value = newValue;
    _focusNode.requestFocus();
  }

  /// Build preview of pending attachments
  Widget _buildAttachmentsPreview() {
    return Container(
      height: 80,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _pendingAttachments.length,
        itemBuilder: (context, index) {
          final attachment = _pendingAttachments[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(attachment.path),
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 80,
                      height: 80,
                      color: AppTheme.darkCard,
                      child: const Icon(Icons.broken_image,
                          color: AppTheme.textMuted),
                    ),
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () => _removeAttachment(index),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Check if running on desktop platform
  bool get _isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  /// Show attachment options (camera or gallery/files)
  void _showAttachmentOptions() {
    debugPrint('📎 _showAttachmentOptions called, isDesktop: $_isDesktop');

    // On desktop, directly open file picker
    if (_isDesktop) {
      debugPrint('📎 Opening file picker for desktop...');
      _pickImageFromFiles();
      return;
    }

    final l10n = AppLocalizations.of(context);
    // On mobile, show options sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: AppTheme.primaryColor),
              title: Text(l10n.chooseFromGallery),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.camera_alt, color: AppTheme.accentColor),
              title: Text(l10n.takePhoto),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Pick image from files using FilePicker (for desktop)
  Future<void> _pickImageFromFiles() async {
    final l10n = AppLocalizations.of(context);
    debugPrint('📎 _pickImageFromFiles called');
    try {
      debugPrint('📎 Calling FilePicker.platform.pickFiles...');
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        dialogTitle: l10n.selectImages,
      );

      debugPrint('📎 FilePicker result: $result');

      if (result != null && result.files.isNotEmpty) {
        debugPrint('📎 Got ${result.files.length} files');
        for (final file in result.files) {
          debugPrint('📎 File: ${file.name}, path: ${file.path}');
          if (file.path != null) {
            await _addAttachmentFromPath(file.path!);
          }
        }
      } else {
        debugPrint('📎 No files selected or result is null');
      }
    } catch (e, stackTrace) {
      final l10n = AppLocalizations.of(context);
      debugPrint('📎 FilePicker error: $e');
      debugPrint('📎 Stack trace: $stackTrace');
      _showSnackBar(l10n.failedToPickImage(e.toString()));
    }
  }

  /// Pick image from gallery (for mobile)
  Future<void> _pickImageFromGallery() async {
    try {
      final images = await _imagePicker.pickMultiImage(
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      for (final image in images) {
        await _addAttachmentFromXFile(image);
      }
    } catch (e) {
      final l10n = AppLocalizations.of(context);
      _showSnackBar(l10n.failedToPickImage(e.toString()));
    }
  }

  /// Take photo with camera (for mobile)
  Future<void> _takePhoto() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (image != null) {
        await _addAttachmentFromXFile(image);
      }
    } catch (e) {
      final l10n = AppLocalizations.of(context);
      _showSnackBar(l10n.failedToTakePhoto(e.toString()));
    }
  }

  /// Add an attachment from a file path
  Future<void> _addAttachmentFromPath(String filePath) async {
    try {
      // Copy file to app's documents directory for persistence
      final appDir = await getApplicationDocumentsDirectory();
      final attachmentsDir =
          Directory(p.join(appDir.path, 'NativeTavern', 'attachments'));
      await attachmentsDir.create(recursive: true);

      final uuid = const Uuid();
      final extension = p.extension(filePath);
      final newFileName = '${uuid.v4()}$extension';
      final newPath = p.join(attachmentsDir.path, newFileName);

      // Copy file
      final sourceFile = File(filePath);
      await sourceFile.copy(newPath);

      // Get file info
      final fileInfo = await File(newPath).stat();

      final attachment = ChatAttachment(
        id: uuid.v4(),
        path: newPath,
        mimeType: _getMimeType(extension),
        sizeBytes: fileInfo.size,
      );

      setState(() {
        _pendingAttachments.add(attachment);
      });
    } catch (e) {
      final l10n = AppLocalizations.of(context);
      _showSnackBar(l10n.failedToAddAttachment(e.toString()));
    }
  }

  /// Add an attachment from XFile (for mobile image_picker)
  Future<void> _addAttachmentFromXFile(XFile file) async {
    try {
      // Copy file to app's documents directory for persistence
      final appDir = await getApplicationDocumentsDirectory();
      final attachmentsDir =
          Directory(p.join(appDir.path, 'NativeTavern', 'attachments'));
      await attachmentsDir.create(recursive: true);

      final uuid = const Uuid();
      final extension = p.extension(file.path);
      final newFileName = '${uuid.v4()}$extension';
      final newPath = p.join(attachmentsDir.path, newFileName);

      // Copy file
      final bytes = await file.readAsBytes();
      await File(newPath).writeAsBytes(bytes);

      // Get file info
      final fileInfo = await File(newPath).stat();

      final attachment = ChatAttachment(
        id: uuid.v4(),
        path: newPath,
        mimeType: _getMimeType(extension),
        sizeBytes: fileInfo.size,
      );

      setState(() {
        _pendingAttachments.add(attachment);
      });
    } catch (e) {
      final l10n = AppLocalizations.of(context);
      _showSnackBar(l10n.failedToAddAttachment(e.toString()));
    }
  }

  /// Remove an attachment
  void _removeAttachment(int index) {
    setState(() {
      _pendingAttachments.removeAt(index);
    });
  }

  /// Get MIME type from file extension
  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.bmp':
        return 'image/bmp';
            default:
        return 'image/jpeg';
    }
  }

  void _showExportDialog() {
    final l10n = AppLocalizations.of(context);
    final chatState = ref.read(activeChatProvider);
    if (chatState.chat == null || chatState.character == null) {
      _showSnackBar(l10n.noChatToExport);
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.upload, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(l10n.exportChat),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.exportChatWith(chatState.character!.name),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.messagesCount(chatState.messages.length),
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(l10n.chooseExportFormat),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _exportChat(useJsonl: false);
            },
            child: Text(l10n.json),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _exportChat(useJsonl: true);
            },
            child: Text(l10n.jsonlStFormat),
          ),
        ],
      ),
    );
  }

  Future<void> _exportChat({bool useJsonl = true}) async {
    final chatState = ref.read(activeChatProvider);
    if (chatState.chat == null || chatState.character == null) return;

    final exportService = ref.read(chatExportServiceProvider);
    final activePersonaAsync = ref.read(activePersonaProvider);
    final userName = activePersonaAsync.valueOrNull?.name ?? 'User';

    try {
      await exportService.exportAndShare(
        chatState.chat!,
        chatState.messages,
        chatState.character!,
        userName: userName,
        useJsonl: useJsonl,
      );
    } catch (e) {
      final l10n = AppLocalizations.of(context);
      _showSnackBar(l10n.exportFailed(e.toString()));
    }
  }


  Future<void> _importChat() async {
    final l10n = AppLocalizations.of(context);
    final exportService = ref.read(chatExportServiceProvider);

    try {
      final result = await exportService.importFromFile();
      if (result == null) {
        _showSnackBar(l10n.noFileSelected);
        return;
      }

      // Show confirmation dialog with import details
      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.importConfirmation),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${l10n.character}: ${result.characterName}'),
              Text('${l10n.user}: ${result.userName}'),
              Text('${l10n.messages}: ${result.messages.length}'),
              Text(
                  '${l10n.date}: ${result.createDate.toString().split('.')[0]}'),
              if (result.authorNote != null && result.authorNote!.isNotEmpty)
                Text('${l10n.hasAuthorsNote}: ${l10n.yes}'),
              const SizedBox(height: 16),
              Text(
                l10n.importMessagesToCurrentChat,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.import),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Import messages to current chat
      final chatState = ref.read(activeChatProvider);
      if (chatState.chat == null) {
        _showSnackBar(l10n.noActiveChat);
        return;
      }

      // Add imported messages
      final chatNotifier = ref.read(activeChatProvider.notifier);
      final uuid = const Uuid();
      final importedCount = await chatNotifier.importMessages(
        result.messages.map((importedMsg) {
          return importedMsg.toChatMessage(chatState.chat!.id, uuid.v4());
        }).toList(),
      );

      // Update author's note if present
      if (result.authorNote != null && result.authorNote!.isNotEmpty) {
        await chatNotifier.updateAuthorNote(result.authorNote!);
        if (result.authorNoteDepth != null) {
          await chatNotifier.updateAuthorNoteDepth(result.authorNoteDepth!);
        }
        if (result.authorNoteEnabled == true) {
          await chatNotifier.toggleAuthorNote(true);
        }
      }

      _showSnackBar(l10n.importedMessages(importedCount));
      _scrollToBottom();
    } catch (e) {
      _showSnackBar(l10n.importFailed(e.toString()));
    }
  }

  void _showClearConfirmation() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearMessages),
        content: Text(l10n.clearMessagesConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Clear all messages
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.clear),
          ),
        ],
      ),
    );
  }
}





/// Dialog for selecting a model from available models


/// Button widget for the input menu panel






