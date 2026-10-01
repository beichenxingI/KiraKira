import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:kirakira/data/models/chat.dart';
import 'package:kirakira/data/models/character.dart';
import 'package:kirakira/data/models/chronicle.dart' as models;
import 'package:kirakira/data/repositories/chronicle_repository.dart';
import 'package:kirakira/domain/services/vector_storage_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

/// Service for importing and exporting chat history
/// Compatible with SillyTavern JSONL format
class ChatExportService {
  static const List<String> _supportedImportExtensions = ['jsonl', 'json'];

  /// Optional injection: embed kira_chronicle inside the chat file when set
  final ChronicleRepository? chronicleRepo;
  final VectorStorageService? vectorStorage;

  ChatExportService({this.chronicleRepo, this.vectorStorage});

  /// Export chat to SillyTavern-compatible JSONL format
  ///
  /// SillyTavern format:
  /// - First line: metadata object with user_name, character_name, create_date
  /// - Following lines: message objects with name, is_user, is_system, send_date, mes, swipes, swipe_id
  Future<String> exportToJsonl(
    Chat chat,
    List<ChatMessage> messages,
    Character character, {
    String? userName,
  }) async {
    final buffer = StringBuffer();

    // First line: metadata
    final metadata = {
      'user_name': userName ?? 'User',
      'character_name': character.name,
      'create_date': chat.createdAt.millisecondsSinceEpoch,
      'chat_metadata': {
        'note_prompt': chat.authorNote,
        'note_depth': chat.authorNoteDepth,
        'note_interval': 1,
        'note_position': 1,
      },
    };
    // Embed super memory data (only in KiraKira's own export; SillyTavern import ignores unknown fields)
    final chronicleData = await _buildChronicleBundle(chat.id);
    if (chronicleData != null) {
      metadata['kira_chronicle'] = chronicleData;
    }
    buffer.writeln(jsonEncode(metadata));

    // Message lines
    for (final message in messages) {
      final isUser = message.role == MessageRole.user;
      final isSystem = message.role == MessageRole.system;

      final messageData = {
        'name': isUser ? (userName ?? 'User') : character.name,
        'is_user': isUser,
        'is_system': isSystem,
        'send_date': message.timestamp.millisecondsSinceEpoch,
        'mes': message.content,
        'swipes': message.swipes,
        'swipe_id': message.currentSwipeIndex,
        if (message.reasoning != null) 'reasoning': message.reasoning,
        if (message.reasoningSwipes != null)
          'reasoning_swipes': message.reasoningSwipes,
        if (message.characterId != null) 'original_avatar': message.characterId,
        if (message.characterName != null)
          'force_avatar': message.characterName,
      };
      buffer.writeln(jsonEncode(messageData));
    }

    return buffer.toString();
  }

  /// Export chat to JSON format (alternative format)
  Future<String> exportToJson(
    Chat chat,
    List<ChatMessage> messages,
    Character character, {
    String? userName,
  }) async {
    final data = {
      'chat_id': chat.id,
      'character_id': chat.characterId,
      'character_name': character.name,
      'user_name': userName ?? 'User',
      'title': chat.title,
      'created_at': chat.createdAt.toIso8601String(),
      'updated_at': chat.updatedAt.toIso8601String(),
      'author_note': chat.authorNote,
      'author_note_depth': chat.authorNoteDepth,
      'author_note_enabled': chat.authorNoteEnabled,
      'messages': messages
          .map((m) => {
                'id': m.id,
                'role': m.role.name,
                'content': m.content,
                'timestamp': m.timestamp.toIso8601String(),
                'swipes': m.swipes,
                'current_swipe_index': m.currentSwipeIndex,
                if (m.reasoning != null) 'reasoning': m.reasoning,
                if (m.reasoningSwipes != null)
                  'reasoning_swipes': m.reasoningSwipes,
                if (m.characterId != null) 'character_id': m.characterId,
                if (m.characterName != null) 'character_name': m.characterName,
              })
          .toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Save exported chat to file and share
  Future<void> exportAndShare(
    Chat chat,
    List<ChatMessage> messages,
    Character character, {
    String? userName,
    bool useJsonl = true,
  }) async {
    final content = useJsonl
        ? await exportToJsonl(chat, messages, character, userName: userName)
        : await exportToJson(chat, messages, character, userName: userName);

    final extension = useJsonl ? 'jsonl' : 'json';
    final fileName = '${character.name}_${chat.id}.$extension';

    // Get temp directory
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(content);

    // Share the file using the new share_plus API
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Chat with ${character.name}',
    );
  }

  /// Save exported chat to downloads folder
  Future<String?> exportToFile(
    Chat chat,
    List<ChatMessage> messages,
    Character character, {
    String? userName,
    bool useJsonl = true,
  }) async {
    final content = useJsonl
        ? await exportToJsonl(chat, messages, character, userName: userName)
        : await exportToJson(chat, messages, character, userName: userName);

    final extension = useJsonl ? 'jsonl' : 'json';
    final fileName = '${character.name}_${chat.id}.$extension';

    // Let user choose save location
    // file_picker 8.3.7: on mobile, saveFile requires bytes (otherwise it
    // throws "Bytes are required"); on desktop it only returns the path
    // without writing the file, so the file must be written manually.
    final isMobile = Platform.isAndroid || Platform.isIOS;
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Chat Export',
      fileName: fileName,
      bytes: isMobile ? utf8.encode(content) : null,
      type: FileType.custom,
      allowedExtensions: [extension],
    );

    if (result != null) {
      if (!isMobile) {
        await File(result).writeAsString(content);
      }
      return result;
    }

    return null;
  }

