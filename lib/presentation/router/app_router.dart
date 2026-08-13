import 'package:flutter/material.dart';
import 'package:kirakira/core/logger/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kirakira/presentation/screens/home/home_screen.dart';
import 'package:kirakira/presentation/screens/splash/splash_screen.dart';
import 'package:kirakira/presentation/screens/main_page/main_page.dart';
import 'package:kirakira/presentation/screens/settings/home_appearance_screen.dart';
import 'package:kirakira/presentation/screens/character/character_list_screen.dart';
import 'package:kirakira/presentation/screens/character/character_detail_screen.dart';
import 'package:kirakira/presentation/screens/character_editor/character_editor_screen.dart';
import 'package:kirakira/presentation/screens/character/character_regex_screen.dart';
import 'package:kirakira/presentation/screens/settings/settings_screen.dart';
import 'package:kirakira/presentation/screens/settings/prompt_manager_screen.dart';
import 'package:kirakira/presentation/screens/settings/advanced_settings_screen.dart';
import 'package:kirakira/presentation/screens/ai_config/llm_test_screen.dart';
import 'package:kirakira/presentation/screens/ai_config/llm_config_list_screen.dart';
import 'package:kirakira/presentation/screens/settings/background_settings_screen.dart';
import 'package:kirakira/presentation/screens/settings/theme_settings_screen.dart';
import 'package:kirakira/presentation/screens/settings/statistics_screen.dart';
import 'package:kirakira/presentation/screens/settings/ai_presets_screen.dart';
import 'package:kirakira/presentation/screens/settings/sprite_settings_screen.dart';
import 'package:kirakira/presentation/screens/settings/tts_settings_screen.dart';
import 'package:kirakira/presentation/screens/settings/stt_settings_screen.dart';
import 'package:kirakira/presentation/screens/settings/translation_settings_screen.dart';
import 'package:kirakira/presentation/screens/settings/image_gen_settings_screen.dart';
import 'package:kirakira/presentation/screens/settings/regex_settings_screen.dart';
import 'package:kirakira/presentation/screens/settings/variables_settings_screen.dart';
import 'package:kirakira/presentation/screens/settings/logit_bias_settings_screen.dart';
import 'package:kirakira/presentation/screens/settings/cfg_scale_settings_screen.dart';
import 'package:kirakira/presentation/screens/settings/tokenizer_settings_screen.dart';
import 'package:kirakira/presentation/screens/settings/vector_storage_settings_screen.dart';
import 'package:kirakira/presentation/widgets/chat/logprobs_panel.dart';
import 'package:kirakira/presentation/screens/ai_config/ai_config_screen.dart';
import 'package:kirakira/presentation/screens/import/import_screen.dart';
import 'package:kirakira/presentation/screens/personas/personas_screen.dart';
import 'package:kirakira/presentation/screens/world_info/world_info_screen.dart';
import 'package:kirakira/presentation/screens/groups/groups_screen.dart';
import 'package:kirakira/presentation/screens/groups/group_detail_screen.dart';
import 'package:kirakira/presentation/screens/tags/tags_screen.dart';
import 'package:kirakira/presentation/widgets/common/app_shell.dart';
import 'package:kirakira/presentation/screens/chat/webview_chat_stage.dart';
import 'package:kirakira/presentation/screens/settings/geek_dashboard_screen.dart';
import 'package:kirakira/presentation/screens/settings/mvu_settings_screen.dart';

/// Route paths
import '../screens/ai_config/model_detection_screen.dart';

