import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'dart:ui';
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
import 'package:kirakira/presentation/screens/chat/chat_bridge_js.dart';
import 'package:kirakira/presentation/providers/settings_providers.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:go_router/go_router.dart';
import 'package:kirakira/presentation/providers/persona_providers.dart';
import 'package:kirakira/domain/services/chat_export_service.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';
import 'package:uuid/uuid.dart';
import 'package:kirakira/presentation/providers/chat_export_provider.dart' show chatExportServiceProvider;
import 'package:kirakira/presentation/providers/prompt_manager_providers.dart';
import 'package:kirakira/presentation/widgets/chat/context_usage_indicator.dart';
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
import 'package:kirakira/domain/services/slash_command/slash_runner.dart';
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
import 'package:share_plus/share_plus.dart';
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
import 'package:kirakira/domain/services/llm_service.dart';
import 'package:kirakira/presentation/providers/mvu_settings_providers.dart';
import 'package:kirakira/domain/services/debug_log_service.dart';
import 'package:kirakira/presentation/widgets/snackbar_utils.dart';
import 'package:kirakira/core/utils/file_utils.dart';

/// compute 用的顶层函数：isolate 中只读图片头部拿宽高，不解码整图（内存安全）。
/// 返回 {'w': 宽, 'h': 高}，失败返回 null。
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
// ─────────────────────────────────────────────────────────────────────────────
//  KiraKira · 新聊天页
//  by 北辰星（NorthStar）
//
//  架构：Flutter 是外壳，消息区是一整个全屏 WebView。
//  通信全部走 ChatBridge，禁止私开 evaluateJavascript 旁路。
//  弹窗覆盖 WebView 前必须 pause()，关闭后 resume()——
//  HC 模式下叠加任何 Flutter 图层都会触发昂贵合成，静止也掉帧。
// ─────────────────────────────────────────────────────────────────────────────

class WebViewChatStage extends ConsumerStatefulWidget {
  final String chatId;
  const WebViewChatStage({super.key, required this.chatId});

  @override
  ConsumerState<WebViewChatStage> createState() => _WebViewChatStageState();
}

class _WebViewChatStageState extends ConsumerState<WebViewChatStage> with TickerProviderStateMixin, WidgetsBindingObserver {
  ProviderSubscription<PromptManagerConfig>? _pmSub;
  ProviderSubscription<String?>? _charSub; // [P5-7B] character 变化自愈监听
  InAppWebViewController? _controller;
  bool _pmIdentifiersLogged = false;
  /// [P5-9/P1] ST 预设 settings 未知键会话级透传缓存(按预设名)。
  /// 平台模型无对应字段的 settings 键不设白名单拦截,写时整袋暂存、读时铺底回出;
  /// should_stream 等已建模键以真值为准覆盖,保证狐神 updatePresetWith 改写后读回一致。
  final Map<String, Map<String, dynamic>> _stSettingsPassthrough = {};
  // [P5-12] 预设读缓存(P5-11 方案1):getPreset TTL 缓存 + 在途请求合并。
  // 狐神面板 800ms 轮询会高频 getPreset('in_use')(4MB JSON),Dart 侧先做
  // TTL+合并;真正的带宽省法在 JS 侧 __KIRA_PRESET_CACHE(任务2.2/2.3)。
  final Map<String, Map<String, dynamic>> _presetReadCache = {};
  final Map<String, DateTime> _presetCacheAt = {};
  final Map<String, Completer<dynamic>> _presetReadInflight = {};
  static const Duration _presetCacheTTL = Duration(milliseconds: 500);
  int _wvCrashCount = 0; // [WV-6/P1-A5] renderer 崩溃自愈次数上限,防"崩→reload→再崩"死循环
  // [P5-12] WebView 合成源统一从这里取(initialData 与崩溃自愈 loadData 必须同源)
  static const String _kWebViewBaseUrl = 'https://localhost/';
  bool _webViewMounted = false; // 延迟挂载:入场后才创建WebView,避免动画期被重活饿死
  final TextEditingController _inputController = TextEditingController();

  /// [翻译] 进行中的消息id集合，防重复请求/占位闪烁
  final Set<String> _translatingIds = {};
  // [发送] 有无待发文字:驱动发送按钮 enabled/disabled 样式(有字亮色/无字灰)
  final ValueNotifier<bool> _hasInput = ValueNotifier(false);
  final ImagePicker _imagePicker = ImagePicker();
  final List<ChatAttachment> _pendingAttachments = [];
  // 气泡头像 data URI 缓存：角色/用户各一份，只算一次
  String? _charAvatarDataUri;
  String? _userAvatarDataUri;
  String? _cachedCharAvatarSrcPath;
  String? _cachedUserAvatarSrcPath;

  /// 把头像文件读成 data URI（相对路径先转绝对，踩过的坑）。源路径没变则用缓存。
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
  /// attachment path → base64 字符串缓存，避免 _pushMessages 每次重复读磁盘
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

  // 第三方库缓存（jQuery/lodash/toastr/yaml），全类共享，只读一次
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
  // 聊天壳 asset:初始 HTML(带占位符)+ 桥 JS;读一次,失败走显性错误页
  static String? _chatStageHtml;
  static String? _chatBridgeJs;
  static bool _chatStageLoaded = false;

  // [P5-6阶段0.1] 世界书读缓存: (方法+参数+角色) → (到期时间, 结果), TTL 2s。
  // 背景: 通路C复活后道渊等卡 5s 轮询 getWorldbook,不缓存则是 N+1 全量 DB+序列化。
  static const Duration _wiCacheTtl = Duration(seconds: 2);
  final Map<String, (DateTime, dynamic)> _wiCache = {};
  static const Object _wiCacheMiss = Object();

  String _wiCacheKey(String method, [Object? arg]) =>
      '$method|${arg ?? ''}|${ref.read(activeChatProvider).character?.id ?? 'none'}';

  /// 读缓存命中返回缓存值;未命中/过期返回 _wiCacheMiss 哨兵(结果本身可为空列表)。
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

  /// 世界书写操作/角色切换后调用,保证写后读一致(写路径不走缓存)。
  void _wiCacheInvalidate([String? reason]) {
    if (_wiCache.isEmpty) return;
    debugPrint('[WI缓存] 失效${reason == null ? '' : '($reason)'}: 清空 ${_wiCache.length} 条');
    _wiCache.clear();
  }

  /// 读取聊天壳资产(html + 桥 js)。成功后才置 _chatStageLoaded=true,
  /// 失败保持 false 以便下次重试,_htmlShell() 会走显性错误页而不是白屏。
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

  /// 加载并缓存第三方库（base64 编码，供内联注入）。只在首次调用时真正读取。
  static Future<void> _loadCompatLibs() async {
    if (_libsLoaded) return;
    try {
      final jquery = await rootBundle.loadString('assets/libs/jquery.min.js');
      final lodash = await rootBundle.loadString('assets/libs/lodash.min.js');
      final toastrJs = await rootBundle.loadString('assets/libs/toastr.min.js');
      // [P3-C/T2] yaml 单独 try:缺失或损坏只失去 YAML,不拖垮 jquery/lodash/toastr 的既有加载
      final toastrCss = await rootBundle.loadString('assets/libs/toastr.min.css');
      String? yamlJs;
      try {
        yamlJs = await rootBundle.loadString('assets/libs/yaml.min.js');
      } catch (e) {
        KiraLogger().info('兼容库', 'yaml 库读取失败(仅 YAML 全局缺失): $e');
      }
      // [P3-M] vue 单独 try:必须用 global 构建才能挂 window.Vue,道渊 CDN bundle 依赖它;
      // 缺失/损坏只失去 Vue,不拖垮其他库
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
      // 加载失败不阻断聊天，仅记录
      KiraLogger().info('兼容库', '第三方库加载失败: $e');
    }
  }
  /// 加载并缓存 MVU bundle(base64),供引擎房内联。
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

  /// 把已缓存的第三方库（base64）注入到外层 WebView 的 window.__KIRA_LIBS。
  /// 页面加载后调用一次，供 injectBridge 按需内联进 iframe。
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
  /// 把当前角色名/用户名注入到外层 WebView 的 window.__KIRA_MACRO_VALUES。
  /// 供 injectBridge 内联的 substitudeMacros 同步读取。
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
  /// 把共享 TavernHelper 门面注入到外层 window.__ENGINE_FACADE_JS,
  /// 供 createEngineRoom 建引擎房 iframe 时内联。
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

