import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import '../../widgets/common/glass_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:kirakira/presentation/screens/chat/tavern_helper_facade.dart';
import 'package:kirakira/presentation/providers/chat_providers.dart';
import 'package:kirakira/data/repositories/chat_repository.dart';
import 'package:kirakira/presentation/providers/ai_preset_providers.dart';
import 'package:kirakira/data/models/ai_preset.dart';
import 'package:kirakira/presentation/providers/regex_providers.dart';
import 'package:kirakira/domain/services/regex_service.dart';
import 'package:kirakira/data/models/regex_script.dart';
import 'package:kirakira/data/models/chat.dart';
import 'package:kirakira/presentation/screens/chat/chat_bridge.dart';
import 'package:kirakira/presentation/providers/settings_providers.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:go_router/go_router.dart';
import 'package:kirakira/presentation/providers/persona_providers.dart';
import 'package:kirakira/domain/services/chat_export_service.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:uuid/uuid.dart';
import 'package:kirakira/presentation/providers/chat_export_provider.dart' show chatExportServiceProvider;
import 'package:kirakira/presentation/providers/prompt_manager_providers.dart';
import '../../providers/quote_color_providers.dart';
import 'package:kirakira/presentation/providers/llm_configs_provider.dart';
import 'dart:io';
import 'package:kirakira/data/models/character.dart';
import 'package:kirakira/data/models/prompt_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:kirakira/presentation/widgets/chat/chat_background_widget.dart';
import 'package:kirakira/core/logger/logger.dart';
import 'package:flutter/gestures.dart';
import 'package:kirakira/domain/services/variables_service.dart';
import 'package:kirakira/domain/services/slash_command/slash_command.dart';
import 'package:kirakira/domain/services/slash_command/commands/basic_commands.dart';
import 'package:kirakira/domain/services/slash_command/commands/variable_commands.dart';
import 'package:kirakira/domain/services/slash_command/commands/control_flow_commands.dart';
import 'package:kirakira/domain/services/slash_command/commands/math_commands.dart';
import 'package:kirakira/domain/services/slash_command/commands/generation_commands.dart';
import 'package:kirakira/domain/services/slash_command/commands/ui_commands.dart';
import 'package:kirakira/domain/services/slash_command/commands/floor_commands.dart';
import 'package:kirakira/data/repositories/world_info_repository.dart';
import 'package:kirakira/presentation/providers/world_info_providers.dart'
    show worldInfoNotifierProvider;
import 'package:kirakira/data/models/world_info.dart' as models;
import 'package:image_picker/image_picker.dart';
import 'package:kirakira/presentation/widgets/chat/image_generation_dialog.dart';
import 'package:kirakira/presentation/screens/chat/chat_images_screen.dart';
import 'package:kirakira/domain/services/image_generation_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:kirakira/presentation/utils/export_delivery.dart';
import 'package:path/path.dart' as p;
import 'package:kirakira/presentation/widgets/common/character_avatar_image.dart';
import 'package:kirakira/core/utils/path_utils.dart';
import 'package:kirakira/presentation/providers/context_usage_providers.dart';
import 'package:image/image.dart' as img;
import 'package:kirakira/presentation/providers/tts_providers.dart';
import 'package:kirakira/presentation/providers/stt_providers.dart';
import 'package:kirakira/domain/services/stt_service.dart';
import 'package:kirakira/presentation/providers/sprite_providers.dart';
import 'package:kirakira/data/models/sprite.dart';
import 'package:kirakira/presentation/providers/cfg_scale_providers.dart';
import 'package:kirakira/presentation/providers/background_providers.dart';
import 'package:kirakira/presentation/providers/variables_providers.dart';
import 'package:kirakira/presentation/providers/tokenizer_providers.dart';
import 'package:kirakira/presentation/providers/vector_storage_providers.dart';
import 'package:kirakira/data/repositories/chronicle_repository.dart';
import 'package:kirakira/presentation/providers/chronicle_providers.dart';
import 'package:kirakira/domain/services/chronicle_summary_service.dart';
import 'package:kirakira/presentation/providers/image_gen_providers.dart';
import 'package:kirakira/data/models/chat_background.dart';
import 'package:kirakira/data/models/vector_storage.dart';
import 'package:kirakira/domain/services/tts_service.dart';
import 'package:kirakira/domain/services/tts_model_service.dart';
import 'package:kirakira/domain/services/llm_service.dart';
import 'package:kirakira/presentation/providers/mvu_settings_providers.dart';
import 'package:kirakira/domain/services/debug_log_service.dart';
import 'package:kirakira/presentation/widgets/snackbar_utils.dart';
import 'package:kirakira/core/utils/file_utils.dart';

/// Top-level function for compute: inside the isolate it reads only the image header to get
/// width/height without decoding the whole image (memory safe).
/// Returns {'w': width, 'h': height}; null on failure.
Map<String, int>? _probeImageSize(String path) {
  try {
    final bytes = File(path).readAsBytesSync();
    final decoder = img.findDecoderForData(bytes);
    if (decoder == null) return null;
    final info = decoder.startDecode(bytes);
    if (info == null) return null;
    return {'w': info.width, 'h': info.height};
  } catch (_) {
    return null;
  }
}
//  KiraKira - new chat screen
//  by NorthStar
//
//  Architecture: Flutter is the shell; the message area is one full-screen WebView.
//  All communication goes through ChatBridge; private evaluateJavascript bypasses are forbidden.
//  Dialogs must pause() before covering the WebView and resume() on close --
//  in HC mode any overlaid Flutter layer triggers expensive compositing and drops frames even when idle.

class WebViewChatStage extends ConsumerStatefulWidget {
  final String chatId;
  const WebViewChatStage({super.key, required this.chatId});

  @override
  ConsumerState<WebViewChatStage> createState() => _WebViewChatStageState();
}

class _WebViewChatStageState extends ConsumerState<WebViewChatStage> with TickerProviderStateMixin, WidgetsBindingObserver {
  // 新增：强制最短加载时间控制
  bool _minLoadingTimeElapsed = false;
  Timer? _minLoadingTimer;
  // WebView 是否已完成首次加载（onLoadStop 成功 / 加载出错 视为就绪）
  bool _webViewReady = false;
  // 星星脉动方向：true = 0→1，false = 1→0；onEnd 翻转以形成循环脉动
  bool _starPulseUp = true;
  ProviderSubscription<PromptManagerConfig>? _pmSub;
  ProviderSubscription<String?>? _charSub; // self-healing listener for character changes
  InAppWebViewController? _controller;
  bool _pmIdentifiersLogged = false;
  /// Session-level passthrough cache for unknown ST preset settings keys, keyed by preset name.
  /// Settings keys with no matching platform model field are not whitelist-blocked: the whole bag
  /// is stashed on write and laid down as the base on read; modeled keys such as should_stream
  /// override with their true values so reads stay consistent after Fox's updatePresetWith rewrite.
  final Map<String, Map<String, dynamic>> _stSettingsPassthrough = {};
  // Preset read cache: getPreset TTL cache + in-flight request coalescing.
  // The Fox panel polls every 800ms and hits getPreset('in_use') heavily (4MB JSON), so the Dart
  // side does TTL+coalescing first; the real bandwidth saving is the JS-side __KIRA_PRESET_CACHE.
  final Map<String, Map<String, dynamic>> _presetReadCache = {};
  final Map<String, DateTime> _presetCacheAt = {};
  final Map<String, Completer<dynamic>> _presetReadInflight = {};
  static const Duration _presetCacheTTL = Duration(milliseconds: 500);
  int _wvCrashCount = 0; // renderer crash self-healing attempt cap, prevents a crash -> reload -> crash loop
  // Single source for the WebView composition origin (initialData and crash-recovery loadData must stay same-origin)
  static const String _kWebViewBaseUrl = 'https://localhost/';
  bool _webViewMounted = false; // deferred mount: the WebView is created only after entry, so heavy work does not starve the entry animation
  final TextEditingController _inputController = TextEditingController();

  /// IDs of messages currently being translated; prevents duplicate requests and placeholder flicker
  final Set<String> _translatingIds = {};
  // whether there is pending input text: drives the send button enabled/disabled style (text = bright, empty = gray)
  final ValueNotifier<bool> _hasInput = ValueNotifier(false);
  final ImagePicker _imagePicker = ImagePicker();
  final List<ChatAttachment> _pendingAttachments = [];
  // Bubble avatar data URI cache: one each for character/user, computed only once
  String? _charAvatarDataUri;
  String? _userAvatarDataUri;
  String? _cachedCharAvatarSrcPath;
  String? _cachedUserAvatarSrcPath;

