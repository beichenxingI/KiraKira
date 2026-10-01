import 'package:flutter/foundation.dart';
import 'package:kirakira/data/models/chat.dart';
import 'package:kirakira/data/models/chronicle.dart';
import 'package:kirakira/domain/services/llm_service.dart';
import 'package:uuid/uuid.dart';

/// Service for automatic chat history summarization
///
/// The legacy automatic summarization is disabled (shouldSummarize always
/// returns false). This service still provides generateSummary (reused by the
/// Chronicle fallback path) and getRecentMessages/createSummaryMessage (kept
/// for backward-compatible reads).
class ChatSummarizationService {
  final LLMService _llmService;

  ChatSummarizationService(this._llmService);

  /// Absolute token limit (a pure proportional threshold almost never triggers with 1M context)
  static const int absoluteTokenLimit = 50000;

  /// Check if summarization should be triggered based on current context usage
  ///
  /// Forcefully disabled: Chronicle super memory takes over all summarization
  /// (three-window sliding + async SummaryTask pipeline + wiki entries).
  /// Legacy automatic summarization (in-memory ChatSummary, lost on restart)
  /// no longer triggers. TODO: delete this service once Chronicle is stable.
  Future<bool> shouldSummarize({
    required List<ChatMessage> messages,
    required List<ChatSummary> existingSummaries,
    required LLMConfig config,
  }) async {
    // Chronicle has taken over summarization; legacy automatic summarization is disabled.
    // TODO: delete this service once Chronicle is stable.
    return false;
  }

  /// Generate a summary of chat history
  Future<ChatSummary> generateSummary({
    required List<ChatMessage> messages,
    required List<ChatSummary> existingSummaries,
    required LLMConfig config,
    String? characterName,
    String? userName,
  }) async {
    debugPrint('📝 Generating summary for ${messages.length} messages...');
    
    // Build the prompt for summarization
    final prompt = _buildSummarizationPrompt(
      messages: messages,
      existingSummaries: existingSummaries,
      characterName: characterName ?? 'Assistant',
      userName: userName ?? 'User',
      customPrompt: config.summaryPrompt,
    );
    
    debugPrint('📝 Summary prompt length: ${prompt.length} chars');
    
    // Generate summary using LLM
    final summaryText = await _generateSummaryText(
      prompt: prompt,
      config: config,
    );
    
    debugPrint('📝 Generated summary: ${summaryText.substring(0, summaryText.length > 100 ? 100 : summaryText.length)}...');
    
    // Create summary record
    final summary = ChatSummary(
      id: const Uuid().v4(),
      content: summaryText,
      endMessageIndex: messages.length - 1,
      createdAt: DateTime.now(),
    );
    
    return summary;
  }

  /// Build the prompt for summarization
  String _buildSummarizationPrompt({
    required List<ChatMessage> messages,
    required List<ChatSummary> existingSummaries,
    required String characterName,
    required String userName,
    String customPrompt = '',
  }) {
    final buffer = StringBuffer();
    
    if (customPrompt.isNotEmpty) {
      buffer.writeln(customPrompt);
    } else {
      buffer.writeln('你是一个专业的角色扮演对话整理助手，请用中文总结下面这段对话历史。');
      buffer.writeln('生成简洁但不遗漏关键信息的总结，重点保留：');
      buffer.writeln('- 剧情的关键进展与转折');
      buffer.writeln('- 角色之间的关系变化与情感线');
      buffer.writeln('- 重要的设定与世界观细节');
      buffer.writeln('- 时间线与时间推进（第几天、时段、关键时间节点）');
      buffer.writeln('- 角色状态与数值变化（好感度、心情、持有物品等，若对话中有出现）');
      buffer.writeln('- 角色做出的关键决定及其后果');
      buffer.writeln('- 当前所处的情境与状态');
      buffer.writeln();
      buffer.writeln('以第三人称、过去时客观叙述，不要遗漏对后续剧情有影响的细节。');
      buffer.writeln('必须用中文输出，即使原对话包含其他语言。');
    }
    buffer.writeln();
    
    // Include existing summaries if any
    if (existingSummaries.isNotEmpty) {
      buffer.writeln('=== PREVIOUS SUMMARY ===');
      // Use the most recent summary
      buffer.writeln(existingSummaries.last.content);
      buffer.writeln();
      buffer.writeln('=== NEW CONVERSATION TO SUMMARIZE ===');
    } else {
      buffer.writeln('=== CONVERSATION TO SUMMARIZE ===');
    }
    
    // Add messages
    for (final message in messages) {
      final speaker = message.role == MessageRole.user ? userName : characterName;
      buffer.writeln('$speaker: ${message.content}');
    }
    
    buffer.writeln();
    if (existingSummaries.isNotEmpty) {
      buffer.writeln('请将之前的总结与上面这段新对话合并，整合成一份连贯的中文总结。');
    } else {
      buffer.writeln('请用中文总结以上对话：');
    }
    buffer.writeln();
    buffer.writeln('SUMMARY:');
    
    return buffer.toString();
  }

