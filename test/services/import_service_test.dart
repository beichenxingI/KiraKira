import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirakira/domain/services/import_service.dart';

/// [Phase 0.1/0.2] character_book 字典 entries 导入 + scanDepth int 解析 + round-trip。
///
/// path_provider platform channel mock：
/// _saveAvatar 经 PathUtils.toRelativePath 调 getApplicationDocumentsDirectory()。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late ImportService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kirakira_import_test');
    service = ImportService(tempDir.path);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return null;
      },
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Map<String, dynamic> entryJson(int id, {bool enabled = true}) => {
        'id': id,
        'keys': ['key_$id'],
        'secondary_keys': <String>[],
        'content': 'content of entry $id',
        'comment': 'comment $id',
        'enabled': enabled,
        'insertion_order': 10 + id,
        'case_sensitive': false,
        'name': 'entry$id',
        'priority': 10,
        'constant': false,
        'selective': false,
        'position': 0,
        'extensions': <String, dynamic>{},
      };

  Map<String, dynamic> v3Card({required dynamic entries, dynamic scanDepth}) => {
        'spec': 'chara_card_v3',
        'spec_version': '3.0',
        'data': {
          'name': 'Test Char',
          'description': 'A test character',
          'personality': 'brave',
          'scenario': 'test scenario',
          'first_mes': 'Hello!',
          'alternate_greetings': ['Hi again', 'Yo'],
          'mes_example': '<START>\n{{user}}: hi\n{{char}}: hello',
          'system_prompt': 'You are Test Char',
          'post_history_instructions': '',
          'creator_notes': 'test notes',
          'tags': ['test'],
          'creator': 'tester',
          'character_version': '1.0',
          'extensions': <String, dynamic>{},
          'character_book': {
            'name': 'Test Book',
            'description': 'book desc',
            if (scanDepth != null) 'scan_depth': scanDepth,
            'token_budget': 1024,
            'recursive_scanning': false,
            'extensions': <String, dynamic>{},
            'entries': entries,
          },
        },
      };

  /// 构造带 tEXt(chara, base64) chunk 的最小 PNG。
  /// parser 不校验 PNG 签名与 CRC，但测试数据按标准形态构造。
  Uint8List buildCardPng(Map<String, dynamic> card, {String keyword = 'chara'}) {
    final value = base64.encode(utf8.encode(jsonEncode(card)));
    final textData = <int>[...utf8.encode(keyword), 0, ...utf8.encode(value)];
    final len = textData.length;
    return Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
      (len >> 24) & 0xFF, (len >> 16) & 0xFF, (len >> 8) & 0xFF, len & 0xFF,
      ...utf8.encode('tEXt'),
      ...textData,
      0, 0, 0, 0, // CRC (parser 不校验)
      0, 0, 0, 0, // IEND length
      ...utf8.encode('IEND'),
      0xAE, 0x42, 0x60, 0x82, // IEND CRC
    ]);
  }

  test('数组 entries 导入成功，词条数正确', () async {
    final card = v3Card(entries: [entryJson(0), entryJson(1, enabled: false)]);
    final imported = await service.importFromPngBytes(buildCardPng(card));

    expect(imported.name, 'Test Char');
    expect(imported.alternateGreetings, ['Hi again', 'Yo']);
    expect(imported.characterBook, isNotNull);
    expect(imported.characterBook!.entries.length, 2);
    expect(imported.characterBook!.entries[0].keys, ['key_0']);
    expect(imported.characterBook!.entries[0].content, 'content of entry 0');
    // enabled=false 且无 disable → 禁用
    expect(imported.characterBook!.entries[1].enabled, false);
  });

  test('字典 entries 导入成功，词条数正确([0.1]修复：不再静默丢条)', () async {
    // 某些 ST 导出/旧卡的 character_book.entries 是 Map(id → entry) 形态
    final dictEntries = {
      '0': entryJson(0),
      '1': entryJson(1),
      '2': entryJson(2),
    };
    final card = v3Card(entries: dictEntries);
    final imported = await service.importFromPngBytes(buildCardPng(card));

    expect(imported.characterBook, isNotNull);
    expect(imported.characterBook!.entries.length, 3);
    expect(imported.characterBook!.entries[0].keys, ['key_0']);
    expect(imported.characterBook!.entries[2].content, 'content of entry 2');
  });

  test('scan_depth int 正确保留([0.2])', () async {
    final card = v3Card(entries: [entryJson(0)], scanDepth: 5);
    final imported = await service.importFromPngBytes(buildCardPng(card));

    expect(imported.characterBook!.scanDepth, 5);
  });

  test('scan_depth 未指定时为 null（不再默认 true）', () async {
    final card = v3Card(entries: [entryJson(0)]);
    final imported = await service.importFromPngBytes(buildCardPng(card));

    expect(imported.characterBook!.scanDepth, isNull);
  });

  test('scan_depth 旧 bool 卡兼容：true→1, false→0([0.2])', () async {
    final cardTrue = v3Card(entries: [entryJson(0)], scanDepth: true);
    final importedTrue = await service.importFromPngBytes(buildCardPng(cardTrue));
    expect(importedTrue.characterBook!.scanDepth, 1);

    final cardFalse = v3Card(entries: [entryJson(0)], scanDepth: false);
    final importedFalse = await service.importFromPngBytes(buildCardPng(cardFalse));
    expect(importedFalse.characterBook!.scanDepth, 0);
  });

  test('round-trip: 导入→导出→再导入无数据丢失', () async {
    final card = v3Card(
      entries: [entryJson(0), entryJson(1, enabled: false)],
      scanDepth: 5,
    );
    final imported = await service.importFromPngBytes(buildCardPng(card));
    expect(imported.characterBook!.entries.length, 2);

    // 导出（avatarData=null 用占位 PNG + 嵌入 chara chunk）
    final exported = await service.exportToPng(imported, null);
    final reimported = await service.importFromPngBytes(exported);

    expect(reimported.name, imported.name);
    expect(reimported.description, imported.description);
    expect(reimported.firstMessage, imported.firstMessage);
    expect(reimported.alternateGreetings, imported.alternateGreetings);
    expect(reimported.exampleMessages, imported.exampleMessages);
    expect(reimported.systemPrompt, imported.systemPrompt);
    expect(reimported.characterBook, isNotNull);
    expect(reimported.characterBook!.entries.length, 2);
    expect(reimported.characterBook!.entries[0].keys, imported.characterBook!.entries[0].keys);
    expect(reimported.characterBook!.entries[1].enabled, false);
    expect(reimported.characterBook!.scanDepth, 5);
  });

  test('导出 JSON 含 alternate_greetings 与 character_book', () async {
    final card = v3Card(entries: [entryJson(0)], scanDepth: 3);
    final imported = await service.importFromPngBytes(buildCardPng(card));
    final json = jsonDecode(service.exportToJson(imported)) as Map<String, dynamic>;

    final data = json['data'] as Map<String, dynamic>;
    expect(data['alternate_greetings'], ['Hi again', 'Yo']);
    expect(data['character_book'], isNotNull);
    final book = data['character_book'] as Map<String, dynamic>;
    expect((book['entries'] as List).length, 1);
    expect(book['scan_depth'], 3);
  });

  test('AICC-Chat 卡(spec=aicc_card)导入成功[Bastet结构化字段修复]', () async {
    // Bastet.aicc.png 同构：aicharactercards.com 的 AICC-Chat 格式(Rin Card Forge 导出)
    final card = {
      'spec': 'aicc_card',
      'spec_version': '1.0',
      'id': '29aa91ee-test',
      'data': {
        'name': 'Bastet',
        'general_description': 'Egyptian Goddess of Home',
        'appearance': 'cat-headed woman',
        'personality': {
          'core': 'Creature of comfort',
          'behavior_rules': ['Expects worship', 'Curious'],
          'speech_style': {
            'tone': 'Regal',
            'verbosity': 'high',
            'format': 'Dialogue in quotes',
            'patterns': ['We/Us royal we'],
          },
        },
        'background_history': 'Millennia ago',
        'world_setting_context': 'Museum manifestation',
        'dialogue': {
          'greetings': ['Greeting 0', 'Greeting 1', 'Greeting 2'],
          'dialogue_examples': ['{{char}}: ex1', '{{char}}: ex2'],
          'group_only_greetings': <String>[],
        },
        'prompts': {
          'system_prompt': '',
          'post_history_instructions': '',
          'depth_prompt': {'text': '', 'depth': 4, 'role': 'system'},
        },
        'world': {'worldbook_name': '', 'worldbook_entries': []},
        'metadata': {
          'card_format': 'AICC-Chat',
          'char_ui_name': '',
          'creator': 'tester',
          'notes': 'AICC notes',
          'version': '1.0',
          'tags': <String>[],
          'features': {'aicc-site-card-id': 'AICC-1'},
        },
      },
      'aicc_id': '3f3fee06-test',
      'aicc_version': {'id': 2955, 'number': 1},
    };
    final imported = await service.importFromPngBytes(buildCardPng(card));

    expect(imported.name, 'Bastet');
    expect(imported.description, 'Egyptian Goddess of Home');
    expect(imported.scenario, 'Museum manifestation');
    // personality 结构化 Map → 可读文本(含 core/behavior_rules/speech_style)
    expect(imported.personality, contains('Creature of comfort'));
    expect(imported.personality, contains('Expects worship'));
    expect(imported.personality, contains('Speech style'));
    // greetings[0] → first_mes, greetings[1..] → alternate_greetings
    expect(imported.firstMessage, 'Greeting 0');
    expect(imported.alternateGreetings, ['Greeting 1', 'Greeting 2']);
    // dialogue_examples → mes_example(<START> 分隔)
    expect(imported.exampleMessages, contains('<START>'));
    expect(imported.exampleMessages, contains('{{char}}: ex1'));
    // metadata → creator/notes/version
    expect(imported.creator, 'tester');
    expect(imported.creatorNotes, 'AICC notes');
    expect(imported.version, '1.0');
    // AICC 专有字段透传 extensions['aicc']
    final aiccExt = imported.extensions['aicc'] as Map<String, dynamic>;
    expect(aiccExt['spec'], 'aicc_card');
    expect(aiccExt['appearance'], 'cat-headed woman');
    expect(aiccExt['depth_prompt'], isNotNull);
    expect(aiccExt['aicc_id'], '3f3fee06-test');
  });

  test('V3 卡 personality 为 Map 时 stringify 不炸[AICC兼容]', () async {
    final card = v3Card(entries: [entryJson(0)]);
    (card['data'] as Map)['personality'] = {'core': 'brave', 'quirks': ['x']};
    final imported = await service.importFromPngBytes(buildCardPng(card));
    expect(imported.personality, contains('brave'));
  });

  test('tags String 逗号分隔转数组[AICC兼容]', () async {
    final card = v3Card(entries: [entryJson(0)]);
    (card['data'] as Map)['tags'] = 'fantasy, magic';
    final imported = await service.importFromPngBytes(buildCardPng(card));
    expect(imported.tags, ['fantasy', 'magic']);
  });
}