  /// Import chat from JSONL format
  /// Returns a tuple of (metadata, messages)
  Future<ChatImportResult?> importFromJsonl(String content) async {
    final lines = content.trim().split('\n');
    if (lines.isEmpty) return null;

    try {
      // First line is metadata
      final metadata = jsonDecode(lines[0]) as Map<String, dynamic>;
      final userName = metadata['user_name'] as String? ?? 'User';
      final characterName =
          metadata['character_name'] as String? ?? 'Character';
      final createDate = metadata['create_date'] as int?;
      final chatMetadata = metadata['chat_metadata'] as Map<String, dynamic>?;

      // Parse messages
      final messages = <ImportedMessage>[];
      for (var i = 1; i < lines.length; i++) {
        if (lines[i].trim().isEmpty) continue;

        try {
          final msgData = jsonDecode(lines[i]) as Map<String, dynamic>;
          final isUser = msgData['is_user'] as bool? ?? false;
          final isSystem = msgData['is_system'] as bool? ?? false;

          MessageRole role;
          if (isSystem) {
            role = MessageRole.system;
          } else if (isUser) {
            role = MessageRole.user;
          } else {
            role = MessageRole.assistant;
          }

          messages.add(ImportedMessage(
            role: role,
            content: msgData['mes'] as String? ?? '',
            timestamp: msgData['send_date'] != null
                ? DateTime.fromMillisecondsSinceEpoch(
                    msgData['send_date'] as int)
                : DateTime.now(),
            swipes: (msgData['swipes'] as List<dynamic>?)?.cast<String>() ?? [],
            currentSwipeIndex: msgData['swipe_id'] as int? ?? 0,
            reasoning: msgData['reasoning'] as String?,
            reasoningSwipes:
                (msgData['reasoning_swipes'] as List<dynamic>?)?.cast<String>(),
            characterId: msgData['original_avatar'] as String?,
            characterName: msgData['force_avatar'] as String?,
          ));
        } catch (e) {
          // Skip malformed message lines
          continue;
        }
      }

      return ChatImportResult(
        userName: userName,
        characterName: characterName,
        createDate: createDate != null
            ? DateTime.fromMillisecondsSinceEpoch(createDate)
            : DateTime.now(),
        authorNote: chatMetadata?['note_prompt'] as String?,
        authorNoteDepth: chatMetadata?['note_depth'] as int?,
        messages: messages,
        // Carry the memory bundle (null when absent; SillyTavern standard files are unaffected)
        chronicleData: metadata['kira_chronicle'] is Map
            ? Map<String, dynamic>.from(metadata['kira_chronicle'] as Map)
            : null,
      );
    } catch (e) {
      return null;
    }
  }