  /// Generate summary text using LLM
  Future<String> _generateSummaryText({
    required String prompt,
    required LLMConfig config,
  }) async {
    final buffer = StringBuffer();
    
    // Create a config with modified settings for summarization
    final summaryConfig = config.copyWith(
      temperature: 0.3, // Lower temperature for more stable, focused summaries
      maxTokens: 9216, // Enough room to preserve details
      model: config.summaryModel.isNotEmpty ? config.summaryModel : config.model, // Use the custom summary model if set, otherwise the main model
    );
    
    // Build messages for summarization
    final messages = [
      {'role': 'system', 'content': 'You are a helpful assistant that creates concise conversation summaries.'},
      {'role': 'user', 'content': prompt},
    ];
    
    // Generate using LLM service
    await for (final chunk in _llmService.generateStreamWithReasoning(messages, summaryConfig)) {
      if (chunk.content != null) {
        buffer.write(chunk.content);
      }
    }
    
    return buffer.toString().trim();
  }

  /// Get messages to include in context after summarization
  List<ChatMessage> getRecentMessages({
    required List<ChatMessage> allMessages,
    required ChatSummary latestSummary,
  }) {
    // Return messages after the last summarized message
    final startIndex = latestSummary.endMessageIndex + 1;
    if (startIndex >= allMessages.length) {
      return [];
    }
    return allMessages.sublist(startIndex);
  }

  /// Four-window split (unarchived zone + hot + warm + cold zones);
  /// [windowSize] is measured in turns (1 turn = user + AI, about 2 messages;
  /// internally multiplied by 2 to convert to messages).
  ///
  /// - Unarchived zone: all unarchived messages (highest attention, injected
  ///   at the end)
  /// - Hot zone: the most recent [windowSize] turns of archived messages
  ///   (original text + entries)
  /// - Warm zone: the [windowSize] turns of archived messages before the hot
  ///   zone (original text + entries)
  /// - Cold zone: the [windowSize] turns of archived messages before the warm
  ///   zone (original text + entries)
  /// - Older archived: fully faded out, original text not injected (content
  ///   is still reachable via entries through F-6/F-7)
  ///
  /// Injection order is cold, warm, hot, then unarchived, exploiting
  /// Lost in the Middle: the newer the content, the closer to the end.
  WindowedMessages getWindowedMessages({
    required Set<String> archivedMessageIds,
    required List<ChatMessage> allMessages,
    int windowSize = 20, // in turns (1 turn = user + AI, about 2 messages)
  }) {
    final nonArchived =
        allMessages.where((m) => !archivedMessageIds.contains(m.id)).toList();
    final archived =
        allMessages.where((m) => archivedMessageIds.contains(m.id)).toList();

    // windowSize is in turns; multiply by 2 to convert to messages
    final windowInMessages = windowSize * 2;

    // Unarchived zone: all unarchived messages (injected at the end, highest attention)
    final unarchived = nonArchived;

    // Hot zone: the most recent windowInMessages archived messages
    final hotStart =
        (archived.length - windowInMessages).clamp(0, archived.length);
    final hot = archived.sublist(hotStart, archived.length);

    // Warm zone: windowInMessages archived messages before the hot zone
    final warmStart = (hotStart - windowInMessages).clamp(0, hotStart);
    final warm = archived.sublist(warmStart, hotStart);

    // Cold zone: windowInMessages archived messages before the warm zone
    final coldStart = (warmStart - windowInMessages).clamp(0, warmStart);
    final cold = archived.sublist(coldStart, warmStart);

    // Older archived: original text not injected (only reachable via entries through F-6/F-7)

    return WindowedMessages(
      unarchived: unarchived,
      hot: hot,
      warm: warm,
      cold: cold,
    );
  }

  /// Create a pseudo-message from summary for context building
  ChatMessage createSummaryMessage({
    required ChatSummary summary,
    required String chatId,
  }) {
    final summaryContent = '''[Context Summary]

${summary.content}''';
    return ChatMessage(
      id: 'summary_${summary.id}',
      chatId: chatId,
      role: MessageRole.assistant,
      content: summaryContent,
      timestamp: summary.createdAt,
      swipes: [summaryContent],
      currentSwipeIndex: 0,
    );
  }
}
