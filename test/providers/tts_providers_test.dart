import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirakira/presentation/providers/tts_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [Phase 0.5] autoPlay 配置持久化 + ttsSpeakProvider 触发条件。
///
/// flutter_tts 平台 channel mock（channel 'flutter_tts'）：
/// 所有 invokeMethod 安全返回，避免测试环境 MissingPluginException。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async {
        switch (call.method) {
          case 'getVoices':
          case 'getLanguages':
            return <dynamic>[];
          default:
            return 1;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
  });

  Future<void> waitFor(bool Function() cond) async {
    for (var i = 0; i < 40; i++) {
      if (cond()) return;
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }

  test('autoPlay 配置持久化往返：setAutoPlay → prefs → 新 notifier 恢复', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(ttsSettingsProvider.notifier).setAutoPlay(true);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final prefs = await SharedPreferences.getInstance();
    final json =
        jsonDecode(prefs.getString('tts_settings')!) as Map<String, dynamic>;
    expect(json['autoPlay'], true);

    // 新 notifier 读取恢复 autoPlay
    final container2 = ProviderContainer();
    addTearDown(container2.dispose);
    await waitFor(() => container2.read(ttsSettingsProvider).autoPlay);
    expect(container2.read(ttsSettingsProvider).autoPlay, true);
  });

  test('autoPlay 默认 false（未开启不朗读）', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(container.read(ttsSettingsProvider).autoPlay, false);
  });

  test('ttsSpeakProvider: enabled=false 早退，不触发朗读', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final service = container.read(ttsServiceProvider);
    var started = false;
    service.onStart = () => started = true;

    final speak = container.read(ttsSpeakProvider);
    await speak('测试文本');

    expect(started, false);
    expect(container.read(ttsSpeakingProvider), false);
  });

  test('ttsSpeakProvider: enabled=true 走完整朗读链路并复位状态', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final service = container.read(ttsServiceProvider);
    var started = false;
    service.onStart = () => started = true;

    container.read(ttsSettingsProvider.notifier).setEnabled(true);
    // 等 setEnabled 触发的 _saveSettings 异步落定，避免 ttsSpeakProvider 依赖在
    // closure 捕获后再次失效（riverpod ref-outdated 断言）
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final speak = container.read(ttsSpeakProvider);
    await speak('测试文本');

    expect(started, true);
    expect(container.read(ttsSpeakingProvider), false);
  });
}