  /// Reads an avatar file into a data URI (relative paths are converted to absolute first -- a past pitfall). Cached while the source path is unchanged.
  Future<String?> _avatarToDataUri(String? rawPath, bool isUser) async {
    if (rawPath == null || rawPath.isEmpty) return null;
    final cachedSrc = isUser ? _cachedUserAvatarSrcPath : _cachedCharAvatarSrcPath;
    final cachedUri = isUser ? _userAvatarDataUri : _charAvatarDataUri;
    if (cachedSrc == rawPath && cachedUri != null) return cachedUri;
    try {
      final abs = await PathUtils.toAbsolutePath(rawPath);
      final file = File(abs);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);
      final uri = 'data:image/png;base64,$b64';
      if (isUser) {
        _userAvatarDataUri = uri;
        _cachedUserAvatarSrcPath = rawPath;
      } else {
        _charAvatarDataUri = uri;
        _cachedCharAvatarSrcPath = rawPath;
      }
      return uri;
    } catch (_) {
      return null;
    }
  }
  /// attachment path -> base64 string cache, avoids _pushMessages re-reading disk every time
  final Map<String, String> _attachmentB64Cache = {};
  final GlobalKey _webViewKey = GlobalKey();
  final FocusNode _inputFocus = FocusNode();
  late final ChatBridge _bridge = ChatBridge(
    onLog: (m) => debugPrint('[bridge] $m'),
  );
  bool _wasGenerating = false;
  late final AnimationController _maskController = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 550));
  late final Animation<double> _maskAnim = CurvedAnimation(parent: _maskController, curve: DesignTokens.curveEmphasized);

  // Third-party library caches (jQuery/lodash/toastr/yaml), shared class-wide, read only once
  static String? _jqueryB64;
  static String? _lodashB64;
  static String? _toastrJsB64;
  static String? _toastrCssB64;
  static String? _yamlB64;
  static String? _vueB64;
  static bool _libsLoaded = false;
  static String? _mvuBundleRaw;
  static bool _mvuLoaded = false;
  static String? _ejsBundleRaw;
  static bool _ejsLoaded = false;
  static String? _ejsStubRaw;
  static bool _ejsStubLoaded = false;
  // Chat shell assets: initial HTML (with placeholders) + bridge JS; read once, failure goes to an explicit error page
  static String? _chatStageHtml;
  static String? _chatBridgeJs;
  static bool _chatStageLoaded = false;

  // Worldbook read cache: (method + args + character) -> (expiry time, result), TTL 2s.
  // Background: after path C was revived, cards like Daoyuan poll getWorldbook every 5s; without
  // a cache each poll costs an N+1 full DB read + serialization.
  static const Duration _wiCacheTtl = Duration(seconds: 2);
  final Map<String, (DateTime, dynamic)> _wiCache = {};
  static const Object _wiCacheMiss = Object();

  String _wiCacheKey(String method, [Object? arg]) =>
      '$method|${arg ?? ''}|${ref.read(activeChatProvider).character?.id ?? 'none'}';

  /// Returns the cached value on a read-cache hit; returns the _wiCacheMiss sentinel on miss/expiry (the result itself may be an empty list).
  dynamic _wiCacheLookup(String method, [Object? arg]) {
    final key = _wiCacheKey(method, arg);
    final hit = _wiCache[key];
    if (hit != null) {
      if (DateTime.now().isBefore(hit.$1)) {
        debugPrint('[WI缓存] 方法=$method, 缓存命中');
        return hit.$2;
      }
      _wiCache.remove(key);
    }
    debugPrint('[WI缓存] 方法=$method, 缓存未命中');
    return _wiCacheMiss;
  }

  void _wiCacheStore(String method, Object? arg, dynamic value) {
    _wiCache[_wiCacheKey(method, arg)] = (DateTime.now().add(_wiCacheTtl), value);
  }

  /// Called after worldbook writes or a character switch to guarantee read-after-write consistency (the write path bypasses the cache).
  void _wiCacheInvalidate([String? reason]) {
    if (_wiCache.isEmpty) return;
    debugPrint('[WI缓存] 失效${reason == null ? '' : '($reason)'}: 清空 ${_wiCache.length} 条');
    _wiCache.clear();
  }

  /// Loads the chat shell assets (html + bridge js). _chatStageLoaded is set true only on
  /// success; on failure it stays false so the next call retries, and _htmlShell() shows an
  /// explicit error page instead of a white screen.
  static Future<void> _loadChatStageAssets() async {
    if (_chatStageLoaded) return;
    try {
      _chatStageHtml = await rootBundle.loadString('assets/chat/chat_stage.html');
      _chatBridgeJs = await rootBundle.loadString('assets/chat/chat_bridge.js');
      _chatStageLoaded = true;
    } catch (e) {
      KiraLogger().error('聊天壳', '聊天壳资产读取失败: $e');
    }
  }

  /// Loads and caches the third-party libraries (base64-encoded for inline injection). Only the first call actually reads them.
  static Future<void> _loadCompatLibs() async {
    if (_libsLoaded) return;
    try {
      final jquery = await rootBundle.loadString('assets/libs/jquery.min.js');
      final lodash = await rootBundle.loadString('assets/libs/lodash.min.js');
      final toastrJs = await rootBundle.loadString('assets/libs/toastr.min.js');
      // yaml gets its own try: if missing or corrupt only YAML is lost, without breaking the existing jquery/lodash/toastr load
      final toastrCss = await rootBundle.loadString('assets/libs/toastr.min.css');
      String? yamlJs;
      try {
        yamlJs = await rootBundle.loadString('assets/libs/yaml.min.js');
      } catch (e) {
        KiraLogger().info('兼容库', 'yaml 库读取失败(仅 YAML 全局缺失): $e');
      }
      // vue gets its own try: it must be the global build to attach window.Vue, which Daoyuan's CDN
      // bundle depends on; if missing or corrupt only Vue is lost, the other libs are unaffected
      String? vueJs;
      try {
        vueJs = await rootBundle.loadString('assets/libs/vue.global.prod.js');
      } catch (e) {
        KiraLogger().info('兼容库', 'vue 库读取失败(仅 Vue 全局缺失): $e');
      }
      _jqueryB64 = base64Encode(utf8.encode(jquery));
      _lodashB64 = base64Encode(utf8.encode(lodash));
      _toastrJsB64 = base64Encode(utf8.encode(toastrJs));
      _toastrCssB64 = base64Encode(utf8.encode(toastrCss));
      _yamlB64 = yamlJs == null ? null : base64Encode(utf8.encode(yamlJs));
      _vueB64 = vueJs == null ? null : base64Encode(utf8.encode(vueJs));
      _libsLoaded = true;
    } catch (e) {
      // Load failure does not block chat, only logs it
      KiraLogger().info('兼容库', '第三方库加载失败: $e');
    }
  }
  /// Loads and caches the MVU bundle (base64) for inlining into the engine room.
  static Future<void> _loadEjsStub() async {
    if (_ejsStubLoaded) return;
    try {
      final bundle = await rootBundle.loadString('assets/libs/ejs_stub.js');
      _ejsStubRaw = bundle;
      _ejsStubLoaded = true;
    } catch (e) {
      KiraLogger().info('EJS', 'stub 加载失败: $e');
    }
  }

  static Future<void> _loadEjsBundle() async {
    if (_ejsLoaded) return;
    try {
      final bundle = await rootBundle.loadString('assets/libs/ejs_bundle.js');
      _ejsBundleRaw = bundle;
      _ejsLoaded = true;
    } catch (e) {
      KiraLogger().info('EJS', 'bundle 加载失败: $e');
    }
  }

  static Future<void> _loadMvuBundle() async {
    if (_mvuLoaded) return;
    try {
      final bundle = await rootBundle.loadString('assets/libs/mvu_bundle.js');
      _mvuBundleRaw = bundle;
      _mvuLoaded = true;
    } catch (e) {
      KiraLogger().info('MVU', 'bundle 加载失败: $e');
    }
  }

  /// Injects the cached third-party libraries (base64) into the outer WebView's window.__KIRA_LIBS.
  /// Called once after page load so injectBridge can inline them into the iframe on demand.
  Future<void> _injectCompatLibs(InAppWebViewController c) async {
    if (!_libsLoaded) return;
    final js = 'window.__KIRA_LIBS={'
        'jquery:"${_jqueryB64 ?? ''}",'
        'lodash:"${_lodashB64 ?? ''}",'
        'toastrJs:"${_toastrJsB64 ?? ''}",'
        'toastrCss:"${_toastrCssB64 ?? ''}",'
        'yaml:"${_yamlB64 ?? ''}",'
        'vue:"${_vueB64 ?? ''}"'
        '};';
    try {
      await c.evaluateJavascript(source: js);
    } catch (e) {
      KiraLogger().info('兼容库', '库注入失败: $e');
    }
  }
  /// Injects the current character name/user name into the outer WebView's window.__KIRA_MACRO_VALUES.
  /// Read synchronously by substitudeMacros inlined by injectBridge.
  Future<void> _injectMacroValues(InAppWebViewController c) async {
    final activeChat = ref.read(activeChatProvider);
    final charName = activeChat.character?.name ?? 'Assistant';
    final userName = ref.read(activePersonaProvider).valueOrNull?.name ?? 'User';
    final js = 'window.__KIRA_MACRO_VALUES={'
        'user:${jsonEncode(userName)},'
        'char:${jsonEncode(charName)}'
        '};'
        'window.__KIRA_CHAT_ID=${jsonEncode(widget.chatId)};';
    try {
      await c.evaluateJavascript(source: js);
    } catch (e) {
      KiraLogger().info('宏值注入', '注入失败: \$e');
    }
  }
  /// Injects the shared TavernHelper facade into the outer window.__ENGINE_FACADE_JS,
  /// inlined when createEngineRoom builds the engine room iframe.
  Future<void> _injectEngineFacade(InAppWebViewController c) async {
    final mvu = ref.read(mvuSettingsProvider);
    final facade = buildTavernHelperFacadeJs(frameId: 'engine-room', mvu: mvu, ejsLoaded: _ejsLoaded);
    final js = 'window.__ENGINE_FACADE_JS=${jsonEncode(facade)};';
    try {
      await c.evaluateJavascript(source: js);
    } catch (e) {
      KiraLogger().info('引擎房', '门面注入失败: $e');
    }
  }

  /// Injects the main environment snapshot into the outer window.__KIRA_MAIN_ENV,
  /// read by the main document's SillyTavern.getContext() skeleton (mvu_settings/EjsTemplate).
  /// On injection failure the HTML side degrades to an empty object and logs a [main env] message; it does not block.
  Future<void> _injectMainEnv(InAppWebViewController c) async {
    final mvu = ref.read(mvuSettingsProvider);
    // chatCompletionSettings truth value (Fox's agent guard waits for it to appear)
    final llm = ref.read(llmConfigProvider);
    final env = <String, dynamic>{
      'mvu': <String, dynamic>{
        '更新方式': mvu.updateMode,
        // the four notification flags are synced into the main environment (same source as the facade bake)
        '通知': <String, dynamic>{
          'MVU框架加载成功': mvu.notifyFrameworkLoaded,
          '变量初始化成功': mvu.notifyInitSuccess,
          '变量更新出错': mvu.notifyVarError,
          '额外模型解析中': mvu.notifyExtraParsing,
        },
        '额外模型解析配置': <String, dynamic>{
          '破限方案': mvu.jailbreakScheme,
          '启用自动请求': mvu.autoRequest,
          'max_chat_history': mvu.maxChatHistory,
          '模型来源': mvu.modelSource,
          'api地址': mvu.apiUrl,
          '模型名称': mvu.modelName,
        },
      },
      // real EJS engine load-state gate (_ejsLoaded static flag), not faked
      'ejsLoaded': _ejsLoaded,
      'chatCompletion': <String, dynamic>{
        'temperature': llm.temperature,
        'top_p': llm.topP,
        'max_tokens': llm.maxTokens,
      },
    };
    final js = 'window.__KIRA_MAIN_ENV=${jsonEncode(env)};';
    try {
      await c.evaluateJavascript(source: js);
    } catch (e) {
      KiraLogger().info('主环境', '注入失败: $e');
    }
  }
  Future<void> _injectPresetScripts(InAppWebViewController c) async {
    // Validate that the chat in the provider matches this widget, preventing wrong scripts from being injected on card-switch races
    final currentChat = ref.read(activeChatProvider).chat;
    if (currentChat?.id != widget.chatId) {
      debugPrint(
          '[脚本注入] 跳过: provider中的chat(${currentChat?.id})与widget.chatId(${widget.chatId})不匹配');
      return;
    }
    final prefs = ref.read(sharedPreferencesProvider);
    final character = ref.read(activeChatProvider).character;
    if (character == null) {
      debugPrint('[脚本注入] 跳过: character为null');
      return;
    }
    final preset = ref.read(activeAIPresetProvider);
    final scripts = <Map<String, dynamic>>[
      ...preset?.tavernHelperScripts ?? const <Map<String, dynamic>>[],
    ];
    final raw = ref.read(activeChatProvider).character?.extensions['tavern_helper'];
    if (raw is Map && raw['scripts'] is List) {
      scripts.addAll((raw['scripts'] as List).whereType<Map>().map(Map<String, dynamic>.from));
    }
    final enabledScripts = scripts.where((s) => s['enabled'] == true && s['content'] is String).toList();
    final authKey = 'tavern_scripts_auth_${character.id ?? 'none'}_${preset?.id ?? 'none'}';
    var allowed = prefs.getBool(authKey);
    if (enabledScripts.isNotEmpty && allowed == null && mounted) {
      final names = enabledScripts.map((s) => '• ${s['name'] ?? '未命名脚本'}').join('\n');
      // HTML confirm dialog: the WebView is already ready during injection, so no Flutter dialog is needed
      allowed = await _showHtmlConfirm(
        title: '此内容包含 ${enabledScripts.length} 个脚本',
        message: '$names\n\n是否允许运行？',
        confirmText: '允许',
        cancelText: '拒绝',
      );
      if (allowed) await prefs.setBool(authKey, true);
      if (!allowed) KiraLogger().info('预设脚本', '用户拒绝，脚本不执行');
    }
    if (allowed != true) enabledScripts.clear();
// Fix: some scripts read _TH.getPreset with synchronous semantics (the platform facade returns
// a Promise), causing an infinite self-triggering loop. Before injection, patch these two read
// points to read the synchronous __KIRA_PRESET_CACHE mirror instead.
// The patch is attempted for all scripts; regexes that do not match return the input unchanged,
// so other scripts are unaffected.
    final patchedScripts = enabledScripts.map<Map<String, dynamic>>((s) {
      final name = s['name']?.toString() ?? '';  // kept for logging
      // the patch is attempted for all scripts; each regex decides whether it applies
      final original = s['content'] as String;
      var patched = original;
      var hit1 = 0, hit2 = 0;
      // Patch 1: isStreamingEnabled (pretty.js:9160)
      patched = patched.replaceAllMapped(
        RegExp(
          r'''return\s+getPreset\s*\?\.\s*\(\s*["']in_use["']\s*\)\s*\?\.\s*settings\s*\?\.\s*should_stream\s*===\s*true\s*;''',
        ),
        (m) {
          hit1++;
          return 'return (((window.__KIRA_PRESET_CACHE||{}).in_use||{}).settings||{})'
              '.should_stream === true;';
        },
      );
      // Patch 2: restoreInlineMediaOption (pretty.js:74212-74213)
      patched = patched.replaceAllMapped(
        RegExp(
          r'''const\s+(\w+)\s*=\s*getPreset\s*\(\s*["']in_use["']\s*\)\s*;\s*const\s+(\w+)\s*=\s*\1\?\.\s*settings\s*\?\.\s*allow_sending_images\s*;''',
        ),
        (m) {
          hit2++;
          return 'const ${m[1]} = ((window.__KIRA_PRESET_CACHE||{}).in_use)||null; '
              'if(!${m[1]}) return; '
              'const ${m[2]} = ${m[1]}?.settings?.allow_sending_images;';
        },
      );
      if (hit1 == 0 && hit2 == 0) {
        debugPrint('[P5-14] 警告: 脚本"$name"patch 未命中任何目标,可能版本不匹配');
        return s;
      }
      debugPrint('[P5-14] patch完成: isStreamingEnabled×$hit1, '
          'restoreInlineMediaOption×$hit2 (脚本: $name)');
      return {...s, 'content': patched};
    }).toList();
    try {
      await c.evaluateJavascript(
        source: 'window.__KIRA_PRESET_SCRIPTS=${jsonEncode(patchedScripts)};',
      );
      // Script-level variable snapshot: prefetch persistent variables for each enabled script so
      //   after injection the script room hydrates them into the facade __varCache.script before
      //   each script starts, making getVariables({type:'script'}) readable synchronously.
      final snapshot = <String, dynamic>{};
      for (final s in enabledScripts) {
        final sid = (s['id'] as String?)?.isNotEmpty == true
            ? s['id'] as String
            : (s['name'] as String? ?? 'unnamed');
        if (sid.isNotEmpty) {
          try {
            snapshot[sid] = VariablesService.instance.getScriptVariables(sid);
          } catch (_) {}
        }
      }
      await c.evaluateJavascript(
        source: 'window.__KIRA_SCRIPT_VARS_SNAPSHOT=${jsonEncode(snapshot)};',
      );
      await c.evaluateJavascript(
        source: 'if(window.resetPresetScriptsRoom)window.resetPresetScriptsRoom();');
      debugPrint('[预设脚本] Dart侧注入 ${enabledScripts.length} 个 允许=$allowed');
    } catch (e) {
      KiraLogger().info('预设脚本', '注入失败: $e');
    }
  }

  /// Injects the MVU bundle (base64) into the outer window.__KIRA_MVU_BUNDLE,
  /// inlined as an ES module when createEngineRoom builds the engine room.
  Future<void> _injectEjsStub(InAppWebViewController c) async {
    if (!_ejsStubLoaded || _ejsStubRaw == null) return;
    final b64 = base64Encode(utf8.encode(_ejsStubRaw!));
    final js = 'window.__KIRA_EJS_STUB="$b64";';
    try {
      await c.evaluateJavascript(source: js);
    } catch (e) {
      KiraLogger().info('EJS', 'stub 注入失败: $e');
    }
  }

  Future<void> _injectEjsBundle(InAppWebViewController c) async {
    if (!_ejsLoaded || _ejsBundleRaw == null) return;
    final b64 = base64Encode(utf8.encode(_ejsBundleRaw!));
    final js = 'window.__KIRA_EJS_BUNDLE="$b64";';
    try {
      await c.evaluateJavascript(source: js);
    } catch (e) {
      KiraLogger().info('EJS', 'bundle 注入失败: $e');
    }
  }

  Future<void> _injectMvuBundle(InAppWebViewController c) async {
    if (!_mvuLoaded || _mvuBundleRaw == null) return;

    var bundle = _mvuBundleRaw!;
    final mvu = ref.read(mvuSettingsProvider);
    if (mvu.customPromptEnabled && mvu.customPrompt.trim().isNotEmpty) {
      bundle = _replaceMvuTask(bundle, mvu.customPrompt.trim());
    }

    final b64 = base64Encode(utf8.encode(bundle));
    final js = 'window.__KIRA_MVU_BUNDLE="$b64";';
    try {
      await c.evaluateJavascript(source: js);
    } catch (e) {
      KiraLogger().info('MVU', 'bundle 注入失败: $e');
    }
  }

  /// Replaces the bundle's const wX='...default task...' with the custom prompt.
  /// The regex uses (?:[^'\\]|\\.)* to skip internally escaped single quotes, avoiding an early cut-off by a non-greedy match.
  String _replaceMvuTask(String bundle, String customTask) {
    final escaped = customTask
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\r\n', '\\r\\n')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r');
    final regex = RegExp(r"const wX='(?:[^'\\]|\\.)*'");
    if (!regex.hasMatch(bundle)) {
      KiraLogger().info('MVU', '⚠️ 未匹配到 const wX,替换跳过(bundle 可能变了)');
      return bundle;
    }
    KiraLogger().info('MVU', '✅ 已用自定义提示词替换默认task');
    return bundle.replaceFirst(regex, "const wX='$escaped'");
  }

  double _keyboardHeight = 0;
  bool _keyboardVisible = false;
  bool _funcPanelOpen = false;
  bool _topBarVisible = true; // top bar scroll hide/show; direction detection happens on the JS side, this only receives the result
  int _pushEpoch = 0; // push generation counter: a new _pushMessages invalidates in-flight history backfill loops
  // HTML dialog wait table: callbackId -> Completer, results come back over the bridge via dialogResult
  final Map<String, Completer<dynamic>> _dialogCompleters = {};

   @override
  void initState() {
    super.initState();
                    // register the EJS render function so LLMService can render the prompt before sending
                    ref.read(ejsRenderRegistryProvider).register(
                      (text) => _handleRenderEJS({'text': text}),
                    );
    // Watch prompt section changes and push them out to the floating panel
    // fireImmediately: the provider is finalized synchronously and read elsewhere early, so once the
    // listener attaches there may be no "change" and the callback would never fire -> the hidden
    // list would be empty on the first frame. Push once immediately as a fallback (queued in the
    // outbox, idempotent and harmless).
    _pmSub = ref.listenManual<PromptManagerConfig>(
      promptManagerProvider,
      (prev, next) {
        // ChatBridge.send automatically queues messages sent before the handshake, no need to check ready
        _bridge.send(BridgeType.pmSectionsChanged, {
          'sections': next.sortedSections
              .map((s) => {
                    'type': s.type.name,
                    'identifier': s.identifier,
                    'name': s.name,
                    'enabled': s.enabled,
                    'order': s.order,
                  })
              .toList(),
        });
      },
      fireImmediately: true,
    );
    WidgetsBinding.instance.addObserver(this);
    _maskController.value = 1.0;
    _inputController.addListener(_syncHasInput);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Optimization: the 5 asset loads are independent (each writes only its own static cache), so load in parallel.
      // Serial loading is a noticeable dead wait during the mask phase on low-end devices.
      await Future.wait([
        _loadChatStageAssets(),
        _loadCompatLibs(),
        _loadMvuBundle(),
        _loadEjsStub(),
        _loadEjsBundle(),
      ]);
      if (!mounted) return;
      // Wait for loadChat to actually finish so character data is ready before mounting the WebView
      // Timeout fallback: a hung DB no longer blocks WebView mounting forever (stuck on the loading screen)
      await ref.read(activeChatProvider.notifier).loadChat(widget.chatId)
          .timeout(const Duration(seconds: 10), onTimeout: () {
        debugPrint('[卡点] loadChat超时10s');
      });
      // Mount the WebView (a 350ms artificial delay used to sit here; removed -- pure load time)
      if (!mounted) return;
      setState(() => _webViewMounted = true);
      // 15s safety net: if loadData fails or the renderer process errors so onLoadStop never fires,
      // the mask would cover the screen forever. Force-remove it after 15s; a brief flash beats a permanent freeze.
      Future.delayed(const Duration(seconds: 15), () {
        if (mounted && _maskController.status != AnimationStatus.dismissed) {
          debugPrint('[安全网] 15s遮罩未撤，强制撤下');
          _maskController.reverse();
        }
      });
    });
    // Self-healing: re-inject scripts when the character changes, preventing timing races from injecting the previous card's scripts
    _charSub = ref.listenManual(
      activeChatProvider.select((s) => s.character?.id),
      (previous, next) {
        if (next != null &&
            next != previous &&
            _webViewMounted &&
            _controller != null) {
          debugPrint('[脚本监听] character变化: $previous → $next, 重新注入');
          _wiCacheInvalidate('character变化'); // clear the worldbook cache on character switch so stale values cannot leak across cards
          final c = _controller;
          if (c != null) _injectPresetScripts(c);
        }
      },
    );
    // 强制显示加载动画至少 2 秒
    _minLoadingTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _minLoadingTimeElapsed = true;
        });
        // 如果 WebView 已经准备好了，检查是否可以隐藏遮罩
        _tryHideMask();
      }
    });
  }

  // 新增：尝试隐藏遮罩（需同时满足：WebView 准备好 + 最短时间已过）
  void _tryHideMask() {
    if (_minLoadingTimeElapsed &&
        _webViewReady &&
        mounted &&
        _maskController.status != AnimationStatus.dismissed) {
      _maskController.reverse();
    }
  }
  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    if (!mounted) return;
    _injectLayoutVars();
  }
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) return;
    // Runaway-loop fix: while another route covers this page (full-screen edit page / navigation /
    // Flutter dialog), ignore keyboard metrics entirely. This page stays alive in the tree: keyboard
    // metrics change each frame -> setState -> full build() rebuild (including the paused
    // InAppWebView) -> HC platform view relayout -> system IME remount -> didChangeMetrics again ->
    // infinite loop. Symptom: the phone vibrates wildly while long-press-selecting text, the keyboard
    // pops repeatedly, the screen thrashes, and it never stops on release.
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final view = View.of(context);
    final bottom = view.viewInsets.bottom / view.devicePixelRatio;
    final visible = bottom > 0;
    if (visible && bottom > _keyboardHeight) _keyboardHeight = bottom; // cache the keyboard height
    if (visible != _keyboardVisible) {
      setState(() => _keyboardVisible = visible); // rebuild only on visible <-> hidden transitions
      // Push keyboard state to the WebView: compensate with body bottom padding, otherwise when
      // docked the newest message lands behind the keyboard at the scroll limit and can never scroll into view
      _bridge.send(BridgeType.keyboardInsets, {
        'visible': visible,
        'height': visible ? _keyboardHeight : 0,
      });
    }
    // Sync layout CSS variables to the WebView (keyboard height / status bar / nav bar / viewport height)
    // Frequency is gated by visible != _keyboardVisible transitions, so per-frame metrics jitter cannot flood the bridge
    _injectLayoutVars();
  }

  /// Top bar show/hide toggle (setState only on state transitions; the scroll events themselves are already collapsed on the JS side)
  void _setTopBarVisible(bool visible) {
    if (!mounted || _topBarVisible == visible) return;
    setState(() => _topBarVisible = visible);
    _sendTopBarInsets();
  }

  /// Push the top bar's occupied space to JS: the WebView is full-bleed, so message start = body padding-top.
  /// Top bar shown -> yields 44 + status bar; collapsed -> only the status bar remains, and that 44px belongs to the message area.
  void _sendTopBarInsets() {
    if (!mounted) return;
    final status = MediaQuery.viewPaddingOf(context).top;
    _bridge.send(BridgeType.topBarInsets, {
      'visible': _topBarVisible,
      'barHeight': _topBarVisible ? 56.0 : 0.0,
      'statusHeight': status,
    });
    _injectLayoutVars();
  }

  // Unified layout variable injection
  // All layout-related CSS variables (--keyboard-height / --status-bar-height / --nav-bar-height /
  // --app-viewport-height / --safe-area-inset-top / --safe-area-inset-bottom)
  // are assembled here in one place and delivered in a single shot via ChatBridge.layoutVars.
  // Triggered by: onLoadStop initial injection + didChangeMetrics (keyboard/orientation changes) + _sendTopBarInsets (top bar toggle).
  // No direct evaluateJavascript: per the hard rule at webview_chat_stage.dart:101, all communication goes through ChatBridge.
  void _showApiErrorDialog(BuildContext context, String err) {
    final codeMatch = RegExp(r'HTTP (\d+)').firstMatch(err);
    final statusCode = codeMatch != null ? int.tryParse(codeMatch.group(1)!) : null;
    String title;
    String hint;
    if (err == '收到空回复') {
      title = '收到空回复';
      hint = '上游可能触发了内容审核（聊天内容被拦截），或模型返回了空响应。\n\n建议：尝试修改最后一条消息措辞，或切换模型。';
    } else {
      switch (statusCode) {
        case 400:
          title = '400 · 请求错误';
          hint = '请求格式有误。常见原因：上下文过长超出模型限制、系统提示词格式不兼容、或请求参数有误。';
        case 401:
          title = '401 · 认证失败';
          hint = 'API Key 无效、已过期或未正确填写。请在设置中检查 API Key 是否正确。';
        case 403:
          title = '403 · 无权访问';
          hint = 'API Key 权限不足，或账户已被封禁/暂停服务。请检查账户状态和 Key 权限范围。';
        case 404:
          title = '404 · 资源不存在';
          hint = '模型名称错误，或 API 端点地址不对。请检查模型 ID 和 Base URL 是否填写正确。';
        case 429:
          title = '429 · 请求过频 / 额度不足';
          hint = '触发了速率限制，或账户余额/调用额度已用完。稍等片刻再试，或检查账户余额。';
        case 500:
          title = '500 · 服务器内部错误';
          hint = 'API 服务器端出错，通常是临时性故障。稍后重试一般可恢复。';
        case 502:
          title = '502 · 网关错误';
          hint = '上游服务不可用或中间代理出错。检查网络连接，或等待服务恢复。';
        case 503:
          title = '503 · 服务不可用';
          hint = '服务过载或正在维护中。稍后重试，或查看服务商状态页。';
        case 529:
          title = '529 · 服务过载';
          hint = 'Claude 特有错误码，服务器当前负载过高。稍等片刻重试即可。';
        default:
          if (err.contains('Timeout') || err.contains('timeout')) {
            title = '请求超时';
            hint = '网络连接超时。检查网络状态，或尝试切换响应更快的模型/节点。';
          } else if (err.contains('Connection Error')) {
            title = '连接失败';
            hint = '无法连接到 API 服务器。检查网络、代理设置，以及 Base URL 是否可访问。';
          } else {
            title = '生成失败';
            hint = '发生了未知错误，请查看下方完整错误信息。';
          }
      }
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1C24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF5350), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFEAEAEA),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF252830),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                hint,
                style: const TextStyle(
                  color: Color(0xFFB8C0CC),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '完整错误信息',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 120),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1117),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2A2D35)),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  err,
                  style: const TextStyle(
                    color: Color(0xFFEF9A9A),
                    fontSize: 12,
                    fontFamily: 'monospace',
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭', style: TextStyle(color: Color(0xFF7C4DFF))),
          ),
        ],
      ),
    );
  }

  void _injectLayoutVars() {
    if (!mounted) return;
    final mq = MediaQuery.of(context);
    final statusBarHeight = mq.viewPadding.top;
    final navBarHeight = mq.viewPadding.bottom;
    final keyboardHeight = mq.viewInsets.bottom;
    // visualViewport is not necessarily available inside the WebView, so use the actual visible height (minus the keyboard)
    final viewportHeight = mq.size.height - keyboardHeight;
    // Theme color injection (follows dark/light)
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _bridge.send(BridgeType.layoutVars, {
      'keyboardHeight': keyboardHeight,
      'statusBarHeight': statusBarHeight,
      'navBarHeight': navBarHeight,
      'viewportHeight': viewportHeight,
      'topBarVisible': _topBarVisible,
      'topBarHeight': _topBarVisible ? 56.0 : 0.0,
      'panelBg': _hex(cs.surface),
      'panelRadius': 24,
      'scrim': 'rgba(0,0,0,0.5)',
      'accent': _hex(isDark ? const Color(0xFF7C4DFF) : cs.primary),
      'text1': _hex(cs.onSurface),
      'text2': _hex(cs.onSurfaceVariant),
      'text3': isDark ? '#8A8A8A' : '#6B7280',
      'inputBg': _hex(isDark
          ? const Color(0xFF20242C)
          : const Color(0xFFF1F3F6)),
      'divider': isDark
          ? 'rgba(255,255,255,0.05)'
          : 'rgba(0,0,0,0.06)',
    });
  }

  /// Color -> #RRGGBB (WebView setProperty does not accept ARGB)
  static String _hex(Color c) {
    final r = (c.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (c.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (c.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }

  /// Crash self-healing exceeded its limit: the user tapped "reload", reset the counter and remount the WebView to recover.
  void _reloadWebViewAfterCrash() {
    _wvCrashCount = 0;
    _reloadWebViewContent();
  }

  /// Crash self-healing: rebuild the content with a fresh loadData instead of controller.reload().
  /// reload treats the loadData page's history entry (whose URL is the baseUrl) as a real navigation
  /// and re-requests it, which fails with net::ERR_NAME_NOT_RESOLVED on a public domain (P5-11 diagnosis, part 5).
  /// Once loadData rebuilds the document, onLoadStop re-runs the injection chain (compat libs / facade /
  /// script room / MVU), which is equivalent to a full recovery.
  Future<void> _reloadWebViewContent() async {
    final c = _controller;
    if (c == null) return;
    try {
      await c.loadData(
        data: _htmlShell(),
        mimeType: 'text/html',
        baseUrl: WebUri(_kWebViewBaseUrl),
      );
    } catch (e) {
      debugPrint('[WV-6] 自愈 loadData 失败: $e');
    }
    // No more delayed _pushMessages backfill: a successful loadData always fires onLoadStop, which
    // already awaits _pushMessages; sending another here would double-run, and two history backfill
    // loops interleaving insertBefore would duplicate/reorder message indexes (one root cause of the message-loss bug).
    // WebView rebuilt: any pending HTML dialogs on the page disappear with it, so settle them as cancelled
    for (final c in _dialogCompleters.values) {
      if (!c.isCompleted) c.complete(false);
    }
    _dialogCompleters.clear();
  }

  @override
  void dispose() {
    _minLoadingTimer?.cancel();
    // Clear the EJS render function registration (leaving the chat page, back to a safe state)
    try {
      ref.read(ejsRenderRegistryProvider).clear();
    } catch (_) {}
    // Settle all pending HTML dialogs as cancelled so no Completer hangs forever
    for (final c in _dialogCompleters.values) {
      if (!c.isCompleted) c.complete(false);
    }
    _dialogCompleters.clear();
    _controller?.evaluateJavascript(
        source: 'if(window.resetEngineRoom){var h=document.getElementById("__engineRoomHost");if(h)h.innerHTML="";}');
    WidgetsBinding.instance.removeObserver(this);
    _maskController.dispose();
    _inputController.dispose();
    _hasInput.dispose();
    _inputFocus.dispose();
    _pmSub?.close();
    _charSub?.close();
    _bridge.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When returning from an external Activity (e.g. the gallery), the WebView's PlatformView touch
    // hit-test region goes stale; force one refresh on resume to restore gestures.
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ro = _webViewKey.currentContext?.findRenderObject();
        ro?.markNeedsLayout();
        ro?.markNeedsPaint();
        _controller?.evaluateJavascript(source: '''
          (function(){
            var d = document.body;
            if(!d) return;
            d.style.opacity = d.style.opacity === '0.99' ? '1' : '0.99';
          })();
        ''');
      });
    }
  }

  // build

  @override
  Widget build(BuildContext context) {
    // Message changes -> smart routing: structural changes go full, content growth goes incremental append
    ref.listen(activeChatProvider, (prev, next) {
      final prevMsgs = prev?.messages ?? const [];
      final nextMsgs = next.messages;

      // Pure tail append (sending a message / adding an AI placeholder): prev is a prefix of next
      // with only extra entries at the end -> append only the new DOM instead of clearing the whole
      // page, eliminating white-flash flicker
      final isPureAppend = prevMsgs.isNotEmpty &&
          nextMsgs.length > prevMsgs.length &&
          _isPrefix(prevMsgs, nextMsgs);

      // Flash fix: pure tail truncation (retry deleting follow-ups / delete this and after): next is
      // a shorter prefix of prev -> remove only the surplus DOM. Retry takes exactly this path; it
      // used to fall into "structure changed -> full rebuild" = screen flash
      final isPureTruncate = prevMsgs.isNotEmpty &&
          nextMsgs.length < prevMsgs.length &&
          _isPrefix(nextMsgs, prevMsgs);

      // Structural change (messages added/removed / chat switched) -> full re-render
      final sameStructure = prevMsgs.length == nextMsgs.length &&
          (nextMsgs.isEmpty || prevMsgs.last.id == nextMsgs.last.id);

      if (isPureAppend) {
        _appendNewMessages(prevMsgs.length, nextMsgs);
      } else if (isPureTruncate) {
        _removeMessagesTail(prevMsgs, nextMsgs.length);
      } else if (!sameStructure) {
        _pushMessages();
      } else if (nextMsgs.isNotEmpty) {
        final last = nextMsgs.last;
        final prevLast = prevMsgs.last;
        if (last.content.length > prevLast.content.length &&
            last.content.startsWith(prevLast.content)) {
          final delta = last.content.substring(prevLast.content.length);
          _bridge.send(BridgeType.appendToken, {'id': last.id, 'token': delta});
        } else if (last.content != prevLast.content) {
          _updateSingleMessage(last.id);
        } else {
          // Swipe structure/index changes on a middle message (reroll inserting a placeholder,
          // swipe switching) -> refresh the synced webview.
          // Only swipes length and index are compared, not content: content changes mid-stream are
          // not refreshed here; they are left to the full refresh when generation ends, avoiding a
          // full rebuild on every reroll token and the jank that causes.
          for (var i = 0; i < nextMsgs.length; i++) {
            if (i >= prevMsgs.length) break;
            if (nextMsgs[i].swipes.length != prevMsgs[i].swipes.length ||
                nextMsgs[i].currentSwipeIndex != prevMsgs[i].currentSwipeIndex) {
              _pushMessages();
              break;
            }
          }
        }
      }

      // The instant generation ends: one full refresh to render the streamed plain text as Markdown/HTML cards
      final gen = next.isGenerating;
      // Ignition: user sends a message -> isGenerating false->true, the user message is already in state
      // -> notify the engine room's MVU initCheck (with msgs filling __chatMessages / SillyTavern.chat)
      if (!_wasGenerating && gen) {
        _syncPrimaryLorebookToEngine();   // push the primary worldbook name into the mirror ahead of generation
        final msgsJson = jsonEncode(_serializeMessagesForMvu());
        _controller?.evaluateJavascript(
            source: 'if(window.__emitToEngine)window.__emitToEngine("generation_started",[],$msgsJson);');
        // Generation started: tell the WebView input bar to switch to the stop button state
        _pushInputBarState();
      }
      if (_wasGenerating && !gen) {
        // Flash fix: when generation ends only refresh the last message in place (rendering the
        // streamed plain text as Markdown/HTML) instead of a full initial rebuild -- that rebuild
        // was the root cause of "a flash on every completed reply".
        // If the JS side finds the node missing or its content is already a card, it replies
        // needFullPush and Dart falls back to a full re-push.
        _updateLastMessage(nextMsgs);
        // Ignition: AI reply finished -> notify the engine room's MVU to parse the new reply and update variables
        if (nextMsgs.isNotEmpty) {
          final lastIdx = nextMsgs.length - 1;
          final msgsJson = jsonEncode(_serializeMessagesForMvu());
          _controller?.evaluateJavascript(
              source: 'if(window.__emitToEngine)window.__emitToEngine("message_received",[$lastIdx],$msgsJson);');
        }
        // Generation end (completed or cancelled) must always emit GENERATION_ENDED (the official
        // value is generation_ended), which listeners like Fox's "restore after generation" rely on;
        // the cancel path via cancelGeneration also lands here instead of spinning idly.
        _emitPresetEvent('generation_ended');
        // Generation ended: tell the WebView input bar to switch back to the send button state
        _pushInputBarState();
      }
      _wasGenerating = gen;
      // Auto image generation finished: message attachments changed -> refresh so the new image shows.
      // Auto image generation is asynchronous, so isGenerating is long false by the time it completes
      // and none of the branches above refresh.
      if (prevMsgs.length == nextMsgs.length) {
        for (var i = 0; i < nextMsgs.length; i++) {
          if (nextMsgs[i].attachments.length != prevMsgs[i].attachments.length) {
            // Attachment changes use a targeted update: a full _pushMessages rebuild (initial:true)
            // does root.innerHTML='' and tears down the whole page -> scrollTop resets to zero (the
            // cause of jumping back to the top after image generation).
            // updateMessage only swaps that bubble's content, so scroll position is naturally kept;
            // rich cards fall back to a full re-push when JS replies needFullPush (same path as at
            // generation end, where the anchor mechanism restores the position).
            debugPrint('[Bug6] 消息 ${nextMsgs[i].id} 附件变化 → 定点更新');
            _updateSingleMessage(nextMsgs[i].id);
            break;
          }
        }
      }

      // Error surfacing: empty reply / generation failure shows a unified dialog.
      // Previously error was silently stored in state but never consumed by the UI, which looked like a hang.
      // 503/network errors show a short hint; the full error stays in the logs (debugPrint already has it).
      final err = next.error;
      if (err != null && err.isNotEmpty && err != prev?.error) {
        if (mounted) _showApiErrorDialog(context, err);
      }
    });

    ref.listen(activeAIPresetIdProvider, (prev, next) {
      if (prev != next && _webViewMounted) {
        final controller = _controller;
        if (controller != null) {
                _injectPresetScripts(controller);
        }
      }
    });

    // Refresh the input bar when STT settings change: the voice bar on the WebView's long-press textarea must follow the toggle
    ref.listen(sttSettingsProvider, (prev, next) {
      if (prev?.enabled != next.enabled && _webViewMounted) {
        _pushInputBarState();
      }
    });
    // Refresh the input bar when the STT recording state changes (for UI state display; no recording indicator yet, kept for later)
    ref.listen(sttListeningProvider, (prev, next) {
      if (prev != next && _webViewMounted) {
        _pushInputBarState();
      }
    });

    ref.listen(activeChatIdProvider, (prev, next) {
      if (prev != next && next != null && _webViewMounted) {
        _controller?.evaluateJavascript(
            source: 'if(window.resetEngineRoom)window.resetEngineRoom();');
      }
      // Reset the top bar to visible on chat switch so it is not missing at the start of a new chat
      _setTopBarVisible(true);
    });

    // Auto image generation placeholder: msgId changes -> show/remove the "generating" placeholder
    ref.listen(activeChatProvider.select((s) => s.generatingImageMsgId),
        (prev, next) {
      if (next != null) {
        _bridge.send(BridgeType.setGenerating,
            {'msgId': next, 'genId': 'auto_$next', 'w': 1, 'h': 1});
      } else if (prev != null) {
        _bridge.send(BridgeType.clearGenerating, {'genId': 'auto_$prev'});
      }
    });
    // Auto image generation progress -> update the placeholder percentage
    ref.listen(activeChatProvider.select((s) => s.imageGenProgress),
        (prev, next) {
      final msgId = ref.read(activeChatProvider).generatingImageMsgId;
      if (msgId != null) {
        _bridge.send(BridgeType.setGenerateProgress,
            {'genId': 'auto_$msgId', 'progress': next});
      }
    });
    // Auto image generation failure -> one-shot notification
    ref.listen(activeChatProvider.select((s) => s.imageGenError),
        (prev, next) {
      if (next != null && next.isNotEmpty && next != prev) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ));
      }
    });

    // Image generation settings changed -> push to the open image generation panel: the panel data
    // used to be a snapshot taken when it opened (_openImageGenPanel pushes only once at open time),
    // so changes made on the Flutter settings page were never picked up. targetPanel makes the JS
    // side apply the data only while the image generation panel is open (prevents cross-panel data
    // pollution, see the settingsPanelData handler in chat_stage.html).
    ref.listen(imageGenSettingsProvider, (prev, next) {
      if (prev == next) return;
      debugPrint('[Bug3] 生图设置变化 → 推送打开中的浮窗');
      _bridge.send(BridgeType.settingsPanelData, {
        'data': _serializeImageGenData(),
        'refresh': true,
        'targetPanel': 'imageGen',
      });
    });
    // Image generation model list finished loading -> push again: the model list is fetched
    // asynchronously (fetchedModelsProvider rebuilds and re-fetches when provider/apiKey changes),
    // so settings were pushed first and a follow-up push after the models arrive keeps the panel
    // showing the latest list.
    ref.listen(availableModelsProvider, (prev, next) {
      if (prev == next) return;
      debugPrint('[Bug3] 生图模型列表变化 → 推送打开中的浮窗');
      _bridge.send(BridgeType.settingsPanelData, {
        'data': _serializeImageGenData(),
        'refresh': true,
        'targetPanel': 'imageGen',
      });
    });

    final character = ref.watch(activeChatProvider.select((s) => s.character));
    // Top bar model name: watch the effective config llmConfigProvider.model (not llmConfigsProvider):
    // switching models (updateModel) only writes the former + writes straight to the DB and does not
    // refresh the latter's in-memory list -> watching the wrong source would never update.
    // Switching schemes (setActive -> applyActiveMultiConfig) also lands in llmConfigProvider, so both paths are live.
    final activeModel = ref.watch(llmConfigProvider.select((s) => s.model));
    final isGenerating = ref.watch(
      activeChatProvider.select((s) => s.isGenerating),
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _exitChat();
      },
      child: Stack(
      children: [
        Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: activeGlassPalette.pageBackground,
      extendBodyBehindAppBar: true,
      appBar: _SlidingAppBar(
        visible: _topBarVisible,
        child: _buildGlassAppBar(character, activeModel),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          ChatBackgroundWidget(
        // Precise select subscription on character.id: ActiveChatState contains the full messages
        // list, so a direct watch would rebuild the whole chat shell on every message/generation state change
        characterId: ref.watch(activeChatProvider.select((s) => s.character?.id)),
        child: Stack(
        children: [
                // WebView moved below the top bar: only wallpaper (Flutter layer) sits behind the
                // bar, so blur cannot sample the WebView -- frosted glass stays safe and smooth.
                Positioned.fill(
                  child: Padding(
                  padding: const EdgeInsets.only(
                    // Full bleed: the WebView always fills (top:0), and message start is decided by
                    // body padding-top (driven by the bridge's topBarInsets). When the top bar
                    // collapses we free that 32px via CSS instead of resizing the platform view --
                    // staying inside the HC compositing performance red line, and fixing the issue
                    // where the bar retracted but that area still showed wallpaper (as if it never retracted).
                    top: 0,
                    // WebView fills to the bottom: the input bar has moved into the WebView
                    // (position:fixed; bottom:var(--keyboard-height)), so Flutter no longer needs a
                    // 64px placeholder. Bottom whitespace for the message list is computed dynamically
                    // by body padding-bottom in chat_stage.html's keyboardInsets handler (input-bar
                    // height + safe-area + keyboard-height), so messages are no longer hidden behind
                    // the input bar.
                    bottom: 0,
                  ),
                  child: _webViewMounted
                      ? InAppWebView(
                  key: _webViewKey,
                  gestureRecognizers: {
                    Factory<VerticalDragGestureRecognizer>(
                      () => VerticalDragGestureRecognizer(),
                    ),
                    Factory<HorizontalDragGestureRecognizer>(
                      () => HorizontalDragGestureRecognizer(),
                    ),
                    Factory<TapGestureRecognizer>(
                      () => TapGestureRecognizer(),
                    ),
                    Factory<LongPressGestureRecognizer>(
                      () => LongPressGestureRecognizer(),
                    ),
                  },
                  initialData: InAppWebViewInitialData(
                    data: _htmlShell(),
                    mimeType: 'text/html',
                    encoding: 'utf-8',
                    // baseUrl uses a synthetic https origin instead of about:blank:
                    //   about:blank is an opaque origin, so any localStorage access from the main
                    //   document or the srcdoc script room throws SecurityError -> settings
                    //   persistence / save clicks break for all three presets (Daoyuan, Fox, XuanShu)
                    //   (see part 2 of the P5-9 report).
                    //   With a stable https origin the main document and the iframe get a real
                    //   same-origin localStorage.
                    //   The synthetic origin is never resolved by the network (loadData only uses
                    //   baseUrl for resource/origin resolution and never starts a navigation).
                    //   localhost rather than a public domain: a renderer crash self-healing reload
                    //   re-requests that URL as a real navigation, and a public domain fails with
                    //   net::ERR_NAME_NOT_RESOLVED (P5-11 part 5).
                    baseUrl: WebUri(_kWebViewBaseUrl),
                  ),
                  initialSettings: InAppWebViewSettings(
                    transparentBackground: true,
                    javaScriptEnabled: true,
                    supportZoom: false,
                    allowFileAccessFromFileURLs: true,
                    allowUniversalAccessFromFileURLs: true,
                    mediaPlaybackRequiresUserGesture: false,
                    useHybridComposition: true,
                  ),
                  // Previously nobody handled the Android renderer being killed by the system OOM
                  // killer -> permanent white screen with no logs.
                  // Session-level self-healing cap of 3 attempts prevents a crash -> reload -> crash
                  // loop; past the cap the user gets a visible prompt instead of a silent white screen.
                  onRenderProcessGone: (controller, detail) {
                    _wvCrashCount++;
                    print('[WV-6] RENDER PROCESS GONE didCrash=${detail.didCrash} x=$_wvCrashCount');
                    if (_wvCrashCount > 3) {
                      print('[WV-6] 超过自愈上限(3),停止自动 reload');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('渲染已多次异常,请点击重新加载'),
                            duration: const Duration(seconds: 6),
                            behavior: SnackBarBehavior.floating,
                            action: SnackBarAction(
                              label: '重新加载',
                              onPressed: _reloadWebViewAfterCrash,
                            ),
                          ),
                        );
                      }
                      return;
                    }
                    // Self-healing uses a loadData rebuild to avoid reload's real navigation to the baseUrl
                    _reloadWebViewContent();
                  },
                  // Previously nobody handled main document load errors -> onLoadStop never fired -> the mask covered the screen forever.
                  // Removing the mask gives the user a way out (back / re-enter); once loading finished the mask is already gone, so a late trigger completes instantly with no visual change.
                  onReceivedError: (controller, request, error) {
                    debugPrint('[WebView] 加载错误: ${error.description}');
                    // 加载出错同样视为“就绪”，交由统一判断（最短时间未到则等定时器）
                    _webViewReady = true;
                    _tryHideMask();
                  },
                  onWebViewCreated: (c) {
                    _controller = c;
                    _bridge.attach(c);
                    _bridge.on(BridgeType.action, _handleAction);
                    // Scroll direction events: down = hide, up/top = show.
                    // The JS side already applies a +/-8px hysteresis and only reports direction changes, so this is a pure mapping.
                    _bridge.on(BridgeType.scroll, (payload) {
                      final dir = payload['dir'] as String?;
                      _setTopBarVisible(dir != 'down');
                    });
                    // HTML dialog result callback: find the waiting Completer by callbackId
                    _bridge.on(BridgeType.dialogResult, (payload) {
                      final callbackId = payload['callbackId'] as String?;
                      if (callbackId == null) return;
                      final completer = _dialogCompleters.remove(callbackId);
                      if (completer != null && !completer.isCompleted) {
                        completer.complete(payload['value'] ?? payload['result']);
                      }
                    });
                    // Card log severity levels: error -> toast + persistent buffer, warn -> persistent buffer,
                    // info/debug -> printed only in dev mode (gated by the DebugLogService capture switch)
                    _bridge.on(BridgeType.log, (payload) {
                      final t = payload['text']?.toString() ?? '';
                      final level = payload['level']?.toString().toLowerCase() ?? 'info';
                      switch (level) {
                        case 'error':
                          DebugLogService().log(t, level: 'ERROR', source: '卡片日志');
                          if (mounted) {
                            showErrorSnackBar(context, t);
                          }
                          break;
                        case 'warn':
                          DebugLogService().log(t, level: 'WARN', source: '卡片日志');
                          debugPrint('[卡片警告] $t');
                          break;
                        default:
                          debugPrint('[卡片日志] $t');
                          break;
                      }
                    });
                    // TavernHelper API: read current chat messages (request-response)
                    _bridge.onRequest('th_getMessages', _handleGetMessages);
                    _bridge.onRequest('th_triggerSlash', _handleTriggerSlash);
                    // Backend for EJS execute(): runs it and returns the pipe
                    _bridge.onRequest('th_executeSlash', _handleExecuteSlash);
                    // UI interaction bridge: toastr -> SnackBar, callGenericPopup -> Dialog
                    _bridge.onRequest('th_toast', _handleToast);
                    _bridge.onRequest('th_popup', _handlePopup);
                    _bridge.onRequest('th_setInput', _handleSetInput);
                    _bridge.onRequest('th_setMessage', _handleSetMessage);
                    _bridge.onRequest('th_getVars', _handleGetVariables);
    _bridge.onRequest('th_wiGetEnabledList', (payload) async {
      final char = ref.read(activeChatProvider).character;
      final book = char?.characterBook;
      if (book == null || book.entries.isEmpty) return <String>[];
      return <String>[book.name ?? 'character_book'];
    });
                    _bridge.onRequest('th_setMessages', _handleSetMessages);
                    _bridge.onRequest('th_setVars', _handleSetVariables);
                    // Worldbook API
                    _bridge.onRequest('th_wiGetLorebooks', _handleWiGetLorebooks);
                    _bridge.onRequest('th_wiCreateBook', _handleWiCreateBook);
                    _bridge.onRequest('th_wiGetEntries', _handleWiGetEntries);
                    _bridge.onRequest('th_wiSetEntries', _handleWiSetEntries);
                    _bridge.onRequest('th_wiCreateEntries', _handleWiCreateEntries);
                    _bridge.onRequest('th_wiDeleteEntries', _handleWiDeleteEntries);
                    _bridge.onRequest('th_wiGetCharLorebooks', _handleWiGetCharLorebooks);
                    _bridge.onRequest('th_wiGetLorebookSettings', _handleWiGetLorebookSettings);
                    _bridge.onRequest('th_wiSetLorebookSettings', _handleWiSetLorebookSettings);
                    _bridge.onRequest('th_generateRaw', _handleGenerateRaw);
                    _bridge.onRequest('th_renderEJS', _handleRenderEJS);
                    _bridge.onRequest('th_mvuParseMessage', _handleMvuParseMessage);
                    // Read-only Tavern regex bridge (Daoyuan's 3rd alert data chain)
                    _bridge.onRequest('th_getRegexes', _handleThGetRegexes);
                    // Prompt management API
                    _bridge.onRequest(BridgeType.pmGetSections, _handlePmGetSections);
                    _bridge.onRequest(BridgeType.pmToggleSection, _handlePmToggleSection);
                    // extensionSettings persistence (Daoyuan/MVU panel writes are flushed to disk)
                    _bridge.onRequest(BridgeType.saveExtensionSettings, _handleSaveExtensionSettings);
                    // Preset management API (Fox reads and writes presets)
                    _bridge.onRequest(BridgeType.getPresetNames, _handleGetPresetNames);
                    _bridge.onRequest(BridgeType.getPreset, _handleGetPreset);
                    _bridge.onRequest(BridgeType.setPreset, _handleSetPreset);
                    _bridge.onRequest(BridgeType.getLoadedPresetName, _handleGetLoadedPresetName);
                    // Generation control (Fox auto-advance / stop)
                    _bridge.onRequest(BridgeType.generate, _handleGenerate);
                    _bridge.onRequest(BridgeType.stopGeneration, _handleStopGeneration);
                    // Chronicle visualization: the memory bank panel's "run state" tab fetches the
                    // working state of all five zones (archive progress + hot/warm/cold/readonly
                    // entry partitions, reusing chronicleVisualizationProvider)
                    _bridge.onRequest('getChronicleVisualization', (payload) async {
                      final chatId = widget.chatId;
                      if (chatId.isEmpty) {
                        throw StateError('当前无活动聊天');
                      }
                      final data = await ref
                          .read(chronicleVisualizationProvider(chatId).future);
                      return {
                        'unarchivedCount': data.unarchivedCount,
                        'unarchivedUserTurns': data.unarchivedUserTurns,
                        'summaryInterval': data.summaryInterval,
                        'progress': data.progress,
                        'totalMessageCount': data.totalMessageCount,
                        'unarchivedStartFloor': data.unarchivedStartFloor,
                        'unarchivedEndFloor': data.unarchivedEndFloor,
                        'zones': [
                          for (final z in data.zones)
                            {
                              'name': z.name,
                              'key': z.key,
                              'startIndex': z.startIndex,
                              'endIndex': z.endIndex,
                              'messageCount': z.messageCount,
                              'hasOriginalText': z.hasOriginalText,
                            }
                        ],
                      };
                    });
                  },
                  onLoadStop: (c, url) async {
                    // Overall try/finally: if any await throws, the callback is no longer interrupted ->
                    // the mask is force-removed in finally, so no failure path can stick on "loading" forever.
                    try {
                    // Page (re)load finished (including crash self-healing loadData rebuilds): reset to visible
                    _setTopBarVisible(true);
                    _sendTopBarInsets(); // re-sync the content start position after a rebuild
                    // Initially inject the layout CSS variables (--keyboard-height etc.)
                    _injectLayoutVars();
                    // Optimization: the 8 injections are independent (each writes a different window
                    // global and has no return-value dependency), so run them in parallel. The previous
                    // 9-fold serial evaluateJavascript chain was the biggest self-inflicted cost in onLoadStop.
                    await Future.wait([
                      _injectCompatLibs(c), // inject third-party libs into the outer window
                      _injectMacroValues(c), // inject character/user names for macro substitution
                      _injectRegexRules(c), // regex rule snapshot (for engine room baking)
                      _injectMainEnv(c), // inject the main environment snapshot (read by the main document's ST skeleton)
                      _injectEngineFacade(c), // inject the engine room's shared facade
                      _injectMvuBundle(c),
                      _injectEjsStub(c),
                      _injectEjsBundle(c), // inject the EJS bundle for the engine room to inline
                    ]);
                    // Dependency: _injectPresetScripts involves user interaction (the authorization
                    // dialog), and its internal resetPresetScriptsRoom synchronously reads the
                    // __KIRA_REGEX_RULES injected above while building the script room -> it must run
                    // serially after the parallel injections complete.
                    await _injectPresetScripts(c);
                    await c.evaluateJavascript(
                        source: 'if(window.createEngineRoom)window.createEngineRoom();');
    // Fuse: if the JS ready signal still has not arrived after 2s (old WebView), force it through
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _bridge.markReadyIfMissing();
    });
                    _bridge.on(BridgeType.modelSelected, (payload) {
                      final model = payload['model'] as String?;
                      if (model != null && model.isNotEmpty) {
                        ref.read(llmConfigProvider.notifier).updateModel(model);
                      }
                    });
                    _bridge.on(BridgeType.switchConfig, (payload) async {
                      final id = payload['configId'] as String?;
                      if (id == null) return;
                      await ref.read(llmConfigsProvider.notifier).setActive(id);
                      ref.read(modelFetchProvider.notifier).reset();
                      final cfg = ref.read(llmConfigProvider);
                      await ref
                          .read(modelFetchProvider.notifier)
                          .fetchModels(cfg);
                      if (!mounted) return;
                      final st = ref.read(modelFetchProvider);
                      final cs = ref.read(llmConfigsProvider);
                      _bridge.send(BridgeType.showModelSheet, {
                        'models': st.models,
                        'current': cfg.model,
                        'configs': cs.configs
                            .map((c) => {
                                  'id': c.id,
                                  'name': c.name,
                                  'active': c.isDefault
                                })
                            .toList(),
                      });
                    });
                    _bridge.on(BridgeType.panelClosed, (payload) {
                      if (mounted) setState(() => _funcPanelOpen = false);
                    });
                    _bridge.on(BridgeType.panelAction, (payload) async {
                      final action = payload['action'] as String? ?? '';
                      switch (action) {
                        case 'jumpFloor':
                          final f = int.tryParse(
                              payload['floor']?.toString() ?? '');
                          if (f == null || f < 1) {
                            _snack('请输入有效的楼层号');
                            break;
                          }
                          final total =
                              ref.read(activeChatProvider).messages.length;
                          if (f > total) {
                            _snack('楼层号超出范围（共 $total 楼）');
                            break;
                          }
                          _bridge.send(BridgeType.scrollToFloor, {'floor': f});
                          break;
                        case 'pickImages':
                          // Push inputBarState several times after picking images, because
                          // _addAttachmentFromXFile's base64 caching is fire-and-forget async:
                          // an immediate push cannot see it yet, so push again after 500/1500ms
                          // to let the cache become ready.
                          await _pickImages();
                          if (mounted) {
                            _pushInputBarState();
                            Future.delayed(const Duration(milliseconds: 500), () {
                              if (mounted) _pushInputBarState();
                            });
                            Future.delayed(const Duration(milliseconds: 1500), () {
                              if (mounted) _pushInputBarState();
                            });
                          }
                          break;
                        case 'exportChat':
                          _exportChatRecord();
                          break;
                        case 'importChat':
                          _importChatRecord();
                          break;
                        case 'clearChat':
                          _confirmClearChat();
                          break;
                        case 'manualSummarize':
                          _confirmManualSummarize();
                          break;
                        case 'noChar':
                          _snack('当前聊天没有关联角色');
                          break;
                        case 'openRegexPanel':
                          final charId =
                              payload['charId'] as String? ?? '';
                          if (charId.isNotEmpty) {
                            await _openRegexPanel(charId);
                          }
                          break;
                        case 'openBackgroundPanel':
                          await _openBackgroundPanel();
                          break;
                        case 'openTtsPanel':
                          await _openTtsPanel();
                          break;
                        case 'openVariablesPanel':
                          await _openVariablesPanel();
                          break;
                        case 'openChroniclePanel':
                          await _openChroniclePanel();
                          break;
                        case 'openWikiPanel':
                          await _openWikiPanel();
                          break;
                        case 'openImageGenPanel':
                          await _openImageGenPanel();
                          break;
                        case 'openSttPanel':
                          await _openSttPanel();
                          break;
                        case 'openSpritePanel':
                          await _openSpritePanel();
                          break;
                        case 'openWorldInfoPanel':
                          await _openWorldInfoPanel();
                          break;
                        case 'openCharacterBookPanel':
                          await _openWorldInfoPanel(initialScope: 'character');
                          break;
                        case 'openPresetPanel':
                          await _openPresetPanel();
                          break;
                        case 'openSamplingPanel':
                          await _openSamplingPanel();
                          break;
                        case 'openPersonaPanel':
                          await _openPersonaPanel();
                          break;
                        case 'openCharacterRegexPanel':
                          final charId = payload['charId'] as String? ??
                              ref.read(activeChatProvider).character?.id;
                          if (charId == null || charId.isEmpty) {
                            _snack('当前聊天没有关联角色');
                            break;
                          }
                          await _openRegexPanel(charId, initialTab: 'character');
                          break;
                        case 'openExportPanel':
                          await _openExportPanel();
                          break;
                        case 'openSearchPanel':
                          _snack('搜索功能开发中');
                          break;
                        case 'navigateTo':
                          final route = payload['route'] as String? ?? '';
                          if (route.isNotEmpty) await _navigateTo(route);
                          break;
                      }
                    });
                    // Settings panel action callback
                    _bridge.on(BridgeType.settingsPanelAction, (payload) async {
                      await _handleSettingsPanelAction(
                          (payload['panel'] as String?) ?? '',
                          (payload['action'] as String?) ?? '',
                          (payload['data'] as Map?)?.cast<String, dynamic>() ??
                              const <String, dynamic>{});
                    });
                    _bridge.on(BridgeType.settingsPanelClosed, (payload) {
                      debugPrint('[浮窗化] settings panel closed: ${payload['panel']}');
                    });
                    // WebView input bar bridge inbound (JS -> Flutter)
                    _bridge.on(BridgeType.inputSend, (payload) {
                      final text = (payload['text'] as String?) ?? '';
                      if (text.trim().isEmpty) return;
                      if (ref.read(activeChatProvider).isGenerating) return;
                      // Sync the WebView textarea's text into _inputController, which _sendMessage reads
                      _inputController.text = text;
                      _sendMessage();
                    });
                    _bridge.on(BridgeType.inputStop, (payload) {
                      HapticFeedback.mediumImpact();
                      ref.read(activeChatProvider.notifier).cancelGeneration();
                    });
                    _bridge.on(BridgeType.inputUpload, (payload) {
                      _handleInputUpload();
                    });
                    _bridge.on(BridgeType.inputFunc, (payload) {
                      _handleInputFunc();
                    });
                    _bridge.on(BridgeType.openSessionImages, (payload) {
                      if (!mounted) return;
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ChatImagesScreen(chatId: widget.chatId),
                      ));
                    });
                    _bridge.on(BridgeType.inputRemoveAttachment, (payload) {
                      final idx = (payload['index'] as num?)?.toInt() ?? -1;
                      _handleInputRemoveAttachment(idx);
                    });
                    // STT bridge inbound (JS -> Flutter, triggered by long-pressing the WebView textarea)
                    _bridge.on(BridgeType.sttStart, (payload) {
                      _sttStart();
                    });
                    _bridge.on(BridgeType.sttStop, (payload) {
                      _sttFinish();
                    });
                    // (a 350ms artificial delay used to sit here; removed -- the injection chain is ready, push the first frame directly)
                    if (!mounted) return;
                    await _pushMessages();
                    // Push the input bar's initial state once the WebView is ready (generating/stt/attachments)
                    _pushInputBarState();
                    // Legacy variable snapshot push: setMessages builds the iframe -> the patch
                    // requests a snapshot (__thRequestSnap), so broadcast the persisted MvuData
                    // entry by entry first; the card gates (getMvuData/getAllVariables) then have data.
                    await _pushInitialVarSnapshots();
                    // Once the opening prompt is ready, actively fill __chatMessages and fire
                    // chat_changed so MVU initCheck runs again (this time SillyTavern.chat is non-empty)
                    final initMsgsJson = jsonEncode(_serializeMessagesForMvu());
                    _controller?.evaluateJavascript(
                        source: 'if(window.__emitToEngine)window.__emitToEngine("chat_changed",[],$initMsgsJson);');
                    // Official naming alignment: in the facade's tavern_events, CHAT_CHANGED =
                    // 'chat_id_changed'; emitting only the old string would leave scripts listening
                    // for CHAT_CHANGED (Fox) blind -> emit both for old/new compatibility.
                    _controller?.evaluateJavascript(
                        source: 'if(window.__emitToEngine)window.__emitToEngine("chat_id_changed",[],$initMsgsJson);');
                    await Future.delayed(const Duration(milliseconds: 500));
                    } catch (e, st) {
                      debugPrint('[onLoadStop] 异常，强制撤遮罩: $e\n$st');
                    } finally {
                      // The mask's single removal point moved into finally: removed on success, exception, or early return
                      _webViewReady = true;
                      _tryHideMask();
                    }
                  },
                )
                      : const SizedBox.shrink(),
                ),
                ),
              // Bottom overlay: function panel + input bar, bottom-anchored.
              // The panel expands upward over the WebView content while the WebView keeps a constant
              // size and never resizes -- completely eliminating expand/collapse jank.
              // The input bar has moved into the WebView (chat_stage.html .chat-input-container) and
              // follows the keyboard automatically via the --keyboard-height CSS variable (see
              // _injectLayoutVars). The function panel also lives in the WebView (see the
              // openFunctionPanel bridge), so the Flutter-side bottom overlay no longer needs any
              // widget; this SizedBox keeps the layout unchanged.
              const Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox.shrink(),
              ),
            ],
        ),
      ),
          // Top bar frosted glass layer: blur over the wallpaper + a gray-black translucent base
          // (so white text stands out).
          // Only wallpaper sits behind it, so blur is safe and smooth. The text floats above via AppBar.
          // Scroll hide: linked to the AppBar's AnimatedSlide with the same parameters, revealing the
          // wallpaper strip once it slides out.
          // The WebView geometry stays fixed (no resize), staying inside the HC compositing performance red line.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            top: _topBarVisible
                ? 0
                : -(56 + MediaQuery.viewPaddingOf(context).top),
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              child: Container(
                height: 56 + MediaQuery.viewPaddingOf(context).top, // top bar two-line title 44 -> 56
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.82),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ], // end Stack children
      ), // end body Stack
        ),
        IgnorePointer(
          child: FadeTransition(
            opacity: _maskAnim,
            child: Container(
              color: activeGlassPalette.pageBackground,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: _starPulseUp ? 1.0 : 0.0),
                      duration: const Duration(milliseconds: 1200),
                      builder: (context, value, child) {
                        final t = (value - 0.5).abs() * 2;
                        final scale = 0.9 + (0.2 * (1 - t));
                        final opacity = 0.7 + (0.3 * (1 - t));

                        return Opacity(
                          opacity: opacity,
                          child: Transform.scale(
                            scale: scale,
                            child: const Icon(
                              Icons.stars,
                              size: 64,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                      onEnd: () {
                        if (mounted) {
                          setState(() {
                            _starPulseUp = !_starPulseUp;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '加载中…',
                      style: TextStyle(
                        fontSize: DesignTokens.fontSizeBodyLarge,
                        fontWeight: FontWeight.w500,
                        color: activeGlassPalette.primaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
     ),
    );
  }
  /// Truncate character names longer than 5 characters with an ellipsis
  String _truncateName(String name) {
    return name;
  }

 Future<dynamic> _handleSetInput(Map<String, dynamic> payload) async {
   final text = (payload['text'] as String?) ?? '';
   if (text.isNotEmpty && mounted) {
     _inputController.text = text;
     _inputController.selection = TextSelection.fromPosition(
       TextPosition(offset: _inputController.text.length),
     );
   }
   return {'ok': true};
 }
  /// TavernHelper triggerSlash: a stripped-down STscript executor.
  /// Supports `|` pipelines and covers the high-frequency opening commands of cards:
  ///   /send <text> - /sys <text>  -> send a message and trigger AI generation
  ///   /trigger                    -> trigger AI generation (skipped if a message was just sent, to avoid duplicates)
  ///   /cut <id>                   -> deliberately a no-op (does not delete user messages, protecting data)
  /// Other commands are ignored without erroring so card scripts are never interrupted.
  bool _slashCommandsRegistered = false;

  /// Platform command registration: send/gen/trigger etc. bridged to host capabilities.
  /// Callbacks do not capture this state; everything is injected via args.env. Registration is idempotent (overwrite).
  void _registerPlatformSlashCommands() {
    registerBasicSlashCommands();
    registerVariableSlashCommands();
    registerControlFlowSlashCommands();
    registerMathSlashCommands();
    registerGenerationSlashCommands();
    registerUiSlashCommands();
    registerFloorSlashCommands();
    if (_slashCommandsRegistered) return;
    _slashCommandsRegistered = true;

    SlashCommandRegistry.register(SlashCommand(name: 'send',
        callback: (args) async {
      final t = args.unnamedAsString();
      if (t.trim().isNotEmpty) await args.env?.sendMessage?.call(t);
      return '';
    }));
    SlashCommandRegistry.register(SlashCommand(name: 'sys',
        callback: (args) async {
      // /sys has no dedicated system message channel yet, so it degrades to a normal send
      final t = args.unnamedAsString();
      if (t.trim().isNotEmpty) await args.env?.sendMessage?.call(t);
      return '';
    }));
    SlashCommandRegistry.register(SlashCommand(name: 'sendas',
        callback: (args) async {
      // No "send as a specified identity" primitive yet, so it degrades to a normal send
      final t = args.unnamedAsString();
      if (t.trim().isNotEmpty) {
        await args.env?.sendMessage?.call(t);
      }
      KiraLogger().info('助手API', '/sendas 暂按普通发送处理');
      return '';
    }));
    SlashCommandRegistry.register(SlashCommand(name: 'trigger',
        callback: (args) async {
      await args.env?.triggerGeneration?.call();
      return '';
    }));
    SlashCommandRegistry.register(SlashCommand(name: 'gen',
        callback: (args) async {
      await args.env?.triggerGeneration?.call();
      return '';
    }));
    SlashCommandRegistry.register(SlashCommand(
        name: 'regenerate',
        aliases: ['regen'],
        callback: (args) async {
          await args.env?.regenerateLast?.call();
          return '';
        }));
    SlashCommandRegistry.register(SlashCommand(name: 'continue',
        callback: (args) async {
      await args.env?.continueGeneration?.call();
      return '';
    }));
    SlashCommandRegistry.register(SlashCommand(name: 'setinput',
        callback: (args) async {
      args.env?.setInput?.call(args.unnamedAsString());
      return '';
    }));
    SlashCommandRegistry.register(SlashCommand(name: 'cut',
        callback: (args) async {
      KiraLogger().info('助手API', '/cut 已忽略（保护数据）');
      return '';
    }));
  }

  /// toastr bridge: info/success/warning/error -> SnackBar.
  /// payload: {level: string, message: string}
  /// Dedupes identical text for 5 seconds so repeated script-room/engine-room initialization or
  /// looped calls do not fire a chain of popups.
  static final Map<String, DateTime> _toastLastShown = {};

  /// Noise reduction: fallback blacklist for MVU framework lifecycle notices (matched against the
  /// body when the old bundle has no title).
  /// The strings come from the actual mvu_bundle.js wording; note that the "requires an opening
  /// prompt" entry includes one extra particle character -- drop any character and it never matches.
  static const List<String> _mvuNoiseSnippets = [
    '开场白才能初始化变量',
    '构建信息',
    '世界书初始化变量被加载',
    '变量初始化失败',
    '不存在任何一条消息',
  ];

  Future<dynamic> _handleToast(Map<String, dynamic> payload) async {
    final level = payload['level']?.toString() ?? 'info';
    final message = payload['message']?.toString() ?? '';
    final title = payload['title']?.toString() ?? '';
    if (message.isEmpty || !mounted) return {'ok': true};
    // Noise reduction: MVU framework notices (build info / needs opening prompt / worldbook loaded...)
    // pop on every session initialization and are debug information -> log only.
    // Identified uniformly by the toastr title prefix (the fix), with the body blacklist merely as a
    // fallback for old bundles.
    if (title.startsWith('[MVU]')) {
      DebugLogService().log('$title $message', level: 'INFO', source: 'MVU提示');
      return {'ok': true, 'muted': true};
    }
    for (final noise in _mvuNoiseSnippets) {
      if (message.contains(noise)) {
        DebugLogService().log('[MVU][$level] $message', level: 'INFO', source: 'MVU提示');
        return {'ok': true, 'muted': true};
      }
    }
    final last = _toastLastShown[message];
    if (last != null && DateTime.now().difference(last) < const Duration(seconds: 5)) {
      KiraLogger().info('卡片toast', '[$level] 去重跳过: $message');
      return {'ok': true, 'deduped': true};
    }
    _toastLastShown[message] = DateTime.now();
    if (_toastLastShown.length > 64) {
      final cutoff = DateTime.now().subtract(const Duration(seconds: 5));
      _toastLastShown.removeWhere((_, t) => t.isBefore(cutoff));
    }
    KiraLogger().info('卡片toast', '[$level] $message');
    final snackBar = SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 4),
      backgroundColor: switch (level) {
        'error' => Colors.red.shade700,
        'warning' => Colors.orange.shade800,
        'success' => Colors.green.shade700,
        _ => null,
      },
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
    return {'ok': true};
  }

  /// callGenericPopup bridge: TEXT/CONFIRM/INPUT/DISPLAY -> HTML dialog (rendered inside the WebView).
  /// Return values align with POPUP_RESULT: CONFIRM -> 1 (null = cancel); INPUT -> string (null = cancel);
  /// TEXT/DISPLAY -> 1. The original Flutter ThPopupDialog moved into the WebView, avoiding the
  /// pause/resume compositing cost.
  Future<dynamic> _handlePopup(Map<String, dynamic> payload) async {
    final text = payload['text']?.toString() ?? '';
    final type = (payload['type'] as num?)?.toInt() ?? 1;
    final inputValue = payload['inputValue']?.toString() ?? '';
    if (!mounted) return null;
    KiraLogger().info('卡片弹窗', 'type=$type text=${text.length}字');
    switch (type) {
      case 2: // CONFIRM
        final ok = await _showHtmlConfirm(title: '确认', message: text);
        if (!mounted) return null;
        return ok ? 1 : null;
      case 3: // INPUT
        final value = await _showHtmlPrompt(
            title: '输入', message: text, initial: inputValue);
        if (!mounted) return null;
        return value;
      case 4: // DISPLAY (the original Flutter implementation had no buttons and barrierDismissible=false, so the dialog could not be closed; a close button is added here)
      case 1: // TEXT
      default:
        await _showHtmlConfirm(
            title: '提示', message: text, confirmText: '关闭', cancelText: '');
        if (!mounted) return null;
        return 1;
    }
  }

  /// th_triggerSlash: executes a slash script, returns {ok, pipe, isAborted, ...}.
  Future<dynamic> _handleTriggerSlash(Map<String, dynamic> payload) async {
    final command = (payload['command'] as String?) ?? '';
    if (command.trim().isEmpty) {
      return {'ok': true, 'pipe': ''};
    }
    KiraLogger().info('助手API', 'th_triggerSlash 收到命令');
    final result = await _runSlashScript(command);
    return {'ok': !result.isError, ...result.toMap()};
  }

  /// Backend for EJS execute(): runs it and returns the full SlashResult (including pipe).
  Future<dynamic> _handleExecuteSlash(Map<String, dynamic> payload) async {
    final command = (payload['command'] as String?) ??
        (payload['text'] as String?) ??
        '';
    final result = await _runSlashScript(command);
    return result.toMap();
  }

  /// Unified execution entry: register platform commands -> build env -> SlashRunner.
  Future<SlashResult> _runSlashScript(String command) async {
    _registerPlatformSlashCommands();
    final config = ref.read(llmConfigProvider);
    final notifier = ref.read(activeChatProvider.notifier);
    final env = SlashEnv(
      chatId: widget.chatId,
      sendMessage: (text) => notifier.sendMessage(text, config),
      triggerGeneration: () => notifier.regenerateLastMessage(config),
      continueGeneration: () => notifier.continueGeneration(config),
      regenerateLast: () => notifier.regenerateLastMessage(config),
      setInput: (text) {
        if (!mounted || text.isEmpty) return;
        _inputController.text = text;
        _inputController.selection = TextSelection.fromPosition(
          TextPosition(offset: _inputController.text.length),
        );
      },
      onUnsupported: (name) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('这张卡使用了暂不支持的命令（/$name），部分功能可能无法使用'),
          duration: const Duration(seconds: 3),
        ));
      },
      // Variable command landing point: always go through VariablesService + persist to disk + resync the engine
      onSetVar: (type, name, value, {index, asType}) async {
        final service = VariablesService.instance;
        if (type == 'global') {
          if (name.isEmpty) {
            await service.clearGlobalVariables();
          } else {
            await service.setGlobalVariable(name, value,
                index: index, asType: asType);
          }
          _syncVarsToEngine('global', service.getAllGlobalVariables());
        } else {
          if (name.isEmpty) {
            service.clearLocalVariables(widget.chatId);
          } else {
            service.setLocalVariable(widget.chatId, name, value,
                index: index, asType: asType);
          }
          await service.saveLocalVariablesToPrefs(widget.chatId);
          final msgs = ref.read(activeChatProvider).messages;
          _syncVarsToEngine('chat', service.getAllLocalVariables(widget.chatId),
              lastMsgId: msgs.isNotEmpty ? msgs.length - 1 : null);
        }
      },
      onDeleteVar: (type, name) async {
        final service = VariablesService.instance;
        if (type == 'global') {
          if (name.isEmpty) {
            await service.clearGlobalVariables();
          } else {
            await service.deleteGlobalVariable(name);
          }
          _syncVarsToEngine('global', service.getAllGlobalVariables());
        } else {
          if (name.isEmpty) {
            service.clearLocalVariables(widget.chatId);
          } else {
            service.deleteLocalVariable(widget.chatId, name);
          }
          await service.saveLocalVariablesToPrefs(widget.chatId);
          final msgs = ref.read(activeChatProvider).messages;
          _syncVarsToEngine('chat', service.getAllLocalVariables(widget.chatId),
              lastMsgId: msgs.isNotEmpty ? msgs.length - 1 : null);
        }
      },
      // /genraw: silently generate once, aggregating the stream back into text
      generateRaw: (prompt) async {
        final config = ref.read(llmConfigProvider);
        final messages = <Map<String, dynamic>>[
          {'role': 'user', 'content': prompt},
        ];
        final buffer = StringBuffer();
        await for (final chunk in ref
            .read(llmServiceProvider)
            .generateStreamWithReasoning(messages, config)) {
          if (chunk.content != null) {
            buffer.write(chunk.content);
          }
        }
        return buffer.toString();
      },
      // /buttons: button-choice dialog, the selected item returns to the pipe -> HTML bottom sheet
      showButtons: (labels) async {
        if (!mounted) return null;
        final result = await _showHtmlBottomSheet([
          for (final label in labels) {'text': label, 'value': label},
        ]);
        return result;
      },
      // Floor operations: message count / hide / swipe
      messageCount: () => ref.read(activeChatProvider).messages.length,
      setMessageHidden: (index, hidden) async {
        final msgs = ref.read(activeChatProvider).messages;
        if (index < 0 || index >= msgs.length) return;
        await ref
            .read(activeChatProvider.notifier)
            .setMessageHidden(msgs[index].id, hidden);
      },
      swipeTo: (index, swipeIndex) async {
        final notifier = ref.read(activeChatProvider.notifier);
        final msgs = ref.read(activeChatProvider).messages;
        if (index < 0 || index >= msgs.length) return;
        final m = msgs[index];
        if (swipeIndex == -1 || swipeIndex == -2) {
          // Relative: -1 = right (next swipe / new swipe), -2 = left (previous swipe)
          final cur = m.currentSwipeIndex < 0 ? 0 : m.currentSwipeIndex;
          final target = swipeIndex == -1 ? cur + 1 : cur - 1;
          if (target < 0) return;
          if (target < m.swipes.length) {
            await notifier.swipeMessage(m.id, target);
          } else if (index == msgs.length - 1) {
            // Swiping right past the end of the last floor = generate a new swipe
            await notifier.regenerateLastMessage(config);
          }
          return;
        }
        if (swipeIndex >= 0 && swipeIndex < m.swipes.length) {
          await notifier.swipeMessage(m.id, swipeIndex);
        }
      },
    );
    // Global variable macro hooks ({{getvar::}} etc.) -- overwrite, idempotent
    SlashRunner.globalMacroResolver = (input) =>
        VariablesService.instance.processVariableMacrosSync(
            input, chatId: widget.chatId);
    return SlashRunner.execute(command, env: env);
  }

  /// Message serialization for MVU: format matches _handleGetMessages; messages use the raw text
  /// (bypassing _serializeMessage's display polish so _.set commands survive).
  List<Map<String, dynamic>> _serializeMessagesForMvu() {
    final activeChat = ref.read(activeChatProvider);
    final messages = activeChat.messages;
    final defaultCharName = activeChat.character?.name ?? 'Assistant';
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < messages.length; i++) {
      final m = messages[i];
      final swipes = m.swipes;
      final swipeId = m.currentSwipeIndex;
      final currentContent =
          (swipes.isNotEmpty && swipeId >= 0 && swipeId < swipes.length)
              ? swipes[swipeId]
              : m.content;
      final name = switch (m.role) {
        MessageRole.user => 'User',
        MessageRole.assistant => m.characterName ?? defaultCharName,
        MessageRole.system => 'System',
      };
// Empty-card fallback: seed an empty MvuData base on message 0.
// MVU's getLastValidVariable->isMvuData requires the book to contain both stat_data and schema,
// otherwise update_variables.ts:1438 returns early for missing stat_data, which drops the _.set
// commands in AI replies. Empty cards have no worldbook/opening-prompt initvar, so this empty base
// lets AI-driven variable updates start from zero.
final effectiveSwipesData = (i == 0 && m.swipesData.isEmpty)
    ? <Map<String, dynamic>>[
        <String, dynamic>{
          'stat_data': <String, dynamic>{},
          'schema': <String, dynamic>{},
          'initialized_lorebooks': <String, dynamic>{},
          'delta_data': <String, dynamic>{},
          'display_data': <String, dynamic>{},
        }
      ]
    : m.swipesData;
      result.add(<String, dynamic>{
        'message_id': i,
        'name': name,
        'role': m.role.name,
        'is_hidden': m.isHidden, // truth value (/hide semantics)
        'message': currentContent,
        'data': <String, dynamic>{},
        'extra': <String, dynamic>{},
        'id': m.id,
        'index': i,
        'is_user': m.role == MessageRole.user,
        'content': m.content,
        'swipe_id': swipeId,
        'swipes': swipes,          // opening prompt text version array; MVU line 143 reads it to find <initvar>
          'variables': effectiveSwipesData,
          'swipes_data': effectiveSwipesData,
        });
      }
    return result;
    }

  /// thMvuParseMessage: forwards the card iframe's parseMessage request to the engine room's MVU bundle.
  /// The engine room's window.Mvu.parseMessage is the local qG function, not an RPC, so call it directly.
  /// fail-open: if the engine room is not ready or Mvu is missing, return old_data unchanged so the card flow is never blocked.
  Future<dynamic> _handleMvuParseMessage(Map<String, dynamic> payload) async {
    final message = payload['message'] as String? ?? '';
    final oldData = payload['old_data'] ?? <String, dynamic>{};
    final controller = _controller;
    if (controller == null) return oldData;

    try {
      final msgJson = jsonEncode(message);
      final oldJson = jsonEncode(oldData);
      final js = '''
        (async function() {
          try {
            var host = document.getElementById('__engineRoomHost');
            var f = host && host.querySelector('iframe[data-frame-id="engine-room"]');
            var w = f && f.contentWindow;
            if (!(w && w.Mvu && typeof w.Mvu.parseMessage === 'function')) {
              return $oldJson;
            }
            var result = await w.Mvu.parseMessage($msgJson, $oldJson);
            return JSON.stringify(result);
          } catch(e) {
            return $oldJson;
          }
        })()
      ''';
      final raw = await controller.evaluateJavascript(source: js);
      if (raw == null) return oldData;
      if (raw is String) {
        try {
          return jsonDecode(raw);
        } catch (_) {
          return oldData;
        }
      }
      return raw;
    } catch (e) {
      debugPrint('[thMvuParseMessage] error: $e');
      return oldData;
    }
  }

  /// EJS render bridge: receives text, sends it into the engine room to run ST-Prompt-Template's
  /// evalTemplate, and returns the rendered text.
  ///
  /// Primary scheme kick+poll: the kick script synchronously returns a seq id (no Promise crossing
  /// the bridge, so it stays stable even on old WebViews); the render result is written by the
  /// iframe callback into the outer window.__krRes slot and polled by Dart.
  /// fail-open: any failure falls back to substituteParams macro substitution, then to the raw text,
  /// so sending is never blocked.
  Future<String> _handleRenderEJS(Map<String, dynamic> payload) async {
    final text = payload['text'] as String? ?? '';
    if (text.isEmpty) return text;

    final controller = _controller;
    if (controller == null) return text;

    try {
      // E4: content without template tags does not start kick+poll; take the macro fast path.
      // (Preserves {{user}}/{{char}} macro behavior; saves 25-75ms per message vs the full kick)
      if (!text.contains('<%')) {
        print('[EJSD-5] no-tag fast path -> macro only len=${text.length}');
        return await _macroFallbackRender(controller, text);
      }

      // Supplement-check fix 1: pour the Dart authoritative variable snapshot into the engine room
      // mirror before rendering (same shape as __varSync).
      // Previously the mirror was only partially synced after MVU wrote through th_setVars, so it
      // restarted empty when the engine room was rebuilt, and global/chat variables written by
      // Flutter macros never entered the mirror -> EJS read stale or empty values.
      final snap = <String, dynamic>{
        'global': VariablesService.instance.getAllGlobalVariables(),
        'chat': VariablesService.instance.getAllLocalVariables(widget.chatId),
        'message': null,
        'mid': -1,
        'sid': 0,
        'floors': const <Map<String, dynamic>>[],
      };
      try {
        final msgs = ref.read(activeChatProvider).messages;
        // Feed ancestor floors: the current swipe variables of the most recent 30 floors, so dist
        // getvar(withMsg) can read history; the window matches _pushInitialVarSnapshots.
        final floors = _collectAncestorFloors(msgs, 30);
        snap['floors'] = floors;
        if (floors.isNotEmpty) {
          final last = floors.last;
          snap['mid'] = last['mid'];
          snap['sid'] = last['sid'];
          snap['message'] = last['data'];
        }
      } catch (_) {}

      final kickJs = '''
        (function() {
          try {
            var host = document.getElementById('__engineRoomHost');
            var f = host && host.querySelector('iframe[data-frame-id="engine-room"]');
            var w = f && f.contentWindow;
            if (!(w && w.EjsTemplate && typeof w.EjsTemplate.evalTemplate === 'function')) {
              try { if (typeof sendToFlutter === 'function') sendToFlutter('log', { text: '[EJSD-3] NOT-READY host=' + (!!host) + ' frame=' + (!!f) + ' ejsType=' + (typeof (w && w.EjsTemplate)) }); } catch (_e0) {}
              return -1;
            }
            try { if (typeof sendToFlutter === 'function') sendToFlutter('log', { text: '[EJSD-3] ready host=' + (!!host) + ' frame=' + (!!f) + ' ejsType=' + (typeof w.EjsTemplate) }); } catch (_e1) {}
            var snap = ${jsonEncode(snap)};
            try {
              if (w._TH) {
                w._TH.__varCache.global = snap.global || {};
                w._TH.__varCache.chat = snap.chat || {};
                // Multi-layer ancestor injection (up to 30 layers, current swipe)
                var fls = snap.floors || [];
                for (var fi = 0; fi < fls.length; fi++) {
                  var fl = fls[fi];
                  if (!fl || typeof fl.mid !== 'number' || fl.mid < 0) continue;
                  w._TH.__varCache.message[fl.mid] = fl.data || {};
                  w.chat[fl.mid] = w.chat[fl.mid] || {};
                  w.chat[fl.mid].variables = w.chat[fl.mid].variables || [];
                  w.chat[fl.mid].variables[fl.sid || 0] = fl.data || {};
                }
                // Compat: the newest layer still writes message/mid/sid
                if (snap.message && typeof snap.mid === 'number' && snap.mid >= 0) {
                  w._TH.__varCache.message[snap.mid] = snap.message;
                  w.chat[snap.mid] = w.chat[snap.mid] || {};
                  w.chat[snap.mid].variables = w.chat[snap.mid].variables || [];
                  w.chat[snap.mid].variables[snap.sid || 0] = snap.message;
                }
              }
              w.extension_settings = w.extension_settings || {};
              w.extension_settings.variables = w.extension_settings.variables || { global: {} };
              w.extension_settings.variables.global = snap.global || {};
              w.chat_metadata = w.chat_metadata || { variables: {} };
              w.chat_metadata.variables = snap.chat || {};
            } catch (e1) {}
            window.__krSeq = (window.__krSeq || 0) + 1;
            var id = window.__krSeq;
            window.__krRes = window.__krRes || {};
            window.__krRes[id] = null;
            // One-time dump of all template-scope keys (EjsTemplate.prepareContext is the upstream Hf)
            if (!window.__krTplDumped) {
              window.__krTplDumped = true;
              try {
                w.EjsTemplate.prepareContext().then(function(ctx) {
                  var detail = {};
                  var ks = Object.keys(ctx);
                  for (var ki = 0; ki < ks.length; ki++) {
                    try { detail[ks[ki]] = typeof ctx[ks[ki]]; } catch (e5) { detail[ks[ki]] = 'unreadable'; }
                  }
                  sendToFlutter('log', { text: '[TPL-1] scope keys=' + ks.length + ' ' + JSON.stringify(detail) });
                }).catch(function(e6) {
                  sendToFlutter('log', { text: '[TPL-1] prepareContext ERR ' + e6 });
                });
              } catch (e7) {
                sendToFlutter('log', { text: '[TPL-1] ERR ' + e7 });
              }
            }
            var t = ${jsonEncode(text)};
            // Pre-render snapshot: after evalTemplate, diff the global/chat
            // buckets and persist setvar/incvar/delvar changes made by the
            // template to Dart via th_setVars.
            window.__krPre = window.__krPre || {};
            try {
              window.__krPre[id] = {
                global: JSON.parse(JSON.stringify(((w.extension_settings && w.extension_settings.variables) || {}).global || {})),
                chat: JSON.parse(JSON.stringify((w.chat_metadata && w.chat_metadata.variables) || {}))
              };
            } catch (ep) { window.__krPre[id] = null; }
            w.EjsTemplate.evalTemplate(t).then(function(v) {
              var diff = null;
              try {
                var pre = window.__krPre[id];
                delete window.__krPre[id];
                if (pre) {
                  var gAfter = ((w.extension_settings && w.extension_settings.variables) || {}).global || {};
                  var cAfter = (w.chat_metadata && w.chat_metadata.variables) || {};
                  // Values written to the bucket are JSON strings; unwrap one
                  // layer before writing back to Dart
                  var unwrap = function(x) {
                    if (typeof x === 'string') { try { return JSON.parse(x); } catch (eu) { return x; } }
                    return x;
                  };
                  var bucketDiff = function(before, after) {
                    var set = {}, del = [], has = false;
                    for (var k in after) {
                      if (!Object.prototype.hasOwnProperty.call(after, k)) continue;
                      if (!before || JSON.stringify(before[k]) !== JSON.stringify(after[k])) {
                        set[k] = unwrap(after[k]); has = true;
                      }
                    }
                    if (before) {
                      for (var k2 in before) {
                        if (!Object.prototype.hasOwnProperty.call(before, k2)) continue;
                        if (!Object.prototype.hasOwnProperty.call(after, k2)) { del.push(k2); has = true; }
                      }
                    }
                    return has ? { set: set, del: del } : null;
                  };
                  var gd = bucketDiff(pre.global, gAfter);
                  var cd = bucketDiff(pre.chat, cAfter);
                  if (gd || cd) diff = { global: gd, chat: cd };
                }
              } catch (ed2) { diff = null; }
              try { if (typeof sendToFlutter === 'function') sendToFlutter('log', { text: '[EJSD-4] slot-write realm_outer=' + (window === parent) + ' id=' + id + ' vlen=' + ((v == null) ? -1 : String(v).length) }); } catch (_e5) {}
              window.__krRes[id] = { ok: true, v: (v == null ? '' : String(v)), diff: diff };
            }).catch(function(e2) {
              try { delete window.__krPre[id]; } catch (_e7) {}
              try { if (typeof sendToFlutter === 'function') sendToFlutter('log', { text: '[EJSD-4] slot-write(CATCH) realm_outer=' + (window === parent) + ' id=' + id + ' err=' + String((e2 && (e2.stack || e2.message)) || e2).slice(0, 120) }); } catch (_e6) {}
              window.__krRes[id] = { ok: false, e: String((e2 && (e2.stack || e2.message)) || e2) };
            });
            return id;
          } catch (e3) {
            return -1;
          }
        })();
      ''';

      final idRaw = await controller.evaluateJavascript(source: kickJs);
      final idNum = idRaw is num ? idRaw.toInt() : int.tryParse(idRaw?.toString() ?? '');
      print('[EJSD-3] kick returned id=$idNum raw=$idRaw');
      if (idNum == null || idNum < 0) {
        print('[EJSD-5] kick -1 -> macro fallback');
        return await _macroFallbackRender(controller, text);
      }

      const pollInterval = Duration(milliseconds: 20);
      const deadline = Duration(milliseconds: 8000);
      final end = DateTime.now().add(deadline);
      while (DateTime.now().isBefore(end)) {
        await Future<void>.delayed(pollInterval);
        final pollJs =
            '(function(){var r=window.__krRes&&window.__krRes[$idNum];'
            "if(r){delete window.__krRes[$idNum];return JSON.stringify(r);}return 'null';})()";
        final raw = await controller.evaluateJavascript(source: pollJs);
        final rawStr = raw?.toString();
        if (rawStr == null || rawStr.isEmpty || rawStr == 'null') continue;
        Map<String, dynamic>? res;
        try {
          res = (jsonDecode(rawStr) as Map?)?.cast<String, dynamic>();
        } catch (_) {
          print('[EJSD-5] poll payload unparseable len=${rawStr.length} head=${rawStr.substring(0, rawStr.length > 80 ? 80 : rawStr.length)}');
        }
        if (res == null) continue;
        if (res['ok'] == true) {
          final v = res['v']?.toString() ?? '';
          // EJS write-back bridge: first persist the in-template setvar/delvar bucket changes;
          // this must happen before the empty-string hard guard (a template that only writes
          // variables outputs an empty string, and that write-back must not be lost).
          if (res['diff'] is Map) {
            await _persistEjsWriteback(
                (res['diff'] as Map).cast<String, dynamic>());
          }
          print('[EJSD-5] evalTemplate ok vlen=${v.length}');
          // E3 hard guard: null/undefined/empty string always falls back to the raw text; never hand empty content to the LLM
          if (v.isEmpty) {
            print('[EJSD-5] evalTemplate EMPTY result -> raw text');
            return text;
          }
          return v;
        }
        print('[EJSD-5] evalTemplate ERR -> macro fallback: ${res['e']}');
        break;
      }
      print('[EJSD-5] poll TIMEOUT -> macro fallback');
      controller.evaluateJavascript(
          source:
              '(function(){try{if(window.__krPre)delete window.__krPre[$idNum];}catch(_){}})()');
      return await _macroFallbackRender(controller, text);
    } catch (e) {
      KiraLogger().info('EJS渲染', '渲染失败 error=$e');
      return text;
    }
  }

  /// EJS write-back bridge: persist the global/chat bucket changes diffed by the engine room into Dart.
  /// Scope routing matches the dist semantics; the message bucket is not persisted (prevents MVU
  /// double-writing, it stays in the mirror only).
  /// After writing back, call _syncVarsToEngine once so the Trinity cache re-merges (same as P6-1 §1.4 step 5).
  Future<void> _persistEjsWriteback(Map<String, dynamic> diff) async {
    try {
      final service = VariablesService.instance;

      // global bucket
      final g = diff['global'];
      if (g is Map) {
        final gm = g.cast<String, dynamic>();
        final setMap =
            (gm['set'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
        final delList = gm['del'] as List? ?? const [];
        for (final k in delList) {
          if (k is String && k.isNotEmpty) {
            await service.deleteGlobalVariable(k);
          }
        }
        if (setMap.isNotEmpty) {
          await _handleSetVariables(
              {'vars': setMap, 'option': const {'type': 'global'}});
        }
        if (setMap.isNotEmpty || delList.isNotEmpty) {
          _syncVarsToEngine('global', service.getAllGlobalVariables());
          KiraLogger().info(
              'EJS写回', 'global set=${setMap.keys.toList()} del=$delList');
        }
      }

      // chat bucket
      final c = diff['chat'];
      if (c is Map) {
        final cm = c.cast<String, dynamic>();
        final setMap =
            (cm['set'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
        final delList = cm['del'] as List? ?? const [];
        var deleted = false;
        for (final k in delList) {
          if (k is String && k.isNotEmpty) {
            service.deleteLocalVariable(widget.chatId, k);
            deleted = true;
          }
        }
        if (setMap.isNotEmpty) {
          // The setMap branch already persists + re-merges in the engine room (reads the whole table back)
          await _handleSetVariables(
              {'vars': setMap, 'option': const {'type': 'chat'}});
          KiraLogger().info(
              'EJS写回', 'chat set=${setMap.keys.toList()} del=$delList');
        } else if (deleted) {
          await service.saveLocalVariablesToPrefs(widget.chatId);
          final readBack = service.getAllLocalVariables(widget.chatId);
          final msgsNow = ref.read(activeChatProvider).messages;
          _syncVarsToEngine('chat', readBack,
              lastMsgId: msgsNow.isNotEmpty ? msgsNow.length - 1 : null);
          KiraLogger().info('EJS写回', 'chat del=$delList');
        }
      }
    } catch (e) {
      // fail-open: a write-back failure is only logged and never blocks rendering
      KiraLogger().info('EJS写回', '持久化失败 error=$e');
    }
  }

  /// Macro substitution fallback (original th_renderEJS behavior): {{user}}/{{char}}/<user>/<char>.
  Future<String> _macroFallbackRender(dynamic controller, String text) async {
    print('[EJSD-5] macroFallback applied len=${text.length}');
    try {
      final js = '''
        (function() {
          try {
            var text = ${jsonEncode(text)};
            if (typeof window._TH !== 'undefined' && typeof window._TH.substituteParams === 'function') {
              return window._TH.substituteParams(text);
            }
            return text;
          } catch (e) {
            console.error('[EJS渲染错误]', e);
            return text;
          }
        })();
      ''';
      final result = await controller.evaluateJavascript(source: js);
      // E3 hard guard: if the macro result is empty (null/non-string/empty string), fall back to the raw text
      if (result != null && result is String && result.isNotEmpty) return result;
      return text;
    } catch (e) {
      KiraLogger().info('EJS渲染', '宏替换兜底也失败 error=$e');
      return text;
    }
  }
  /// TavernHelper generateRaw: MVU extra-model parsing goes through here.
  /// Splits cfg.custom_api into a temporary LLMConfig, flattens ordered_prompts+injects into
  /// messages, sends one request via llm_service, and returns the text verbatim to MVU (MVU parses
  /// _.set itself and then persists via setVariables).
  Future<dynamic> _handleGenerateRaw(Map<String, dynamic> payload) async {
    final cfg = (payload['cfg'] as Map?)?.cast<String, dynamic>() ?? {};
    final customApi = (cfg['custom_api'] as Map?)?.cast<String, dynamic>();

    KiraLogger().info('额外模型', 'th_generateRaw 被调 hasCustomApi=${customApi != null}');

    // 1) Build the config: use an independent config when custom_api exists, otherwise reuse the main chat config ("same as the plug")
    LLMConfig config = ref.read(llmConfigProvider);
    if (customApi != null) {
      final apiUrl = (customApi['apiurl'] as String?)?.trim();
      final key = (customApi['key'] as String?)?.trim();
      final model = (customApi['model'] as String?)?.trim();
      config = config.copyWith(
        apiUrl: (apiUrl != null && apiUrl.isNotEmpty) ? apiUrl : config.apiUrl,
        apiKey: (key != null && key.isNotEmpty) ? key : config.apiKey,
        model: (model != null && model.isNotEmpty) ? model : config.model,
        maxTokens: _asInt(customApi['max_tokens']) ?? config.maxTokens,
        temperature: _asDouble(customApi['temperature']) ?? config.temperature,
        topP: _asDouble(customApi['top_p']) ?? config.topP,
        frequencyPenalty:
            _asDouble(customApi['frequency_penalty']) ?? config.frequencyPenalty,
        presencePenalty:
            _asDouble(customApi['presence_penalty']) ?? config.presencePenalty,
      );
      KiraLogger().info('额外模型',
          'custom_api model=${config.model} url=${config.apiUrl} maxTok=${config.maxTokens} temp=${config.temperature}');
    } else {
      KiraLogger().info('额外模型', 'custom_api 为空，沿用主对话 config model=${config.model}');
    }

    // 2) Flatten ordered_prompts + injects into messages (B+: concatenate in order first)
    final messages = <Map<String, dynamic>>[];
    void appendList(dynamic list) {
      if (list is! List) return;
      for (final e in list) {
        if (e is Map) {
          final role = (e['role'] as String?) ?? 'system';
          final content = (e['content'] as String?) ?? '';
          if (content.isNotEmpty) {
            messages.add({'role': role, 'content': content});
          }
        } else if (e == 'chat_history') {
          // Expand the real chat history (last N messages) to fix the empty past_observe shell
          final n = _asInt(cfg['max_chat_history']) ?? 10;
          final history = ref.read(activeChatProvider).messages;
          final recent =
              history.length > n ? history.sublist(history.length - n) : history;
          
          for (var h = 0; h < recent.length; h++) {
            final m0 = recent[h];
            final sw0 = m0.swipes;
            final si = m0.currentSwipeIndex;
            final c = (sw0.isNotEmpty && si >= 0 && si < sw0.length) ? sw0[si] : m0.content;
          }

          for (int i = 0; i < recent.length; i++) {
            final m = recent[i];
            // Consistent with _serializeMessagesForMvu: prefer the current swipe's body text
            final sw = m.swipes;
            final swIdx = m.currentSwipeIndex;
            final mContent =
                (sw.isNotEmpty && swIdx >= 0 && swIdx < sw.length)
                    ? sw[swIdx]
                    : m.content;
            if (mContent.trim().isEmpty) continue;

            final r = switch (m.role) {
              MessageRole.user => 'user',
              MessageRole.assistant => 'assistant',
              MessageRole.system => 'system',
            };

            final isSecondLast = (i == recent.length - 2);
            final isLast = (i == recent.length - 1);
            String prefix = '';
            if (isSecondLast) prefix = '[上一轮] ';
            if (isLast) prefix = '[本轮最新剧情] ';

            String content = mContent;
            if (i > 0) content = '\n\n$content';

            messages.add({'role': r, 'content': prefix + content});
          }
        }
        // Other string placeholders (persona/char/world_info/user_input) are ignored in stage B
      }
    }

    appendList(cfg['ordered_prompts']);
    appendList(cfg['injects']);
    // Inject the variable state (before the update): trace back through message swipesData to take
    // the last valid stat_data, matching MVU getLastValidVariable's read semantics. No longer reads
    // the empty storage A.
    try {
      final histMsgs = ref.read(activeChatProvider).messages;
      Map<String, dynamic>? currentStat;
      for (int i = histMsgs.length - 1; i >= 0; i--) {
        final sd = histMsgs[i].swipesData;
        final swIdx = histMsgs[i].currentSwipeIndex;
        if (sd.isEmpty) continue;
        final idx = (swIdx >= 0 && swIdx < sd.length) ? swIdx : 0;
        final stat = sd[idx]['stat_data'];
        if (stat != null) {
          currentStat = Map<String, dynamic>.from(stat as Map);
          break;
        }
      }
      if (currentStat != null) {
        messages.add({
          'role': 'system',
          'content': '更新前变量状态：\n${jsonEncode(currentStat)}',
        });
      } else {
      }
    } catch (e) {
      KiraLogger().info('额外模型', '注入变量状态失败: $e');
    }

    // MVU's user_input is the user turn content, add it -- otherwise everything is a system turn and Claude-like channels return 422
    final userInput = (cfg['user_input'] as String?)?.trim();
    if (userInput != null && userInput.isNotEmpty) {
      messages.add({'role': 'user', 'content': userInput});
    } else if (!messages.any((m) => m['role'] == 'user') && messages.isNotEmpty) {
      messages.last['role'] = 'user';
    }

    KiraLogger().info('额外模型', '拍平后 messages 条数=${messages.length}');

    if (messages.isEmpty) {
      KiraLogger().info('额外模型', 'messages 为空，返回空串');
      return '';
    }

    // 3) Call llm_service once, aggregating the stream into the full text
    try {
      final buffer = StringBuffer();
      await for (final chunk
          in ref.read(llmServiceProvider).generateStreamWithReasoning(messages, config)) {
        if (chunk.content != null) {
          buffer.write(chunk.content);
        }
      }
      final text = buffer.toString();
      KiraLogger().info('额外模型', 'generateRaw 返回文本长度=${text.length}');
      return text;
    } catch (e) {
      KiraLogger().info('额外模型', 'generateRaw 请求失败: $e');
      // On failure return an empty string so MVU takes its own retry/degradation path instead of throwing across the bridge
      return '';
    }
  }

  int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  double? _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
  /// Flutter-side implementation of TavernHelper getChatMessages.
  /// Reads the current chat messages and maps them to the TavernHelper-aligned format.
  /// Single data source: ActiveChatNotifier.state.messages (prevents cross-chat mix-ups).
  Future<dynamic> _handleGetMessages(Map<String, dynamic> payload) async {
    // Accept both parameter names: spec include_swipes / legacy include_swipe
    final start = (payload['start'] as int?) ?? 0;
    final includeSwipe = (payload['include_swipes'] as bool?) ??
        (payload['include_swipe'] as bool?) ??
        false;
    KiraLogger().info('助手API', 'th_getMessages 被调用 start=$start swipe=$includeSwipe');

    final activeChat = ref.read(activeChatProvider);
    final messages = activeChat.messages;
    // Name derivation: assistant/system prefer the cached character name on the message, then the current character name
    final defaultCharName = activeChat.character?.name ?? 'Assistant';
    KiraLogger().info('助手API', 'th_getMessages 读到 ${messages.length} 条消息');
    final result = <Map<String, dynamic>>[];

    for (var i = start; i < messages.length; i++) {
      final m = messages[i];
      final swipes = m.swipes;
      final swipeId = m.currentSwipeIndex;
      // Current swipe content: take the current swipe when swipes exist, otherwise use content
      final currentContent =
          (swipes.isNotEmpty && swipeId >= 0 && swipeId < swipes.length)
              ? swipes[swipeId]
              : m.content;
      final name = switch (m.role) {
        MessageRole.user => 'User',
        MessageRole.assistant => m.characterName ?? defaultCharName,
        MessageRole.system => 'System',
      };
      // Align with the TavernHelper ChatMessage spec fields
      final map = <String, dynamic>{
        'message_id': i,
        'name': name,
        'role': m.role.name, // system / assistant / user
        'is_hidden': m.isHidden, // truth value (/hide semantics)
        'message': currentContent,
        'data': <String, dynamic>{},
        'extra': <String, dynamic>{},
        // Legacy field compatibility (so places depending on the old format do not break)
        'id': m.id,
        'index': i,
        'is_user': m.role == MessageRole.user,
        'content': m.content,
        'swipe_id': swipeId,
        'variables': m.swipesData,
      };
      if (includeSwipe) {
        // Align with the ChatMessageSwiped spec
        map['swipes'] = swipes;
        map['swipes_data'] = m.swipesData;
        map['swipes_info'] =
            List.generate(swipes.length, (_) => <String, dynamic>{});
      }
      result.add(map);
    }
    return result;
  }

  /// TavernHelper getVariables: returns the whole variable table for a scope.
  /// option.type: 'chat' (local) / 'global', defaulting to 'chat'.
  Future<dynamic> _handleGetVariables(Map<String, dynamic> payload) async {
    final option = (payload['option'] as Map?)?.cast<String, dynamic>() ?? {};
    final type = (option['type'] as String?) ?? 'chat';
    final service = VariablesService.instance;
    KiraLogger().info('助手API', 'th_getVars 被调用 type=$type');

    if (type == 'global') {
      return service.getAllGlobalVariables();
    }
    // Script-level variables (normally read through the facade's local cache; this is the fallback for the direct bridge path).
    if (type == 'script') {
      final scriptId = (option['script_id'] as String?) ??
          (option['scriptId'] as String?) ??
          '';
      return service.getScriptVariables(scriptId);
    }
    // Default: chat-local variables
    final result = service.getAllLocalVariables(widget.chatId);
    return result;
  }

  /// TavernHelper setVariables: writes to the variable table for a scope and persists it.
  /// Semantics: the incoming vars are written key by key (insertOrAssign), not replacing the whole table.
  Future<dynamic> _handleSetVariables(Map<String, dynamic> payload) async {
    final vars = (payload['vars'] as Map?)?.cast<String, dynamic>() ?? {};
    final option = (payload['option'] as Map?)?.cast<String, dynamic>() ?? {};
    final type = (option['type'] as String?) ?? 'chat';
    final service = VariablesService.instance;
    KiraLogger().info('助手API', 'th_setVars 被调用 type=$type keys=${vars.keys.toList()}');

    // Script-level variables: isolated by script_id, whole-table write, persisted at device level.
    if (type == 'script') {
      final scriptId = (option['script_id'] as String?) ??
          (option['scriptId'] as String?) ??
          '';
      if (scriptId.isEmpty) {
        KiraLogger().info('助手API', 'th_setVars type=script 但缺少 script_id,忽略');
        return {};
      }
      await service.setScriptVariables(scriptId, vars);
      return service.getScriptVariables(scriptId);
    }

    if (type == 'global') {
      for (final entry in vars.entries) {
        await service.setGlobalVariable(entry.key, entry.value);
      }
      return service.getAllGlobalVariables();
    }
    // Message-level persistence: write the whole MvuData into the message's swipesData and persist.
    // MVU's replaceVariables uses type:message but often omits message_id (it relies on the host to
    // implicitly locate the "current message").
    // When missing, fall back to the last message -- matching getLastValidVariable's backward
    // read semantics from the tail.
    if (type == 'message') {
      final messageId = option['message_id'] as int?;
      final notifier = ref.read(activeChatProvider.notifier);
      final messages = ref.read(activeChatProvider).messages;

      // Pick the target message: use a valid message_id, otherwise fall back to the last one
      int? targetIndex;
      if (messageId != null && messageId >= 0 && messageId < messages.length) {
        targetIndex = messageId;
      } else if (messages.isNotEmpty) {
        targetIndex = messages.length - 1;
        debugPrint('[setVars修复] message_id 缺失($messageId)，落到最后一条 mid=$targetIndex');
      }

      if (targetIndex != null) {
        final target = messages[targetIndex];
        final swipeId = target.currentSwipeIndex < 0 ? 0 : target.currentSwipeIndex;
        // Capture the last valid stat_data before the update (for MVU bridge comparison)
        Map<String, dynamic>? chronicleOldStat;
        for (var i = targetIndex; i >= 0; i--) {
          final sd = messages[i].swipesData;
          if (sd.isEmpty) continue;
          final swIdx = messages[i].currentSwipeIndex >= 0 &&
                  messages[i].currentSwipeIndex < sd.length
              ? messages[i].currentSwipeIndex
              : 0;
          final stat = sd[swIdx]['stat_data'];
          if (stat is Map && stat.isNotEmpty) {
            chronicleOldStat = Map<String, dynamic>.from(stat);
            break;
          }
        }
        final newSwipesData =
            List<Map<String, dynamic>>.from(target.swipesData);
        while (newSwipesData.length <= swipeId) {
          newSwipesData.add(<String, dynamic>{});
        }
        newSwipesData[swipeId] = Map<String, dynamic>.from(vars);
        await notifier.updateMessageSwipesData(target.id, newSwipesData);
        debugPrint('[setVars修复] 已写入 mid=$targetIndex id=${target.id} swipe=$swipeId');
        debugPrint('[setVars修复] 已写入 mid=$targetIndex swipe=$swipeId keys=${vars.keys.toList()}');
        debugPrint('[setVars落点] targetIndex=$targetIndex '
            '写入的stat_data=${jsonEncode(vars['stat_data'])}');
        // MVU -> Chronicle bridge: significant numeric changes become memory events (async, reads MVU without writing back)
        if (vars['stat_data'] is Map && (vars['stat_data'] as Map).isNotEmpty) {
          unawaited(ref.read(chronicleOrchestratorProvider).onMvuVariableUpdated(
                widget.chatId,
                chronicleOldStat,
                Map<String, dynamic>.from(vars['stat_data'] as Map),
              ));
        }
        // Sync the engine room mirror
        _syncVarsToEngine('message', vars, messageId: targetIndex, lastMsgId: targetIndex, swipeId: swipeId);
        return vars;
      }
      // Only when there is no message at all (extreme case) does it land on the chat fallback
      debugPrint('[setVars修复] 无任何消息，回退 chat 分支');
    }
    // Default chat-local variables: write to memory + persist to disk
    for (final entry in vars.entries) {
      service.setLocalVariable(widget.chatId, entry.key, entry.value);
    }
    await service.saveLocalVariablesToPrefs(widget.chatId);
    final readBack = service.getAllLocalVariables(widget.chatId);
    // Supply lastMsgId: both the card gate and the latest resolution depend on it; when missing the card side keeps its old value
    final msgsNow = ref.read(activeChatProvider).messages;
    _syncVarsToEngine('chat', readBack, lastMsgId: msgsNow.isNotEmpty ? msgsNow.length - 1 : null);
    return readBack;
  }

  /// Injects a regex rule snapshot (consumed by the synchronous getRegexedString engine in the
  /// engine room / script room / card facade).
  /// Compact field form: f=findRegex r=replaceString p=placement indexes o=order d=disabled
  /// mo=markdownOnly po=promptOnly e=runOnEdit t=trimStrings min/max=depth range.
  Future<void> _injectRegexRules(dynamic c) async {
    try {
      final character = ref.read(activeChatProvider).character;
      final combined = ref.read(combinedRegexScriptsProvider(character?.id));
      final rules = combined
          .map((s) => <String, dynamic>{
                'f': s.findRegex,
                'r': s.replaceString,
                'p': s.placement.map((e) => e.index).toList(),
                'o': s.order,
                'd': s.disabled,
                'mo': s.markdownOnly,
                'po': s.promptOnly,
                'e': s.runOnEdit,
                't': s.trimStrings,
                'min': s.minDepth,
                'max': s.maxDepth,
              })
          .toList();
      await c.evaluateJavascript(
          source: 'window.__KIRA_REGEX_RULES=${jsonEncode(rules)};');
    } catch (e) {
      debugPrint('[正则规则注入] 失败: $e');
    }
  }

  /// Ancestor floor snapshot: the current swipe variables of the most recent N floors.
  List<Map<String, dynamic>> _collectAncestorFloors(
      List<ChatMessage> msgs, int maxFloors) {
    final floors = <Map<String, dynamic>>[];
    for (var i = msgs.length - 1; i >= 0 && floors.length < maxFloors; i--) {
      final sd = msgs[i].swipesData;
      if (sd.isEmpty) continue;
      final swIdx =
          msgs[i].currentSwipeIndex < 0 ? 0 : msgs[i].currentSwipeIndex;
      final sid = swIdx < sd.length ? swIdx : 0;
      floors.add({'mid': i, 'sid': sid, 'data': sd[sid]});
    }
    return floors.reversed.toList(); // ascending (old -> new)
  }

  /// Reads the current prompt sections list (for the floating panel).
  /// Returns [{type, name, enabled, order}, ...] for every section (regardless of enabled) so the
  /// panel can render all toggles in one pass.
  Future<List<Map<String, dynamic>>> _handlePmGetSections(
      Map<String, dynamic> payload) async {
    final config = ref.read(promptManagerProvider);
    if (!_pmIdentifiersLogged) {
      _pmIdentifiersLogged = true;
      debugPrint('[PM] sections identifiers=${config.sortedSections.map((s) => {
        'identifier': s.identifier,
        'type': s.type.name,
        'name': s.name,
      }).toList()}');
    }
    return config.sortedSections
        .map((s) => {
              'type': s.type.name,
              'identifier': s.identifier,
              'name': s.name,
              'enabled': s.enabled,
              'order': s.order,
            })
        .toList();
  }

  /// Toggles a section (floating panel click lands here).
  /// payload: { type: 'nsfw' } or { type: 'nsfw', enabled: false }.
  /// If enabled is provided it is set directly; otherwise it toggles. Returns the updated section list.
  Future<List<Map<String, dynamic>>> _handlePmToggleSection(
      Map<String, dynamic> payload) async {
    final typeName = payload['type']?.toString() ?? '';
    if (typeName.isEmpty) return _handlePmGetSections(payload);
    final ident = payload['identifier']?.toString();
    debugPrint('[PM] toggle payload=$payload');
    final config = ref.read(promptManagerProvider);
    final type = PromptSectionType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => PromptSectionType.custom,
    );
    final matches = ident == null || ident.isEmpty
        ? config.sections.where((s) =>
            s.type == type && s.identifier == null).toList()
        : config.sections.where((s) => s.identifier == ident).toList();
    debugPrint('[预设球] 匹配请求: type=$typeName, identifier=$ident, name=${payload['name']}');
    debugPrint('[预设球] 匹配结果: 找到${matches.length}个section');
    if (matches.length != 1) {
      debugPrint('[预设球] 匹配失败: 期望1个，实际${matches.length}个');
      debugPrint('[PM] toggle 拒绝: 命中数=${matches.length} type=$typeName ident=$ident');
      return _handlePmGetSections(payload);
    }
    final cur = matches.single;
    final next =
        payload.containsKey('enabled') ? payload['enabled'] == true : !cur.enabled;
    final notifier = ref.read(promptManagerProvider.notifier);
    await notifier.updateSection(cur.copyWith(enabled: next));
    // No active push; the listener automatically pushes pmSectionsChanged, but return the current state so the panel can refresh instantly
    return _handlePmGetSections(payload);
  }
  // Preset management API (ST Preset contract)
  // Fix for Fox's broken links, part 2: the full getPreset('in_use')/updatePresetWith chain.
  // Shape aligns with ST: { name, settings:{should_stream,...}, prompts:[{identifier,name,role,content,enabled,...}] }.
  // The 'in_use' name resolves to the active preset; active values for settings/prompts are read
  // from the live providers (llmConfigProvider.streamEnabled / promptManagerProvider.sections).

  /// ST prompt entry <- PromptSection (key set taken from the common subset of the ST tavern-helper Preset contract)
  Map<String, dynamic> _stPromptFromSection(PromptSection s) => {
        'identifier': s.identifier ?? s.type.name,
        'name': s.name,
        'system_prompt': s.role == null || s.role == 'system',
        'role': s.role ?? 'system',
        'content': s.content ?? '',
        'enabled': s.enabled,
        'injection_position': s.injectionPosition ?? 0,
        'injection_depth': s.injectionDepth ?? 4,
        'injection_order': s.order,
        'order': s.order,
        'forbid_overrides': false,
        'marker': false,
      };

  /// AIPreset -> ST Preset JSON. With live=true, settings/prompts take the live provider values.
  Map<String, dynamic> _stPresetJson(AIPreset preset, {required bool live}) {
    final passthrough = _stSettingsPassthrough[preset.name];
    final streamEnabled = live
        ? ref.read(llmConfigProvider).streamEnabled
        : preset.generationSettings.streamEnabled;
    final settings = <String, dynamic>{
      if (passthrough != null) ...passthrough, // unknown keys laid down as the base
      'should_stream': streamEnabled, // modeled keys overridden with their true values
      'allow_sending_images':
          (passthrough?['allow_sending_images'] as String?) ?? 'auto',
    };
    final sections = live
        ? ref.read(promptManagerProvider).sections
        : (preset.promptManagerConfig?.sections ??
            PromptManagerConfig.defaultConfig().sections);
    return {
      'name': preset.name,
      'settings': settings,
      'prompts': sections.map(_stPromptFromSection).toList(),
    };
  }

  /// Resolve a preset by name: 'in_use' -> the active one, otherwise a full lookup by name.
  (AIPreset?, bool) _resolveStPreset(String? name) {
    if (name == null || name.isEmpty || name == 'in_use') {
      final active = ref.read(activeAIPresetProvider);
      return (active, true);
    }
    final all = ref.read(allAIPresetsProvider);
    final hit = all.firstWhereOrNull((p) => p.name == name);
    if (hit == null) return (null, false);
    final active = ref.read(activeAIPresetProvider);
    return (hit, hit.id == active?.id);
  }

  Future<dynamic> _handleGetPresetNames(Map<String, dynamic> payload) async {
    try {
      return ref.read(allAIPresetsProvider).map((p) => p.name).toList();
    } catch (e) {
      debugPrint('[getPresetNames] 错误: $e');
      return <String>[];
    }
  }

  Future<dynamic> _handleGetLoadedPresetName(Map<String, dynamic> payload) async {
    return ref.read(activeAIPresetProvider)?.name ?? '';
  }

  Future<dynamic> _handleGetPreset(Map<String, dynamic> payload) async {
    try {
      final name = payload['name'] as String?;
      if (name == null || name.isEmpty) return null;
      final cacheKey = name;

      // TTL cache hit
      final cached = _presetReadCache[cacheKey];
      final cachedAt = _presetCacheAt[cacheKey];
      if (cached != null &&
          cachedAt != null &&
          DateTime.now().difference(cachedAt) < _presetCacheTTL) {
        debugPrint('[getPreset] 缓存命中: $name');
        return cached;
      }

      // In-flight coalescing: concurrent reads of the same preset are computed once
      final inflight = _presetReadInflight[cacheKey];
      if (inflight != null) {
        debugPrint('[getPreset] 在途合并: $name');
        return await inflight.future;
      }
      final completer = Completer<dynamic>();
      _presetReadInflight[cacheKey] = completer;
      try {
        final (preset, live) = _resolveStPreset(name);
        if (preset == null) {
          completer.complete(null);
          return null;
        }
        final result = _stPresetJson(preset, live: live);
        _presetReadCache[cacheKey] = result;
        _presetCacheAt[cacheKey] = DateTime.now();
        completer.complete(result);
        return result;
      } finally {
        _presetReadInflight.remove(cacheKey);
      }
    } catch (e) {
      debugPrint('[getPreset] 错误: $e');
      return null;
    }
  }

  /// setPreset(name, preset): write back.
  /// - settings.should_stream -> generation settings (in_use takes effect immediately in llmConfig);
  ///   all other settings keys go into the session passthrough bag (laid down verbatim as the base
  ///   on the next getPreset, with no field whitelist).
  /// - prompts -> merged into PromptManagerConfig by identifier
  ///   (in_use applies synchronously to the live promptManagerProvider and persists the active
  ///   preset, so switching presets back and forth loses nothing).
  /// - On completion emits preset_changed / settings_updated events (for Fox's invalidate/preset/load hooks).
  Future<dynamic> _handleSetPreset(Map<String, dynamic> payload) async {
    try {
      final name = payload['name'] as String?;
      final presetData = payload['preset'] as Map<String, dynamic>?;
      if (name == null || name.isEmpty || presetData == null) {
        return {'ok': false, 'error': 'name and preset required'};
      }
      final (target, isLive) = _resolveStPreset(name);
      if (target == null) return {'ok': false, 'error': 'preset not found: $name'};

      final settings = presetData['settings'] as Map<String, dynamic>?;
      final shouldStream = settings?['should_stream'] as bool?;
      if (settings != null) {
        _stSettingsPassthrough[target.name] =
            Map<String, dynamic>.from(settings);
      }

      // prompts -> sections merge (by identifier; unrecognized entries are skipped, no whitelist)
      PromptManagerConfig? newConfig;
      final prompts = presetData['prompts'] as List<dynamic>?;
      if (prompts != null) {
        final baseSections = isLive
            ? ref.read(promptManagerProvider).sections
            : (target.promptManagerConfig?.sections ??
                PromptManagerConfig.defaultConfig().sections);
        final sections = List<PromptSection>.from(baseSections);
        for (final raw in prompts) {
          if (raw is! Map) continue;
          final p = raw.cast<String, dynamic>();
          final ident = (p['identifier'] ?? p['name'])?.toString();
          if (ident == null || ident.isEmpty) continue;
          final idx = sections.indexWhere(
              (s) => (s.identifier ?? s.type.name) == ident);
          if (idx < 0) continue;
          final cur = sections[idx];
          sections[idx] = cur.copyWith(
            content: p['content'] as String?,
            enabled: p['enabled'] as bool?,
            role: p['role'] as String?,
            name: (p['name'] as String?)?.isNotEmpty == true
                ? p['name'] as String
                : null,
            order: (p['injection_order'] as num? ?? p['order'] as num?)
                ?.toInt(),
            injectionPosition: (p['injection_position'] as num?)?.toInt(),
            injectionDepth: (p['injection_depth'] as num?)?.toInt(),
          );
        }
        newConfig = PromptManagerConfig(sections: sections);
      }

      // Apply to live (in_use only): the streaming toggle + prompt config take effect immediately
      if (isLive) {
        if (shouldStream != null) {
          // updateStreamEnabled is a synchronous setter (persists internally) and must not be awaited
          ref.read(llmConfigProvider.notifier).updateStreamEnabled(shouldStream);
        }
        if (newConfig != null) {
          await ref.read(promptManagerProvider.notifier).applyPreset(
                PromptManagerPreset(
                  id: target.id,
                  name: target.name,
                  config: newConfig,
                  createdAt: target.createdAt,
                  updatedAt: DateTime.now(),
                ),
              );
        }
      }

      // Persist into the preset object (first edit of a built-in converts it to a custom override, same as _saveCurrentToActivePreset)
      final updatedPreset = target.copyWith(
        isBuiltIn: false,
        updatedAt: DateTime.now(),
        generationSettings: shouldStream != null
            ? target.generationSettings.copyWith(streamEnabled: shouldStream)
            : null,
        promptManagerConfig: newConfig,
      );
      final customPresets = ref.read(aiCustomPresetsProvider);
      final notifier = ref.read(aiCustomPresetsProvider.notifier);
      if (customPresets.any((p) => p.id == target.id)) {
        await notifier.updatePreset(updatedPreset);
      } else {
        await notifier.addPreset(updatedPreset);
      }

      // Successful write -> immediately invalidate the read cache (both sides: this layer plus each
      // script room's JS-side __KIRA_PRESET_CACHE cleared by the preset_changed event)
      _presetReadCache.clear();
      _presetCacheAt.clear();

      _emitPresetEvent('preset_changed');
      _emitPresetEvent('settings_updated');
      debugPrint('[setPreset] 已保存: ${target.name} (live=$isLive, '
          'stream=$shouldStream, prompts=${prompts?.length ?? '-'})');
      return {'ok': true};
    } catch (e) {
      debugPrint('[setPreset] 错误: $e');
      return {'ok': false, 'error': '$e'};
    }
  }

  /// generate: triggers a full generation turn (Fox auto-advance / second generation).
  /// Arg shape (TH contract): a 'normal'/'continue' string, or {user_input:'text'}.
  /// The bridge's 30s timeout is shorter than LLM generation time -> the result is not bound to the
  /// return value; completion/cancel is notified by the generation_ended event (see 3.3), so scripts
  /// should follow the event rather than the return value.
  Future<dynamic> _handleGenerate(Map<String, dynamic> payload) async {
    try {
      if (ref.read(activeChatProvider).isGenerating) {
        debugPrint('[generate] 生成中,忽略重复触发');
        return '';
      }
      final config = ref.read(llmConfigProvider);
      final arg = payload['arg'];
      String? userInput;
      if (arg is Map) {
        userInput = (arg['user_input'] as String?)?.trim();
      }
      if (userInput != null && userInput.isNotEmpty) {
        // {user_input} semantics: insert a user message and trigger generation
        await ref.read(activeChatProvider.notifier).sendMessage(userInput, config);
      } else {
        // Both 'normal'/'continue' mean: have the AI generate the next message from the current chat
        await ref.read(activeChatProvider.notifier).continueGeneration(config);
      }
      return '';
    } catch (e) {
      debugPrint('[generate] 错误: $e');
      return '';
    }
  }

  /// stopGeneration: cancels the current generation.
  Future<dynamic> _handleStopGeneration(Map<String, dynamic> payload) async {
    try {
      await ref.read(activeChatProvider.notifier).cancelGeneration();
      return {'ok': true};
    } catch (e) {
      debugPrint('[stopGeneration] 错误: $e');
      return {'ok': false, 'error': '$e'};
    }
  }

  /// Sends a preset/settings event to the engine room (JS __emitToEngine relays it to all script rooms).
  void _emitPresetEvent(String type) {
    _controller?.evaluateJavascript(
        source:
            'if(window.__emitToEngine)window.__emitToEngine(${jsonEncode(type)},[],null);');
  }

  /// Reverse sync: push the variable table into the engine room mirror.
  void _syncVarsToEngine(String type, Map<String, dynamic> data, {int? messageId, int? lastMsgId, int? swipeId}) {
    final dataJson = jsonEncode(data);
    final midArg = messageId?.toString() ?? 'null';
    final lastArg = lastMsgId?.toString() ?? 'null';
    final swipeArg = swipeId?.toString() ?? 'null';
    _controller?.evaluateJavascript(
        source: 'if(window.__syncVarsToEngine)window.__syncVarsToEngine('
            '"$type",$dataJson,$midArg,$lastArg,$swipeArg);');
  }

  /// After startup/rebuild, push the legacy MvuData (swipesData) entry by entry into
  /// __syncVarsToEngine so the card iframe's window.Mvu gates (which need message-level stat_data)
  /// and snapshot reads have data available.
  /// Only the most recent 30 are pushed (matching the first-frame render batch) to avoid injecting
  /// the whole package for long chats.
  Future<void> _pushInitialVarSnapshots() async {
    try {
      final messages = ref.read(activeChatProvider).messages;
      final lastIdx = messages.length - 1;
      if (lastIdx < 0) return;
      final start = lastIdx > 29 ? lastIdx - 29 : 0;
      for (var i = start; i <= lastIdx; i++) {
        final m = messages[i];
        if (m.swipesData.isEmpty) continue;
        final sid = m.currentSwipeIndex < 0 ? 0 : m.currentSwipeIndex;
        final data = (sid < m.swipesData.length) ? m.swipesData[sid] : m.swipesData.first;
        if (data.isEmpty) continue;
        _syncVarsToEngine('message', data, messageId: i, lastMsgId: lastIdx, swipeId: sid);
      }
      // Also push the chat variables in one shot (card gate fallback + for getAllVariables merging)
      final chatVars = VariablesService.instance.getAllLocalVariables(widget.chatId);
      if (chatVars.isNotEmpty) {
        _syncVarsToEngine('chat', chatVars, lastMsgId: lastIdx);
      }
      KiraLogger().info('MVU', '存量变量快照已推送 start=$start lastIdx=$lastIdx');
    } catch (e) {
      KiraLogger().info('MVU', '存量变量快照推送失败: $e');
    }
  }
  /// Push the character's primary worldbook name into the engine room mirror (for MVU isExtraModelSupported to read synchronously)
  Future<void> _syncPrimaryLorebookToEngine() async {
    try {
      final charId = ref.read(activeChatProvider).character?.id;
      if (charId == null) return;
      final repo = ref.read(worldInfoRepositoryProvider);
      final books = await repo.getWorldInfosForCharacter(charId);
      // A2 fix: the primary book is the first book with entries -- an auto empty shell sorted first no longer shadows the real book
      final names = books.map((b) => b.name).whereType<String>().toList();
      String? primary;
      for (final b in books) {
        if (b.enabled && b.entries.isNotEmpty) {
          primary = b.name;
          break;
        }
      }
      primary ??= names.isNotEmpty ? names.first : null;
      _controller?.evaluateJavascript(
          source: 'if(window.__syncPrimaryLorebook)'
              'window.__syncPrimaryLorebook(${jsonEncode(primary)});');
    } catch (e) {
      debugPrint('[主世界书同步] 失败: $e');
    }
  }

  // Worldbook API handlers
  // Serializes WorldInfoEntry into card-side (SillyTavern-style) JSON
  Map<String, dynamic> _wiEntryToJson(models.WorldInfoEntry e) => {
        'uid': e.id,
        'worldId': e.worldInfoId,
        // Supply the name field (ST semantics: name = comment, the display name).
        //   Daoyuan only matches entries with e.name === / e.name.includes(...) (e.g. pretty.js:1312-1314),
        //   so a missing name throws "Cannot read properties of undefined (reading 'includes')".
        'name': e.comment,
        'keys': e.keys,
        'secondary_keys': e.secondaryKeys,
        'content': e.content,
        'comment': e.comment,
        'enabled': e.enabled,
        'constant': e.constant,
        'selective': e.selective,
        'order': e.insertionOrder,
        'position': e.position.index,
        'depth': e.depth,
        'probability': e.probability,
      };

  /// Returns the worldbook list bound to the current character (including global ones).
  Future<dynamic> _handleWiGetLorebooks(Map<String, dynamic> payload) async {
    // Read cache: in a steady 5s polling loop the TTL window keeps hitting the cache instead of the DB
    final cached = _wiCacheLookup('th_wiGetLorebooks');
    if (!identical(cached, _wiCacheMiss)) return cached;
    final WorldInfoRepository repo = ref.read(worldInfoRepositoryProvider);
    final all = await repo.getAllWorldInfos();
    final result = all.map((b) => b.name).toList();
    _wiCacheStore('th_wiGetLorebooks', null, result);
    return result;
  }

  /// Creates a worldbook (SillyTavern createLorebook). payload: {name}
  Future<dynamic> _handleWiCreateBook(Map<String, dynamic> payload) async {
    _wiCacheInvalidate('th_wiCreateBook');
    final WorldInfoRepository repo = ref.read(worldInfoRepositoryProvider);
    final name = payload['name'] as String?;
    if (name == null || name.isEmpty) return {'ok': false, 'error': 'name required'};
    final all = await repo.getAllWorldInfos();
    final exists = all.where((b) => b.name == name);
    if (exists.isNotEmpty) {
      return {'ok': true, 'name': name, 'existed': true};
    }
    final book = await repo.createWorldInfo(name: name, isGlobal: true);
    return {'ok': true, 'name': book.name, 'id': book.id};
  }

  /// Fetches worldbook entries (over the bridge for MVU/EJS). payload: {name}
  /// A2 fix: merge semantics -- returns all of the character's bound and enabled worldbook entries
  /// (sorted uniformly by insertion_order), no longer shadowed by auto empty shells;
  /// when the table side is empty it falls back to the character card's embedded character_book
  /// (legacy data compatibility).
  Future<dynamic> _handleWiGetEntries(Map<String, dynamic> payload) async {
    // Read cache: the key includes the requested book name; under merge semantics null/same name gives the same result
    final reqName = payload['name'] as String?;
    final cached = _wiCacheLookup('th_wiGetEntries', reqName);
    if (!identical(cached, _wiCacheMiss)) return cached;
    final WorldInfoRepository repo = ref.read(worldInfoRepositoryProvider);
    final charId = ref.read(activeChatProvider).character?.id;

    // Fetch a book precisely by name: both Daoyuan and MVU request books individually by name
    //   (TH getWorldbook(name) semantics).
    //   The old merge semantics made Daoyuan select entries from other books when it asked for an
    //   unbound/disabled book, and made MVU's per-book requests return duplicated merged sets.
    //   Now: when reqName is present, first look for an exact hit across the whole repository and
    //   return all of that book's entries on a hit (including disabled ones, since Daoyuan manages
    //   the toggles); only on a miss or an empty book does it fall through to the merge + embedded
    //   fallback below (keeping the 519 embedded fallback from regressing).
    if (reqName != null && reqName.isNotEmpty) {
      final allBooks = await repo.getAllWorldInfos();
      final target = allBooks.firstWhereOrNull((b) => b.name == reqName);
      if (target != null && target.entries.isNotEmpty) {
        final entries = target.entries.map(_wiEntryToJson).toList()
          ..sort((a, b) =>
              (a['order'] as int? ?? 0).compareTo(b['order'] as int? ?? 0));
        _wiCacheStore('th_wiGetEntries', reqName, entries);
        return entries;
      }
    }

    final merged = <Map<String, dynamic>>[];
    if (charId != null) {
      final books = await repo.getWorldInfosForCharacter(charId);
      for (final b in books) {
        if (!b.enabled || b.entries.isEmpty) continue;
        merged.addAll(b.entries.map(_wiEntryToJson));
      }
      merged.sort((a, b) => (a['order'] as int? ?? 0).compareTo(b['order'] as int? ?? 0));
    }
    if (merged.isEmpty) {
      // Fallback: the embedded character_book (legacy data compatibility when the table side has no entries)
      final book = ref.read(activeChatProvider).character?.characterBook;
      final fallback = <Map<String, dynamic>>[];
      if (book != null) {
        final name = reqName;
        // The name returned by 519 comes back verbatim; if it does not match, return nothing
        if (name == null || (book.name ?? 'character_book') == name) {
          fallback.addAll(book.entries.map(_charBookEntryToMvu));
        }
      }
      _wiCacheStore('th_wiGetEntries', reqName, fallback);
      return fallback;
    }
    _wiCacheStore('th_wiGetEntries', reqName, merged);
    return merged;
  }
  Future<dynamic> _handleWiGetLorebookSettings(Map<String, dynamic> payload) async {
    // MVU takes selected_global_lorebooks from here as the globally enabled worldbooks
    // Return an empty list first so MVU does not error and can keep running
    return {'selected_global_lorebooks': <String>[], 'overflow_alert': false};
  }

  /// getTavernRegexes read-only bridge: maps RegexScript -> ST TavernRegex shape.
  /// type=global returns only global; character returns the merged global + current character set
  /// (combined, disabled scripts already filtered);
  /// the platform has no preset dimension, so it degrades to the same as global. Sorted by order
  /// (execution order).
  Future<dynamic> _handleThGetRegexes(Map<String, dynamic> payload) async {
    final type = payload['type']?.toString() ?? 'global';
    final character = ref.read(activeChatProvider).character;
    List<RegexScript> scripts;
    switch (type) {
      case 'character':
        scripts = ref.read(combinedRegexScriptsProvider(character?.id));
        break;
      case 'global':
      case 'preset':
      default:
        scripts = ref.read(globalRegexScriptsProvider).where((s) => !s.disabled).toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    }
    return scripts.map(_regexScriptToTavernRegex).toList();
  }

  /// RegexScript -> TavernRegex (official tavern_regex.d.ts shape: source/destination boolean buckets)
  Map<String, dynamic> _regexScriptToTavernRegex(RegexScript s) => {
        'id': s.id,
        'script_name': s.scriptName,
        'enabled': !s.disabled,
        'scope': s.scriptType == RegexScriptType.character ? 'character' : 'global',
        'find_regex': s.findRegex,
        'replace_string': s.replaceString,
        'trim_strings': s.trimStrings,
        'source': {
          'user_input': s.placement.contains(RegexPlacement.userInput),
          'ai_output': s.placement.contains(RegexPlacement.aiOutput),
          'slash_command': s.placement.contains(RegexPlacement.slashCommand),
          'world_info': s.placement.contains(RegexPlacement.worldInfo),
          'reasoning': s.placement.contains(RegexPlacement.reasoning),
        },
        'destination': {
          'display': !s.promptOnly,
          'prompt': s.promptOnly || !s.markdownOnly,
        },
        'run_on_edit': s.runOnEdit,
        'min_depth': s.minDepth,
        'max_depth': s.maxDepth,
      };

  /// extensionSettings persistence: Daoyuan/MVU panel write-back -> extract mvu_settings into MvuSettings.
  /// Merge semantics: null keys keep the platform's current values (the JS side's MVU writes back a
  /// fully parsed object every time, see mvu_bundle:3154-3161, but merging defensively key by key
  /// avoids a future partial object wiping platform values).
  /// After persisting, re-push __KIRA_MAIN_ENV so the main document's getContext picks up the new
  /// values synchronously within the session.
  Future<dynamic> _handleSaveExtensionSettings(Map<String, dynamic> payload) async {
    try {
      final settings = payload['settings'] as Map<String, dynamic>?;
      if (settings == null) return {'ok': false, 'error': 'settings required'};
      final mvu = settings['mvu_settings'] as Map<String, dynamic>?;
      if (mvu == null) return {'ok': true}; // no mvu section, nothing to do
      final notify = mvu['通知'] as Map<String, dynamic>?;
      final extra = mvu['额外模型解析配置'] as Map<String, dynamic>?;
      final cur = ref.read(mvuSettingsProvider);
      final updated = cur.copyWith(
        updateMode: mvu['更新方式'] as String?,
        notifyFrameworkLoaded: notify?['MVU框架加载成功'] as bool?,
        notifyInitSuccess: notify?['变量初始化成功'] as bool?,
        notifyVarError: notify?['变量更新出错'] as bool?,
        // All four keys live under the notification bucket (Daoyuan's In() writes all four there),
        // previously they were read from the extra-model parsing config bucket -> always null -> that key stayed stuck
        // at the baked default
        notifyExtraParsing: notify?['额外模型解析中'] as bool?,
        jailbreakScheme: extra?['破限方案'] as String?,
        autoRequest: extra?['启用自动请求'] as bool?,
        maxChatHistory: (extra?['max_chat_history'] as num?)?.toInt(),
        modelSource: extra?['模型来源'] as String?,
        apiUrl: extra?['api地址'] as String?,
        apiKey: extra?['密钥'] as String?,
        modelName: extra?['模型名称'] as String?,
        // Persist the whole raw object verbatim (MVU's internal already-notified flags etc. all
        // live in it; previously only three sections were kept, so lost flags made the upgrade
        // reminder pop again on every page entry)
        webRaw: mvu,
      );
      await ref.read(mvuSettingsProvider.notifier).applyFromWeb(updated);
      // Same-origin refresh of the main document's __KIRA_MAIN_ENV, so Daoyuan reads the new values next turn
      final c = _controller;
      if (c != null) await _injectMainEnv(c);
      // After saving settings, emit SETTINGS_UPDATED (Fox listens to it for panel state sync)
      _emitPresetEvent('settings_updated');
      return {'ok': true};
    } catch (e) {
      debugPrint('[saveExtensionSettings] 错误: $e');
      return {'ok': false, 'error': '$e'};
    }
  }


  Future<dynamic> _handleWiSetLorebookSettings(Map<String, dynamic> payload) async {
    return {'ok': true};
  }
  /// Embedded worldbook entry -> card-side (SillyTavern-style) JSON, fields aligned with _wiEntryToJson.
  /// MVU reads comment (to filter [initvar]) and content (to extract the <initvar> block).
  Map<String, dynamic> _charBookEntryToMvu(CharacterBookEntry e) => {
        'uid': e.id,
        // Supply the name field (aligned with _wiEntryToJson, required by Daoyuan's .name.includes).
        'name': e.name.isNotEmpty ? e.name : e.comment,
        'keys': e.keys,
        'secondary_keys': e.secondaryKeys,
        'content': e.content,
        'comment': e.comment,
        'enabled': e.enabled,
        'constant': e.constant,
        'selective': e.selective,
        'order': e.insertionOrder,
        'position': e.position,
      };

  /// Worldbooks bound to the character. MVU expects a {primary, additional:[...]} structure.
  Future<dynamic> _handleWiGetCharLorebooks(Map<String, dynamic> payload) async {
    // Read cache: reuse for the same character within 2s
    final cached = _wiCacheLookup('th_wiGetCharLorebooks');
    if (!identical(cached, _wiCacheMiss)) return cached;
    final WorldInfoRepository repo = ref.read(worldInfoRepositoryProvider);
    final charId = ref.read(activeChatProvider).character?.id;
    if (charId == null) {
      const empty = {'primary': null, 'additional': <String>[]};
      _wiCacheStore('th_wiGetCharLorebooks', null, empty);
      return empty;
    }
    final books = await repo.getWorldInfosForCharacter(charId);
    // A2 fix: primary is the first book that is enabled and has entries, so an empty shell does not shadow the real book
    final names = books.map((b) => b.name).whereType<String>().toList();
    String? primary;
    final additional = <String>[];
    var primaryDecided = false;
    for (final b in books) {
      final n = b.name;
      if (!primaryDecided && b.enabled && b.entries.isNotEmpty) {
        primary = n;
        primaryDecided = true;
        continue;
      }
      if (n != primary) additional.add(n);
    }
    if (!primaryDecided && names.isNotEmpty) {
      primary = names.first;
      additional.remove(primary);
    }
    final result = {
      'primary': primary,
      'additional': additional,
    };
    _wiCacheStore('th_wiGetCharLorebooks', null, result);
    return result;
  }

  /// Updates entries (finds existing entries by uid and changes content/keywords). payload: {worldId/name, entries:[...]}
  Future<dynamic> _handleWiSetEntries(Map<String, dynamic> payload) async {
    _wiCacheInvalidate('th_wiSetEntries');
    final WorldInfoRepository repo = ref.read(worldInfoRepositoryProvider);
    final worldId = await _wiResolveWorldId(repo, payload);
    if (worldId == null) return {'ok': false, 'error': 'lorebook not found'};
    final incoming = (payload['entries'] as List?) ?? [];
    final existing = await repo.getEntriesForWorldInfo(worldId);
    final byId = {for (final e in existing) e.id: e};
    var updated = 0;
    for (final raw in incoming) {
      final m = (raw as Map).cast<String, dynamic>();
      final uid = m['uid'] as String?;
      final target = uid != null ? byId[uid] : null;
      if (target == null) continue;
      final next = target.copyWith(
        keys: (m['keys'] as List?)?.cast<String>() ?? target.keys,
        secondaryKeys: (m['secondary_keys'] as List?)?.cast<String>() ?? target.secondaryKeys,
        content: (m['content'] as String?) ?? target.content,
        comment: (m['comment'] as String?) ?? target.comment,
        enabled: (m['enabled'] as bool?) ?? target.enabled,
      );
      await repo.updateEntry(next);
      updated++;
    }
    return {'ok': true, 'updated': updated};
  }
  /// TavernHelper setChatMessages (plural): MVU uses it to seed per-swipe variables into messages.
  /// Each item is {message_id, swipes_data:[...]}, writing swipes_data into ChatMessage.swipesData.
  Future<dynamic> _handleSetMessages(Map<String, dynamic> payload) async {
    final msgs = (payload['msgs'] as List?) ?? const [];
    final messages = ref.read(activeChatProvider).messages;
    final notifier = ref.read(activeChatProvider.notifier);
    // Fox's forceRefreshAll sends all floors (message_id only, no swipes_data); previously an
    // unconditional _pushMessages caused a pointless "empty update -> full re-render" loop
    // (P5-11 part 6). Now re-render only when something was actually written.
    var changed = false;
    for (final raw in msgs) {
      if (raw is! Map) continue;
      final mid = raw['message_id'] as int?;
      if (mid == null || mid < 0 || mid >= messages.length) continue;
      final swipesData = (raw['swipes_data'] as List?)
              ?.map((e) => (e as Map).cast<String, dynamic>())
              .toList() ??
          const <Map<String, dynamic>>[];
      if (swipesData.isEmpty) {
        continue;
      }
      await notifier.updateMessageSwipesData(messages[mid].id, swipesData);
      changed = true;
    }
    if (changed && mounted) await _pushMessages();
    return {'ok': true};
  }

  /// Creates entries. payload: {worldId/name, entries:[{keys, content, ...}]}
  Future<dynamic> _handleWiCreateEntries(Map<String, dynamic> payload) async {
    _wiCacheInvalidate('th_wiCreateEntries');
    final WorldInfoRepository repo = ref.read(worldInfoRepositoryProvider);
    final worldId = await _wiResolveWorldId(repo, payload);
    if (worldId == null) return {'ok': false, 'error': 'lorebook not found'};
    final incoming = (payload['entries'] as List?) ?? [];
    final created = <String>[];
    for (final raw in incoming) {
      final m = (raw as Map).cast<String, dynamic>();
      final e = await repo.addEntry(
        worldInfoId: worldId,
        keys: (m['keys'] as List?)?.cast<String>() ?? [],
        content: (m['content'] as String?) ?? '',
        secondaryKeys: (m['secondary_keys'] as List?)?.cast<String>(),
        comment: m['comment'] as String?,
      );
      created.add(e.id);
    }
    return {'ok': true, 'created': created};
  }

  /// Deletes entries. payload: {uids:[...]}
  Future<dynamic> _handleWiDeleteEntries(Map<String, dynamic> payload) async {
    _wiCacheInvalidate('th_wiDeleteEntries');
    final WorldInfoRepository repo = ref.read(worldInfoRepositoryProvider);
    final uids = (payload['uids'] as List?)?.cast<String>() ?? [];
    for (final uid in uids) {
      await repo.deleteEntry(uid);
    }
    return {'ok': true, 'deleted': uids.length};
  }

  /// Resolves the target worldbook id from the payload (accepts worldId or name).
  Future<String?> _wiResolveWorldId(WorldInfoRepository repo, Map<String, dynamic> payload) async {
    final worldId = payload['worldId'] as String?;
    if (worldId != null) return worldId;
    final name = payload['name'] as String?;
    if (name == null) return null;
    final all = await repo.getAllWorldInfos();
    final matches = all.where((b) => b.name == name);
    return matches.isEmpty ? null : matches.first.id;
  }
  /// Flutter-side implementation of TavernHelper setChatMessage.
  /// Locates the message by floor index, switches the swipe or rewrites the content, then triggers
  /// a WebView re-render.
  /// Single data source: activeChatProvider (prevents cross-chat mix-ups).
  Future<dynamic> _handleSetMessage(Map<String, dynamic> payload) async {
    final index = payload['index'] as int?;
    final swipeId = payload['swipe_id'] as int?;
    final content = payload['content'] as String?;
    final refresh = (payload['refresh'] != null); // refresh when the refresh field is present
    KiraLogger().info('助手API',
        'th_setMessage 被调用 index=$index swipe_id=$swipeId refresh=$refresh');

    final messages = ref.read(activeChatProvider).messages;
    if (index == null || index < 0 || index >= messages.length) {
      return {'ok': false, 'reason': 'index out of range'};
    }
    final target = messages[index];
    final notifier = ref.read(activeChatProvider.notifier);

    KiraLogger().info('助手API',
        'th_setMessage 第$index楼 swipes数量=${target.swipes.length}');
    if (swipeId != null &&
        swipeId >= 0 &&
        swipeId < target.swipes.length) {
      // Prefer switching by swipe: taking content from the swipes array is more reliable
      KiraLogger().info('助手API', 'th_setMessage 切换到 swipe $swipeId');
      await notifier.swipeMessage(target.id, swipeId);
    } else if (content != null) {
      // Without a valid swipe_id, rewrite the current floor's content
      await notifier.editMessage(target.id, content);
    } else {
      return {'ok': false, 'reason': 'no swipe_id or content'};
    }

    if (refresh && mounted) {
      await _pushMessages();
    }
    return {'ok': true};
  }

  Widget _buildAvatar(Character? character) {
    final avatarPath = character?.assets?.avatarPath;
    final avatarUrl = character?.assets?.avatarUrl;

    // Top bar avatar 32 -> 24: fits the 32dp short top bar
    const Widget fallback = CircleAvatar(
      radius: 12,
      backgroundColor: Colors.white12,
      child: Icon(Icons.person, size: 14, color: Colors.white54),
    );

    if (avatarPath != null && avatarPath.isNotEmpty) {
      // Use the shared component: it handles relative -> absolute path conversion + caching, fixing the top bar avatar not showing
      return ClipOval(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CharacterAvatarImage(
            imagePath: avatarPath,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
          ),
        ),
      );
    } else if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 12,
        backgroundColor: Colors.white12,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }
    return fallback;
  }
  /// Dark frosted-glass top bar: short, semi-transparent, airy
  PreferredSizeWidget _buildGlassAppBar(
      Character? character, String? activeModel) {
    return AppBar(
      // 56: two-line title (character name + model name); the same height must stay in sync across:
      // bridge barHeight / the frosted layer's AnimatedPositioned / __KIRA_TOP_INSET__ baked in
      toolbarHeight: 56,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Colors.transparent, // the background is left to the frosted layer in the body
      titleSpacing: 12,
      // Simple chevron < replacing the arrow_back (arrow with a bar) that AppBar inserts automatically;
      // goes through _exitChat, the same exit flow as the system back gesture
      leading: IconButton(
        tooltip: '返回',
        icon: const Icon(Icons.chevron_left, size: 28),
        color: activeGlassPalette.primaryText,
        onPressed: _exitChat,
      ),
      // flexibleSpace does not render in this AppBar and was dropped; the frosted glass is now a separate layer at the top of the body
      title: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openModelSheet(),
        child: Row(
          children: [
            _buildAvatar(character),
            const SizedBox(width: 10),
            // Two-line title: character name on top, model name below (small gray text); tapping opens the model sheet
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _truncateName(character?.name ?? '未知角色'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: activeGlassPalette.primaryText,
                      fontSize: DesignTokens.fontSizeBodyLarge,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.15,
                    ),
                  ),
                  Builder(builder: (_) {
                    final modelName =
                        (activeModel == null || activeModel.isEmpty)
                            ? '未选择模型'
                            : activeModel;
                    return Text(
                      _truncateName(modelName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: activeGlassPalette.secondaryText,
                        fontSize: 11,
                        height: 1.1,
                        letterSpacing: -0.1,
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(width: 6),
            // Auto image generation in progress: breathing star hint (moved here from the input bar, hidden and taking no space normally)
            if (ref.watch(activeChatProvider.select((s) => s.isGeneratingImage)))
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _BreathingStar(),
              ),
            Icon(
              Icons.unfold_more_rounded,
              size: 16,
              color: activeGlassPalette.secondaryText,
            ),
          ],
        ),
      ),
      actions: [
        // Back to top: scroll to the first message (floor 1, reusing the jump-to-floor bridge)
        Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: GlassDesign.controlFill,
            shape: BoxShape.circle,
            border: Border.all(color: GlassDesign.highlightBorder),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: '回到顶部',
            iconSize: 16,
            color: activeGlassPalette.primaryText,
            icon: const Icon(Icons.arrow_upward_rounded),
            onPressed: () {
              _bridge.send(BridgeType.scrollToFloor, {'floor': 1});
            },
          ),
        ),
        Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: GlassDesign.controlFill,
            shape: BoxShape.circle,
            border: Border.all(color: GlassDesign.highlightBorder),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: '功能菜单',
            iconSize: 16,
            color: activeGlassPalette.primaryText,
            icon: const Icon(Icons.add_rounded),
            onPressed: _handleInputFunc,
          ),
        ),
      ],
    );
  }

  Future<void> _openModelSheet() async {
    final config = ref.read(llmConfigProvider);
    final configsState = ref.read(llmConfigsProvider);
    // Open the sheet first, showing the loading state
    _bridge.send(BridgeType.showModelSheet, {
      'models': <String>[],
      'current': config.model,
      'loading': true,
      
      'configs': configsState.configs
          .map((c) => {'id': c.id, 'name': c.name, 'active': c.isDefault})
          .toList(),
    });
    // Fetch in the background, update when done
    await ref.read(modelFetchProvider.notifier).fetchModels(config);
    if (!mounted) return;
    final state = ref.read(modelFetchProvider);
    if (state.status == ModelFetchStatus.error) {
      _bridge.send(BridgeType.showModelSheet, {
        'models': <String>[],
        'current': config.model,
        'loading': false,
        'error': state.errorMessage ?? '获取模型失败',
        
      'configs': configsState.configs
            .map((c) => {'id': c.id, 'name': c.name, 'active': c.isDefault})
            .toList(),
      });
      return;
    }
    _bridge.send(BridgeType.showModelSheet, {
      'models': state.models,
      'current': config.model,
      'loading': false,
      
      'configs': configsState.configs
          .map((c) => {'id': c.id, 'name': c.name, 'active': c.isDefault})
          .toList(),
    });
  }

  // Bottom input bar
  // The input bar has moved into the WebView (chat_stage.html .chat-input-container) and follows
  // the keyboard via the --keyboard-height CSS variable; all interaction goes through ChatBridge:
  //   inputSend / inputStop / inputUpload / inputFunc / inputRemoveAttachment
  // Flutter pushes state through inputBarState (generating/attachments/tokenCount/stt etc.).
  // The original Flutter input bar UI is no longer rendered; the related state
  // (_inputController/_pendingAttachments/_hasInput/_TokenCountBadge/_SttMicButton etc.) is kept so
  // script flows like #send_but can still reuse it.

  Widget _buildInputBar(bool isGenerating) {
    return const SizedBox.shrink();
  }

  // WebView input bar bridge: function menu button (the original Flutter IconButton's onPressed logic).
  // Now triggered by the WebView's #funcBtn calling the inputFunc bridge; this implements the original logic.
  void _handleInputFunc() {
    if (_funcPanelOpen) {
      _bridge.send(BridgeType.closeFunctionPanel, {});
      setState(() => _funcPanelOpen = false);
      return;
    }
    final usage = ref.read(contextUsageProvider);
    final charId = ref.read(activeChatProvider).character?.id ?? '';
    _bridge.send(BridgeType.openFunctionPanel, {
      'contextUsed': usage?.totalTokens ?? 0,
      'contextMax': usage?.maxContext ?? 0,
      'contextPct': usage?.usagePercentage ?? 0,
      'contextLevel': usage?.level.name ?? 'low',
      'charId': charId,
      'components': (usage?.components ?? [])
          .map((c) => {'name': c.name, 'tokens': c.tokenCount})
          .toList(),
    });
    setState(() => _funcPanelOpen = true);
  }

  // WebView input bar bridge: image upload button (removed; the method is kept in case of rollback)
  // Image upload now goes through the + menu -> func-overlay "image" item -> panelAction.pickImages -> _pickImages
  // See the case 'pickImages' branch in _bridge.on(BridgeType.panelAction)
  void _handleInputUpload() {
    _pickImages().then((_) {
      if (!mounted) return;
      _pushInputBarState();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _pushInputBarState();
      });
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) _pushInputBarState();
      });
    });
  }

  // WebView input bar bridge: remove a pending image
  void _handleInputRemoveAttachment(int index) {
    if (index < 0 || index >= _pendingAttachments.length) return;
    setState(() => _pendingAttachments.removeAt(index));
    _pushInputBarState();
  }

  // Pushes the current input bar state to the WebView (generating / attachments / token count / STT toggle)
  // Triggered by: isGenerating changes / attachments added or removed / STT toggle changes / STT recording state changes
  void _pushInputBarState() {
    if (!mounted) return;
    final isGenerating = ref.read(activeChatProvider).isGenerating;
    final showTokenCount = ref.read(tokenizerSettingsProvider).showTokenCount;
    final text = _inputController.text.trim();
    String? tokenCount;
    if (showTokenCount && text.isNotEmpty) {
      // tokenCountEstimateProvider is a Provider.family<int, String> and returns an int directly
      final estimate = ref.read(tokenCountEstimateProvider(text));
      tokenCount = '$estimate';
    }
    final atts = <Map<String, String>>[];
    for (final a in _pendingAttachments) {
      final b64 = _attachmentB64Cache[a.path];
      if (b64 != null && b64.isNotEmpty) {
        atts.add({'thumb': 'data:image/jpeg;base64,$b64'});
      }
    }
    _bridge.send(BridgeType.inputBarState, {
      'generating': isGenerating,
      'tokenCount': tokenCount ?? '',
      'attachments': atts,
      'sttEnabled': ref.read(sttSettingsProvider).enabled,
      'sttListening': ref.read(sttListeningProvider),
    });
  }


  // Syncs "whether the input field has content" into _hasInput (the ValueNotifier does not notify
  // when the value is unchanged; the button is rebuilt only on true<->false transitions instead of
  // rebuilding the whole build on every keystroke)
  void _syncHasInput() {
    _hasInput.value = _inputController.text.trim().isNotEmpty;
  }

  // STT mic button: hold to record, release to recognize, result appended to the input field

  Future<void> _sttStart() async {
    HapticFeedback.mediumImpact();
    try {
      await ref.read(sttStartListeningProvider)();
      if (!mounted) return;
      if (!ref.read(sttListeningProvider)) {
        showErrorSnackBar(context, '未能开始录音，请检查麦克风权限或稍后重试');
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, '录音启动失败：$e');
    }
  }

  Future<void> _sttFinish() async {
    HapticFeedback.mediumImpact();
    try {
      await ref.read(sttStopListeningProvider)();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, '识别失败：$e');
      return;
    }
    if (!mounted) return;
    final result = ref.read(sttResultProvider);
    ref.read(sttClearResultProvider)();
    final text = result?.text.trim() ?? '';
    if (text.isEmpty) return;
    // The input bar lives in the WebView, so the STT result must be bridged back to fill the textarea.
    // It is still synced into _inputController so flows like #send_but read consistent _inputController.text.
    _inputController.text = '${_inputController.text}$text';
    _inputController.selection = TextSelection.fromPosition(
      TextPosition(offset: _inputController.text.length),
    );
    _bridge.send(BridgeType.sttResult, {'text': text});
    _pushInputBarState();
  }

  Future<void> _sttCancel() async {
    try {
      await ref.read(sttCancelListeningProvider)();
    } catch (_) {
      // Ignore cancellation failures silently
    }
  }

  /// Exit the chat page: pause -> mask covers instantly -> unmount the WebView -> pop one frame later.
  /// The top bar's back button and PopScope (system back gesture) share this flow.
  Future<void> _exitChat() async {
    await _controller?.pause();
    // Cover with the mask instantly (no fade-in with forward -- translucent x WebView compositing janks)
    _maskController.value = 1.0;
    // Unmount the WebView from the tree first to eliminate the ghost-image flash during the pop transition
    if (mounted) setState(() => _webViewMounted = false);
    // Empty chat: if the user never sent a message -> discard it (no memory entry / no storage used).
    // The decision uses the persistent hasUserMessage marker (set once a message is sent, never
    // cleared by deleting messages), set in repository.addMessage.
    await _discardEmptyChatIfNeeded();
    // Wait one frame to make sure the WebView is truly removed and the mask is fully covering
    await Future.delayed(const Duration(milliseconds: 32));
    if (mounted) context.pop();
  }

  /// On exit, if this chat never had a user message (only the opening prompt / blank), delete it
  /// cascade-style. Chats with the marker are untouched. After deletion the chat list providers are
  /// invalidated so the memory page reflects it immediately.
  Future<void> _discardEmptyChatIfNeeded() async {
    final chatId = ref.read(activeChatProvider).chat?.id;
    if (chatId == null) return;
    try {
      final repo = ref.read(chatRepositoryProvider);
      if (!await repo.hasUserMessaged(chatId)) {
        await repo.deleteChat(chatId);
        ref.invalidate(allChatsProvider);
        ref.invalidate(recentChatsProvider);
        ref.invalidate(characterChatsProvider);
        debugPrint('[空会话] 用户未发言,已丢弃 chat=$chatId');
      }
    } catch (e) {
      debugPrint('[空会话] 丢弃失败(保留会话兜底): $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _navigateTo(String route) async {
    await _controller?.pause();
    _maskController.value = 1.0;   // instant full black, covering the WebView during the transition so the platform view is not composited per frame
    if (!mounted) return;
    await context.push(route);
    if (!mounted) return;
    _maskController.reverse();      // fade the black curtain out after returning
    await _controller?.resume();
  }

  // Settings panel: Flutter-side handling

  Future<void> _handleSettingsPanelAction(
      String panel, String action, Map<String, dynamic> data) async {
    switch (panel) {
      case 'regex':
        await _handleRegexPanelAction(action, data);
        break;
      case 'background':
        await _handleBackgroundPanelAction(action, data);
        break;
      case 'tts':
        await _handleTtsPanelAction(action, data);
        break;
      case 'variables':
        await _handleVariablesPanelAction(action, data);
        break;
      case 'chronicle':
        await _handleChroniclePanelAction(action, data);
        break;
      case 'wiki':
        await _handleWikiPanelAction(action, data);
        break;
      case 'imageGen':
        await _handleImageGenPanelAction(action, data);
        break;
      case 'stt':
        await _handleSttPanelAction(action, data);
        break;
      case 'export':
        await _handleExportPanelAction(action, data);
        break;
      case 'sampling':
        await _handleSamplingPanelAction(action, data);
        break;
      case 'persona':
        await _handlePersonaPanelAction(action, data);
        break;
      case 'sprite':
        await _handleSpritePanelAction(action, data);
        break;
      case 'preset':
        await _handlePresetPanelAction(action, data);
        break;
      case 'worldInfo':
        await _handleWorldInfoPanelAction(action, data);
        break;
    }
  }

  /// Opens the regex panel (global/character tab): collects the regex script data and pushes it to the WebView.
  Future<void> _openRegexPanel(String charId, {String initialTab = 'global'}) async {
    final notifier =
        ref.read(characterRegexScriptsProvider(charId).notifier);
    await notifier.ready;
    if (!mounted) return;
    _bridge.send(BridgeType.openSettingsPanel, {
      'panel': 'regex',
      'title': '正则脚本',
      'data': _serializeRegexData(editDetail: null)
        ..['initialTab'] = initialTab,
    });
  }

  /// Serializes regex script data (dual-scope lists + edit-state detail; reused for open/refresh).
  Map<String, dynamic> _serializeRegexData(
      {Map<String, dynamic>? editDetail}) {
    final character = ref.read(activeChatProvider).character;
    final characterId = character?.id;
    final globalScripts = ref.read(globalRegexScriptsProvider);
    final characterScripts = characterId != null
        ? ref.read(characterRegexScriptsProvider(characterId))
        : <RegexScript>[];
    List<Map<String, dynamic>> serializeList(List<RegexScript> scripts) {
      return scripts
          .map((s) => <String, dynamic>{
                'id': s.id,
                'name': s.scriptName,
                'pattern': s.findRegex,
                'replacement': s.replaceString,
                'enabled': !s.disabled,
              })
          .toList();
    }
    return <String, dynamic>{
      'globalScripts': serializeList(globalScripts),
      'characterScripts': serializeList(characterScripts),
      'charName': character?.name ?? '',
      if (editDetail != null) 'editDetail': editDetail,
    };
  }

  /// Regex panel action handling: list load / detail / toggle / delete / save.
  Future<void> _handleRegexPanelAction(
      String action, Map<String, dynamic> data) async {
    final character = ref.read(activeChatProvider).character;
    final characterId = character?.id;
    final scope = data['scope'] as String? ?? 'global';

    Future<void> pushRefresh({Map<String, dynamic>? editDetail}) async {
      // Re-inject the regex rule snapshot after a change (fixes the JS sync engine using stale
      // rules): __KIRA_REGEX_RULES was previously injected only once at onLoadStop, so after a
      // panel toggle/delete/save/import the JS sync engine (__kiraRunRegex reads
      // window.__KIRA_REGEX_RULES) kept serving old values.
      // The injection is idempotent (rewrites the whole object), and it also refreshes to the
      // latest when the panel opens (loadRegexList).
      final controller = _controller;
      if (controller != null && _webViewMounted) {
        await _injectRegexRules(controller);
      }
      _bridge.send(BridgeType.settingsPanelData, {
        'data': _serializeRegexData(editDetail: editDetail),
        'refresh': true,
      });
    }

    switch (action) {
      case 'loadRegexList':
        await pushRefresh();
        break;

      case 'getRegexDetail':
        final id = data['id'] as String?;
        Map<String, dynamic>? detail;
        if (id != null && id.isNotEmpty) {
          final list = scope == 'global'
              ? ref.read(globalRegexScriptsProvider)
              : (characterId != null
                  ? ref.read(characterRegexScriptsProvider(characterId))
                  : <RegexScript>[]);
          for (final s in list) {
            if (s.id == id) {
              detail = {
                'id': s.id,
                'name': s.scriptName,
                'description': s.description ?? '',
                'pattern': s.findRegex,
                'replacement': s.replaceString,
                'enabled': !s.disabled,
                'placement': s.placement.map((p) => p.name).toList(),
                'markdownOnly': s.markdownOnly,
                'promptOnly': s.promptOnly,
                'runOnEdit': s.runOnEdit,
                'order': s.order,
                'minDepth': s.minDepth ?? 0,
                'maxDepth': s.maxDepth ?? 100,
              };
              break;
            }
          }
        }
        await pushRefresh(editDetail: detail ?? {});
        break;

      case 'toggleRegex':
        final id = data['id'] as String? ?? '';
        final enabled = data['enabled'] as bool? ?? true;
        if (id.isEmpty) return;
        if (scope == 'global') {
          final notifier = ref.read(globalRegexScriptsProvider.notifier);
          for (final s in ref.read(globalRegexScriptsProvider)) {
            if (s.id == id) {
              await notifier.updateScript(
                s.copyWith(disabled: !enabled, updatedAt: DateTime.now()),
              );
              break;
            }
          }
        } else if (characterId != null) {
          final notifier =
              ref.read(characterRegexScriptsProvider(characterId).notifier);
          for (final s in ref.read(characterRegexScriptsProvider(characterId))) {
            if (s.id == id) {
              await notifier.updateScript(
                s.copyWith(disabled: !enabled, updatedAt: DateTime.now()),
              );
              break;
            }
          }
        }
        await pushRefresh();
        // The regex display effect is already baked into rendered bubbles, so a re-push is needed for it to take effect immediately
        await _repushRenderedWindowForRegexChange();
        break;

      case 'deleteRegex':
        final id = data['id'] as String? ?? '';
        final name = data['name'] as String? ?? '此规则';
        if (id.isEmpty) return;
        final ok = await _showHtmlConfirm(
          title: '删除正则规则',
          message: '删除「$name」？此操作不可撤销。',
          confirmText: '删除',
          cancelText: '取消',
          danger: true,
        );
        if (!mounted || !ok) return;
        if (scope == 'global') {
          await ref.read(globalRegexScriptsProvider.notifier).removeScript(id);
        } else if (characterId != null) {
          await ref
              .read(characterRegexScriptsProvider(characterId).notifier)
              .removeScript(id);
        }
        await pushRefresh();
        // Re-push the rendered floors after deleting a rule (the display effect disappears immediately)
        await _repushRenderedWindowForRegexChange();
        break;

      case 'saveRegex':
        final id = data['id'] as String?;
        final name = data['name'] as String? ?? '';
        final description = data['description'] as String? ?? '';
        final pattern = data['pattern'] as String? ?? '';
        final replacement = data['replacement'] as String? ?? '';
        final placementRaw = data['placement'] as List<dynamic>? ?? const [];
        final placement = placementRaw
            .map((p) => RegexPlacement.values.firstWhere(
                  (e) => e.name == p.toString(),
                  orElse: () => RegexPlacement.aiOutput,
                ))
            .toList();
        final markdownOnly = data['markdownOnly'] as bool? ?? false;
        final promptOnly = data['promptOnly'] as bool? ?? false;
        final runOnEdit = data['runOnEdit'] as bool? ?? false;
        final order = (data['order'] as num?)?.toInt() ?? 0;
        final minDepth = (data['minDepth'] as num?)?.toInt() ?? 0;
        final maxDepth = (data['maxDepth'] as num?)?.toInt() ?? 100;
        if (pattern.isEmpty) {
          _snack('匹配模式不能为空');
          return;
        }
        if (scope == 'global') {
          final notifier = ref.read(globalRegexScriptsProvider.notifier);
          if (id != null && id.isNotEmpty) {
            for (final s in ref.read(globalRegexScriptsProvider)) {
              if (s.id == id) {
                await notifier.updateScript(s.copyWith(
                  scriptName: name.isNotEmpty ? name : s.scriptName,
                  description: description,
                  findRegex: pattern,
                  replaceString: replacement,
                  placement: placement.isNotEmpty ? placement : s.placement,
                  markdownOnly: markdownOnly,
                  promptOnly: promptOnly,
                  runOnEdit: runOnEdit,
                  order: order,
                  minDepth: minDepth,
                  maxDepth: maxDepth,
                  updatedAt: DateTime.now(),
                ));
                break;
              }
            }
          } else {
            await notifier.addScript(createRegexScript(
              scriptName: name.isNotEmpty ? name : '未命名规则',
              description: description.isNotEmpty ? description : null,
              findRegex: pattern,
              replaceString: replacement,
              placement: placement.isNotEmpty
                  ? placement
                  : const [RegexPlacement.aiOutput],
              markdownOnly: markdownOnly,
              promptOnly: promptOnly,
              runOnEdit: runOnEdit,
              minDepth: minDepth,
              maxDepth: maxDepth,
            ));
          }
        } else if (characterId != null) {
          final notifier =
              ref.read(characterRegexScriptsProvider(characterId).notifier);
          if (id != null && id.isNotEmpty) {
            for (final s in ref.read(characterRegexScriptsProvider(characterId))) {
              if (s.id == id) {
                await notifier.updateScript(s.copyWith(
                  scriptName: name.isNotEmpty ? name : s.scriptName,
                  description: description,
                  findRegex: pattern,
                  replaceString: replacement,
                  placement: placement.isNotEmpty ? placement : s.placement,
                  markdownOnly: markdownOnly,
                  promptOnly: promptOnly,
                  runOnEdit: runOnEdit,
                  order: order,
                  minDepth: minDepth,
                  maxDepth: maxDepth,
                  updatedAt: DateTime.now(),
                ));
                break;
              }
            }
          } else {
            await notifier.addScript(createRegexScript(
              scriptName: name.isNotEmpty ? name : '未命名规则',
              description: description.isNotEmpty ? description : null,
              findRegex: pattern,
              replaceString: replacement,
              placement: placement.isNotEmpty
                  ? placement
                  : const [RegexPlacement.aiOutput],
              markdownOnly: markdownOnly,
              promptOnly: promptOnly,
              runOnEdit: runOnEdit,
              minDepth: minDepth,
              maxDepth: maxDepth,
            ));
          }
        }
        await pushRefresh();
        // Re-push the rendered floors after saving/creating a rule (the display effect takes effect immediately)
        await _repushRenderedWindowForRegexChange();
        break;

      case 'importRegex':
        final pickResult = await FilePicker.platform.pickFiles(
          dialogTitle: '导入正则规则',
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        if (pickResult == null || pickResult.files.single.path == null) {
          _snack('未选择文件');
          return;
        }
        final content = await File(pickResult.files.single.path!).readAsString();
        final count = await ref
            .read(globalRegexScriptsProvider.notifier)
            .importScripts(content);
        _snack('已导入 $count 条规则');
        await pushRefresh();
        break;

      case 'exportRegex':
        final json = ref.read(globalRegexScriptsProvider.notifier).exportScripts();
        // Unified export delivery: share / save to file
        await deliverExportFile(
          context: context,
          fileName: 'regex_scripts_${DateTime.now().millisecondsSinceEpoch}.json',
          bytes: utf8.encode(json),
          subject: '正则规则导出',
          ext: 'json',
        );
        break;
    }
  }

  // Bubble background panel

  Future<void> _openBackgroundPanel() async {
    _bridge.send(BridgeType.openSettingsPanel, {
      'panel': 'background',
      'title': '气泡背景',
      'data': _serializeBackgroundData(),
    });
  }

  Map<String, dynamic> _serializeBackgroundData() {
    final appSettings = ref.read(appSettingsProvider);
    final bg = ref.read(globalBackgroundProvider);
    final quoteState = ref.read(quoteColorStateProvider);
    return <String, dynamic>{
      'useCharacterAvatar': appSettings.useCharacterAvatarAsBackground,
      'enableBlur': appSettings.enableBackgroundBlur,
      'backgroundOpacity': appSettings.backgroundOpacity,
      'chatLayoutMode': appSettings.chatLayoutMode,
      'bgType': bg.type.name,
      'bgOpacity': bg.opacity,
      'bgBlur': bg.blur,
      'bubbleOpacity': bg.bubbleOpacity,
      'imagePath': bg.imagePath ?? '',
      'quotePrimaryA': _hex(quoteState.primaryA),
      'quotePrimaryB': _hex(quoteState.primaryB),
      'quoteSymbols': QuoteSymbol.values
          .where((s) =>
              s != QuoteSymbol.doubleQuote && s != QuoteSymbol.parenthesis)
          .map((s) => <String, dynamic>{
                'symbol': s.name,
                'label': _quoteSymbolLabel(s),
                'enabled': quoteState.enabledFor(s),
              })
          .toList(),
    };
  }

  static String _quoteSymbolLabel(QuoteSymbol s) {
    switch (s) {
      case QuoteSymbol.doubleQuote:
        return '双引号';
      case QuoteSymbol.parenthesis:
        return '圆括号';
      case QuoteSymbol.cornerBracket:
        return '直角括号「」';
      case QuoteSymbol.doubleCorner:
        return '双直角括号『』';
      case QuoteSymbol.blackLenticular:
        return '方头括号【】';
      case QuoteSymbol.bookTitle:
        return '书名号《》';
      case QuoteSymbol.squareBracket:
        return '英文方括号[]';
    }
  }

  static Color? _parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var h = hex.replaceFirst('#', '');
    if (h.length == 3) {
      h = h.split('').map((c) => c + c).join();
    }
    if (h.length != 6) return null;
    final value = int.tryParse(h, radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value);
  }

  Future<void> _handleBackgroundPanelAction(
      String action, Map<String, dynamic> data) async {
    switch (action) {
      case 'toggleUseCharacterAvatar':
        ref.read(appSettingsProvider.notifier)
            .updateUseCharacterAvatarAsBackground(data['enabled'] as bool);
        break;
      case 'toggleBlur':
        ref.read(appSettingsProvider.notifier)
            .updateEnableBackgroundBlur(data['enabled'] as bool);
        break;
      case 'setBackgroundOpacity':
        ref.read(appSettingsProvider.notifier)
            .updateBackgroundOpacity((data['opacity'] as num).toDouble());
        break;
      case 'setBubbleOpacity':
        final bg = ref.read(globalBackgroundProvider);
        await ref.read(globalBackgroundProvider.notifier)
            .setBackground(bg.copyWith(bubbleOpacity: (data['opacity'] as num).toDouble()));
        break;
      case 'pickBackgroundImage':
        try {
          final file = await _imagePicker.pickImage(source: ImageSource.gallery);
          if (file == null) break;
          final bg = ref.read(globalBackgroundProvider);
          await ref.read(globalBackgroundProvider.notifier)
              .setBackground(bg.copyWith(type: BackgroundType.image, imagePath: file.path));
        } catch (e) {
          _snack('选择图片失败: $e');
        }
        _bridge.send(BridgeType.settingsPanelData, {
          'data': _serializeBackgroundData(),
          'refresh': true,
        });
        break;
      case 'clearBackground':
        await ref.read(globalBackgroundProvider.notifier).clearBackground();
        _bridge.send(BridgeType.settingsPanelData, {
          'data': _serializeBackgroundData(),
          'refresh': true,
        });
        break;
      case 'setLayoutMode':
        ref.read(appSettingsProvider.notifier)
            .updateChatLayoutMode(data['mode'] as String);
        break;
      case 'setQuotePrimaryA':
        final cA = _parseHexColor(data['color'] as String?);
        if (cA != null) {
          await ref.read(quoteColorStateProvider.notifier).setPrimaryA(cA);
        }
        _bridge.send(BridgeType.settingsPanelData, {
          'data': _serializeBackgroundData(),
          'refresh': true,
        });
        break;
      case 'setQuotePrimaryB':
        final cB = _parseHexColor(data['color'] as String?);
        if (cB != null) {
          await ref.read(quoteColorStateProvider.notifier).setPrimaryB(cB);
        }
        _bridge.send(BridgeType.settingsPanelData, {
          'data': _serializeBackgroundData(),
          'refresh': true,
        });
        break;
      case 'setQuoteSymbolEnabled':
        final symStr = data['symbol'] as String? ?? '';
        if (symStr.isEmpty) return;
        final symbol = QuoteSymbol.values.firstWhere(
          (s) => s.name == symStr,
          orElse: () => QuoteSymbol.cornerBracket,
        );
        await ref
            .read(quoteColorStateProvider.notifier)
            .setEnabled(symbol, data['enabled'] as bool);
        break;
      case 'resetQuoteColors':
        await ref.read(quoteColorStateProvider.notifier).resetAll();
        _bridge.send(BridgeType.settingsPanelData, {
          'data': _serializeBackgroundData(),
          'refresh': true,
        });
        break;
    }
  }

  // TTS voice panel

  Future<void> _openTtsPanel() async {
    final settings = ref.read(ttsSettingsProvider);
    // Properly await the voice list instead of using whenData, which could yield an empty list
    List<Map<String, String>> voices = [];
    try {
      final voiceList = await ref
          .read(availableVoicesProvider.future)
          .timeout(const Duration(seconds: 3));
      voices = voiceList
          .map((v) => {'value': v.id, 'label': v.name})
          .toList();
    } catch (_) {}
    _bridge.send(BridgeType.openSettingsPanel, {
      'panel': 'tts',
      'title': 'TTS 语音',
      'data': <String, dynamic>{
        'enabled': settings.enabled,
        'autoPlay': settings.autoPlay,
        'queueMessages': settings.queueMessages,
        'provider': settings.provider.name,
        'voiceId': settings.voiceId ?? '',
        'rate': settings.rate,
        'pitch': settings.pitch,
        'volume': settings.volume,
        'apiKey': (settings.apiKey?.isNotEmpty ?? false) ? '***REDACTED***' : '',
        'apiEndpoint': settings.apiEndpoint ?? '',
        'sherpaModelName': settings.sherpaModelName ?? '',
        'qwenModel': settings.qwenModel ?? '',
        'availableVoices': voices,
      },
    });
  }

  Future<void> _handleTtsPanelAction(
      String action, Map<String, dynamic> data) async {
    final notifier = ref.read(ttsSettingsProvider.notifier);
    switch (action) {
      case 'toggleTts':
        notifier.setEnabled(data['enabled'] as bool);
        break;
      case 'setAutoPlay':
        notifier.setAutoPlay(data['enabled'] as bool);
        break;
      case 'setQueueMode':
        notifier.setQueueMessages(data['enabled'] as bool);
        break;
      case 'setProvider':
        final providerStr = data['provider'] as String;
        final provider = TTSProvider.values.firstWhere(
          (p) => p.name == providerStr,
          orElse: () => TTSProvider.system,
        );
        notifier.setProvider(provider);
        // Force-refresh the voice list after switching engines
        ref.refresh(availableVoicesProvider);
        try {
          final voices = await ref
              .read(availableVoicesProvider.future)
              .timeout(const Duration(seconds: 3));
          _bridge.send(BridgeType.settingsPanelData, {
            'data': <String, dynamic>{
              'availableVoices': voices
                  .map((v) => {'value': v.id, 'label': v.name})
                  .toList(),
              'voiceId': '',
            },
            'refresh': true,
          });
        } catch (_) {}
        break;
      case 'setVoice':
        notifier.setVoiceId(data['voiceId'] as String?);
        break;
      case 'setRate':
        notifier.setRate((data['rate'] as num).toDouble());
        break;
      case 'setPitch':
        notifier.setPitch((data['pitch'] as num).toDouble());
        break;
      case 'setVolume':
        notifier.setVolume((data['volume'] as num).toDouble());
        break;
      case 'setApiKey':
        final ttsKeyValue = data['value'] as String;
        // Ignore the redacted value echoed back by the panel so it cannot overwrite the real key
        if (ttsKeyValue == '***REDACTED***') break;
        notifier.setApiKey(ttsKeyValue);
        break;
      case 'setApiEndpoint':
        notifier.setApiEndpoint(data['value'] as String);
        break;
      case 'setSherpaModelName':
        notifier.setSherpaModelName(data['value'] as String?);
        break;
      case 'setQwenModel':
        notifier.setQwenModel(data['value'] as String?);
        break;
      case 'importTtsModel':
        try {
          final name = await TtsModelService.instance.importModel();
          if (name != null) {
            notifier.setSherpaModelName(name);
            ref.refresh(availableVoicesProvider);
            _bridge.send(BridgeType.settingsPanelData, {
              'data': <String, dynamic>{
                'sherpaModelName': name,
              },
              'refresh': true,
            });
          }
        } catch (_) {}
        break;
      case 'testTts':
        final speak = ref.read(ttsSpeakProvider);
        speak('你好，这是语音合成测试。');
        break;
    }
  }

  // Variable management panel

  Future<void> _openVariablesPanel() async {
    _bridge.send(BridgeType.openSettingsPanel, {
      'panel': 'variables',
      'title': '变量管理',
      'data': _serializeVariablesData(),
    });
  }

  Map<String, dynamic> _serializeVariablesData() {
    final globalVars = ref.read(globalVariablesProvider);
    final chatId = widget.chatId;
    final localVars = ref.read(localVariablesProvider(chatId));
    return <String, dynamic>{
      'globalVariables': globalVars.entries
          .map((e) => {'name': e.key, 'value': e.value.toString()})
          .toList(),
      'localVariables': localVars.entries
          .map((e) => {'name': e.key, 'value': e.value.toString()})
          .toList(),
      'hasChat': true,
    };
  }

  Future<void> _handleVariablesPanelAction(
      String action, Map<String, dynamic> data) async {
    switch (action) {
      case 'createVariable':
        final scope = data['scope'] as String? ?? 'global';
        final name = await _showHtmlPrompt(
          title: '新建${scope == 'global' ? '全局' : '会话'}变量',
          message: '请输入变量名',
        );
        if (name == null || name.trim().isEmpty || !mounted) return;
        final value = await _showHtmlPrompt(
          title: '设置变量值',
          message: '变量 "${name.trim()}" 的值',
        );
        if (value == null || !mounted) return;
        if (scope == 'global') {
          await ref.read(globalVariablesProvider.notifier)
              .setVariable(name.trim(), value);
        } else {
          ref.read(localVariablesProvider(widget.chatId).notifier)
              .setVariable(name.trim(), value);
        }
        _bridge.send(BridgeType.settingsPanelData, {
          'data': _serializeVariablesData(),
          'refresh': true,
        });
        break;

      case 'updateVariable':
        final scope = data['scope'] as String? ?? 'global';
        final name = data['name'] as String? ?? '';
        if (name.isEmpty) return;
        final newValue = await _showHtmlPrompt(
          title: '编辑变量',
          message: '修改变量 "$name" 的值',
        );
        if (newValue == null || !mounted) return;
        if (scope == 'global') {
          await ref.read(globalVariablesProvider.notifier)
              .setVariable(name, newValue);
        } else {
          ref.read(localVariablesProvider(widget.chatId).notifier)
              .setVariable(name, newValue);
        }
        _bridge.send(BridgeType.settingsPanelData, {
          'data': _serializeVariablesData(),
          'refresh': true,
        });
        break;

      case 'deleteVariable':
        final scope = data['scope'] as String? ?? 'global';
        final name = data['name'] as String? ?? '';
        if (name.isEmpty) return;
        final ok = await _showHtmlConfirm(
          title: '删除变量',
          message: '删除变量 "$name"？此操作不可撤销。',
          confirmText: '删除',
          cancelText: '取消',
          danger: true,
        );
        if (!mounted || !ok) return;
        if (scope == 'global') {
          await ref.read(globalVariablesProvider.notifier).deleteVariable(name);
        } else {
          ref.read(localVariablesProvider(widget.chatId).notifier).deleteVariable(name);
        }
        _bridge.send(BridgeType.settingsPanelData, {
          'data': _serializeVariablesData(),
          'refresh': true,
        });
        break;

      case 'clearAllVariables':
        final scope = data['scope'] as String?;
        if (scope == null) {
          final ok = await _showHtmlConfirm(
            title: '清空变量',
            message: '确认清空所有全局和会话变量？此操作不可撤销。',
            confirmText: '清空',
            cancelText: '取消',
            danger: true,
          );
          if (!mounted || !ok) return;
          await ref.read(globalVariablesProvider.notifier).clearAll();
          ref.read(localVariablesProvider(widget.chatId).notifier).clearAll();
        } else if (scope == 'global') {
          await ref.read(globalVariablesProvider.notifier).clearAll();
        } else if (scope == 'local') {
          ref.read(localVariablesProvider(widget.chatId).notifier).clearAll();
        }
        _bridge.send(BridgeType.settingsPanelData, {
          'data': _serializeVariablesData(),
          'refresh': true,
        });
        break;
    }
  }

  // Chronicle super memory panel

  Future<void> _openChroniclePanel() async {
    _bridge.send(BridgeType.openSettingsPanel, {
      'panel': 'chronicle',
      'title': 'Chronicle 超级记忆',
      'data': await _serializeChronicleData(),
    });
  }

  Future<Map<String, dynamic>> _serializeChronicleData() async {
    final cs = ref.read(chronicleSettingsProvider);
    final vs = ref.read(vectorStorageSettingsProvider);
    final vsService = ref.read(vectorStorageServiceProvider);
    final repo = ref.read(chronicleRepositoryProvider);

    int entryCount = 0;
    try {
      entryCount = await repo.countEntries(widget.chatId);
    } catch (_) {}

    return {
      'enabled': cs.enabled,
      'summaryInterval': cs.summaryInterval,
      'summaryPasses': cs.summaryPasses,
      'tokenPressureThreshold': cs.tokenPressureThreshold,
      'hotWindowSize': cs.hotWindowSize,
      'ragTopK': cs.ragTopK,
      'emotionRecallEnabled': cs.emotionRecallEnabled,
      'mvuBridgeEnabled': cs.mvuBridgeEnabled,
      'customPromptSuffix': cs.customPromptSuffix,
      'summaryUsesMainModel': cs.summaryUsesMainModel,
      'summaryBaseUrl': cs.summaryBaseUrl,
      'summaryApiKey': cs.summaryApiKey,
      'summaryModelName': cs.summaryModelName,
      'embeddingProvider': vs.embeddingProvider.name,
      'embeddingModel':
          vs.embeddingModel ?? vs.embeddingProvider.defaultModel,
      'embeddingApiUrl': vs.embeddingApiUrl ?? '',
      'embeddingApiKey': vs.embeddingApiKey ?? '',
      'entryCount': entryCount,
      'hasLegacyVectors': vsService.hasLegacyVectors,
    };
  }

  Future<void> _handleChroniclePanelAction(
      String action, Map<String, dynamic> data) async {
    final cn = ref.read(chronicleSettingsProvider.notifier);
    final vn = ref.read(vectorStorageSettingsProvider.notifier);
    switch (action) {
      case 'toggleEnabled':
        cn.setEnabled(data['enabled'] as bool);
        break;
      case 'setSummaryInterval':
        cn.setSummaryInterval((data['value'] as num).toInt());
        break;
      case 'setSummaryPasses':
        cn.setSummaryPasses((data['value'] as num).toInt());
        break;
      case 'setTokenPressureThreshold':
        cn.setTokenPressureThreshold((data['value'] as num).toDouble());
        break;
      case 'setHotWindowSize':
        cn.setHotWindowSize((data['value'] as num).toInt());
        break;
      case 'setRagTopK':
        cn.setRagTopK((data['value'] as num).toInt());
        break;
      case 'setEmotionRecallEnabled':
        cn.setEmotionRecallEnabled(data['enabled'] as bool);
        break;
      case 'setMvuBridgeEnabled':
        cn.setMvuBridgeEnabled(data['enabled'] as bool);
        break;
      case 'setCustomPromptSuffix':
        cn.setCustomPromptSuffix(data['value'] as String);
        break;
      case 'setSummaryBaseUrl':
        cn.setSummaryBaseUrl(data['value'] as String);
        break;
      case 'setSummaryApiKey':
        cn.setSummaryApiKey(data['value'] as String);
        break;
      case 'setSummaryModelName':
        cn.setSummaryModelName(data['value'] as String);
        break;
      case 'setEmbeddingProvider':
        final providerStr = data['value'] as String;
        final provider = EmbeddingProvider.values.firstWhere(
          (p) => p.name == providerStr,
          orElse: () => EmbeddingProvider.local,
        );
        vn.setEmbeddingProvider(provider);
        break;
      case 'setEmbeddingModel':
        vn.setEmbeddingModel(data['value'] as String);
        break;
      case 'setEmbeddingApiUrl':
        vn.setEmbeddingApiUrl(data['value'] as String);
        break;
      case 'setEmbeddingApiKey':
        vn.setEmbeddingApiKey(data['value'] as String);
        break;
      case 'cleanLegacyVectors':
        await ref.read(vectorStorageServiceProvider).removeLegacyVectors();
        break;
      case 'fetchSummaryModels':
        try {
          final baseUrl = data['baseUrl'] as String? ?? '';
          final apiKey = data['apiKey'] as String? ?? '';
          if (baseUrl.isEmpty || apiKey.isEmpty) {
            _snack('请先填写 Base URL 和 API Key');
            _bridge.send(BridgeType.settingsPanelData,
                {'data': await _serializeChronicleData(), 'refresh': true});
            return;
          }
          final tempConfig = LLMConfig(
            provider: LLMProvider.openAICompatible,
            apiKey: apiKey,
            apiUrl: baseUrl,
            model: '',
          );
          final models = await ref
              .read(llmServiceProvider)
              .getAvailableModels(tempConfig);
          final updated = await _serializeChronicleData();
          updated['availableSummaryModels'] = models;
          _bridge.send(BridgeType.settingsPanelData,
              {'data': updated, 'refresh': true});
          if (models.isEmpty) _snack('未拉取到模型，请检查地址和密钥');
        } catch (e) {
          _snack('拉取失败: $e');
          _bridge.send(BridgeType.settingsPanelData,
              {'data': await _serializeChronicleData(), 'refresh': true});
        }
        return;
    }
    _bridge.send(BridgeType.settingsPanelData,
        {'data': await _serializeChronicleData(), 'refresh': true});
  }

  // Wiki memory bank management panel (run monitoring + memory management)

  Future<void> _openWikiPanel() async {
    _bridge.send(BridgeType.openSettingsPanel, {
      'panel': 'wiki',
      'title': 'Chronicle 记忆库',
      'data': await _serializeWikiData(),
    });
  }

  /// Parses the task's messageIds JSON and returns the id list (empty on failure)
  static List<String> _parseTaskMessageIds(String json) {
    try {
      final list = jsonDecode(json) as List;
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, dynamic>> _serializeWikiData() async {
    final cs = ref.read(chronicleSettingsProvider);
    final repo = ref.read(chronicleRepositoryProvider);

    final entries = await repo.getAllEntries(widget.chatId);
    final entities = await repo.getAllEntities(widget.chatId);
    final tasks = await repo.getTasksForChat(widget.chatId);
    final archivedIds = await repo.getArchivedMessageIds(widget.chatId);
    final messages = ref.read(activeChatProvider).messages;

    return {
      // entry list
      'entries': [
        for (final e in entries)
          {
            'id': e.id,
            'type': e.type.name,
            'title': e.title,
            'content': e.content,
            'importance': e.importance,
            'alwaysInject': e.alwaysInject,
            'anchor': e.anchor,
            'deprecated': e.deprecated,
            'tags': e.tags,
            'sourceMessageIds': e.sourceMessageIds,
            'turnIndex': e.turnIndex,
            'createdAt': e.createdAt.toIso8601String(),
            'updatedAt': e.updatedAt.toIso8601String(),
          },
      ],
      // entity list
      'entities': [
        for (final en in entities)
          {
            'id': en.id,
            'name': en.name,
            'type': en.type.name,
            'description': en.description,
            'currentState': en.currentState,
            'aliases': en.aliases,
          },
      ],
      // task queue
      'tasks': [
        for (final t in tasks)
          {
            'id': t.id,
            'status': t.status,
            'messageCount': _parseTaskMessageIds(t.messageIds).length,
            'fromTurn': t.fromTurn,
            'toTurn': t.toTurn,
            'error': t.error,
            'createdAt': t.createdAt.toIso8601String(),
            'finishedAt': t.finishedAt?.toIso8601String(),
          },
      ],
      // stats
      'stats': {
        'entryCount': entries.length,
        'entityCount': entities.length,
        'archivedMessageCount': archivedIds.length,
        'totalMessageCount': messages.length,
        'totalVisibleMessageCount':
            messages.where((m) => !m.isHidden).length,
        'pendingTaskCount': tasks.where((t) => t.status == 'pending').length,
        'failedTaskCount': tasks.where((t) => t.status == 'failed').length,
      },
      // the full prompt currently in effect (built-in template, without conversation content)
      'currentPrompt': ChronicleSummaryService.basePrompt,
      // user-defined suffix
      'customPromptSuffix': cs.customPromptSuffix,
      // mature content prompt suffix (separate field)
      'matureContentSuffix': cs.matureContentSuffix,
      // max retry count
      'maxRetries': cs.maxRetries,
    };
  }

  Future<void> _handleWikiPanelAction(
      String action, Map<String, dynamic> data) async {
    final cn = ref.read(chronicleSettingsProvider.notifier);
    final repo = ref.read(chronicleRepositoryProvider);
    switch (action) {
      case 'updateEntry':
        final entryId = data['id'] as String? ?? '';
        if (entryId.isNotEmpty) {
          final candidates =
              await repo.getEntriesByIds(widget.chatId, [entryId]);
          if (candidates.isNotEmpty) {
            final e = candidates.first;
            await repo.upsertMemoryEntry(e.copyWith(
              title: (data['title'] as String?)?.trim() ?? e.title,
              content: (data['content'] as String?)?.trim() ?? e.content,
              importance: (data['importance'] as num?)?.toInt() ?? e.importance,
              alwaysInject: (data['alwaysInject'] as bool?) ?? e.alwaysInject,
              anchor: (data['anchor'] as bool?) ?? e.anchor,
              tags: data['tags'] is List
                  ? (data['tags'] as List).map((t) => t.toString()).toList()
                  : e.tags,
            ));
          }
        }
        break;
      case 'deleteEntry':
        final entryId = data['id'] as String? ?? '';
        if (entryId.isNotEmpty) await repo.deleteEntry(entryId);
        break;
      case 'updateEntity':
        final entityId = data['id'] as String? ?? '';
        if (entityId.isNotEmpty) {
          final all = await repo.getAllEntities(widget.chatId);
          for (final en in all) {
            if (en.id == entityId) {
              await repo.upsertEntity(en.copyWith(
                description: (data['description'] as String?)?.trim() ??
                    en.description,
                currentState: (data['currentState'] as String?)?.trim() ??
                    en.currentState,
              ));
              break;
            }
          }
        }
        break;
      case 'deleteEntity':
        final entityId = data['id'] as String? ?? '';
        if (entityId.isNotEmpty) await repo.deleteEntity(entityId);
        break;
      case 'retryTask':
        final taskId = data['id'] as String? ?? '';
        if (taskId.isNotEmpty) await repo.updateTaskStatus(taskId, 'pending');
        break;
      case 'deleteTask':
        final taskId = data['id'] as String? ?? '';
        if (taskId.isNotEmpty) await repo.deleteTask(taskId);
        break;
      case 'clearFailedTasks':
        await repo.clearFailedTasksForChat(widget.chatId);
        break;
      case 'fullResummarize':
        try {
          final settings = ref.read(chronicleSettingsProvider);
          // 1. Clear the existing entries, archive records, and task queue
          await repo.deleteAllEntriesForChat(widget.chatId);
          await repo.clearArchivedMessageIds(widget.chatId);
          await repo.clearTasksForChat(widget.chatId);
          // 2. Fetch all visible messages
          final allMessages = ref.read(activeChatProvider).messages
              .where((m) => !m.isHidden)
              .toList();
          if (allMessages.isEmpty) break;
          // 3. Slice by summaryInterval (turns x2 = message count) and enqueue each batch separately
          // (a single task holding all messages makes the LLM input too long and occasionally breaks JSON formatting)
          final batchSize = settings.summaryInterval * 2;
          for (int i = 0; i < allMessages.length; i += batchSize) {
            final end = (i + batchSize).clamp(0, allMessages.length);
            final batchIds =
                allMessages.sublist(i, end).map((m) => m.id).toList();
            await repo.enqueueSummaryTask(
              chatId: widget.chatId,
              messageIds: batchIds,
              fromTurn: i ~/ 2,
              toTurn: end ~/ 2,
              forceEnqueue: true, // skip the hasActiveTask check
            );
          }
          // Kick one round of consumption right after enqueueing (preserving the original forceEnqueueAll's immediate execution)
          ref.read(chronicleOrchestratorProvider).kickProcess();
          final batchCount = (allMessages.length / batchSize).ceil();
          _snack('已重新对全部消息入队总结（$batchCount批）');
        } catch (e) {
          _snack('全量总结失败: $e');
        }
        break;
      case 'resummarizeEntry':
        final rEntryId = data['entryId'] as String? ?? '';
        if (rEntryId.isEmpty) break;
        // The LLM call takes a while, so send a loading state to the HTML first (refresh:false does not re-render)
        _bridge.send(BridgeType.settingsPanelData, {
          'data': {'loading': true, 'loadingMessage': '正在重新总结，请稍候…'},
          'refresh': false,
        });
        String? resErr;
        try {
          resErr = await ref
              .read(chronicleOrchestratorProvider)
              .resummarizeEntry(widget.chatId, rEntryId,
                  data['extraRequirement'] as String? ?? '');
        } catch (e) {
          resErr = e.toString();
        }
        final wikiData = await _serializeWikiData();
        if (resErr != null) {
          wikiData['wikiError'] = resErr;
          _snack('重新总结失败: $resErr');
        } else {
          _snack('重新总结完成');
        }
        _bridge.send(BridgeType.settingsPanelData,
            {'data': wikiData, 'refresh': true});
        return;
      case 'manualSummarize':
        try {
          final messages = ref.read(activeChatProvider).messages;
          final config = ref.read(llmConfigProvider);
          final ok = await ref
              .read(chronicleOrchestratorProvider)
              .checkAndEnqueue(
                chatId: widget.chatId,
                messages: messages,
                llmConfig: config,
                force: true,
              );
          _snack(ok ? '已触发记忆整理' : '触发失败');
        } catch (e) {
          _snack('触发失败: $e');
        }
        break;
      case 'setMatureContentSuffix':
        cn.setMatureContentSuffix(data['value'] as String);
        break;
      case 'setMaxRetries':
        cn.setMaxRetries((data['value'] as num).toInt());
        break;
    }
    _bridge.send(BridgeType.settingsPanelData,
        {'data': await _serializeWikiData(), 'refresh': true});
  }

  // STT speech recognition panel

  Future<void> _openSttPanel() async {
    _bridge.send(BridgeType.openSettingsPanel, {
      'panel': 'stt',
      'title': 'STT 语音识别',
      'data': await _serializeSttData(),
    });
  }

  Future<Map<String, dynamic>> _serializeSttData() async {
    final s = ref.read(sttSettingsProvider);
    bool available = true;
    try {
      available =
          await ref.read(sttAvailableProvider.future).timeout(const Duration(seconds: 2));
    } catch (_) {}
    return <String, dynamic>{
      'enabled': s.enabled,
      'provider': s.provider.id,
      'language': s.language,
      'continuousListening': s.continuousListening,
      'autoSend': s.autoSend,
      'showPartialResults': s.showPartialResults,
      'apiKey': s.apiKey ?? '',
      'apiEndpoint': s.apiEndpoint ?? '',
      'available': available,
    };
  }

  Future<void> _handleSttPanelAction(
      String action, Map<String, dynamic> data) async {
    final notifier = ref.read(sttSettingsProvider.notifier);
    switch (action) {
      case 'toggleEnabled':
        notifier.setEnabled(data['enabled'] as bool);
        break;
      case 'setProvider':
        final p = STTProvider.values.firstWhere(
          (e) => e.id == (data['value'] as String),
          orElse: () => STTProvider.sherpa,
        );
        notifier.setProvider(p);
        break;
      case 'setLanguage':
        notifier.setLanguage(data['value'] as String);
        break;
      case 'setContinuousListening':
        notifier.setContinuousListening(data['enabled'] as bool);
        break;
      case 'setAutoSend':
        notifier.setAutoSend(data['enabled'] as bool);
        break;
      case 'setShowPartialResults':
        notifier.setShowPartialResults(data['enabled'] as bool);
        break;
      case 'setApiKey':
        notifier.setApiKey(data['value'] as String);
        break;
      case 'setApiEndpoint':
        notifier.setApiEndpoint(data['value'] as String);
        break;
    }
    _bridge.send(BridgeType.settingsPanelData,
        {'data': await _serializeSttData(), 'refresh': true});
  }

  // Export / import panel

  Future<void> _openExportPanel() async {
    final chatState = ref.read(activeChatProvider);
    final messages = chatState.messages;
    int entryCount = 0;
    try {
      entryCount = await ref
          .read(chronicleRepositoryProvider)
          .countEntries(widget.chatId);
    } catch (_) {}
    _bridge.send(BridgeType.openSettingsPanel, {
      'panel': 'export',
      'title': '导出 / 导入',
      'data': <String, dynamic>{
        'defaultFormat': 'jsonl',
        'messageCount': messages.length,
        'charName': chatState.character?.name ?? '当前会话',
        'hasChronicle': entryCount > 0,
      },
    });
  }

  Future<void> _handleExportPanelAction(
      String action, Map<String, dynamic> data) async {
    switch (action) {
      case 'exportChat':
        await _exportChatRecord(
          useJsonl: (data['format'] as String? ?? 'jsonl') == 'jsonl',
          toFile: false,
        );
        break;
      case 'exportChatToFile':
        await _exportChatRecord(
          useJsonl: (data['format'] as String? ?? 'jsonl') == 'jsonl',
          toFile: true,
        );
        break;
      case 'importChat':
        await _importChatRecord();
        break;
    }
  }

  // Sampling parameters panel

  Future<void> _openSamplingPanel() async {
    _bridge.send(BridgeType.openSettingsPanel, {
      'panel': 'sampling',
      'title': '采样参数',
      'data': _serializeSamplingData(),
    });
  }

  Map<String, dynamic> _serializeSamplingData() {
    final c = ref.read(llmConfigProvider);
    final cfg = ref.read(cfgScaleSettingsProvider);
    return <String, dynamic>{
      'temperature': c.temperature,
      'topP': c.topP,
      'topK': c.topK,
      'minP': c.minP,
      'typicalP': c.typicalP,
      'topA': c.topA,
      'tailFreeSampling': c.tailFreeSampling,
      'repetitionPenalty': c.repetitionPenalty,
      'repetitionPenaltyRange': c.repetitionPenaltyRange,
      'frequencyPenalty': c.frequencyPenalty,
      'presencePenalty': c.presencePenalty,
      'mirostatMode': c.mirostatMode,
      'mirostatTau': c.mirostatTau,
      'mirostatEta': c.mirostatEta,
      'maxTokens': c.maxTokens,
      'contextLength': c.contextLength,
      'stopSequencesStr': c.stopSequences.join(','),
      'streamEnabled': c.streamEnabled,
      'cfg': <String, dynamic>{
        'enabled': cfg.enabled,
        'globalGuidanceScale': cfg.globalGuidanceScale,
      },
    };
  }

  Future<void> _handleSamplingPanelAction(
      String action, Map<String, dynamic> data) async {
    final ln = ref.read(llmConfigProvider.notifier);
    switch (action) {
      case 'setTemperature':
        ln.updateTemperature((data['value'] as num).toDouble());
        break;
      case 'setTopP':
        ln.updateTopP((data['value'] as num).toDouble());
        break;
      case 'setTopK':
        ln.updateTopK((data['value'] as num).toInt());
        break;
      case 'setMinP':
        ln.updateMinP((data['value'] as num).toDouble());
        break;
      case 'setTypicalP':
        ln.updateTypicalP((data['value'] as num).toDouble());
        break;
      case 'setTopA':
        ln.updateTopA((data['value'] as num).toDouble());
        break;
      case 'setTailFreeSampling':
        ln.updateTailFreeSampling((data['value'] as num).toDouble());
        break;
      case 'setRepetitionPenalty':
        ln.updateRepetitionPenalty((data['value'] as num).toDouble());
        break;
      case 'setRepetitionPenaltyRange':
        ln.updateRepetitionPenaltyRange((data['value'] as num).toInt());
        break;
      case 'setFrequencyPenalty':
        ln.updateFrequencyPenalty((data['value'] as num).toDouble());
        break;
      case 'setPresencePenalty':
        ln.updatePresencePenalty((data['value'] as num).toDouble());
        break;
      case 'setMirostatMode':
        ln.updateMirostatMode((data['value'] as num).toInt());
        break;
      case 'setMirostatTau':
        ln.updateMirostatTau((data['value'] as num).toDouble());
        break;
      case 'setMirostatEta':
        ln.updateMirostatEta((data['value'] as num).toDouble());
        break;
      case 'setMaxTokens':
        ln.updateMaxTokens((data['value'] as num).toInt());
        break;
      case 'setContextLength':
        ln.updateContextLength((data['value'] as num).toInt());
        break;
      case 'setStopSequences':
        final raw = data['value'] as String? ?? '';
        ln.updateStopSequences(raw
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList());
        break;
      case 'setStreamEnabled':
        ln.updateStreamEnabled(data['enabled'] as bool);
        break;
      case 'setSeed':
        ln.updateSeed((data['value'] as num).toInt());
        break;
      case 'toggleCfg':
        ref
            .read(cfgScaleSettingsProvider.notifier)
            .setEnabled(data['enabled'] as bool);
        break;
      case 'setCfgScale':
        ref
            .read(cfgScaleSettingsProvider.notifier)
            .setGlobalGuidanceScale((data['value'] as num).toDouble());
        break;
      case 'resetToDefault':
        ln.updateTemperature(0.8);
        ln.updateTopP(0.95);
        ln.updateTopK(40);
        ln.updateMinP(0);
        ln.updateTypicalP(1);
        ln.updateTopA(0);
        ln.updateTailFreeSampling(1);
        ln.updateRepetitionPenalty(1.1);
        ln.updateRepetitionPenaltyRange(512);
        ln.updateFrequencyPenalty(0);
        ln.updatePresencePenalty(0);
        ln.updateMirostatMode(0);
        ln.updateMirostatTau(5);
        ln.updateMirostatEta(0.1);
        ln.updateMaxTokens(512);
        ln.updateContextLength(8192);
        ln.updateStopSequences(const []);
        ln.updateSeed(-1);
        break;
    }
    _bridge.send(BridgeType.settingsPanelData,
        {'data': _serializeSamplingData(), 'refresh': true});
  }

  // Persona management panel

  Future<void> _openPersonaPanel() async {
    await ref.read(personaNotifierProvider.notifier).refresh();
    if (!mounted) return;
    _bridge.send(BridgeType.openSettingsPanel, {
      'panel': 'persona',
      'title': '人设管理',
      'data': _serializePersonaData(),
    });
  }

  /// Avatar file -> data URL (WebView loadData cannot load file://, so base64 is inlined)
  static String _avatarDataUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    try {
      final f = File(path);
      if (!f.existsSync()) return '';
      final ext = p.extension(path).toLowerCase();
      final mime = ext == '.jpg' || ext == '.jpeg'
          ? 'image/jpeg'
          : (ext == '.webp' ? 'image/webp' : 'image/png');
      final bytes = f.readAsBytesSync();
      if (bytes.isEmpty) return '';
      return 'data:$mime;base64,${base64Encode(bytes)}';
    } catch (_) {
      return '';
    }
  }

  Map<String, dynamic> _serializePersonaData(
      {Map<String, dynamic>? editDetail}) {
    final personas = ref.read(personaNotifierProvider).valueOrNull ?? [];
    final activeId = ref.read(activePersonaIdProvider);
    return <String, dynamic>{
      'personas': personas
          .map((p) => <String, dynamic>{
                'id': p.id,
                'name': p.name,
                'avatarPath': _avatarDataUrl(p.avatarPath),
                'isDefault': p.isDefault,
              })
          .toList(),
      'activeId': activeId ?? '',
      if (editDetail != null) 'editDetail': editDetail,
    };
  }

  Future<void> _handlePersonaPanelAction(
      String action, Map<String, dynamic> data) async {
    final notifier = ref.read(personaNotifierProvider.notifier);

    Future<void> pushRefresh({Map<String, dynamic>? editDetail}) async {
      _bridge.send(BridgeType.settingsPanelData, {
        'data': _serializePersonaData(editDetail: editDetail),
        'refresh': true,
      });
    }

    switch (action) {
      case 'loadPersonaList':
        await notifier.refresh();
        await pushRefresh();
        break;
      case 'setDefaultPersona':
        final id = data['id'] as String? ?? '';
        if (id.isEmpty) return;
        await notifier.setActivePersona(id);
        await notifier.setDefaultPersona(id);
        _snack('已切换人设');
        await pushRefresh();
        break;
      case 'getPersonaDetail':
        final id = data['id'] as String?;
        Map<String, dynamic> detail = {};
        if (id != null && id.isNotEmpty) {
          final personas =
              ref.read(personaNotifierProvider).valueOrNull ?? [];
          for (final p in personas) {
            if (p.id == id) {
              detail = {
                'id': p.id,
                'name': p.name,
                'description': p.description,
                'avatarPath': '',
              };
              break;
            }
          }
        }
        await pushRefresh(editDetail: detail);
        break;
      case 'savePersona':
        final id = data['id'] as String?;
        final name = data['name'] as String? ?? '';
        final description = data['description'] as String? ?? '';
        if (name.trim().isEmpty) {
          _snack('名称不能为空');
          return;
        }
        if (id != null && id.isNotEmpty) {
          final personas =
              ref.read(personaNotifierProvider).valueOrNull ?? [];
          for (final p in personas) {
            if (p.id == id) {
              await notifier.updatePersona(
                  p.copyWith(name: name.trim(), description: description));
              break;
            }
          }
        } else {
          await notifier.createPersona(
              name: name.trim(), description: description);
        }
        _snack('已保存');
        await notifier.refresh();
        await pushRefresh();
        break;
      case 'deletePersona':
        final id = data['id'] as String? ?? '';
        if (id.isEmpty) return;
        final ok = await _showHtmlConfirm(
          title: '删除人设',
          message: '删除该人设？此操作不可撤销。',
          confirmText: '删除',
          cancelText: '取消',
          danger: true,
        );
        if (!mounted || !ok) return;
        try {
          await notifier.deletePersona(id);
          _snack('已删除');
        } catch (e) {
          _snack('$e');
        }
        await pushRefresh();
        break;
      case 'pickPersonaAvatar':
        final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 256,
          maxHeight: 256,
        );
        if (picked == null) return;
        final avatarId = data['id'] as String?;
        if (avatarId != null && avatarId.isNotEmpty) {
          final personas = ref.read(personaNotifierProvider).valueOrNull ?? [];
          for (final pers in personas) {
            if (pers.id == avatarId) {
              await notifier.updatePersona(
                  pers.copyWith(avatarPath: picked.path));
              break;
            }
          }
          _snack('头像已更新');
        }
        await pushRefresh();
        break;
    }
  }

  // Sprite panel (placeholder configuration)

  Future<void> _openSpritePanel() async {
    _bridge.send(BridgeType.openSettingsPanel, {
      'panel': 'sprite',
      'title': '精灵立绘',
      'data': await _serializeSpriteData(),
    });
  }

  Future<Map<String, dynamic>> _serializeSpriteData() async {
    final s = ref.read(spriteSettingsProvider);
    final character = ref.read(activeChatProvider).character;
    int spriteCount = 0;
    try {
      final pack = character != null
          ? await ref.read(spritePackProvider(character.id).future)
          : null;
      spriteCount = pack?.sprites.length ?? 0;
    } catch (_) {}
    return <String, dynamic>{
      'enabled': s.enabled,
      'size': s.size,
      'position': s.position.name,
      'opacity': s.opacity,
      'showDuringStreaming': s.showDuringStreaming,
      'animateTransitions': s.animateTransitions,
      'transitionDurationMs': s.transitionDurationMs,
      'charId': character?.id ?? '',
      'charName': character?.name ?? '',
      'spriteCount': spriteCount,
    };
  }

  Future<void> _handleSpritePanelAction(
      String action, Map<String, dynamic> data) async {
    final notifier = ref.read(spriteSettingsProvider.notifier);
    switch (action) {
      case 'toggleEnabled':
        notifier.setEnabled(data['enabled'] as bool);
        break;
      case 'setSize':
        notifier.setSize((data['value'] as num).toDouble());
        break;
      case 'setPosition':
        final posStr = data['value'] as String;
        final pos = SpritePosition.values.firstWhere(
          (p) => p.name == posStr,
          orElse: () => SpritePosition.left,
        );
        notifier.setPosition(pos);
        break;
      case 'setOpacity':
        notifier.setOpacity((data['value'] as num).toDouble());
        break;
      case 'setShowDuringStreaming':
        notifier.setShowDuringStreaming(data['enabled'] as bool);
        break;
      case 'setAnimateTransitions':
        notifier.setAnimateTransitions(data['enabled'] as bool);
        break;
      case 'setTransitionDuration':
        notifier.setTransitionDuration((data['value'] as num).toInt());
        break;
      case 'pickSpriteImage':
        final charId = ref.read(activeChatProvider).character?.id;
        if (charId == null || charId.isEmpty) {
          _snack('当前聊天没有关联角色');
          return;
        }
        final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
        if (picked == null) return;
        try {
          await ref
              .read(spritePackNotifierProvider(charId).notifier)
              .addSprite('neutral', File(picked.path));
          _snack('已添加为 neutral 表情图');
        } catch (e) {
          _snack('添加失败: $e');
        }
        break;
    }
    _bridge.send(BridgeType.settingsPanelData,
        {'data': await _serializeSpriteData(), 'refresh': true});
  }

  // Preset & prompt panel

  Future<void> _openPresetPanel() async {
    _bridge.send(BridgeType.openSettingsPanel, {
      'panel': 'preset',
      'title': '预设 & 提示词',
      'data': _serializePresetData(),
    });
  }

  Map<String, dynamic> _serializePresetData(
      {String? tab, Map<String, dynamic>? editDetail}) {
    final presets = ref.read(allAIPresetsProvider);
    final activeId = ref.read(activeAIPresetIdProvider);
    final promptConfig = ref.read(promptManagerProvider);
    return <String, dynamic>{
      'presets': presets
          .map((p) => <String, dynamic>{
                'id': p.id,
                'name': p.name,
                'isBuiltIn': p.isBuiltIn,
                'isActive': p.id == activeId,
              })
          .toList(),
      'activePresetName': presets
          .where((p) => p.id == activeId)
          .map((p) => p.name)
          .firstOrNull,
      'promptSections': promptConfig.sections
          .map((s) => <String, dynamic>{
                'id': s.type.name,
                'name': PromptSection.getDisplayName(s.type),
                'enabled': s.enabled,
                'content': _getSectionContent(s),
              })
          .toList(),
      if (tab != null) 'tab': tab,
      if (editDetail != null) 'editDetail': editDetail,
    };
  }

  String _getSectionContent(PromptSection section) {
    final c = section.content;
    if (c == null) return '';
    return c;
  }

  Future<void> _handlePresetPanelAction(
      String action, Map<String, dynamic> data) async {
    final promptNotifier = ref.read(promptManagerProvider.notifier);
    switch (action) {
      case 'loadPresetData':
        _bridge.send(BridgeType.settingsPanelData, {
          'data': _serializePresetData(tab: data['tab'] as String?),
          'refresh': true,
        });
        break;
      case 'applyPreset':
        final id = data['id'] as String? ?? '';
        if (id.isEmpty) return;
        final presets = ref.read(allAIPresetsProvider);
        final preset = presets.where((p) => p.id == id).firstOrNull;
        if (preset == null) return;
        _snack('正在应用预设…');
        await ref.read(aiPresetManagerProvider).applyPreset(preset);
        _snack('预设已应用');
        _bridge.send(BridgeType.settingsPanelData, {
          'data': _serializePresetData(),
          'refresh': true,
        });
        break;
      case 'createPreset':
        final count = ref.read(aiCustomPresetsProvider).length + 1;
        final preset = await ref
            .read(aiPresetManagerProvider)
            .createFromCurrentSettings(name: '自定义预设 $count');
        await ref.read(aiCustomPresetsProvider.notifier).addPreset(preset);
        _snack('已创建「${preset.name}」');
        _bridge.send(BridgeType.settingsPanelData, {
          'data': _serializePresetData(),
          'refresh': true,
        });
        break;
      case 'togglePromptSection':
        final typeId = data['id'] as String? ?? '';
        if (typeId.isEmpty) return;
        final type = PromptSectionType.values.firstWhere(
          (t) => t.name == typeId,
          orElse: () => PromptSectionType.systemPrompt,
        );
        await promptNotifier.toggleSection(type);
        break;
      case 'updatePromptContent':
        final typeId = data['id'] as String? ?? '';
        final content = data['content'] as String? ?? '';
        if (typeId.isEmpty) return;
        final type = PromptSectionType.values.firstWhere(
          (t) => t.name == typeId,
          orElse: () => PromptSectionType.systemPrompt,
        );
        await promptNotifier.updateSectionContent(type, content);
        break;
      case 'resetPromptSections':
        await promptNotifier.resetToDefault();
        _snack('已恢复默认');
        _bridge.send(BridgeType.settingsPanelData, {
          'data': _serializePresetData(),
          'refresh': true,
        });
        break;
      case 'renamePreset':
        final renameId = data['id'] as String? ?? '';
        final currentName = data['currentName'] as String? ?? '';
        if (renameId.isEmpty) return;
        _bridge.send(BridgeType.closeSettingsPanel, {});
        await Future.delayed(const Duration(milliseconds: 350));
        final newName = await _showHtmlPrompt(
          title: '重命名预设',
          message: '新的预设名称',
          initial: currentName,
        );
        if (!mounted || newName == null || newName.trim().isEmpty) return;
        final allPresetsNow = ref.read(allAIPresetsProvider);
        final target = allPresetsNow.where((p) => p.id == renameId).firstOrNull;
        if (target == null) return;
        await ref
            .read(aiCustomPresetsProvider.notifier)
            .updatePreset(target.copyWith(name: newName.trim()));
        _snack('已重命名');
        _bridge.send(BridgeType.openSettingsPanel, {
          'panel': 'preset',
          'title': '预设 & 提示词',
          'data': _serializePresetData(),
        });
        break;
      case 'deletePreset':
        final delId = data['id'] as String? ?? '';
        if (delId.isEmpty) return;
        await ref.read(aiCustomPresetsProvider.notifier).deletePreset(delId);
        _snack('已删除');
        _bridge.send(BridgeType.settingsPanelData, {
          'data': _serializePresetData(),
          'refresh': true,
        });
        break;
      case 'importPreset':
        final pickResult = await FilePicker.platform.pickFiles(
          dialogTitle: '导入预设',
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        if (pickResult == null || pickResult.files.single.path == null) {
          _snack('未选择文件');
          return;
        }
        final content = await File(pickResult.files.single.path!).readAsString();
        try {
          final json = jsonDecode(content) as Map<String, dynamic>;
          final preset =
              await ref.read(aiCustomPresetsProvider.notifier).importPreset(json);
          _snack('已导入「${preset.name}」');
        } catch (e) {
          _snack('导入失败: $e');
        }
        _bridge.send(BridgeType.settingsPanelData, {
          'data': _serializePresetData(),
          'refresh': true,
        });
        break;
      case 'exportPreset':
        final activeIdNow = ref.read(activeAIPresetIdProvider);
        final presetsNow = ref.read(allAIPresetsProvider);
        final active = presetsNow.where((p) => p.id == activeIdNow).firstOrNull;
        if (active == null) {
          _snack('当前无激活预设');
          return;
        }
        final exportJson = jsonEncode(active.toExportJson());
        // Unified export delivery: share / save to file
        await deliverExportFile(
          context: context,
          fileName:
              '${active.name}_${DateTime.now().millisecondsSinceEpoch}.json',
          bytes: utf8.encode(exportJson),
          subject: '预设导出',
          ext: 'json',
        );
        break;
    }
  }

  // Worldbook panel (three-level navigation)

  Future<void> _openWorldInfoPanel({String initialScope = 'global'}) async {
    final character = ref.read(activeChatProvider).character;
    _bridge.send(BridgeType.openSettingsPanel, {
      'panel': 'worldInfo',
      'title': '世界书',
      'data': await _serializeWorldInfoData(
        initialScope: initialScope,
        characterId: initialScope == 'character' ? character?.id : null,
      ),
    });
  }

  Future<Map<String, dynamic>> _serializeWorldInfoData(
      {String? initialScope, String? characterId}) async {
    final repo = ref.read(worldInfoRepositoryProvider);
    final globalBooks = await repo.getGlobalWorldInfos();
    final characterBooks = characterId != null
        ? await repo.getWorldInfosForCharacter(characterId)
        : <models.WorldInfo>[];
    Map<String, dynamic> serializeBook(models.WorldInfo b) {
      return <String, dynamic>{
        'id': b.id,
        'name': b.name,
        'enabled': b.enabled,
        'entryCount': b.entries.length,
      };
    }
    return <String, dynamic>{
      'globalBooks': globalBooks.map(serializeBook).toList(),
      'characterBooks': characterBooks.map(serializeBook).toList(),
      'currentCharId': characterId ?? '',
      if (initialScope != null) 'initialTab': initialScope,
    };
  }

  Future<void> _handleWorldInfoPanelAction(
      String action, Map<String, dynamic> data) async {
    final repo = ref.read(worldInfoRepositoryProvider);
    final notifier = ref.read(worldInfoNotifierProvider.notifier);
    final character = ref.read(activeChatProvider).character;
    final scope = data['scope'] as String? ?? 'global';

    Future<void> pushBooks() async {
      _bridge.send(BridgeType.settingsPanelData, {
        'data': await _serializeWorldInfoData(
          characterId: character?.id,
        ),
        'refresh': true,
      });
    }

    switch (action) {
      case 'loadWorldBooks':
        await pushBooks();
        break;
      case 'toggleWorldBook':
        final id = data['id'] as String? ?? '';
        final enabled = data['enabled'] as bool? ?? true;
        if (id.isEmpty) return;
        final book = await repo.getWorldInfoById(id);
        if (book == null) return;
        await notifier.updateWorldInfo(book.copyWith(enabled: enabled));
        await pushBooks();
        break;
      case 'createWorldBook':
        final isGlobal = scope == 'global';
        final name = isGlobal ? '新全局世界书' : '新角色世界书';
        await notifier.createWorldInfo(
          name: name,
          isGlobal: isGlobal,
          characterId: isGlobal ? null : character?.id,
        );
        _snack('已创建，点击进入添加条目');
        await pushBooks();
        break;
      case 'deleteWorldBook':
        final id = data['id'] as String? ?? '';
        if (id.isEmpty) return;
        final ok = await _showHtmlConfirm(
          title: '删除世界书',
          message: '删除该世界书及其全部条目？此操作不可撤销。',
          confirmText: '删除',
          cancelText: '取消',
          danger: true,
        );
        if (!mounted || !ok) return;
        await notifier.deleteWorldInfo(id);
        await pushBooks();
        break;
      case 'loadWorldEntries':
        final bookId = data['bookId'] as String? ?? '';
        if (bookId.isEmpty) return;
        final book = await repo.getWorldInfoById(bookId);
        if (book == null) return;
        final entries = book.entries
            .map((e) => <String, dynamic>{
                  'id': e.id,
                  'comment': e.comment,
                  'keysStr': e.keys.join(', '),
                  'enabled': e.enabled,
                  'constant': e.constant,
                })
            .toList();
        _bridge.send(BridgeType.settingsPanelData, {
          'data': <String, dynamic>{
            'entries': entries,
            'currentCharId': character?.id ?? '',
          },
          'refresh': true,
        });
        break;
      case 'getWorldEntryDetail':
        final bookId = data['bookId'] as String? ?? '';
        final id = data['id'] as String?;
        if (bookId.isEmpty) return;
        final book = await repo.getWorldInfoById(bookId);
        Map<String, dynamic> detail = {};
        if (book != null && id != null && id.isNotEmpty) {
          for (final e in book.entries) {
            if (e.id == id) {
              detail = {
                'id': e.id,
                'keysStr': e.keys.join(', '),
                'secondaryKeysStr': e.secondaryKeys.join(', '),
                'comment': e.comment,
                'content': e.content,
                'order': e.insertionOrder,
                'enabled': e.enabled,
                'constant': e.constant,
                'selective': e.selective,
                'caseSensitive': e.caseSensitive,
                'matchWholeWords': e.matchWholeWords,
                'useProbability': e.useProbability,
                'probability': e.probability,
                'position': e.position.name,
                'depth': e.depth,
                'role': e.role.name,
                'group': e.group ?? '',
                'groupWeight': e.groupWeight,
                'preventRecursion': e.preventRecursion,
                'excludeRecursion': e.excludeRecursion,
                'delayUntilRecursion': e.delayUntilRecursion,
              };
              break;
            }
          }
        }
        _bridge.send(BridgeType.settingsPanelData, {
          'data': <String, dynamic>{
            'editDetail': detail,
            'currentCharId': character?.id ?? '',
          },
          'refresh': true,
        });
        break;
      case 'toggleWorldEntry':
        final bookId = data['bookId'] as String? ?? '';
        final id = data['id'] as String? ?? '';
        final enabled = data['enabled'] as bool? ?? true;
        if (bookId.isEmpty || id.isEmpty) return;
        final book = await repo.getWorldInfoById(bookId);
        if (book == null) return;
        for (final e in book.entries) {
          if (e.id == id) {
            await notifier.updateEntry(e.copyWith(enabled: enabled));
            break;
          }
        }
        final updated = await repo.getWorldInfoById(bookId);
        final entries = (updated?.entries ?? [])
            .map((e) => <String, dynamic>{
                  'id': e.id,
                  'comment': e.comment,
                  'keysStr': e.keys.join(', '),
                  'enabled': e.enabled,
                  'constant': e.constant,
                })
            .toList();
        _bridge.send(BridgeType.settingsPanelData, {
          'data': <String, dynamic>{
            'entries': entries,
            'currentCharId': character?.id ?? '',
          },
          'refresh': true,
        });
        break;
      case 'deleteWorldEntry':
        final id = data['id'] as String? ?? '';
        if (id.isEmpty) return;
        final ok = await _showHtmlConfirm(
          title: '删除条目',
          message: '删除该条目？此操作不可撤销。',
          confirmText: '删除',
          cancelText: '取消',
          danger: true,
        );
        if (!mounted || !ok) return;
        await notifier.deleteEntry(id);
        final bookId = data['bookId'] as String? ?? '';
        final updated = bookId.isNotEmpty
            ? await repo.getWorldInfoById(bookId)
            : null;
        final entries = (updated?.entries ?? [])
            .map((e) => <String, dynamic>{
                  'id': e.id,
                  'comment': e.comment,
                  'keysStr': e.keys.join(', '),
                  'enabled': e.enabled,
                  'constant': e.constant,
                })
            .toList();
        _bridge.send(BridgeType.settingsPanelData, {
          'data': <String, dynamic>{
            'entries': entries,
            'currentCharId': character?.id ?? '',
          },
          'refresh': true,
        });
        break;
      case 'saveWorldEntry':
        final bookId = data['bookId'] as String? ?? '';
        final id = data['id'] as String?;
        final keysRaw = data['keys'] as String? ?? '';
        final secKeysRaw = data['secondaryKeys'] as String? ?? '';
        final comment = data['comment'] as String? ?? '';
        final content = data['content'] as String? ?? '';
        final order = (data['order'] as num?)?.toInt() ?? 100;
        final enabled = data['enabled'] as bool? ?? true;
        final constant = data['constant'] as bool? ?? false;
        final selective = data['selective'] as bool? ?? false;
        final caseSensitive = data['caseSensitive'] as bool? ?? false;
        final matchWholeWords = data['matchWholeWords'] as bool? ?? false;
        final useProbability = data['useProbability'] as bool? ?? false;
        final probability = (data['probability'] as num?)?.toInt() ?? 100;
        final positionStr = data['position'] as String? ?? 'before';
        final depth = (data['depth'] as num?)?.toInt() ?? 0;
        final roleStr = data['role'] as String? ?? 'system';
        final group = data['group'] as String?;
        final groupWeight = (data['groupWeight'] as num?)?.toInt() ?? 100;
        final preventRecursion = data['preventRecursion'] as bool? ?? false;
        final excludeRecursion = data['excludeRecursion'] as bool? ?? false;
        final delayUntilRecursion = data['delayUntilRecursion'] as bool? ?? false;
        if (bookId.isEmpty) return;
        if (!constant && keysRaw.trim().isEmpty) {
          _snack('触发词不能为空（或勾选「始终插入」）');
          return;
        }
        final keys = keysRaw
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        final secondaryKeys = secKeysRaw
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        final position = models.WorldInfoPosition.values.firstWhere(
          (p) => p.name == positionStr,
          orElse: () => models.WorldInfoPosition.before,
        );
        final role = models.WorldInfoRole.values.firstWhere(
          (r) => r.name == roleStr,
          orElse: () => models.WorldInfoRole.system,
        );
        if (id != null && id.isNotEmpty) {
          final book = await repo.getWorldInfoById(bookId);
          if (book != null) {
            for (final e in book.entries) {
              if (e.id == id) {
                await notifier.updateEntry(e.copyWith(
                  keys: keys,
                  secondaryKeys: secondaryKeys,
                  comment: comment,
                  content: content,
                  insertionOrder: order,
                  enabled: enabled,
                  constant: constant,
                  selective: selective,
                  caseSensitive: caseSensitive,
                  matchWholeWords: matchWholeWords,
                  useProbability: useProbability,
                  probability: probability,
                  position: position,
                  depth: depth,
                  role: role,
                  group: (group != null && group.isNotEmpty) ? group : e.group,
                  groupWeight: groupWeight,
                  preventRecursion: preventRecursion,
                  excludeRecursion: excludeRecursion,
                  delayUntilRecursion: delayUntilRecursion,
                ));
                break;
              }
            }
          }
        } else {
          await notifier.addEntry(
            worldInfoId: bookId,
            keys: keys,
            content: content,
            secondaryKeys: secondaryKeys.isNotEmpty ? secondaryKeys : null,
            comment: comment,
            position: position,
            constant: constant,
            selective: selective,
            insertionOrder: order,
          );
        }
        _snack('已保存');
        final updated = await repo.getWorldInfoById(bookId);
        final entries = (updated?.entries ?? [])
            .map((e) => <String, dynamic>{
                  'id': e.id,
                  'comment': e.comment,
                  'keysStr': e.keys.join(', '),
                  'enabled': e.enabled,
                  'constant': e.constant,
                })
            .toList();
        _bridge.send(BridgeType.settingsPanelData, {
          'data': <String, dynamic>{
            'entries': entries,
            'currentCharId': character?.id ?? '',
          },
          'refresh': true,
        });
        break;
    }
  }

  // Image generation settings panel

  Future<void> _openImageGenPanel() async {
    _bridge.send(BridgeType.openSettingsPanel, {
      'panel': 'imageGen',
      'title': '生图设置',
      'data': _serializeImageGenData(),
    });
  }

  Map<String, dynamic> _serializeImageGenData() {
    final settings = ref.read(imageGenSettingsProvider);
    final models = ref.read(availableModelsProvider);
    return <String, dynamic>{
      'enabled': settings.enabled,
      'autoImageMode': settings.autoImageMode.id,
      'provider': settings.provider.id,
      'model': settings.model,
      'availableModels': models,
      'apiKey': (settings.apiKey?.isNotEmpty ?? false) ? '***REDACTED***' : '',
      'apiEndpoint': settings.effectiveEndpoint,
      'requiresApiKey': settings.provider.requiresApiKey,
      'isLocalProvider': settings.provider.isLocalProvider,
      'defaultWidth': settings.defaultWidth,
      'defaultHeight': settings.defaultHeight,
      'defaultNegativePrompt': settings.defaultNegativePrompt ?? '',
      'positivePromptPrefix': settings.positivePromptPrefix ?? '',
      'imageTagInstruction': settings.imageTagInstruction ?? '',
      'enableAutoPromptGeneration': settings.enableAutoPromptGeneration,
      'defaultSteps': settings.defaultSteps,
      'defaultCfgScale': settings.defaultCfgScale,
      'defaultSampler': settings.defaultSampler,
      'availableSamplers': ImageGenSampler.forProvider(settings.provider)
          .map((s) => s.name)
          .toList(),
      'novelaiAnlasGuard': settings.novelaiAnlasGuard,
      'novelaiSm': settings.novelaiSm,
      'novelaiSmDyn': settings.novelaiSmDyn,
      'novelaiDecrisper': settings.novelaiDecrisper,
      'novelaiVarietyBoost': settings.novelaiVarietyBoost,
      'openaiStyle': settings.openaiStyle,
      'openaiQuality': settings.openaiQuality,
      'availableProviders': ImageGenProvider.values
          .map((p) => {'value': p.id, 'label': p.displayName})
          .toList(),
    };
  }

  Future<void> _handleImageGenPanelAction(
      String action, Map<String, dynamic> data) async {
    final notifier = ref.read(imageGenSettingsProvider.notifier);
    switch (action) {
      case 'toggleEnabled':
        notifier.setEnabled(data['enabled'] as bool);
        break;
      case 'setAutoImageMode':
        notifier.setAutoImageMode(AutoImageMode.fromId(data['mode'] as String?));
        break;
      case 'setProvider':
        final provider = ImageGenProvider.fromId(data['provider'] as String);
        if (provider != null) {
          notifier.setProvider(provider);
          // Refresh the panel after switching providers so it shows the new provider's API config and model
          _bridge.send(BridgeType.settingsPanelData, {
            'data': _serializeImageGenData(),
            'refresh': true,
          });
        }
        break;
      case 'setModel':
        notifier.setModel(data['model'] as String);
        break;
      case 'setApiKey':
        final imageGenKey = data['key'] as String?;
        // Ignore the redacted value echoed back by the panel so it cannot overwrite the real key
        if (imageGenKey == '***REDACTED***') break;
        notifier.setApiKey(imageGenKey);
        break;
      case 'setApiEndpoint':
        notifier.setApiEndpoint(data['endpoint'] as String?);
        break;
      case 'setDefaultWidth':
        notifier.setDefaultWidth((data['width'] as num).toInt());
        break;
      case 'setDefaultHeight':
        notifier.setDefaultHeight((data['height'] as num).toInt());
        break;
      case 'setImageSize':
        // Preset size selection: parse the "widthxheight" string and set both dimensions
        final size = data['size'] as String?;
        if (size != null && size != 'custom') {
          final parts = size.split('x');
          if (parts.length == 2) {
            final w = int.tryParse(parts[0]);
            final h = int.tryParse(parts[1]);
            if (w != null && h != null) {
              notifier.setDefaultWidth(w);
              notifier.setDefaultHeight(h);
              _bridge.send(BridgeType.settingsPanelData, {
                'data': _serializeImageGenData(),
                'refresh': true,
              });
            }
          }
        }
        break;
      case 'setCustomWidth':
        notifier.setDefaultWidth((data['width'] as num).toInt());
        break;
      case 'setCustomHeight':
        notifier.setDefaultHeight((data['height'] as num).toInt());
        break;
      case 'setDefaultSteps':
        notifier.setDefaultSteps((data['steps'] as num).toInt());
        break;
      case 'setDefaultCfgScale':
        notifier.setDefaultCfgScale((data['cfgScale'] as num).toDouble());
        break;
      case 'setDefaultNegativePrompt':
        notifier.setDefaultNegativePrompt(data['prompt'] as String?);
        break;
      case 'setPositivePromptPrefix':
        notifier.setPositivePromptPrefix(data['prefix'] as String?);
        break;
      case 'setImageTagInstruction':
        notifier.setImageTagInstruction(data['instruction'] as String?);
        break;
      case 'toggleAutoPromptGeneration':
        notifier.setEnableAutoPromptGeneration(data['enabled'] as bool);
        break;
      case 'setOpenaiStyle':
        notifier.setOpenaiStyle(data['style'] as String);
        break;
      case 'setOpenaiQuality':
        notifier.setOpenaiQuality(data['quality'] as String);
        break;
      case 'setSampler':
        notifier.setDefaultSampler(data['value'] as String);
        break;
      case 'setNovelaiAnlasGuard':
        notifier.setNovelaiAnlasGuard(data['enabled'] as bool);
        break;
      case 'setNovelaiSm':
        notifier.setNovelaiSm(data['enabled'] as bool);
        break;
      case 'setNovelaiSmDyn':
        notifier.setNovelaiSmDyn(data['enabled'] as bool);
        break;
      case 'setNovelaiDecrisper':
        notifier.setNovelaiDecrisper(data['enabled'] as bool);
        break;
      case 'setNovelaiVarietyBoost':
        notifier.setNovelaiVarietyBoost(data['enabled'] as bool);
        break;
    }
  }

  // HTML dialog helpers: confirm box / prompt box / bottom action sheet
  // Dialogs render inside the WebView alongside messages, so there is no Flutter layer
  // compositing overhead for HC, and no pause/resume either (pause freezes card scripts).
  // Results come back through dialogResult, matched by callbackId.

  Future<dynamic> _waitForDialogResult(String callbackId) {
    final completer = Completer<dynamic>();
    _dialogCompleters[callbackId] = completer;
    // Timeout fallback: if dialog rendering fails or a WebView rebuild drops the message the
    // Completer hangs forever, taking the caller (including the onLoadStop injection chain) down with it.
    // A 30s wait with no reply resolves as a cancel.
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _dialogCompleters.remove(callbackId);
        debugPrint('[弹窗超时] callbackId=$callbackId 等待超时30s，默认返回false');
        return false;
      },
    );
  }

  /// HTML confirm box. Passing an empty [cancelText] turns it into a single-button alert.
  Future<bool> _showHtmlConfirm({
    required String title,
    required String message,
    String confirmText = '确认',
    String cancelText = '取消',
    bool danger = false,
  }) async {
    final callbackId = 'dlg_${DateTime.now().microsecondsSinceEpoch}';
    _bridge.send(BridgeType.showConfirm, {
      'title': title,
      'message': message,
      'confirmText': confirmText,
      'cancelText': cancelText,
      'callbackId': callbackId,
      'danger': danger,
    });
    final result = await _waitForDialogResult(callbackId);
    return result == true;
  }

  /// HTML input dialog. Returns null on cancel.
  Future<String?> _showHtmlPrompt({
    required String title,
    required String message,
    String initial = '',
  }) async {
    final callbackId = 'dlg_${DateTime.now().microsecondsSinceEpoch}';
    _bridge.send(BridgeType.showPrompt, {
      'title': title,
      'message': message,
      'initial': initial,
      'callbackId': callbackId,
    });
    final result = await _waitForDialogResult(callbackId);
    return result is String ? result : null;
  }

  /// HTML bottom sheet. Returns null on cancel, the selected value otherwise.
  Future<String?> _showHtmlBottomSheet(
    List<Map<String, dynamic>> items, {
    String? title,
  }) async {
    final callbackId = 'dlg_${DateTime.now().microsecondsSinceEpoch}';
    _bridge.send(BridgeType.showBottomSheet, {
      'items': items,
      'title': title,
      'callbackId': callbackId,
    });
    final result = await _waitForDialogResult(callbackId);
    return result is String ? result : null;
  }

  // The three-dot button has been replaced by a plus menu (via func-overlay), so this method
  // currently has no entry point; kept in case we roll back -- clear chat / manual summarize are
  // only reachable from here today, and could later be hooked into func-overlay.
  Future<void> _showTopMenuSheet() async {
    final result = await _showHtmlBottomSheet([
      {'text': '导出聊天', 'value': 'exportChat'},
      {'text': '导入聊天', 'value': 'importChat'},
      {'text': '清空聊天', 'value': 'clearChat', 'danger': true},
      {'text': '手动总结上下文', 'value': 'manualSummarize'},
      {'text': '全局设置', 'value': 'globalSettings'},
    ], title: '聊天选项');
    if (!mounted || result == null) return;
    switch (result) {
      case 'exportChat':
        await _exportChatRecord();
        break;
      case 'importChat':
        await _importChatRecord();
        break;
      case 'clearChat':
        await _confirmClearChat();
        break;
      case 'manualSummarize':
        await _confirmManualSummarize();
        break;
      case 'globalSettings':
        await _openBackgroundPanel();
        break;
    }
  }

  Future<void> _confirmClearChat() async {
    // HTML confirm box, no pause/resume needed (dialogs live in the WebView alongside messages)
    final ok = await _showHtmlConfirm(
      title: '清空聊天',
      message: '将删除本对话的全部消息，且不可恢复。确定吗？',
      confirmText: '清空',
      cancelText: '取消',
      danger: true,
    );
    if (!mounted) return;
    if (ok) {
      ref.read(activeChatProvider.notifier).clearChat();
      await _pushMessages();
    }
  }

  Future<void> _confirmManualSummarize() async {
    // HTML confirm box, no pause/resume needed
    final ok = await _showHtmlConfirm(
      title: '手动总结上下文',
      message:
          '将基于当前全部历史重新生成一份总结，覆盖已有总结。适合自动总结失败或效果不佳时使用。可能耗时并消耗较多 token，确定吗？',
    );
    if (!mounted) return;
    if (ok) {
      _snack('正在总结上下文…');
      final err = await ref.read(activeChatProvider.notifier).manualSummarize();
      _snack(err ?? '总结完成');
    }
  }

  Future<void> _exportChatRecord({bool? useJsonl, bool? toFile}) async {
    final chatState = ref.read(activeChatProvider);
    if (chatState.chat == null || chatState.character == null) {
      _snack('当前聊天无法导出');
      return;
    }
    final userName =
        ref.read(activePersonaProvider).valueOrNull?.name ?? 'User';

    // Let the user pick first: share, or save to file (skipped when called with arguments)
    // HTML bottom sheet, no pause/resume needed
    String? mode;
    if (useJsonl == null && toFile == null) {
      mode = await _showHtmlBottomSheet(const [
        {'text': '分享', 'value': 'share'},
        {'text': '保存到文件', 'value': 'file'},
      ], title: '导出聊天');
      if (!mounted) return;
      if (mode == null) return;
    } else {
      mode = (toFile == true) ? 'file' : 'share';
    }

    // Inject Chronicle capability so the export embeds kira_chronicle
    final service = ChatExportService(
      chronicleRepo: ref.read(chronicleRepositoryProvider),
      vectorStorage: ref.read(vectorStorageServiceProvider),
    );
    try {
      if (mode == 'share') {
        await service.exportAndShare(
          chatState.chat!,
          chatState.messages,
          chatState.character!,
          userName: userName,
          useJsonl: useJsonl ?? true,
        );
      } else {
        final path = await service.exportToFile(
          chatState.chat!,
          chatState.messages,
          chatState.character!,
          userName: userName,
          useJsonl: useJsonl ?? true,
        );
        if (path != null) {
          _snack('已保存到：$path');
        } else {
          _snack('已取消保存');
        }
      }
    } catch (e) {
      _snack('导出失败：$e');
    }
  }

  Future<void> _importChatRecord() async {
    await _controller?.pause();
    final l10n = AppLocalizations.of(context);
    try {
      final exportService = ref.read(chatExportServiceProvider);
      final result = await exportService.importFromFile();
      // Resume the WebView as soon as the system file picker returns: the confirm dialog after
      // this is HTML-based, so the WebView must stay alive
      await _controller?.resume();
      if (result == null) {
        _snack('未选择文件');
        return;
      }

      if (!mounted) return;

      // Confirmation dialog: show the import details (HTML confirm box, details joined into multiple lines)
      final details = [
        '${l10n.character}: ${result.characterName}',
        '${l10n.user}: ${result.userName}',
        '${l10n.messages}: ${result.messages.length}',
        '${l10n.date}: ${result.createDate.toString().split('.')[0]}',
        if (result.authorNote != null && result.authorNote!.isNotEmpty)
          '${l10n.hasAuthorsNote}: ${l10n.yes}',
        '',
        l10n.importMessagesToCurrentChat,
      ].join('\n');
      final confirmed = await _showHtmlConfirm(
        title: l10n.importConfirmation,
        message: details,
      );

      if (!confirmed) {
        return;
      }

      // Persist: pass widget.chatId explicitly instead of relying on state.chat
      final chatNotifier = ref.read(activeChatProvider.notifier);
      const uuid = Uuid();
      final importedCount = await chatNotifier.importMessages(
        result.messages.map((m) => m.toChatMessage(widget.chatId, uuid.v4())).toList(),
        chatId: widget.chatId,
      );

      // Restore the embedded super memory
      if (result.chronicleData != null) {
        await exportService.restoreChronicleToChat(
            widget.chatId, result.chronicleData!);
      }

      // Update the author note
      if (result.authorNote != null && result.authorNote!.isNotEmpty) {
        await chatNotifier.updateAuthorNote(result.authorNote!);
        if (result.authorNoteDepth != null) {
          await chatNotifier.updateAuthorNoteDepth(result.authorNoteDepth!);
        }
        if (result.authorNoteEnabled == true) {
          await chatNotifier.toggleAuthorNote(true);
        }
      }

      _snack(l10n.importedMessages(importedCount));
    } catch (e) {
      _snack(l10n.importFailed(e.toString()));
    } finally {
      await _controller?.resume();
    }
  }
  Future<void> _sendMessage() async {
    final content = _inputController.text.trim();
    final attachments = List<ChatAttachment>.from(_pendingAttachments);
    // Skip only when there is neither text nor image
    if (content.isEmpty && attachments.isEmpty) return;
    final config = ref.read(llmConfigProvider);
    _inputController.clear();
    // Clear pending attachments and refresh the preview
    setState(() => _pendingAttachments.clear());
    _inputFocus.unfocus();
    // Images never enter the WebView (they are handled by a separate image view), so sending
    // works the same with or without images.
    // Fire MVU initCheck (generation_started is emitted before generation starts)
    _controller?.evaluateJavascript(
        source: 'if(window.__emitToEngine)window.__emitToEngine("generation_started",[],${jsonEncode(_serializeMessagesForMvu())});');
    await ref
        .read(activeChatProvider.notifier)
        .sendMessage(content, config, attachments: attachments);
  }

  Future<void> _pickImages() async {
    try {
      final files = await _imagePicker.pickMultiImage();
      if (files.isEmpty) return;
      for (final xfile in files) {
        await _addAttachmentFromXFile(xfile);
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }

  /// Adds an image picked from the gallery to the pending attachments (without sending it
  /// immediately), so the user can keep typing after returning to the chat and send text and
  /// image together at the end.
  Future<void> _sendImageFile(File file) async {
    try {
      final stat = await file.stat();
      const uuid = Uuid();
      final ext = p.extension(file.path);
      final size = await compute(_probeImageSize, file.path);
      _pendingAttachments.add(ChatAttachment(
        id: uuid.v4(),
        path: file.path,
        mimeType: _getMimeType(ext),
        sizeBytes: stat.size,
        width: size?['w'],
        height: size?['h'],
      ));
      if (mounted) {
        setState(() {}); // refresh the pending preview above the input box
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('图片已添加，可继续输入文字后发送')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加图片失败: $e')),
        );
      }
    }
  }

  /// Writes the selected image bytes into the app directory and builds a ChatAttachment.
  Future<void> _addAttachmentFromBytes(Uint8List bytes, String name) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final attachmentsDir =
          Directory(p.join(appDir.path, 'NativeTavern', 'attachments'));
      await attachmentsDir.create(recursive: true);

      const uuid = Uuid();
      var extension = p.extension(name);
      if (extension.isEmpty) extension = '.jpg';
      final newFileName = '${uuid.v4()}$extension';
      final newPath = p.join(attachmentsDir.path, newFileName);

      await File(newPath).writeAsBytes(bytes);
      final fileInfo = await File(newPath).stat();

      final size = await compute(_probeImageSize, newPath);
      _pendingAttachments.add(ChatAttachment(
        id: uuid.v4(),
        path: newPath,
        mimeType: _getMimeType(extension),
        sizeBytes: fileInfo.size,
        width: size?['w'],
        height: size?['h'],
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加附件失败: $e')),
        );
      }
    }
  }

  /// Copies the selected image into the app documents directory and builds a ChatAttachment.
  Future<void> _addAttachmentFromXFile(XFile file) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final attachmentsDir =
          Directory(p.join(appDir.path, 'NativeTavern', 'attachments'));
      await attachmentsDir.create(recursive: true);

      const uuid = Uuid();
      final extension = p.extension(file.path);
      final newFileName = '${uuid.v4()}$extension';
      final newPath = p.join(attachmentsDir.path, newFileName);

      final bytes = await file.readAsBytes();
      await File(newPath).writeAsBytes(bytes);
      final fileInfo = await File(newPath).stat();

      final size = await compute(_probeImageSize, newPath);
      final attachment = ChatAttachment(
        id: uuid.v4(),
        path: newPath,
        mimeType: _getMimeType(extension),
        sizeBytes: fileInfo.size,
        width: size?['w'],
        height: size?['h'],
      );
      _pendingAttachments.add(attachment);
      // Warm the cache: read the file and base64-encode it in a background isolate so sending
      // can use it directly without blocking the main thread
      compute(encodeFileToBase64, newPath).then((b64) {
        _attachmentB64Cache[newPath] = b64;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加附件失败: $e')),
        );
      }
    }
  }

  /// Infers the MIME type from the extension.
  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.bmp':
        return 'image/bmp';
      default:
        return 'image/jpeg';
    }
  }

  // Bubble action button handling

  void _handleAction(Map<String, dynamic> payload) {
    final id = payload['id'] as String? ?? '';
    final action = payload['action'] as String? ?? '';
    // Full-screen image viewer: intercepted before the id / isGenerating checks,
    // since viewing an image is not subject to those limits
    if (action == 'viewImage') {
      final attPath = payload['attPath'] as String? ?? '';
      if (attPath.isNotEmpty) _showFullImage(attPath);
      return;
    }
    // Flicker fix: when the targeted JS update fails (missing node / card message) -> fall back to a full re-push
    if (action == 'needFullPush') {
      _pushMessages();
      return;
    }
    // A send triggered by a script via #send_but (Fox, etc.): equivalent to the user tapping
    // send in the input box.
    // It has no bubble id, so it must be handled before the empty-id bail-out.
    if (action == 'sendFromStage') {
      final text = (payload['text'] as String? ?? '').trim();
      if (text.isEmpty) return;
      if (ref.read(activeChatProvider).isGenerating) return;
      final config = ref.read(llmConfigProvider);
      ref.read(activeChatProvider.notifier).sendMessage(text, config);
      return;
    }
    if (id.isEmpty) return;
    // Bubble action buttons are disabled while generating to avoid clashing with the running generation
    if (ref.read(activeChatProvider).isGenerating) return;
    final notifier = ref.read(activeChatProvider.notifier);
    final config = ref.read(llmConfigProvider);

    switch (action) {
      case 'tts':
        _speakMessage(id);
        break;
        break;
      case 'continue':
        _confirmAndRun(
          '继续生成',
          '让 AI 在这条消息上继续续写？',
          () => notifier.continueMessage(id, config),
        );
        break;
      case 'retry':
        _confirmAndRun(
          '重试',
          '将删除这条之后的内容并重新生成，确定吗？',
          () async {
            if (mounted) {
              _bridge.send(BridgeType.showToast, {'text': '正在重试…'});
            }
            await notifier.retryMessage(id, config);
          },
        );
        break;
      case 'reroll':
        // Keep the old version and generate a new one (adds a swipe)
        // Made fire-and-forget async: regenerateMessage is a Future, with a toast once it finishes
        () async {
          await notifier.regenerateMessage(id, config);
          if (mounted) {
            _bridge.send(BridgeType.showToast, {'icon': '✨', 'text': '重新生成中'});
          }
        }();
        break;
      case 'swipePrev':
        _switchSwipe(id, -1);
        break;
      case 'swipeNext':
        _switchSwipe(id, 1);
        break;
      case 'edit':
        _showEditDialog(id);
        break;
      case 'delete':
        _showDeleteConfirm(id);
        break;
      case 'more':
        _showMoreSheet(id);
        break;
      case 'imagegen':
        _showImageGenerationDialog(id);
        break;
      case 'translate':
        _translateMessage(id);
        break;
    }
  }

  void _speakMessage(String id) {
    final msgs = ref.read(activeChatProvider).messages;
    final idx = msgs.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    final speak = ref.read(ttsSpeakProvider);
    speak(msgs[idx].content); // TTSService runs _cleanTextForTTS internally
  }
  void _showFullImage(String encodedPath) {
    final path = Uri.decodeComponent(encodedPath);
    // Parse msgId from the file name: ai_auto_{msgId}_{i}.png
    String? msgId;
    final m = RegExp(r'ai_auto_(\d+)_').firstMatch(p.basename(path));
    if (m != null) msgId = m.group(1);
    debugPrint('[全屏图] path=$path');
    debugPrint('[全屏图] 解析msgId=$msgId, basename=${p.basename(path)}');
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, __, ___) => _FullImageViewer(
        path: path,
        onRegenerate: msgId == null
            ? null
            : () {
                Navigator.of(context).pop(); // close the full-screen view
                final config = ref.read(llmConfigProvider);
                ref
                    .read(activeChatProvider.notifier)
                    .regenerateAutoImage(msgId!, config);
              },
      ),
    ));
  }
  /// Generates an illustration for a message: opens the image generation dialog, then attaches
  /// the result to that message.
  void _showImageGenerationDialog(String messageId) async {
    final state = ref.read(activeChatProvider);
    final message = state.messages.firstWhere(
      (m) => m.id == messageId,
      orElse: () => state.messages.first,
    );
    final character = state.character;

    final result = await ImageGenerationDialog.show(
      context,
      basePrompt: ImageGenerationService.extractImagePrompt(message.content)
          ?? message.content,
      characterName: character?.name,
      mode: message.role == MessageRole.assistant
          ? ImageGenMode.lastMessage
          : ImageGenMode.free,
    );

    if (result != null && result.images.isNotEmpty && mounted) {
      try {
        final appDocDir = await getApplicationDocumentsDirectory();
        // Store in the chat-specific subdirectory chat_images/{chatId}/, consistent with the gallery page
        final imagesDir = Directory(
            p.join(appDocDir.path, 'chat_images', widget.chatId));
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }

        for (int i = 0; i < result.images.length; i++) {
          final imageBytes = result.images[i];
          final imageId = const Uuid().v4();
          // the ai_ prefix makes the gallery page file it under the "AI generated" subpage
          final fileName = 'ai_$imageId.${result.format}';
          final filePath = p.join(imagesDir.path, fileName);
          await File(filePath).writeAsBytes(imageBytes);

          final size = await compute(_probeImageSize, filePath);
          final attachment = ChatAttachment(
            id: imageId,
            path: filePath,
            mimeType: 'image/${result.format}',
            sizeBytes: imageBytes.length,
            width: size?['w'],
            height: size?['h'],
          );
          await ref
              .read(activeChatProvider.notifier)
              .addAttachmentToMessage(message.id, attachment);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('生成完成 - 已添加 ${result.images.length} 张图片')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('保存图片失败: $e')),
          );
        }
      }
    }
  }
  // Switch a message's reply version (swipe): delta -1 for the previous version / +1 for the next
  void _switchSwipe(String id, int delta) {
    final state = ref.read(activeChatProvider);
    final msg = state.messages.firstWhere(
      (m) => m.id == id,
      orElse: () => state.messages.first,
    );
    if (msg.swipes.length <= 1) return;
    final next = msg.currentSwipeIndex + delta;
    if (next < 0 || next >= msg.swipes.length) return; // no wrap-around at either end
    ref.read(activeChatProvider.notifier).swipeMessage(id, next);
  }

  // Generic confirm box (the WebView is paused to avoid compositing overhead)

  Future<void> _confirmAndRun(
    String title,
    String body,
    VoidCallback action,
  ) async {
    // HTML confirm box, no pause/resume needed
    final ok = await _showHtmlConfirm(title: title, message: body);
    if (!mounted) return;
    if (ok) action();
  }

  // Edit (full-screen page, to avoid HC compositing overhead)

  Future<void> _showEditDialog(String id) async {
    final messages = ref.read(activeChatProvider).messages;
    final idx = messages.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    await _controller?.pause();
    String? result;
    try {
      result = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (ctx) =>
              _EditMessagePage(initialText: messages[idx].content),
        ),
      );
    } finally {
      await _controller?.resume();
    }
    if (result != null) {
      await ref.read(activeChatProvider.notifier).editMessage(id, result);
      _updateSingleMessage(id);
      // Edit saved: dynamic-island toast in the WebView
      if (mounted) {
        _bridge.send(BridgeType.showToast, {'icon': '✏️', 'text': '消息已修改'});
      }
    }
  }

  // Delete confirmation

  Future<void> _showDeleteConfirm(String id) async {
    // HTML confirm box (missed in the previous migration round, added now), no pause/resume needed
    final ok = await _showHtmlConfirm(
      title: '删除消息',
      message: '确定删除这条消息吗？此操作无法撤销。',
      confirmText: '删除',
      cancelText: '取消',
      danger: true,
    );
    if (!mounted) return;
    if (ok) {
      // Flicker fix: no explicit full push anymore -- after deleteMessage changes state, ref.listen
      // branches by change type (mid-delete -> structural change, full re-layout of floors;
      // tail truncation -> targeted removal), so pushing again would clear the screen twice
      await ref.read(activeChatProvider.notifier).deleteMessage(id);
      // Delete finished: dynamic-island toast in the WebView
      if (mounted) {
        _bridge.send(BridgeType.showToast, {'icon': '🗑️', 'text': '消息已删除'});
      }
    }
  }

  // More actions bottom menu

  Future<void> _showMoreSheet(String id) async {
    // HTML bottom sheet, no pause/resume needed
    final result = await _showHtmlBottomSheet(const [
      {'text': '删除此条及之后所有', 'value': 'delete_after', 'danger': true},
    ]);
    if (!mounted || result == null) return;
    if (result == 'delete_after') {
      // Flicker fix: tail truncation goes through ref.listen as a targeted removal
      // (removeMessage), so no explicit full push
      await ref
          .read(activeChatProvider.notifier)
          .deleteMessageAndAfter(id);
    }
  }

  // Translate message (direct LLM translation, result shown as light small text under the bubble)

  Future<void> _translateMessage(String id) async {
    if (_translatingIds.contains(id)) return;
    final messages = ref.read(activeChatProvider).messages;
    final idx = messages.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    final content = messages[idx].content.trim();
    if (content.isEmpty) return;

    _translatingIds.add(id);
    // Push a placeholder first, overwritten once the translation comes back
    _bridge.send(BridgeType.setMessageTranslation, {'id': id, 'text': '正在翻译…'});
    try {
      final config = ref.read(llmConfigProvider);
      final translated = await ref.read(llmServiceProvider).generate(
        [
          {
            'role': 'system',
            'content': '你是翻译引擎。将用户发送的文本翻译为中文，只输出翻译结果，'
                '不要输出任何解释、原文或额外说明。如果文本本身已是中文，原样输出。',
          },
          {'role': 'user', 'content': content},
        ],
        config,
      );
      final text = translated.trim();
      if (!mounted) return;
      if (text.isEmpty) {
        _bridge.send(BridgeType.setMessageTranslation, {'id': id, 'text': ''});
        showErrorSnackBar(context, '翻译结果为空');
        return;
      }
      _bridge.send(BridgeType.setMessageTranslation, {'id': id, 'text': text});
    } catch (e) {
      if (!mounted) return;
      // Failure: clear the placeholder
      _bridge.send(BridgeType.setMessageTranslation, {'id': id, 'text': ''});
      showErrorSnackBar(context, '翻译失败：$e');
    } finally {
      _translatingIds.remove(id);
    }
  }

  // Push messages to the WebView

  // Serializes a single message into a Map for _pushMessages
  Map<String, dynamic> _serializeMessage(
      ChatMessage m, int i, int lastAiIndex, Character? character, List<RegexScript> scripts) {
    String rawContent = m.content.isEmpty
        ? ''
        : RegexService.instance.getRegexedString(
            m.content,
            m.role == MessageRole.user
                ? RegexPlacement.userInput
                : RegexPlacement.aiOutput,
            scripts,
            characterName: character?.name,
            userName: null,
            isMarkdown: true,
            isPrompt: false,
            isEdit: false,
            depth: i,
          );
    // Strip the <image> tags from auto-generated images; display only, the stored source is untouched
    rawContent = rawContent
        .replaceAll(RegExp(r'<image>[\s\S]*?</image>', caseSensitive: false), '')
        .trim();
    // afterRegexPrePeel = the real regex output length before codeBlockMatch peels the fence.
    // The old afterRegex trace recorded the post-peel value (afterRegex == afterUnwrap always
    // held), so it observed nothing.
    final afterRegexPrePeel = rawContent.length;
    final codeBlockMatch = RegExp(
      // Strip only the ```html fence. The original [a-zA-Z]* matched any language: when an entire
      // message was a single ```markdown/```text fence (e.g. an AI explaining "what is a script"),
      // the fence was stripped, and any <style/<script text in the content made isRichHtml treat
      // it as an HTML card and push it into an iframe -> transparent background + black text +
      // blank collapsed content + markdown not rendered (layout completely broken).
      // Non-html fences should be kept -> the markdown library renders them as <pre><code> blocks.
      r'^```html\s*\n([\s\S]*?)```\s*$',
      multiLine: false,
      caseSensitive: false,
    ).firstMatch(rawContent.trim());
    // Peel narrowed: only strip when the whole message has <= 1 ```html fence.
    // Peeling a multi-fence message breaks segs pairing (measured in P3-H section 2);
    // for a single-fence message the downstream htmlFenceMatch/docStart paths agree
    // whether or not we peel, so compatibility is preserved.
    final fenceCountPrePeel = RegExp(r'```html\s*\n', caseSensitive: false)
        .allMatches(rawContent)
        .length;
    if (codeBlockMatch != null && fenceCountPrePeel <= 1) {
      rawContent = codeBlockMatch.group(1) ?? rawContent;
    }
    final codeBlockPeeled = codeBlockMatch != null && fenceCountPrePeel <= 1;
    final processed = rawContent;
    // If the message mixes narration text with a complete HTML document, split it at the document
    // start (<!DOCTYPE/<html): narration goes to the markdown bubble, the document goes into an
    // iframe alone, so narration is not dragged into the iframe and squeezed into a narrow strip
    // competing with the card for flex space.
    // A ```html fence is detected first: text before the fence is prose in markdown, HTML inside
    // the fence goes to the iframe
    final htmlFenceMatch = RegExp(
      r'```html\s*\n([\s\S]*?)```',
      caseSensitive: false,
    ).firstMatch(processed);
    String proseHtml = '';
    String bodyForRender = processed;
    if (htmlFenceMatch != null) {
      final before = processed.substring(0, htmlFenceMatch.start).trim();
      if (before.isNotEmpty) {
        proseHtml = _stripInterBlockWs(_highlightQuotes(md.markdownToHtml(
            before,
            extensionSet: md.ExtensionSet.gitHubWeb)));
      }
      bodyForRender = htmlFenceMatch.group(1) ?? ''; // the pure HTML inside the fence
    } else {
      // No ```html fence: fall through to the existing <!DOCTYPE/<html document-splitting logic
      final docStart = RegExp(r'<!DOCTYPE|<html', caseSensitive: false)
          .firstMatch(processed);
      if (docStart != null && docStart.start > 0) {
        final prose = processed.substring(0, docStart.start).trim();
        if (prose.isNotEmpty) {
          proseHtml = _stripInterBlockWs(_highlightQuotes(md.markdownToHtml(
              prose,
              extensionSet: md.ExtensionSet.gitHubWeb)));
        }
        bodyForRender = processed.substring(docStart.start);
      }
    }
    // Document-level check instead of substring-level: plain text mentioning <script>/<body>
    // is no longer misjudged as an HTML card and pushed into an iframe (root cause of broken layout)
    final looksLikeHtml = _looksLikeHtmlDoc(bodyForRender);
    final rendered = looksLikeHtml
        ? normalizeCodeQuotes(bodyForRender)
        : _stripInterBlockWs(_highlightQuotes(md.markdownToHtml(
            bodyForRender,
            extensionSet: md.ExtensionSet.gitHubWeb,
          )));
    final htmlFenceMatches = RegExp(
      r'```html\s*\n([\s\S]*?)```',
      caseSensitive: false,
    ).allMatches(processed).toList();
    List<Map<String, dynamic>>? segs;
    if (htmlFenceMatches.length > 1) {
      segs = <Map<String, dynamic>>[];
      var cursor = 0;
      for (final match in htmlFenceMatches) {
        final gap = processed.substring(cursor, match.start);
        if (gap.trim().isNotEmpty) {
          segs.add({
            'type': 'prose',
            'html': _highlightQuotes(md.markdownToHtml(
              gap,
              extensionSet: md.ExtensionSet.gitHubWeb,
            )),
          });
        }
        final body = match.group(1) ?? '';
        final rich = _looksLikeHtmlDoc(body);
        segs.add({
          'type': rich ? 'frontend' : 'prose',
          'html': rich
              ? normalizeCodeQuotes(body)
              : _highlightQuotes(md.markdownToHtml(
                  body,
                  extensionSet: md.ExtensionSet.gitHubWeb,
                )),
        });
        cursor = match.end;
      }
      final tail = processed.substring(cursor);
      if (tail.trim().isNotEmpty) {
        segs.add({
          'type': 'prose',
          'html': _highlightQuotes(md.markdownToHtml(
            tail,
            extensionSet: md.ExtensionSet.gitHubWeb,
          )),
        });
      }
    }
    final attachmentsHtml = _buildAttachmentsHtml(m);
    final wvScript = RegExp(r'<script', caseSensitive: false).hasMatch(m.content);
    final wvStyle = RegExp(r'<style', caseSensitive: false).hasMatch(m.content);
    final wvHtmlTag = RegExp(r'<[a-zA-Z]', caseSensitive: false).hasMatch(m.content);
    // docCount: occurrences of <!DOCTYPE|<html (bare documents, without a fence)
    final docCount = RegExp(r'<!DOCTYPE|<html', caseSensitive: false)
        .allMatches(processed)
        .length;
    print('[WV-1] id=${m.id} role=${m.role.name} len=${m.content.length} '
        'script=$wvScript style=$wvStyle htmlTag=$wvHtmlTag '
        'fence=${htmlFenceMatch != null} fenceCount=${htmlFenceMatches.length} '
        'docCount=$docCount peeled=$codeBlockPeeled rich=$looksLikeHtml');
    // Length trace across steps (raw->regex->fenceUnwrap->split->render) to locate the step that
    // escapes or swallows content.
    // afterRegex now records the real regex output length before peeling (<codeBlockMatch>),
    // otherwise it always equals afterUnwrap.
    print('[WV-2] id=${m.id} raw=${m.content.length} afterRegex=$afterRegexPrePeel '
        'afterUnwrap=${processed.length} body=${bodyForRender.length} rendered=${rendered.length}');
    // Segs production audit: produced or not, how many segments, each segment's type + length;
    // when null, give the reason (silent failures forbidden).
    if (segs != null) {
      final segDetail = segs
          .map((s) => '${s['type']}:${(s['html'] as String?)?.length ?? 0}')
          .join(',');
      print('[WV-3] id=${m.id} segs=${segs.length} [$segDetail]');
    } else {
      final reason = htmlFenceMatches.isEmpty
          ? 'no-html-fence(全消息无```html围栏)'
          : 'fenceCount<=1(单前端,走旧 prose/html 字段)';
      print('[WV-3] id=${m.id} segs=null reason=$reason');
    }
    // Drop audit: content actually dropped. Iron rule 5 in practice -- without it the next
    // silent drop would go unnoticed.
    // - segs mode: by construction it covers processed character by character, drops 0 (regression guard).
    // - no segs + single-fence path: the fence tail (and the fence markers) are silently dropped
    //   -> droppedRaw = tail length + fence marker overhead.
    // - no segs + docStart path: bodyForRender runs to the end of the message, nothing dropped.
    int droppedRaw = 0;
    if (segs != null) {
      droppedRaw = 0;
    } else if (htmlFenceMatch != null) {
      final fenceBodyLen = (htmlFenceMatch.group(1) ?? '').length;
      droppedRaw = processed.length - fenceBodyLen - htmlFenceMatch.start;
    }
    final warnTag = droppedRaw > 500 ? ' <== WARN: 疑似静默丢弃!' : '';
    print('[WV-4] id=${m.id} processed=${processed.length} '
        'droppedRaw=$droppedRaw (${segs != null ? 'segs模式=0' : 'no-segs单围栏路径'})'
        '$warnTag');
    return {
      'id': m.id,
      'role': m.role.name,
      'createdAt': m.timestamp.millisecondsSinceEpoch,
      'prose': proseHtml, // narration before the document; the render layer puts it above the iframe
      'rich': looksLikeHtml, // tells JS explicitly whether to use the iframe or the bubble, replacing JS-side guesswork
      // Attachments HTML lives in its own field instead of being appended to html: in rich mode
      // it would be dragged into the iframe srcdoc (fixed 300px height, scrolling=no, images buried
      // at the end of the iframe and invisible), and in segs mode the html field is ignored
      // entirely by JS (the attachments would be lost).
      'html': rendered,
      if (attachmentsHtml.isNotEmpty) 'attachmentsHtml': attachmentsHtml,
      if (segs != null) 'segs': segs,
      'reasoning': m.currentReasoning ?? '',
      'swipeCount': m.swipes.length,
      'swipeIndex': m.currentSwipeIndex,
      'floor': i + 1,
      'isLatestAi': i == lastAiIndex,
    };
  }

  /// Single-item serialization fault isolation: if any _serializeMessage call throws, degrade
  /// to one visible placeholder message -- never abort the whole batch, never trigger a
  /// "everything gone and zero logs" outcome.
  Map<String, dynamic> _safeSerializeMessage(
      ChatMessage m, int i, int lastAiIndex, Character? character, List<RegexScript> scripts) {
    try {
      return _serializeMessage(m, i, lastAiIndex, character, scripts);
    } catch (e) {
      print('[WV-8] SERIALIZE-FAIL id=${m.id} err=$e');
      String raw = m.content;
      if (raw.length > 200) raw = raw.substring(0, 200);
      return {
        'id': m.id,
        'role': m.role.name,
        'prose': '此消息序列化失败：$e\n原文（前200字）：$raw',
        'html': '',
        'reasoning': '',
        'swipeCount': m.swipes.length,
        'swipeIndex': m.currentSwipeIndex,
        'floor': i + 1,
        'isLatestAi': i == lastAiIndex,
      };
    }
  }

  /// Batch serialization fallback: encode a list of maps into the base64 payload for setMessages.
  /// If the batch jsonEncode/utf8/base64 fails, fall back to encoding and sending one item at a
  /// time (each with its own try), so the batch never silently fails to send with JS knowing
  /// nothing; if single items fail too, send one visible placeholder.
  Future<void> _sendEncodedMessages(
      List<Map<String, dynamic>> list,
      {bool initial = false, bool prepend = false, Map<String, dynamic>? avatars}) async {
    if (list.isEmpty) return;
    Map<String, dynamic> extra() => {
          if (initial) 'initial': true,
          if (prepend) 'prepend': true,
          if (avatars != null) 'avatars': avatars,
        };
    try {
      final b64 = base64Encode(utf8.encode(jsonEncode(list)));
      _bridge.send(BridgeType.setMessages, {'data': b64, ...extra()});
      return;
    } catch (e) {
      print('[WV-8] BATCH-ENCODE-FAIL count=${list.length} err=$e');
    }

    // Fallback: encode and send one item at a time
    var anySent = false;
    var firstSent = false;
    for (final m in list) {
      try {
        final b64 = base64Encode(utf8.encode(jsonEncode([m])));
        // Only the first item carries initial/avatars: if every item carried initial, JS would
        // clear the screen with root.innerHTML='' on each arrival, and the fallback run would end
        // up with only the last item. prepend must be kept on every item (each one has to be
        // prepended for the in-batch reversal compensation to work).
        final flags = <String, dynamic>{
          if (prepend) 'prepend': true,
          if (initial && !firstSent) 'initial': true,
          if (avatars != null && !firstSent) 'avatars': avatars,
        };
        _bridge.send(BridgeType.setMessages, {'data': b64, ...flags});
        firstSent = true;
        anySent = true;
      } catch (e2) {
        print('[WV-8] ITEM-ENCODE-FAIL id=${m['id']} err=$e2');
      }
    }

    // Single items all failed too: send a visible placeholder so the screen is not blank with no hint
    if (!anySent) {
      try {
        final placeholder = {
          'id': '__encode-fail__',
          'role': 'system',
          'prose': '<p>消息渲染失败：批量与逐条编码均未成功，请重启聊天页。</p>',
          'html': '',
          'reasoning': '',
          'swipeCount': 1,
          'swipeIndex': 0,
          'floor': 1,
          'isLatestAi': true,
        };
        final b64 = base64Encode(utf8.encode(jsonEncode([placeholder])));
        _bridge.send(BridgeType.setMessages, {'data': b64, ...extra()});
      } catch (_) {
        print('[WV-8] PLACEHOLDER-ENCODE-FAIL 无法发送占位消息');
      }
    }
  }

  /// Whether prev is a prefix of next (the first N ids match exactly)
  bool _isPrefix(List<ChatMessage> prev, List<ChatMessage> next) {
    for (var i = 0; i < prev.length; i++) {
      if (prev[i].id != next[i].id) return false;
    }
    return true;
  }

  /// Serializes and appends only the messages newly added at the end, without clearing the page,
  /// to avoid white flashes and jitter
  Future<void> _appendNewMessages(
      int startFrom, List<ChatMessage> messages) async {
    final chatState = ref.read(activeChatProvider);
    final character = chatState.character;
    // Previously this also awaited persona (3s timeout) but never used it (the append path sends
    // no avatar/name) -- a blocking await that wasted time, now removed. This is what the analyzer's
    // unused_local_variable was about.
    final scripts = ref.read(combinedRegexScriptsProvider(character?.id));

    int lastAiIndex = -1;
    for (var i = 0; i < messages.length; i++) {
      if (messages[i].role != MessageRole.user) lastAiIndex = i;
    }

    final list = <Map<String, dynamic>>[];
    for (var i = startFrom; i < messages.length; i++) {
      list.add(_safeSerializeMessage(messages[i], i, lastAiIndex, character, scripts));
    }
    if (list.isEmpty) return;
    // No initial / prepend -> setMessages takes the "append rendering" branch
    await _sendEncodedMessages(list);
    // The pure-append path also needs image patching: a new message with images (sendMessage
    // adds attachments to state in one shot) comes through here, and the placeholder
    // <img data-att-path> only gets its src filled by the setImage channel -- without this step
    // the image never appears
    await _pushImages(messages.sublist(startFrom));
  }

  /// Tail truncation: remove the trailing messages that no longer exist in prev from the DOM
  /// instead of rebuilding the page. Retry (delete the following content and regenerate) and
  /// "delete this and everything after" both come through here; they used to fall into the full
  /// initial rebuild = flicker.
  void _removeMessagesTail(List<ChatMessage> prev, int keepCount) {
    if (keepCount >= prev.length) return;
    final ids = prev.sublist(keepCount).map((m) => m.id).toList();
    if (ids.isEmpty) return;
    _bridge.send(BridgeType.removeMessage, {'ids': ids});
  }

  /// Targeted refresh of the last message: replaces the full _pushMessages after generation ends.
  /// Swaps the accumulated streaming plain text for proper Markdown/HTML rendering, touching only
  /// this one bubble. If the JS node is missing or the content is a card (rich) it sends back
  /// needFullPush and Dart falls back to a full re-push.
  void _updateLastMessage(List<ChatMessage> msgs) {
    if (msgs.isEmpty) {
      _pushMessages();
      return;
    }
    final chatState = ref.read(activeChatProvider);
    final character = chatState.character;
    final scripts = ref.read(combinedRegexScriptsProvider(character?.id));
    final lastIdx = msgs.length - 1;
    int lastAiIndex = -1;
    for (var i = 0; i < msgs.length; i++) {
      if (msgs[i].role != MessageRole.user) lastAiIndex = i;
    }
    final m = _safeSerializeMessage(
        msgs[lastIdx], lastIdx, lastAiIndex, character, scripts);
    _bridge.send(BridgeType.updateMessage, m);
    // Attachment placeholder images go through a separate channel (html holds a data-att-path placeholder)
    _pushImages([msgs[lastIdx]]);
  }

  /// Targeted refresh of a single message: after an edit only that one DOM node is updated,
  /// with no full rebuild.
  /// Rich cards are handled by JS replying needFullPush, falling back to a full re-push.
  void _updateSingleMessage(String id) {
    final chatState = ref.read(activeChatProvider);
    final msgs = chatState.messages;
    final idx = msgs.indexWhere((m) => m.id == id);
    if (idx < 0) { _pushMessages(); return; }
    final character = chatState.character;
    final scripts = ref.read(combinedRegexScriptsProvider(character?.id));
    int lastAiIndex = -1;
    for (var i = 0; i < msgs.length; i++) {
      if (msgs[i].role != MessageRole.user) lastAiIndex = i;
    }
    final m = _safeSerializeMessage(msgs[idx], idx, lastAiIndex, character, scripts);
    _bridge.send(BridgeType.updateMessage, m);
    _pushImages([msgs[idx]]);
  }

  /// Re-pushes already-rendered floors after a regex change: the display effect is baked into
  /// the bubble at serialization time (_serializeMessage calls RegexService.getRegexedString),
  /// so without a re-push the rendered floors keep the old effect (root cause of needing to
  /// leave and re-enter for it to take effect).
  /// updateMessage per message swaps content in place (no full initial rebuild, avoiding the
  /// scroll position loss of a full rebuild); only the default render window is pushed (the
  /// most recent 50, same as _pushMessages' first screen window) -- earlier floors have no DOM
  /// node, so updateMessage replies needFullPush and triggers a full fallback push.
  Future<void> _repushRenderedWindowForRegexChange() async {
    final chatState = ref.read(activeChatProvider);
    final msgs = chatState.messages;
    if (msgs.isEmpty) return;
    final character = chatState.character;
    final scripts = ref.read(combinedRegexScriptsProvider(character?.id));
    int lastAiIndex = -1;
    for (var i = 0; i < msgs.length; i++) {
      if (msgs[i].role != MessageRole.user) lastAiIndex = i;
    }
    const int batchSize = 50;
    final start = msgs.length > batchSize ? msgs.length - batchSize : 0;
    debugPrint('[Bug4] 正则变更重推已渲染楼层: ${msgs.length - start} 条'
        '（从 $start 到 ${msgs.length - 1}）');
    for (var i = start; i < msgs.length; i++) {
      final m = _safeSerializeMessage(msgs[i], i, lastAiIndex, character, scripts);
      _bridge.send(BridgeType.updateMessage, m);
      // patch attachment placeholder images in step (html holds a data-att-path placeholder)
      await _pushImages([msgs[i]]);
    }
  }

  String _buildAttachmentsHtml(ChatMessage m) {
    if (m.attachments.isEmpty) return '';
    final buf = StringBuffer('<div class="att-wrap">');
    for (final att in m.attachments) {
      final encPath = Uri.encodeComponent(att.path);
      // use the real aspect ratio when width/height are known, 1:1 otherwise (older images)
      final w = att.width ?? 1;
      final h = att.height ?? 1;
      buf.write(
        '<img class="att-img" data-att-path="$encPath" '
        'style="aspect-ratio:$w/$h;" '
        'data-id="${m.id}" data-act="openImages" />',
      );
    }
    buf.write('</div>');
    return buf.toString();
  }

  Future<void> _pushMessages() async {
    // Generation counter: if another push happens during this one, the old catch-up loop is
    // invalidated by epoch
    _pushEpoch++;
    final epoch = _pushEpoch;
    debugPrint('[图片诊断] _pushMessages 开始执行 epoch=$epoch');
    final chatState = ref.read(activeChatProvider);
    final character = chatState.character;
    final persona = await ref.read(activePersonaProvider.future)
        .timeout(const Duration(seconds: 3))
        .catchError((e) {
      debugPrint('[卡点] activePersona 超时/出错: $e');
      return null;
    });
    final scripts = ref.read(combinedRegexScriptsProvider(character?.id));
    final messages = chatState.messages;

    int lastAiIndex = -1;
    for (var i = 0; i < messages.length; i++) {
      if (messages[i].role != MessageRole.user) lastAiIndex = i;
    }

    // First-screen batch 30 -> 50: one base64 payload carries 20 more messages, one less catch-up round trip
    const int batchSize = 50;
    final total = messages.length;
    // Only the most recent batchSize messages are rendered initially
    final startIndex = total > batchSize ? total - batchSize : 0;

    final initialList = <Map<String, dynamic>>[];
    for (var i = startIndex; i < total; i++) {
      initialList.add(_safeSerializeMessage(messages[i], i, lastAiIndex, character, scripts));
    }
    // Send the most recent messages first
    debugPrint('[图片诊断] _pushMessages 发送 setMessages, 条数=${initialList.length}');
    // Avatar + name: one copy of each globally, sent once with the first screen (kept out of
    // every message to avoid bloat and stutter)
    // persona was already read at the top of the function (with a 3s timeout fallback), so the
    // second duplicate read here is removed -- awaiting the same provider twice could waste up
    // to 6s with the result necessarily identical
    String? charUri;
    String? userUri;
    try {
      final uris = await Future.wait([
        _avatarToDataUri(character?.assets?.avatarPath, false)
            .timeout(const Duration(seconds: 3)),
        _avatarToDataUri(persona?.avatarPath, true)
            .timeout(const Duration(seconds: 3)),
      ]);
      charUri = uris[0];
      userUri = uris[1];
    } catch (e) {
      debugPrint('[卡点] 头像转换 超时/出错: $e');
    }
    // A newer push may have started while serializing / loading avatars: this stale round steps
    // aside to prevent a double initial clear
    if (epoch != _pushEpoch) {
      debugPrint('[PUSH] epoch=$epoch 已过时(当前=$_pushEpoch),放弃本轮推送');
      return;
    }
    await _sendEncodedMessages(initialList, initial: true, avatars: {
      'char': charUri,
      'user': userUri,
      'charName': character?.name ?? 'Assistant',
      'userName': persona?.name ?? 'User',
    });

    // Silently append older history in the background
    if (startIndex > 0) {
      // Startup delay 100 -> 50ms, batch size 20 -> 30: catch-up is about twice as fast
      Future.delayed(const Duration(milliseconds: 50), () async {
        const int historyBatchSize = 30;
        // The cursor approach covers every floor in [0, startIndex): the original
        // for (start = startIndex - 20; start >= 0; start -= 20) missed the earliest
        // (total - 30) % 20 floors when (total - 30) % 20 != 0 (e.g. 100 messages ->
        // startIndex = 70), leaving floors 1-10 permanently missing ("messages disappear
        // when you scroll to the top").
        var cursor = startIndex;
        while (cursor > 0) {
          // Check the generation before each batch: if a new render happened meanwhile this
          // loop invalidates itself immediately (the new push catches up history on its own)
          if (epoch != _pushEpoch) {
            debugPrint('[PUSH] epoch=$epoch 补发作废(当前=$_pushEpoch),已补到index=$cursor');
            return;
          }
          var batchStart = cursor - historyBatchSize;
          if (batchStart < 0) batchStart = 0;
          final batch = <Map<String, dynamic>>[];
          for (var i = batchStart; i < cursor; i++) {
            batch.add(_safeSerializeMessage(messages[i], i, lastAiIndex, character, scripts));
          }
          if (batch.isNotEmpty) {
            // JS-side prepend inserts one item at a time via insertBefore(root.firstChild),
            // which reverses the order, so sending batches in ascending order would read
            // backwards within a batch -> the sender compensates with batch.reversed.
            // This is an implicit coupling to "compensate for JS's reverse insertion"; in P2
            // the JS side should insert against a fixed anchor and Dart should keep natural
            // ascending order, decoupling this.
            await _sendEncodedMessages(batch.reversed.toList(), prepend: true);
            // Yield between batches 16 -> 8ms: still prevents consecutive batches from blocking, at half the cadence
            await Future.delayed(const Duration(milliseconds: 8));
          }
          cursor = batchStart;
        }
      });
    }

    // After setMessages, images are pushed one by one through a separate channel (the placeholder img is already in the html)
    _pushImages(messages);
  }

  /// Pushes every message's image attachments to the WebView one base64 image at a time,
  /// matching the placeholder img by data-att-path.
  /// Each image is sent separately so the setMessages payload no longer bloats with images,
  /// and large images cannot blow up the transfer.
  Future<void> _pushImages(List<ChatMessage> messages) async {
    for (final m in messages) {
      if (m.attachments.isEmpty) continue;
      for (final att in m.attachments) {
        try {
          String? b64 = _attachmentB64Cache[att.path];
          if (b64 == null) {
            final file = File(att.path);
            if (!file.existsSync()) continue;
            final encoded = await compute(encodeFileToBase64, att.path);
            _attachmentB64Cache[att.path] = encoded;
            b64 = encoded;
          }
          _bridge.send(BridgeType.setImage, {
            'path': Uri.encodeComponent(att.path),
            'mime': att.mimeType ?? 'image/jpeg',
            'b64': b64,
          });
          // Yield to the event loop so a run of images does not block at once
          await Future.delayed(const Duration(milliseconds: 8));
        } catch (_) {
          // Skip on a single image failure
        }
      }
    }
  }

  /// Adds a highlight span to quoted/bracketed dialogue (the markers are colored along with the content)
  /// Quote-style markers -> quote-q (primary A, warm orange), bracket-style -> quote-p (primary B, cyan blue)
  String _highlightQuotes(String html) {
    // Quote / square bracket / book title mark styles: each marker pairs with itself, markers and content colored together
    final quotePattern = RegExp(
        r'“[^”\r\n]*”|「[^」\r\n]*」|『[^』\r\n]*』|【[^】\r\n]*】|《[^》\r\n]*》',
        dotAll: true);
    html = html.replaceAllMapped(quotePattern, (m) {
      return '<span class="quote-q">${m.group(0)}</span>';
    });
    // Parenthesis styles: Chinese and English parentheses (markers and content colored together)
    final parenPattern = RegExp(r'[（(][^（）()]*[）)]', dotAll: true);
    html = html.replaceAllMapped(parenPattern, (m) {
      return '<span class="quote-p">${m.group(0)}</span>';
    });
    return html;
  }

  /// Converts a Color to a CSS hex string, for inlining into webview style variables
  String _colorToCss(Color c) =>
      '#${c.value.toRadixString(16).substring(2).padLeft(6, '0')}';
  // HTML skeleton

  String _chatStageErrorPage(String reason) {
    // Explicit failure page: a missing/unreadable asset shows the user exactly what broke
    // instead of a white screen.
    return '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>聊天壳加载失败</title></head>'
        '<body style="margin:24px;background:#14161C;color:#F5F7FA;'
        'font-family:-apple-system,BlinkMacSystemFont,sans-serif;">'
        '<div style="max-width:560px;margin:20vh auto 0;padding:24px;'
        'background:#231B1B;border:1px solid rgba(255,107,107,.4);'
        'border-radius:14px;">'
        '<div style="font-size:18px;font-weight:600;color:#FF9B9B;margin-bottom:8px;">聊天壳加载失败</div>'
        '<div style="font-size:14px;line-height:1.6;color:#E0E0E0;">'
        'assets/chat/ 下的聊天壳资源未就绪或读取失败。'
        '</div>'
        '<div style="font-size:13px;color:#B8BEC8;margin-top:10px;word-break:break-word;">'
        '$reason'
        '</div>'
        '<div style="font-size:12px;color:#8A8A8A;margin-top:14px;">'
        '请确认安装包完整;如问题持续,请联系开发。'
        '</div>'
        '</div></body></html>';
  }

  // Cached key for _htmlShell: replaceAll has to scan 313KB x 4, and InAppWebView only uses
  // initialData on creation -- rebuilding it in build on keyboard show/hide setState was pure
  // waste. The key holds the quote colors + top bar inset (the only two dynamic values), so it
  // recomputes only when they change; correctness matches the old implementation.
  String? _cachedHtmlShell;
  String? _cachedHtmlShellKey;

  String _htmlShell() {
    final html = _chatStageHtml;
    final bridge = _chatBridgeJs;
    if (html == null || bridge == null) {
      return _chatStageErrorPage('缺少聊天壳资源(_chatStageHtml / _chatBridgeJs 为空)');
    }
    final key = '${_colorToCss(ref.watch(quoteColorStateProvider).primaryA)}|'
        '${_colorToCss(ref.watch(quoteColorStateProvider).primaryB)}|'
        '${MediaQuery.viewPaddingOf(context).top}';
    if (_cachedHtmlShellKey == key && _cachedHtmlShell != null) {
      return _cachedHtmlShell!;
    }
    final shell = html
        .replaceAll('__KIRA_QUOTE_Q_COLOR__', _colorToCss(ref.watch(quoteColorStateProvider).primaryA))
        .replaceAll('__KIRA_QUOTE_P_COLOR__', _colorToCss(ref.watch(quoteColorStateProvider).primaryB))
        // The initial content start position is baked into the HTML: once the WebView goes
        // edge-to-edge the first frame must already clear the top bar, and waiting for a bridge
        // message would flash briefly
        .replaceAll('__KIRA_TOP_INSET__',
            (56 + MediaQuery.viewPaddingOf(context).top + 12).toStringAsFixed(1))
        .replaceAll('__KIRA_CHAT_BRIDGE__', bridge)
        // Master switch for the debug scan (baked in from kDebugMode, off in production by
        // default; see chat_stage.html head)
        .replaceAll('__KIRA_DEBUG__', kDebugMode ? 'true' : 'false');
    _cachedHtmlShell = shell;
    _cachedHtmlShellKey = key;
    return shell;
  }
}

