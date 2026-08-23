import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
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
import 'package:kirakira/presentation/screens/settings/log_view_screen.dart';
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
import 'package:kirakira/presentation/screens/about/about_screen.dart';

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
  // ===== 设置树二层化(B-T3,宪法 §五.5 层级 ≤3)=====
  static const promptManager = '/settings/ai/prompt-manager';
  static const advancedSettings = '/settings/ai/advanced';
  static const backgroundSettings = '/settings/appearance/background';
  static const homeAppearance = '/settings/appearance/home';
  static const themeSettings = '/settings/appearance/theme';
  static const statistics = '/settings/data/statistics';
  static const settingsLogs = '/settings/data/logs';
  static const advanced = '/advanced'; // 极客 Core:独立仪表盘,不进 /settings 树
  static const chatStatistics = '/chat/:id/statistics';
  static const aiPresets = '/settings/ai/presets';
  static const import_ = '/import';
  static const personas = '/personas';
  static const worldInfo = '/world-info';
  static const groups = '/groups';
  static const groupDetail = '/groups/:id';
  static const tags = '/tags';
  static const spriteSettings = '/settings/appearance/sprites';
  static const characterSprites = '/characters/:id/sprites';
  static const characterRegex = '/characters/:id/regex';
  static const ttsSettings = '/settings/tools/tts';
  static const sttSettings = '/settings/tools/stt';
  static const translationSettings = '/settings/tools/translation';
  static const imageGenSettings = '/settings/tools/image-gen';
  static const regexSettings = '/settings/tools/regex';
  static const variablesSettings = '/settings/tools/variables';
  static const mvuSettings = '/settings/ai/mvu';
  static const logitBiasSettings = '/settings/ai/logit-bias';
  static const cfgScaleSettings = '/settings/ai/cfg-scale';
  static const logprobsSettings = '/logprobs-settings'; // 调试工具,保留原路径
  static const tokenizerSettings = '/settings/ai/tokenizer';
  static const vectorStorageSettings = '/settings/tools/vector-storage';
  static const llmTest = '/llm-test'; // 调试页,保留原路径
  static const llmConfigList = '/llm-config-list'; // 工程页,保留原路径
  static const modelDetection = '/model-detection'; // 独立沉浸页,保留原路径
  static const webviewStage = '/webview-stage/:id';
  static const about = '/about';
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
/// tab 页转场：交叉淡入 + 轻微上浮,durationMd(300ms) + curveSlide(宪法统一档)。
CustomTransitionPage<void> _buildTabPage(LocalKey key, Widget child) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: DesignTokens.durationMd),
    reverseTransitionDuration:
        const Duration(milliseconds: DesignTokens.durationMd),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: DesignTokens.curveSlide,
      );
      return FadeTransition(
        opacity: curved,
        child: child,
      );
    },
  );
}

