import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kirakira/data/models/character.dart';
import 'package:kirakira/presentation/widgets/chat/typing_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kirakira/data/models/chat.dart';
import 'package:kirakira/data/models/chat_background.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:kirakira/presentation/providers/background_providers.dart';
import 'package:kirakira/presentation/providers/bookmark_providers.dart';
import 'package:kirakira/presentation/providers/chat_providers.dart';
import 'package:kirakira/presentation/providers/settings_providers.dart';
import 'package:kirakira/presentation/theme/app_theme.dart';
import 'package:kirakira/domain/services/regex_service.dart';
import 'package:kirakira/presentation/providers/regex_providers.dart';
import 'package:kirakira/data/models/regex_script.dart';
import 'package:kirakira/presentation/screens/chat/chat_layout_mode.dart';
import 'package:kirakira/presentation/widgets/chat/message_content_widget.dart';
import 'package:kirakira/presentation/widgets/chat/reasoning_widget.dart';
import 'package:kirakira/presentation/widgets/chat/visual_novel_message_view.dart';
import 'package:kirakira/presentation/widgets/common/character_avatar_image.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

class MessageBubble extends ConsumerStatefulWidget {
  final ChatMessage message;
  final int messageIndex;
  final String chatId;
  final Character? character;
  final bool isGenerating;
  final bool isLast;
  final bool hasBackground;
  final double bubbleOpacity;
  final String layoutMode;
  final void Function(int) onSwipe;
  final void Function(String) onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onRegenerate;
  final VoidCallback onContinueFromHere;
  final VoidCallback onDeleteAndAfter;
  final VoidCallback onCreateBookmark;
  final VoidCallback? onGenerateImage;
  final bool allowWebView;
  final bool simplified;

  const MessageBubble({
    super.key,
    required this.message,
    required this.messageIndex,
    required this.chatId,
    required this.character,
    required this.isGenerating,
    required this.isLast,
    this.hasBackground = false,
    this.bubbleOpacity = 0.8,
    this.layoutMode = 'bubble',
    this.allowWebView = true,
    this.simplified = false,
    required this.onSwipe,
    required this.onEdit,
    required this.onDelete,
    this.onRegenerate,
    required this.onContinueFromHere,
    required this.onDeleteAndAfter,
    required this.onCreateBookmark,
    this.onGenerateImage,
  });

  @override
  ConsumerState<MessageBubble> createState() => MessageBubbleState();
}

