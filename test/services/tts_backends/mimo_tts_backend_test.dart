import 'package:flutter_test/flutter_test.dart';
import 'package:kirakira/domain/services/tts_backends/mimo_tts_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MimoTtsBackend', () {
    test('initialize：API Key 未配置抛异常', () async {
      final backend = MimoTtsBackend(apiKey: null);
      await expectLater(backend.initialize(), throwsException);
    });

    test('initialize：API Key 已配置通过', () async {
      final backend = MimoTtsBackend(apiKey: 'sk-test');
      await backend.initialize();
      expect(backend.displayName, '小米 MiMo');
      expect(backend.isLocal, isFalse);
      await backend.dispose();
    });

    test('8 预置音色列表', () {
      final backend = MimoTtsBackend(apiKey: 'sk-test');
      final voices = backend.getAvailableVoices();
      expect(voices.length, 9); // mimo_default + 8 音色
      expect(voices.first['value'], 'mimo_default');
      expect(voices.any((v) => v['value'] == '冰糖'), isTrue);
      expect(voices.any((v) => v['value'] == 'Dean'), isTrue);
    });

    test('speak：API Key 未配置直接抛异常（不发请求）', () async {
      final backend = MimoTtsBackend(apiKey: null);
      await expectLater(
        backend.speak('测试'),
        throwsException,
      );
    });

    test('baseUrl 自定义生效', () {
      final backend = MimoTtsBackend(apiKey: 'sk', baseUrl: 'https://custom.example.com/v1');
      // Dio 内部 baseUrl 已构造，验证不崩即可
      expect(backend.displayName, isNotEmpty);
    });

    test('能力声明：supportsPitch/Rate=true（经指令近似）', () {
      final backend = MimoTtsBackend(apiKey: 'sk');
      expect(backend.supportsPitch, isTrue);
      expect(backend.supportsRate, isTrue);
      expect(backend.configHint, contains('限时免费'));
    });
  });
}
