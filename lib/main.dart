import 'package:flutter/material.dart';
import 'package:kirakira/core/logger/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/app.dart';
import 'package:kirakira/core/services/initialization_module.dart';
import 'package:kirakira/domain/providers/register_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 图片缓存上限调到200MB，角色多时减少淘汰频率
  PaintingBinding.instance.imageCache.maximumSizeBytes = 200 << 20;
  FlutterError.onError = (details) { KiraLogger().error('FLUTTER', details.exceptionAsString(), details.stack); };

  // Register LLM providers (must be before InitializationModule.create)
  registerLlmProviders();

  // Initialize module（封装所有启动依赖创建与 Provider 覆盖）
  final initModule = await InitializationModule.create();
  KiraLogger().init();

  runApp(
    ProviderScope(
      overrides: initModule.overrides,
      child: const NativeTavernApp(),
    ),
  );
}
