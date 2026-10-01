import 'package:flutter/material.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:kirakira/core/logger/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kirakira/presentation/screens/home/home_screen.dart';
import 'package:kirakira/presentation/screens/splash/splash_screen.dart';
import 'package:kirakira/presentation/screens/main_page/main_page.dart';
import 'package:kirakira/presentation/screens/character/character_list_screen.dart';
import 'package:kirakira/presentation/screens/character/character_regex_screen.dart';
import 'package:kirakira/presentation/screens/settings/settings_screen.dart';
import 'package:kirakira/presentation/screens/ai_config/llm_test_screen.dart';
import 'package:kirakira/presentation/screens/ai_config/llm_config_list_screen.dart';
import 'package:kirakira/presentation/screens/settings/sprite_settings_screen.dart';
import 'package:kirakira/presentation/screens/settings/image_gen_settings_screen.dart';
// VectorStorageSettingsScreen route removed; its import is kept commented out
// import 'package:kirakira/presentation/screens/settings/vector_storage_settings_screen.dart';
import 'package:kirakira/presentation/widgets/chat/logprobs_panel.dart';
import 'package:kirakira/presentation/screens/ai_config/ai_config_screen.dart';
import 'package:kirakira/presentation/screens/import/import_screen.dart';
import 'package:kirakira/presentation/screens/world_info/world_info_screen.dart';
import 'package:kirakira/presentation/screens/groups/groups_screen.dart';
import 'package:kirakira/presentation/screens/groups/group_detail_screen.dart';
import 'package:kirakira/presentation/screens/tags/tags_screen.dart';
import 'package:kirakira/presentation/widgets/common/app_shell.dart';
import 'package:kirakira/presentation/screens/chat/webview_chat_stage.dart';
import 'package:kirakira/presentation/screens/about/about_screen.dart';

/// Route paths
import '../screens/ai_config/model_detection_screen.dart';

abstract class AppRoutes {
  static const home = '/';
  static const splash = '/splash';
  static const characters = '/characters';
  static const chats = '/chats';
  static const chat = '/chat/:id';
  static const settings = '/settings';
  static const aiConfig = '/ai-config';
  // backgroundSettings/homeAppearance/spriteSettings/personas constants and
  // routes removed (their UI moved into dialogs).
  // ttsSettings/sttSettings/translationSettings/statistics/settingsLogs/
  // chatStatistics likewise moved into dialogs; constants and routes removed.
  // /advanced removed; its features are now split across the various dialogs.
  static const import_ = '/import';
  // '/world-info' restored but narrowed to global mode only (characterId branch removed)
  static const worldInfo = '/world-info';
  static const groups = '/groups';
  static const groupDetail = '/groups/:id';
  static const tags = '/tags';
  static const characterSprites = '/characters/:id/sprites';
  static const characterRegex = '/characters/:id/regex';
  static const imageGenSettings = '/settings/tools/image-gen';
  static const logprobsSettings = '/logprobs-settings'; // Debug tool; original path kept
  static const vectorStorageSettings = '/settings/tools/vector-storage';
  static const llmTest = '/llm-test'; // Debug screen; original path kept
  static const llmConfigList = '/llm-config-list'; // Engineering screen; original path kept
  static const modelDetection = '/model-detection'; // Standalone immersive screen; original path kept
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
/// Tab page transition: cross-fade, durationMd (300ms) + curveSlide.
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

/// Root-level push transition: iOS-style slide.
/// New page slides in from the right (350ms easeOutCubic); the previous page
/// shifts 30% left for the iOS parallax effect.
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
          // Previous page shifts 30% left (iOS parallax)
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
      // Character card routes (/characters/:id, /characters/new, /characters/:id/edit)
      // are replaced by preview/edit dialogs and removed; the regex route stays (referenced by the webview)
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
      // /personas and /settings/appearance/background|home|sprites routes removed;
      // personas open via showPersonaSettingsDialog, the appearance options via their own dialogs.
      // Global worldbook list page (global mode only; no characterId branch).
      // Always constructed with isGlobal=true.
      GoRoute(
        path: AppRoutes.worldInfo,
        name: 'worldInfo',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          return _buildIosPushPage(
              state.pageKey, const WorldInfoScreen(isGlobal: true));
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
      // Routes /settings/tools/tts|stt|translation|regex|variables,
      // /settings/data/statistics|logs and /settings/ai/advanced|logit-bias|
      // presets|prompt-manager|cfg-scale|mvu|tokenizer moved into dialogs; routes removed.
      GoRoute(
        path: AppRoutes.imageGenSettings,
        name: 'imageGenSettings',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildIosPushPage(state.pageKey, const ImageGenSettingsScreen()),
      ),
      GoRoute(
        path: AppRoutes.logprobsSettings,
        name: 'logprobsSettings',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            _buildIosPushPage(state.pageKey, const LogprobsSettingsScreen()),
      ),
      // VectorStorageSettingsScreen route removed; its settings entry is now
      // owned by the Chronicle panel. The file is kept for rollback.
      // GoRoute(
      //   path: AppRoutes.vectorStorageSettings,
      //   name: 'vectorStorageSettings',
      //   parentNavigatorKey: _rootNavigatorKey,
      //   pageBuilder: (context, state) => _buildIosPushPage(
      //       state.pageKey, const VectorStorageSettingsScreen()),
      // ),
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
      // Legacy path fallback: the chat domain still pushes '/image-gen-settings' here.
      // The source file is off-limits, so this redirect keeps old jumps working.
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