  /// [P5-6阶段2.1] 把主环境快照注入外层 window.__KIRA_MAIN_ENV,
  /// 供主文档 SillyTavern.getContext() 骨架读取(mvu_settings/EjsTemplate)。
  /// 注入失败由 HTML 侧降级为空对象并打 [主环境] 日志,不阻断。
  Future<void> _injectMainEnv(InAppWebViewController c) async {
    final mvu = ref.read(mvuSettingsProvider);
    // [P5-9/P1] chatCompletionSettings 真值(狐神 agent 守卫等待它出现)
    final llm = ref.read(llmConfigProvider);
    final env = <String, dynamic>{
      'mvu': <String, dynamic>{
        '更新方式': mvu.updateMode,
        // [P5-8/P1] 通知四键同步进主环境(与 facade 烘焙同源)
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
      // EJS 引擎真实加载状态门控(_ejsLoaded 静态标志),不是造假
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
    // [P5-7B] 校验: 确保 provider 中的 chat 与本 widget 匹配,防止切卡竞态注入错误脚本
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
    final authKey = 'tavern_scripts_auth_${character?.id ?? 'none'}_${preset?.id ?? 'none'}';
    var allowed = prefs.getBool(authKey);
    if (enabledScripts.isNotEmpty && allowed == null && mounted) {
      final names = enabledScripts.map((s) => '• ${s['name'] ?? '未命名脚本'}').join('\n');
      // [弹窗] HTML确认框:注入阶段 WebView 已就绪,无需 Flutter 弹窗
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
// 修复: 部分脚本按同步语义读 _TH.getPreset（平台门面返回 Promise），
// 导致无限自激循环。注入前 patch 这两个读点，改为读 __KIRA_PRESET_CACHE 同步镜像。
// 对所有脚本尝试 patch，regex 未命中的原样返回，不影响其他脚本。
    final patchedScripts = enabledScripts.map<Map<String, dynamic>>((s) {
      final name = s['name']?.toString() ?? '';  // 保留供日志用
      // patch对所有脚本尝试，regex命中与否自行决定
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
      // [P5-9/P0-3] 脚本级变量快照:为每个启用脚本预取持久化变量,注入后脚本房在
      //   每个脚本启动前 hydrate 进门面 __varCache.script,getVariables({type:'script'}) 即可同步读到。
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

  /// 把 MVU bundle(base64)注入外层 window.__KIRA_MVU_BUNDLE,
  /// 供 createEngineRoom 建引擎房时内联为 ES module。
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

  /// 用自定义提示词替换 bundle 里的 const wX='...默认task...'。
  /// 正则用 (?:[^'\\]|\\.)* 跳过内部转义单引号,避免非贪婪提前截断。
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
  bool _topBarVisible = true; // [顶栏] 滚动隐藏/显示,方向判定在 JS 侧,这里只收结果
  int _pushEpoch = 0; // [RC3] 推送代际计数器:新一次 _pushMessages 使在途的历史补发循环作废
  // [弹窗] HTML弹窗等待表:callbackId → Completer,结果经 dialogResult 桥回传
  final Map<String, Completer<dynamic>> _dialogCompleters = {};

   @override
  void initState() {
    super.initState();
                    // 登记 EJS 渲染函数,供 LLMService 发送前渲染提示词
                    ref.read(ejsRenderRegistryProvider).register(
                      (text) => _handleRenderEJS({'text': text}),
                    );
    // [P3-K2-4] 监听 prompt sections 变化, 出站推给悬浮球
    // [P5-6阶段1.3] fireImmediately: provider 同步定型且早被别处读走,监听附加后
    // 无"变化"则回调永不触发 → 隐藏列表首帧空。立即推一次兜底(outbox 排队,幂等无害)。
    _pmSub = ref.listenManual<PromptManagerConfig>(
      promptManagerProvider,
      (prev, next) {
        // ChatBridge.send 内部自动排队握手前消息, 无需检查 ready
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
      // [优化] 5 个资产加载互不依赖(各自只写自己的静态缓存),并行读取。
      // 串行时低端机上这是遮罩期一段可观的白等。
      await Future.wait([
        _loadChatStageAssets(),
        _loadCompatLibs(),
        _loadMvuBundle(),
        _loadEjsStub(),
        _loadEjsBundle(),
      ]);
      if (!mounted) return;
      // [P5-7B] 等 loadChat 真正完成,确保 character 数据就绪后再挂 WebView
      // [P0-3] 超时兜底:DB 挂起时不再永久阻塞 WebView 挂载(卡在加载界面)
      await ref.read(activeChatProvider.notifier).loadChat(widget.chatId)
          .timeout(const Duration(seconds: 10), onTimeout: () {
        debugPrint('[卡点] loadChat超时10s');
      });
      // 挂载 WebView(此前这里还有 350ms 人为延迟,已删——纯加载耗时)
      if (!mounted) return;
      setState(() => _webViewMounted = true);
      // [P0-3] 15s 安全网:loadData 失败/渲染进程异常等导致 onLoadStop 永不触发时,
      // 遮罩会永久盖屏。15s 未撤强制撤下,宁可闪一下也不要永久卡死。
      Future.delayed(const Duration(seconds: 15), () {
        if (mounted && _maskController.status != AnimationStatus.dismissed) {
          debugPrint('[安全网] 15s遮罩未撤，强制撤下');
          _maskController.reverse();
        }
      });
    });
    // [P5-7B] 自愈: character 变化时重新注入脚本,防止时序竞态注入旧卡脚本
    _charSub = ref.listenManual(
      activeChatProvider.select((s) => s.character?.id),
      (previous, next) {
        if (next != null &&
            next != previous &&
            _webViewMounted &&
            _controller != null) {
          debugPrint('[脚本监听] character变化: $previous → $next, 重新注入');
          _wiCacheInvalidate('character变化'); // [P5-6阶段0.1] 切角色清空世界书缓存,防串卡旧值
          final c = _controller;
          if (c != null) _injectPresetScripts(c);
        }
      },
    );
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
    // [鬼畜修复] 有其它路由盖在本页之上时(全屏编辑页/导航/Flutter弹窗)完全不处理键盘度量。
    // 本页此时仍在树下存活:键盘每帧度量变化 → setState → 重建整个 build()(含已 pause 的
    // InAppWebView) → HC 平台视图重排 → 系统 IME 重挂 → 再次 didChangeMetrics → 无限循环。
    // 表现即"长按选择文字时手机狂震、键盘反复弹、屏幕鬼畜、松手仍不停"。
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final view = View.of(context);
    final bottom = view.viewInsets.bottom / view.devicePixelRatio;
    final visible = bottom > 0;
    if (visible && bottom > _keyboardHeight) _keyboardHeight = bottom; // 缓存键盘高度
    if (visible != _keyboardVisible) {
      setState(() => _keyboardVisible = visible); // 仅在显↔隐跳变时重建一次
      // [键盘] 推送键盘状态给 WebView:body 底部 padding 补偿,否则贴底时
      // 最新消息落在键盘后方且已在滚动上限,永远滚不出来
      _bridge.send(BridgeType.keyboardInsets, {
        'visible': visible,
        'height': visible ? _keyboardHeight : 0,
      });
    }
    // [聊天页大改] 同步布局 CSS 变量给 WebView(键盘高度/状态栏/导航栏/viewport 高度)
    // 频率受 visible != _keyboardVisible 跳变门控,不会因每帧 metrics 抖动而刷爆桥
    _injectLayoutVars();
  }

  /// [顶栏] 显隐切换(仅状态跳变时 setState,滚动事件本身在 JS 侧已收敛)
  void _setTopBarVisible(bool visible) {
    if (!mounted || _topBarVisible == visible) return;
    setState(() => _topBarVisible = visible);
    _sendTopBarInsets();
  }

  /// [顶栏] 把顶栏占位推给 JS:WebView 全出血,消息起始位置 = body padding-top。
  /// 顶栏显示 → 让出 44+状态栏;收起 → 只留状态栏,那 44px 归消息区。
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

  // ── [聊天页大改] 布局变量统一注入 ───────────────────────────────────────────
  // 所有布局相关 CSS 变量(--keyboard-height / --status-bar-height / --nav-bar-height /
  // --app-viewport-height / --safe-area-inset-top / --safe-area-inset-bottom)
  // 集中在这一个函数里组装,经 ChatBridge.layoutVars 一次性下发。
  // 触发时机:onLoadStop 初始注入 + didChangeMetrics(键盘/方向变化)+ _sendTopBarInsets(顶栏切换)。
  // 不直接 evaluateJavascript:遵守 webview_chat_stage.dart:101 通信全部走 ChatBridge 的硬性规定。
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
    // visualViewport 在 WebView 里不一定可用,用实际可视高度(减去键盘)
    final viewportHeight = mq.size.height - keyboardHeight;
    // [新菜单] 主题色注入（深色/浅色都跟随）
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

  /// Color → #RRGGBB（WebView setProperty 不认 ARGB）
  static String _hex(Color c) {
    final r = (c.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (c.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (c.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }

  /// [P1-A5] 崩溃自愈超限后,用户点「重新加载」:重置计数并重挂 webview 恢复。
  void _reloadWebViewAfterCrash() {
    _wvCrashCount = 0;
    _reloadWebViewContent();
  }

  /// [P5-12] 崩溃自愈:重新 loadData 重建内容,而非 controller.reload()。
  /// reload 会把 loadData 页面的历史条目(其 URL 即 baseUrl)当真实导航重新请求,
  /// 公网域名会 net::ERR_NAME_NOT_RESOLVED(P5-11 诊断第五部分)。
  /// loadData 重建文档后 onLoadStop 会重跑注入链(兼容库/门面/脚本房/MVU),等价完整恢复。
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
    // [RC3] 不再 delayed 补发 _pushMessages:loadData 成功必触发 onLoadStop,
    // 那里已 await _pushMessages;这里再补一发会形成双跑,两个历史补发循环
    // 交错 insertBefore → 楼层重复/乱序(消息丢失bug根因之一)。
    // [弹窗] WebView 重建,页面上未决的 HTML 弹窗随之消失,按取消收场
    for (final c in _dialogCompleters.values) {
      if (!c.isCompleted) c.complete(false);
    }
    _dialogCompleters.clear();
  }

  @override
  void dispose() {
    // 清空 EJS 渲染函数登记(离开聊天页,回到安全态)
    try {
      ref.read(ejsRenderRegistryProvider).clear();
    } catch (_) {}
    // [弹窗] 未决 HTML 弹窗全部按取消收场,防 Completer 永久挂起
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
    // 从相册等外部 Activity 返回时，WebView 的 PlatformView 触摸命中区域会失效，
    // resume 时强制刷新一次，恢复手势。
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

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // 消息变化 → 智能分流：结构变化走全量，内容增长走增量追加
    ref.listen(activeChatProvider, (prev, next) {
      final prevMsgs = prev?.messages ?? const [];
      final nextMsgs = next.messages;

      // 纯末尾追加（发消息 / 新增AI占位）：prev 是 next 前缀，只在末尾多出几条
      // → 只追加新增 DOM，不清空整页，消除闪白抖动
      final isPureAppend = prevMsgs.isNotEmpty &&
          nextMsgs.length > prevMsgs.length &&
          _isPrefix(prevMsgs, nextMsgs);

      // [闪屏修复] 纯尾部截断（retry 删后续 / 删除此条及之后）：next 是 prev 的前缀且更短
      // → 只摘掉多出来的 DOM。retry 走的就是这条路,原先落进"结构变化→全量重建"= 闪屏
      final isPureTruncate = prevMsgs.isNotEmpty &&
          nextMsgs.length < prevMsgs.length &&
          _isPrefix(nextMsgs, prevMsgs);

      // 结构变化（增删消息 / 换聊天）→ 全量重渲染
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
          // 中间消息的 swipe 结构/索引变化（reroll 插占位、swipe 切换）→ 刷新同步 webview。
          // 只看 swipes 数量与 index，不看 content：流式中间的 content 变化不在此刷，
          // 交给生成结束时那次全量刷新，避免 reroll 每个 token 全量重建导致卡顿。
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

      // 生成结束的瞬间：全量刷新一次，把流式的纯文本正确渲染成 Markdown/HTML 卡片
      final gen = next.isGenerating;
      // 点火：用户发消息 → isGenerating false→true，用户消息已入 state
      // → 通知引擎房 MVU initCheck（带 msgs 填充 __chatMessages / SillyTavern.chat）
      if (!_wasGenerating && gen) {
        _syncPrimaryLorebookToEngine();   // 趁生成期间提前推主世界书名进镜像
        final msgsJson = jsonEncode(_serializeMessagesForMvu());
        _controller?.evaluateJavascript(
            source: 'if(window.__emitToEngine)window.__emitToEngine("generation_started",[],$msgsJson);');
        // [聊天页大改] 生成开始:通知 WebView 输入栏切到停止按钮态
        _pushInputBarState();
      }
      if (_wasGenerating && !gen) {
        // [闪屏修复] 生成结束只定点刷新最后一条(把流式纯文本渲染成 Markdown/HTML),
        // 不再整页 initial 重建 —— 那是"每次回复完成都闪一下"的根因。
        // JS 侧节点缺失或内容是卡片时回 needFullPush,Dart 兜底全量重推。
        _updateLastMessage(nextMsgs);
        // 点火：AI 回复完成 → 通知引擎房 MVU 解析新回复、更新变量
        if (nextMsgs.isNotEmpty) {
          final lastIdx = nextMsgs.length - 1;
          final msgsJson = jsonEncode(_serializeMessagesForMvu());
          _controller?.evaluateJavascript(
              source: 'if(window.__emitToEngine)window.__emitToEngine("message_received",[$lastIdx],$msgsJson);');
        }
        // [P5-9/P1] 生成结束(完成或取消)必发 GENERATION_ENDED(官方值 generation_ended),
        // 狐神"生成结束后恢复"等 listener 依赖;取消路径 cancelGeneration 也走这里,不再空转。
        _emitPresetEvent('generation_ended');
        // [聊天页大改] 生成结束:通知 WebView 输入栏切回发送按钮态
        _pushInputBarState();
      }
      _wasGenerating = gen;
      // 自动生图完成：消息 attachments 变化 → 刷新让新图显示。
      // 自动生图是异步的，完成时 isGenerating 早已 false，上面的分支都不刷。
      if (prevMsgs.length == nextMsgs.length) {
        for (var i = 0; i < nextMsgs.length; i++) {
          if (nextMsgs[i].attachments.length != prevMsgs[i].attachments.length) {
            _pushMessages();
            break;
          }
        }
      }

      // 错误提示：空回复/生成失败，统一弹 SnackBar。
      // 之前 error 默默设进 state 但 UI 从不消费，让人以为卡住。
      // 503/网络错误显示简短提示，完整 error 留给日志（debugPrint 已有）。
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

    // [聊天页大改] STT 设置变化时刷新输入栏:WebView 长按 textarea 的语音条要跟随开关显隐
    ref.listen(sttSettingsProvider, (prev, next) {
      if (prev?.enabled != next.enabled && _webViewMounted) {
        _pushInputBarState();
      }
    });
    // [聊天页大改] STT 录音中状态变化时刷新输入栏(供 UI 状态展示,目前未加录音指示,留作后续)
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
      // [顶栏] 切会话重置为显示,避免新会话开局顶栏消失
      _setTopBarVisible(true);
    });

    // 自动生图占位符：msgId 变化 → 显示/移除"生成中"占位
    ref.listen(activeChatProvider.select((s) => s.generatingImageMsgId),
        (prev, next) {
      if (next != null) {
        _bridge.send(BridgeType.setGenerating,
            {'msgId': next, 'genId': 'auto_$next', 'w': 1, 'h': 1});
      } else if (prev != null) {
        _bridge.send(BridgeType.clearGenerating, {'genId': 'auto_$prev'});
      }
    });
    // 自动生图进度 → 更新占位符百分比
    ref.listen(activeChatProvider.select((s) => s.imageGenProgress),
        (prev, next) {
      final msgId = ref.read(activeChatProvider).generatingImageMsgId;
      if (msgId != null) {
        _bridge.send(BridgeType.setGenerateProgress,
            {'genId': 'auto_$msgId', 'progress': next});
      }
    });
    // 自动生图失败 → 一次性提醒
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

    final character = ref.watch(activeChatProvider.select((s) => s.character));
    // [顶栏模型名] watch 生效配置 llmConfigProvider.model(而非 llmConfigsProvider):
    // 切模型(updateModel)只写前者+直写DB,不刷新后者的内存列表 → watch 错源会不更新。
    // 切方案(setActive→applyActiveMultiConfig)同样落 llmConfigProvider,两条路径都实时。
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
        characterId: ref.watch(activeChatProvider).character?.id,
        child: Stack(
        children: [
                // WebView 下移到顶栏下方：顶栏后面只剩壁纸(Flutter层)，
                // blur 采样不到 WebView，毛玻璃安全、不卡。
                Positioned.fill(
                  child: Padding(
                  padding: EdgeInsets.only(
                    // [顶栏] 全出血:WebView 恒定铺满(top:0),消息起始位置由 body
                    // padding-top 决定(桥 topBarInsets 驱动)。顶栏收起时改 CSS 让出
                    // 那 32px,而不是 resize 平台视图 —— 守住 HC 合成性能红线,
                    // 也修掉"顶栏收回去了但那块仍是壁纸、等于没收"的问题。
                    top: 0,
                    // [聊天页大改] WebView 铺满到底部:输入栏已迁入 WebView
                    // (position:fixed; bottom:var(--keyboard-height)),不需要 Flutter
                    // 侧再留 64px 占位。消息列表底部留白改由 body padding-bottom
                    // 在 chat_stage.html 的 keyboardInsets handler 里动态计算
                    // (input-bar 高度 + safe-area + keyboard-height),消息不再被
                    // 输入栏遮住。
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
                    // [P5-9/P0-1] baseUrl 用合成 https 源替代 about:blank：
                    //   about:blank 是不透明源(opaque origin)，主文档与 srcdoc 脚本房的
                    //   localStorage 访问一律抛 SecurityError → 三预设(人间月下/狐神/玄枢)
                    //   的"设置持久化/点击保存"全部失效（见 P5-9 报告第二部分）。
                    //   改为稳定 https 源后，主文档与 iframe 获得同源真实 localStorage。
                    //   合成源不会被网络解析(loadData 仅用 baseUrl 做资源/来源解析，不发起导航)。
                    //   [P5-12] localhost 而非公网域名：渲染进程崩溃自愈 reload 会把该地址
                    //   当真实导航重新请求，公网域名会 net::ERR_NAME_NOT_RESOLVED（P5-11 第五部分）。
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
                  // [WV-6] Android renderer 被系统 OOM 杀死时此前无人处理 → 永久白屏无日志。
                  // [P1-A5] 会话级自愈上限 3 次,防"崩→reload→再崩"死循环;超限给用户可见提示,不许静默白屏。
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
                    // [P5-12] 自愈改 loadData 重建,避免 reload 对 baseUrl 的真实导航
                    _reloadWebViewContent();
                  },
                  // [P0-3] 主文档加载错误此前无人处理 → onLoadStop 永不触发 → 遮罩永久盖屏。
                  // 撤下遮罩给用户出路(可返回/重进);加载完成后遮罩已撤,再触发是无视觉变化的立即完成。
                  onReceivedError: (controller, request, error) {
                    debugPrint('[WebView] 加载错误: ${error.description}');
                    if (mounted) _maskController.reverse();
                  },
                  onWebViewCreated: (c) {
                    _controller = c;
                    _bridge.attach(c);
                    _bridge.on(BridgeType.action, _handleAction);
                    // [顶栏] 滚动方向事件:down=隐藏,up/top=显示。
                    // JS 侧已做 ±8px 迟滞+方向变化才上报,这里只做纯映射。
                    _bridge.on(BridgeType.scroll, (payload) {
                      final dir = payload['dir'] as String?;
                      _setTopBarVisible(dir != 'down');
                    });
                    // [弹窗] HTML 弹窗结果回传:按 callbackId 找到等待中的 Completer
                    _bridge.on(BridgeType.dialogResult, (payload) {
                      final callbackId = payload['callbackId'] as String?;
                      if (callbackId == null) return;
                      final completer = _dialogCompleters.remove(callbackId);
                      if (completer != null && !completer.isCompleted) {
                        completer.complete(payload['value'] ?? payload['result']);
                      }
                    });
                    // [P5-6阶段1.2] 卡片日志分级: error→toast+常驻缓冲, warn→常驻缓冲,
                    // info/debug→仅开发模式打印(由 DebugLogService 捕获开关门控)
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
                    // 酒馆助手 API：读取当前会话消息（请求-响应）
                    _bridge.onRequest('th_getMessages', _handleGetMessages);
                    _bridge.onRequest('th_triggerSlash', _handleTriggerSlash);
                    // [P6-3] EJS execute() 的后端:执行并回传 pipe
                    _bridge.onRequest('th_executeSlash', _handleExecuteSlash);
                    // [P6-5.1] UI 交互桥:toastr → SnackBar,callGenericPopup → Dialog
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
                    // 世界书 API
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
                    // [P5-6阶段2.4] 酒馆正则只读桥(道渊第3条报警数据链)
                    _bridge.onRequest('th_getRegexes', _handleThGetRegexes);
                    // [P3-K2] 提示词管理 API
                    _bridge.onRequest(BridgeType.pmGetSections, _handlePmGetSections);
                    _bridge.onRequest(BridgeType.pmToggleSection, _handlePmToggleSection);
                    // [P5-8/P1] extensionSettings 持久化(道渊/MVU 面板写回落盘)
                    _bridge.onRequest(BridgeType.saveExtensionSettings, _handleSaveExtensionSettings);
                    // [P5-9/P1] 预设管理 API(狐神读写预设)
                    _bridge.onRequest(BridgeType.getPresetNames, _handleGetPresetNames);
                    _bridge.onRequest(BridgeType.getPreset, _handleGetPreset);
                    _bridge.onRequest(BridgeType.setPreset, _handleSetPreset);
                    _bridge.onRequest(BridgeType.getLoadedPresetName, _handleGetLoadedPresetName);
                    // [P5-9/P1] 生成控制(狐神自动推进/停止)
                    _bridge.onRequest(BridgeType.generate, _handleGenerate);
                    _bridge.onRequest(BridgeType.stopGeneration, _handleStopGeneration);
                  },
                  onLoadStop: (c, url) async {
                    // [P0-2] 整体 try/finally:任一 await 抛异常不再中断回调 →
                    // 遮罩在 finally 强制撤下,任何失败路径都不会永久卡"加载中"。
                    try {
                    // [顶栏] 页面(重)载完成(含崩溃自愈 loadData 重建)重置为显示
                    _setTopBarVisible(true);
                    _sendTopBarInsets(); // 重建后重新同步内容起始位置
                    // [聊天页大改] 初始注入布局 CSS 变量(--keyboard-height 等)
                    _injectLayoutVars();
                    // [优化] 8 个注入互不依赖(各自只写不同的 window 全局,无返回值依赖),
                    // 并行注入。此前 9 连串行 evaluateJavascript 是 onLoadStop 最大的自找耗时。
                    await Future.wait([
                      _injectCompatLibs(c), // 注入第三方库到外层window
                      _injectMacroValues(c), // 注入宏替换用的角色名/用户名
                      _injectRegexRules(c), // [P6-5.2] 正则规则快照(引擎房烘焙用)
                      _injectMainEnv(c), // [P5-6阶段2.1] 注入主环境快照(主文档ST骨架读)
                      _injectEngineFacade(c), // 注入引擎房共享门面
                      _injectMvuBundle(c),
                      _injectEjsStub(c),
                      _injectEjsBundle(c), // 注入 EJS bundle 供引擎房内联
                    ]);
                    // [依赖] _injectPresetScripts 含用户交互(授权弹窗),且其内部
                    // resetPresetScriptsRoom 构建脚本房时同步读上面注入的
                    // __KIRA_REGEX_RULES → 必须在并行注入完成后串行跑
                    await _injectPresetScripts(c);
                    await c.evaluateJavascript(
                        source: 'if(window.createEngineRoom)window.createEngineRoom();');
    // 保险丝：2 秒后若 JS 的 ready 信号仍未到（老 WebView），强制放行
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
                          // [聊天页大改] 选完图后多次推送 inputBarState,
                          // 因 _addAttachmentFromXFile 的 base64 缓存是 fire-and-forget
                          // 异步,立即推送拿不到,延迟 500/1500ms 再推让缓存就绪
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
                    // [浮窗化] 设置面板操作回传
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
                    // [聊天页大改] WebView 输入栏桥接入站(JS→Flutter)
                    _bridge.on(BridgeType.inputSend, (payload) {
                      final text = (payload['text'] as String?) ?? '';
                      if (text.trim().isEmpty) return;
                      if (ref.read(activeChatProvider).isGenerating) return;
                      // 把 WebView textarea 的 text 同步到 _inputController,_sendMessage 读它
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
                    // [聊天页大改] STT 桥接入站(JS→Flutter,WebView 长按 textarea 触发)
                    _bridge.on(BridgeType.sttStart, (payload) {
                      _sttStart();
                    });
                    _bridge.on(BridgeType.sttStop, (payload) {
                      _sttFinish();
                    });
                    // (此前这里还有 350ms 人为延迟,已删——注入链已就绪,直接推首屏)
                    if (!mounted) return;
                    await _pushMessages();
                    // [聊天页大改] WebView 就绪后推送输入栏初始状态(generating/stt/attachments)
                    _pushInputBarState();
                    // [P3-E3] 存量变量快照推送: setMessages 建 iframe → patch 索要快照(__thRequestSnap)
                    // 前先把已落库的 MvuData 逐条广播, card 门控(getMvuData/getAllVariables)才有数据。
                    await _pushInitialVarSnapshots();
                    // 开场白就绪后主动填充 __chatMessages 并触发 chat_changed，
                    // 让 MVU initCheck 重跑一次（这次 SillyTavern.chat 非空）
                    final initMsgsJson = jsonEncode(_serializeMessagesForMvu());
                    _controller?.evaluateJavascript(
                        source: 'if(window.__emitToEngine)window.__emitToEngine("chat_changed",[],$initMsgsJson);');
                    // [P5-9/P1] 官方命名对齐:facade tavern_events 里 CHAT_CHANGED='chat_id_changed',
                    // 只发旧串会让监听 CHAT_CHANGED 的脚本(狐神)收不到 → 双发兼容新旧。
                    _controller?.evaluateJavascript(
                        source: 'if(window.__emitToEngine)window.__emitToEngine("chat_id_changed",[],$initMsgsJson);');
                    await Future.delayed(const Duration(milliseconds: 500));
                    } catch (e, st) {
                      debugPrint('[onLoadStop] 异常，强制撤遮罩: $e\n$st');
                    } finally {
                      // [P0-2] 遮罩唯一清除点移入 finally:成功/异常/提前 return 都会撤下
                      if (mounted) await _maskController.reverse();
                    }
                  },
                )
                      : const SizedBox.shrink(),
                ),
                ),
              // 底部浮层：功能面板 + 输入栏，bottom 锚定。
              // 面板展开往上盖住 WebView 内容，WebView 尺寸恒定、永不 resize —— 彻底消除展开/收起顿卡。
              // [聊天页大改] 输入栏已迁入 WebView(chat_stage.html .chat-input-container),
              // 通过 --keyboard-height CSS 变量自动跟随键盘(见 _injectLayoutVars)。
              // 功能面板也早就在 WebView 内(见 openFunctionPanel 桥),
              // Flutter 侧底部浮层不再需要任何 widget,这里用 SizedBox 占位避免布局变动。
              const Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox.shrink(),
              ),
            ],
        ),
      ),
          // 顶栏毛玻璃层:blur 磨砂壁纸 + 灰黑半透明底(让白字显眼)。
          // 后面只有壁纸,blur 安全不卡。文字由 AppBar 浮在其上。
          // [顶栏] 滚动隐藏:与 AppBar 的 AnimatedSlide 同参数联动,滑出后露出壁纸条。
          // WebView 几何不动(不 resize),守住 HC 合成性能红线。
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
                height: 56 + MediaQuery.viewPaddingOf(context).top, // [顶栏] 双行标题 44→56
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
        ], // Stack children 结束
      ), // body Stack 结束
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
                    Icon(
                      Icons.auto_awesome,
                      size: 44,
                      color: activeGlassPalette.accent,
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
  /// 角色名超过5个字用省略号截断
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
  /// 酒馆助手 triggerSlash：精简版 STscript 执行器。
  /// 支持管道 `|` 串联，覆盖开局类卡片高频命令：
  ///   /send <text> · /sys <text>  → 发一条消息并触发 AI 生成
  ///   /trigger                    → 触发 AI 生成（若前面已发消息则跳过，避免重复）
  ///   /cut <id>                   → 稳妥起见做 noop（不删用户消息，保护数据）
  /// 其余命令忽略但不报错，保证卡片脚本不中断。
  bool _slashCommandsRegistered = false;

  /// [P6-3] 平台命令注册:send/gen/trigger 等桥接到宿主能力。
  /// 回调不捕获 this 状态,一切经 args.env 注入;注册幂等(覆盖写)。
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
      // /sys 暂无独立系统消息通道,退化为普通发送
      final t = args.unnamedAsString();
      if (t.trim().isNotEmpty) await args.env?.sendMessage?.call(t);
      return '';
    }));
    SlashCommandRegistry.register(SlashCommand(name: 'sendas',
        callback: (args) async {
      // 暂无"以指定身份发送"底层能力,退化为普通发送
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

  /// [P6-5.1] toastr 桥:info/success/warning/error → SnackBar。
  /// payload: {level: string, message: string}
  /// [P6-BUG-1] 同文案 5 秒去重:脚本房/引擎房重复初始化或循环调用时不再连环弹。
  static final Map<String, DateTime> _toastLastShown = {};

  /// [降噪] MVU 框架生命周期提示兜底黑名单(老 bundle / title 缺失时按正文匹配)。
  /// 字符串取自 mvu_bundle.js 实际文案,注意"需要有开场白"含"有"字,漏字即永不匹配。
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
    // [降噪] MVU 框架提示(构建信息/需要开场白/世界书加载…)每次会话初始化必弹,
    // 属调试信息 → 只进调试日志。按 toastr title 前缀统一识别(根治),
    // 正文黑名单仅作老 bundle 兜底。
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

  /// [P6-5.1] callGenericPopup 桥:TEXT/CONFIRM/INPUT/DISPLAY → HTML 弹窗(WebView内渲染)。
  /// 返回值对齐 POPUP_RESULT:CONFIRM → 1(null=取消);INPUT → 字符串(null=取消);
  /// TEXT/DISPLAY → 1。[弹窗] 原 Flutter ThPopupDialog 迁入 WebView,免 pause/resume 合成开销。
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
      case 4: // DISPLAY(原 Flutter 实现无按钮且 barrierDismissible=false,弹窗无法关闭,此处补关闭钮)
      case 1: // TEXT
      default:
        await _showHtmlConfirm(
            title: '提示', message: text, confirmText: '关闭', cancelText: '');
        if (!mounted) return null;
        return 1;
    }
  }

  /// [P6-3] th_triggerSlash:执行斜杠脚本,返回 {ok, pipe, isAborted, ...}。
  Future<dynamic> _handleTriggerSlash(Map<String, dynamic> payload) async {
    final command = (payload['command'] as String?) ?? '';
    if (command.trim().isEmpty) {
      return {'ok': true, 'pipe': ''};
    }
    KiraLogger().info('助手API', 'th_triggerSlash 收到命令');
    final result = await _runSlashScript(command);
    return {'ok': !result.isError, ...result.toMap()};
  }

  /// [P6-3] EJS execute() 的后端:执行并回传完整 SlashResult(含 pipe)。
  Future<dynamic> _handleExecuteSlash(Map<String, dynamic> payload) async {
    final command = (payload['command'] as String?) ??
        (payload['text'] as String?) ??
        '';
    final result = await _runSlashScript(command);
    return result.toMap();
  }

  /// [P6-3] 统一执行入口:注册平台命令 → 构造 env → SlashRunner。
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
      // [P6-4] 变量命令落点:统一走 VariablesService + 落盘 + 引擎重同步
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
      // [P6-4] /genraw:静默生成一次,聚合流回文本
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
      // [P6-5.1] /buttons:按钮选择弹窗,选中项回管道 → HTML底部选择框
      showButtons: (labels) async {
        if (!mounted) return null;
        final result = await _showHtmlBottomSheet([
          for (final label in labels) {'text': '$label', 'value': '$label'},
        ]);
        return result;
      },
      // [P6-5.3] 楼层操作:消息数 / 隐藏 / swipe
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
          // 相对:-1=右(下一 swipe/新 swipe),-2=左(上一 swipe)
          final cur = m.currentSwipeIndex < 0 ? 0 : m.currentSwipeIndex;
          final target = swipeIndex == -1 ? cur + 1 : cur - 1;
          if (target < 0) return;
          if (target < m.swipes.length) {
            await notifier.swipeMessage(m.id, target);
          } else if (index == msgs.length - 1) {
            // 末层右切超出 = 生成新 swipe
            await notifier.regenerateLastMessage(config);
          }
          return;
        }
        if (swipeIndex >= 0 && swipeIndex < m.swipes.length) {
          await notifier.swipeMessage(m.id, swipeIndex);
        }
      },
    );
    // 全局变量宏钩子({{getvar::}} 等) — 覆盖写,幂等
    SlashRunner.globalMacroResolver = (input) =>
        VariablesService.instance.processVariableMacrosSync(
            input, chatId: widget.chatId);
    return SlashRunner.execute(command, env: env);
  }

  /// 给 MVU 用的消息序列化：格式对齐 _handleGetMessages，
  /// message 用原文(不走 _serializeMessage 的显示美化，保住 _.set 指令)。
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
// 空卡兜底：给第 0 条消息种一个空的 MvuData 基座。
// MVU 的 getLastValidVariable→isMvuData 要求本子里同时有 stat_data 和 schema，
// 否则 update_variables.ts:1438 会因缺 stat_data 直接 return，
// 导致 AI 回复里的 _.set 指令被丢弃。空卡没有世界书/开场白 initvar，
// 这个空基座让 AI 驱动的变量更新能从零开始。
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
        'is_hidden': m.isHidden, // [P6-5.3] 真值(/hide 语义)
        'message': currentContent,
        'data': <String, dynamic>{},
        'extra': <String, dynamic>{},
        'id': m.id,
        'index': i,
        'is_user': m.role == MessageRole.user,
        'content': m.content,
        'swipe_id': swipeId,
        'swipes': swipes,          //开场白文本版本数组，MVU的143行读它找<initvar>
          'variables': effectiveSwipesData,
          'swipes_data': effectiveSwipesData,
        });
      }
    return result;
    }

  /// thMvuParseMessage: 把卡片 iframe 的 parseMessage 请求转发到引擎房 MVU bundle。
  /// 引擎房的 window.Mvu.parseMessage 是本地 qG 函数,不走 RPC,直接调即可。
  /// fail-open:引擎房未就绪或 Mvu 不存在时返回 old_data 原样,不阻断卡片流程。
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

  /// EJS 渲染桥:接收文本,发进引擎房跑 ST-Prompt-Template 的 evalTemplate,返回渲染后的文本。
  ///
  /// 主案 kick+poll:kick 脚本同步返回 seq id(零 Promise 穿桥依赖,老 WebView 也稳),
  /// 渲染结果由 iframe 回调写进外层 window.__krRes 槽,Dart 轮询读取。
  /// fail-open:任何失败回退 substituteParams 宏替换,再退原文,永不阻断发送。
  Future<String> _handleRenderEJS(Map<String, dynamic> payload) async {
    final text = payload['text'] as String? ?? '';
    if (text.isEmpty) return text;

    final controller = _controller;
    if (controller == null) return text;

    try {
      // E4:不含模板标签的内容不发起 kick+poll,直走宏替换快路径。
      // (保留 {{user}}/{{char}} 宏行为;较原全量 kick 省去 25-75ms/条)
      if (!text.contains('<%')) {
        print('[EJSD-5] no-tag fast path -> macro only len=${text.length}');
        return await _macroFallbackRender(controller, text);
      }

      // ── 补验1修复:渲染前把 Dart 权威变量快照灌进引擎房镜像(__varSync 同形)──
      // 此前镜像只在 MVU 经 th_setVars 写后局部同步,引擎房重建后从空开始,
      // Flutter 宏写的 global/chat 变量从不进镜像 → EJS 会读到旧值或空值。
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
        // [P6-5.2] Ancestor 历史楼层喂入:最近 30 层的当前 swipe 变量,
        // dist getvar(withMsg) 可读历史;与 _pushInitialVarSnapshots 窗口一致。
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
                // [P6-5.2] Ancestor 多层灌入(最近30层当前swipe)
                var fls = snap.floors || [];
                for (var fi = 0; fi < fls.length; fi++) {
                  var fl = fls[fi];
                  if (!fl || typeof fl.mid !== 'number' || fl.mid < 0) continue;
                  w._TH.__varCache.message[fl.mid] = fl.data || {};
                  w.chat[fl.mid] = w.chat[fl.mid] || {};
                  w.chat[fl.mid].variables = w.chat[fl.mid].variables || [];
                  w.chat[fl.mid].variables[fl.sid || 0] = fl.data || {};
                }
                // 兼容:最新层仍写 message/mid/sid
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
            // [TPL-1] 一次性 dump 模板作用域全量 key(EjsTemplate.prepareContext 即上游 Hf)
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
            // [P6-2] 渲染前快照:evalTemplate 后对 global/chat 桶做 diff,
            // 把模板内 setvar/incvar/delvar 的变化经 th_setVars 持久化到 Dart。
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
                  // dist 写入桶的值是 JSON 字符串,回写 Dart 前先解一层
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
            "(function(){var r=window.__krRes&&window.__krRes[$idNum];"
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
          // [P6-2] EJS 写回桥:先把模板内 setvar/delvar 的桶变化持久化,
          // 必须在空串硬保护之前(纯写变量的模板输出为空也不能丢写回)。
          if (res['diff'] is Map) {
            await _persistEjsWriteback(
                (res['diff'] as Map).cast<String, dynamic>());
          }
          print('[EJSD-5] evalTemplate ok vlen=${v.length}');
          // E3 硬保护:null/undefined/空串一律回退原文,绝不把空内容交给 LLM
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

  /// [P6-2] EJS 写回桥:把引擎房 diff 出的 global/chat 桶变化持久化到 Dart。
  /// scope 路由与 dist 语义对位;message 桶不落库(防 MVU 双写,只留在镜像)。
  /// 写回后 _syncVarsToEngine 一次,让 Trinity cache 重合并(同 P6-1 §1.4 第5步)。
  Future<void> _persistEjsWriteback(Map<String, dynamic> diff) async {
    try {
      final service = VariablesService.instance;

      // ── global 桶 ──
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

      // ── chat 桶 ──
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
          // setmap 分支自带落盘+引擎房重合并(读回整表)
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
      // fail-open:写回失败只记日志,绝不阻断渲染
      KiraLogger().info('EJS写回', '持久化失败 error=$e');
    }
  }

  /// 宏替换兜底(原 th_renderEJS 行为):{{user}}/{{char}}/<user>/<char>。
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
      // E3 硬保护:宏替换结果为空(null/非串/空串)一律回退原文
      if (result != null && result is String && result.isNotEmpty) return result;
      return text;
    } catch (e) {
      KiraLogger().info('EJS渲染', '宏替换兜底也失败 error=$e');
      return text;
    }
  }
  /// 酒馆助手 generateRaw：MVU 额外模型解析走这里。
  /// 拆 cfg.custom_api 造临时 LLMConfig，拍平 ordered_prompts+injects 成 messages，
  /// 调 llm_service 发一次请求，把文本原样回传给 MVU（MVU 自己解析 _.set 后走 setVariables 落库）。
  Future<dynamic> _handleGenerateRaw(Map<String, dynamic> payload) async {
    final cfg = (payload['cfg'] as Map?)?.cast<String, dynamic>() ?? {};
    final customApi = (cfg['custom_api'] as Map?)?.cast<String, dynamic>();

    KiraLogger().info('额外模型', 'th_generateRaw 被调 hasCustomApi=${customApi != null}');

    // 1) 造 config：有 custom_api 用独立配置，否则沿用主对话 config（"与插头相同"）
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

    // 2) 拍平 ordered_prompts + injects 成 messages（B+：先顺序拼接）
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
          // 展开真实聊天记录（最近 N 条），修复 past_observe 空壳
          final n = _asInt(cfg['max_chat_history']) ?? 10;
          final history = ref.read(activeChatProvider).messages;
          final recent =
              history.length > n ? history.sublist(history.length - n) : history;
          
          for (var _h = 0; _h < recent.length; _h++) {
            final _m = recent[_h];
            final _sw = _m.swipes;
            final _si = _m.currentSwipeIndex;
            final _c = (_sw.isNotEmpty && _si >= 0 && _si < _sw.length) ? _sw[_si] : _m.content;
          }

          for (int i = 0; i < recent.length; i++) {
            final m = recent[i];
            // 与 _serializeMessagesForMvu 一致：优先取当前 swipe 的正文
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
            if (i > 0) content = '\n\n' + content;

            messages.add({'role': r, 'content': prefix + content});
          }
        }
        // 其他字符串占位符(persona/char/world_info/user_input)B阶段忽略
      }
    }

    appendList(cfg['ordered_prompts']);
    appendList(cfg['injects']);
    // 注入当前变量状态（更新前）：从消息 swipesData 回溯取最后一条有效 stat_data，
    // 与 MVU getLastValidVariable 的读取语义一致。不再读空的存储A。
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

    // MVU 的 user_input 是 user turn 内容，补上——否则全 system，Claude 等通道 422
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

    // 3) 调 llm_service 发一次，聚合流为完整文本
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
      // 失败返回空串，让 MVU 走它的重试/降级，不抛异常炸桥
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
  /// 酒馆助手 getChatMessages 的 Flutter 侧实现。
  /// 读取当前会话消息，映射成与 TavernHelper 对齐的格式返回。
  /// 数据源唯一：ActiveChatNotifier.state.messages（避免串台）。
  Future<dynamic> _handleGetMessages(Map<String, dynamic> payload) async {
    // 兼容两种参数名：规格 include_swipes / 旧版 include_swipe
    final start = (payload['start'] as int?) ?? 0;
    final includeSwipe = (payload['include_swipes'] as bool?) ??
        (payload['include_swipe'] as bool?) ??
        false;
    KiraLogger().info('助手API', 'th_getMessages 被调用 start=$start swipe=$includeSwipe');

    final activeChat = ref.read(activeChatProvider);
    final messages = activeChat.messages;
    // name 推导：assistant/system 优先用消息缓存的角色名，其次用当前角色名
    final defaultCharName = activeChat.character?.name ?? 'Assistant';
    KiraLogger().info('助手API', 'th_getMessages 读到 ${messages.length} 条消息');
    final result = <Map<String, dynamic>>[];

    for (var i = start; i < messages.length; i++) {
      final m = messages[i];
      final swipes = m.swipes;
      final swipeId = m.currentSwipeIndex;
      // 当前 swipe 内容：有 swipes 就取当前，否则用 content
      final currentContent =
          (swipes.isNotEmpty && swipeId >= 0 && swipeId < swipes.length)
              ? swipes[swipeId]
              : m.content;
      final name = switch (m.role) {
        MessageRole.user => 'User',
        MessageRole.assistant => m.characterName ?? defaultCharName,
        MessageRole.system => 'System',
      };
      // 对齐 TavernHelper ChatMessage 规格字段
      final map = <String, dynamic>{
        'message_id': i,
        'name': name,
        'role': m.role.name, // system / assistant / user
        'is_hidden': m.isHidden, // [P6-5.3] 真值(/hide 语义)
        'message': currentContent,
        'data': <String, dynamic>{},
        'extra': <String, dynamic>{},
        // 兼容旧字段（避免已依赖旧格式的地方炸）
        'id': m.id,
        'index': i,
        'is_user': m.role == MessageRole.user,
        'content': m.content,
        'swipe_id': swipeId,
        'variables': m.swipesData,
      };
      if (includeSwipe) {
        // 对齐 ChatMessageSwiped 规格
        map['swipes'] = swipes;
        map['swipes_data'] = m.swipesData;
        map['swipes_info'] =
            List.generate(swipes.length, (_) => <String, dynamic>{});
      }
      result.add(map);
    }
    return result;
  }

  /// 酒馆助手 getVariables：按 scope 返回整个变量表。
  /// option.type: 'chat'(局部) / 'global'(全局)，默认 'chat'。
  Future<dynamic> _handleGetVariables(Map<String, dynamic> payload) async {
    final option = (payload['option'] as Map?)?.cast<String, dynamic>() ?? {};
    final type = (option['type'] as String?) ?? 'chat';
    final service = VariablesService.instance;
    KiraLogger().info('助手API', 'th_getVars 被调用 type=$type');

    if (type == 'global') {
      return service.getAllGlobalVariables();
    }
    // [P5-9/P0-3] 脚本级变量(读走门面本地缓存,此处为桥直达路径的兜底)。
    if (type == 'script') {
      final scriptId = (option['script_id'] as String?) ??
          (option['scriptId'] as String?) ??
          '';
      return service.getScriptVariables(scriptId);
    }
    // 默认 chat 局部变量
    final result = service.getAllLocalVariables(widget.chatId);
    return result;
  }

  /// 酒馆助手 setVariables：按 scope 写入变量表并持久化。
  /// 语义：把传入的 vars 逐 key 写入（insertOrAssign），不整表替换。
  Future<dynamic> _handleSetVariables(Map<String, dynamic> payload) async {
    final vars = (payload['vars'] as Map?)?.cast<String, dynamic>() ?? {};
    final option = (payload['option'] as Map?)?.cast<String, dynamic>() ?? {};
    final type = (option['type'] as String?) ?? 'chat';
    final service = VariablesService.instance;
    KiraLogger().info('助手API', 'th_setVars 被调用 type=$type keys=${vars.keys.toList()}');

    // [P5-9/P0-3] 脚本级变量:按 script_id 隔离,整表写入,设备级持久。
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
    // MVU 消息级持久化：把整份 MvuData 写进消息的 swipesData 并落库。
    // MVU 的 replaceVariables 用 type:message 但常不带 message_id（它靠宿主隐式定位"当前消息"）。
    // 缺失时落到最后一条消息——契合 getLastValidVariable 从末尾回溯的读取语义。
    if (type == 'message') {
      final messageId = option['message_id'] as int?;
      final notifier = ref.read(activeChatProvider.notifier);
      final messages = ref.read(activeChatProvider).messages;

      // 选定目标消息：有效 message_id 用它，否则回退到最后一条
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
        // [CHRONICLE Phase 4] 捕获更新前的最后有效stat_data（MVU桥接比对用）
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
        // [CHRONICLE Phase 4] MVU→Chronicle桥接：重大数值变化→记忆事件（异步，只读MVU不回写）
        if (vars['stat_data'] is Map && (vars['stat_data'] as Map).isNotEmpty) {
          unawaited(ref.read(chronicleOrchestratorProvider).onMvuVariableUpdated(
                widget.chatId,
                chronicleOldStat,
                Map<String, dynamic>.from(vars['stat_data'] as Map),
              ));
        }
        // 同步引擎房镜像
        _syncVarsToEngine('message', vars, messageId: targetIndex, lastMsgId: targetIndex, swipeId: swipeId);
        return vars;
      }
      // 连一条消息都没有（极端情况），才落 chat 兜底
      debugPrint('[setVars修复] 无任何消息，回退 chat 分支');
    }
    // 默认 chat 局部变量：写内存 + 落盘持久化
    for (final entry in vars.entries) {
      service.setLocalVariable(widget.chatId, entry.key, entry.value);
    }
    await service.saveLocalVariablesToPrefs(widget.chatId);
    final readBack = service.getAllLocalVariables(widget.chatId);
    // [P3-E3] 补 lastMsgId: card 门控与 latest 解析都依赖它, 缺失时 card 端维持旧值
    final msgsNow = ref.read(activeChatProvider).messages;
    _syncVarsToEngine('chat', readBack, lastMsgId: msgsNow.isNotEmpty ? msgsNow.length - 1 : null);
    return readBack;
  }

  /// [P6-5.2] 注入正则规则快照(引擎房/脚本房/卡片门面的同步 getRegexedString 引擎消费)。
  /// 字段紧凑形:f=findRegex r=replaceString p=placement索引 o=order d=disabled
  /// mo=markdownOnly po=promptOnly e=runOnEdit t=trimStrings min/max=深度区间。
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

  /// [P6-5.2] Ancestor 历史楼层快照:最近 N 层的当前 swipe 变量。
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
    return floors.reversed.toList(); // 升序(老→新)
  }

  /// [P3-K2-2] 读取当前 prompt sections 列表（球用）
  /// 返 [{type, name, enabled, order}, ...] 全 section（无论 enabled），方便球一次性渲染开关。
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

  /// [P3-K2-2] 切换某 section 开关（球点击 → 这）
  /// payload: { type: 'nsfw' } 或 { type: 'nsfw', enabled: false }。
  /// 若提供 enabled 则直接 set；否则 toggle。返更新后的 section 列表。
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
    // 不主动 push,listener 会自动推 pmSectionsChanged;但同步返当前状态供球即时刷新
    return _handlePmGetSections(payload);
  }
  // ── [P5-9/P1] 预设管理 API(ST Preset 契约) ─────────────────────
  // 狐神断链二修复:getPreset('in_use')/updatePresetWith 全链路。
  // 形状对齐 ST: { name, settings:{should_stream,...}, prompts:[{identifier,name,role,content,enabled,...}] }。
  // 'in_use' 名字解析到当前激活预设;settings/prompts 的活跃值读 live provider
  // (llmConfigProvider.streamEnabled / promptManagerProvider.sections)。

  /// ST prompt 条目 ← PromptSection(键集取 ST tavern-helper Preset 契约常用子集)
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

  /// AIPreset → ST Preset JSON。live=true 时 settings/prompts 取 live provider 真值。
  Map<String, dynamic> _stPresetJson(AIPreset preset, {required bool live}) {
    final passthrough = _stSettingsPassthrough[preset.name];
    final streamEnabled = live
        ? ref.read(llmConfigProvider).streamEnabled
        : preset.generationSettings.streamEnabled;
    final settings = <String, dynamic>{
      if (passthrough != null) ...passthrough, // 未知键铺底
      'should_stream': streamEnabled, // 已建模键以真值覆盖
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

  /// 按名解析预设:'in_use' → 当前激活,否则全量按名查找。
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

      // [P5-12] TTL 缓存命中
      final cached = _presetReadCache[cacheKey];
      final cachedAt = _presetCacheAt[cacheKey];
      if (cached != null &&
          cachedAt != null &&
          DateTime.now().difference(cachedAt) < _presetCacheTTL) {
        debugPrint('[getPreset] 缓存命中: $name');
        return cached;
      }

      // [P5-12] 在途合并:同一预设的并发读只算一次
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

  /// setPreset(name, preset): 写回。
  /// - settings.should_stream → 生成设置(in_use 立即生效到 llmConfig);
  ///   其余 settings 键进会话透传袋(下次 getPreset 原样铺底,不做字段白名单)。
  /// - prompts → 按 identifier 合并进 PromptManagerConfig
  ///   (in_use 同步应用 live promptManagerProvider 并落盘激活预设,切预设往返不丢)。
  /// - 完成后发 preset_changed / settings_updated 事件(供狐 invalidate/preset/load 钩子)。
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

      // prompts → sections 合并(按 identifier;未识条目跳过,不名单)
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

      // 应用到 live(仅 in_use):流式开关 + prompt 配置立即生效
      if (isLive) {
        if (shouldStream != null) {
          // updateStreamEnabled 是同步 setter(内部自持久化),不可 await
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

      // 持久化进预设对象(内建首次修改转自定义覆写,同 _saveCurrentToActivePreset)
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

      // [P5-12] 写成功 → 立即失效读缓存(双侧:本层 + 各脚本房 JS 侧由
      // preset_changed 事件清 __KIRA_PRESET_CACHE)
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

  /// [P5-9/P1] generate: 触发完整生成回合(狐神自动推进/二次生成)。
  /// arg 形态(TH 契约): 'normal'/'continue' 字符串,或 {user_input:'文本'}。
  /// 桥 30s 超时 < LLM 生成时长 → 不和生成结果绑定,立即返回;
  /// 完成/取消由 generation_ended 事件通知(见 3.3),脚本应走事件而非返回值。
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
        // {user_input} 语义:插一条用户消息并触发生成
        await ref.read(activeChatProvider.notifier).sendMessage(userInput, config);
      } else {
        // 'normal'/'continue' 均 = 让 AI 基于当前会话生成下一条
        await ref.read(activeChatProvider.notifier).continueGeneration(config);
      }
      return '';
    } catch (e) {
      debugPrint('[generate] 错误: $e');
      return '';
    }
  }

  /// [P5-9/P1] stopGeneration: 取消当前生成。
  Future<dynamic> _handleStopGeneration(Map<String, dynamic> payload) async {
    try {
      await ref.read(activeChatProvider.notifier).cancelGeneration();
      return {'ok': true};
    } catch (e) {
      debugPrint('[stopGeneration] 错误: $e');
      return {'ok': false, 'error': '$e'};
    }
  }

  /// 向引擎房发预设/设置事件(JS __emitToEngine 会中继到全部脚本房)。
  void _emitPresetEvent(String type) {
    _controller?.evaluateJavascript(
        source:
            'if(window.__emitToEngine)window.__emitToEngine(${jsonEncode(type)},[],null);');
  }

  /// 反向同步:把变量表推进引擎房镜像。
  void _syncVarsToEngine(String type, Map<String, dynamic> data, {int? messageId, int? lastMsgId, int? swipeId}) {
    final dataJson = jsonEncode(data);
    final midArg = messageId?.toString() ?? 'null';
    final lastArg = lastMsgId?.toString() ?? 'null';
    final swipeArg = swipeId?.toString() ?? 'null';
    _controller?.evaluateJavascript(
        source: 'if(window.__syncVarsToEngine)window.__syncVarsToEngine('
            '"$type",$dataJson,$midArg,$lastArg,$swipeArg);');
  }

  /// [P3-E3] 启动/重建后把存量 MvuData(swipesData)逐条推进 __syncVarsToEngine,
  /// 让 card iframe 的 window.Mvu 门控(需 message 级 stat_data)与快照读有数据可用。
  /// 仅推最近 30 条(与首屏渲染批量一致), 避免长聊天整包注入。
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
      // chat 变量也补一拍(card 门控兜底 + getAllVariables 合并用)
      final chatVars = VariablesService.instance.getAllLocalVariables(widget.chatId);
      if (chatVars.isNotEmpty) {
        _syncVarsToEngine('chat', chatVars, lastMsgId: lastIdx);
      }
      KiraLogger().info('MVU', '存量变量快照已推送 start=$start lastIdx=$lastIdx');
    } catch (e) {
      KiraLogger().info('MVU', '存量变量快照推送失败: $e');
    }
  }
  /// 推送角色主世界书名到引擎房镜像（供 MVU isExtraModelSupported 同步读）
  Future<void> _syncPrimaryLorebookToEngine() async {
    try {
      final charId = ref.read(activeChatProvider).character?.id;
      if (charId == null) return;
      final repo = ref.read(worldInfoRepositoryProvider);
      final books = await repo.getWorldInfosForCharacter(charId);
      // A2修复:主书取第一本【有条目】的书——自动空壳排前时不再遮蔽真书
      final names = books.map((b) => b.name).whereType<String>().toList();
      String? primary;
      for (final b in books) {
        if (b.enabled && b.entries.isNotEmpty && b.name != null) {
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

  // ── 世界书 API handlers ─────────────────────────────
  // 把 WorldInfoEntry 序列化成卡片侧（SillyTavern 风格）的 JSON
  Map<String, dynamic> _wiEntryToJson(models.WorldInfoEntry e) => {
        'uid': e.id,
        'worldId': e.worldInfoId,
        // [P5-8/P0] 补 name 字段(ST 语义: name=comment 显示名)。
        //   道渊对条目只做 e.name===/e.name.includes(...) 匹配(e.g pretty.js:1312-1314),
        //   缺 name 即抛 "Cannot read properties of undefined (reading 'includes')"。
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

  /// 取当前角色绑定的世界书列表（含全局）。
  Future<dynamic> _handleWiGetLorebooks(Map<String, dynamic> payload) async {
    // [P5-6阶段0.1] 读缓存: 5s 轮询稳态下 TTL 窗口内不再打 DB
    final cached = _wiCacheLookup('th_wiGetLorebooks');
    if (!identical(cached, _wiCacheMiss)) return cached;
    final WorldInfoRepository repo = ref.read(worldInfoRepositoryProvider);
    final all = await repo.getAllWorldInfos();
    final result = all.map((b) => b.name).toList();
    _wiCacheStore('th_wiGetLorebooks', null, result);
    return result;
  }

  /// 新建一本世界书（SillyTavern createLorebook）。payload: {name}
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

  /// 取角色世界书条目(走桥给 MVU/EJS)。payload: {name}
  /// A2修复:合并语义——返回该角色【全部已绑定且启用】的世界书条目
  /// (按 insertion_order 统一排序),不再被自动空壳遮蔽;
  /// 表侧为空时回退角色卡内嵌 character_book(兼容旧数据)。
  Future<dynamic> _handleWiGetEntries(Map<String, dynamic> payload) async {
    // [P5-6阶段0.1] 读缓存: key 含请求书名,合并语义下 null/同名同结果
    final reqName = payload['name'] as String?;
    final cached = _wiCacheLookup('th_wiGetEntries', reqName);
    if (!identical(cached, _wiCacheMiss)) return cached;
    final WorldInfoRepository repo = ref.read(worldInfoRepositoryProvider);
    final charId = ref.read(activeChatProvider).character?.id;

    // [P5-8/P0] 按名精确取书:道渊/MVU 都是按名单本请求(TH getWorldbook(name) 语义)。
    //   原合并语义会让道渊选"未绑定/禁用"书时取到别书条目、MVU 逐本请求拿到重复合集。
    //   现在:有 reqName 时优先在仓库全量精确命中该书,命中即返回该书全部条目(含禁用,
    //   道渊要做开关管理);未命中或空书才走下方合并+内嵌兜底(保 519 内嵌回退不回归)。
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
      // 回退:内嵌 character_book(表侧无条目时的旧数据兼容)
      final book = ref.read(activeChatProvider).character?.characterBook;
      final fallback = <Map<String, dynamic>>[];
      if (book != null) {
        final name = reqName;
        // 519 返回的名字会原样传回来，对不上就不返
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
    // MVU 从这里拿 selected_global_lorebooks 当作全局启用世界书
    // 先返空列表，保证 MVU 不报错、能继续跑
    return {'selected_global_lorebooks': <String>[], 'overflow_alert': false};
  }

  /// [P5-6阶段2.4] getTavernRegexes 只读桥: RegexScript → ST TavernRegex 形状映射。
  /// type=global 只回全局; character 回全局+当前角色合并(combined,禁用脚本已滤);
  /// preset 平台无此维度,降级同 global。排序按 order(执行顺序)。
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

  /// RegexScript → TavernRegex(官方 tavern_regex.d.ts 形状: source/destination 布尔桶)
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

  /// [P5-8/P1] extensionSettings 持久化:道渊/MVU 面板写回 → 提取 mvu_settings 落定 MvuSettings。
  /// 合并语义:null 键保留平台现值(JS 侧 MVU 每次写回完整解析对象,见 mvu_bundle:3154-3161,
  /// 但防御性按键合并,避免未来半截对象清掉平台值)。
  /// 持久化后重推 __KIRA_MAIN_ENV,主文档 getContext 当会话内同步新值。
  Future<dynamic> _handleSaveExtensionSettings(Map<String, dynamic> payload) async {
    try {
      final settings = payload['settings'] as Map<String, dynamic>?;
      if (settings == null) return {'ok': false, 'error': 'settings required'};
      final mvu = settings['mvu_settings'] as Map<String, dynamic>?;
      if (mvu == null) return {'ok': true}; // 无 mvu 段,无事可做
      final notify = mvu['通知'] as Map<String, dynamic>?;
      final extra = mvu['额外模型解析配置'] as Map<String, dynamic>?;
      final cur = ref.read(mvuSettingsProvider);
      final updated = cur.copyWith(
        updateMode: mvu['更新方式'] as String?,
        notifyFrameworkLoaded: notify?['MVU框架加载成功'] as bool?,
        notifyInitSuccess: notify?['变量初始化成功'] as bool?,
        notifyVarError: notify?['变量更新出错'] as bool?,
        notifyExtraParsing: extra?['额外模型解析中'] as bool?,
        jailbreakScheme: extra?['破限方案'] as String?,
        autoRequest: extra?['启用自动请求'] as bool?,
        maxChatHistory: (extra?['max_chat_history'] as num?)?.toInt(),
        modelSource: extra?['模型来源'] as String?,
        apiUrl: extra?['api地址'] as String?,
        apiKey: extra?['密钥'] as String?,
        modelName: extra?['模型名称'] as String?,
        // [P6-BUG-1] 整份原始对象透传落盘(MVU 的 internal 已提醒标志等
        // 全在其中;此前只留三段,标志丢失导致升级提醒每次进页重弹)
        webRaw: mvu,
      );
      await ref.read(mvuSettingsProvider.notifier).applyFromWeb(updated);
      // 主文档 __KIRA_MAIN_ENV 同源刷新,道渊下一轮读到的就是新值
      final c = _controller;
      if (c != null) await _injectMainEnv(c);
      // [P5-9/P1] 设置保存后发 SETTINGS_UPDATED(狐神监听它做面板状态同步)
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
  /// 内嵌世界书条目 → 卡片侧(SillyTavern风格)JSON，字段对齐 _wiEntryToJson。
  /// MVU 读 comment(筛 [initvar]) 和 content(抽 <initvar> 块)。
  Map<String, dynamic> _charBookEntryToMvu(CharacterBookEntry e) => {
        'uid': e.id,
        // [P5-8/P0] 补 name 字段(与 _wiEntryToJson 对齐,道渊 .name.includes 必需)。
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

  /// 角色绑定的世界书。MVU 期望 {primary, additional:[...]} 结构。
  Future<dynamic> _handleWiGetCharLorebooks(Map<String, dynamic> payload) async {
    // [P5-6阶段0.1] 读缓存: 同角色 2s 内复用
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
    // A2修复:primary 取第一本【启用且有条目】的书,空壳不遮蔽真书
    final names = books.map((b) => b.name).whereType<String>().toList();
    String? primary;
    final additional = <String>[];
    var primaryDecided = false;
    for (final b in books) {
      final n = b.name;
      if (n == null) continue;
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

  /// 更新条目（按 uid 找到已有条目改内容/关键词）。payload: {worldId/name, entries:[...]}
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
  /// 酒馆助手 setChatMessages（复数）：MVU 用它把 per-swipe 变量种进消息。
  /// 每项 {message_id, swipes_data:[...]}，把 swipes_data 写进 ChatMessage.swipesData。
  Future<dynamic> _handleSetMessages(Map<String, dynamic> payload) async {
    final msgs = (payload['msgs'] as List?) ?? const [];
    final messages = ref.read(activeChatProvider).messages;
    final notifier = ref.read(activeChatProvider.notifier);
    // [P5-12] 狐神 forceRefreshAll 会把全部楼层(仅 message_id,无 swipes_data)
    // 发过来;此前无条件 _pushMessages 造成"空更新→全量重渲染"无意义回路
    // (P5-11 第六部分)。改为只在有真实写入时才重渲染。
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

  /// 新建条目。payload: {worldId/name, entries:[{keys, content, ...}]}
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

  /// 删除条目。payload: {uids:[...]}
  Future<dynamic> _handleWiDeleteEntries(Map<String, dynamic> payload) async {
    _wiCacheInvalidate('th_wiDeleteEntries');
    final WorldInfoRepository repo = ref.read(worldInfoRepositoryProvider);
    final uids = (payload['uids'] as List?)?.cast<String>() ?? [];
    for (final uid in uids) {
      await repo.deleteEntry(uid);
    }
    return {'ok': true, 'deleted': uids.length};
  }

  /// 从 payload 解析出目标世界书 id（支持传 worldId 或 name）。
  Future<String?> _wiResolveWorldId(WorldInfoRepository repo, Map<String, dynamic> payload) async {
    final worldId = payload['worldId'] as String?;
    if (worldId != null) return worldId;
    final name = payload['name'] as String?;
    if (name == null) return null;
    final all = await repo.getAllWorldInfos();
    final matches = all.where((b) => b.name == name);
    return matches.isEmpty ? null : matches.first.id;
  }
  /// 酒馆助手 setChatMessage 的 Flutter 侧实现。
  /// 按楼层索引定位消息，切换 swipe 或改写内容，然后触发 WebView 重渲染。
  /// 数据源唯一：activeChatProvider（避免串台）。
  Future<dynamic> _handleSetMessage(Map<String, dynamic> payload) async {
    final index = payload['index'] as int?;
    final swipeId = payload['swipe_id'] as int?;
    final content = payload['content'] as String?;
    final refresh = (payload['refresh'] != null); // 有 refresh 字段就刷新
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
      // 优先按 swipe 切换：从 swipes 数组取内容更可靠
      KiraLogger().info('助手API', 'th_setMessage 切换到 swipe $swipeId');
      await notifier.swipeMessage(target.id, swipeId);
    } else if (content != null) {
      // 无有效 swipe_id 时，按内容改写当前楼层
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

    // [顶栏] 头像 32→24:适配 32dp 矮顶栏
    Widget fallback = const CircleAvatar(
      radius: 12,
      backgroundColor: Colors.white12,
      child: Icon(Icons.person, size: 14, color: Colors.white54),
    );

    if (avatarPath != null && avatarPath.isNotEmpty) {
      // 走统一组件：内部处理相对→绝对路径转换 + 缓存,修复顶栏头像不显示
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
  /// 深色磨砂玻璃顶栏：矮、半透明、通透
  PreferredSizeWidget _buildGlassAppBar(
      Character? character, String? activeModel) {
    return AppBar(
      // [顶栏] 56:双行标题(角色名+模型名);同高度需同步:
      // bridge barHeight / 毛玻璃层 AnimatedPositioned / __KIRA_TOP_INSET__ 烘入
      toolbarHeight: 56,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Colors.transparent, // 背景交给 body 里的毛玻璃层
      titleSpacing: 12,
      // [返回] 简约尖括号 <,替代 AppBar 自动插入的 arrow_back(带横杠箭头);
      // 走 _exitChat 与系统返回手势同一退出流程
      leading: IconButton(
        tooltip: '返回',
        icon: const Icon(Icons.chevron_left, size: 28),
        color: activeGlassPalette.primaryText,
        onPressed: _exitChat,
      ),
      // flexibleSpace 在此 AppBar 中不渲染,已放弃,毛玻璃改由 body 顶部独立层实现
      title: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openModelSheet(),
        child: Row(
          children: [
            _buildAvatar(character),
            const SizedBox(width: 10),
            // [顶栏] 双行标题:上行角色名,下行模型名(小字灰),点击弹模型层
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
            // 自动生图中：呼吸✨提示(从输入栏迁移至此,平时隐藏不占空间)
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
        // 回到顶部：滚到第一条消息(楼层1,复用跳楼层桥)
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
    // 先弹窗，显示 loading 状态
    _bridge.send(BridgeType.showModelSheet, {
      'models': <String>[],
      'current': config.model,
      'loading': true,
      
      'configs': configsState.configs
          .map((c) => {'id': c.id, 'name': c.name, 'active': c.isDefault})
          .toList(),
    });
    // 后台拉取，完成后更新
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

  // ── 底部输入栏 ──────────────────────────────────────────────────────────────
  // [聊天页大改] 输入栏已迁入 WebView(chat_stage.html .chat-input-container)
  // 通过 --keyboard-height CSS 变量跟随键盘,所有交互走 ChatBridge:
  //   inputSend / inputStop / inputUpload / inputFunc / inputRemoveAttachment
  // Flutter 通过 inputBarState 推送状态(generating/attachments/tokenCount/stt 等)。
  // 原 Flutter 输入栏 UI 不再渲染,相关状态(_inputController/_pendingAttachments/
  // _hasInput/_TokenCountBadge/_SttMicButton 等)保留以便脚本 #send_but 等流程复用。

  Widget _buildInputBar(bool isGenerating) {
    return const SizedBox.shrink();
  }

  // [聊天页大改] WebView 输入栏桥:功能菜单按钮(原 Flutter IconButton 的 onPressed 逻辑)
  // 现在由 WebView 的 #funcBtn 调 inputFunc 桥触发,这里实现原逻辑。
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

  // [聊天页大改] WebView 输入栏桥:图片上传按钮(已移除,保留方法以防回滚)
  // 图片上传现在走 +号菜单 → func-overlay "图片" 项 → panelAction.pickImages → _pickImages
  // 见 _bridge.on(BridgeType.panelAction) 的 case 'pickImages' 分支
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

  // [聊天页大改] WebView 输入栏桥:移除某张待发图片
  void _handleInputRemoveAttachment(int index) {
    if (index < 0 || index >= _pendingAttachments.length) return;
    setState(() => _pendingAttachments.removeAt(index));
    _pushInputBarState();
  }

  // [聊天页大改] 把当前输入栏状态推给 WebView(generating / 附件 / token 计数 / STT 开关)
  // 触发时机:isGenerating 变化 / 附件增删 / STT 开关变化 / STT 录音中变化
  void _pushInputBarState() {
    if (!mounted) return;
    final isGenerating = ref.read(activeChatProvider).isGenerating;
    final showTokenCount = ref.read(tokenizerSettingsProvider).showTokenCount;
    final text = _inputController.text.trim();
    String? tokenCount;
    if (showTokenCount && text.isNotEmpty) {
      // tokenCountEstimateProvider 是 Provider.family<int, String>,直接返回 int
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


  // [发送] 同步"输入框是否有内容"到 _hasInput(ValueNotifier 值不变不通知,
  // 只有 true↔false 跳变时重建按钮,不逐键重建整个 build)
  void _syncHasInput() {
    _hasInput.value = _inputController.text.trim().isNotEmpty;
  }

  // ── [STT] 话筒按钮:按住录音,松开识别,结果追加到输入框 ──────────────────────

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
    // [聊天页大改] 输入栏在 WebView 里,STT 结果要桥回 WebView 填到 textarea
    // 同时仍同步到 _inputController,以便 #send_but 等脚本流程读 _inputController.text 时一致
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
      // 取消失败静默处理
    }
  }

  /// 退出聊天页:pause → 遮罩瞬间盖满 → 卸载 WebView → 一帧后 pop。
  /// 顶栏返回按钮与 PopScope(系统返回手势)共用此流程。
  Future<void> _exitChat() async {
    await _controller?.pause();
    // 遮罩瞬间盖满(不用 forward 淡入——半透明×WebView 合成会卡)
    _maskController.value = 1.0;
    // 先把 WebView 从树上卸载,消除 pop 切页时的残影闪烁
    if (mounted) setState(() => _webViewMounted = false);
    // [空会话] 用户从没发过消息 → 丢弃(不进回忆/不占存储)。判定用持久标记
    // hasUserMessage(发过即置位、删消息不回退),在 repository.addMessage 置位。
    await _discardEmptyChatIfNeeded();
    // 等一帧,确保 WebView 真正移除、遮罩已盖稳
    await Future.delayed(const Duration(milliseconds: 32));
    if (mounted) context.pop();
  }

  /// [空会话] 退出时若本会话从未有过用户消息(只有开场白/空白),级联删除之。
  /// 有标记的会话零接触。删除后失效聊天列表 provider,回忆页立即可见。
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
    _maskController.value = 1.0;   // 瞬间全黑，转场期间挡死 WebView，避免平台视图逐帧合成
    if (!mounted) return;
    await context.push(route);
    if (!mounted) return;
    _maskController.reverse();      // 返回后黑幕淡出
    await _controller?.resume();
  }

  // ── [浮窗化] 设置面板:Flutter 端处理 ──────────────────────────────────

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

  /// 打开正则浮窗面板(全局/角色tab):收集正则脚本数据推给 WebView。
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

  /// 序列化正则脚本数据(双scope列表+编辑态详情,打开/刷新复用)。
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

  /// 正则面板操作处理:列表加载/详情/开关/删除/保存。
  Future<void> _handleRegexPanelAction(
      String action, Map<String, dynamic> data) async {
    final character = ref.read(activeChatProvider).character;
    final characterId = character?.id;
    final scope = data['scope'] as String? ?? 'global';

    Future<void> pushRefresh({Map<String, dynamic>? editDetail}) async {
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
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/regex_scripts_${DateTime.now().millisecondsSinceEpoch}.json');
        await file.writeAsString(json);
        await Share.shareXFiles([XFile(file.path)], subject: '正则规则导出');
        break;
    }
  }

  // ── [浮窗化] 气泡背景面板 ─────────────────────────────────────────────

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

  // ── [浮窗化] TTS语音面板 ─────────────────────────────────────────────

  Future<void> _openTtsPanel() async {
    final settings = ref.read(ttsSettingsProvider);
    // [P2修复] 正确await语音列表,而非whenData可能拿到空列表
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
        'apiKey': settings.apiKey ?? '',
        'apiEndpoint': settings.apiEndpoint ?? '',
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
        // [P2修复] 切换引擎后强制刷新语音列表
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
        notifier.setApiKey(data['value'] as String);
        break;
      case 'setApiEndpoint':
        notifier.setApiEndpoint(data['value'] as String);
        break;
      case 'testTts':
        final speak = ref.read(ttsSpeakProvider);
        speak('你好，这是语音合成测试。');
        break;
    }
  }

  // ── [浮窗化] 变量管理面板 ────────────────────────────────────────────

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

  // ── [Chronicle融合] Chronicle 超级记忆面板 ─────────────────────────

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

  // ── [Chronicle融合] Wiki 记忆库管理面板（运行监控+记忆管理） ────────

  Future<void> _openWikiPanel() async {
    _bridge.send(BridgeType.openSettingsPanel, {
      'panel': 'wiki',
      'title': 'Chronicle 记忆库',
      'data': await _serializeWikiData(),
    });
  }

  /// 解析任务 messageIds JSON，返回id列表（失败返回空）
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
      // 词条列表
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
      // 实体列表
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
      // 任务队列
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
      // 统计
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
      // 当前生效的完整prompt（内置模板，不含对话内容）
      'currentPrompt': ChronicleSummaryService.basePrompt,
      // 用户自定义追加
      'customPromptSuffix': cs.customPromptSuffix,
      // 成人内容提示词追加（独立字段）
      'matureContentSuffix': cs.matureContentSuffix,
      // 最大重试次数
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
          await repo.deleteAllEntriesForChat(widget.chatId);
          await repo.clearArchivedMessageIds(widget.chatId);
          await repo.clearTasksForChat(widget.chatId);
          final messages = ref.read(activeChatProvider).messages;
          await ref
              .read(chronicleOrchestratorProvider)
              .forceEnqueueAll(widget.chatId, messages);
          _snack('已重新对全部消息入队总结');
        } catch (e) {
          _snack('全量总结失败: $e');
        }
        break;
      case 'resummarizeEntry':
        final rEntryId = data['entryId'] as String? ?? '';
        if (rEntryId.isEmpty) break;
        // LLM调用耗时较长，先发loading状态通知HTML（refresh:false不重渲染）
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

  // ── [浮窗化] STT 语音识别面板 ────────────────────────────────────────

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

  // ── [浮窗化] 导出/导入面板 ───────────────────────────────────────────

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

  // ── [浮窗化] 采样参数面板 ────────────────────────────────────────────

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

  // ── [浮窗化] 人设管理面板 ────────────────────────────────────────────

  Future<void> _openPersonaPanel() async {
    await ref.read(personaNotifierProvider.notifier).refresh();
    if (!mounted) return;
    _bridge.send(BridgeType.openSettingsPanel, {
      'panel': 'persona',
      'title': '人设管理',
      'data': _serializePersonaData(),
    });
  }

  /// 头像文件 → data URL（WebView loadData 无法加载 file://，转 base64 内联）
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

  // ── [浮窗化] 精灵图面板（占位配置） ──────────────────────────────────

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

  // ── [浮窗化] 预设&提示词面板 ─────────────────────────────────────────

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
        final tempDir = await getTemporaryDirectory();
        final file = File(
            '${tempDir.path}/${active.name}_${DateTime.now().millisecondsSinceEpoch}.json');
        await file.writeAsString(exportJson);
        await Share.shareXFiles([XFile(file.path)], subject: '预设导出');
        break;
    }
  }

  // ── [浮窗化] 世界书面板（三级导航） ──────────────────────────────────

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

  // ── [浮窗化] 生图设置面板 ────────────────────────────────────────────

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
      'apiKey': settings.apiKey ?? '',
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
          // [P1修复] 切换提供商后刷新面板,显示新提供商的API配置和模型
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
        notifier.setApiKey(data['key'] as String?);
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
        // [P1修复] 预设尺寸选择:解析"宽x高"字符串,同时设置宽高
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

  // ── [弹窗] HTML 弹窗辅助:确认框/输入框/底部选择框 ──────────────────────────
  // 弹窗与消息同渲染在 WebView 内,无 Flutter 图层叠加的 HC 合成开销,
  // 也免去 pause/resume(pause 会冻结卡片脚本)。结果经 dialogResult 按 callbackId 配对。

  Future<dynamic> _waitForDialogResult(String callbackId) {
    final completer = Completer<dynamic>();
    _dialogCompleters[callbackId] = completer;
    // [P0-8] 超时兜底:弹窗渲染失败/WebView 重建丢消息时 Completer 永久挂起,
    // 会把调用方(含 onLoadStop 注入链)一起挂死。30s 未回应按取消收场。
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _dialogCompleters.remove(callbackId);
        debugPrint('[弹窗超时] callbackId=$callbackId 等待超时30s，默认返回false');
        return false;
      },
    );
  }

  /// HTML 确认框。[cancelText] 传空串 = 单按钮提示框。
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

  /// HTML 输入弹窗。取消返回 null。
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

  /// HTML 底部选择框。取消返回 null,选中返回 value。
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

  // [顶栏精简] 三个点按钮已改+号菜单(走 func-overlay);本方法暂无入口,
  // 保留以防回滚——清空聊天/手动总结目前仅此处可达,后续可挂进 func-overlay。
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
    // [弹窗] HTML确认框,无需 pause/resume(弹窗与消息同在 WebView 内)
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
    // [弹窗] HTML确认框,无需 pause/resume
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

    // 先让用户选：分享，还是保存到文件（带参调用时跳过选择）
    // [弹窗] HTML底部选择框,无需 pause/resume
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

    // [CHRONICLE Phase 2] 注入Chronicle能力，导出内嵌kira_chronicle
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
      // [弹窗] 系统文件选择器结束即恢复 WebView:后续确认框改为 HTML,需要 WebView 存活
      await _controller?.resume();
      if (result == null) {
        _snack('未选择文件');
        return;
      }

      if (!mounted) return;

      // 确认弹窗：展示导入详情(HTML确认框,详情拼为多行文本)
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

      // 落库：显式传 widget.chatId，不依赖 state.chat
      final chatNotifier = ref.read(activeChatProvider.notifier);
      final uuid = const Uuid();
      final importedCount = await chatNotifier.importMessages(
        result.messages.map((m) => m.toChatMessage(widget.chatId, uuid.v4())).toList(),
        chatId: widget.chatId,
      );

      // [CHRONICLE Phase 2] 恢复内嵌的超级记忆
      if (result.chronicleData != null) {
        await exportService.restoreChronicleToChat(
            widget.chatId, result.chronicleData!);
      }

      // 更新作者注记
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
    // 文字和图片都没有才跳过
    if (content.isEmpty && attachments.isEmpty) return;
    final config = ref.read(llmConfigProvider);
    _inputController.clear();
    // 清空待发附件并刷新预览
    setState(() => _pendingAttachments.clear());
    _inputFocus.unfocus();
    // 图片不进 WebView（统一由独立图片界面管理），带不带图都走普通发送。
    // 触发 MVU initCheck（generation_started 在生成前点火）
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

  /// 把相册页选中的图片加入待发附件（不立即发送），
  /// 返回聊天后用户可继续打字，最后图文一起发送。
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
        setState(() {}); // 刷新输入框上方的待发预览
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

  /// 把选中图片的字节写入应用目录，构造 ChatAttachment。
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

  /// 把选中的图片复制到应用文档目录，构造 ChatAttachment。
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
      // 预热缓存：在后台 isolate 读文件转 base64，发送时直接用，不阻塞主线程
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

  /// 根据扩展名推断 MIME 类型。
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

  // ── 气泡操作按钮处理 ────────────────────────────────────────────────────────

  void _handleAction(Map<String, dynamic> payload) {
    final id = payload['id'] as String? ?? '';
    final action = payload['action'] as String? ?? '';
    // 图片全屏查看：早于 id/生成中 拦截，看图不受这些限制
    if (action == 'viewImage') {
      final attPath = payload['attPath'] as String? ?? '';
      if (attPath.isNotEmpty) _showFullImage(attPath);
      return;
    }
    // [闪屏修复] JS 定点更新失败(节点缺失/卡片消息) → 兜底全量重推
    if (action == 'needFullPush') {
      _pushMessages();
      return;
    }
    // [P5-9/P1] 脚本经 #send_but 触发的发送(狐神等):等价于用户在输入框点发送。
    // 无气泡 id,须在 id 判空拦截之前处理。
    if (action == 'sendFromStage') {
      final text = (payload['text'] as String? ?? '').trim();
      if (text.isEmpty) return;
      if (ref.read(activeChatProvider).isGenerating) return;
      final config = ref.read(llmConfigProvider);
      ref.read(activeChatProvider.notifier).sendMessage(text, config);
      return;
    }
    if (id.isEmpty) return;
    // 生成中禁止操作气泡按钮，避免与正在进行的生成冲突
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
        // 保留旧版本，生成一个新版本（新增 swipe）
        // [聊天页大改] 改 fire-and-forget 异步:regenerateMessage 是 Future,完成后提示
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
    speak(msgs[idx].content); // TTSService 内部会 _cleanTextForTTS 清洗
  }
  void _showFullImage(String encodedPath) {
    final path = Uri.decodeComponent(encodedPath);
    // 从文件名解析 msgId：ai_auto_{msgId}_{i}.png
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
                Navigator.of(context).pop(); // 关全屏
                final config = ref.read(llmConfigProvider);
                ref
                    .read(activeChatProvider.notifier)
                    .regenerateAutoImage(msgId!, config);
              },
      ),
    ));
  }
  /// 为指定消息生成配图：弹出生图对话框，生成后作为附件挂到该消息。
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
        // 存进会话专属子目录 chat_images/{chatId}/，与相册页统一
        final imagesDir = Directory(
            p.join(appDocDir.path, 'chat_images', widget.chatId));
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }

        for (int i = 0; i < result.images.length; i++) {
          final imageBytes = result.images[i];
          final imageId = const Uuid().v4();
          // ai_ 前缀，让相册页归入"AI生成"子页
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
  // 切换消息的回复版本（swipe）：delta 为 -1 上一版 / +1 下一版
  void _switchSwipe(String id, int delta) {
    final state = ref.read(activeChatProvider);
    final msg = state.messages.firstWhere(
      (m) => m.id == id,
      orElse: () => state.messages.first,
    );
    if (msg.swipes.length <= 1) return;
    final next = msg.currentSwipeIndex + delta;
    if (next < 0 || next >= msg.swipes.length) return; // 到头不循环
    ref.read(activeChatProvider.notifier).swipeMessage(id, next);
  }

  // ── 通用确认框（pause WebView 防合成开销）──────────────────────────────────

  Future<void> _confirmAndRun(
    String title,
    String body,
    VoidCallback action,
  ) async {
    // [弹窗] HTML确认框,无需 pause/resume
    final ok = await _showHtmlConfirm(title: title, message: body);
    if (!mounted) return;
    if (ok) action();
  }

  // ── 编辑（全屏页，避免 HC 合成开销）───────────────────────────────────────

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
      // [聊天页大改] 编辑保存:WebView 动态岛提示
      if (mounted) {
        _bridge.send(BridgeType.showToast, {'icon': '✏️', 'text': '消息已修改'});
      }
    }
  }

  // ── 删除确认 ───────────────────────────────────────────────────────────────

  Future<void> _showDeleteConfirm(String id) async {
    // [弹窗] HTML确认框(上一轮迁移遗漏,本轮补上),无需 pause/resume
    final ok = await _showHtmlConfirm(
      title: '删除消息',
      message: '确定删除这条消息吗？此操作无法撤销。',
      confirmText: '删除',
      cancelText: '取消',
      danger: true,
    );
    if (!mounted) return;
    if (ok) {
      // [闪屏修复] 不再显式全量 push:deleteMessage 改 state 后 ref.listen 会按变化类型
      // 分流(中间删除→结构变化全量重排楼层;尾部截断→定点摘除),显式再推一次等于双重清屏
      await ref.read(activeChatProvider.notifier).deleteMessage(id);
      // [聊天页大改] 删除完成:WebView 动态岛提示
      if (mounted) {
        _bridge.send(BridgeType.showToast, {'icon': '🗑️', 'text': '消息已删除'});
      }
    }
  }

  // ── 更多操作底部菜单 ───────────────────────────────────────────────────────

  Future<void> _showMoreSheet(String id) async {
    // [弹窗] HTML底部选择框,无需 pause/resume
    final result = await _showHtmlBottomSheet(const [
      {'text': '删除此条及之后所有', 'value': 'delete_after', 'danger': true},
    ]);
    if (!mounted || result == null) return;
    if (result == 'delete_after') {
      // [闪屏修复] 尾部截断由 ref.listen 走定点摘除(removeMessage),不再显式全量 push
      await ref
          .read(activeChatProvider.notifier)
          .deleteMessageAndAfter(id);
    }
  }

  // ── 翻译消息（LLM直译，结果显示在气泡下方浅色小字）────────────────────

  Future<void> _translateMessage(String id) async {
    if (_translatingIds.contains(id)) return;
    final messages = ref.read(activeChatProvider).messages;
    final idx = messages.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    final content = messages[idx].content.trim();
    if (content.isEmpty) return;

    _translatingIds.add(id);
    // 先推占位符，译文回来后覆盖
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
      // 失败：清掉占位符
      _bridge.send(BridgeType.setMessageTranslation, {'id': id, 'text': ''});
      showErrorSnackBar(context, '翻译失败：$e');
    } finally {
      _translatingIds.remove(id);
    }
  }

  // ── 推送消息到 WebView ────────────────────────────────────────────────────

  // 把单条消息序列化成Map，供_pushMessages使用
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
    // 剥离自动生图的 <image> 标签，只影响显示，不动已存原文
    rawContent = rawContent
        .replaceAll(RegExp(r'<image>[\s\S]*?</image>', caseSensitive: false), '')
        .trim();
    // [H1] afterRegexPrePeel = 2882 codeBlockMatch 剥壳之前的真实正则产物长度。
    // 旧 [WV-2] 的 afterRegex 打的是剥壳之后的值(afterRegex==afterUnwrap 恒成立)，等于没有观测。
    final afterRegexPrePeel = rawContent.length;
    final codeBlockMatch = RegExp(
      // [MD修复] 仅剥 ```html 围栏。原 [a-zA-Z]* 匹配任意语言:整条消息是单个
      // ```markdown/```text 围栏时(如AI讲解"脚本是什么"的全文)围栏被剥,
      // 内容里出现 <style/<script 等字样就会被 isRichHtml 判成 HTML 卡片塞进
      // iframe → 透明背景+黑字+空白折叠+markdown不渲染(排版全毁)。
      // 非 html 围栏应保留 → markdown 库渲染成 <pre><code> 代码块。
      r'^```html\s*\n([\s\S]*?)```\s*$',
      multiLine: false,
      caseSensitive: false,
    ).firstMatch(rawContent.trim());
    // [P3-K1-3] 剥壳收窄:仅当全消息 ```html 围栏数 ≤1 时才剥。
    // 多围栏消息剥壳会破坏 segs 配对(P3-H §2 实测);单围栏消息剥与不剥,
    // 下游 htmlFenceMatch/docStart 两条路径结果一致,保持兼容。
    final fenceCountPrePeel = RegExp(r'```html\s*\n', caseSensitive: false)
        .allMatches(rawContent)
        .length;
    if (codeBlockMatch != null && fenceCountPrePeel <= 1) {
      rawContent = codeBlockMatch.group(1) ?? rawContent;
    }
    final codeBlockPeeled = codeBlockMatch != null && fenceCountPrePeel <= 1;
    final processed = rawContent;
    // 若消息是"旁白文字 + 完整 HTML 文档"的混合体，以文档起点(<!DOCTYPE/<html)为界切开：
    // 旁白走 markdown 气泡，文档单独进 iframe，避免旁白被拖进 iframe 与卡片抢 flex 空间(挤成窄条)。
    // 优先识别 ```html 围栏：围栏前的文字走 markdown 当 prose，围栏内 HTML 走 iframe
    final htmlFenceMatch = RegExp(
      r'```html\s*\n([\s\S]*?)```',
      caseSensitive: false,
    ).firstMatch(processed);
    String proseHtml = '';
    String bodyForRender = processed;
    if (htmlFenceMatch != null) {
      final before = processed.substring(0, htmlFenceMatch.start).trim();
      if (before.isNotEmpty) {
        proseHtml = _highlightQuotes(md.markdownToHtml(
            before,
            extensionSet: md.ExtensionSet.gitHubWeb));
      }
      bodyForRender = htmlFenceMatch.group(1) ?? ''; // 围栏内的纯 HTML
    } else {
      // 无 ```html 围栏：走原有 <!DOCTYPE/<html 文档切分逻辑
      final docStart = RegExp(r'<!DOCTYPE|<html', caseSensitive: false)
          .firstMatch(processed);
      if (docStart != null && docStart.start > 0) {
        final prose = processed.substring(0, docStart.start).trim();
        if (prose.isNotEmpty) {
          proseHtml = _highlightQuotes(md.markdownToHtml(
              prose,
              extensionSet: md.ExtensionSet.gitHubWeb));
        }
        bodyForRender = processed.substring(docStart.start);
      }
    }
    // [MD修复2] 文档级判定替代子串级:正文提到 <script>/<body> 等字样的纯文本
    // 不再被误判为HTML卡片塞进iframe(排版全毁根因)
    final looksLikeHtml = _looksLikeHtmlDoc(bodyForRender);
    final rendered = looksLikeHtml
        ? normalizeCodeQuotes(bodyForRender)
        : _highlightQuotes(md.markdownToHtml(
            bodyForRender,
            extensionSet: md.ExtensionSet.gitHubWeb,
          ));
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
    // [H1] docCount: <!DOCTYPE|<html 出现次数(裸文档,无围栏)
    final docCount = RegExp(r'<!DOCTYPE|<html', caseSensitive: false)
        .allMatches(processed)
        .length;
    print('[WV-1] id=${m.id} role=${m.role.name} len=${m.content.length} '
        'script=$wvScript style=$wvStyle htmlTag=$wvHtmlTag '
        'fence=${htmlFenceMatch != null} fenceCount=${htmlFenceMatches.length} '
        'docCount=$docCount peeled=$codeBlockPeeled rich=$looksLikeHtml');
    // [WV-2] 各步骤长度轨迹(raw→regex→fenceUnwrap→split→render),定位转义/吞内容步。
    // afterRegex 改打剥壳(<codeBlockMatch>)之前的真实正则产物长度,否则与 afterUnwrap 恒等。
    print('[WV-2] id=${m.id} raw=${m.content.length} afterRegex=${afterRegexPrePeel} '
        'afterUnwrap=${processed.length} body=${bodyForRender.length} rendered=${rendered.length}');
    // [WV-3] segs 产出审计：产没产、几段、每段 type+长度；null 时给原因(禁止静默)。
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
    // [WV-4] 丢弃审计:真实被丢内容。铁律5落地——没它发现不了下一次静默丢弃。
    // - segs 模式:构造上逐字符覆盖 processed,丢 0(回归守卫)。
    // - 无 segs + 单围栏路径:围栏尾段(以及围栏标记)被静默丢弃 → droppedRaw=尾段长度+围栏标记开销。
    // - 无 segs + docStart 路径:bodyForRender 切到消息末尾,无丢弃。
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
      'prose': proseHtml, // 文档前的旁白文字，渲染层放在 iframe 之上
      'rich': looksLikeHtml, // [MD修复2] 显式告知 JS 走 iframe 还是气泡,替代 JS 侧二次猜测
      'html': rendered + attachmentsHtml,
      if (segs != null) 'segs': segs,
      'reasoning': m.currentReasoning ?? '',
      'swipeCount': m.swipes.length,
      'swipeIndex': m.currentSwipeIndex,
      'floor': i + 1,
      'isLatestAi': i == lastAiIndex,
    };
  }

  /// [WV-8] 单条序列化故障隔离：任何一条 _serializeMessage 抛错，
  /// 只降级为一条可见占位消息，绝不中断整批、绝不触发"全灭且零日志"。
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

  /// [WV-8] 批量序列化兜底：把一组 map 编码成 setMessages 的 base64 载荷。
  /// 批量 jsonEncode/utf8/base64 失败时降级为逐条 encode 逐条发（每条再单独 try），
  /// 绝不出现"整批静默不发、JS 侧一无所知"；逐条也全失败时发一条可见占位。
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

    // 降级：逐条 encode 逐条发
    var anySent = false;
    var firstSent = false;
    for (final m in list) {
      try {
        final b64 = base64Encode(utf8.encode(jsonEncode([m])));
        // [RC4] 只有第一条携带 initial/avatars:若逐条都带 initial,JS 每收一条就
        // root.innerHTML='' 清一次屏,降级跑完只剩最后一条。prepend 必须逐条保留
        // (每条都要头插,批内反转补偿才成立)。
        final flags = <String, dynamic>{
          if (prepend) 'prepend': true,
          if (initial && !firstSent) 'initial': true,
          if (avatars != null && !firstSent) 'avatars': avatars!,
        };
        _bridge.send(BridgeType.setMessages, {'data': b64, ...flags});
        firstSent = true;
        anySent = true;
      } catch (e2) {
        print('[WV-8] ITEM-ENCODE-FAIL id=${m['id']} err=$e2');
      }
    }

    // 逐条也全失败：发一条可见占位，避免空白无提示
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

  /// prev 是否为 next 的前缀（前 N 条 id 完全一致）
  bool _isPrefix(List<ChatMessage> prev, List<ChatMessage> next) {
    for (var i = 0; i < prev.length; i++) {
      if (prev[i].id != next[i].id) return false;
    }
    return true;
  }

  /// 只序列化并追加"末尾新增的那几条"，不清空整页，避免闪白/抖动
  Future<void> _appendNewMessages(
      int startFrom, List<ChatMessage> messages) async {
    final chatState = ref.read(activeChatProvider);
    final character = chatState.character;
    // [优化] 原先这里还 await persona(3s超时)但从未使用(追加模式不带头像/名字)——
    // 纯浪费的阻塞 await 已删。分析器报 unused_local_variable 即此。
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
    // 不带 initial / prepend → setMessages 走"追加渲染"分支
    await _sendEncodedMessages(list);
  }

  /// [闪屏修复] 尾部截断:把 prev 中已不存在的尾部消息从 DOM 摘掉,不整页重建。
  /// retry(删除后续重新生成)/删除此条及之后 都走这里,原先会落进全量 initial 重建 = 闪屏。
  void _removeMessagesTail(List<ChatMessage> prev, int keepCount) {
    if (keepCount >= prev.length) return;
    final ids = prev.sublist(keepCount).map((m) => m.id).toList();
    if (ids.isEmpty) return;
    _bridge.send(BridgeType.removeMessage, {'ids': ids});
  }

  /// [闪屏修复] 定点刷新最后一条消息:替代生成结束时的全量 _pushMessages。
  /// 把流式累积的纯文本换成正式 Markdown/HTML 渲染,只动这一个气泡。
  /// JS 侧节点缺失或内容是卡片(rich)时回 needFullPush,Dart 兜底全量重推。
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
    // 附件占位图走独立通道补图(html 里是 data-att-path 占位)
    _pushImages([msgs[lastIdx]]);
  }

  /// 定点刷新单条消息：编辑后只更新那一条DOM节点，不触发全量重建。
  /// rich卡片由JS侧回传needFullPush兜底全量重推。
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

  String _buildAttachmentsHtml(ChatMessage m) {
    if (m.attachments.isEmpty) return '';
    final buf = StringBuffer('<div class="att-wrap">');
    for (final att in m.attachments) {
      final encPath = Uri.encodeComponent(att.path);
      // 有宽高用真实比例，无（旧图）默认 1:1
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
    // [RC3] 代际递增:本次推送期间若又发生新推送,旧的补发循环按 epoch 作废
    _pushEpoch++;
    final epoch = _pushEpoch;
    debugPrint('[图片诊断] _pushMessages 开始执行 epoch=$epoch');
    final chatState = ref.read(activeChatProvider);
    final character = chatState.character;
    var persona = await ref.read(activePersonaProvider.future)
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

    // [优化] 首屏批量 30→50:一次 base64 载荷多带 20 条,少一轮补发往返
    const int batchSize = 50;
    final total = messages.length;
    // 初始只渲染最近batchSize条
    final startIndex = total > batchSize ? total - batchSize : 0;

    final initialList = <Map<String, dynamic>>[];
    for (var i = startIndex; i < total; i++) {
      initialList.add(_safeSerializeMessage(messages[i], i, lastAiIndex, character, scripts));
    }
    // 先发送最近的消息
    debugPrint('[图片诊断] _pushMessages 发送 setMessages, 条数=${initialList.length}');
    // 头像+名字：全局各一份，随首屏一次性下发（不进每条消息，避免膨胀拖卡）
    // [优化] persona 已在函数开头读过(带3s超时兜底),此处原第二次重复读取已删——
    // 同一 provider 重复 await 最坏白等 6s,且结果必然相同
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
    // [RC3] 序列化/头像期间可能已有更新的推送启动:过时的本轮直接让位,防双份 initial 清屏
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

    // 后台静默追加历史消息
    if (startIndex > 0) {
      // [优化] 启动延迟 100→50ms,批大小 20→30:补发整体提速约一半
      Future.delayed(const Duration(milliseconds: 50), () async {
        const int historyBatchSize = 30;
        // [RC1] 游标法覆盖 [0, startIndex) 全部楼层:原 for(start=startIndex-20; start>=0; start-=20)
        // 在 (total-30)%20≠0 时(如100条→startIndex=70)会漏掉最早的 (total-30)%20 条(floor 1-10),
        // 造成"顶部楼层永久缺失、滑上去消息消失"。
        var cursor = startIndex;
        while (cursor > 0) {
          // [RC3] 每批前检查代际:期间发生过新渲染,本循环立即作废(新推送自己会补发历史)
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
            // [P1-A4] JS 侧 prepend 逐条 insertBefore(root.firstChild) 是反向插入，
            // 升序发批会导致批内阅读顺序颠倒 → 发送侧用 batch.reversed 补偿。
            // 这是「补偿 JS 反向插入」的隐式耦合；P2 应改为 JS 侧用固定锚点插入、
            // Dart 保持自然升序，还这块解耦。
            await _sendEncodedMessages(batch.reversed.toList(), prepend: true);
            // [优化] 批间让出 16→8ms:仍防连续多批阻塞,节奏减半
            await Future.delayed(const Duration(milliseconds: 8));
          }
          cursor = batchStart;
        }
      });
    }

    // setMessages 之后，图片通过独立通道逐张推送（占位 img 已在 html 中）
    _pushImages(messages);
  }

  /// 把所有消息的图片附件逐张 base64 推给 WebView，按 data-att-path 匹配占位 img。
  /// 每张独立发送，setMessages payload 不再因图片膨胀，大图也不会撑爆传输。
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
          // 让出事件循环，避免连续多图一次性阻塞
          await Future.delayed(const Duration(milliseconds: 8));
        } catch (_) {
          // 单张失败跳过
        }
      }
    }
  }

  /// 给引号/括号包裹的对话内容加高亮span（符号连同内容一起染色）
  /// 引号类 → quote-q（主色A暖橙），括号类 → quote-p（主色B碧蓝）
  String _highlightQuotes(String html) {
    // 引号/方括号/书名号类：每种符号各自配对，符号+内容整体染
    final quotePattern = RegExp(
        r'“[^”\r\n]*”|「[^」\r\n]*」|『[^』\r\n]*』|【[^】\r\n]*】|《[^》\r\n]*》',
        dotAll: true);
    html = html.replaceAllMapped(quotePattern, (m) {
      return '<span class="quote-q">${m.group(0)}</span>';
    });
    // 圆括号类：中文圆括号、英文圆括号（符号+内容整体染）
    final parenPattern = RegExp(r'[（(][^（）()]*[）)]', dotAll: true);
    html = html.replaceAllMapped(parenPattern, (m) {
      return '<span class="quote-p">${m.group(0)}</span>';
    });
    return html;
  }

  /// Color转CSS十六进制字符串，供内联到webview样式变量
  String _colorToCss(Color c) =>
      '#${c.value.toRadixString(16).substring(2).padLeft(6, '0')}';
  // ── HTML 骨架 ─────────────────────────────────────────────────────────────

  String _chatStageErrorPage(String reason) {
    // 显性失败页:asset 缺失/读取异常让用户立刻看到"哪里坏了",而不是白屏。
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

  // [优化] _htmlShell 键控缓存:replaceAll 要扫 313KB×4,InAppWebView 只在创建时用
  // initialData,键盘显隐等 setState 重建 build 时是纯白算。键含 quote 颜色 + 顶栏 inset
  // (仅有的两个动态量),变了才重算,正确性与旧实现一致。
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
        // [顶栏] 初始内容起始位置直接烘进 HTML:WebView 全出血后首帧就要避开顶栏,
        // 不能等桥消息到达(会闪一下)
        .replaceAll('__KIRA_TOP_INSET__',
            (56 + MediaQuery.viewPaddingOf(context).top + 12).toStringAsFixed(1))
        .replaceAll('__KIRA_CHAT_BRIDGE__', bridge)
        // [优化] 调试扫描总开关(kDebugMode 烘入,生产默认关,见 chat_stage.html head)
        .replaceAll('__KIRA_DEBUG__', kDebugMode ? 'true' : 'false');
    _cachedHtmlShell = shell;
    _cachedHtmlShellKey = key;
    return shell;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  全屏编辑页：不透明全屏 = WebView 被完全遮住 = 无合成开销 = 120fps 丝滑
// ─────────────────────────────────────────────────────────────────────────────

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
      // [键盘] 固定布局:键盘 inset 逐帧变化不再重排 expands 字段,
      // 长按选择/复制工具栏不会被弹起的键盘打断(键盘鬼畜根因)
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
      // [鬼畜修复] 普通 Padding 直接跟随系统 viewInsets:AnimatedPadding 的 200ms
      // 动画会与系统键盘动画叠加,拖拽选择时每帧重排 expands 字段 → 选择手柄反复
      // 重定位 → haptic 连发 + 视觉抖动。
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
/// 圆形操作按钮：图标严格居中 + 按下态反馈 + 触觉。
/// 替代 IconButton.filled（其内部最小交互尺寸约束会把图标挤偏）。
class _CircleActionButton extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color foreground;
  final String tooltip;
  final VoidCallback? onTap;

  const _CircleActionButton({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.tooltip,
    this.onTap,
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
          // 按下时的水波纹 + 高亮，给明确点击反馈
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

/// 呼吸感的 ✨ 星星：亮一下暗一下，用于"正在生成图片"提示。
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
  final VoidCallback? onRegenerate; // 为 null 时不显示重新生成按钮
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

/// [MD修复2] HTML卡片判定(文档级证据):
/// a) 首个非空白字符是标签开始(<字母 或 <!),或
/// b) 内容以 <!DOCTYPE / <html 文档标记开头(docStart 分支裁剪后即如此)。
/// 旧子串级判定(<style|<script|<body 提及即真)会把"正文中讲到HTML标签的纯文本"
/// ——讲脚本教程的AI回复必然出现——整条塞进 iframe:透明bg+黑字+空白折叠+
/// markdown不渲染 → 排版全毁。非围栏的"前导文字+卡片"会退化为可读文本,
/// 属可接受代价;显式 ```html 围栏路径不受影响。
bool _looksLikeHtmlDoc(String s) {
  final t = s.trimLeft();
  return t.isNotEmpty && RegExp(r'^<[a-zA-Z!]').hasMatch(t);
}

/// 把代码位置的弯引号(智能引号)归一化为直引号。仅用于进 iframe 的 HTML 卡片：
/// 卡片作者/AI 常用中文弯引号,会破坏 JS 字符串定界(name:'x')与
/// HTML/SVG 属性定界(viewBox="0"),导致 SyntaxError / 属性截断 → 卡片崩溃。
/// 借鉴 RisuAI 渲染前归一化(仅阶段1)。正文走 markdown 气泡不经此处,
/// 弯引号原样保留、_highlightQuotes 染色不受影响。
/// 保留书名号《》与角引号「」『』(正文排版符,非代码定界符)。
///
/// [P3-D] 只在 <script>/<style> 块之外做替换,块内原样保留:
/// 旧实现全文本替换,把 JS 字符串字面量内部的弯引号也换成直引号
/// (如 desc:"“深蓝!”…" 被改成 desc:""深蓝!"…" → SyntaxError 整块脚本死亡)。
/// 块外(HTML 属性/正文/裸文本JS)保持原归一化行为。
/// 边界: <script> 未闭合 → 非贪婪匹配不命中 → 该段照旧归一化(与旧行为一致);
/// JS 字符串内的字面量 "</script>" 与浏览器解析行为一致地提前截断块,
/// 卡片本身已在字符串内写 <\/script> 转义,不受影响。
String normalizeCodeQuotes(String html) {
  // 全文替换：弯引号在JS里无论出现在何处都是非法的
  // 出现为字符串定界符时必须替换；出现在字符串内容里时替换为直引号对语义无害
  return html
      .replaceAll(RegExp('[\u2018\u2019\u201a\u201b]'), "'")
      .replaceAll(RegExp('[\u201c\u201d\u201e\u201f\uff02]'), '"')
      .replaceAll(RegExp('\u2026+'), '...');
}

/// [顶栏] 滑动显隐包装:Scaffold 布局位不变(extendBodyBehindAppBar 下 body 全出血,
/// WebView 几何零变化),仅视觉平移出屏;FractionalTranslation 的命中测试跟随位移,
/// 滑走后按钮不可误触。
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
/// [STT] 话筒按钮：长按开始录音（图标变红），松开识别并把结果填入输入框。
/// 短按不触发录音（长按语义），中途手势被夺走走 onCancel 丢弃。
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
/// [极客Core迁移 P5.3] 输入框旁的 token 计数徽标
/// 消费 tokenizerSettingsProvider.showTokenCount(此前未接线);
/// 监听输入框变化,仅重建自身,不逐键重建整个输入栏。
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
