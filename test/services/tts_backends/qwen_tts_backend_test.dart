import 'package:flutter_test/flutter_test.dart';
import 'package:kirakira/domain/services/tts_backends/qwen_tts_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QwenTtsBackend', () {
    test('initialize：API Key 未配置抛异常', () async {
      final backend = QwenTtsBackend(apiKey: null);
      await expectLater(backend.initialize(), throwsException);
    });

    test('initialize：API Key 已配置通过', () async {
      final backend = QwenTtsBackend(apiKey: 'sk-test');
      await backend.initialize();
      expect(backend.displayName, '阿里通义 TTS');
      expect(backend.isLocal, isFalse);
      await backend.dispose();
    });

    test('qwen 模型用 Qwen 音色列表（不支持 rate/pitch）', () {
      final backend = QwenTtsBackend(apiKey: 'sk', model: 'qwen3-tts-flash');
      final voices = backend.getAvailableVoices();
      expect(voices.any((v) => v['value'] == 'Cherry'), isTrue);
      expect(voices.any((v) => v['value'] == 'Rocky'), isTrue);
      expect(backend.supportsPitch, isFalse);
      expect(backend.supportsRate, isFalse);
    });

    test('cosyvoice 模型用 Cosy 音色列表（支持 rate/pitch）', () {
      final backend = QwenTtsBackend(
          apiKey: 'sk', model: 'cosyvoice-v3-flash');
      final voices = backend.getAvailableVoices();
      expect(voices.any((v) => v['value'] == 'longanyang'), isTrue);
      expect(voices.any((v) => v['value'] == 'loongbella_v3'), isTrue);
      expect(backend.supportsPitch, isTrue);
      expect(backend.supportsRate, isTrue);
    });

    test('speak：API Key 未配置直接抛异常（不发请求）', () async {
      final backend = QwenTtsBackend(apiKey: null);
      await expectLater(backend.speak('测试'), throwsException);
    });

    test('friendlyError 错误码映射', () {
      expect(QwenTtsBackend.friendlyError(Exception('HTTP 429 rate limit')),
          contains('频繁'));
      expect(QwenTtsBackend.friendlyError(Exception('403 FreeTierOnly')),
          contains('额度'));
      expect(QwenTtsBackend.friendlyError(Exception('Arrearage')),
          contains('欠费'));
      expect(QwenTtsBackend.friendlyError(Exception('error code: 418')),
          contains('不匹配'));
      expect(QwenTtsBackend.friendlyError(Exception('401 InvalidApiKey')),
          contains('无效'));
    });
  });
}
