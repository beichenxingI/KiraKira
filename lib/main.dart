import 'package:flutter/material.dart';
import 'package:kirakira/core/logger/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirakira/app.dart';
import 'package:kirakira/core/services/initialization_service.dart';
import 'package:kirakira/data/repositories/character_repository.dart';
import 'package:kirakira/data/repositories/chat_repository.dart';
import 'package:kirakira/data/repositories/world_info_repository.dart';
import 'package:kirakira/domain/services/llm_service.dart';
import 'package:kirakira/domain/services/import_service.dart';
import 'package:kirakira/presentation/providers/settings_providers.dart';
import 'package:kirakira/presentation/screens/import/import_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) { KiraLogger().error('FLUTTER', details.exceptionAsString(), details.stack); };
  
  // Initialize core services
  final initData = await InitializationService.initialize();
  KiraLogger().init();
  
  // Get shared preferences
  final prefs = await SharedPreferences.getInstance();
  
  // Create repositories
  final database = initData.database;
  final characterRepo = CharacterRepository(database, initData.dataPath);
  final chatRepo = ChatRepository(database);
  final worldInfoRepo = WorldInfoRepository(database);
  
  // Create services
  final llmService = LLMService();
  final importService = ImportService(initData.dataPath);
  
  runApp(
    ProviderScope(
      overrides: [
        // Database
        databaseProvider.overrideWithValue(database),
        
        // Repositories
        characterRepositoryProvider.overrideWithValue(characterRepo),
        chatRepositoryProvider.overrideWithValue(chatRepo),
        worldInfoRepositoryProvider.overrideWithValue(worldInfoRepo),
        
        // Services
        llmServiceProvider.overrideWithValue(llmService),
        importServiceProvider.overrideWithValue(importService),
        
        // Shared preferences
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const NativeTavernApp(),
    ),
  );
}