  /// Import chat from JSON format
  Future<ChatImportResult?> importFromJson(String content) async {
    try {
      final data = jsonDecode(content) as Map<String, dynamic>;

      final userName = data['user_name'] as String? ?? 'User';
      final characterName = data['character_name'] as String? ?? 'Character';
      final createdAt = data['created_at'] != null
          ? DateTime.parse(data['created_at'] as String)
          : DateTime.now();

      final messagesData = data['messages'] as List<dynamic>? ?? [];
      final messages = messagesData.map((m) {
        final msgData = m as Map<String, dynamic>;
        return ImportedMessage(
          role: MessageRole.values.firstWhere(
            (r) => r.name == msgData['role'],
            orElse: () => MessageRole.user,
          ),
          content: msgData['content'] as String? ?? '',
          timestamp: msgData['timestamp'] != null
              ? DateTime.parse(msgData['timestamp'] as String)
              : DateTime.now(),
          swipes: (msgData['swipes'] as List<dynamic>?)?.cast<String>() ?? [],
          currentSwipeIndex: msgData['current_swipe_index'] as int? ?? 0,
          reasoning: msgData['reasoning'] as String?,
          reasoningSwipes:
              (msgData['reasoning_swipes'] as List<dynamic>?)?.cast<String>(),
          characterId: msgData['character_id'] as String?,
          characterName: msgData['character_name'] as String?,
        );
      }).toList();

      return ChatImportResult(
        userName: userName,
        characterName: characterName,
        createDate: createdAt,
        authorNote: data['author_note'] as String?,
        authorNoteDepth: data['author_note_depth'] as int?,
        authorNoteEnabled: data['author_note_enabled'] as bool?,
        messages: messages,
      );
    } catch (e) {
      return null;
    }
  }

  // Chat file embedding (kira_chronicle)

  /// Build the kira_chronicle bundle (entries/entities/relationships/emotions
  /// + gzip-compressed vectors + window state). Only wiki entry vectors are
  /// stored, not message original-text vectors (keeps chat export size down).
  /// Returns null when there is no Chronicle data or no repo was injected.
  Future<Map<String, dynamic>?> _buildChronicleBundle(String chatId) async {
    final repo = chronicleRepo;
    if (repo == null) return null;
    try {
      final entries = await repo.getAllEntries(chatId);
      final entities = await repo.getAllEntities(chatId);
      final relationships = await repo.getAllRelationships(chatId);
      final emotions = await repo.getAllEmotions(chatId);
      if (entries.isEmpty &&
          entities.isEmpty &&
          relationships.isEmpty &&
          emotions.isEmpty) {
        return null;
      }

      // Vectors: only chronicle_* documents (coexist with RAG original-text vectors; export only carries wiki vectors)
      final vectors = <Map<String, dynamic>>[];
      if (vectorStorage != null) {
        final collection = vectorStorage!.getCollection(chatId);
        if (collection != null) {
          for (final doc in collection.documents) {
            if (doc.id.startsWith('chronicle_') && doc.embedding != null) {
              vectors.add({
                'id': doc.id,
                'content': doc.content,
                'embedding': doc.embedding,
                'metadata': doc.metadata,
              });
            }
          }
        }
      }

      final archivedIds = await repo.getArchivedMessageIds(chatId);

      return {
        'version': 1,
        'entries': entries.map((e) => e.toJson()).toList(),
        'entities': entities.map((e) => e.toJson()).toList(),
        'relationships': relationships.map((r) => r.toJson()).toList(),
        'emotions': emotions.map((e) => e.toJson()).toList(),
        // gzip-compressed then base64 (384 dims, ~150 entries is about 80KB)
        'vectors': _gzipBase64(jsonEncode(vectors)),
        'window_state': {
          'archived_message_ids': archivedIds.toList(),
        },
      };
    } catch (e) {
      // Chronicle bundling failure does not affect chat export
      return null;
    }
  }

