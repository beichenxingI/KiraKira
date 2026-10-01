import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kirakira/domain/services/tts_model_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _MockPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  static Directory? _docsDir;
  static Directory? _tmpDir;

  @override
  Future<String?> getApplicationDocumentsPath() async =>
      (_docsDir ??= Directory.systemTemp.createTempSync('kira_tts_test')).path;

  @override
  Future<String?> getTemporaryPath() async =>
      (_tmpDir ??= Directory.systemTemp.createTempSync('kira_tts_tmp')).path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    PathProviderPlatform.instance = _MockPathProvider();
  });

  group('TtsModelEntry', () {
    test('toJson/fromJson 往返（含可选字段）', () {
      final entry = TtsModelEntry(
        name: 'vits-icefall-zh-aishell3',
        modelType: 'vits',
        modelPath: '/tmp/models/model.onnx',
        tokens: '/tmp/models/tokens.txt',
        lexicon: '/tmp/models/lexicon.txt',
        dictDir: '/tmp/models/dict',
        ruleFsts: '/tmp/models/rule.fst',
        sampleRate: 8000,
        numSpeakers: 174,
        importedAt: DateTime(2026, 9, 25),
      );
      final json = entry.toJson();
      final restored = TtsModelEntry.fromJson(json);

      expect(restored.name, entry.name);
      expect(restored.modelType, entry.modelType);
      expect(restored.modelPath, entry.modelPath);
      expect(restored.tokens, entry.tokens);
      expect(restored.lexicon, entry.lexicon);
      expect(restored.dictDir, entry.dictDir);
      expect(restored.sampleRate, 8000);
      expect(restored.numSpeakers, 174);
    });

    test('fromJson 缺省可选字段不崩', () {
      final restored = TtsModelEntry.fromJson({
        'name': 'melo',
        'modelType': 'vits',
        'modelPath': '/tmp/melo.onnx',
        'tokens': '/tmp/tokens.txt',
      });
      expect(restored.lexicon, isNull);
      expect(restored.voices, isNull);
      expect(restored.sampleRate, 16000);
      expect(restored.numSpeakers, 1);
    });

    test('modelSizeBytes：文件不存在返回 0', () {
      final entry = TtsModelEntry(
        name: 'x',
        modelType: 'vits',
        modelPath: '/nonexistent/model.onnx',
        tokens: '/nonexistent/tokens.txt',
        importedAt: DateTime.now(),
      );
      expect(entry.modelSizeBytes, 0);
    });
  });

  group('TtsModelService manifest（临时目录）', () {
    test('空清单返回空列表', () async {
      // loadManifest 在模型目录不存在/为空时不崩，返回空
      final manifest = await TtsModelService.instance.loadManifest();
      expect(manifest, isA<List<TtsModelEntry>>());
    });

    test('manifest.json 手工写入后可读回', () async {
      final dir = await TtsModelService.instance.getModelsDirectory();
      final manifestFile = File('${dir.path}/manifest.json');
      final entry = TtsModelEntry(
        name: 'test-model',
        modelType: 'vits',
        modelPath: '${dir.path}/test-model/model.onnx',
        tokens: '${dir.path}/test-model/tokens.txt',
        sampleRate: 16000,
        numSpeakers: 5,
        importedAt: DateTime.now(),
      );
      await manifestFile.writeAsString(jsonEncode([entry.toJson()]), flush: true);

      final manifest = await TtsModelService.instance.loadManifest();
      expect(manifest.any((e) => e.name == 'test-model'), isTrue);

      // 清理
      await manifestFile.delete();
    });
  });
}