class MessageBubbleState extends ConsumerState<MessageBubble> {
  bool _isEditing = false;
  bool _forceFullRender = false;
  late TextEditingController _editController;
  String? _cachedContent;
  String? _cachedProcessed;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.message.content);
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.role == MessageRole.user;
    final hasSwipes = widget.message.swipes.length > 1;

    // 正则处理：拿到所有生效脚本，应用到显示内容
    final isSimplified = widget.simplified && !_forceFullRender;
    final displayContent = isSimplified ? widget.message.content : _getCachedProcessedContent();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _buildAvatar(),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onLongPress: () => _showMessageOptions(context),
                  onTap: isSimplified ? () => setState(() => _forceFullRender = true) : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: _buildMessageDecoration(isUser),
                    child: _isEditing
                        ? _buildEditField()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Show image attachments if available
                              if (widget.message.hasAttachments)
                                _buildAttachments(),
                              // Show reasoning/thinking content if available
                              if (!isUser && widget.message.hasReasoning)
                                _buildReasoningSection(),
                              if (widget.isGenerating &&
                                  widget.message.content.isEmpty)
                                const TypingIndicator()
                              else
                                MessageContentWidget(
                                  content: displayContent,
                                  textColor: isUser
                                      ? Colors.white
                                      : AppTheme.textPrimary,
                                  selectable: true,
                                  onLongPress: () =>
                                      _showMessageOptions(context),
                                  isStreaming: widget.isGenerating,
                                  messageId: widget.message.id,
                                  allowWebView: widget.allowWebView && !isSimplified,
                                  initDelay: widget.messageIndex * 300,
                                ),
                            ],
                          ),
                  ),
                ),

                // Swipe controls
                if (hasSwipes && !widget.isGenerating)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, size: 20),
                          onPressed: widget.message.currentSwipeIndex > 0
                              ? () => widget.onSwipe(
                                    widget.message.currentSwipeIndex - 1,
                                  )
                              : null,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        Text(
                          '${widget.message.currentSwipeIndex + 1}/${widget.message.swipes.length}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textMuted,
                                  ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, size: 20),
                          onPressed: widget.message.currentSwipeIndex <
                                  widget.message.swipes.length - 1
                              ? () => widget.onSwipe(
                                    widget.message.currentSwipeIndex + 1,
                                  )
                              : null,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  BoxDecoration _buildMessageDecoration(bool isUser) {
    final isTransparent = widget.layoutMode == 'transparent';

    if (isTransparent && widget.hasBackground) {
      // Transparent mode: very light background with blur effect
      return BoxDecoration(
        color: isUser
            ? AppTheme.accentColor.withValues(alpha: 0.35)
            : Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUser
              ? AppTheme.accentColor.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
        // Glass morphism effect
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );
    } else {
      // Classic bubble mode
      return BoxDecoration(
        color: isUser
            ? (widget.hasBackground
                ? AppTheme.accentColor.withValues(alpha: widget.bubbleOpacity)
                : AppTheme.accentColor)
            : (widget.hasBackground
                ? Colors.transparent.withValues(alpha: widget.bubbleOpacity)
                : Colors.transparent),
        borderRadius: BorderRadius.circular(16),
      );
    }
  }

  Widget _buildAvatar() {
    if (widget.character?.assets?.avatarPath != null) {
      return CharacterAvatarCircle(
        imagePath: widget.character!.assets!.avatarPath!,
        radius: 16,
        errorBuilder: (_, __, ___) => const CircleAvatar(
          radius: 16,
          child: Icon(Icons.person, size: 16),
        ),
      );
    }
    return const CircleAvatar(
      radius: 16,
      child: Icon(Icons.person, size: 16),
    );
  }

  /// Build the reasoning/thinking section for AI messages
  Widget _buildReasoningSection() {
    final l10n = AppLocalizations.of(context);
    final reasoning = widget.message.currentReasoning;
    if (reasoning == null || reasoning.isEmpty) {
      return const SizedBox.shrink();
    }

    // During streaming, show the streaming version
    if (widget.isGenerating && widget.isLast) {
      return StreamingReasoningWidget(
        reasoning: reasoning,
        isStreaming: true,
        label: l10n.thinking,
      );
    }

    // For completed messages, show the collapsible version
    return ReasoningWidget(
      reasoning: reasoning,
      initiallyExpanded: false,
      label: l10n.thinking,
    );
  }

  /// Build image attachments grid for messages
  Widget _buildAttachments() {
    final attachments = widget.message.attachments;
    if (attachments.isEmpty) return const SizedBox.shrink();

    // For single image, show larger preview
    if (attachments.length == 1) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          onTap: () => _showImagePreview(attachments[0]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 250,
                maxHeight: 200,
              ),
              child: Image.file(
                File(attachments[0].path),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 150,
                  height: 100,
                  color: AppTheme.darkBackground,
                  child:
                      const Icon(Icons.broken_image, color: AppTheme.textMuted),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // For multiple images, show a grid
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: attachments.map((attachment) {
          return GestureDetector(
            onTap: () => _showImagePreview(attachment),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(attachment.path),
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 80,
                  height: 80,
                  color: AppTheme.darkBackground,
                  child: const Icon(Icons.broken_image,
                      size: 20, color: AppTheme.textMuted),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Show full-screen image preview
  void _showImagePreview(ChatAttachment attachment) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(attachment.path),
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 200,
                      height: 200,
                      color: AppTheme.darkCard,
                      child: const Icon(Icons.broken_image,
                          size: 48, color: AppTheme.textMuted),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditField() {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        TextField(
          controller: _editController,
          maxLines: null,
          autofocus: true,
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => setState(() => _isEditing = false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                widget.onEdit(_editController.text);
                setState(() => _isEditing = false);
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ],
    );
  }

  void _showMessageOptions(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAssistant = widget.message.role == MessageRole.assistant;

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
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),

            // Copy
            ListTile(
              leading: const Icon(Icons.copy, color: AppTheme.textSecondary),
              title: Text(l10n.copy),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: widget.message.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.copiedToClipboard),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),

            // Edit
            ListTile(
              leading: const Icon(Icons.edit, color: AppTheme.textSecondary),
              title: Text(l10n.edit),
              onTap: () {
                Navigator.pop(context);
                _editController.text = widget.message.content;
                setState(() => _isEditing = true);
              },
            ),

            // Regenerate (only for assistant messages)
            if (isAssistant && widget.onRegenerate != null)
              ListTile(
                leading:
                    const Icon(Icons.refresh, color: AppTheme.primaryColor),
                title: Text(l10n.regenerate),
                subtitle: Text(l10n.generateNewResponse),
                onTap: () {
                  Navigator.pop(context);
                  widget.onRegenerate!();
                },
              ),

            // Continue from here
            ListTile(
              leading:
                  const Icon(Icons.play_arrow, color: AppTheme.accentColor),
              title: Text(l10n.continueFromHere),
              subtitle: Text(
                widget.message.role == MessageRole.user
                    ? l10n.deleteMessagesAfterAndRegenerate
                    : l10n.deleteMessagesAfterThis,
              ),
              onTap: () {
                Navigator.pop(context);
                widget.onContinueFromHere();
              },
            ),

            // Create bookmark
            ListTile(
              leading:
                  const Icon(Icons.bookmark_add, color: AppTheme.accentColor),
              title: Text(l10n.createBookmark),
              subtitle: Text(l10n.saveAsCheckpoint),
              onTap: () {
                Navigator.pop(context);
                widget.onCreateBookmark();
              },
            ),

            // Generate image (if enabled)
            if (widget.onGenerateImage != null)
              ListTile(
                leading: const Icon(Icons.auto_awesome,
                    color: AppTheme.primaryColor),
                title: Text(l10n.generateImagesUsingAi),
                onTap: () {
                  Navigator.pop(context);
                  widget.onGenerateImage!();
                },
              ),

            const Divider(),

            // Delete this message
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.orange),
              title: Text(l10n.deleteThisMessage),
              onTap: () {
                Navigator.pop(context);
                widget.onDelete();
              },
            ),

            // Delete this and all after
            if (!widget.isLast)
              ListTile(
                leading: const Icon(Icons.delete_sweep, color: Colors.red),
                title: Text(
                  l10n.deleteThisAndAllAfter,
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  widget.onDeleteAndAfter();
                },
              ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
  String _getCachedProcessedContent() {
    final current = widget.message.content;
    if (_cachedContent == current && _cachedProcessed != null) {
      return _cachedProcessed!;
    }
    _cachedContent = current;
    _cachedProcessed = _getProcessedContent();
    return _cachedProcessed!;
  }
  /// 应用正则脚本到消息内容（只影响显示，不修改原始数据）
  String _getProcessedContent() {
    final originalContent = widget.message.content;
    if (originalContent.isEmpty) return originalContent;

    // 拿到合并后的正则脚本（全局+角色）
    final scripts = ref.watch(combinedRegexScriptsProvider(widget.character?.id));
    if (scripts.isEmpty) return originalContent;

    // 确定应用范围
    final isUser = widget.message.role == MessageRole.user;
    final placement = isUser ? RegexPlacement.userInput : RegexPlacement.aiOutput;

    // 应用正则（纯渲染层处理，不写回数据库）
    final processed = RegexService.instance.getRegexedString(
      originalContent,
      placement,
      scripts,
      characterName: widget.character?.name,
      userName: null, // 如果有用户名配置可以传进来
      isMarkdown: false,
      isPrompt: false,
      isEdit: false,
      depth: widget.messageIndex,
    );

    return processed;
  }
}