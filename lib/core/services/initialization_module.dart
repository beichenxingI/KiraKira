import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirakira/core/services/initialization_service.dart';
import 'package:kirakira/data/database/database.dart';
import 'package:kirakira/data/repositories/character_repository.dart';
import 'package:kirakira/data/repositories/chat_repository.dart';
import 'package:kirakira/data/repositories/world_info_repository.dart';
import 'package:kirakira/domain/services/import_service.dart';
import 'package:kirakira/domain/services/llm_service.dart';
import 'package:kirakira/domain/services/variables_service.dart';
import 'package:kirakira/presentation/providers/settings_providers.dart';
import 'package:kirakira/presentation/screens/import/import_screen.dart';

/// Initialization module: creates dependencies and builds the Provider
/// overrides used at app startup.
///
/// Design constraints:
/// - Takes over only the Provider set that `main.dart` previously overrode;
///   behavior is unchanged.
/// - Repository Providers already implemented in their own files
///   (persona/group/tag/llmConfig/bookmark) are not taken over, to avoid
///   changing existing behavior.
/// - `api_credential_repository` uses static FlutterSecureStorage storage and
///   needs no db injection.
/// - `worldInfoRepositoryProvider` has two definitions (the UnimplementedError
///   version in the repository file and the self-implemented version in
///   world_info_providers); unifying them is medium risk and deferred.
class InitializationModule {
  final SharedPreferences prefs;
  final AppDatabase database;
  final String dataPath;

  // Repositories (only the three main.dart originally overrode)
  late final CharacterRepository characterRepository;
  late final ChatRepository chatRepository;
  late final WorldInfoRepository worldInfoRepository;

  // Services
  late final EJSRenderRegistry ejsRegistry;
  late final LLMService llmService;
  late final ImportService importService;

  // Provider overrides
  late final List<Override> overrides;

  InitializationModule._({
    required this.prefs,
    required this.database,
    required this.dataPath,
  }) {
    _createRepositories();
    _createServices();
    _buildOverrides();
  }

  /// Full initialization (used by main.dart).
  static Future<InitializationModule> create() async {
    final prefs = await SharedPreferences.getInstance();
    final initData = await InitializationService.initialize();
    // Load global variables at startup so a write before loading can no
    // longer overwrite the save with an empty table
    await VariablesService.instance.initialize();
    return InitializationModule._(
      prefs: prefs,
      database: initData.database,
      dataPath: initData.dataPath,
    );
  }

  /// Test factory: injects mock dependencies.
  static InitializationModule forTesting({
    required SharedPreferences prefs,
    required AppDatabase database,
    required String dataPath,
  }) {
    return InitializationModule._(
      prefs: prefs,
      database: database,
      dataPath: dataPath,
    );
  }

  void _createRepositories() {
    characterRepository = CharacterRepository(database, dataPath);
    chatRepository = ChatRepository(database);
    worldInfoRepository = WorldInfoRepository(database);
  }

  void _createServices() {
    ejsRegistry = EJSRenderRegistry();
    llmService = LLMService(ejsRenderer: RegistryEJSRenderer(ejsRegistry));
    importService = ImportService(dataPath);
  }

  void _buildOverrides() {
    overrides = [
      // Database
      databaseProvider.overrideWithValue(database),
      // Repositories
      characterRepositoryProvider.overrideWithValue(characterRepository),
      chatRepositoryProvider.overrideWithValue(chatRepository),
      worldInfoRepositoryProvider.overrideWithValue(worldInfoRepository),
      // Services
      llmServiceProvider.overrideWithValue(llmService),
      ejsRenderRegistryProvider.overrideWithValue(ejsRegistry),
      importServiceProvider.overrideWithValue(importService),
      // Shared preferences
      sharedPreferencesProvider.overrideWithValue(prefs),
    ];
  }
}
