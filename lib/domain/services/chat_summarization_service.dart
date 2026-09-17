import 'package:flutter/foundation.dart';
import 'package:kirakira/data/models/chat.dart';
import 'package:kirakira/data/models/chronicle.dart';
import 'package:kirakira/domain/services/llm_service.dart';
import 'package:kirakira/domain/services/tokenizer_service.dart';
import 'package:uuid/uuid.dart';

/// Service for automatic chat history summarization
class ChatSummarizationService {
  final LLMService _llmService;
  final TokenizerService _tokenizerService;

  ChatSummarizationService(this._llmService, this._tokenizerService);

  /// [CHRONICLE Phase 1] 绝对token上限（H7修正：1M上下文时纯比例阈值几乎永不触发）
  static const int absoluteTokenLimit = 50000;

  /// Check if summarization should be triggered based on current context usage
  Future<bool> shouldSummarize({
    required List<ChatMessage> messages,
    required List<ChatSummary> existingSummaries,
    required LLMConfig config,
  }) async {
    if (!config.autoSummarizeEnabled) {
      return false;
    }

    // Calculate token usage based on what will actually be in context
    int contextTokens;

    if (existingSummaries.isEmpty) {
      // No summaries yet - count all messages
      contextTokens = await _estimateTokenCount(messages, []);
      debugPrint('📊 No summaries yet, counting all ${messages.length} messages');
    } else {
      // Have summaries - only count the latest summary + recent messages
      final latestSummary = existingSummaries.last;
      final recentMessages = getRecentMessages(
        allMessages: messages,
        latestSummary: latestSummary,
      );

      // Count: 1 summary + recent messages
      contextTokens = await _estimateTokenCount(recentMessages, [latestSummary]);
      debugPrint('📊 Have ${existingSummaries.length} summaries, counting 1 summary + ${recentMessages.length} recent messages');
    }

    final maxContext = config.contextLength;
    final threshold = config.autoSummarizeThreshold;

    final currentUsage = contextTokens / maxContext;

    // [CHRONICLE Phase 1] 比例阈值 + 绝对上限双触发（H7）
    final shouldTrigger =
        currentUsage >= threshold || contextTokens >= absoluteTokenLimit;

    debugPrint('📊 Context usage: $contextTokens / $maxContext tokens (${(currentUsage * 100).toStringAsFixed(1)}%)');
    debugPrint('📊 Threshold: ${(threshold * 100).toStringAsFixed(1)}% | absolute limit: $absoluteTokenLimit');
    debugPrint('📊 Should trigger: $shouldTrigger');

    return shouldTrigger;
  }

  /// Estimate total token count for messages and summaries
  Future<int> _estimateTokenCount(
    List<ChatMessage> messages,
    List<ChatSummary> summaries,
  ) async {
    int totalTokens = 0;
    
    // Count summary tokens
    for (final summary in summaries) {
      totalTokens += _tokenizerService.estimateTokenCount(summary.content);
    }
    
    // Count message tokens
    for (final message in messages) {
      totalTokens += _tokenizerService.estimateTokenCount(message.content);
      // Also count reasoning if present
      if (message.reasoning != null) {
        totalTokens += _tokenizerService.estimateTokenCount(message.reasoning!);
      }
    }
    
    return totalTokens;
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
      temperature: 0.3, // 降低温度让总结更稳定聚焦
      maxTokens: 9216, // 给总结足够空间保留细节
      model: config.summaryModel.isNotEmpty ? config.summaryModel : config.model, // 有自定义总结模型就用它，否则沿用主模型
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

  /// [CHRONICLE Phase 1] 三窗口切分（替代"上次总结后全量注入"）。
  ///
  /// - 热区：最近 [windowSize] 条未归档消息（高注意力，注入末尾）
  /// - 温区：最近 [windowSize] 条已归档消息（渐进淡出）
  /// - 冷区：温区之前的 [windowSize] 条已归档（最低注意力，超出即彻底淡出）
  ///
  /// 注入顺序 冷→温→热，利用 Lost in the Middle：越新越靠末尾。
  WindowedMessages getWindowedMessages({
    required Set<String> archivedMessageIds,
    required List<ChatMessage> allMessages,
    int windowSize = 20,
  }) {
    final nonArchived =
        allMessages.where((m) => !archivedMessageIds.contains(m.id)).toList();
    final archived =
        allMessages.where((m) => archivedMessageIds.contains(m.id)).toList();

    // 热区：最近 windowSize 条未归档
    final hot = nonArchived.length <= windowSize
        ? nonArchived
        : nonArchived.sublist(nonArchived.length - windowSize);

    // 温区：最近 windowSize 条已归档
    final warm = archived.length <= windowSize
        ? archived
        : archived.sublist(archived.length - windowSize);

    // 冷区：温区之前的 windowSize 条已归档；再往前彻底淡出（不再注入）
    final olderArchived = archived.length > windowSize
        ? archived.sublist(0, archived.length - windowSize)
        : <ChatMessage>[];
    final cold = olderArchived.length <= windowSize
        ? olderArchived
        : olderArchived.sublist(olderArchived.length - windowSize);

    return WindowedMessages(cold: cold, warm: warm, hot: hot);
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
