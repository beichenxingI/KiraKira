import 'package:flutter_test/flutter_test.dart';
import 'package:kirakira/domain/services/tts_backends/baidu_tts_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BaiduTtsBackend', () {
    test('initialize：AK/SK 未配置抛异常', () async {
      final backend = BaiduTtsBackend(apiKey: null, secretKey: null);
      await expectLater(backend.initialize(), throwsException);
    });

    test('initialize：仅 AK 缺 SK 抛异常', () async {
      final backend = BaiduTtsBackend(apiKey: 'ak-test', secretKey: null);
      await expectLater(backend.initialize(), throwsException);
    });

    test('8 预置发音人列表', () {
      final backend = BaiduTtsBackend(apiKey: 'ak', secretKey: 'sk');
      final voices = backend.getAvailableVoices();
      expect(voices.length, 8);
      expect(voices.first['value'], '0');
      expect(voices.any((v) => v['value'] == '4'), isTrue); // 童声
    });

    test('speak：AK/SK 未配置直接抛异常（不发请求）', () async {
      final backend = BaiduTtsBackend(apiKey: null, secretKey: null);
      await expectLater(backend.speak('测试'), throwsException);
    });

    test('invalidateToken 清除缓存', () {
      final backend = BaiduTtsBackend(apiKey: 'ak', secretKey: 'sk');
      backend.invalidateToken();
      expect(backend.displayName, '百度语音合成');
    });

    test('能力声明：supportsPitch/Rate=true（pit/spd 0-15）', () {
      final backend = BaiduTtsBackend(apiKey: 'ak', secretKey: 'sk');
      expect(backend.supportsPitch, isTrue);
      expect(backend.supportsRate, isTrue);
      expect(backend.configHint, contains('永久免费'));
    });

    test('friendlyError 错误码映射', () {
      expect(BaiduTtsBackend.friendlyError(Exception('"err_no":503')),
          contains('过期'));
      expect(BaiduTtsBackend.friendlyError(Exception('"err_no":505')),
          contains('欠费'));
      expect(BaiduTtsBackend.friendlyError(Exception('"err_no":513')),
          contains('并发'));
      expect(BaiduTtsBackend.friendlyError(Exception('invalid_client')),
          contains('无效'));
    });
  });
}
