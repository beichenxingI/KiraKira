import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/models/bookmark.dart';
import 'package:kirakira/data/models/chat.dart';
import 'package:kirakira/data/models/character.dart';
import 'package:kirakira/data/models/group.dart';
import 'package:kirakira/data/models/persona.dart';
import 'package:kirakira/data/models/prompt_manager.dart';
import 'package:kirakira/data/models/world_info.dart';
import 'package:kirakira/data/repositories/chat_repository.dart';
import 'package:kirakira/data/repositories/character_repository.dart';
import 'package:kirakira/data/repositories/persona_repository.dart';
import 'package:kirakira/domain/services/llm_service.dart';
import 'package:kirakira/domain/services/macro_service.dart';
import 'package:kirakira/domain/services/variables_service.dart';
import 'package:kirakira/domain/services/chat_summarization_service.dart';
import 'package:kirakira/presentation/providers/group_providers.dart';
import 'package:kirakira/presentation/providers/llm_configs_provider.dart';
import 'package:kirakira/presentation/providers/persona_providers.dart';
import 'package:kirakira/presentation/providers/prompt_manager_providers.dart';
import 'package:kirakira/presentation/providers/settings_providers.dart';
import 'package:kirakira/presentation/providers/world_info_providers.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:kirakira/presentation/providers/image_gen_providers.dart';
import 'package:kirakira/domain/services/image_generation_service.dart';
import 'package:kirakira/presentation/providers/tts_providers.dart';
import 'package:kirakira/presentation/providers/vector_storage_providers.dart';
import 'package:kirakira/data/models/vector_storage.dart'
    show EmbeddingProvider, EmbeddingProviderExtension;
import 'package:kirakira/data/repositories/chronicle_repository.dart';
import 'package:kirakira/presentation/providers/chronicle_providers.dart';
import 'package:kirakira/data/models/chronicle.dart'
    show
        MemoryEntity,
        MemoryEntry,
        MemoryRelationship,
        EmotionNode,
        WindowedMessages;
import 'package:kirakira/core/utils/file_utils.dart';

// Note: Repository providers are defined in their respective repository files
// llmServiceProvider is defined in settings_providers.dart

/// Current active chat ID
final activeChatIdProvider = StateProvider<String?>((ref) => null);


/// Active chat state
class ActiveChatState {
  final Chat? chat;
  final Character? character;
  final Group? group; // For group chats
  final Map<String, Character>
      groupCharacters; // Character cache for group chats
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isGenerating;
  final bool isGeneratingImage; // Auto image generation in progress (drives the pulsing indicator)
  final String? generatingImageMsgId; // ID of the message currently generating an image
  final double imageGenProgress; // Auto image generation progress, 0~1
  final String? imageGenError; // Auto image generation error (one-shot notice)
  final String? error;
  final String?
      currentResponderId; // Which character is currently responding (group chat)

  const ActiveChatState({
    this.chat,
    this.character,
    this.group,
    this.groupCharacters = const {},
    this.messages = const [],
    this.isLoading = false,
    this.isGenerating = false,
    this.isGeneratingImage = false,
    this.generatingImageMsgId,
    this.imageGenProgress = 0,
    this.imageGenError,
    this.error,
    this.currentResponderId,
  });

  /// Check if this is a group chat
  bool get isGroupChat => group != null;

  ActiveChatState copyWith({
    Chat? chat,
    Character? character,
    Group? group,
    bool clearGroup = false,
    Map<String, Character>? groupCharacters,
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isGenerating,
    bool? isGeneratingImage,
    String? generatingImageMsgId,
    bool clearGeneratingImageMsgId = false,
    double? imageGenProgress,
    String? imageGenError,
    String? error,
    String? currentResponderId,
    bool clearCurrentResponder = false,
  }) {
    return ActiveChatState(
      chat: chat ?? this.chat,
      character: character ?? this.character,
      group: clearGroup ? null : (group ?? this.group),
      groupCharacters: groupCharacters ?? this.groupCharacters,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isGenerating: isGenerating ?? this.isGenerating,
      isGeneratingImage: isGeneratingImage ?? this.isGeneratingImage,
      generatingImageMsgId: clearGeneratingImageMsgId
          ? null
          : (generatingImageMsgId ?? this.generatingImageMsgId),
      imageGenProgress: imageGenProgress ?? this.imageGenProgress,
      imageGenError: imageGenError, // One-shot: cleared when omitted
      error: error,
      currentResponderId: clearCurrentResponder
          ? null
          : (currentResponderId ?? this.currentResponderId),
    );
  }
}

/// Active chat notifier
class ActiveChatNotifier extends StateNotifier<ActiveChatState> {
  final ChatRepository _chatRepository;
  final CharacterRepository _characterRepository;
  final PersonaRepository _personaRepository;
  final LLMService _llmService;
  final WorldInfoMatcher _worldInfoMatcher;
  final ChatSummarizationService _summarizationService;
  final Ref _ref;

  // Track cancellation flag for stream processing
  bool _isCancelling = false;
  int _generationToken = 0;

  // IDs of entries already injected by the fixed layer, used for recall layer deduplication
  Set<String> _lastF6EntryIds = {};

  ActiveChatNotifier({
    required ChatRepository chatRepository,
    required CharacterRepository characterRepository,
    required PersonaRepository personaRepository,
    required LLMService llmService,
    required WorldInfoMatcher worldInfoMatcher,
    required ChatSummarizationService summarizationService,
    required Ref ref,
  })  : _chatRepository = chatRepository,
        _characterRepository = characterRepository,
        _personaRepository = personaRepository,
        _llmService = llmService,
        _worldInfoMatcher = worldInfoMatcher,
        _summarizationService = summarizationService,
        _ref = ref,
        super(const ActiveChatState());

  /// Cancel current generation
  Future<void> cancelGeneration() async {
    _isCancelling = true;
    _generationToken++; // Invalidate the token: any running loop aborts immediately
    // Loops return right away on token invalidation and skip cleanup, so remove the
    // empty placeholder here. Same criterion as failure handling: the last message is
    // an assistant with empty content = a thinking bubble that received nothing.
    // A partial reply with non-empty content is kept.
    final msgs = List<ChatMessage>.from(state.messages);
    if (msgs.isNotEmpty &&
        msgs.last.role == MessageRole.assistant &&
        msgs.last.content.trim().isEmpty) {
      msgs.removeLast();
      state = state.copyWith(messages: msgs, isGenerating: false);
    } else {
      state = state.copyWith(isGenerating: false);
    }
    Future.delayed(const Duration(milliseconds: 500), () {
      _isCancelling = false;
    });
  }

  /// Updates the active chat's character snapshot (fixes stale data after a character edit).
  /// Swaps only the character field and does not set isLoading, avoiding a full-page
  /// reload flicker; LLM prompt assembly (sendMessage/_buildContextUpTo) reads this snapshot.
  /// Pass a new instance (content changed, id unchanged): _charSub only watches the id,
  /// so no re-injection storm is triggered.
  void updateCharacterSnapshot(Character character) {
    state = state.copyWith(character: character);
  }

