import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kirakira/core/services/initialization_service.dart';
import 'package:kirakira/data/database/database.dart';
import 'package:kirakira/data/repositories/character_repository.dart';
import 'package:kirakira/data/repositories/chat_repository.dart';
import 'package:kirakira/data/repositories/world_info_repository.dart';
import 'package:kirakira/domain/services/import_service.dart';
import 'package:kirakira/domain/services/llm_service.dart';
import 'package:kirakira/presentation/providers/settings_providers.dart';
import 'package:kirakira/presentation/screens/import/import_screen.dart';

/// 初始化模块：封装应用启动时的依赖创建与 Provider 覆盖。
///
/// 设计原则（阶段1-1.1）：
/// - 仅接管 `main.dart` 原有 override 的 Provider 集合，保持功能不变。
/// - 不强行接管已在各自文件中自实现的 Repository Provider（persona/group/tag/
///   llmConfig/bookmark），避免破坏现有行为。
/// - `api_credential_repository` 走 FlutterSecureStorage 静态存储，无需 db 注入，
///   手册将其计入 9 个 Repository Provider 属假设偏差，已记入执行报告。
/// - `worldInfoRepositoryProvider` 存在两处定义（repository 文件的 UnimplementedError 版
///   与 world_info_providers 文件的自实现版），统一属中风险，留待遗留清单处理。
class InitializationModule {
  final SharedPreferences prefs;
  final AppDatabase database;
  final String dataPath;

  // Repositories（仅 main.dart 原本 override 的三个）
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

  /// 完整初始化（用于 main.dart）。
  static Future<InitializationModule> create() async {
    final prefs = await SharedPreferences.getInstance();
    final initData = await InitializationService.initialize();
    return InitializationModule._(
      prefs: prefs,
      database: initData.database,
      dataPath: initData.dataPath,
    );
  }

  /// 测试用工厂：可注入 Mock 依赖。
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
