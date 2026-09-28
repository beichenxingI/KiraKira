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
// [Chronicle融合] VectorStorageSettingsScreen 路由已摘除，import 一并注释
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
  // [外观三项迁移 + 人设迁移] backgroundSettings/homeAppearance/
  // spriteSettings/personas 常量与路由已删除(浮窗化)。
  // [极客Core迁移 P1] ttsSettings/sttSettings/translationSettings/statistics/
  // settingsLogs/chatStatistics 已浮窗化,常量与路由一并删除。
  // [P7] /advanced(极客Core)及其常量删除,功能已全部分流至各浮窗。
  static const import_ = '/import';
  // [P3-E/Z] '/world-info' 恢复, 但收窄为只支持全局模式(characterId 分支已砍)
  static const worldInfo = '/world-info';
  static const groups = '/groups';
  static const groupDetail = '/groups/:id';
  static const tags = '/tags';
  static const characterSprites = '/characters/:id/sprites';
  static const characterRegex = '/characters/:id/regex';
  static const imageGenSettings = '/settings/tools/image-gen';
  static const logprobsSettings = '/logprobs-settings'; // 调试工具,保留原路径
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
      // 角色卡浮窗化：/characters/:id（详情）、/characters/new、/characters/:id/edit
      // 已由预览/编辑浮窗替代，路由删除；regex 路由保留（webview 引用）
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
      // [外观三项迁移 + 人设迁移] /personas、/settings/appearance/background|home|
      // sprites 已浮窗化,路由删除(人设经 showPersonaSettingsDialog,
      // 外观三项经各自设置浮窗)。
      // [P3-E/Z] 全局世界书列表页(仅全局模式; 不接受 characterId 分支,
      // 双模歧义是 A3-T4 删它的根因)。恒以 isGlobal=true 构造。
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
      // [极客Core迁移 P1-P5] /settings/tools/tts|stt|translation|regex|
      // variables、/settings/data/statistics|logs、/settings/ai/advanced|
      // logit-bias|presets|prompt-manager|cfg-scale|mvu|tokenizer
      // 已浮窗化,路由删除。
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
      // [Chronicle融合] VectorStorageSettingsScreen 路由已摘除，
      // 设置入口由 Chronicle 面板接管。文件保留以便回滚。
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