/// root 级 push 转场:iOS 侧滑(B-T2)
/// 新页右侧滑入(350ms easeOutCubic),前页微向左挪 30%(iOS 视差)。
CustomTransitionPage<void> _buildIosPushPage(LocalKey key, Widget child) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero)
            .animate(curved),
        child: SlideTransition(
          // 前页微向左挪 30%,iOS 视差
          position: Tween(begin: Offset.zero, end: const Offset(-0.3, 0))
              .animate(secondaryAnimation),
          child: child,
        ),
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
        pageBuilder: (context, state) {
          final cid = state.uri.queryParameters['characterId'];
          final isGlobal = state.uri.queryParameters['isGlobal'] == 'true';
          return _buildIosPushPage(state.pageKey,
              WorldInfoScreen(characterId: cid, isGlobal: isGlobal));
        },
      ),
      GoRoute(
        path: AppRoutes.about,
        name: 'about',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildIosPushPage(state.pageKey, const AboutScreen()),
      ),
      GoRoute(
        path: AppRoutes.characterRegex,
        name: 'characterRegex',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return _buildIosPushPage(
              state.pageKey, CharacterRegexScreen(characterId: id));
        },
      ),
      // Full-screen routes (outside shell)
      // NOTE: More specific routes must come BEFORE wildcard routes
      // /characters/new must come before /characters/:id
      GoRoute(
        path: AppRoutes.characterCreate,
        name: 'characterCreate',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildIosPushPage(state.pageKey, const CharacterEditorScreen()),
      ),
      GoRoute(
        path: AppRoutes.characterEdit,
        name: 'characterEdit',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return _buildIosPushPage(
              state.pageKey, CharacterEditorScreen(characterId: id));
        },
      ),
      GoRoute(
        path: AppRoutes.characterDetail,
        name: 'characterDetail',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return _buildIosPushPage(
              state.pageKey, CharacterDetailScreen(characterId: id));
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
        pageBuilder: (context, state) =>
            _buildIosPushPage(state.pageKey, const ImportScreen()),
      ),
      GoRoute(
        path: AppRoutes.personas,
        name: 'personas',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildIosPushPage(state.pageKey, const PersonasScreen()),
      ),
      GoRoute(
        path: AppRoutes.promptManager,
        name: 'promptManager',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildIosPushPage(state.pageKey, const PromptManagerScreen()),
      ),
      GoRoute(
        path: AppRoutes.advancedSettings,
        name: 'advancedSettings',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildIosPushPage(state.pageKey, const AdvancedSettingsScreen()),
      ),
      GoRoute(
        path: AppRoutes.homeAppearance,
        name: 'homeAppearance',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildIosPushPage(state.pageKey, const HomeAppearanceScreen()),
      ),
      GoRoute(
        path: AppRoutes.backgroundSettings,
        name: 'backgroundSettings',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildIosPushPage(state.pageKey, const BackgroundSettingsScreen()),
      ),
      GoRoute(
        path: AppRoutes.themeSettings,
        name: 'themeSettings',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildIosPushPage(state.pageKey, const ThemeSettingsScreen()),
      ),
      GoRoute(
        path: AppRoutes.advanced,
        name: 'advanced',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildIosPushPage(state.pageKey, const GeekDashboardScreen()),
      ),
      GoRoute(
        path: AppRoutes.statistics,
        name: 'statistics',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildIosPushPage(state.pageKey, const StatisticsScreen()),
      ),
      GoRoute(
        path: AppRoutes.mvuSettings,
        name: 'mvuSettings',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildIosPushPage(state.pageKey, const MvuSettingsScreen()),
      ),
      GoRoute(
        path: AppRoutes.aiPresets,
        name: 'aiPresets',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildIosPushPage(state.pageKey, const AIPresetsScreen()),
      ),
      GoRoute(
        path: AppRoutes.chatStatistics,
        name: 'chatStatistics',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return _buildIosPushPage(
              state.pageKey, StatisticsScreen(chatId: id));
        },
      ),
      GoRoute(
        path: AppRoutes.groups,
        name: 'groups',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildIosPushPage(state.pageKey, const GroupsScreen()),
      ),
      GoRoute(
        path: AppRoutes.groupDetail,
        name: 'groupDetail',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return _buildIosPushPage(
              state.pageKey, GroupDetailScreen(groupId: id));
        },
      ),
      GoRoute(
        path: AppRoutes.tags,
        name: 'tags',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildIosPushPage(state.pageKey, const TagsScreen()),
      ),
      GoRoute(
        path: AppRoutes.spriteSettings,
        name: 'spriteSettings',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildIosPushPage(state.pageKey, const SpriteSettingsScreen()),
      ),
      GoRoute(
        path: AppRoutes.characterSprites,
        name: 'characterSprites',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          final name = state.uri.queryParameters['name'] ?? 'Character';
          return _buildIosPushPage(state.pageKey,
              CharacterSpritesScreen(characterId: id, characterName: name));
        },
      ),
      GoRoute(
        path: AppRoutes.ttsSettings,
        name: 'ttsSettings',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildIosPushPage(state.pageKey, const TTSSettingsScreen()),
      ),
      GoRoute(
        path: AppRoutes.sttSettings,
        name: 'sttSettings',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildIosPushPage(state.pageKey, const STTSettingsScreen()),
      ),
      GoRoute(
        path: AppRoutes.translationSettings,
        name: 'translationSettings',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildIosPushPage(state.pageKey, const TranslationSettingsScreen()),
      ),
      GoRoute(
        path: AppRoutes.imageGenSettings,
        name: 'imageGenSettings',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildIosPushPage(state.pageKey, const ImageGenSettingsScreen()),
      ),
      GoRoute(
        path: AppRoutes.regexSettings,
        name: 'regexSettings',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildIosPushPage(state.pageKey, const RegexSettingsScreen()),
      ),
      GoRoute(
        path: AppRoutes.variablesSettings,
        name: 'variablesSettings',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final chatId = state.uri.queryParameters['chatId'];
          return _buildIosPushPage(
              state.pageKey, VariablesSettingsScreen(chatId: chatId));
        },
      ),
      GoRoute(
        path: AppRoutes.logitBiasSettings,
        name: 'logitBiasSettings',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildIosPushPage(state.pageKey, const LogitBiasSettingsScreen()),
      ),
      GoRoute(
        path: AppRoutes.cfgScaleSettings,
        name: 'cfgScaleSettings',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final characterId = state.uri.queryParameters['characterId'];
          final chatId = state.uri.queryParameters['chatId'];
          return _buildIosPushPage(
            state.pageKey,
            CFGScaleSettingsScreen(characterId: characterId, chatId: chatId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.logprobsSettings,
        name: 'logprobsSettings',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildIosPushPage(state.pageKey, const LogprobsSettingsScreen()),
      ),
      GoRoute(
        path: AppRoutes.tokenizerSettings,
        name: 'tokenizerSettings',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildIosPushPage(state.pageKey, const TokenizerSettingsScreen()),
      ),
      GoRoute(
        path: AppRoutes.vectorStorageSettings,
        name: 'vectorStorageSettings',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _buildIosPushPage(
            state.pageKey, const VectorStorageSettingsScreen()),
      ),
      GoRoute(
        path: AppRoutes.llmTest,
        name: 'llmTest',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildIosPushPage(state.pageKey, const LlmTestScreen()),
      ),
      GoRoute(
        path: AppRoutes.llmConfigList,
        name: 'llmConfigList',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildIosPushPage(state.pageKey, const LlmConfigListScreen()),
      ),
      GoRoute(
        path: AppRoutes.settingsLogs,
        name: 'settingsLogs',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildIosPushPage(state.pageKey, const LogViewScreen()),
      ),
      // 遗留路径兜底(聊天域 push '/image-gen-settings' 指向这里;
      // 禁区文件禁改,redirect 保活旧跳转)
      GoRoute(
        path: '/image-gen-settings',
        redirect: (context, state) => AppRoutes.imageGenSettings,
      ),
      GoRoute(
        path: AppRoutes.modelDetection,
        name: 'modelDetection',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildIosPushPage(state.pageKey, const ModelDetectionScreen()),
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