abstract class AppRoutes {
  static const home = '/';
  static const splash = '/splash';
  static const characters = '/characters';
  static const characterDetail = '/characters/:id';
  static const characterCreate = '/characters/new';
  static const characterEdit = '/characters/:id/edit';
  static const chats = '/chats';
  static const chat = '/chat/:id';
  static const settings = '/settings';
  static const aiConfig = '/ai-config';
  static const promptManager = '/prompt-manager';
  static const advancedSettings = '/advanced-settings';
  static const backgroundSettings = '/background-settings';
  static const homeAppearance = '/home-appearance';
  static const themeSettings = '/theme-settings';
  static const statistics = '/statistics';
  static const advanced = '/advanced';
  static const chatStatistics = '/chat/:id/statistics';
  static const aiPresets = '/ai-presets';
  static const import_ = '/import';
  static const personas = '/personas';
  static const worldInfo = '/world-info';
  static const groups = '/groups';
  static const groupDetail = '/groups/:id';
  static const tags = '/tags';
  static const spriteSettings = '/sprite-settings';
  static const characterSprites = '/characters/:id/sprites';
  static const characterRegex = '/characters/:id/regex';
  static const ttsSettings = '/tts-settings';
  static const sttSettings = '/stt-settings';
  static const translationSettings = '/translation-settings';
  static const imageGenSettings = '/image-gen-settings';
  static const regexSettings = '/regex-settings';
  static const variablesSettings = '/variables-settings';
  static const mvuSettings = '/mvu-settings';
  static const logitBiasSettings = '/logit-bias-settings';
  static const cfgScaleSettings = '/cfg-scale-settings';
  static const logprobsSettings = '/logprobs-settings';
  static const tokenizerSettings = '/tokenizer-settings';
  static const vectorStorageSettings = '/vector-storage-settings';
  static const llmTest = '/llm-test';
  static const llmConfigList = '/llm-config-list';
  static const modelDetection = '/model-detection';
  static const webviewStage = '/webview-stage/:id';
}

/// Navigation keys for nested navigation
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();


class _NavObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    final name = route.settings.name ?? route.runtimeType.toString();
    final prev = previousRoute?.settings.name ?? 'none';
    KiraLogger().route('PUSH: $prev -> $name');
  }
  @override
  void didPop(Route route, Route? previousRoute) {
    final name = route.settings.name;
    KiraLogger().route('POP: $name');
  }
  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    final n = newRoute?.settings.name ?? '?';
    final o = oldRoute?.settings.name ?? '?';
    KiraLogger().route('REPLACE:  -> ');
  }
}
/// tab 页转场：交叉淡入 + 轻微上浮，250ms，顺滑不拖沓。
CustomTransitionPage<void> _buildTabPage(LocalKey key, Widget child) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: child,
      );
    },
  );
}

