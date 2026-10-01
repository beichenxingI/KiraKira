import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirakira/presentation/providers/image_gen_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [Phase 0.4] 生图 API 密钥迁移 secure storage + prefs 不落明文。
///
/// flutter_secure_storage 用 method channel mock：
/// channel 'plugins.it_nomads.com/flutter_secure_storage'，
/// read/write/delete/containsKey 传 {'key': key, 'options': ...}。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final secureStore = <String, String>{};

  setUp(() {
    secureStore.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        switch (call.method) {
          case 'read':
            return secureStore[call.arguments['key'] as String];
          case 'write':
            secureStore[call.arguments['key'] as String] =
                call.arguments['value'] as String;
            return null;
          case 'delete':
            secureStore.remove(call.arguments['key'] as String);
            return null;
          case 'containsKey':
            return secureStore.containsKey(call.arguments['key'] as String);
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
  });

  /// notifier 构造即异步 _loadSettings，轮询等待其落定。
  Future<void> waitForLoad(
    ProviderContainer container,
    bool Function() cond,
  ) async {
    for (var i = 0; i < 40; i++) {
      if (cond()) return;
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }

  test('旧明文 key 自动迁移：secure storage 写入，prefs 清除', () async {
    SharedPreferences.setMockInitialValues({
      'image_gen_settings': jsonEncode({
        'enabled': true,
        'provider': 'novelai',
        'apiKeys': {'novelai': 'nai_legacy_key'},
      }),
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await waitForLoad(container, () =>
        container.read(imageGenSettingsProvider).apiKeys['novelai'] ==
            'nai_legacy_key');

    final loaded = container.read(imageGenSettingsProvider);
    expect(loaded.apiKeys['novelai'], 'nai_legacy_key');
    // secure storage 已写入迁移后的密钥
    expect(secureStore['image_gen_apikeys'], isNotNull);
    expect(secureStore['image_gen_apikeys']!.contains('nai_legacy_key'), true);
    // prefs 明文已清除
    final prefs = await SharedPreferences.getInstance();
    final json =
        jsonDecode(prefs.getString('image_gen_settings')!) as Map<String, dynamic>;
    expect((json['apiKeys'] as Map).isEmpty, true);
  });

  test('setApiKey 写入 secure storage，prefs 不落明文', () async {
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    container.read(imageGenSettingsProvider.notifier).setApiKey('nai_new_key');
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final loaded = container.read(imageGenSettingsProvider);
    expect(loaded.apiKeys[loaded.provider.id], 'nai_new_key');
    final stored = secureStore['image_gen_apikeys'];
    expect(stored, isNotNull);
    expect(stored!.contains('nai_new_key'), true);
    // prefs JSON 无明文 key
    final prefs = await SharedPreferences.getInstance();
    final json =
        jsonDecode(prefs.getString('image_gen_settings')!) as Map<String, dynamic>;
    expect((json['apiKeys'] as Map).isEmpty, true);
    expect(json.containsKey('promptOptApiKey'), true);
    expect(json['promptOptApiKey'], isNull);
  });

  test('secure storage 已有 key 时优先读取，不重复迁移', () async {
    secureStore['image_gen_apikeys'] =
        jsonEncode({'openai': 'sk_secure_key'});
    SharedPreferences.setMockInitialValues({
      'image_gen_settings': jsonEncode({
        'provider': 'openai',
        'apiKeys': {'openai': 'sk_old_plain'},
      }),
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await waitForLoad(container, () =>
        container.read(imageGenSettingsProvider).apiKeys['openai'] ==
            'sk_secure_key');

    final loaded = container.read(imageGenSettingsProvider);
    expect(loaded.apiKeys['openai'], 'sk_secure_key');
    // secure storage 未被旧明文覆盖
    expect(secureStore['image_gen_apikeys']!.contains('sk_old_plain'), false);
  });

  test('promptOptApiKey 同样迁移到 secure storage', () async {
    SharedPreferences.setMockInitialValues({
      'image_gen_settings': jsonEncode({
        'provider': 'openai',
        'promptOptApiKey': 'sk_opt_legacy',
      }),
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await waitForLoad(container, () =>
        container.read(imageGenSettingsProvider).promptOptApiKey ==
            'sk_opt_legacy');

    expect(secureStore['image_gen_promptopt_apikey'], 'sk_opt_legacy');
    final prefs = await SharedPreferences.getInstance();
    final json =
        jsonDecode(prefs.getString('image_gen_settings')!) as Map<String, dynamic>;
    expect(json['promptOptApiKey'], isNull);
  });
}
