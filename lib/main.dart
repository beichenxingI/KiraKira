import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kirakira/core/logger/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/app.dart';
import 'package:kirakira/core/services/initialization_module.dart';
import 'package:kirakira/domain/providers/register_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global immersive mode: hide the system status and navigation bars,
  // revealed temporarily by an edge swipe
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [],
  );
  // System bar style: transparent background + light icons (shown when swiped out)
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

  // Raise the image cache cap to 200MB to reduce eviction with many characters
  PaintingBinding.instance.imageCache.maximumSizeBytes = 200 << 20;
  FlutterError.onError = (details) { KiraLogger().error('FLUTTER', details.exceptionAsString(), details.stack); };

  // Register LLM providers (must be before InitializationModule.create)
  registerLlmProviders();

  // Initialize module (creates all startup dependencies and Provider overrides)
  final initModule = await InitializationModule.create();
  KiraLogger().init();

  runApp(
    ProviderScope(
      overrides: initModule.overrides,
      child: const NativeTavernApp(),
    ),
  );
}