// Full-screen edit page: an opaque fullscreen = the WebView is fully covered = no compositing
// overhead = smooth 120fps

class _EditMessagePage extends StatefulWidget {
  final String initialText;
  const _EditMessagePage({required this.initialText});

  @override
  State<_EditMessagePage> createState() => _EditMessagePageState();
}

class _EditMessagePageState extends State<_EditMessagePage> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fixed layout: the keyboard inset changing frame by frame no longer re-lays-out the
      // expands field, so the long-press select/copy toolbar is not interrupted by the rising
      // keyboard (root cause of the keyboard thrash)
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('编辑消息'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
      // Jitter fix: plain Padding follows the system viewInsets directly. AnimatedPadding's
      // 200ms animation stacked on top of the system keyboard animation re-laid-out the expands
      // field every frame while dragging a selection -> the selection handles kept re-locating
      // -> repeated haptics + visual jitter.
      body: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: TextField(
          controller: _controller,
          maxLines: null,
          expands: true,
          autofocus: true,
          textAlignVertical: TextAlignVertical.top,
          decoration: const InputDecoration(border: InputBorder.none),
        ),
      ),
    );
  }
}
/// Circular action button: icon strictly centered + pressed-state feedback + haptics.
/// Stands in for IconButton.filled (whose internal minimum interaction size constraint nudges
/// the icon off-center).
class _CircleActionButton extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color foreground;
  final String tooltip;
  final VoidCallback? onTap = null;

  const _CircleActionButton({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // Ripple + highlight on press, giving clear click feedback
          splashColor: Colors.white.withValues(alpha: 0.22),
          highlightColor: Colors.white.withValues(alpha: 0.12),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: Icon(icon, size: 22, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}

/// A breathing sparkle that brightens and dims, used as the "generating image" indicator.
class _BreathingStar extends StatefulWidget {
  @override
  State<_BreathingStar> createState() => _BreathingStarState();
}

class _BreathingStarState extends State<_BreathingStar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _c, curve: DesignTokens.curveEmphasized),
      ),
      child: const Text('✨', style: TextStyle(fontSize: 16)),
    );
  }
}

