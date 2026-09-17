import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kirakira/core/logger/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/app.dart';
import 'package:kirakira/core/services/initialization_module.dart';
import 'package:kirakira/domain/providers/register_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 全局沉浸式模式：隐藏系统状态栏和导航栏，从边缘滑动临时呼出
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [],
  );
  // 系统栏样式：透明背景 + 亮色图标（呼出时显示）
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

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
