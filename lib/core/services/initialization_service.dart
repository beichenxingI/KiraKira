import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kirakira/data/database/database.dart';
import 'package:kirakira/data/repositories/chat_repository.dart';
import 'package:kirakira/data/repositories/world_info_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

/// Provider for database
final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

/// Initialization data returned after startup
class InitializationData {
  final AppDatabase database;
  final String dataPath;

  InitializationData({
    required this.database,
    required this.dataPath,
  });
}

/// Service responsible for initializing the app on startup
class InitializationService {
  static bool _initialized = false;
  static InitializationData? _initData;
  static const String _builtInWorldInfosLoadedKey = 'builtin_worldinfos_loaded';
  
  /// Initialize all core services
  static Future<InitializationData> initialize() async {
    if (_initialized && _initData != null) {
      return _initData!;
    }
    
    debugPrint('🚀 Initializing KiraKira...');
    
    // Get data directory
    final appDir = await getApplicationDocumentsDirectory();
    final dataPath = '${appDir.path}/KiraKira';
    
    // Ensure directories exist
    await _ensureDirectories(dataPath);
    
    // Initialize database
    final database = AppDatabase();
    
    _initData = InitializationData(
      database: database,
      dataPath: dataPath,
    );
    
    // Load built-in world infos
    await _loadBuiltInWorldInfos(database);

    // [空会话] 启动清扫:删除从未有过用户消息的会话
    //(旧版本遗留 + 进程被杀没走退出丢弃的临时会话),失败不阻断启动
    try {
      final purged = await ChatRepository(database).purgeEmptyChats();
      if (purged > 0) {
        debugPrint('[空会话] 启动清扫:已删除 $purged 个无用户消息的会话');
      }
    } catch (e) {
      debugPrint('[空会话] 启动清扫失败(跳过): $e');
    }

    _initialized = true;
    debugPrint('✅ KiraKira initialized successfully');
    debugPrint('📁 Data path: $dataPath');
    
    return _initData!;
  }

  /// Load built-in world infos from assets
  static Future<void> _loadBuiltInWorldInfos(AppDatabase database) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final worldInfosLoaded = prefs.getBool(_builtInWorldInfosLoadedKey) ?? false;
      
      if (worldInfosLoaded) {
        debugPrint('📚 Built-in world infos already loaded');
        return;
      }
      
      debugPrint('📚 Loading built-in world infos...');
      final repo = WorldInfoRepository(database);
      await repo.loadBuiltInWorldInfos();
      
      // Mark as loaded
      await prefs.setBool(_builtInWorldInfosLoadedKey, true);
      debugPrint('✅ Built-in world infos loaded successfully');
    } catch (e) {
      debugPrint('⚠️ Failed to load built-in world infos: $e');
    }
  }
  
  /// Ensure all required directories exist
  static Future<void> _ensureDirectories(String basePath) async {
    final directories = [
      'characters',
      'chats',
      'worlds',
      'backgrounds',
      'avatars',
      'assets',
      'thumbnails',
      'models',
      'exports',
    ];
    
    for (final dir in directories) {
      final directory = Directory('$basePath/$dir');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
        debugPrint('📁 Created directory: ${directory.path}');
      }
    }
  }
  
  /// Get the data path (must be initialized first)
  static String get dataPath {
    if (_initData == null) {
      throw StateError('InitializationService not initialized');
    }
    return _initData!.dataPath;
  }
  
  /// Get the database (must be initialized first)
  static AppDatabase get database {
    if (_initData == null) {
      throw StateError('InitializationService not initialized');
    }
    return _initData!.database;
  }
}