class _FullImageViewer extends StatelessWidget {
  final String path;
  final VoidCallback? onRegenerate; // when null the regenerate button is hidden
  const _FullImageViewer({required this.path, this.onRegenerate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: SizedBox.expand(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5.0,
                child: Center(
                  child: Image.file(
                    File(path),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image, color: Colors.white54, size: 64),
                  ),
                ),
              ),
            ),
          ),
          if (onRegenerate != null)
            Positioned(
              right: 20,
              bottom: 40,
              child: FloatingActionButton.extended(
                onPressed: onRegenerate,
                backgroundColor: Colors.black54,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text('重新生成',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}

/// HTML card detection (document-level evidence):
/// a) the first non-whitespace character starts a tag (<letter or <!), or
/// b) the content opens with a <!DOCTYPE / <html document marker (exactly what the docStart
///    branch leaves after trimming).
/// The old substring-level check (true if <style|<script|<body was merely mentioned) shoved any
/// plain text discussing HTML tags -- inevitable in an AI reply explaining scripting -- entirely
/// into an iframe: transparent bg + black text + blank collapsed content + markdown not rendered
/// -> layout completely broken. Non-fenced "leading text + card" degrades to readable text, an
/// acceptable cost; the explicit ```html fence path is unaffected.
bool _looksLikeHtmlDoc(String s) {
  final t = s.trimLeft();
  return t.isNotEmpty && RegExp(r'^<[a-zA-Z!]').hasMatch(t);
}

/// Normalizes curly (smart) quotes at code positions to straight quotes. Only for HTML cards
/// that go into the iframe: card authors/AI commonly use Chinese curly quotes, which break JS
/// string delimiters (name:'x') and HTML/SVG attribute delimiters (viewBox="0"), causing
/// SyntaxError / truncated attributes -> the card crashes.
/// Modeled on RisuAI's pre-render normalization (stage 1 only). Body text goes through the
/// markdown bubble and never hits this, so curly quotes are preserved there and the
/// _highlightQuotes coloring is unaffected.
/// Book title marks and corner brackets are kept (typography characters, not code delimiters).
///
/// Replacements are applied only outside <script>/<style> blocks, leaving block contents intact
/// (P3-D): the old implementation replaced everywhere, including curly quotes inside JS string
/// literals (e.g. a desc:"..." value whose content held curly quotes became desc:""..." ->
/// SyntaxError, killing the whole script). Outside blocks (HTML attributes / body / bare text
/// in JS) normalization behaves as before.
/// Edge cases: an unclosed <script> means the non-greedy match does not hit -> that segment is
/// normalized as before (same as the old behavior);
/// a literal "</script>" inside a JS string truncates the block early, matching browser parsing;
/// cards that need it already escape it as <\/script>, so they are unaffected.
/// Strips the whitespace newlines between block-level elements (>\n< -> ><).
/// In markdown library output every raw < > is a tag delimiter (text content is already escaped),
/// and whitespace newlines between blocks render as zero-height lines under normal white-space
/// (invisible); once .msg gains pre-wrap they render as empty lines -> paragraph spacing blows up.
/// After stripping, pre-wrap only affects real line breaks inside text content (including <pre>
/// code blocks: their content is already escaped and the char before the trailing \n is text,
/// not >, so they are unaffected).
String _stripInterBlockWs(String html) =>
    html.replaceAll(RegExp(r'>[ \t]*\n+[ \t]*<'), '><');

String normalizeCodeQuotes(String html) {
  // Block-aware normalization (P3-D1): normalize outside blocks, leave block contents intact
  // (fixes curly quotes inside a game's HTML triggering SyntaxError after regex replacement).
  // Curly quotes are illegal as JS string delimiters but legal as string content
  // (e.g. a desc:"..." value whose content held curly quotes); a global replace would also turn
  // the ones inside content into straight quotes -> string terminates early -> the script dies.
  String norm(String s) => s
      .replaceAll(RegExp('[\u2018\u2019\u201a\u201b]'), "'")
      .replaceAll(RegExp('[\u201c\u201d\u201e\u201f\uff02]'), '"')
      .replaceAll(RegExp('\u2026+'), '...');

  // Extract all <script>/<style> blocks (non-greedy; an unclosed block does not match -> that
  // segment is normalized as before)
  final blocks = RegExp(
    r'<script[^>]*>[\s\S]*?</script>|<style[^>]*>[\s\S]*?</style>',
    caseSensitive: false,
  ).allMatches(html);

  final buf = StringBuffer();
  var last = 0;

  for (final m in blocks) {
    // normalize outside the block
    buf.write(norm(html.substring(last, m.start)));
    // leave the block intact
    buf.write(html.substring(m.start, m.end));
    last = m.end;
  }

  // normalize the final segment outside the blocks
  buf.write(norm(html.substring(last)));

  return buf.toString();
}

/// Slide-to-hide wrapper: the Scaffold layout slot does not move (under extendBodyBehindAppBar
/// the body runs edge-to-edge, so the WebView geometry is unchanged) -- only the visual slides
/// off screen; FractionalTranslation's hit testing follows the offset, so the buttons cannot be
/// tapped accidentally once slid away.
class _SlidingAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool visible;
  final PreferredSizeWidget child;

  const _SlidingAppBar({required this.visible, required this.child});

  @override
  Size get preferredSize => child.preferredSize;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, -1),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: child,
    );
  }
}
/// STT mic button: long-press to start recording (icon turns red), release to recognize and
/// fill the result into the input box.
/// A short tap does not start recording (long-press semantics); if the gesture is taken over
/// midway, onCancel discards it.
class _SttMicButton extends StatelessWidget {
  const _SttMicButton({
    required this.color,
    required this.recording,
    required this.onStart,
    required this.onFinish,
    required this.onCancel,
  });