/// App router provider
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    observers: [_NavObserver()],
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SplashScreen(),
      ),
      // Main shell with bottom navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.chats,
            name: 'chats',
            pageBuilder: (context, state) => _buildTabPage(state.pageKey, const HomeScreen()),
          ),
          GoRoute(
            path: AppRoutes.home,
            name: 'home',
            pageBuilder: (context, state) => _buildTabPage(state.pageKey, const MainPage()),
          ),
          GoRoute(
            path: AppRoutes.characters,
            name: 'characters',
            pageBuilder: (context, state) => _buildTabPage(state.pageKey, const CharacterListScreen()),
          ),
          GoRoute(
            path: AppRoutes.aiConfig,
            name: 'aiConfig',
            pageBuilder: (context, state) => _buildTabPage(state.pageKey, const AIConfigScreen()),
          ),
          GoRoute(
            path: AppRoutes.settings,
            name: 'settings',
            pageBuilder: (context, state) => _buildTabPage(state.pageKey, const SettingsScreen()),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.worldInfo,
        name: 'worldInfo',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final cid = state.uri.queryParameters['characterId'];
          final isGlobal = state.uri.queryParameters['isGlobal'] == 'true';
          return WorldInfoScreen(characterId: cid, isGlobal: isGlobal);
        },
      ),
      GoRoute(
        path: AppRoutes.characterRegex,
        name: 'characterRegex',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CharacterRegexScreen(characterId: id);
        },
      ),
      // Full-screen routes (outside shell)
      // NOTE: More specific routes must come BEFORE wildcard routes
      // /characters/new must come before /characters/:id
      GoRoute(
        path: AppRoutes.characterCreate,
        name: 'characterCreate',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CharacterEditorScreen(),
      ),
      GoRoute(
        path: AppRoutes.characterEdit,
        name: 'characterEdit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CharacterEditorScreen(characterId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.characterDetail,
        name: 'characterDetail',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CharacterDetailScreen(characterId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.webviewStage,
        name: 'webviewStage',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return WebViewChatStage(chatId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.chat,
        name: 'chat',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return WebViewChatStage(chatId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.import_,
        name: 'import',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ImportScreen(),
      ),
      GoRoute(
        path: AppRoutes.personas,
        name: 'personas',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PersonasScreen(),
      ),
      GoRoute(
        path: AppRoutes.promptManager,
        name: 'promptManager',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PromptManagerScreen(),
      ),
      GoRoute(
        path: AppRoutes.advancedSettings,
        name: 'advancedSettings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AdvancedSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.homeAppearance,
        name: 'homeAppearance',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const HomeAppearanceScreen(),
      ),
      GoRoute(
        path: AppRoutes.backgroundSettings,
        name: 'backgroundSettings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BackgroundSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.themeSettings,
        name: 'themeSettings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ThemeSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.advanced,
        name: 'advanced',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const GeekDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.statistics,
        name: 'statistics',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const StatisticsScreen(),
      ),
     GoRoute(
        path: AppRoutes.mvuSettings,
        name: 'mvuSettings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MvuSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.aiPresets,
        name: 'aiPresets',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AIPresetsScreen(),
      ),
      GoRoute(
        path: AppRoutes.chatStatistics,
        name: 'chatStatistics',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return StatisticsScreen(chatId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.groups,
        name: 'groups',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const GroupsScreen(),
      ),
      GoRoute(
        path: AppRoutes.groupDetail,
        name: 'groupDetail',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return GroupDetailScreen(groupId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.tags,
        name: 'tags',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TagsScreen(),
      ),
      GoRoute(
        path: AppRoutes.spriteSettings,
        name: 'spriteSettings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SpriteSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.characterSprites,
        name: 'characterSprites',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final name = state.uri.queryParameters['name'] ?? 'Character';
          return CharacterSpritesScreen(characterId: id, characterName: name);
        },
      ),
      GoRoute(
        path: AppRoutes.ttsSettings,
        name: 'ttsSettings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TTSSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.sttSettings,
        name: 'sttSettings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const STTSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.translationSettings,
        name: 'translationSettings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TranslationSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.imageGenSettings,
        name: 'imageGenSettings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ImageGenSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.regexSettings,
        name: 'regexSettings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RegexSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.variablesSettings,
        name: 'variablesSettings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final chatId = state.uri.queryParameters['chatId'];
          return VariablesSettingsScreen(chatId: chatId);
        },
      ),
      GoRoute(
        path: AppRoutes.logitBiasSettings,
        name: 'logitBiasSettings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LogitBiasSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.cfgScaleSettings,
        name: 'cfgScaleSettings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final characterId = state.uri.queryParameters['characterId'];
          final chatId = state.uri.queryParameters['chatId'];
          return CFGScaleSettingsScreen(
            characterId: characterId,
            chatId: chatId,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.logprobsSettings,
        name: 'logprobsSettings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LogprobsSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.tokenizerSettings,
        name: 'tokenizerSettings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TokenizerSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.vectorStorageSettings,
        name: 'vectorStorageSettings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const VectorStorageSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.llmTest,
        name: 'llmTest',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LlmTestScreen(),
      ),
      GoRoute(
        path: AppRoutes.llmConfigList,
        name: 'llmConfigList',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LlmConfigListScreen(),
      ),
      GoRoute(
        path: AppRoutes.modelDetection,
        name: 'modelDetection',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ModelDetectionScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(state.uri.toString()),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});
