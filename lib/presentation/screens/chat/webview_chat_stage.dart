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
import 'package:kirakira/presentation/screens/chat/chat_screen.dart' show chatExportServiceProvider;
import 'package:kirakira/presentation/providers/prompt_manager_providers.dart';
import 'package:kirakira/presentation/widgets/chat/context_usage_indicator.dart';
import '../../providers/quote_color_providers.dart';
import 'package:kirakira/presentation/providers/llm_configs_provider.dart';
import 'dart:io';
import 'package:kirakira/data/models/character.dart';
import 'package:kirakira/data/database/database.dart' as db;
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
import 'package:kirakira/data/models/world_info.dart' as models;
import 'package:image_picker/image_picker.dart';
import 'package:kirakira/presentation/screens/chat/image_picker_sheet.dart';
import 'package:kirakira/presentation/widgets/chat/image_generation_dialog.dart';
import 'package:kirakira/presentation/screens/chat/chat_images_screen.dart';
import 'package:kirakira/domain/services/image_generation_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:kirakira/presentation/widgets/common/character_avatar_image.dart';
import 'package:kirakira/core/utils/path_utils.dart';
import 'package:kirakira/presentation/providers/context_usage_providers.dart';
import 'package:image/image.dart' as img;
import 'package:kirakira/presentation/providers/tts_providers.dart';
import 'package:kirakira/domain/services/llm_service.dart';
import 'package:kirakira/presentation/providers/mvu_settings_providers.dart';
import 'package:kirakira/domain/services/debug_log_service.dart';
import 'package:kirakira/presentation/widgets/snackbar_utils.dart';
import 'package:kirakira/presentation/screens/chat/th_popup_dialog.dart';
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
      allowed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: Text('此内容包含 ${enabledScripts.length} 个脚本'),
        content: Text('$names\n\n是否允许运行？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('拒绝')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('允许')),
        ],
      )) ?? false;
      await prefs.setBool(authKey, allowed);
      if (!allowed) KiraLogger().info('预设脚本', '用户拒绝，脚本不执行');
    }
    if (allowed != true) enabledScripts.clear();
    // [P5-14] 狐神 getPreset 自激环修复(诊断见 DiaoYan/P5/P5-13_狐神超时刷屏诊断.md)。
    // 根因: 狐神按同步语义读 _TH.getPreset(平台门面返回 Promise),
    //   isStreamingEnabled / restoreInlineMediaOption 永远读到 undefined
    //   → 判定"偏离偏好" → setPreset → Dart 无条件回发 preset_changed/settings_updated
    //   → 事件监听器再读再写 → 无限自激(th timeout: th_getPreset 刷屏)。
    // 修复: 注入前把这 2 个读点改为读 __KIRA_PRESET_CACHE 同步镜像(P5-12 JS 侧缓存):
    //   1) isStreamingEnabled: 缓存命中读 should_stream;未命中返回 false(与旧行为一致)。
    //      首次 setStreaming 成功后 updatePresetWith 收尾的 getPreset 会回填缓存,
    //      后续事件回调(+300~1000ms)读到 true === 偏好 → 不再写 → 环自然熄火。
    //   2) restoreInlineMediaOption: 缓存未就绪直接跳过。它在 settings_updated 监听器里
    //      被同步调用,此刻缓存必刚被事件清空 —— 若仍按 undefined 误判并写回,环永不熄火;
    //      跳过后其写回只发生在缓存就绪窗口,收敛。
    // 仅按脚本名命中狐神,其余脚本原样注入;不改脚本源文件,仅注入时内存 patch,可逆。
    final patchedScripts = enabledScripts.map<Map<String, dynamic>>((s) {
      final name = s['name']?.toString() ?? '';
      if (!name.contains('狐神') && !name.contains('玄狐')) return s;
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
        debugPrint('[P5-14] 警告: 狐神脚本"$name"patch 未命中任何目标,可能版本不匹配');
        return s;
      }
      debugPrint('[P5-14] 狐神patch完成: isStreamingEnabled×$hit1, '
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _loadChatStageAssets();
      await _loadCompatLibs();
      await _loadMvuBundle();
      await _loadEjsStub();
      await _loadEjsBundle();
      if (!mounted) return;
      // [P5-7B] 等 loadChat 真正完成,确保 character 数据就绪后再挂 WebView
      await ref.read(activeChatProvider.notifier).loadChat(widget.chatId);
      // 延迟挂载 WebView:让入场这段时间保持纯 Flutter(无 WebView 重活),动画/遮罩流畅
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      setState(() => _webViewMounted = true);
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
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) return;
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
  }

  /// [顶栏] 显隐切换(仅状态跳变时 setState,滚动事件本身在 JS 侧已收敛)
  void _setTopBarVisible(bool visible) {
    if (!mounted || _topBarVisible == visible) return;
    setState(() => _topBarVisible = visible);
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
  }

  @override
  void dispose() {
    // 清空 EJS 渲染函数登记(离开聊天页,回到安全态)
    try {
      ref.read(ejsRenderRegistryProvider).clear();
    } catch (_) {}
    _controller?.evaluateJavascript(
        source: 'if(window.resetEngineRoom){var h=document.getElementById("__engineRoomHost");if(h)h.innerHTML="";}');
    WidgetsBinding.instance.removeObserver(this);
    _maskController.dispose();
    _inputController.dispose();
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

      // 结构变化（增删消息 / 换聊天）→ 全量重渲染
      final sameStructure = prevMsgs.length == nextMsgs.length &&
          (nextMsgs.isEmpty || prevMsgs.last.id == nextMsgs.last.id);

      if (isPureAppend) {
        _appendNewMessages(prevMsgs.length, nextMsgs);
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
          _pushMessages();
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
      }
      if (_wasGenerating && !gen) {
        _pushMessages();
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
        final msg = err == '收到空回复'
            ? '收到空回复'
            : '生成失败，请检查网络或 API 配置';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
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
    final activeLlmConfig = ref.watch(llmConfigsProvider).active;
    final isGenerating = ref.watch(
      activeChatProvider.select((s) => s.isGenerating),
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _controller?.pause();
        // 遮罩瞬间盖满(不用 forward 淡入——半透明×WebView 合成会卡)
        _maskController.value = 1.0;
        // 先把 WebView 从树上卸载,消除 pop 切页时的残影闪烁
        if (mounted) setState(() => _webViewMounted = false);
        // 等一帧,确保 WebView 真正移除、遮罩已盖稳
        await Future.delayed(const Duration(milliseconds: 32));
        if (mounted) context.pop();
      },
      child: Stack(
      children: [
        Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: activeGlassPalette.pageBackground,
      extendBodyBehindAppBar: true,
      appBar: _SlidingAppBar(
        visible: _topBarVisible,
        child: _buildGlassAppBar(character, activeLlmConfig),
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
                    top: 32 + MediaQuery.of(context).padding.top, // [顶栏] 48→32
                    // 底部留出输入栏基础高度：让最后一条消息的工具栏/楼层露在输入栏上方，
                    // 不被浮层遮住。固定值（不含面板/附件），避免动态变化触发 WebView resize。
                    bottom: 64 + MediaQuery.of(context).padding.bottom,
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
                    // [顶栏] 页面(重)载完成(含崩溃自愈 loadData 重建)重置为显示
                    _setTopBarVisible(true);
                    await _injectCompatLibs(c); // 注入第三方库到外层window
                    await _injectMacroValues(c); // 注入宏替换用的角色名/用户名
                    await _injectRegexRules(c); // [P6-5.2] 正则规则快照(引擎房烘焙用)
                    await _injectMainEnv(c); // [P5-6阶段2.1] 注入主环境快照(主文档ST骨架读)
                     await _injectEngineFacade(c); // 注入引擎房共享门面
                     await _injectPresetScripts(c);
                     await _injectMvuBundle(c);
      await _injectEjsStub(c);
      await _injectEjsBundle(c); // 注入 EJS bundle 供引擎房内联
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
                          _pickImages();
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
                        case 'navigateTo':
                          final route = payload['route'] as String? ?? '';
                          if (route.isNotEmpty) await _navigateTo(route);
                          break;
                      }
                    });
                    await Future.delayed(const Duration(milliseconds: 350));
                    if (!mounted) return;
                    await _pushMessages();
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
                    await Future.delayed(const Duration(milliseconds: 500));
                    if (mounted) _maskController.reverse();
                  },
                )
                      : const SizedBox.shrink(),
                ),
                ),
              // 底部浮层：功能面板 + 输入栏，bottom 锚定。
              // 面板展开往上盖住 WebView 内容，WebView 尺寸恒定、永不 resize —— 彻底消除展开/收起顿卡。
              // [A1] AnimatedPadding 顺滑化:键盘弹/收不再硬跳
              Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.only(
                    bottom: _keyboardVisible ? _keyboardHeight : 0,
                  ),
                  child: _buildInputBar(isGenerating),
                ),
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
                : -(32 + MediaQuery.of(context).padding.top),
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              child: Container(
                height: 32 + MediaQuery.of(context).padding.top, // [顶栏] 48→32
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
    if (name.length <= 5) return name;
    return '${name.substring(0, 5)}…';
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

  Future<dynamic> _handleToast(Map<String, dynamic> payload) async {
    final level = payload['level']?.toString() ?? 'info';
    final message = payload['message']?.toString() ?? '';
    if (message.isEmpty || !mounted) return {'ok': true};
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

  /// [P6-5.1] callGenericPopup 桥:TEXT/CONFIRM/INPUT/DISPLAY → Flutter Dialog。
  /// payload: {text, type(1/2/3/4), inputValue}
  /// 返回:CONFIRM → 1/0(取消 null);INPUT → 字符串(取消 null);TEXT/DISPLAY → 1。
  Future<dynamic> _handlePopup(Map<String, dynamic> payload) async {
    final text = payload['text']?.toString() ?? '';
    final type = (payload['type'] as num?)?.toInt() ?? 1;
    final inputValue = payload['inputValue']?.toString() ?? '';
    if (!mounted) return null;
    KiraLogger().info('卡片弹窗', 'type=$type text=${text.length}字');
    final result = await showDialog<dynamic>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ThPopupDialog(
        text: text,
        type: type,
        inputValue: inputValue,
      ),
    );
    return result;
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
      // [P6-5.1] /buttons:按钮选择弹窗,选中项回管道
      showButtons: (labels) async {
        if (!mounted) return null;
        final result = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final label in labels)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: SizedBox(
                        width: double.maxFinite,
                        child: FilledButton.tonal(
                          onPressed: () => Navigator.of(ctx).pop(label),
                          child: Text(label),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
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
      Character? character, dynamic activeLlmConfig) {
    return AppBar(
      toolbarHeight: 32, // [顶栏] 48→32:缩小1/3
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Colors.transparent, // 背景交给 body 里的毛玻璃层
      titleSpacing: 12,
      // flexibleSpace 在此 AppBar 中不渲染,已放弃,毛玻璃改由 body 顶部独立层实现
      title: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openModelSheet(),
        child: Row(
          children: [
            _buildAvatar(character),
            const SizedBox(width: 10),
            // [顶栏] 单行标题:32dp 放不下双行,模型信息改由点击标题弹模型层查看
            Expanded(
              child: Text(
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
            tooltip: '会话图片',
            iconSize: 16,
            color: activeGlassPalette.primaryText,
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ChatImagesScreen(chatId: widget.chatId),
              ));
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openModelSheet() async {
    final config = ref.read(llmConfigProvider);
    await ref.read(modelFetchProvider.notifier).fetchModels(config);
    if (!mounted) return;
    final state = ref.read(modelFetchProvider);
    if (state.status == ModelFetchStatus.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.errorMessage ?? '获取模型失败')),
      );
      return;
    }
    final configsState = ref.read(llmConfigsProvider);
    _bridge.send(BridgeType.showModelSheet, {
      'models': state.models,
      'current': config.model,
      'configs': configsState.configs
          .map((c) => {'id': c.id, 'name': c.name, 'active': c.isDefault})
          .toList(),
    });
  }

  // ── 底部输入栏 ──────────────────────────────────────────────────────────────

  Widget _buildInputBar(bool isGenerating) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 待发图片预览条：纯 Flutter，不碰 WebView
          if (_pendingAttachments.isNotEmpty)
            Container(
              height: 76,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              alignment: Alignment.centerLeft,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _pendingAttachments.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final att = _pendingAttachments[i];
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                        child: Image.file(
                          File(att.path),
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: -6,
                        top: -6,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _pendingAttachments.removeAt(i)),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          // 输入行：半透明深色胶囊
          Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: activeGlassPalette.glassTint.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20), // [A1] 输入框圆角:20px(比气泡14px更圆润,接近iOS Messages)
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () {
                    if (_funcPanelOpen) {
                      _bridge.send(BridgeType.closeFunctionPanel, {});
                      setState(() => _funcPanelOpen = false);
                      return;
                    }
                    final usage = ref.read(contextUsageProvider);
                    final charId =
                        ref.read(activeChatProvider).character?.id ?? '';
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
                  },
                  icon: Icon(_funcPanelOpen
                      ? Icons.close_rounded
                      : Icons.add_rounded),
                  color: activeGlassPalette.secondaryText,
                ),
                Expanded(
                  // [A1] Shift+Enter=发送,Enter=换行(硬件键盘;手机软键盘回车即换行,发送走右侧按钮)。
                  // CallbackShortcuts 挂在焦点链上,无需额外 FocusNode。
                  child: CallbackShortcuts(
                    bindings: <ShortcutActivator, VoidCallback>{
                      const SingleActivator(LogicalKeyboardKey.enter, shift: true):
                          _sendMessage,
                    },
                    child: TextField(
                      controller: _inputController,
                      enabled: !isGenerating,
                      focusNode: _inputFocus,
                      maxLines: 5,
                      minLines: 1,
                      // [A1] send→newline:回车不再发送,改为插入换行
                      textInputAction: TextInputAction.newline,
                      onEditingComplete: () {
                        // 吞掉默认"完成编辑"行为(防意外失焦),换行交给 newline action
                      },
                      style: TextStyle(color: activeGlassPalette.primaryText),
                      cursorColor: activeGlassPalette.accent,
                      decoration: InputDecoration(
                        hintText: '输入消息…（Enter 换行，Shift+Enter 发送）',
                        hintStyle: TextStyle(
                          color: activeGlassPalette.secondaryText
                              .withValues(alpha: 0.7),
                        ),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                if (isGenerating)
                  _CircleActionButton(
                    icon: Icons.stop_rounded,
                    background: const Color(0xFFE5484D), // 生成中：红色停止
                    foreground: Colors.white,
                    tooltip: '停止生成',
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      ref
                          .read(activeChatProvider.notifier)
                          .cancelGeneration();
                    },
                  )
                else
                  _CircleActionButton(
                    icon: Icons.arrow_upward_rounded,
                    background: activeGlassPalette.accent,
                    foreground: const Color(0xFF06111A),
                    tooltip: '发送',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _sendMessage();
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
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

  Future<void> _confirmClearChat() async {
    await _controller?.pause();
    bool? ok;
    try {
      ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('清空聊天'),
          content: const Text('将删除本对话的全部消息，且不可恢复。确定吗？'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('清空', style: TextStyle(color: Colors.red))),
          ],
        ),
      );
    } finally {
      await _controller?.resume();
    }
    if (ok == true) {
      ref.read(activeChatProvider.notifier).clearChat();
      await _pushMessages();
    }
  }

  Future<void> _confirmManualSummarize() async {
    await _controller?.pause();
    bool? ok;
    try {
      ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('手动总结上下文'),
          content: const Text('将基于当前全部历史重新生成一份总结，覆盖已有总结。适合自动总结失败或效果不佳时使用。可能耗时并消耗较多 token，确定吗？'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('开始总结')),
          ],
        ),
      );
    } finally {
      await _controller?.resume();
    }
    if (ok == true) {
      _snack('正在总结上下文…');
      final err = await ref.read(activeChatProvider.notifier).manualSummarize();
      _snack(err ?? '总结完成');
    }
  }

  Future<void> _exportChatRecord() async {
    final chatState = ref.read(activeChatProvider);
    if (chatState.chat == null || chatState.character == null) {
      _snack('当前聊天无法导出');
      return;
    }
    final userName =
        ref.read(activePersonaProvider).valueOrNull?.name ?? 'User';

    // 先让用户选：分享，还是保存到文件
    await _controller?.pause();
    String? mode;
    try {
      mode = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('导出聊天'),
          content: const Text('选择导出方式（SillyTavern 兼容 JSONL）'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, 'share'),
                child: const Text('分享')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, 'file'),
                child: const Text('保存到文件')),
          ],
        ),
      );
    } finally {
      await _controller?.resume();
    }
    if (mode == null) return;

    final service = ChatExportService();
    try {
      if (mode == 'share') {
        await service.exportAndShare(
          chatState.chat!,
          chatState.messages,
          chatState.character!,
          userName: userName,
          useJsonl: true,
        );
      } else {
        final path = await service.exportToFile(
          chatState.chat!,
          chatState.messages,
          chatState.character!,
          userName: userName,
          useJsonl: true,
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
      if (result == null) {
        _snack('未选择文件');
        await _controller?.resume();
        return;
      }

      if (!mounted) return;

      // 确认弹窗：展示导入详情
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.importConfirmation),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${l10n.character}: ${result.characterName}'),
              Text('${l10n.user}: ${result.userName}'),
              Text('${l10n.messages}: ${result.messages.length}'),
              Text('${l10n.date}: ${result.createDate.toString().split('.')[0]}'),
              if (result.authorNote != null && result.authorNote!.isNotEmpty)
                Text('${l10n.hasAuthorsNote}: ${l10n.yes}'),
              const SizedBox(height: 16),
              Text(
                l10n.importMessagesToCurrentChat,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.import),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        await _controller?.resume();
        return;
      }

      // 落库：显式传 widget.chatId，不依赖 state.chat
      final chatNotifier = ref.read(activeChatProvider.notifier);
      final uuid = const Uuid();
      final importedCount = await chatNotifier.importMessages(
        result.messages.map((m) => m.toChatMessage(widget.chatId, uuid.v4())).toList(),
        chatId: widget.chatId,
      );

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
          () => notifier.retryMessage(id, config),
        );
        break;
      case 'reroll':
        // 保留旧版本，生成一个新版本（新增 swipe）
        notifier.regenerateMessage(id, config);
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
    await _controller?.pause();
    bool? ok;
    try {
      ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    } finally {
      await _controller?.resume();
    }
    if (ok == true) action();
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
      await _pushMessages();
    }
  }

  // ── 删除确认 ───────────────────────────────────────────────────────────────

  Future<void> _showDeleteConfirm(String id) async {
    await _controller?.pause();
    bool? ok;
    try {
      ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('删除消息'),
          content: const Text('确定删除这条消息吗？此操作不可撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除',
                  style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    } finally {
      await _controller?.resume();
    }
    if (ok == true) {
      await ref.read(activeChatProvider.notifier).deleteMessage(id);
      await _pushMessages();
    }
  }

  // ── 更多操作底部菜单 ───────────────────────────────────────────────────────

  void _showMoreSheet(String id) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.delete_sweep),
              title: const Text('删除此条及之后所有'),
              onTap: () async {
                Navigator.pop(ctx);
                await ref
                    .read(activeChatProvider.notifier)
                    .deleteMessageAndAfter(id);
                await _pushMessages();
              },
            ),
          ],
        ),
      ),
    );
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
      r'^```[a-zA-Z]*\n([\s\S]*?)```\s*$',
      multiLine: false,
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
    final looksLikeHtml = RegExp(
      r'<style|<script|<!DOCTYPE|<html|<head|<body',
      caseSensitive: false,
    ).hasMatch(bodyForRender);
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
        final rich = RegExp(
          r'<style|<script|<!DOCTYPE|<html|<head|<body',
          caseSensitive: false,
        ).hasMatch(body);
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
      'prose': proseHtml, // 文档前的旁白文字，渲染层放在 iframe 之上
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
    dynamic persona;
    try {
      persona = await ref.read(activePersonaProvider.future)
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('[卡点] activePersona 超时/出错: $e');
      persona = null;
    }
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

    const int batchSize = 30;
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
    try {
      persona = await ref.read(activePersonaProvider.future)
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('[卡点] activePersona2 超时/出错: $e');
    }
    String? charUri;
    String? userUri;
    try {
      charUri = await _avatarToDataUri(character?.assets?.avatarPath, false)
          .timeout(const Duration(seconds: 3));
      userUri = await _avatarToDataUri(persona?.avatarPath, true)
          .timeout(const Duration(seconds: 3));
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
      Future.delayed(const Duration(milliseconds: 100), () async {
        const int historyBatchSize = 20;
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
            await Future.delayed(const Duration(milliseconds: 16));
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

  String _htmlShell() {
    final html = _chatStageHtml;
    final bridge = _chatBridgeJs;
    if (html == null || bridge == null) {
      return _chatStageErrorPage('缺少聊天壳资源(_chatStageHtml / _chatBridgeJs 为空)');
    }
    return html
        .replaceAll('__KIRA_QUOTE_Q_COLOR__', _colorToCss(ref.watch(quoteColorStateProvider).primaryA))
        .replaceAll('__KIRA_QUOTE_P_COLOR__', _colorToCss(ref.watch(quoteColorStateProvider).primaryB))
        .replaceAll('__KIRA_CHAT_BRIDGE__', bridge);
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
      body: Padding(
        padding: const EdgeInsets.all(16),
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
  final VoidCallback onTap;

  const _CircleActionButton({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.tooltip,
    required this.onTap,
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
  String norm(String s) => s
      .replaceAll(RegExp('[‘’‚‛]'), "'")
      .replaceAll(RegExp('[“”„‟＂]'), '"')
      .replaceAll(RegExp('…+'), '...');
  final blocks = RegExp(
    r'<script[^>]*>[\s\S]*?</script>|<style[^>]*>[\s\S]*?</style>',
    caseSensitive: false,
  ).allMatches(html);
  final buf = StringBuffer();
  var last = 0;
  for (final m in blocks) {
    buf.write(norm(html.substring(last, m.start)));
    buf.write(html.substring(m.start, m.end));
    last = m.end;
  }
  buf.write(norm(html.substring(last)));
  return buf.toString();
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