  /// Load a chat by ID
  Future<void> loadChat(String chatId) async {
    _generationToken++; // Invalidate any running generation before switching chats
    _isCancelling = true; // Cut off generation still running for the previous chat
    state = state.copyWith(isLoading: true, error: null);
    // Must reset right after this chat loads; otherwise the stop flag stays set and
    // every later generation breaks after a few tokens (empty reply but still billed).
    _isCancelling = false;

    try {
      final chat = await _chatRepository.getChat(chatId);
      if (chat == null) {
        state = state.copyWith(isLoading: false, error: 'Chat not found');
        return;
      }

      final character =
          await _characterRepository.getCharacter(chat.characterId);
      final messages = await _chatRepository.getMessages(chatId);

      // Temporary debug: verify the character data loaded by loadChat
      debugPrint('═══ [loadChat] 读取角色数据 ═══');
      debugPrint('[loadChat] chatId = $chatId');
      debugPrint('[loadChat] characterId = ${chat.characterId}');
      debugPrint('[loadChat] character != null: ${character != null}');
      if (character != null) {
        debugPrint('[loadChat] character.id = ${character.id}');
        debugPrint('[loadChat] character.name = ${character.name}');
        debugPrint('[loadChat] description 长度: ${character.description.length}');
        if (character.description.isNotEmpty) {
          final preview = character.description.length > 80 
              ? character.description.substring(0, 80) 
              : character.description;
          debugPrint('[loadChat] description 开头: $preview');
        }
        debugPrint('[loadChat] systemPrompt 长度: ${character.systemPrompt.length}');
        debugPrint('[loadChat] extensions 键: ${character.extensions.keys.join(", ")}');
        debugPrint('[loadChat] characterBook != null: ${character.characterBook != null}');
        if (character.characterBook != null) {
          debugPrint('[loadChat] characterBook 条目数: ${character.characterBook!.entries.length}');
        }
      }
      debugPrint('═══ [loadChat] 结束 ═══\n');

      // Restore this chat's local variables (TavernHelper getVariables archive)
      await VariablesService.instance.loadLocalVariablesFromPrefs(chatId);

      // Check if this is a group chat
      if (chat.isGroupChat) {
        final groupsAsync = _ref.read(groupListProvider);
        final groups = groupsAsync.valueOrNull ?? [];
        final group = groups.firstWhere(
          (g) => g.id == chat.groupId,
          orElse: () => throw Exception('Group not found'),
        );

        // Load all group member characters
        final groupChars = <String, Character>{};
        for (final member in group.members) {
          final char =
              await _characterRepository.getCharacter(member.characterId);
          if (char != null) {
            groupChars[char.id] = char;
          }
        }

        state = state.copyWith(
          chat: chat,
          character: character,
          group: group,
          groupCharacters: groupChars,
          messages: messages,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          chat: chat,
          character: character,
          clearGroup: true,
          groupCharacters: const {},
          messages: messages,
          isLoading: false,
        );
      }

      // RAG: prepare and activate a dedicated vector collection for this chat
      try {
        final vsService = _ref.read(vectorStorageServiceProvider);
        if (vsService.getCollection(chatId) == null) {
          // Dimensions are read dynamically from the current embedding provider
          // (local bge = 384) instead of the hardcoded 512, a historical mistake:
          // the local model actually outputs 384 dimensions.
          final vsSettings = _ref.read(vectorStorageSettingsProvider);
          vsService.createCollectionWithId(
            id: chatId,
            name: chat.title,
            dimensions: vsSettings.embeddingProvider.defaultDimensions,
          );
          _ref.read(vectorCollectionsProvider.notifier).refresh();
        }
        _ref
            .read(vectorStorageSettingsProvider.notifier)
            .setActiveCollection(chatId);
      } catch (e) {
        // Collection setup failures must not block chat loading
      }

      // One-time legacy summary migration (async, does not block loading)
      if (chat.summaries.isNotEmpty) {
        final orchestrator = _ref.read(chronicleOrchestratorProvider);
        unawaited(orchestrator.migrateOldSummaries(chat));
      }
    } catch (e, stackTrace) {
      debugPrint('❌ ChatProvider error: $e\n$stackTrace');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Create a new chat with a character
  Future<String?> createChat(String characterId, {String? selectedGreeting}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final character = await _characterRepository.getCharacter(characterId);
      if (character == null) {
        state = state.copyWith(isLoading: false, error: 'Character not found');
        return null;
      }

      final chat = Chat(
        id: _generateId(),
        characterId: characterId,
        title: 'Chat with ${character.name}',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _chatRepository.createChat(chat);

      // Add first message (greeting) if character has one
      final greetingText = selectedGreeting ?? character.firstMessage;
      if (greetingText.isNotEmpty) {
        // Get active persona for macro processing
        final activePersonaId = _ref.read(activePersonaIdProvider);
        Persona? persona;
        if (activePersonaId != null) {
          persona = await _personaRepository.getPersona(activePersonaId);
        }
        persona ??= await _personaRepository.getDefaultPersona();

        // Process macros in the greeting
        final macroContext = MacroContext.fromData(
          character: character,
          persona: persona,
          chat: chat,
          messages: [],
        );
        final processedGreeting =
            MacroService(macroContext).process(greetingText);

        // The primary greeting plus all alternate greetings go into swipes,
        // matching SillyTavern: swipe 0 is the primary greeting, swipe 1+ are alternates.
        // Front-loaded cards commonly use setChatMessage to switch to swipe 1 for the
        // actual story start.
        final allSwipes = <String>[processedGreeting];
        for (final alt in character.alternateGreetings) {
          if (alt.trim().isEmpty) continue;
          allSwipes.add(MacroService(macroContext).process(alt));
        }

        final greeting = ChatMessage(
          id: _generateId(),
          chatId: chat.id,
          role: MessageRole.assistant,
          content: processedGreeting,
          timestamp: DateTime.now(),
          swipes: allSwipes,
          currentSwipeIndex: 0,
        );
        await _chatRepository.addMessage(greeting);
        state = state.copyWith(
          chat: chat,
          character: character,
          messages: [greeting],
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          chat: chat,
          character: character,
          messages: [],
          isLoading: false,
        );
      }

      return chat.id;
    } catch (e, stackTrace) {
      debugPrint('❌ ChatProvider createChat error: $e\n$stackTrace');
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  /// Create a new group chat
  Future<String?> createGroupChat(Group group) async {
    if (group.members.isEmpty) return null;

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Load all member characters
      final groupChars = <String, Character>{};
      for (final member in group.members) {
        final char =
            await _characterRepository.getCharacter(member.characterId);
        if (char != null) {
          groupChars[char.id] = char;
        }
      }

      if (groupChars.isEmpty) {
        state = state.copyWith(
            isLoading: false, error: 'No valid characters in group');
        return null;
      }

      // Use first member as the "primary" character
      final firstCharId = group.members.first.characterId;
      final firstChar = groupChars[firstCharId]!;

      final chat = Chat(
        id: _generateId(),
        characterId: firstCharId,
        groupId: group.id,
        title: 'Chat with ${group.name}',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _chatRepository.createChat(chat);

      // Get active persona for macro processing
      final activePersonaId = _ref.read(activePersonaIdProvider);
      Persona? persona;
      if (activePersonaId != null) {
        persona = await _personaRepository.getPersona(activePersonaId);
      }
      persona ??= await _personaRepository.getDefaultPersona();

      // Generate initial greetings from each character (if they have one)
      final messages = <ChatMessage>[];
      for (final member in group.members.where((m) => !m.isMuted)) {
        final char = groupChars[member.characterId];
        if (char != null && char.firstMessage.isNotEmpty) {
          // Process macros in the greeting
          final macroContext = MacroContext.fromData(
            character: char,
            persona: persona,
            chat: chat,
            messages: messages,
            groupCharacters: groupChars.values.toList(),
          );
          final processedGreeting =
              MacroService(macroContext).process(char.firstMessage);

          final greeting = ChatMessage(
            id: _generateId(),
            chatId: chat.id,
            role: MessageRole.assistant,
            content: processedGreeting,
            timestamp: DateTime.now(),
            swipes: [processedGreeting],
            currentSwipeIndex: 0,
            characterId: char.id,
            characterName: char.name,
          );
          await _chatRepository.addMessage(greeting);
          messages.add(greeting);
        }
      }

      state = state.copyWith(
        chat: chat,
        character: firstChar,
        group: group,
        groupCharacters: groupChars,
        messages: messages,
        isLoading: false,
      );

      return chat.id;
    } catch (e, stackTrace) {
      debugPrint('❌ ChatProvider createGroupChat error: $e\n$stackTrace');
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  /// Send a user message and get AI response
  Future<void> sendMessage(
    String content,
    LLMConfig config, {
    List<ChatAttachment> attachments = const [],
  }) async {
    if (state.chat == null) return;

    // For group chats, use group message handling
    if (state.isGroupChat) {
      await sendGroupMessage(content, config, attachments: attachments);
      return;
    }

    if (state.character == null) return;

    // Add user message
    final userMessage = ChatMessage(
      id: _generateId(),
      chatId: state.chat!.id,
      role: MessageRole.user,
      content: content,
      timestamp: DateTime.now(),
      swipes: [content],
      currentSwipeIndex: 0,
      attachments: attachments,
    );

    await _chatRepository.addMessage(userMessage);
    _indexMessageToVector(chatId: userMessage.chatId, messageId: userMessage.id, content: userMessage.content);
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isGenerating: true,
      error: null,
    );

    // Chronicle takes over compaction (queues async summarization); falls back to the
    // legacy summary path when disabled or on failure
    final chronicleHandled = await _ref
        .read(chronicleOrchestratorProvider)
        .checkAndEnqueue(
          chatId: state.chat!.id,
          messages: state.messages,
          llmConfig: config,
        );
    if (!chronicleHandled) {
      await _checkAndSummarize(config);
    }

    final context = await _buildContext();

    try {
      // Create placeholder for assistant message
      final assistantMessage = ChatMessage(
        id: _generateId(),
        chatId: state.chat!.id,
        role: MessageRole.assistant,
        content: '',
        timestamp: DateTime.now(),
        swipes: [''],
        currentSwipeIndex: 0,
      );

      state = state.copyWith(
        messages: [...state.messages, assistantMessage],
      );

      String finalContent;
      String? finalReasoning;

      if (config.streamEnabled) {
        // Stream the response with reasoning support
        final contentBuffer = StringBuffer();
        final reasoningBuffer = StringBuffer();
        final int myToken = ++_generationToken;
        final String myChatId = state.chat!.id;
        await for (final chunk
            in _llmService.generateStreamWithReasoning(context, config)) {
          // Validate the token: stop and discard immediately if it expired or the chat
          // switched, so output can never bleed into another chat
          if (myToken != _generationToken || state.chat?.id != myChatId) {
            return;
          }
          if (_isCancelling) break;
          if (chunk.isReasoningChunk && chunk.reasoning != null) {
            reasoningBuffer.write(chunk.reasoning);
          }
          if (chunk.content != null) {
            contentBuffer.write(chunk.content);
          }
          final updatedMessage = assistantMessage.copyWith(
            content: contentBuffer.toString(),
            swipes: [contentBuffer.toString()],
            reasoning:
                reasoningBuffer.isNotEmpty ? reasoningBuffer.toString() : null,
            reasoningSwipes: reasoningBuffer.isNotEmpty
                ? [reasoningBuffer.toString()]
                : null,
          );

          final updatedMessages = List<ChatMessage>.from(state.messages);
          updatedMessages[updatedMessages.length - 1] = updatedMessage;
          state = state.copyWith(messages: updatedMessages);
        }
        finalContent = contentBuffer.toString();
        finalReasoning =
            reasoningBuffer.isNotEmpty ? reasoningBuffer.toString() : null;
      } else {
        // Non-streaming: get complete response at once with reasoning support
        final response =
            await _llmService.generateWithReasoning(context, config);
        finalContent = response.content;
        finalReasoning = response.reasoning;

        // Update the message with final content
        final updatedMessage = assistantMessage.copyWith(
          content: finalContent,
          swipes: [finalContent],
        );
        final updatedMessages = List<ChatMessage>.from(state.messages);
        updatedMessages[updatedMessages.length - 1] = updatedMessage;
        state = state.copyWith(messages: updatedMessages);
      }

      // Empty reply handling: if the AI returned nothing, drop the placeholder
      // message, surface an "empty reply" error, and skip persistence so no empty
      // bubble is left looking stuck. A user-cancelled partial reply never reaches
      // here (the loop already broke/returned above).
      if (finalContent.trim().isEmpty) {
        final withoutEmpty = List<ChatMessage>.from(state.messages)
          ..removeWhere((m) => m.id == assistantMessage.id);
        state = state.copyWith(
          messages: withoutEmpty,
          isGenerating: false,
          error: '收到空回复',
        );
        return;
      }

      // Save the final message
      final finalMessage = assistantMessage.copyWith(
        content: finalContent,
        swipes: [finalContent],
        reasoning: finalReasoning,
        reasoningSwipes: finalReasoning != null ? [finalReasoning] : null,
      );
      await _chatRepository.addMessage(finalMessage);
      _indexMessageToVector(chatId: finalMessage.chatId, messageId: finalMessage.id, content: finalMessage.content);

      state = state.copyWith(isGenerating: false);

      // Auto image generation (does not block the main flow; failures do not affect the chat)
      _maybeAutoGenerateImage(finalMessage, config);
      // Auto-play: speak the new AI reply after it is persisted (does not block the main flow)
      _maybeAutoSpeak(finalMessage);
    } catch (e, stackTrace) {
      debugPrint('❌ ChatProvider sendMessage error: $e\n$stackTrace');
      // On failure (503/400/network etc.) remove the still-"thinking" placeholder so
      // the UI never spins forever. Criterion: the last message is an assistant with
      // empty content = a placeholder that received no tokens. If the stream broke
      // after partial content arrived, content is non-empty and the message is kept.
      final msgs = List<ChatMessage>.from(state.messages);
      if (msgs.isNotEmpty &&
          msgs.last.role == MessageRole.assistant &&
          msgs.last.content.trim().isEmpty) {
        msgs.removeLast();
      }
      state = state.copyWith(
        messages: msgs,
        isGenerating: false,
        error: e.toString(),
      );
    }
  }
  /// Auto image generation: extracts <image> tags from the AI reply according to the
  /// autoImageMode setting. File names matching ai_auto_{messageId}_* act as the
  /// "already generated" marker so re-entry never regenerates duplicates.
  Future<void> _maybeAutoGenerateImage(ChatMessage msg, LLMConfig config) async {
    try {
      final settings = _ref.read(imageGenSettingsProvider);
      final mode = settings.autoImageMode;
      debugPrint('[自动生图] 触发检查: mode=$mode, enabled=${settings.enabled}, role=${msg.role}');
      if (mode == AutoImageMode.off) { debugPrint('[自动生图] 跳过: 模式关闭'); return; }
      if (!settings.enabled) { debugPrint('[自动生图] 跳过: 生图总开关未开'); return; }
      if (msg.role != MessageRole.assistant) { debugPrint('[自动生图] 跳过: 非AI消息'); return; }

      final chatId = msg.chatId;

      // Extract the <image>...</image> tag content
      String? prompt = ImageGenerationService.extractImagePrompt(msg.content);
      debugPrint('[自动生图] 提取标签: ${prompt ?? "(无标签)"}');

      if (prompt == null || prompt.isEmpty) {
        // No tag: prompt-only mode has no fallback, so exit here
        if (mode == AutoImageMode.promptOnly) return;

        // Plain body with the tags stripped out
        final body = msg.content
            .replaceAll(RegExp(r'<image>[\s\S]*?</image>', caseSensitive: false), '')
            .trim();

        // Skip when there is no substantial content: a reply this short has no visual
        // scene worth rendering
        if (body.length < 10) {
          debugPrint('[自动生图] 跳过: 正文过短无视觉内容');
          return;
        }

        // Call the LLM once to distill the body into English visual tags, which yields
        // better results than sending the raw text
        prompt = await _extractVisualTags(body, config);
        if (prompt == null || prompt.isEmpty) {
          debugPrint('[自动生图] 跳过: 提炼视觉标签失败');
          return;
        }
        debugPrint('[自动生图] 提炼标签: $prompt');
      }

      // promptOnly mode: extract tags without generating an image
      if (mode == AutoImageMode.promptOnly) return;

      // Duplicate guard: check whether this message already has auto-generated images
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(base.path, 'chat_images', chatId));
      if (!await dir.exists()) await dir.create(recursive: true);
      final already = dir
          .listSync()
          .whereType<File>()
          .any((f) => p.basename(f.path).startsWith('ai_auto_${msg.id}_'));
      if (already) return; // Image already generated, skip

      // Invoke the image service (spinner placeholder with pulsing indicator)
      state = state.copyWith(
        isGeneratingImage: true,
        generatingImageMsgId: msg.id,
        imageGenProgress: 0,
      );
      final service = _ref.read(imageGenServiceProvider);
      // SSE progress callback updates the placeholder progress
      service.onProgress = (p) {
        state = state.copyWith(imageGenProgress: p);
      };
      try {
        // Prepend the user-configured positive prefix to the final prompt
        // (e.g. "masterpiece, best quality, ")
        final prefix = settings.positivePromptPrefix;
        final finalPrompt = (prefix != null && prefix.isNotEmpty)
            ? '$prefix${prompt.trim()}'
            : prompt;
        final result = await service.generate(ImageGenRequest(
          prompt: finalPrompt,
          width: settings.defaultWidth,
          height: settings.defaultHeight,
          steps: settings.defaultSteps,
          cfgScale: settings.defaultCfgScale,
          sampler: settings.defaultSampler,
          model: settings.model,
          negativePrompt: settings.defaultNegativePrompt,
        ));

        if (result != null && result.images.isNotEmpty) {
          for (var i = 0; i < result.images.length; i++) {
            final name = 'ai_auto_${msg.id}_$i.${result.format}';
            final filePath = p.join(dir.path, name);
            await File(filePath).writeAsBytes(result.images[i]);
            // Add the generated image to the message's attachments so the bubble renders it
            await addAttachmentToMessage(
              msg.id,
              ChatAttachment(
                id: 'ai_auto_${msg.id}_$i',
                path: filePath,
                mimeType: 'image/${result.format}',
                width: settings.defaultWidth,
                height: settings.defaultHeight,
              ),
            );
          }
          debugPrint('[自动生图] 消息 ${msg.id} 生成 ${result.images.length} 张，已加入 attachments');
        }
      } finally {
        service.onProgress = null; // Unbind so manual generation is unaffected
        state = state.copyWith(
          isGeneratingImage: false,
          clearGeneratingImageMsgId: true,
        );
      }
    } catch (e) {
      debugPrint('[自动生图] 失败: $e');
      state = state.copyWith(
          imageGenError: '配图生成失败，请检查 Local Dream 是否已加载模型');
    }
  }

  /// Speaks a newly persisted AI reply automatically.
  /// Triggers only when ttsSettings.autoPlay is enabled and the message is a non-empty
  /// assistant message; if a new reply arrives while already speaking, speakByStyle
  /// stops first and reads the latest one. Does not block the main flow and swallows
  /// all exceptions (TTS failures do not affect the chat).
  void _maybeAutoSpeak(ChatMessage msg) {
    try {
      final ttsSettings = _ref.read(ttsSettingsProvider);
      if (!ttsSettings.autoPlay) return;
      if (!ttsSettings.enabled) return;
      if (msg.role != MessageRole.assistant) return;
      if (msg.content.trim().isEmpty) return;
      _ref.read(ttsSpeakProvider)(msg.content);
    } catch (e) {
      debugPrint('[autoPlay] 自动朗读失败: $e');
    }
  }

  /// Makes a second LLM call to distill a passage into comma-separated English visual
  /// tags. Returns null on failure. Note: this consumes one extra API call.
  /// If extractionInstruction is non-empty it replaces the hardcoded default instruction.
  /// When enableAutoPromptGeneration and autoPromptConfigId are set, the selected API
  /// service config is used instead of the default llmConfigProvider.
  Future<String?> _extractVisualTags(String body, LLMConfig config) async {
    try {
      final truncated = body.length > 600 ? body.substring(0, 600) : body;
      final settings = _ref.read(imageGenSettingsProvider);
      final instruction = (settings.extractionInstruction != null &&
              settings.extractionInstruction!.isNotEmpty)
          ? settings.extractionInstruction!
          : 'You are a prompt extractor for an image generator. '
              'Read the text and output ONLY a comma-separated list of English '
              'visual tags describing the scene (characters, appearance, actions, '
              'environment, lighting). No sentences, no explanation, tags only. '
              'If there is no visual scene, output: NONE';
      final messages = <Map<String, dynamic>>[
        {'role': 'system', 'content': instruction},
        {'role': 'user', 'content': truncated},
      ];
      // Prefer the user-selected API service (overrides model/key/endpoint)
      LLMConfig effectiveConfig = config;
      if (settings.enableAutoPromptGeneration &&
          settings.autoPromptConfigId != null) {
        final configs = _ref.read(llmConfigsProvider);
        final selected = configs.configs
            .where((c) => c.id == settings.autoPromptConfigId)
            .firstOrNull;
        if (selected != null) {
          effectiveConfig = config.copyWith(
            model: selected.model ?? config.model,
            apiKey: selected.apiKey ?? config.apiKey,
            apiUrl: selected.endpoint,
          );
        }
      }
      final resp = await _llmService.generateWithReasoning(messages, effectiveConfig);
      final tags = resp.content.trim();
      if (tags.isEmpty || tags.toUpperCase().contains('NONE')) return null;
      return tags;
    } catch (e) {
      debugPrint('[自动生图] 提炼调用失败: $e');
      return null;
    }
  }

  /// Regeneration entropy injection: nudges temperature up at low settings so identical
  /// context does not yield near-duplicate output, and randomizes a fixed seed
  /// (-1 means no seed is sent, letting the server choose).
  LLMConfig _withRegenerateEntropy(LLMConfig config) {
    final double bumped = config.temperature < 0.6
        ? (config.temperature + 0.15).clamp(0.0, 2.0).toDouble()
        : config.temperature;
    final int seed = config.seed == -1
        ? -1
        : DateTime.now().millisecondsSinceEpoch % 100000;
    return config.copyWith(temperature: bumped, seed: seed);
  }

  /// Regenerate the last assistant message
  Future<void> regenerateLastMessage(LLMConfig config) async {
    if (state.messages.isEmpty) return;

    final lastMessage = state.messages.last;
    if (lastMessage.role != MessageRole.assistant) return;

    // Entropy injection: regeneration shares the original context, so entropy is needed
    // to avoid near-duplicate output at low temperature
    config = _withRegenerateEntropy(config);

    state = state.copyWith(isGenerating: true, error: null);

    try {
      final context = await _buildContext(excludeLastAssistant: true);

      String finalContent;
      String? finalReasoning;

      if (config.streamEnabled) {
        // Streaming mode
        final contentBuffer = StringBuffer();
        final reasoningBuffer = StringBuffer();
        final int myToken = ++_generationToken;
        final String myChatId = state.chat!.id;
        await for (final chunk
            in _llmService.generateStreamWithReasoning(context, config)) {
          // Validate the token: stop and discard immediately if it expired or the chat
          // switched, so output can never bleed into another chat
          if (myToken != _generationToken || state.chat?.id != myChatId) {
            return;
          }
          if (_isCancelling) break;

          if (chunk.isReasoningChunk && chunk.reasoning != null) {
            reasoningBuffer.write(chunk.reasoning);
          }
          if (chunk.content != null) {
            contentBuffer.write(chunk.content);
          }

          final newSwipes = List<String>.from(lastMessage.swipes);
          final newSwipeIndex = newSwipes.length;
          newSwipes.add(contentBuffer.toString());

          // Handle reasoning swipes
          final newReasoningSwipes =
              List<String>.from(lastMessage.reasoningSwipes ?? []);
          while (newReasoningSwipes.length < newSwipeIndex) {
            newReasoningSwipes.add('');
          }
          if (reasoningBuffer.isNotEmpty) {
            if (newReasoningSwipes.length <= newSwipeIndex) {
              newReasoningSwipes.add(reasoningBuffer.toString());
            } else {
              newReasoningSwipes[newSwipeIndex] = reasoningBuffer.toString();
            }
          }

          final updatedMessage = lastMessage.copyWith(
            content: contentBuffer.toString(),
            swipes: newSwipes,
            currentSwipeIndex: newSwipeIndex,
            reasoning:
                reasoningBuffer.isNotEmpty ? reasoningBuffer.toString() : null,
            reasoningSwipes:
                newReasoningSwipes.isNotEmpty ? newReasoningSwipes : null,
          );

          final updatedMessages = List<ChatMessage>.from(state.messages);
          updatedMessages[updatedMessages.length - 1] = updatedMessage;
          state = state.copyWith(messages: updatedMessages);
        }
        finalContent = contentBuffer.toString();
        finalReasoning =
            reasoningBuffer.isNotEmpty ? reasoningBuffer.toString() : null;
      } else {
        // Non-streaming mode with reasoning support
        final response =
            await _llmService.generateWithReasoning(context, config);
        finalContent = response.content;
        finalReasoning = response.reasoning;
      }

      // Save the updated message
      final newSwipes = List<String>.from(lastMessage.swipes);
      newSwipes.add(finalContent);

      // Handle reasoning swipes for final message
      final newReasoningSwipes =
          List<String>.from(lastMessage.reasoningSwipes ?? []);
      while (newReasoningSwipes.length < newSwipes.length - 1) {
        newReasoningSwipes.add('');
      }
      if (finalReasoning != null && finalReasoning.isNotEmpty) {
        newReasoningSwipes.add(finalReasoning);
      }

      final finalMessage = lastMessage.copyWith(
        content: finalContent,
        swipes: newSwipes,
        currentSwipeIndex: newSwipes.length - 1,
        reasoning: finalReasoning,
        reasoningSwipes:
            newReasoningSwipes.isNotEmpty ? newReasoningSwipes : null,
      );
      await _chatRepository.updateMessage(finalMessage);

      state = state.copyWith(isGenerating: false);
    } catch (e, stackTrace) {
      debugPrint('❌ ChatProvider regenerateLastMessage error: $e\n$stackTrace');
      state = state.copyWith(isGenerating: false, error: e.toString());
    }
  }

  /// Swipe to a different response variant
  Future<void> swipeMessage(String messageId, int swipeIndex) async {
    final messageIndex = state.messages.indexWhere((m) => m.id == messageId);
    if (messageIndex < 0) return;

    final message = state.messages[messageIndex];
    if (swipeIndex < 0 || swipeIndex >= message.swipes.length) return;

    final updatedMessage = message.copyWith(
      content: message.swipes[swipeIndex],
      currentSwipeIndex: swipeIndex,
    );

    await _chatRepository.updateMessage(updatedMessage);

    final updatedMessages = List<ChatMessage>.from(state.messages);
    updatedMessages[messageIndex] = updatedMessage;
    state = state.copyWith(messages: updatedMessages);
  }

  /// Edit a message
  Future<void> editMessage(String messageId, String newContent) async {
    final messageIndex = state.messages.indexWhere((m) => m.id == messageId);
    if (messageIndex < 0) return;

    final message = state.messages[messageIndex];
    final updatedSwipes = List<String>.from(message.swipes);
    updatedSwipes[message.currentSwipeIndex] = newContent;

    final updatedMessage = message.copyWith(
      content: newContent,
      swipes: updatedSwipes,
    );

    await _chatRepository.updateMessage(updatedMessage);

    final updatedMessages = List<ChatMessage>.from(state.messages);
    updatedMessages[messageIndex] = updatedMessage;
    state = state.copyWith(messages: updatedMessages);
  }
  /// Updates per-swipe variables for a single message (MVU setChatMessages target)
  Future<void> updateMessageSwipesData(
      String messageId, List<Map<String, dynamic>> swipesData) async {
    final messageIndex = state.messages.indexWhere((m) => m.id == messageId);
    if (messageIndex < 0) return;

    final updatedMessage =
        state.messages[messageIndex].copyWith(swipesData: swipesData);

    await _chatRepository.updateMessage(updatedMessage);

    final updatedMessages = List<ChatMessage>.from(state.messages);
    updatedMessages[messageIndex] = updatedMessage;
    state = state.copyWith(messages: updatedMessages);
  }

  /// Hides/shows a single message (/hide and /unhide target, SillyTavern is_system semantics)
  Future<void> setMessageHidden(String messageId, bool hidden) async {
    final messageIndex = state.messages.indexWhere((m) => m.id == messageId);
    if (messageIndex < 0) return;

    final updatedMessage =
        state.messages[messageIndex].copyWith(isHidden: hidden);

    await _chatRepository.updateMessage(updatedMessage);

    final updatedMessages = List<ChatMessage>.from(state.messages);
    updatedMessages[messageIndex] = updatedMessage;
    state = state.copyWith(messages: updatedMessages);
  }

  /// Delete a message
  Future<void> deleteMessage(String messageId) async {
    await _chatRepository.deleteMessage(messageId);
    state = state.copyWith(
      messages: state.messages.where((m) => m.id != messageId).toList(),
    );
  }

  /// Add an attachment to an existing message
  Future<void> addAttachmentToMessage(
      String messageId, ChatAttachment attachment) async {
    final messageIndex = state.messages.indexWhere((m) => m.id == messageId);
    if (messageIndex < 0) return;

    final message = state.messages[messageIndex];
    final updatedAttachments = [...message.attachments, attachment];

    final updatedMessage = message.copyWith(
      attachments: updatedAttachments,
    );

    await _chatRepository.updateMessage(updatedMessage);

    final updatedMessages = List<ChatMessage>.from(state.messages);
    updatedMessages[messageIndex] = updatedMessage;
    state = state.copyWith(messages: updatedMessages);
  }

  /// Delete a message and all messages after it
  Future<void> deleteMessageAndAfter(String messageId) async {
    final messageIndex = state.messages.indexWhere((m) => m.id == messageId);
    if (messageIndex < 0) return;

    // Delete all messages from this index onwards
    final messagesToDelete = state.messages.sublist(messageIndex);
    for (final msg in messagesToDelete) {
      await _chatRepository.deleteMessage(msg.id);
    }

    state = state.copyWith(
      messages: state.messages.sublist(0, messageIndex),
    );
  }

  /// Regenerate a specific assistant message (adds new swipe)
  Future<void> regenerateMessage(String messageId, LLMConfig config) async {
    final messageIndex = state.messages.indexWhere((m) => m.id == messageId);
    if (messageIndex < 0) return;

    final message = state.messages[messageIndex];
    if (message.role != MessageRole.assistant) return;

    // Entropy injection: regeneration shares the original context, so entropy is needed
    // to avoid near-duplicate output at low temperature
    config = _withRegenerateEntropy(config);

    // Append an empty placeholder swipe first so the user sees a "thinking" state while rerolling
    final placeholderSwipes = List<String>.from(message.swipes)..add('');
    final placeholderMessage = message.copyWith(
      content: '',
      swipes: placeholderSwipes,
      currentSwipeIndex: placeholderSwipes.length - 1,
    );
    final placeholderMessages = List<ChatMessage>.from(state.messages);
    placeholderMessages[messageIndex] = placeholderMessage;
    state = state.copyWith(
      messages: placeholderMessages,
      isGenerating: true,
      error: null,
    );

    try {
      final context = await _buildContextUpTo(messageIndex);

      String finalContent;
      String? finalReasoning;

      if (config.streamEnabled) {
        final contentBuffer = StringBuffer();
        final reasoningBuffer = StringBuffer();
        final int myToken = ++_generationToken;
        final String myChatId = state.chat!.id;
        await for (final chunk
            in _llmService.generateStreamWithReasoning(context, config)) {
          if (myToken != _generationToken || state.chat?.id != myChatId) {
            return;
          }
          if (_isCancelling) break;

          if (chunk.isReasoningChunk && chunk.reasoning != null) {
            reasoningBuffer.write(chunk.reasoning);
          }
          if (chunk.content != null) {
            contentBuffer.write(chunk.content);
          }

          // Read the latest message from state (including the placeholder swipe) and
          // update only the last swipe
          final current = state.messages[messageIndex];
          final streamSwipes = List<String>.from(current.swipes);
          streamSwipes[streamSwipes.length - 1] = contentBuffer.toString();

          final streamReasoningSwipes =
              List<String>.from(current.reasoningSwipes ?? []);
          while (streamReasoningSwipes.length < streamSwipes.length - 1) {
            streamReasoningSwipes.add('');
          }
          if (reasoningBuffer.isNotEmpty) {
            if (streamReasoningSwipes.length < streamSwipes.length) {
              streamReasoningSwipes.add(reasoningBuffer.toString());
            } else {
              streamReasoningSwipes[streamSwipes.length - 1] =
                  reasoningBuffer.toString();
            }
          }

          final streamMessage = current.copyWith(
            content: contentBuffer.toString(),
            swipes: streamSwipes,
            currentSwipeIndex: streamSwipes.length - 1,
            reasoning:
                reasoningBuffer.isNotEmpty ? reasoningBuffer.toString() : null,
            reasoningSwipes:
                streamReasoningSwipes.isNotEmpty ? streamReasoningSwipes : null,
          );
          final streamMessages = List<ChatMessage>.from(state.messages);
          streamMessages[messageIndex] = streamMessage;
          state = state.copyWith(messages: streamMessages);
        }
        finalContent = contentBuffer.toString();
        finalReasoning =
            reasoningBuffer.isNotEmpty ? reasoningBuffer.toString() : null;
      } else {
        final response =
            await _llmService.generateWithReasoning(context, config);
        finalContent = response.content;
        finalReasoning = response.reasoning;
      }

      // Read the latest state after streaming ends, finalize the last swipe, and persist it
      final latestMessage = state.messages[messageIndex];
      final finalSwipes = List<String>.from(latestMessage.swipes);
      finalSwipes[finalSwipes.length - 1] = finalContent;

      final finalReasoningSwipes =
          List<String>.from(latestMessage.reasoningSwipes ?? []);
      while (finalReasoningSwipes.length < finalSwipes.length - 1) {
        finalReasoningSwipes.add('');
      }
      if (finalReasoning != null && finalReasoning.isNotEmpty) {
        if (finalReasoningSwipes.length < finalSwipes.length) {
          finalReasoningSwipes.add(finalReasoning);
        } else {
          finalReasoningSwipes[finalSwipes.length - 1] = finalReasoning;
        }
      }

      final finalMessage = latestMessage.copyWith(
        content: finalContent,
        swipes: finalSwipes,
        currentSwipeIndex: finalSwipes.length - 1,
        reasoning: finalReasoning,
        reasoningSwipes:
            finalReasoningSwipes.isNotEmpty ? finalReasoningSwipes : null,
      );
      await _chatRepository.updateMessage(finalMessage);

      state = state.copyWith(
        messages: List<ChatMessage>.from(state.messages)
          ..[messageIndex] = finalMessage,
        isGenerating: false,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ ChatProvider regenerateMessage error: $e\n$stackTrace');
      // On cancel or failure, remove the trailing empty placeholder swipe so no empty shell remains
      final msgs = List<ChatMessage>.from(state.messages);
      final current = msgs[messageIndex];
      if (current.swipes.length > 1 && current.swipes.last.trim().isEmpty) {
        final cleanSwipes =
            current.swipes.sublist(0, current.swipes.length - 1);
        msgs[messageIndex] = current.copyWith(
          content: cleanSwipes.last,
          swipes: cleanSwipes,
          currentSwipeIndex: cleanSwipes.length - 1,
        );
      }
      state = state.copyWith(
        messages: msgs,
        isGenerating: false,
        error: e.toString(),
      );
    }
  }

  /// Continue from a specific message (delete all after and regenerate)
  Future<void> continueFromMessage(String messageId, LLMConfig config) async {
    final messageIndex = state.messages.indexWhere((m) => m.id == messageId);
    if (messageIndex < 0) return;

    // Delete all messages after this one
    if (messageIndex < state.messages.length - 1) {
      final messagesToDelete = state.messages.sublist(messageIndex + 1);
      for (final msg in messagesToDelete) {
        await _chatRepository.deleteMessage(msg.id);
      }
      state = state.copyWith(
        messages: state.messages.sublist(0, messageIndex + 1),
      );
    }

    // If the message is from user, generate assistant response
    final message = state.messages[messageIndex];
    if (message.role == MessageRole.user) {
      await _generateAssistantResponse(config);
    }
  }
  /// Retry: branches on the role of the tapped message.
  /// - Assistant message: delete it and everything after it, then regenerate from the
  ///   previous message.
  /// - User message: keep it, delete everything after it, then regenerate from it.
  Future<void> retryMessage(String messageId, LLMConfig config) async {
    final messageIndex = state.messages.indexWhere((m) => m.id == messageId);
    if (messageIndex < 0) return;
    final message = state.messages[messageIndex];

    // Determine how far to keep (inclusive): for an assistant message keep up to the
    // previous one, for a user message keep through itself.
    final keepUpTo =
        message.role == MessageRole.assistant ? messageIndex : messageIndex + 1;

    // Capture all IDs to delete up front so state changes cannot cause missed deletions
    final deleteIds =
        state.messages.sublist(keepUpTo).map((m) => m.id).toList();
    // Update in-memory state first so the UI reflects it immediately
    state = state.copyWith(messages: state.messages.sublist(0, keepUpTo));
    // Then delete from the database one by one; a single failure does not affect the rest
    for (final delId in deleteIds) {
      try {
        await _chatRepository.deleteMessage(delId);
      } catch (e) {
        debugPrint('⚠ retry 删除消息失败 $delId: $e');
      }
    }

    // Generate a new AI reply from the remaining context
    await _generateAssistantResponse(config);
  }

  /// Continue: only available for assistant messages. Creates a new assistant bubble
  /// whose context includes the message being continued so the model picks up from it.
  Future<void> continueMessage(String messageId, LLMConfig config) async {
    if (state.chat == null) return;
    final messageIndex = state.messages.indexWhere((m) => m.id == messageId);
    if (messageIndex < 0) return;
    final message = state.messages[messageIndex];
    if (message.role != MessageRole.assistant) return;

    state = state.copyWith(isGenerating: true, error: null);
    try {
      // Truncate the context through the continued message (inclusive) so the model
      // continues from it
      final context = await _buildContextUpTo(messageIndex + 1);

      // Create a new empty assistant bubble that starts from scratch
      final newMessage = ChatMessage(
        id: _generateId(),
        chatId: state.chat!.id,
        role: MessageRole.assistant,
        content: '',
        timestamp: DateTime.now(),
        swipes: [''],
        currentSwipeIndex: 0,
      );
      state = state.copyWith(messages: [...state.messages, newMessage]);

      final contentBuffer = StringBuffer();
      final int myToken = ++_generationToken;
      final String myChatId = state.chat!.id;

      if (config.streamEnabled) {
        await for (final chunk
            in _llmService.generateStreamWithReasoning(context, config)) {
          if (myToken != _generationToken || state.chat?.id != myChatId) {
            return;
          }
          if (_isCancelling) break;
          if (chunk.content != null) {
            contentBuffer.write(chunk.content);
          }
          final updated = newMessage.copyWith(
            content: contentBuffer.toString(),
            swipes: [contentBuffer.toString()],
          );
          final msgs = List<ChatMessage>.from(state.messages);
          final idx = msgs.indexWhere((m) => m.id == newMessage.id);
          if (idx >= 0) {
            msgs[idx] = updated;
            state = state.copyWith(messages: msgs);
          }
        }
      } else {
        final response =
            await _llmService.generateWithReasoning(context, config);
        contentBuffer.write(response.content);
      }

      final finalMessage = newMessage.copyWith(
        content: contentBuffer.toString(),
        swipes: [contentBuffer.toString()],
      );
      await _chatRepository.addMessage(finalMessage);
      _indexMessageToVector(chatId: finalMessage.chatId, messageId: finalMessage.id, content: finalMessage.content);
      final msgs = List<ChatMessage>.from(state.messages);
      final idx = msgs.indexWhere((m) => m.id == newMessage.id);
      if (idx >= 0) msgs[idx] = finalMessage;
      state = state.copyWith(messages: msgs, isGenerating: false);
    } catch (e, st) {
      debugPrint('❌ continueMessage error: $e\n$st');
      state = state.copyWith(isGenerating: false, error: e.toString());
    }
  }

  /// Continue generation without user message (for "Continue" quick reply)
  Future<void> continueGeneration(LLMConfig config) async {
    if (state.chat == null) return;

    // For group chats, pick a character to respond
    if (state.isGroupChat) {
      final group = state.group;
      if (group == null) return;

      final activeMemberIds = group.members
          .where((m) => !m.isMuted)
          .map((m) => m.characterId)
          .toList();

      if (activeMemberIds.isEmpty) return;

      // Pick the next character in sequence
      final lastAssistantMsg = state.messages.reversed.firstWhere(
        (m) => m.role == MessageRole.assistant && m.characterId != null,
        orElse: () => state.messages.first,
      );

      String nextCharId;
      if (lastAssistantMsg.characterId != null) {
        final lastIndex =
            activeMemberIds.indexOf(lastAssistantMsg.characterId!);
        final nextIndex = (lastIndex + 1) % activeMemberIds.length;
        nextCharId = activeMemberIds[nextIndex];
      } else {
        nextCharId = activeMemberIds.first;
      }

      await _generateGroupCharacterResponse(nextCharId, config);
      return;
    }

    // For single character chats
    await _generateAssistantResponse(config);
  }

  /// Generate assistant response based on current context
  Future<void> _generateAssistantResponse(LLMConfig config) async {
    if (state.chat == null || state.character == null) return;

    state = state.copyWith(isGenerating: true, error: null);

    try {
      final context = await _buildContext();

      // Create placeholder for assistant message
      final assistantMessage = ChatMessage(
        id: _generateId(),
        chatId: state.chat!.id,
        role: MessageRole.assistant,
        content: '',
        timestamp: DateTime.now(),
        swipes: [''],
        currentSwipeIndex: 0,
      );

      state = state.copyWith(
        messages: [...state.messages, assistantMessage],
      );

      String finalContent;
      String? finalReasoning;

      if (config.streamEnabled) {
        // Stream the response with reasoning support
        final contentBuffer = StringBuffer();
        final reasoningBuffer = StringBuffer();
        final int myToken = ++_generationToken;
        final String myChatId = state.chat!.id;
        await for (final chunk
            in _llmService.generateStreamWithReasoning(context, config)) {
          // Validate the token: stop and discard immediately if it expired or the chat
          // switched, so output can never bleed into another chat
          if (myToken != _generationToken || state.chat?.id != myChatId) {
            return;
          }
          // Check if generation was cancelled
          if (_isCancelling) {
            break;
          }

          if (chunk.isReasoningChunk && chunk.reasoning != null) {
            reasoningBuffer.write(chunk.reasoning);
          }
          if (chunk.content != null) {
            contentBuffer.write(chunk.content);
          }
          final updatedMessage = assistantMessage.copyWith(
            content: contentBuffer.toString(),
            swipes: [contentBuffer.toString()],
            reasoning:
                reasoningBuffer.isNotEmpty ? reasoningBuffer.toString() : null,
            reasoningSwipes: reasoningBuffer.isNotEmpty
                ? [reasoningBuffer.toString()]
                : null,
          );

          final updatedMessages = List<ChatMessage>.from(state.messages);
          updatedMessages[updatedMessages.length - 1] = updatedMessage;
          state = state.copyWith(messages: updatedMessages);
        }
        finalContent = contentBuffer.toString();
        finalReasoning =
            reasoningBuffer.isNotEmpty ? reasoningBuffer.toString() : null;
      } else {
        // Non-streaming: get complete response at once with reasoning support
        final response =
            await _llmService.generateWithReasoning(context, config);
        finalContent = response.content;
        finalReasoning = response.reasoning;

        // Update the message with final content
        final updatedMessage = assistantMessage.copyWith(
          content: finalContent,
          swipes: [finalContent],
        );
        final updatedMessages = List<ChatMessage>.from(state.messages);
        updatedMessages[updatedMessages.length - 1] = updatedMessage;
        state = state.copyWith(messages: updatedMessages);
      }

      // Save the final message
      final finalMessage = assistantMessage.copyWith(
        content: finalContent,
        swipes: [finalContent],
        reasoning: finalReasoning,
        reasoningSwipes: finalReasoning != null ? [finalReasoning] : null,
      );
      await _chatRepository.addMessage(finalMessage);
      _indexMessageToVector(chatId: finalMessage.chatId, messageId: finalMessage.id, content: finalMessage.content);

      state = state.copyWith(isGenerating: false);

      // On regeneration, clear this message's old auto-generated images before regenerating
      await _clearAutoImages(finalMessage);
      _maybeAutoGenerateImage(finalMessage, config);
      // Auto-play the regenerated reply as well
      _maybeAutoSpeak(finalMessage);
    } catch (e, stackTrace) {
      debugPrint(
          '❌ ChatProvider _generateAssistantResponse error: $e\n$stackTrace');
      state = state.copyWith(
        isGenerating: false,
        error: e.toString(),
      );
    }
  }
  /// Removes a message's old auto-generated images (called on regeneration to reset
  /// the duplicate guard).
  Future<void> _clearAutoImages(ChatMessage msg) async {
    try {
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(base.path, 'chat_images', msg.chatId));
      if (!await dir.exists()) return;
      final ts = DateTime.now().millisecondsSinceEpoch;
      for (final f in dir.listSync().whereType<File>()) {
        final name = p.basename(f.path);
        if (name.startsWith('ai_auto_${msg.id}_')) {
          await f.rename(p.join(dir.path, 'ai_auto_old_${ts}_$name'));
        }
      }
    } catch (e) {
      debugPrint('[自动生图] 清理旧图失败: $e');
    }
  }
  /// Regenerates a message's auto image: the old image is replaced only after generation
  /// succeeds, so a failure leaves the existing image untouched.
  Future<void> regenerateAutoImage(String messageId, LLMConfig config) async {
    final idx = state.messages.indexWhere((m) => m.id == messageId);
    if (idx < 0) return;
    final msg = state.messages[idx];

    // Extract the original <image> tag prompt and reuse it unchanged
    final prompt = ImageGenerationService.extractImagePrompt(msg.content);
    if (prompt == null || prompt.isEmpty) {
      state = state.copyWith(imageGenError: '未找到图像标签，无法重新生成');
      return;
    }

    final settings = _ref.read(imageGenSettingsProvider);
    final service = _ref.read(imageGenServiceProvider);

    // Spinner placeholder (reuses the same state as the first block)
    state = state.copyWith(
      isGeneratingImage: true,
      generatingImageMsgId: msg.id,
      imageGenProgress: 0,
    );
    service.onProgress = (p) {
      state = state.copyWith(imageGenProgress: p);
    };

    try {
      // 1. Generate into memory first; the old image stays untouched
      // Prepend the configured positive prompt prefix
      final prefix = settings.positivePromptPrefix;
      final finalPrompt = (prefix != null && prefix.isNotEmpty)
          ? '$prefix${prompt.trim()}'
          : prompt;
      final result = await service.generate(ImageGenRequest(
        prompt: finalPrompt,
        width: settings.defaultWidth,
        height: settings.defaultHeight,
        steps: settings.defaultSteps,
        cfgScale: settings.defaultCfgScale,
        sampler: settings.defaultSampler,
        model: settings.model,
        negativePrompt: settings.defaultNegativePrompt,
      ));
      if (result == null || result.images.isEmpty) {
        throw Exception('未返回图片');
      }

      // 2. Replacement starts only after generation succeeds; the failure risk has passed
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(base.path, 'chat_images', msg.chatId));
      if (!await dir.exists()) await dir.create(recursive: true);

      // 2a. Rename old images so they stay visible in the session gallery, and the
      // duplicate guard resets
      await _clearAutoImages(msg);

      // 2b. Remove the old ai_auto images from attachments
      final kept = msg.attachments
          .where((a) => !a.id.startsWith('ai_auto_${msg.id}_'))
          .toList();
      final cleared = msg.copyWith(attachments: kept);
      await _chatRepository.updateMessage(cleared);
      final msgs = List<ChatMessage>.from(state.messages);
      msgs[idx] = cleared;
      state = state.copyWith(messages: msgs);

      // 2c. Write the new image and attach it to the message
      // The timestamp keeps the new path unique so the base64 cache cannot serve the old image
      final ts = DateTime.now().millisecondsSinceEpoch;
      for (var i = 0; i < result.images.length; i++) {
        final name = 'ai_auto_${msg.id}_${ts}_$i.${result.format}';
        final filePath = p.join(dir.path, name);
        await File(filePath).writeAsBytes(result.images[i]);
        await addAttachmentToMessage(
          msg.id,
          ChatAttachment(
            id: 'ai_auto_${msg.id}_${ts}_$i',
            path: filePath,
            mimeType: 'image/${result.format}',
            width: settings.defaultWidth,
            height: settings.defaultHeight,
          ),
        );
      }
      debugPrint('[重新生成] 消息 ${msg.id} 完成，旧图已保留');
    } catch (e) {
      // 3. On failure: old images and attachments were never touched, so the bubble
      // still shows the original
      debugPrint('[重新生成] 失败: $e');
      state = state.copyWith(imageGenError: '重新生成失败，已保留原图');
    } finally {
      service.onProgress = null;
      state = state.copyWith(
        isGeneratingImage: false,
        clearGeneratingImageMsgId: true,
      );
    }
  }

  /// Build context for LLM
  /// This method builds the full message list according to Prompt Manager configuration
  Future<List<Map<String, dynamic>>> _buildContext(
      {bool excludeLastAssistant = false}) async {
    final messages = <Map<String, dynamic>>[];

    // Auto image generation: when not off, inject the illustration instruction that
    // teaches the AI to emit <image> visual tags
    final imgSettings = _ref.read(imageGenSettingsProvider);
    if (imgSettings.autoImageMode != AutoImageMode.off && imgSettings.enabled) {
      // User-defined <image> tag instruction takes priority; the hardcoded default is
      // used when empty
      final tagInstruction = imgSettings.imageTagInstruction;
      final content = (tagInstruction != null && tagInstruction.isNotEmpty)
          ? tagInstruction
          : '【配图指令】当你的回复描绘了具体的视觉场景（人物、动作、环境）时，'
              '在回复的最末尾追加一行图像描述，格式严格为：\n'
              '<image>用英文逗号分隔的视觉标签，例如：1girl, silver hair, '
              'white dress, garden, sunlight</image>\n'
              '只写画面能看到的视觉元素，不要写心理、对话或剧情。';
      messages.add({'role': 'system', 'content': content});
    }
    final character = state.character;
    final chat = state.chat;

    // Read the global settings once; reused by the window, fixed layer, and recall
    // layer below. When Chronicle is enabled, legacy raw RAG text injection is taken
    // over and disabled (the recall layer's wiki summaries replace it).
    final chronicleSettings = _ref.read(chronicleSettingsProvider);

    // Get chat messages - use summaries if available
    var chatMessages = state.messages;
    if (excludeLastAssistant &&
        chatMessages.isNotEmpty &&
        chatMessages.last.role == MessageRole.assistant) {
      chatMessages = chatMessages.sublist(0, chatMessages.length - 1);
    }

    // Check if we have summaries and should use them
    final summaries = chat?.summaries ?? [];
    if (summaries.isNotEmpty) {
      final lastSummary = summaries.last;
      // Get only recent messages after the last summary
      final recentMessages = _summarizationService.getRecentMessages(
        allMessages: chatMessages,
        latestSummary: lastSummary,
      );
      // Use recent messages for building context
      chatMessages = recentMessages;
    }

    // Four-window sliding split replaces full-history injection
    // When Chronicle is enabled it takes over history splitting: unarchived (all
    // unarchived, highest attention at the end) / hot (recently archived) / warm /
    // cold (older archived), each window covering hotWindowSize turns (x2 messages).
    // Hidden messages (isHidden) never enter the prompt. Falls back to the legacy
    // behavior on failure.
    // Split result is captured so zone boundary markers can be inserted below.
    WindowedMessages? chronicleWindowed;
    if (chat != null && chronicleSettings.enabled) {
      try {
        final chronicleRepo = _ref.read(chronicleRepositoryProvider);
        final archivedIds = await chronicleRepo.getArchivedMessageIds(chat.id);
        final windowed = _summarizationService.getWindowedMessages(
          archivedMessageIds: archivedIds,
          allMessages: chatMessages.where((m) => !m.isHidden).toList(),
          windowSize: chronicleSettings.hotWindowSize,
        );
        chronicleWindowed = windowed;
        chatMessages = windowed.injectionOrder;
        debugPrint('[CHRONICLE] 四窗口注入：'
            '冷${windowed.cold.length}/温${windowed.warm.length}/热${windowed.hot.length}/'
            '未总结${windowed.unarchived.length} '
            '(归档${archivedIds.length}条)');
      } catch (e) {
        debugPrint('[CHRONICLE] 窗口切分失败，回落全量注入: $e');
      }
    }

    // Find matching World Info entries
    List<WorldInfoEntry> worldInfoEntries = [];
    if (character != null) {
      worldInfoEntries =
          await _findMatchingWorldInfoEntries(character, chatMessages);
    }
    // Chronicle has taken over context injection; the legacy RAG retrieval block was removed

    // Get Prompt Manager configuration
    final promptConfig = _ref.read(promptManagerProvider);
    final enabledSections = promptConfig.enabledSections;

    // Get active persona
    final activePersonaId = _ref.read(activePersonaIdProvider);
    Persona? persona;
    if (activePersonaId != null) {
      persona = await _personaRepository.getPersona(activePersonaId);
    }
    persona ??= await _personaRepository.getDefaultPersona();

    // Get LLM config for macro context
    final llmConfig = _ref.read(llmConfigProvider);

    // Create macro context for processing
    MacroContext? macroContext;
    MacroService? macroService;
    if (character != null) {
      macroContext = MacroContext.fromData(
        character: character,
        persona: persona,
        chat: state.chat,
        messages: state.messages,
        modelName: llmConfig.model,
        providerName: llmConfig.provider.name,
      );
      macroService = MacroService(macroContext);
    }

    // Helper to process macros in text (basic macros + variable macros)
    final chatIdForMacros = state.chat?.id;
    String processMacros(String text) {
      final step1 = macroService?.process(text) ?? text;
      return VariablesService.instance
          .processVariableMacrosSync(step1, chatId: chatIdForMacros);
    }

    // Helper to process macros including variable macros (async)
    final chatId = state.chat?.id;
    Future<String> processMacrosAsync(String text) async {
      final step1 = macroService?.process(text) ?? text;
      return VariablesService.instance.processVariableMacros(step1, chatId: chatId);
    }

    // Group world info entries by position
    final groupedEntries = _worldInfoMatcher.groupByPosition(worldInfoEntries);

    // Helper to add world info entries at a position
    void addWorldInfoAt(WorldInfoPosition position, String role) {
      final entries = groupedEntries[position];
      if (entries != null && entries.isNotEmpty) {
        for (final entry in entries) {
          messages.add({
            'role': role,
            'content':
                '[${entry.comment.isNotEmpty ? entry.comment : "World Info"}]\n${processMacros(entry.content)}',
          });
        }
      }
    }

    // Explicit F/B/W bucketing:
    //   F (front) = before chat history; B (before) = inserted into history by depth;
    //   W (absolute) = after chat history.
    //   When bucket is null it is derived by the existing rules (depth-based check plus
    //   the relative position of chatHistory), keeping character card / worldbook /
    //   jailbreak injection behavior exactly as before.
    final fSections = <PromptSection>[];
    final bSections = <PromptSection>[];
    final wSections = <PromptSection>[];
    bool foundChatHistory = false;

    for (final section in enabledSections) {
      if (section.type == PromptSectionType.chatHistory) {
        foundChatHistory = true;
        continue;
      }

      final bucket = section.bucket;
      // Bucket B: explicit before, or the existing depth-based check when auto-derived
      if (bucket == PromptBucket.before ||
          (bucket == null &&
              section.injectionPosition == 1 &&
              section.injectionDepth != null)) {
        bSections.add(section);
        continue;
      }

      final bool afterChat;
      if (bucket == PromptBucket.absolute) {
        afterChat = true;
      } else if (bucket == PromptBucket.front) {
        afterChat = false;
      } else {
        afterChat = foundChatHistory;
      }

      if (afterChat) {
        wSections.add(section);
      } else {
        fSections.add(section);
      }
    }

    // Build pre-chat messages
    for (final section in fSections) {
      final sectionMessages = await _buildSectionMessages(
        section,
        character,
        persona,
        worldInfoEntries,
        groupedEntries,
        processMacros,
        addWorldInfoAt,
      );
      messages.addAll(sectionMessages);
    }

    // Variable state injection: scan message swipesData backwards for the latest valid
    // stat_data, matching the read semantics of MVU getLastValidVariable.
    // Format aligns with the Tavern MVU variable persistence format.
    final statData = _getLatestStatData(chatMessages);
    if (statData != null && statData.isNotEmpty) {
      const maxLen = 5000;
      var json = jsonEncode(statData);
      if (json.length > maxLen) {
        json = '${json.substring(0, maxLen)}...（已截断，变量状态过长）';
      }
      messages.add({
        'role': 'system',
        'content': '[当前已持久化变量状态]\n'
            '以下是从MVU变量更新中解析并持久化的最新状态。后续回复应基于这些状态继续推进，'
            '并在需要变更状态时输出新的变量更新指令。\n'
            '$json\n'
            '[/当前已持久化变量状态]',
      });
      debugPrint('[MVU] 注入变量状态到提示词: ${statData.keys.length} keys');
    }

    // Add summary message if we have summaries
    if (summaries.isNotEmpty) {
      final latestSummary = summaries.last;
      final summaryMessage = _summarizationService.createSummaryMessage(
        summary: latestSummary,
        chatId: state.chat!.id,
      );
      messages.add({
        'role': 'system',
        'content': '[Conversation Summary]\n${summaryMessage.content}',
      });
      debugPrint(
          '📌 Added summary to context: ${latestSummary.content.substring(0, min(100, latestSummary.content.length))}...');
    }

    // Wiki fixed layer injection
    // Contents: anchor/always-injected entries + main entity states + key relationships
    // + live emotions + high-importance event titles.
    // Budget: 650 tokens with a ±30% estimation error; content over the budget is
    // trimmed in ascending importance order.
    if (chat != null && chronicleSettings.enabled) {
      try {
        final chronicleRepo = _ref.read(chronicleRepositoryProvider);
        final fixedEntries = await chronicleRepo.getFixedLayerEntries(chat.id);
        final entities = await chronicleRepo.getMainEntities(chat.id);
        final relationships = await chronicleRepo.getKeyRelationships(chat.id);
        final emotions = await chronicleRepo.getActiveEmotions(chat.id);
        // Record the injected entry IDs so the recall layer can deduplicate against them
        _lastF6EntryIds = fixedEntries.map((e) => e.id).toSet();

        final brief = _buildChronicleMemoryBrief(
          fixedEntries: fixedEntries,
          entities: entities,
          relationships: relationships,
          emotions: emotions,
          tokenBudget: 650,
        );
        if (brief.isNotEmpty) {
          messages.add({
            'role': 'system',
            'content': '[Chronicle Memory]\n$brief\n[/Chronicle Memory]',
          });
          debugPrint(
              '[CHRONICLE] F-6固定层注入：约${(brief.length / 3.35).ceil()} tokens');
        }
      } catch (e) {
        debugPrint('[CHRONICLE] F-6注入跳过（不影响对话）: $e');
      }
    }

    // Wiki recall layer injection (runs alongside RAG rather than replacing it)
    // Recalls wiki entries with a hybrid score (vector 0.5 + keyword 0.2 + recency 0.1
    // + emotion 0.1 + importance 0.1), excludes entries already injected by the fixed
    // layer, uses a 400 token budget, and triggers an early summary asynchronously on
    // topic shift.
    if (chat != null && chronicleSettings.enabled && chatMessages.isNotEmpty) {
      try {
        ChatMessage? lastUserMsg;
        for (var i = chatMessages.length - 1; i >= 0; i--) {
          if (chatMessages[i].role == MessageRole.user) {
            lastUserMsg = chatMessages[i];
            break;
          }
        }
        if (lastUserMsg != null && lastUserMsg.content.trim().isNotEmpty) {
          final recall = _ref.read(chronicleRecallServiceProvider);
          final recallResult = await recall.recallAndBuild(
            chatId: chat.id,
            query: lastUserMsg.content,
            allMessages: state.messages,
            topK: chronicleSettings.ragTopK,
            excludeEntryIds: _lastF6EntryIds,
            tokenBudget: 400,
            emotionRecallEnabled: chronicleSettings.emotionRecallEnabled,
          );
          if (recallResult.blockText.isNotEmpty) {
            messages.add({
              'role': 'system',
              'content':
                  '[Chronicle Recalled]\n${recallResult.blockText}\n[/Chronicle Recalled]',
            });
            debugPrint(
                '[CHRONICLE] F-7召回层注入：${recallResult.entryIds.length}条词条');
          }
          if (recallResult.topicShift) {
            // Topic shift triggers an asynchronous early summary without blocking this send
            unawaited(_ref
                .read(chronicleOrchestratorProvider)
                .onTopicShift(chat.id, state.messages));
          }
        }
      } catch (e) {
        debugPrint('[CHRONICLE] F-7注入跳过（不影响对话）: $e');
      }
    }

    // Add chat messages with depth-based injections
    final depthEntries = worldInfoEntries
        .where((e) => e.position == WorldInfoPosition.atDepth)
        .toList();

    // Prepare Author's Note for depth-based injection
    final authorNoteEnabled = chat?.authorNoteEnabled ?? false;
    final authorNote = chat?.authorNote ?? '';
    final authorNoteDepth = chat?.authorNoteDepth ?? 4;

    // Chronicle zone boundaries in injection order (cold, warm, hot, unarchived);
    // markers are only injected when the four-window split is active.
    final zoneWindowed = chronicleWindowed;
    final coldZoneEnd = zoneWindowed?.cold.length ?? 0;
    final warmZoneEnd = coldZoneEnd + (zoneWindowed?.warm.length ?? 0);
    final hotZoneEnd = warmZoneEnd + (zoneWindowed?.hot.length ?? 0);
    final unarchivedZoneStart = hotZoneEnd;
    final zoneMarkersActive = zoneWindowed != null;

    for (var i = 0; i < chatMessages.length; i++) {
      final msg = chatMessages[i];

      // Zone boundary markers: label each zone so the model can tell archived
      // history from the current conversation (Lost in the Middle effect).
      if (zoneMarkersActive) {
        if (i == 0 && coldZoneEnd > 0) {
          messages.add({
            'role': 'system',
            'content': '[Historical Context - Cold Zone]\n'
                'This zone contains $coldZoneEnd older archived messages from the distant past. '
                'Low attention priority: reference only when long-term continuity is needed.',
          });
        } else if (i == coldZoneEnd && warmZoneEnd > coldZoneEnd) {
          messages.add({
            'role': 'system',
            'content': '[Historical Context - Warm Zone]\n'
                'This zone contains ${warmZoneEnd - coldZoneEnd} archived messages from the recent past. '
                'Mid attention priority: use for recent plot developments and character interactions.',
          });
        } else if (i == warmZoneEnd && hotZoneEnd > warmZoneEnd) {
          messages.add({
            'role': 'system',
            'content': '[Historical Context - Hot Zone]\n'
                'This zone contains the ${hotZoneEnd - warmZoneEnd} most recent archived messages. '
                'High attention priority: this is the immediate history leading into '
                'the current conversation below.',
          });
        } else if (i == unarchivedZoneStart &&
            unarchivedZoneStart < chatMessages.length) {
          messages.add({
            'role': 'system',
            'content': '[Current Conversation - Unarchived Zone]\n'
                'This is the active conversation zone with maximum attention priority. '
                'These ${chatMessages.length - unarchivedZoneStart} messages are not archived yet '
                'and form the ongoing dialogue; base your response primarily on this section.',
          });
        }
      }

      // Depth is counted from the end (most recent = depth 0)
      final depthFromEnd = chatMessages.length - 1 - i;

      // Check if any depth-based world info entries should be inserted before this message
      for (final entry in depthEntries) {
        if (entry.depth == depthFromEnd) {
          messages.add({
            'role': 'system',
            'content':
                '[World Info: ${entry.comment.isNotEmpty ? entry.comment : "Context"}]\n${processMacros(entry.content)}',
          });
        }
      }

      // Check if any depth-based prompt sections should be inserted
      for (final section in bSections) {
        if (section.injectionDepth == depthFromEnd) {
          final sectionMessages = await _buildSectionMessages(
            section,
            character,
            persona,
            worldInfoEntries,
            groupedEntries,
            processMacros,
            addWorldInfoAt,
          );
          messages.addAll(sectionMessages);
        }
      }

      // Inject Author's Note at the configured depth
      if (authorNoteEnabled &&
          authorNote.isNotEmpty &&
          depthFromEnd == authorNoteDepth) {
        final processedNote = await _processAuthorNoteMacros(authorNote);
        messages.add({
          'role': 'system',
          'content': '[Author\'s Note]\n$processedNote',
        });
      }

      // Flag the user's latest message as the required response target
      if (msg.role == MessageRole.user && i == chatMessages.length - 1) {
        messages.add({
          'role': 'system',
          'content': "[USER'S LATEST MESSAGE - RESPOND TO THIS]\n"
              "This is the user's most recent input that you MUST respond to. "
              'Base your reply on the current conversation (Unarchived Zone), '
              'recent history (Hot Zone), and long-term background '
              '(Warm/Cold Zones and Chronicle entries).',
        });
      }

      // Build message with attachments if present
      if (msg.hasAttachments && msg.role == MessageRole.user) {
          messages.add(await _buildMultimodalMessage(msg));
      } else {
        messages.add({
          'role': msg.role == MessageRole.user ? 'user' : 'assistant',
          'content': msg.content,
        });
      }
    }

    // If Author's Note depth is beyond message count, insert at the start of chat
    if (authorNoteEnabled &&
        authorNote.isNotEmpty &&
        authorNoteDepth >= chatMessages.length) {
      final processedNote = await _processAuthorNoteMacros(authorNote);
      // Find where chat messages start and insert before
      final chatStartIndex = messages.length - chatMessages.length;
      if (chatStartIndex >= 0) {
        messages.insert(chatStartIndex, {
          'role': 'system',
          'content': '[Author\'s Note]\n$processedNote',
        });
      }
    }

    // Build post-chat messages
    for (final section in wSections) {
      final sectionMessages = await _buildSectionMessages(
        section,
        character,
        persona,
        worldInfoEntries,
        groupedEntries,
        processMacros,
        addWorldInfoAt,
      );
      messages.addAll(sectionMessages);
    }

    return messages;
  }

  /// Build messages for a single prompt section
  /// Scans the message list backwards for the latest valid stat_data (same semantics
  /// as MVU getLastValidVariable)
  Map<String, dynamic>? _getLatestStatData(List<ChatMessage> messages) {
    for (int i = messages.length - 1; i >= 0; i--) {
      final msg = messages[i];
      if (msg.role != MessageRole.assistant) continue;
      final swipesData = msg.swipesData;
      if (swipesData.isEmpty) continue;
      final swIdx = msg.currentSwipeIndex >= 0 && msg.currentSwipeIndex < swipesData.length
          ? msg.currentSwipeIndex : 0;
      final data = swipesData[swIdx];
      final stat = data['stat_data'];
      if (stat is Map && stat.isNotEmpty) {
        return Map<String, dynamic>.from(stat);
      }
    }
    return null;
  }

  /// Determines whether section.content is still the prefilled default (not user-edited).
  /// Empty or identical to getDefaultContent counts as untouched; anything else means
  /// the user actually edited it. Implements the priority:
  /// user edit > character card field > default text.
  bool _isUntouchedSectionContent(PromptSection section) {
    final c = section.content;
    if (c == null || c.trim().isEmpty) return true;
    return c.trim() ==
        PromptSection.getDefaultContent(section.type).trim();
  }

  /// Builds the fixed-layer memory brief block.
  /// Priority: (1) anchor entries (2) main entity states (3) key relationships
  /// (4) live emotions (5) high-importance event titles.
  /// Budget control: tokens are a ±30% estimate, so char budget = token*3.35;
  /// content over the limit is trimmed in ascending entry importance order.
  String _buildChronicleMemoryBrief({
    required List<MemoryEntry> fixedEntries,
    required List<MemoryEntity> entities,
    required List<MemoryRelationship> relationships,
    required List<EmotionNode> emotions,
    int tokenBudget = 650,
  }) {
    final budgetChars = (tokenBudget * 3.35).ceil();
    final entityNameById = <String, String>{
      for (final e in entities) e.id: e.name,
    };

    final sections = <String>[];

    // (1) Anchor/always-injected entries: trimmed in descending importance first (the
    // budget semantics are unchanged), then sorted ascending by turnIndex.
    // Ordering fix: entries carry a turn prefix so the main model can tell the order of
    // events and avoid confusing cause and effect.
    if (fixedEntries.isNotEmpty) {
      String turnLabel(int idx) => idx <= 0 ? '早期' : '第$idx轮';
      String lineOf(MemoryEntry e) =>
          '· [${turnLabel(e.turnIndex)}] ${e.title}：${e.content}';
      final byImportance = [...fixedEntries]
        ..sort((a, b) => b.importance.compareTo(a.importance));
      final kept = <MemoryEntry>[];
      var used = 0;
      for (final e in byImportance) {
        final cost = lineOf(e).length + 1; // +1 for the newline
        if (kept.isNotEmpty && used + cost > budgetChars) break;
        kept.add(e);
        used += cost;
      }
      kept.sort((a, b) => a.turnIndex.compareTo(b.turnIndex));
      final lines = <String>[for (final e in kept) lineOf(e)];
      sections.add('【关键记忆】\n${lines.join('\n')}');
    }

    // (2) Current state of main entities
    if (entities.isNotEmpty) {
      final lines = <String>[];
      for (final e in entities) {
        var line = '· ${e.name}';
        if (e.description.isNotEmpty) line += '（${e.description}）';
        if (e.currentState.isNotEmpty) line += '：${e.currentState}';
        lines.add(line);
      }
      sections.add('【人物与实体】\n${lines.join('\n')}');
    }

    // (3) Key relationships
    if (relationships.isNotEmpty) {
      final lines = <String>[];
      for (final r in relationships) {
        final from = entityNameById[r.fromEntityId] ?? '？';
        final to = entityNameById[r.toEntityId] ?? '？';
        final line = '· $from 与 $to（${r.relationType} ${r.strength}）'
            '${r.description.isNotEmpty ? '：${r.description}' : ''}';
        lines.add(line);
      }
      sections.add('【关系】\n${lines.join('\n')}');
    }

    // (4) Live emotions
    if (emotions.isNotEmpty) {
      final lines = <String>[];
      for (final emo in emotions) {
        final name = entityNameById[emo.entityId] ?? '？';
        lines.add(
            '· $name 对玩家感到${emo.emotion}（强度${emo.intensity}）${emo.trigger.isNotEmpty ? '，起因：${emo.trigger}' : ''}');
      }
      sections.add('【当前情感】\n${lines.join('\n')}');
    }

    // Assemble and trim to budget: drop sections from the tail (lowest priority) first;
    // the entry section is already sorted by importance within (1).
    final buffer = StringBuffer();
    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      if (buffer.length + section.length + 1 <= budgetChars) {
        if (buffer.isNotEmpty) buffer.writeln();
        buffer.write(section);
      } else if (i == 0) {
        // Section (1) alone exceeds the budget: keep its head (highest importance is first)
        buffer.write(section.substring(0, budgetChars));
        break;
      } else {
        break; // Drop lower-priority sections that do not fit
      }
    }

    return buffer.toString();
  }

  Future<List<Map<String, dynamic>>> _buildSectionMessages(
    PromptSection section,
    Character? character,
    Persona? persona,
    List<WorldInfoEntry> worldInfoEntries,
    Map<WorldInfoPosition, List<WorldInfoEntry>> groupedEntries,
    String Function(String) processMacros,
    void Function(WorldInfoPosition, String) addWorldInfoAt,
  ) async {
    final messages = <Map<String, dynamic>>[];
    final role = section.role ?? 'system';

    switch (section.type) {
      case PromptSectionType.systemPrompt:
        // Priority fix: user edit > character card system_prompt > default text.
        // (The old logic let the prefilled generic default always win because it was
        // never empty, silently discarding the character card's system_prompt.)
        final String content;
        if (!_isUntouchedSectionContent(section)) {
          content = section.content!;
        } else if (character != null &&
            character.systemPrompt.isNotEmpty) {
          content = character.systemPrompt;
        } else {
          content = PromptSection.getDefaultContent(
              PromptSectionType.systemPrompt);
        }
        if (content.isNotEmpty) {
          // Add world info before system prompt (using 'before' position as proxy)
          final beforeEntries = groupedEntries[WorldInfoPosition.before];
          if (beforeEntries != null) {
            for (final entry in beforeEntries) {
              messages.add({
                'role': role,
                'content':
                    '[${entry.comment.isNotEmpty ? entry.comment : "World Info"}]\n${processMacros(entry.content)}',
              });
            }
          }

          messages.add({'role': role, 'content': processMacros(content)});

          // Add world info after system prompt (using 'after' position as proxy)
          final afterEntries = groupedEntries[WorldInfoPosition.after];
          if (afterEntries != null) {
            for (final entry in afterEntries) {
              messages.add({
                'role': role,
                'content':
                    '[${entry.comment.isNotEmpty ? entry.comment : "World Info"}]\n${processMacros(entry.content)}',
              });
            }
          }
        }
        break;

      case PromptSectionType.persona:
        if (persona != null && persona.name.isNotEmpty) {
          final buffer = StringBuffer();
          buffer.writeln('The user is ${persona.name}.');
          if (persona.description.isNotEmpty) {
            buffer.writeln(
                'User description: ${processMacros(persona.description)}');
          }
          messages.add({'role': role, 'content': buffer.toString().trim()});
        }
        break;

      case PromptSectionType.characterDescription:
        if (character != null && character.description.isNotEmpty) {
          // Add world info before character definitions
          final beforeEntries = groupedEntries[WorldInfoPosition.before];
          if (beforeEntries != null) {
            for (final entry in beforeEntries) {
              messages.add({
                'role': role,
                'content':
                    '[${entry.comment.isNotEmpty ? entry.comment : "World Info"}]\n${processMacros(entry.content)}',
              });
            }
          }

          messages.add({
            'role': role,
            'content': 'Description:\n${processMacros(character.description)}',
          });
        }
        break;

      case PromptSectionType.characterPersonality:
        if (character != null && character.personality.isNotEmpty) {
          messages.add({
            'role': role,
            'content': 'Personality:\n${processMacros(character.personality)}',
          });
        }
        break;

      case PromptSectionType.characterScenario:
        if (character != null && character.scenario.isNotEmpty) {
          messages.add({
            'role': role,
            'content': 'Scenario:\n${processMacros(character.scenario)}',
          });

          // Add world info after character definitions
          final afterEntries = groupedEntries[WorldInfoPosition.after];
          if (afterEntries != null) {
            for (final entry in afterEntries) {
              messages.add({
                'role': role,
                'content':
                    '[${entry.comment.isNotEmpty ? entry.comment : "World Info"}]\n${processMacros(entry.content)}',
              });
            }
          }
        }
        break;

      case PromptSectionType.exampleMessages:
        if (character != null && character.exampleMessages.isNotEmpty) {
          // Add world info before examples (using EMTop)
          final beforeEntries = groupedEntries[WorldInfoPosition.EMTop];
          if (beforeEntries != null) {
            for (final entry in beforeEntries) {
              messages.add({
                'role': role,
                'content':
                    '[${entry.comment.isNotEmpty ? entry.comment : "World Info"}]\n${processMacros(entry.content)}',
              });
            }
          }

          messages.add({
            'role': role,
            'content':
                'Example dialogue:\n${processMacros(character.exampleMessages)}',
          });

          // Add world info after examples (using EMBottom)
          final afterEntries = groupedEntries[WorldInfoPosition.EMBottom];
          if (afterEntries != null) {
            for (final entry in afterEntries) {
              messages.add({
                'role': role,
                'content':
                    '[${entry.comment.isNotEmpty ? entry.comment : "World Info"}]\n${processMacros(entry.content)}',
              });
            }
          }
        }
        break;

      case PromptSectionType.worldInfo:
        // World info entries that don't have a specific position
        // Only include entries with outlet position (all other positions are handled elsewhere)
        final generalEntries = worldInfoEntries
            .where((e) => e.position == WorldInfoPosition.outlet)
            .toList();
        for (final entry in generalEntries) {
          messages.add({
            'role': role,
            'content':
                '[${entry.comment.isNotEmpty ? entry.comment : "World Info"}]\n${processMacros(entry.content)}',
          });
        }
        break;

      case PromptSectionType.worldInfoAfter:
        final afterEntries = groupedEntries[WorldInfoPosition.after];
        if (afterEntries != null) {
          for (final entry in afterEntries) {
            messages.add({
              'role': role,
              'content':
                  '[${entry.comment.isNotEmpty ? entry.comment : "World Info"}]\n${processMacros(entry.content)}',
            });
          }
        }
        break;

      case PromptSectionType.authorNote:
        // Author's note is handled separately with depth injection
        // ANTop = before Author's Note
        final beforeEntries = groupedEntries[WorldInfoPosition.ANTop];
        if (beforeEntries != null) {
          for (final entry in beforeEntries) {
            messages.add({
              'role': role,
              'content':
                  '[${entry.comment.isNotEmpty ? entry.comment : "World Info"}]\n${processMacros(entry.content)}',
            });
          }
        }
        // ANBottom = after Author's Note
        final afterEntries = groupedEntries[WorldInfoPosition.ANBottom];
        if (afterEntries != null) {
          for (final entry in afterEntries) {
            messages.add({
              'role': role,
              'content':
                  '[${entry.comment.isNotEmpty ? entry.comment : "World Info"}]\n${processMacros(entry.content)}',
            });
          }
        }
        break;

      case PromptSectionType.postHistoryInstructions:
        // Same fix as systemPrompt: the prefilled default jailbreak text always won the
        // priority inversion, silently discarding the character card's
        // post_history_instructions.
        final String content;
        if (!_isUntouchedSectionContent(section)) {
          content = section.content!;
        } else if (character != null &&
            character.postHistoryInstructions.isNotEmpty) {
          content = character.postHistoryInstructions;
        } else {
          content = PromptSection.getDefaultContent(
              PromptSectionType.postHistoryInstructions);
        }
        if (content.isNotEmpty) {
          messages.add({'role': role, 'content': processMacros(content)});
        }
        break;

      case PromptSectionType.nsfw:
        // NSFW prompt from section content
        final content = section.content?.isNotEmpty == true
            ? section.content!
            : PromptSection.getDefaultContent(PromptSectionType.nsfw);
        if (content.isNotEmpty) {
          messages.add({'role': role, 'content': processMacros(content)});
        }
        break;

      case PromptSectionType.chatHistory:
        // Chat history is handled separately in the main loop
        break;

      case PromptSectionType.enhanceDefinitions:
        // Enhanced definitions - could add more detailed character info
        break;

      case PromptSectionType.custom:
        // Custom prompt from imported preset
        if (section.content?.isNotEmpty == true) {
          messages
              .add({'role': role, 'content': processMacros(section.content!)});
        }
        break;
    }

    return messages;
  }

  /// Process macros in Author's Note
  Future<String> _processAuthorNoteMacros(String note) async {
    final character = state.character;
    if (character == null) return note;

    // Get active persona
    final activePersonaId = _ref.read(activePersonaIdProvider);
    Persona? persona;
    if (activePersonaId != null) {
      persona = await _personaRepository.getPersona(activePersonaId);
    }
    persona ??= await _personaRepository.getDefaultPersona();

    // Get LLM config
    final llmConfig = _ref.read(llmConfigProvider);

    final macroContext = MacroContext.fromData(
      character: character,
      persona: persona,
      chat: state.chat,
      messages: state.messages,
      modelName: llmConfig.model,
      providerName: llmConfig.provider.name,
    );

    return MacroService(macroContext).process(note);
  }

  /// Build context up to a specific message index (exclusive)
  Future<List<Map<String, dynamic>>> _buildContextUpTo(int messageIndex) async {
    final messages = <Map<String, dynamic>>[];
    final character = state.character;
    final chat = state.chat;

    // Get chat messages up to (but not including) the specified index
    var chatMessages = state.messages.sublist(0, messageIndex);

    // Four-window sliding split (regenerate/edit path matches the main path)
    // Split result is captured so zone boundary markers can be inserted below.
    WindowedMessages? chronicleWindowed;
    if (chat != null) {
      try {
        final chronicleSettings = _ref.read(chronicleSettingsProvider);
        if (chronicleSettings.enabled) {
          final chronicleRepo = _ref.read(chronicleRepositoryProvider);
          final archivedIds =
              await chronicleRepo.getArchivedMessageIds(chat.id);
          final windowed = _summarizationService.getWindowedMessages(
            archivedMessageIds: archivedIds,
            allMessages: chatMessages.where((m) => !m.isHidden).toList(),
            windowSize: chronicleSettings.hotWindowSize,
          );
          chronicleWindowed = windowed;
          chatMessages = windowed.injectionOrder;
        }
      } catch (_) {
        // Fall back to the legacy behavior on failure
      }
    }

    // Find matching World Info entries
    List<WorldInfoEntry> worldInfoEntries = [];
    if (character != null) {
      worldInfoEntries =
          await _findMatchingWorldInfoEntries(character, chatMessages);
    }

    // Get Prompt Manager configuration
    final promptConfig = _ref.read(promptManagerProvider);
    final enabledSections = promptConfig.enabledSections;

    // Get active persona
    final activePersonaId = _ref.read(activePersonaIdProvider);
    Persona? persona;
    if (activePersonaId != null) {
      persona = await _personaRepository.getPersona(activePersonaId);
    }
    persona ??= await _personaRepository.getDefaultPersona();

    // Get LLM config for macro context
    final llmConfig = _ref.read(llmConfigProvider);

    // Create macro context for processing
    MacroContext? macroContext;
    MacroService? macroService;
    if (character != null) {
      macroContext = MacroContext.fromData(
        character: character,
        persona: persona,
        chat: state.chat,
        messages: chatMessages,
        modelName: llmConfig.model,
        providerName: llmConfig.provider.name,
      );
      macroService = MacroService(macroContext);
    }

    // Helper to process macros in text
    String processMacros(String text) => macroService?.process(text) ?? text;

    // Group world info entries by position
    final groupedEntries = _worldInfoMatcher.groupByPosition(worldInfoEntries);

    // Helper to add world info entries at a position
    void addWorldInfoAt(WorldInfoPosition position, String role) {
      final entries = groupedEntries[position];
      if (entries != null && entries.isNotEmpty) {
        for (final entry in entries) {
          messages.add({
            'role': role,
            'content':
                '[${entry.comment.isNotEmpty ? entry.comment : "World Info"}]\n${processMacros(entry.content)}',
          });
        }
      }
    }

    // Explicit F/B/W bucketing (same rules as _buildContext, preserving existing behavior)
    final fSections = <PromptSection>[];
    final bSections = <PromptSection>[];
    final wSections = <PromptSection>[];
    bool foundChatHistory = false;

    for (final section in enabledSections) {
      if (section.type == PromptSectionType.chatHistory) {
        foundChatHistory = true;
        continue;
      }

      final bucket = section.bucket;
      if (bucket == PromptBucket.before ||
          (bucket == null &&
              section.injectionPosition == 1 &&
              section.injectionDepth != null)) {
        bSections.add(section);
        continue;
      }

      final bool afterChat;
      if (bucket == PromptBucket.absolute) {
        afterChat = true;
      } else if (bucket == PromptBucket.front) {
        afterChat = false;
      } else {
        afterChat = foundChatHistory;
      }

      if (afterChat) {
        wSections.add(section);
      } else {
        fSections.add(section);
      }
    }

    // Build pre-chat messages
    for (final section in fSections) {
      final sectionMessages = await _buildSectionMessages(
        section,
        character,
        persona,
        worldInfoEntries,
        groupedEntries,
        processMacros,
        addWorldInfoAt,
      );
      messages.addAll(sectionMessages);
    }

    // Add summary message if we have summaries
    final summaries = chat?.summaries ?? [];
    if (summaries.isNotEmpty) {
      final latestSummary = summaries.last;
      final summaryMessage = _summarizationService.createSummaryMessage(
        summary: latestSummary,
        chatId: state.chat!.id,
      );
      messages.add({
        'role': 'system',
        'content': '[Conversation Summary]\n${summaryMessage.content}',
      });
      debugPrint(
          '📌 Added summary to context: ${latestSummary.content.substring(0, min(100, latestSummary.content.length))}...');
    }

    // Add chat messages with depth-based injections
    final depthEntries = worldInfoEntries
        .where((e) => e.position == WorldInfoPosition.atDepth)
        .toList();

    // Prepare Author's Note for depth-based injection
    final authorNoteEnabled = chat?.authorNoteEnabled ?? false;
    final authorNote = chat?.authorNote ?? '';
    final authorNoteDepth = chat?.authorNoteDepth ?? 4;

    // Chronicle zone boundaries in injection order (cold, warm, hot, unarchived);
    // markers are only injected when the four-window split is active.
    final zoneWindowed = chronicleWindowed;
    final coldZoneEnd = zoneWindowed?.cold.length ?? 0;
    final warmZoneEnd = coldZoneEnd + (zoneWindowed?.warm.length ?? 0);
    final hotZoneEnd = warmZoneEnd + (zoneWindowed?.hot.length ?? 0);
    final unarchivedZoneStart = hotZoneEnd;
    final zoneMarkersActive = zoneWindowed != null;

    for (var i = 0; i < chatMessages.length; i++) {
      final msg = chatMessages[i];

      // Zone boundary markers: label each zone so the model can tell archived
      // history from the current conversation (Lost in the Middle effect).
      if (zoneMarkersActive) {
        if (i == 0 && coldZoneEnd > 0) {
          messages.add({
            'role': 'system',
            'content': '[Historical Context - Cold Zone]\n'
                'This zone contains $coldZoneEnd older archived messages from the distant past. '
                'Low attention priority: reference only when long-term continuity is needed.',
          });
        } else if (i == coldZoneEnd && warmZoneEnd > coldZoneEnd) {
          messages.add({
            'role': 'system',
            'content': '[Historical Context - Warm Zone]\n'
                'This zone contains ${warmZoneEnd - coldZoneEnd} archived messages from the recent past. '
                'Mid attention priority: use for recent plot developments and character interactions.',
          });
        } else if (i == warmZoneEnd && hotZoneEnd > warmZoneEnd) {
          messages.add({
            'role': 'system',
            'content': '[Historical Context - Hot Zone]\n'
                'This zone contains the ${hotZoneEnd - warmZoneEnd} most recent archived messages. '
                'High attention priority: this is the immediate history leading into '
                'the current conversation below.',
          });
        } else if (i == unarchivedZoneStart &&
            unarchivedZoneStart < chatMessages.length) {
          messages.add({
            'role': 'system',
            'content': '[Current Conversation - Unarchived Zone]\n'
                'This is the active conversation zone with maximum attention priority. '
                'These ${chatMessages.length - unarchivedZoneStart} messages are not archived yet '
                'and form the ongoing dialogue; base your response primarily on this section.',
          });
        }
      }

      // Depth is counted from the end (most recent = depth 0)
      final depthFromEnd = chatMessages.length - 1 - i;

      // Check if any depth-based world info entries should be inserted
      for (final entry in depthEntries) {
        if (entry.depth == depthFromEnd) {
          messages.add({
            'role': 'system',
            'content':
                '[World Info: ${entry.comment.isNotEmpty ? entry.comment : "Context"}]\n${processMacros(entry.content)}',
          });
        }
      }

      // Check if any depth-based prompt sections should be inserted
      for (final section in bSections) {
        if (section.injectionDepth == depthFromEnd) {
          final sectionMessages = await _buildSectionMessages(
            section,
            character,
            persona,
            worldInfoEntries,
            groupedEntries,
            processMacros,
            addWorldInfoAt,
          );
          messages.addAll(sectionMessages);
        }
      }

      // Inject Author's Note at the configured depth
      if (authorNoteEnabled &&
          authorNote.isNotEmpty &&
          depthFromEnd == authorNoteDepth) {
        final processedNote = await _processAuthorNoteMacros(authorNote);
        messages.add({
          'role': 'system',
          'content': '[Author\'s Note]\n$processedNote',
        });
      }

      // Flag the user's latest message as the required response target
      if (msg.role == MessageRole.user && i == chatMessages.length - 1) {
        messages.add({
          'role': 'system',
          'content': "[USER'S LATEST MESSAGE - RESPOND TO THIS]\n"
              "This is the user's most recent input that you MUST respond to. "
              'Base your reply on the current conversation (Unarchived Zone), '
              'recent history (Hot Zone), and long-term background '
              '(Warm/Cold Zones and Chronicle entries).',
        });
      }

      // Build message with attachments if present
      if (msg.hasAttachments && msg.role == MessageRole.user) {
          messages.add(await _buildMultimodalMessage(msg));
      } else {
        messages.add({
          'role': msg.role == MessageRole.user ? 'user' : 'assistant',
          'content': msg.content,
        });
      }
    }

    // If Author's Note depth is beyond message count, insert at the start of chat
    if (authorNoteEnabled &&
        authorNote.isNotEmpty &&
        authorNoteDepth >= chatMessages.length) {
      final processedNote = await _processAuthorNoteMacros(authorNote);
      final chatStartIndex = messages.length - chatMessages.length;
      if (chatStartIndex >= 0) {
        messages.insert(chatStartIndex, {
          'role': 'system',
          'content': '[Author\'s Note]\n$processedNote',
        });
      }
    }

    // Build post-chat messages
    for (final section in wSections) {
      final sectionMessages = await _buildSectionMessages(
        section,
        character,
        persona,
        worldInfoEntries,
        groupedEntries,
        processMacros,
        addWorldInfoAt,
      );
      messages.addAll(sectionMessages);
    }

    return messages;
  }

  /// Find matching World Info entries based on chat context
  Future<List<WorldInfoEntry>> _findMatchingWorldInfoEntries(
    Character character,
    List<ChatMessage> chatMessages,
  ) async {
    final activeIds = _ref.read(activeWorldInfoIdsProvider);
    final allWorldInfos = await _ref.read(allWorldInfosProvider.future);

    final enabledWorldInfoIds = allWorldInfos
        .where((w) =>
            w.enabled &&
            (w.isGlobal ||
                w.characterId == character.id ||
                activeIds.contains(w.id)))
        .map((w) => w.id)
        .toList();

    final allWorldInfoIds =
        <String>{...enabledWorldInfoIds, ...activeIds}.toList();

    if (allWorldInfoIds.isEmpty) return [];

    final contextBuffer = StringBuffer();
    contextBuffer.writeln(character.name);
    contextBuffer.writeln(character.description);
    contextBuffer.writeln(character.personality);
    contextBuffer.writeln(character.scenario);
    for (final msg in chatMessages) {
      contextBuffer.writeln(msg.content);
    }

    return _worldInfoMatcher.findMatchingEntries(
      contextText: contextBuffer.toString(),
      worldInfoIds: allWorldInfoIds,
    );
  }

  /// Build a multimodal message with text and images
  Future<Map<String, dynamic>> _buildMultimodalMessage(ChatMessage msg) async {
    // Build content array with text and images
    final contentParts = <Map<String, dynamic>>[];

    // Add text content if present
    if (msg.content.isNotEmpty) {
      contentParts.add({
        'type': 'text',
        'text': msg.content,
      });
    }

    // Add image attachments as base64 (file read and encoding run in an isolate to
    // avoid blocking the main thread)
    for (final attachment in msg.attachments) {
      try {
        if (File(attachment.path).existsSync()) {
          final base64Data = await compute(encodeFileToBase64, attachment.path);
          final mimeType = attachment.mimeType ?? 'image/jpeg';
          contentParts.add({
            'type': 'image_url',
            'image_url': {
              'url': 'data:$mimeType;base64,$base64Data',
            },
          });
        }
      } catch (e) {
        debugPrint('Error loading attachment: $e');
      }
    }

    return {
      'role': 'user',
      'content': contentParts,
    };
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        (DateTime.now().microsecond % 1000).toString().padLeft(3, '0');
  }
  /// Embeds a message and writes it idempotently into this chat's vector collection.
  /// document.id uses messageId so swipes/regeneration/edits of the same message keep
  /// only the latest entry. Fully fault-tolerant: an embedding failure is skipped and
  /// never blocks the conversation.
  Future<void> _indexMessageToVector({
    required String chatId,
    required String messageId,
    required String content,
  }) async {
    try {
      final text = content.trim();
      if (text.isEmpty) return;

      final vsSettings = _ref.read(vectorStorageSettingsProvider);
      if (!vsSettings.enabled) return; // Skip when RAG is disabled by the user, saving compute

      final vsService = _ref.read(vectorStorageServiceProvider);
      // loadChat should already have created the collection; create it here as a safety net
      if (vsService.getCollection(chatId) == null) {
        // Dimensions are read dynamically (local bge = 384) instead of hardcoded 512
        vsService.createCollectionWithId(
          id: chatId,
          name: state.chat?.title ?? 'Chat',
          dimensions: vsSettings.embeddingProvider.defaultDimensions,
        );
      }

      final embedder = _ref.read(embeddingServiceProvider);
      final vec = await embedder.generateEmbedding(text, vsSettings);

      vsService.addDocumentWithId(
        collectionId: chatId,
        documentId: messageId,
        content: text,
        embedding: vec,
        metadata: {'type': 'message', 'messageId': messageId},
      );
      _ref.read(vectorCollectionsProvider.notifier).refresh();
    } catch (e) {
      debugPrint('⚠️ RAG 入库跳过（不影响对话）: $e');
    }
  }

  /// Check if summarization is needed and generate summary if threshold is reached
  Future<void> _checkAndSummarize(LLMConfig config) async {
    final chat = state.chat;
    if (chat == null) return;

    if (!config.autoSummarizeEnabled) {
      debugPrint('📝 Auto-summarization disabled');
      return;
    }

    // Check if we should summarize
    final shouldSummarize = await _summarizationService.shouldSummarize(
      messages: state.messages,
      existingSummaries: chat.summaries,
      config: config,
    );

    if (!shouldSummarize) {
      debugPrint('📝 No summarization needed');
      return;
    }

    debugPrint('🔄 Triggering auto-summarization...');

    try {
      // Get character and persona for summary context
      final character = state.character;
      final activePersonaId = _ref.read(activePersonaIdProvider);
      Persona? persona;
      if (activePersonaId != null) {
        persona = await _personaRepository.getPersona(activePersonaId);
      }
      persona ??= await _personaRepository.getDefaultPersona();

      // Determine which messages to summarize
      final messagesToSummarize = chat.summaries.isEmpty
          ? state.messages // First summary: summarize all messages
          : _summarizationService.getRecentMessages(
              allMessages: state.messages,
              latestSummary: chat.summaries.last,
            ); // Subsequent summaries: only new messages

      if (messagesToSummarize.isEmpty) {
        debugPrint('📝 No messages to summarize');
        return;
      }

      debugPrint('📝 Summarizing ${messagesToSummarize.length} messages...');

      // Generate summary
      final summary = await _summarizationService.generateSummary(
        messages: messagesToSummarize,
        existingSummaries: chat.summaries,
        config: config,
        characterName: character?.name,
        userName: persona?.name.isNotEmpty == true ? persona!.name : 'User',
      );

      // Add summary to chat
      final updatedSummaries = [...chat.summaries, summary];
      final updatedChat = chat.copyWith(summaries: updatedSummaries);
      await _chatRepository.updateChat(updatedChat);

      // Update state
      state = state.copyWith(chat: updatedChat);

      debugPrint(
          '✅ Summary created successfully (${updatedSummaries.length} total summaries)');
      debugPrint(
          '📌 Summary preview: ${summary.content.substring(0, min(100, summary.content.length))}...');
    } catch (e) {
      debugPrint('❌ Failed to create summary: $e');
      // Don't fail the entire message sending if summarization fails
    }
  }

  /// Manual full summary: ignores the threshold and existing summaries, regenerates one
  /// from all messages, and replaces the old summaries. Returns null on success or an
  /// error message otherwise; acts as a fallback when auto-summarization fails or
  /// produces poor results.
  Future<String?> manualSummarize() async {
    final chat = state.chat;
    if (chat == null) return '当前没有可总结的对话';

    if (state.messages.isEmpty) return '没有可总结的消息';

    final config = _ref.read(llmConfigProvider);

    // Raise the output limit so the summary is not truncated by maxTokens
    final summaryConfig = config.copyWith(maxTokens: 16384);

    try {
      final character = state.character;
      final activePersonaId = _ref.read(activePersonaIdProvider);
      Persona? persona;
      if (activePersonaId != null) {
        persona = await _personaRepository.getPersona(activePersonaId);
      }
      persona ??= await _personaRepository.getDefaultPersona();

      // Full pass: summarize every message without building on old summaries (passing
      // empty existingSummaries generates from scratch)
      final summary = await _summarizationService.generateSummary(
        messages: state.messages,
        existingSummaries: const [],
        config: summaryConfig,
        characterName: character?.name,
        userName: persona?.name.isNotEmpty == true ? persona!.name : 'User',
      );

      // Replace rather than append: a manual summary starts over and only this one is kept
      final updatedChat = chat.copyWith(summaries: [summary]);
      await _chatRepository.updateChat(updatedChat);
      state = state.copyWith(chat: updatedChat);

      debugPrint('✅ 手动总结完成，已替换为全新总结');
      return null;
    } catch (e) {
      debugPrint('❌ 手动总结失败: $e');
      return '总结失败：$e';
    }
  }

  /// Clear the current chat
  void clearChat() {
    state = const ActiveChatState();
  }

  /// Import messages into the current chat and refresh local state.
  Future<int> importMessages(List<ChatMessage> messages, {String? chatId}) async {
    final resolvedChatId = chatId ?? state.chat?.id;
    if (resolvedChatId == null || messages.isEmpty) return 0;

    await _chatRepository.clearMessages(resolvedChatId);
    final sortedMessages = [...messages]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (final message in sortedMessages) {
      await _chatRepository.addMessage(message.copyWith(chatId: resolvedChatId));
    }

    final updatedChat = await _chatRepository.getChat(resolvedChatId);
    final updatedMessages = await _chatRepository.getMessages(resolvedChatId);
    print('DEBUG importMessages: resolvedChatId=$resolvedChatId, stored=${updatedMessages.length}');

    state = state.copyWith(
      chat: updatedChat ?? state.chat,
      messages: updatedMessages,
    );

    return sortedMessages.length;
  }

  // Author's Note methods

  /// Update Author's Note content
  Future<void> updateAuthorNote(String content) async {
    if (state.chat == null) return;

    final updatedChat = state.chat!.copyWith(authorNote: content);
    await _chatRepository.updateChat(updatedChat);
    state = state.copyWith(chat: updatedChat);
  }

  /// Update Author's Note depth
  Future<void> updateAuthorNoteDepth(int depth) async {
    if (state.chat == null) return;

    final updatedChat = state.chat!.copyWith(authorNoteDepth: depth);
    await _chatRepository.updateChat(updatedChat);
    state = state.copyWith(chat: updatedChat);
  }

  /// Toggle Author's Note enabled state
  Future<void> toggleAuthorNote(bool enabled) async {
    if (state.chat == null) return;

    final updatedChat = state.chat!.copyWith(authorNoteEnabled: enabled);
    await _chatRepository.updateChat(updatedChat);
    state = state.copyWith(chat: updatedChat);
  }

  /// Update all Author's Note settings at once
  Future<void> updateAuthorNoteSettings({
    String? content,
    int? depth,
    bool? enabled,
  }) async {
    if (state.chat == null) return;

    final updatedChat = state.chat!.copyWith(
      authorNote: content ?? state.chat!.authorNote,
      authorNoteDepth: depth ?? state.chat!.authorNoteDepth,
      authorNoteEnabled: enabled ?? state.chat!.authorNoteEnabled,
    );
    await _chatRepository.updateChat(updatedChat);
    state = state.copyWith(chat: updatedChat);
  }

  // Bookmark / branching methods

  /// Get the message index for a given message ID
  int getMessageIndex(String messageId) {
    return state.messages.indexWhere((m) => m.id == messageId);
  }

  /// Get message ID at a specific index
  String? getMessageIdAt(int index) {
    if (index < 0 || index >= state.messages.length) return null;
    return state.messages[index].id;
  }

  /// Branch from a bookmark - delete messages after bookmark point and continue from there
  Future<void> branchFromBookmark(Bookmark bookmark) async {
    if (state.chat == null) return;

    // Find the message index for this bookmark
    final messageIndex =
        state.messages.indexWhere((m) => m.id == bookmark.messageId);
    if (messageIndex < 0) {
      // Message not found - might be in a different branch
      // Try to restore messages up to the bookmark's message index
      state =
          state.copyWith(error: 'Bookmark message not found in current chat');
      return;
    }

    // Delete all messages after the bookmark point
    if (messageIndex < state.messages.length - 1) {
      final messagesToDelete = state.messages.sublist(messageIndex + 1);
      for (final msg in messagesToDelete) {
        await _chatRepository.deleteMessage(msg.id);
      }

      state = state.copyWith(
        messages: state.messages.sublist(0, messageIndex + 1),
      );
    }
  }

  /// Get preview of messages up to a bookmark point
  List<ChatMessage> getMessagesUpTo(String messageId) {
    final index = state.messages.indexWhere((m) => m.id == messageId);
    if (index < 0) return [];
    return state.messages.sublist(0, index + 1);
  }

  /// Check if a bookmark's message still exists in current chat
  bool isBookmarkValid(Bookmark bookmark) {
    return state.messages.any((m) => m.id == bookmark.messageId);
  }

  // Group chat methods

  /// Send a message in group chat and get responses from characters
  Future<void> sendGroupMessage(
    String content,
    LLMConfig config, {
    List<ChatAttachment> attachments = const [],
  }) async {
    if (state.chat == null || state.group == null) return;

    // Add user message
    final userMessage = ChatMessage(
      id: _generateId(),
      chatId: state.chat!.id,
      role: MessageRole.user,
      content: content,
      timestamp: DateTime.now(),
      swipes: [content],
      currentSwipeIndex: 0,
      attachments: attachments,
    );

    await _chatRepository.addMessage(userMessage);
    _indexMessageToVector(chatId: userMessage.chatId, messageId: userMessage.id, content: userMessage.content);
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      error: null,
    );

    // Determine which characters should respond based on response mode
    final responders = _selectResponders(content);

    // Generate responses from each selected character
    for (final characterId in responders) {
      await _generateGroupCharacterResponse(characterId, config);
    }
  }

  /// Select which characters should respond based on group settings
  List<String> _selectResponders(String userMessage) {
    final group = state.group;
    if (group == null) return [];

    final activeMemberIds = group.members
        .where((m) => !m.isMuted)
        .map((m) => m.characterId)
        .toList();

    if (activeMemberIds.isEmpty) return [];

    final responseMode =
        group.settings.responseMode ?? GroupResponseMode.natural;

    switch (responseMode) {
      case GroupResponseMode.sequential:
        // Return the next character in sequence
        final lastAssistantMsg = state.messages.reversed.firstWhere(
          (m) => m.role == MessageRole.assistant && m.characterId != null,
          orElse: () => state.messages.first,
        );

        if (lastAssistantMsg.characterId != null) {
          final lastIndex =
              activeMemberIds.indexOf(lastAssistantMsg.characterId!);
          final nextIndex = (lastIndex + 1) % activeMemberIds.length;
          return [activeMemberIds[nextIndex]];
        }
        return [activeMemberIds.first];

      case GroupResponseMode.random:
        // Pick a random character
        final random = Random();
        return [activeMemberIds[random.nextInt(activeMemberIds.length)]];

      case GroupResponseMode.all:
        // All non-muted characters respond
        return activeMemberIds;

      case GroupResponseMode.manual:
        // User selects - return currently selected character if any
        final selectedId = _ref.read(selectedGroupCharacterIdProvider);
        if (selectedId != null && activeMemberIds.contains(selectedId)) {
          return [selectedId];
        }
        return [];

      case GroupResponseMode.natural:
        // AI decides based on context, trigger words, and talkativeness
        return _selectNaturalResponders(userMessage, activeMemberIds);
    }
  }

  /// Select responders using natural/AI-based selection
  List<String> _selectNaturalResponders(
      String userMessage, List<String> activeMemberIds) {
    final group = state.group;
    if (group == null) return [];

    final selectedResponders = <String>[];
    final random = Random();
    final lowerMessage = userMessage.toLowerCase();

    for (final member in group.members.where((m) => !m.isMuted)) {
      // Check trigger words
      bool triggered = false;
      for (final trigger in member.triggerWords) {
        if (lowerMessage.contains(trigger.toLowerCase())) {
          triggered = true;
          break;
        }
      }

      // Check character name mention
      final character = state.groupCharacters[member.characterId];
      if (character != null &&
          lowerMessage.contains(character.name.toLowerCase())) {
        triggered = true;
      }

      // If triggered, definitely respond
      if (triggered) {
        selectedResponders.add(member.characterId);
      } else {
        // Otherwise, use talkativeness probability
        if (random.nextInt(100) < member.talkativeness) {
          selectedResponders.add(member.characterId);
        }
      }
    }

    // Ensure at least one character responds
    if (selectedResponders.isEmpty && activeMemberIds.isNotEmpty) {
      // Pick the most talkative one
      final mostTalkative = group.members
          .where((m) => !m.isMuted && activeMemberIds.contains(m.characterId))
          .reduce((a, b) => a.talkativeness > b.talkativeness ? a : b);
      selectedResponders.add(mostTalkative.characterId);
    }

    return selectedResponders;
  }

  /// Generate a response from a specific character in a group chat
  Future<void> _generateGroupCharacterResponse(
      String characterId, LLMConfig config) async {
    final character = state.groupCharacters[characterId];
    if (character == null || state.chat == null) return;

    state = state.copyWith(
      isGenerating: true,
      currentResponderId: characterId,
      error: null,
    );

    try {
      final context = await _buildGroupContext(character);

      // Create placeholder for assistant message
      final assistantMessage = ChatMessage(
        id: _generateId(),
        chatId: state.chat!.id,
        role: MessageRole.assistant,
        content: '',
        timestamp: DateTime.now(),
        swipes: [''],
        currentSwipeIndex: 0,
        characterId: character.id,
        characterName: character.name,
      );

      state = state.copyWith(
        messages: [...state.messages, assistantMessage],
      );

      String finalContent;
      String? finalReasoning;

      if (config.streamEnabled) {
        // Stream the response with reasoning support
        final contentBuffer = StringBuffer();
        final reasoningBuffer = StringBuffer();
        final int myToken = ++_generationToken;
        final String myChatId = state.chat!.id;
        await for (final chunk
            in _llmService.generateStreamWithReasoning(context, config)) {
          // Validate the token: stop and discard immediately if it expired or the chat
          // switched, so output can never bleed into another chat
          if (myToken != _generationToken || state.chat?.id != myChatId) {
            return;
          }
          if (_isCancelling) break;

          if (chunk.isReasoningChunk && chunk.reasoning != null) {
            reasoningBuffer.write(chunk.reasoning);
          }
          if (chunk.content != null) {
            contentBuffer.write(chunk.content);
          }
          final updatedMessage = assistantMessage.copyWith(
            content: contentBuffer.toString(),
            swipes: [contentBuffer.toString()],
            reasoning:
                reasoningBuffer.isNotEmpty ? reasoningBuffer.toString() : null,
            reasoningSwipes: reasoningBuffer.isNotEmpty
                ? [reasoningBuffer.toString()]
                : null,
          );

          final updatedMessages = List<ChatMessage>.from(state.messages);
          updatedMessages[updatedMessages.length - 1] = updatedMessage;
          state = state.copyWith(messages: updatedMessages);
        }
        finalContent = contentBuffer.toString();
        finalReasoning =
            reasoningBuffer.isNotEmpty ? reasoningBuffer.toString() : null;
      } else {
        // Non-streaming: get complete response at once with reasoning support
        final response =
            await _llmService.generateWithReasoning(context, config);
        finalContent = response.content;
        finalReasoning = response.reasoning;

        // Update the message with final content
        final updatedMessage = assistantMessage.copyWith(
          content: finalContent,
          swipes: [finalContent],
        );
        final updatedMessages = List<ChatMessage>.from(state.messages);
        updatedMessages[updatedMessages.length - 1] = updatedMessage;
        state = state.copyWith(messages: updatedMessages);
      }

      // Save the final message
      final finalMessage = assistantMessage.copyWith(
        content: finalContent,
        swipes: [finalContent],
        reasoning: finalReasoning,
        reasoningSwipes: finalReasoning != null ? [finalReasoning] : null,
      );
      await _chatRepository.addMessage(finalMessage);
      _indexMessageToVector(chatId: finalMessage.chatId, messageId: finalMessage.id, content: finalMessage.content);

      state = state.copyWith(
        isGenerating: false,
        clearCurrentResponder: true,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ ChatProvider group response error: $e\n$stackTrace');
      state = state.copyWith(
        isGenerating: false,
        clearCurrentResponder: true,
        error: e.toString(),
      );
    }
  }

  /// Build context for group chat
  Future<List<Map<String, dynamic>>> _buildGroupContext(
      Character respondingCharacter) async {
    final messages = <Map<String, dynamic>>[];
    final group = state.group;
    if (group == null) return messages;

    // Build system prompt for group chat
    final systemPrompt = await _buildGroupSystemPrompt(respondingCharacter);
    messages.add({'role': 'system', 'content': systemPrompt});

    // Add chat messages
    for (final msg in state.messages) {
      if (msg.role == MessageRole.user) {
        messages.add({'role': 'user', 'content': msg.content});
      } else if (msg.role == MessageRole.assistant) {
        // For group chats, include character name in the message
        final charName = msg.characterName ?? 'Unknown';
        messages.add({
          'role': 'assistant',
          'content': '[$charName]: ${msg.content}',
        });
      }
    }

    return messages;
  }

  /// Build system prompt for group chat
  Future<String> _buildGroupSystemPrompt(Character respondingCharacter) async {
    final buffer = StringBuffer();
    final group = state.group;
    if (group == null) return '';

    // Get active persona
    final activePersonaId = _ref.read(activePersonaIdProvider);
    Persona? persona;
    if (activePersonaId != null) {
      persona = await _personaRepository.getPersona(activePersonaId);
    }
    persona ??= await _personaRepository.getDefaultPersona();

    // Get LLM config for macro context
    final llmConfig = _ref.read(llmConfigProvider);

    // Create macro context for processing
    final macroContext = MacroContext.fromData(
      character: respondingCharacter,
      persona: persona,
      chat: state.chat,
      messages: state.messages,
      modelName: llmConfig.model,
      providerName: llmConfig.provider.name,
      groupCharacters: state.groupCharacters.values.toList(),
    );
    final macroService = MacroService(macroContext);

    // Helper to process macros in text
    String processMacros(String text) => macroService.process(text);

    buffer.writeln('This is a group roleplay conversation.');
    buffer.writeln('You are roleplaying as ${respondingCharacter.name}.');
    buffer.writeln();

    // Add persona information
    if (persona != null && persona.name.isNotEmpty) {
      buffer.writeln('The user is ${persona.name}.');
      if (persona.description.isNotEmpty) {
        buffer
            .writeln('User description: ${processMacros(persona.description)}');
      }
      buffer.writeln();
    }

    // Describe the responding character
    buffer.writeln('=== YOUR CHARACTER: ${respondingCharacter.name} ===');
    if (respondingCharacter.description.isNotEmpty) {
      buffer.writeln(
          'Description: ${processMacros(respondingCharacter.description)}');
    }
    if (respondingCharacter.personality.isNotEmpty) {
      buffer.writeln(
          'Personality: ${processMacros(respondingCharacter.personality)}');
    }
    buffer.writeln();

    // Describe other characters in the group
    buffer.writeln('=== OTHER CHARACTERS IN THIS CONVERSATION ===');
    for (final entry in state.groupCharacters.entries) {
      if (entry.key != respondingCharacter.id) {
        final char = entry.value;
        buffer.writeln(
            '${char.name}: ${char.description.isNotEmpty ? processMacros(char.description) : "No description"}');
      }
    }
    buffer.writeln();

    // Add scenario if the responding character has one
    if (respondingCharacter.scenario.isNotEmpty) {
      buffer
          .writeln('Scenario: ${processMacros(respondingCharacter.scenario)}');
      buffer.writeln();
    }

    // Add system prompt if the responding character has one
    if (respondingCharacter.systemPrompt.isNotEmpty) {
      buffer.writeln(processMacros(respondingCharacter.systemPrompt));
    }

    buffer.writeln();
    buffer.writeln(
        'IMPORTANT: Stay in character as ${respondingCharacter.name}. ');
    buffer.writeln(
        'Do not speak for other characters. Only respond as ${respondingCharacter.name}.');
    buffer.writeln(
        'Do not include your name prefix in your response - just write your dialogue/actions directly.');

    return buffer.toString();
  }

  /// Manually trigger a specific character to respond (for manual mode)
  Future<void> triggerCharacterResponse(
      String characterId, LLMConfig config) async {
    if (!state.isGroupChat) return;
    await _generateGroupCharacterResponse(characterId, config);
  }
}

/// Provider for active chat
final activeChatProvider =
    StateNotifierProvider<ActiveChatNotifier, ActiveChatState>((ref) {
  final chatRepo = ref.watch(chatRepositoryProvider);
  final characterRepo = ref.watch(characterRepositoryProvider);
  final personaRepo = ref.watch(personaRepositoryProvider);
  final llmService = ref.watch(llmServiceProvider);
  final worldInfoMatcher = ref.watch(worldInfoMatcherProvider);
  final summarizationService = ref.watch(chatSummarizationServiceProvider);

  return ActiveChatNotifier(
    chatRepository: chatRepo,
    characterRepository: characterRepo,
    personaRepository: personaRepo,
    llmService: llmService,
    worldInfoMatcher: worldInfoMatcher,
    summarizationService: summarizationService,
    ref: ref,
  );
});

/// Chat list for a character
final characterChatsProvider =
    FutureProvider.family<List<Chat>, String>((ref, characterId) async {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.getChatsForCharacter(characterId);
});

/// All chats list
final allChatsProvider = FutureProvider<List<Chat>>((ref) async {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.getAllChats();
});

/// Recent chats
final recentChatsProvider = FutureProvider<List<Chat>>((ref) async {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.getRecentChats(limit: 10);
});