  /// Restore Chronicle data to the target chat after import. Imported
  /// messages get newly generated messageIds, so the archived ids in
  /// window_state are stale: only entries/entities/relationships/emotions/
  /// vectors are restored, and window state is naturally rebuilt by the new
  /// conversation.
  Future<void> restoreChronicleToChat(
      String chatId, Map<String, dynamic> bundle) async {
    final repo = chronicleRepo;
    if (repo == null) return;
    try {
      for (final e in (bundle['entries'] as List? ?? const [])) {
        if (e is! Map) continue;
        final entry = models.MemoryEntry.fromJson(
            Map<String, dynamic>.from(e));
        // Rebind to the target chat
        await repo.upsertMemoryEntry(entry.copyWith(
          chatId: chatId,
          updatedAt: DateTime.now(),
        ));
      }
      for (final e in (bundle['entities'] as List? ?? const [])) {
        if (e is! Map) continue;
        final entity = models.MemoryEntity.fromJson(
            Map<String, dynamic>.from(e));
        await repo.upsertEntity(entity.copyWith(
          chatId: chatId,
          updatedAt: DateTime.now(),
        ));
      }
      for (final r in (bundle['relationships'] as List? ?? const [])) {
        if (r is! Map) continue;
        final rel = models.MemoryRelationship.fromJson(
            Map<String, dynamic>.from(r));
        await repo.upsertRelationship(
          chatId,
          models.UpsertRelationshipInstruction(
            fromName: '',
            toName: '',
            relationType: rel.relationType,
            strength: rel.strength,
            description: rel.description,
          ),
          fromEntityId: rel.fromEntityId,
          toEntityId: rel.toEntityId,
        );
      }
      for (final e in (bundle['emotions'] as List? ?? const [])) {
        if (e is! Map) continue;
        final emo = models.EmotionNode.fromJson(
            Map<String, dynamic>.from(e));
        await repo.upsertEmotion(
          chatId,
          models.UpsertEmotionInstruction(
            entityName: '',
            emotion: emo.emotion,
            intensity: emo.intensity,
            trigger: emo.trigger,
            active: emo.isActive,
          ),
          entityId: emo.entityId,
          turnIndex: emo.turnIndex,
        );
      }

      // Vector restore (skipped when the target chat's collection does not
      // exist; the collection is auto-created by loadChat/message sending)
      final vectorsRaw = bundle['vectors'] as String?;
      if (vectorsRaw != null && vectorsRaw.isNotEmpty && vectorStorage != null) {
        try {
          final vectorsJson = _gunzipBase64(vectorsRaw);
          final vectors = jsonDecode(vectorsJson) as List;
          final collection = vectorStorage!.getCollection(chatId);
          if (collection != null) {
            for (final v in vectors) {
              if (v is! Map) continue;
              final id = v['id'] as String?;
              final embedding = (v['embedding'] as List?)
                  ?.map((e) => (e as num).toDouble())
                  .toList();
              if (id == null || embedding == null) continue;
              vectorStorage!.addDocumentWithId(
                collectionId: chatId,
                documentId: id,
                content: v['content'] as String? ?? '',
                embedding: embedding,
                metadata: v['metadata'] is Map
                    ? Map<String, dynamic>.from(v['metadata'] as Map)
                    : const {},
              );
            }
          }
        } catch (_) {
          // Vector restore failure does not block entry restore
        }
      }
    } catch (_) {
      // Chronicle restore failure does not affect message import
    }
  }

  static String _gzipBase64(String json) {
    final bytes = utf8.encode(json);
    final compressed = GZipCodec().encode(bytes);
    return base64Encode(compressed);
  }

  static String _gunzipBase64(String b64) {
    final bytes = base64Decode(b64);
    final decompressed = GZipCodec().decode(bytes);
    return utf8.decode(decompressed);
  }

  /// Import chat from file
  Future<ChatImportResult?> importFromFile() async {    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = File(result.files.first.path!);
    final content = await file.readAsString();
    final fileName = result.files.first.name.toLowerCase();
    final fileExtension =
        fileName.contains('.') ? fileName.split('.').last : '';

    if (!_supportedImportExtensions.contains(fileExtension)) {
      return null;
    }

    final trimmed = content.trimLeft();
    // A JSON array means a third-party platform format
    if (trimmed.startsWith('[')) {
      return importFromThirdPartyArray(content);
    }
    if (fileName.endsWith('.jsonl')) {
      return importFromJsonl(content);
    }
    return importFromJson(content);
  }

