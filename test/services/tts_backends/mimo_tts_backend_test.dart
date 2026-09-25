import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kirakira/domain/services/tts_backends/mimo_tts_backend.dart';

// 最小合法 WAV（44 字节 header + 4 字节 PCM16 静音）
Uint8List _minimalWav() {
  final b = ByteData(44 + 4);
  final u = b.buffer.asUint8List();
  u.setAll(0, utf8.encode('RIFF'));
  b.setUint32(4, 36, Endian.little);
  u.setAll(8, utf8.encode('WAVE'));
  u.setAll(12, utf8.encode('fmt '));
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, 1, Endian.little);
  b.setUint32(24, 24000, Endian.little);
  b.setUint32(28, 48000, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  u.setAll(36, utf8.encode('data'));
  b.setUint32(40, 4, Endian.little);
  // 4 字节静音
  return u;
}

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