  final Color color;
  final bool recording;
  final VoidCallback onStart;
  final VoidCallback onFinish;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (_) => onStart(),
      onLongPressEnd: (_) => onFinish(),
      onLongPressCancel: onCancel,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Icon(
          recording ? Icons.mic : Icons.mic_none,
          color: recording ? const Color(0xFFE5484D) : color,
          size: 22,
        ),
      ),
    );
  }
}
/// Token count badge next to the input box.
/// Consumes tokenizerSettingsProvider.showTokenCount (previously unwired);
/// listens for input changes and rebuilds only itself instead of rebuilding the whole input
/// bar on every keystroke.
class _TokenCountBadge extends ConsumerStatefulWidget {
  const _TokenCountBadge({required this.controller, required this.color});

  final TextEditingController controller;
  final Color color;

  @override
  ConsumerState<_TokenCountBadge> createState() => _TokenCountBadgeState();
}

class _TokenCountBadgeState extends ConsumerState<_TokenCountBadge> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final showTokenCount =
        ref.watch(tokenizerSettingsProvider).showTokenCount;
    if (!showTokenCount) return const SizedBox.shrink();
    final text = widget.controller.text;
    if (text.trim().isEmpty) return const SizedBox.shrink();
    final estimate = ref.watch(tokenCountEstimateProvider(text));
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Text(
        '~$estimate',
        style: TextStyle(
          fontSize: 11,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: widget.color.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}