  /// Auto-detect format and import
  Future<ChatImportResult?> importFromString(String content) async {
    // Try JSONL first (starts with { and has multiple lines)
    if (content.trim().startsWith('{') && content.contains('\n')) {
      final result = await importFromJsonl(content);
      if (result != null) return result;
    }

    // Try JSON
    return importFromJson(content);
  }
  /// Import chat history from a third-party platform (JSON array format).
  /// Format: [{id, role, content, timestamp, image (optional base64), embedding (discarded)}]
  Future<ChatImportResult?> importFromThirdPartyArray(String content) async {
    try {
      final data = jsonDecode(content) as List<dynamic>;
      final messages = <ImportedMessage>[];

      // Directory for saving imported images
      final dir = await getApplicationDocumentsDirectory();
      final imgDir = Directory('${dir.path}/imported_images');
      if (!await imgDir.exists()) await imgDir.create(recursive: true);

      for (final item in data) {
        if (item is! Map<String, dynamic>) continue;

        // Role mapping
        final roleStr = item['role'] as String? ?? 'assistant';
        final role = roleStr == 'user'
            ? MessageRole.user
            : (roleStr == 'system' ? MessageRole.system : MessageRole.assistant);

        final ts = item['timestamp'];
        final timestamp = ts is int
            ? DateTime.fromMillisecondsSinceEpoch(ts)
            : DateTime.now();

        // Save base64 image to disk (embedding is ignored, not parsed)
        final attachments = <ChatAttachment>[];
        final imageData = item['image'] as String?;
        if (imageData != null && imageData.isNotEmpty) {
          try {
            // Strip a possible data:image/xxx;base64, prefix
            var b64 = imageData;
            var mime = 'image/png';
            if (b64.startsWith('data:')) {
              final comma = b64.indexOf(',');
              if (comma != -1) {
                final header = b64.substring(5, comma); // image/png;base64
                mime = header.split(';').first;
                b64 = b64.substring(comma + 1);
              }
            }
            final bytes = base64Decode(b64);
            final ext = mime.contains('jpeg') || mime.contains('jpg')
                ? 'jpg'
                : (mime.contains('webp') ? 'webp' : 'png');
            final imgId = '${DateTime.now().microsecondsSinceEpoch}_${messages.length}';
            final imgFile = File('${imgDir.path}/$imgId.$ext');
            await imgFile.writeAsBytes(bytes);
            attachments.add(ChatAttachment(
              id: imgId,
              path: imgFile.path,
              mimeType: mime,
              sizeBytes: bytes.length,
            ));
          } catch (_) {
            // Skip the image on decode failure, keep the text
          }
        }

        messages.add(ImportedMessage(
          role: role,
          content: item['content'] as String? ?? '',
          timestamp: timestamp,
          attachments: attachments,
        ));
      }

      if (messages.isEmpty) return null;

      return ChatImportResult(
        userName: 'User',
        characterName: 'Imported',
        createDate: messages.first.timestamp,
        messages: messages,
      );
    } catch (e, stack) {
      print('importFromThirdPartyArray error: $e');
      print('Stack: $stack');
      return null;
    }
  }
}

/// Result of importing a chat
class ChatImportResult {
  final String userName;
  final String characterName;
  final DateTime createDate;
  final String? authorNote;
  final int? authorNoteDepth;
  final bool? authorNoteEnabled;
  final List<ImportedMessage> messages;
  /// Raw kira_chronicle bundle (restored by the caller after import)
  final Map<String, dynamic>? chronicleData;

  ChatImportResult({
    required this.userName,
    required this.characterName,
    required this.createDate,
    this.authorNote,
    this.authorNoteDepth,
    this.authorNoteEnabled,
    required this.messages,
    this.chronicleData,
  });
}

/// Imported message data
class ImportedMessage {
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final List<String> swipes;
  final int currentSwipeIndex;
  final String? reasoning;
  final List<String>? reasoningSwipes;
  final String? characterId;
  final String? characterName;
  final List<ChatAttachment> attachments;

  ImportedMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.swipes = const [],
    this.currentSwipeIndex = 0,
    this.reasoning,
    this.reasoningSwipes,
    this.characterId,
    this.characterName,
    this.attachments = const [],
  });

  /// Convert to ChatMessage
  ChatMessage toChatMessage(String chatId, String id) {
    return ChatMessage(
      id: id,
      chatId: chatId,
      role: role,
      content: content,
      timestamp: timestamp,
      swipes: swipes.isEmpty ? [content] : swipes,
      currentSwipeIndex: currentSwipeIndex,
      reasoning: reasoning,
      reasoningSwipes: reasoningSwipes,
      characterId: characterId,
      characterName: characterName,
      attachments: attachments,
    );
  }
}
