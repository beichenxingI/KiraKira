import 'dart:convert';
import 'dart:ui';
import '../../widgets/common/glass_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:kirakira/presentation/providers/chat_providers.dart';
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
import 'package:kirakira/presentation/widgets/chat/context_usage_indicator.dart';
import '../../providers/quote_color_providers.dart';
import 'package:kirakira/presentation/providers/llm_configs_provider.dart';
import 'dart:io';
import 'package:kirakira/data/models/character.dart';
import 'package:kirakira/data/database/database.dart' as db;
import 'package:flutter/foundation.dart';
import 'package:kirakira/presentation/widgets/chat/chat_background_widget.dart';
import 'package:kirakira/core/logger/logger.dart';
import 'package:flutter/gestures.dart';
import 'package:kirakira/domain/services/variables_service.dart';
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

/// compute 用的顶层函数：在独立 isolate 读文件并返回 base64 字符串。
String _readFileAsB64(String path) {
  return base64Encode(File(path).readAsBytesSync());
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
  InAppWebViewController? _controller;
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
  late final Animation<double> _maskAnim = CurvedAnimation(parent: _maskController, curve: Curves.easeInOut);

  // 第三方库缓存（jQuery/lodash/toastr），全类共享，只读一次
  static String? _jqueryB64;
  static String? _lodashB64;
  static String? _toastrJsB64;
  static String? _toastrCssB64;
  static bool _libsLoaded = false;

  /// 加载并缓存第三方库（base64 编码，供内联注入）。只在首次调用时真正读取。
  static Future<void> _loadCompatLibs() async {
    if (_libsLoaded) return;
    try {
      final jquery = await rootBundle.loadString('assets/libs/jquery.min.js');
      final lodash = await rootBundle.loadString('assets/libs/lodash.min.js');
      final toastrJs = await rootBundle.loadString('assets/libs/toastr.min.js');
      final toastrCss = await rootBundle.loadString('assets/libs/toastr.min.css');
      _jqueryB64 = base64Encode(utf8.encode(jquery));
      _lodashB64 = base64Encode(utf8.encode(lodash));
      _toastrJsB64 = base64Encode(utf8.encode(toastrJs));
      _toastrCssB64 = base64Encode(utf8.encode(toastrCss));
      _libsLoaded = true;
    } catch (e) {
      // 加载失败不阻断聊天，仅记录
      KiraLogger().info('兼容库', '第三方库加载失败: $e');
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
        'toastrCss:"${_toastrCssB64 ?? ''}"'
        '};';
    try {
      await c.evaluateJavascript(source: js);
    } catch (e) {
      KiraLogger().info('兼容库', '库注入失败: $e');
    }
  }

  double _keyboardHeight = 0;
  bool _keyboardVisible = false;
  bool _funcPanelOpen = false;

   @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _maskController.value = 1.0;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _loadCompatLibs();
      if (!mounted) return;
      ref.read(activeChatProvider.notifier).loadChat(widget.chatId);
      // 延迟挂载 WebView:让入场这段时间保持纯 Flutter(无 WebView 重活),动画/遮罩流畅
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      setState(() => _webViewMounted = true);
    });
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
    }
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _maskController.dispose();
    _inputController.dispose();
    _inputFocus.dispose();
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
      if (_wasGenerating && !gen) {
        _pushMessages();
      }
      _wasGenerating = gen;

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
      appBar: _buildGlassAppBar(character, activeLlmConfig),
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
                    top: 48 + MediaQuery.of(context).padding.top,
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
                    baseUrl: WebUri('about:blank'),
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
                  onWebViewCreated: (c) {
                    _controller = c;
                    _bridge.attach(c);
                    _bridge.on(BridgeType.action, _handleAction);
                    _bridge.on(BridgeType.log, (payload) {
                      debugPrint('[卡片日志] ${payload['text']}');
                    });
                    // 酒馆助手 API：读取当前会话消息（请求-响应）
                    _bridge.onRequest('th_getMessages', _handleGetMessages);
                    _bridge.onRequest('th_triggerSlash', _handleTriggerSlash);
                    _bridge.onRequest('th_setMessage', _handleSetMessage);
                    _bridge.onRequest('th_getVars', _handleGetVariables);
                    _bridge.onRequest('th_setVars', _handleSetVariables);
                    // 世界书 API
                    _bridge.onRequest('th_wiGetLorebooks', _handleWiGetLorebooks);
                    _bridge.onRequest('th_wiCreateBook', _handleWiCreateBook);
                    _bridge.onRequest('th_wiGetEntries', _handleWiGetEntries);
                    _bridge.onRequest('th_wiSetEntries', _handleWiSetEntries);
                    _bridge.onRequest('th_wiCreateEntries', _handleWiCreateEntries);
                    _bridge.onRequest('th_wiDeleteEntries', _handleWiDeleteEntries);
                    _bridge.onRequest('th_wiGetCharLorebooks', _handleWiGetCharLorebooks);
                  },
                  onLoadStop: (c, url) async {
                    await _injectCompatLibs(c); // 注入第三方库到外层window
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
                    await Future.delayed(const Duration(milliseconds: 500));
                    if (mounted) _maskController.reverse();
                  },
                )
                      : const SizedBox.shrink(),
                ),
                ),
              // 底部浮层：功能面板 + 输入栏，bottom 锚定。
              // 面板展开往上盖住 WebView 内容，WebView 尺寸恒定、永不 resize —— 彻底消除展开/收起顿卡。
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
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
          Positioned(
            top: 0, left: 0, right: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              child: Container(
                height: 48 + MediaQuery.of(context).padding.top,
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
                        fontSize: 15,
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

  /// 酒馆助手 triggerSlash：精简版 STscript 执行器。
  /// 支持管道 `|` 串联，覆盖开局类卡片高频命令：
  ///   /send <text> · /sys <text>  → 发一条消息并触发 AI 生成
  ///   /trigger                    → 触发 AI 生成（若前面已发消息则跳过，避免重复）
  ///   /cut <id>                   → 稳妥起见做 noop（不删用户消息，保护数据）
  /// 其余命令忽略但不报错，保证卡片脚本不中断。
  Future<dynamic> _handleTriggerSlash(Map<String, dynamic> payload) async {
    final command = (payload['command'] as String?) ?? '';
    if (command.trim().isEmpty) return {'ok': true};
    KiraLogger().info('助手API', 'th_triggerSlash 收到命令');

    final config = ref.read(llmConfigProvider);
    final notifier = ref.read(activeChatProvider.notifier);

    // 按管道分段
    final segments = command.split('|');
    String? pendingText; // 待发送的消息文本
    var wantTrigger = false;

    for (final rawSeg in segments) {
      final seg = rawSeg.trim();
      if (seg.isEmpty) continue;

      if (seg.startsWith('/send') || seg.startsWith('/sys')) {
        // 取命令后的正文
        final firstSpace = seg.indexOf(' ');
        final text = firstSpace >= 0 ? seg.substring(firstSpace + 1).trim() : '';
        if (text.isNotEmpty) {
          pendingText = (pendingText == null) ? text : '$pendingText\n$text';
        }
      } else if (seg.startsWith('/trigger')) {
        wantTrigger = true;
      } else if (seg.startsWith('/cut')) {
        // 稳妥起见：不删除用户消息，仅记录
        KiraLogger().info('助手API', '/cut 已忽略（保护数据）');
      } else {
        KiraLogger().info('助手API', '未实现的命令，已忽略: $seg');
      }
    }

    // 有待发文本：sendMessage 会自动触发生成，一步到位
    if (pendingText != null && pendingText.trim().isNotEmpty) {
      await notifier.sendMessage(pendingText, config);
      return {'ok': true, 'sent': true};
    }

    // 无文本但要求 /trigger：单独触发一次生成（重发最后的AI回复）
    if (wantTrigger) {
      await notifier.regenerateLastMessage(config);
      return {'ok': true, 'triggered': true};
    }

    return {'ok': true};
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
        'is_hidden': false, // ChatMessage 无隐藏字段，固定 false
        'message': currentContent,
        'data': <String, dynamic>{},
        'extra': <String, dynamic>{},
        // 兼容旧字段（避免已依赖旧格式的地方炸）
        'id': m.id,
        'index': i,
        'is_user': m.role == MessageRole.user,
        'content': m.content,
        'swipe_id': swipeId,
      };
      if (includeSwipe) {
        // 对齐 ChatMessageSwiped 规格
        map['swipes'] = swipes;
        map['swipes_data'] =
            List.generate(swipes.length, (_) => <String, dynamic>{});
        map['swipes_info'] =
            List.generate(swipes.length, (_) => <String, dynamic>{});
      }
      result.add(map);
    }
    KiraLogger().info('助手API', 'th_getMessages 返回 ${result.length} 条');
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
    // 默认 chat 局部变量
    return service.getAllLocalVariables(widget.chatId);
  }

  /// 酒馆助手 setVariables：按 scope 写入变量表并持久化。
  /// 语义：把传入的 vars 逐 key 写入（insertOrAssign），不整表替换。
  Future<dynamic> _handleSetVariables(Map<String, dynamic> payload) async {
    final vars = (payload['vars'] as Map?)?.cast<String, dynamic>() ?? {};
    final option = (payload['option'] as Map?)?.cast<String, dynamic>() ?? {};
    final type = (option['type'] as String?) ?? 'chat';
    final service = VariablesService.instance;
    KiraLogger().info('助手API', 'th_setVars 被调用 type=$type keys=${vars.keys.toList()}');

    if (type == 'global') {
      for (final entry in vars.entries) {
        await service.setGlobalVariable(entry.key, entry.value);
      }
      return service.getAllGlobalVariables();
    }
    // 默认 chat 局部变量：写内存 + 落盘持久化
    for (final entry in vars.entries) {
      service.setLocalVariable(widget.chatId, entry.key, entry.value);
    }
    await service.saveLocalVariablesToPrefs(widget.chatId);
    return service.getAllLocalVariables(widget.chatId);
  }

  // ── 世界书 API handlers ─────────────────────────────
  // 把 WorldInfoEntry 序列化成卡片侧（SillyTavern 风格）的 JSON
  Map<String, dynamic> _wiEntryToJson(models.WorldInfoEntry e) => {
        'uid': e.id,
        'worldId': e.worldInfoId,
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
    final WorldInfoRepository repo = ref.read(worldInfoRepositoryProvider);
    final all = await repo.getAllWorldInfos();
    return all.map((b) => b.name).toList();
  }

  /// 新建一本世界书（SillyTavern createLorebook）。payload: {name}
  Future<dynamic> _handleWiCreateBook(Map<String, dynamic> payload) async {
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

  /// 取某本世界书的所有条目。payload: {name} 或 {id}
  Future<dynamic> _handleWiGetEntries(Map<String, dynamic> payload) async {
    final WorldInfoRepository repo = ref.read(worldInfoRepositoryProvider);
    final name = payload['name'] as String?;
    final id = payload['id'] as String?;
    models.WorldInfo? book;
    if (id != null) {
      book = await repo.getWorldInfoById(id);
    } else if (name != null) {
      final all = await repo.getAllWorldInfos();
      final matches = all.where((b) => b.name == name);
      book = matches.isEmpty ? null : matches.first;
    }
    if (book == null) return [];
    final entries = await repo.getEntriesForWorldInfo(book.id);
    return entries.map(_wiEntryToJson).toList();
  }

  /// 角色绑定的世界书名列表。
  Future<dynamic> _handleWiGetCharLorebooks(Map<String, dynamic> payload) async {
    final WorldInfoRepository repo = ref.read(worldInfoRepositoryProvider);
    final charId = ref.read(activeChatProvider).character?.id;
    if (charId == null) return [];
    final books = await repo.getWorldInfosForCharacter(charId);
    return books.map((b) => {'id': b.id, 'name': b.name}).toList();
  }

  /// 更新条目（按 uid 找到已有条目改内容/关键词）。payload: {worldId/name, entries:[...]}
  Future<dynamic> _handleWiSetEntries(Map<String, dynamic> payload) async {
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

  /// 新建条目。payload: {worldId/name, entries:[{keys, content, ...}]}
  Future<dynamic> _handleWiCreateEntries(Map<String, dynamic> payload) async {
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

    Widget fallback = const CircleAvatar(
      radius: 16,
      backgroundColor: Colors.white12,
      child: Icon(Icons.person, size: 18, color: Colors.white54),
    );

    if (avatarPath != null && avatarPath.isNotEmpty) {
      // 走统一组件：内部处理相对→绝对路径转换 + 缓存,修复顶栏头像不显示
      return ClipOval(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CharacterAvatarImage(
            imagePath: avatarPath,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
          ),
        ),
      );
    } else if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 16,
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
      toolbarHeight: 48,
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _truncateName(character?.name ?? '未知角色'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: activeGlassPalette.primaryText,
                      fontSize: 15,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    ref.watch(llmConfigProvider).model.isNotEmpty
                        ? ref.watch(llmConfigProvider).model
                        : (activeLlmConfig?.name?.toString() ?? '未选择模型'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: activeGlassPalette.secondaryText,
                      fontSize: 10.5,
                      height: 1.1,
                    ),
                  ),
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
        Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: GlassDesign.controlFill,
            shape: BoxShape.circle,
            border: Border.all(color: GlassDesign.highlightBorder),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            tooltip: '会话图片',
            iconSize: 18,
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
                        borderRadius: BorderRadius.circular(8),
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
              borderRadius: BorderRadius.circular(28),
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
                  child: TextField(
                    controller: _inputController,
                    enabled: !isGenerating,
                    focusNode: _inputFocus,
                    maxLines: 5,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    style: TextStyle(color: activeGlassPalette.primaryText),
                    cursorColor: activeGlassPalette.accent,
                    decoration: InputDecoration(
                      hintText: '输入消息…',
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
    await ref
        .read(activeChatProvider.notifier)
        .sendMessage(content, config, attachments: attachments);
  }

  Future<void> _pickImages() async {
    // 和 _navigateTo 一样：先暂停 WebView 并盖遮罩，返回后再恢复，
    // 否则 InAppWebView 的 PlatformView 命中区会在返回后失效导致无法滑动。
    await _controller?.pause();
    _maskController.value = 1.0;
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatImagesScreen(
        chatId: widget.chatId,
        onSend: (file) => _sendImageFile(file),
      ),
    ));
    if (!mounted) return;
    _maskController.reverse();            // 返回时黑幕淡出（此时不卡，好看）
    await _controller?.resume();
  }

  /// 把相册页选中的图片加入待发附件（不立即发送），
  /// 返回聊天后用户可继续打字，最后图文一起发送。
  Future<void> _sendImageFile(File file) async {
    try {
      final stat = await file.stat();
      const uuid = Uuid();
      final ext = p.extension(file.path);
      _pendingAttachments.add(ChatAttachment(
        id: uuid.v4(),
        path: file.path,
        mimeType: _getMimeType(ext),
        sizeBytes: stat.size,
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

      _pendingAttachments.add(ChatAttachment(
        id: uuid.v4(),
        path: newPath,
        mimeType: _getMimeType(extension),
        sizeBytes: fileInfo.size,
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

      final attachment = ChatAttachment(
        id: uuid.v4(),
        path: newPath,
        mimeType: _getMimeType(extension),
        sizeBytes: fileInfo.size,
      );
      _pendingAttachments.add(attachment);
      // 预热缓存：在后台 isolate 读文件转 base64，发送时直接用，不阻塞主线程
      compute(_readFileAsB64, newPath).then((b64) {
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
    if (id.isEmpty) return;
    // 生成中禁止操作气泡按钮，避免与正在进行的生成冲突
    if (ref.read(activeChatProvider).isGenerating) return;
    final notifier = ref.read(activeChatProvider.notifier);
    final config = ref.read(llmConfigProvider);

    switch (action) {
      case 'openImages':
        _pickImages(); // 复用带 pause/resume 保护的相册页打开逻辑
        break;
      case 'tts':
        debugPrint('[tts] 预留 TTS 接口，消息 $id');
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
      basePrompt: message.content,
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

          final attachment = ChatAttachment(
            id: imageId,
            path: filePath,
            mimeType: 'image/${result.format}',
            sizeBytes: imageBytes.length,
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
        .replaceAll(RegExp(r'<image>[sS]*?</image>', caseSensitive: false), '')
        .trim();
    final codeBlockMatch = RegExp(
      r'^```[a-zA-Z]*\n([\s\S]*?)```\s*$',
      multiLine: false,
    ).firstMatch(rawContent.trim());
    if (codeBlockMatch != null) {
      rawContent = codeBlockMatch.group(1) ?? rawContent;
    }
    final processed = rawContent;
    final looksLikeHtml = RegExp(
      r'<style|<script|<!DOCTYPE|<html|<head|<body',
      caseSensitive: false,
    ).hasMatch(processed);
    final rendered = looksLikeHtml
        ? processed
        : _highlightQuotes(md.markdownToHtml(
            processed,
            extensionSet: md.ExtensionSet.gitHubWeb,
          ));
    final attachmentsHtml = _buildAttachmentsHtml(m);
    return {
      'id': m.id,
      'role': m.role.name,
      'html': rendered + attachmentsHtml,
      'reasoning': m.currentReasoning ?? '',
      'swipeCount': m.swipes.length,
      'swipeIndex': m.currentSwipeIndex,
      'floor': i + 1,
      'isLatestAi': i == lastAiIndex,
    };
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
    await ref.read(regexScriptsReadyProvider(character?.id));
    final scripts = ref.read(combinedRegexScriptsProvider(character?.id));

    int lastAiIndex = -1;
    for (var i = 0; i < messages.length; i++) {
      if (messages[i].role != MessageRole.user) lastAiIndex = i;
    }

    final list = <Map<String, dynamic>>[];
    for (var i = startFrom; i < messages.length; i++) {
      list.add(_serializeMessage(messages[i], i, lastAiIndex, character, scripts));
    }
    if (list.isEmpty) return;
    final b64 = base64Encode(utf8.encode(jsonEncode(list)));
    // 不带 initial / prepend → setMessages 走"追加渲染"分支
    _bridge.send(BridgeType.setMessages, {'data': b64});
  }

  /// 把消息的图片附件读成 base64，拼成 <img> 内联到气泡 HTML。
  /// 结果缓存在 _attachmentB64Cache，_pushMessages 多次调用只读一次磁盘。
  /// WebView 不渲染真实图片（统一走独立图片界面），仅显示占位标记。
  String _buildAttachmentsHtml(ChatMessage m) {
    if (m.attachments.isEmpty) return '';
    final count = m.attachments.length;
    // 套用 act-btn + data-id + data-act，自动接入现有点击监听，
    // 点击发 action=openImages 给 Flutter，跳转独立相册页（不塞真图进 WebView）。
    return '<div class="act-btn" data-id="${m.id}" data-act="openImages" '
        'style="display:inline-flex;align-items:center;gap:4px;cursor:pointer;'
        'margin-top:6px;padding:4px 10px;border-radius:12px;'
        'background:rgba(124,77,255,.15);color:#7C4DFF;font-size:13px;">'
        '🖼 查看图片${count > 1 ? ' ($count)' : ''}</div>';
  }

  Future<void> _pushMessages() async {
    debugPrint('[图片诊断] _pushMessages 开始执行');
    final chatState = ref.read(activeChatProvider);
    final character = chatState.character;
    await ref.read(regexScriptsReadyProvider(character?.id));
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
      initialList.add(_serializeMessage(messages[i], i, lastAiIndex, character, scripts));
    }
    // 先发送最近的消息
    final initialJson = jsonEncode(initialList);
    final initialB64 = base64Encode(utf8.encode(initialJson));
    debugPrint('[图片诊断] _pushMessages 发送 setMessages, 条数=${initialList.length}');
    // 头像+名字：全局各一份，随首屏一次性下发（不进每条消息，避免膨胀拖卡）
    final persona = await ref.read(activePersonaProvider.future);
    final charUri = await _avatarToDataUri(character?.assets?.avatarPath, false);
    final userUri = await _avatarToDataUri(persona?.avatarPath, true);
    _bridge.send(BridgeType.setMessages, {
      'data': initialB64,
      'initial': true,
      'avatars': {
        'char': charUri,
        'user': userUri,
        'charName': character?.name ?? 'Assistant',
        'userName': persona?.name ?? 'User',
      },
    });

    // 后台静默追加历史消息
    if (startIndex > 0) {
      Future.delayed(const Duration(milliseconds: 100), () async {
        const int historyBatchSize = 20;
        for (var start = startIndex - historyBatchSize;
            start >= 0;
            start -= historyBatchSize) {
          final end = start + historyBatchSize;
          final batch = <Map<String, dynamic>>[];
          for (var i = start; i < end && i < startIndex; i++) {
            batch.add(_serializeMessage(messages[i], i, lastAiIndex, character, scripts));
          }
          if (batch.isNotEmpty) {
            final batchJson = jsonEncode(batch);
            final batchB64 = base64Encode(utf8.encode(batchJson));
            _bridge.send(BridgeType.setMessages, {'data': batchB64, 'prepend': true});
            await Future.delayed(const Duration(milliseconds: 16));
          }
        }
      });
    }

    // setMessages 之后，图片通过独立通道逐张推送（占位 img 已在 html 中）
    _pushImages(messages);
  }

  /// 把所有消息的图片附件逐张 base64 推给 WebView，按 data-att-path 匹配占位 img。
  /// 每张独立发送，setMessages payload 不再因图片膨胀，大图也不会撑爆传输。
  Future<void> _pushImages(List<ChatMessage> messages) async {
    return; // 图片已改为独立 Flutter 界面管理，WebView 不再接收图片。
    // ignore: dead_code
    for (final m in messages) {
      if (m.attachments.isEmpty) continue;
      for (final att in m.attachments) {
        try {
          String? b64 = _attachmentB64Cache[att.path];
          if (b64 == null) {
            final file = File(att.path);
            if (!file.existsSync()) continue;
            b64 = base64Encode(await file.readAsBytes());
            _attachmentB64Cache[att.path] = b64;
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

  String _htmlShell() {
    return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<style>
  :root {
    --quote-q-color: ${_colorToCss(ref.watch(quoteColorStateProvider).primaryA)};
    --quote-p-color: ${_colorToCss(ref.watch(quoteColorStateProvider).primaryB)};
  }
  * { -webkit-tap-highlight-color: transparent; -webkit-touch-callout: none; }
  .model-sheet-overlay{position:fixed;inset:0;background:rgba(0,0,0,.45);
    display:none;z-index:9999;align-items:flex-end;}
  .model-sheet-overlay.show{display:flex;}
  .model-sheet-panel{width:100%;max-height:70vh;background:#14161C;
    border-radius:18px 18px 0 0;padding:16px;box-sizing:border-box;
    display:flex;flex-direction:column;transform:translateY(100%);
    transition:transform .25s ease;}
  .model-sheet-overlay.show .model-sheet-panel{transform:translateY(0);}
  .model-sheet-header{font-size:15px;font-weight:600;color:#F5F7FA;margin-bottom:10px;}
  .config-switcher{margin-bottom:10px;}
  .config-current{display:flex;align-items:center;justify-content:space-between;
    padding:10px 12px;background:#20242C;border-radius:8px;color:#F5F7FA;
    font-size:13px;cursor:pointer;}
  .config-current .arrow{transition:transform .2s;font-size:12px;color:#8A8A8A;}
  .config-switcher.open .config-current .arrow{transform:rotate(180deg);}
  .config-list{max-height:0;overflow:hidden;transition:max-height .25s ease;}
  .config-switcher.open .config-list{max-height:200px;overflow-y:auto;margin-top:6px;}
  .config-item{padding:10px 12px;margin-bottom:6px;border-radius:8px;
    background:rgba(255,255,255,.05);color:#F5F7FA;font-size:13px;cursor:pointer;
    border:1px solid rgba(255,255,255,.08);}
  .config-item.active{background:rgba(121,199,255,.12);border-color:rgba(121,199,255,.4);}
  .model-search{background:#20242C;border:none;border-radius:8px;padding:10px 12px;
    color:#F5F7FA;font-size:14px;margin-bottom:10px;outline:none;}
  .model-list{overflow-y:auto;flex:1;}
  .model-item{padding:12px 14px;margin-bottom:8px;border-radius:12px;
    background:rgba(255,255,255,.05);color:#F5F7FA;font-size:14px;cursor:pointer;
    border:1px solid rgba(255,255,255,.08);}
  .model-item.selected{background:rgba(121,199,255,.12);border-color:rgba(121,199,255,.4);}
  html { height: 100%; }
  html, body { margin:0; padding:0; background:transparent; min-height: 100%; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    color: #E0E0E0; font-size: 15px; line-height: 1.5;
    padding: 12px;}
  img { max-width: 100%; height: auto; display: block; }
  .quote-q { color: var(--quote-q-color, #FFA726); font-weight: 500; }
  .quote-p { color: var(--quote-p-color, #29B6F6); font-weight: 500; }
  .msg {
    display: inline-block; max-width: 78%;
    margin: 14px 0; padding: 16px 18px; border-radius: 22px;
    word-wrap: break-word; overflow-wrap: break-word;
    box-shadow: 0 2px 12px rgba(0,0,0,0.15);
  }
  .msg-group.user { text-align: right; }
  .msg-group.assistant { text-align: left; }
  .msg.user {
    background: rgba(40,42,50,0.72);
    border: 1px solid rgba(255,255,255,0.10);
  }
  .msg.assistant {
    background: rgba(24,26,32,0.68);
    border: 1px solid rgba(255,255,255,0.07);
  }
  .msg.system { background: rgba(24,26,32,0.45); font-style: italic; opacity: .8; }
  .msg p { margin: 6px 0; }
  .msg strong { font-weight: 600; color: #FFFFFF; }
  .msg em { color: #D6C8FF; }
  .msg code {
    background: rgba(255,255,255,0.12); padding: 2px 6px;
    border-radius: 6px; font-size: 13px;
  }
  .msg pre {
    background: rgba(0,0,0,0.28); padding: 12px; border-radius: 12px;
    overflow-x: auto;
  }
  .msg pre code { background: none; padding: 0; }
  .msg ul, .msg ol { padding-left: 20px; margin: 6px 0; }
  .msg blockquote {
    border-left: 3px solid rgba(124,77,255,0.6);
    margin: 6px 0; padding-left: 12px; opacity: .85;
  }
  .msg-header {
    display: flex; align-items: center; gap: 8px;
    margin-bottom: 6px; padding: 0 2px;
  }
  .msg-group.user .msg-header { flex-direction: row-reverse; }
  .msg-avatar {
    width: 32px; height: 32px; border-radius: 50%;
    object-fit: cover; flex: 0 0 auto;
    border: 1.5px solid rgba(255,255,255,0.18);
  }
  .msg-name {
    font-size: 12px; color: #B8BEC8; font-weight: 500;
  }
  .reasoning {
    font-size: 13px; opacity: .55; border-left: 2px solid rgba(124,77,255,0.6);
    padding-left: 10px; margin-bottom: 8px;
  }
  img { max-width: 100%; height: auto; border-radius: 14px; }
  iframe.card-frame {
    width: 100%; border: none; display: block;
    background: transparent; height: 300px; border-radius: 18px;
  }
  /* 消息组：气泡 + 挂在外面下方的工具条 */
  .msg-group { margin: 14px 0; }
  .msg-group .msg { margin: 0; }
  /* 工具条容器，挂在气泡外面下方，不占气泡内部空间 */
  .msg-tools {
    display: flex; align-items: center; flex-wrap: wrap;
    gap: 6px; padding: 6px 8px 2px;
  }
  .msg-group.user .msg-tools { justify-content: flex-end; }
  /* 折叠态：一个极简小胶囊（三个点） */
  .tools-toggle {
    background: rgba(255,255,255,0.06); color: #9A9A9A; border: none;
    border-radius: 12px; padding: 3px 12px; font-size: 14px; line-height: 1;
    letter-spacing: 2px; cursor: pointer;
    transition: background .15s ease; -webkit-tap-highlight-color: transparent;
  }
  .tools-toggle:active { background: rgba(255,255,255,0.14); }
  /* 展开的按钮排：常驻 flex，靠 max-height + opacity 做平滑弹缩（display 不能过渡）。 */
  .tools-expanded {
    display: flex; align-items: center; flex-wrap: wrap; gap: 5px; width: 100%;
    max-height: 0; opacity: 0; overflow: hidden;
    transition: max-height .22s ease, opacity .18s ease;
    will-change: max-height, opacity;
  }
  .msg-tools.open .tools-expanded {
    max-height: 120px; opacity: 1;
  }
  /* toggle 收起态时淡出，展开后隐藏（display 切换无需动画，它是收起态的入口） */
  .tools-toggle { transition: opacity .15s ease, background .15s ease; }
  .msg-tools.open .tools-toggle { display: none; }
  .act-btn {
    background: rgba(30,34,44,0.92); color: #EDEFF2; border: none;
    width: 32px; height: 32px; border-radius: 50%; padding: 0;
    font-size: 16px; line-height: 1;
    display: flex; align-items: center; justify-content: center;
    cursor: pointer; transition: background .15s ease;
    -webkit-tap-highlight-color: transparent; flex: 0 0 auto;
    border: 1px solid rgba(255,255,255,0.10);
  }
  .act-btn:active { background: rgba(50,56,70,0.95); }
  .act-spacer { flex: 1; min-width: 4px; }
  .act-del { background: rgba(70,28,28,0.92); color: #FF9B9B; border: 1px solid rgba(255,77,77,0.25); }
  .act-del:active { background: rgba(95,36,36,0.95); }
  .swipe-bar {
    display: flex; align-items: center; justify-content: center;
    gap: 14px; padding: 4px 0 2px;
  }
  .msg-group.user .swipe-bar { justify-content: flex-end; padding-right: 8px; }
  .swipe-btn {
    background: rgba(255,255,255,0.08); color: #CFCFCF; border: none;
    border-radius: 10px; width: 30px; height: 24px; font-size: 15px;
    cursor: pointer; -webkit-tap-highlight-color: transparent;
  }
  .swipe-btn:disabled { opacity: 0.3; }
  .swipe-btn:active:not(:disabled) { background: rgba(255,255,255,0.18); }
  .swipe-label { font-size: 12px; color: #9A9A9A; min-width: 40px; text-align: center; }
  .floor-tag-wrap { display: flex; padding: 2px 8px 0; }
  .msg-group.user .floor-tag-wrap { justify-content: flex-end; }
  .floor-tag {
    background: rgba(124,77,255,0.14); color: #B39DFF;
    border-radius: 10px; padding: 2px 10px; font-size: 11px;
    letter-spacing: 0.5px;
  }
  .act-close {
    background: rgba(255,255,255,0.05); color: #8A8A8A;
  }

  .thinking {
    display: inline-flex; align-items: center; gap: 6px;
    padding: 7px 14px; border-radius: 16px;
    background: rgba(30,34,44,0.72);
    font-size: 13px; color: #B8C0CC;
  }
  .thinking .star { display: inline-block; will-change: transform; }
  @keyframes think-spin {
    0%   { transform: rotate(0deg); }
    25%  { transform: rotate(360deg); }   /* 前 1/4 时间转一圈 */
    100% { transform: rotate(360deg); }   /* 后 3/4 停住 → 转一下、停一下 */
  }
  .thinking .star { animation: think-spin 1.8s ease-in-out infinite; }
  .func-overlay{position:fixed;inset:0;background:rgba(0,0,0,.5);display:none;
    z-index:9998;align-items:flex-end;}
  .func-panel{width:100%;background:#12141C;border-radius:18px 18px 0 0;
    padding:16px;box-sizing:border-box;max-height:75vh;overflow-y:auto;
    transform-origin:left bottom;transform:scale(.08);opacity:0;
    transition:transform .42s cubic-bezier(0.34,1.56,0.64,1),opacity .22s ease;}
  .func-overlay.show .func-panel{transform:scale(1);opacity:1;}
  .func-context{margin-bottom:12px;color:#7FD98A;font-size:13px;cursor:pointer;
    background:rgba(127,217,138,.08);border-radius:10px;padding:8px 12px;}
  .func-context-head{display:flex;align-items:center;justify-content:space-between;}
  .func-context-arrow{font-size:10px;color:#7FD98A;transition:transform .2s;}
  .func-context.open .func-context-arrow{transform:rotate(180deg);}
  .func-context-detail{max-height:0;overflow:hidden;transition:max-height .28s ease;}
  .func-context.open .func-context-detail{max-height:240px;overflow-y:auto;margin-top:8px;}
  .func-ctx-row{display:flex;justify-content:space-between;padding:6px 4px;
    font-size:12px;color:#C8CDD6;border-bottom:1px solid rgba(255,255,255,.05);}
  .func-ctx-tok{color:#8A8A8A;}
  .func-floor-row{display:flex;gap:8px;margin-bottom:14px;}
  .func-floor-input{flex:1;background:#20242C;border:none;border-radius:10px;
    padding:10px 12px;color:#F5F7FA;font-size:14px;outline:none;}
  .func-btn-jump{background:#7C4DFF;color:#fff;border-radius:10px;
    padding:10px 18px;font-size:14px;cursor:pointer;display:flex;align-items:center;}
  .func-group-label{color:#8A8A8A;font-size:11px;font-weight:600;
    letter-spacing:.8px;margin:8px 0 8px;}
  .func-grid{display:flex;flex-wrap:wrap;gap:8px;margin-bottom:6px;}
  .func-item{width:72px;height:70px;background:rgba(255,255,255,.05);
    border:1px solid rgba(255,255,255,.08);border-radius:14px;color:#C8CDD6;
    font-size:12px;display:flex;flex-direction:column;align-items:center;
    justify-content:center;gap:7px;cursor:pointer;
    opacity:0;transform:translateY(10px) scale(.8);
    transition:opacity .3s ease,transform .32s cubic-bezier(0.34,1.56,0.64,1),background .15s;}
  .func-overlay.show .func-item{opacity:1;transform:translateY(0) scale(1);}
  .func-overlay.show .func-grid .func-item:nth-child(1){transition-delay:.14s;}
  .func-overlay.show .func-grid .func-item:nth-child(2){transition-delay:.19s;}
  .func-overlay.show .func-grid .func-item:nth-child(3){transition-delay:.24s;}
  .func-overlay.show .func-grid .func-item:nth-child(4){transition-delay:.29s;}
  .func-overlay.show .func-grid .func-item:nth-child(5){transition-delay:.34s;}
  .func-overlay.show .func-grid .func-item:nth-child(6){transition-delay:.39s;}
  .func-overlay.show .func-grid .func-item:nth-child(7){transition-delay:.44s;}
  .func-item:active{background:rgba(124,77,255,.22);}
  .func-icon{width:26px;height:26px;stroke:#5B9EF5;fill:none;stroke-width:2;
    stroke-linecap:round;stroke-linejoin:round;}
</style>
</head>
<body>
<div id="root"></div>
<div id="model-sheet" class="model-sheet-overlay">
  <div class="model-sheet-panel">
    <div class="model-sheet-header">选择模型</div>
    <input id="model-search" class="model-search" placeholder="搜索模型…" />
    <div id="config-switcher" class="config-switcher" style="display:none;">
      <div class="config-current" id="config-current">
        <span id="config-current-name">方案</span>
        <span class="arrow">▼</span>
      </div>
      <div class="config-list" id="config-list"></div>
    </div>
    <div id="model-list" class="model-list"></div>
  </div>
</div>
<div id="func-overlay" class="func-overlay">
  <div id="func-panel" class="func-panel">
    <div class="func-context" id="func-context">
      <div class="func-context-head">
        <span id="func-context-label"></span>
        <span class="func-context-arrow">▼</span>
      </div>
      <div class="func-context-detail" id="func-context-detail"></div>
    </div>
    <div class="func-floor-row">
      <input id="func-floor-input" class="func-floor-input" type="number" placeholder="输入楼层号跳转…"/>
      <div class="func-btn-jump func-action" data-action="jumpFloor">跳转</div>
    </div>
    <div class="func-group-label">对话</div>
    <div class="func-grid">
      <div class="func-item func-action" data-action="pickImages"><svg class="func-icon" viewBox="0 0 24 24"><rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><path d="m21 15-5-5L5 21"/></svg><span>图片</span></div>
      <div class="func-item func-action" data-action="exportChat"><svg class="func-icon" viewBox="0 0 24 24"><path d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8"/><polyline points="16 6 12 2 8 6"/><line x1="12" y1="2" x2="12" y2="15"/></svg><span>导出</span></div>
      <div class="func-item func-action" data-action="importChat"><svg class="func-icon" viewBox="0 0 24 24"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg><span>导入</span></div>
      <div class="func-item func-action" data-action="clearChat"><svg class="func-icon" viewBox="0 0 24 24"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg><span>清空</span></div>
    </div>
    <div class="func-group-label">设置</div>
    <div class="func-grid">
      <div class="func-item func-action" data-action="navigateTo" data-route="/image-gen-settings"><svg class="func-icon" viewBox="0 0 24 24"><path d="M12 20h9"/><path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4z"/></svg><span>生图</span></div>
      <div class="func-item func-action" data-action="navigateTo" data-route="/tts-settings"><svg class="func-icon" viewBox="0 0 24 24"><path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z"/><path d="M19 10v2a7 7 0 0 1-14 0v-2"/><line x1="12" y1="19" x2="12" y2="23"/><line x1="8" y1="23" x2="16" y2="23"/></svg><span>语音</span></div>
      <div class="func-item func-action" data-action="navigateTo" data-route="/vector-storage-settings"><svg class="func-icon" viewBox="0 0 24 24"><rect x="4" y="4" width="16" height="16" rx="2"/><rect x="9" y="9" width="6" height="6"/><line x1="9" y1="1" x2="9" y2="4"/><line x1="15" y1="1" x2="15" y2="4"/><line x1="9" y1="20" x2="9" y2="23"/><line x1="15" y1="20" x2="15" y2="23"/><line x1="20" y1="9" x2="23" y2="9"/><line x1="20" y1="14" x2="23" y2="14"/><line x1="1" y1="9" x2="4" y2="9"/><line x1="1" y1="14" x2="4" y2="14"/></svg><span>记忆</span></div>
      <div class="func-item func-action" data-action="navigateTo" data-route="/variables-settings"><svg class="func-icon" viewBox="0 0 24 24"><polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/></svg><span>变量</span></div>
      <div class="func-item func-action" data-action="navigateToChar" data-route-tpl="/characters/{charId}/regex"><svg class="func-icon" viewBox="0 0 24 24"><polyline points="17 1 21 5 17 9"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><polyline points="7 23 3 19 7 15"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/></svg><span>正则</span></div>
      <div class="func-item func-action" data-action="navigateToChar" data-route-tpl="/world-info?characterId={charId}"><svg class="func-icon" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/><line x1="2" y1="12" x2="22" y2="12"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/></svg><span>世界书</span></div>
      <div class="func-item func-action" data-action="navigateTo" data-route="/background-settings"><svg class="func-icon" viewBox="0 0 24 24"><polygon points="12 2 2 7 12 12 22 7 12 2"/><polyline points="2 17 12 22 22 17"/><polyline points="2 12 12 17 22 12"/></svg><span>气泡</span></div>
    </div>
  </div>
</div>
<script>
$kChatBridgeJs
  var __allModels = [];
  var __currentModel = '';
  function __renderModelList(filter) {
    var list = document.getElementById('model-list');
    if (!list) return;
    var q = (filter || '').toLowerCase();
    list.innerHTML = '';
    __allModels.filter(function(m){ return m.toLowerCase().indexOf(q) >= 0; })
      .forEach(function(m){
        var el = document.createElement('div');
        el.className = 'model-item' + (m === __currentModel ? ' selected' : '');
        el.textContent = m;
        el.onclick = function(){
          sendToFlutter('modelSelected', { model: m });
          __closeModelSheet();
        };
        list.appendChild(el);
      });
  }
  function __closeModelSheet(){
    var ov = document.getElementById('model-sheet');
    if(!ov) return;
    ov.classList.remove('show');
    setTimeout(function(){ ov.style.display = 'none'; }, 260);
  }
  var __configs = [];
  function __renderConfigs(){
    var sw = document.getElementById('config-switcher');
    var listEl = document.getElementById('config-list');
    var nameEl = document.getElementById('config-current-name');
    if(!sw || !listEl || !nameEl) return;
    // 只有一个方案(或没有)时,不显示方案切换
    if(__configs.length <= 1){ sw.style.display = 'none'; return; }
    sw.style.display = 'block';
    var activeCfg = __configs.filter(function(c){ return c.active; })[0];
    nameEl.textContent = activeCfg ? activeCfg.name : '方案';
    listEl.innerHTML = '';
    __configs.forEach(function(c){
      var el = document.createElement('div');
      el.className = 'config-item' + (c.active ? ' active' : '');
      el.textContent = c.name;
      el.onclick = function(){
        if(c.active){ sw.classList.remove('open'); return; } // 点当前方案只收起
        sendToFlutter('switchConfig', { configId: c.id });
        sw.classList.remove('open');
      };
      listEl.appendChild(el);
    });
    // 点"当前方案"行展开/收起
    var cur = document.getElementById('config-current');
    if(cur){ cur.onclick = function(){ sw.classList.toggle('open'); }; }
  }
  registerBridgeHandler('showModelSheet', function(p){
    __allModels = p.models || [];
    __currentModel = p.current || '';
    __configs = p.configs || [];
    __renderConfigs();
    var s = document.getElementById('model-search');
    if (s) { s.value = ''; s.oninput = function(){ __renderModelList(s.value); }; }
    __renderModelList('');
    var ov = document.getElementById('model-sheet');
    if (ov) {
      ov.style.display = 'flex';
      requestAnimationFrame(function(){
        requestAnimationFrame(function(){ ov.classList.add('show'); });
      });
      ov.onclick = function(e){ if(e.target === ov) __closeModelSheet(); };
    }
  });
  registerBridgeHandler('hideModelSheet', function(){
    __closeModelSheet();
  });
  window.__funcCharId = '';
  function __closeFuncPanel(){
    var ov = document.getElementById('func-overlay');
    if(!ov) return;
    ov.classList.remove('show');
    setTimeout(function(){ ov.style.display = 'none'; }, 300);
    sendToFlutter('panelClosed', {});
  }
  function __handleFuncAction(el){
    var action = el.getAttribute('data-action');
    if(action === 'jumpFloor'){
      var inp = document.getElementById('func-floor-input');
      var v = inp ? inp.value.trim() : '';
      if(v){ sendToFlutter('panelAction', {action:'jumpFloor', floor:v}); }
      __closeFuncPanel(); return;
    }
    if(action === 'navigateToChar'){
      if(!window.__funcCharId){
        sendToFlutter('panelAction', {action:'noChar'});
        __closeFuncPanel(); return;
      }
      var tpl = el.getAttribute('data-route-tpl') || '';
      sendToFlutter('panelAction', {action:'navigateTo', route: tpl.replace('{charId}', window.__funcCharId)});
      __closeFuncPanel(); return;
    }
    if(action === 'navigateTo'){
      sendToFlutter('panelAction', {action:'navigateTo', route: el.getAttribute('data-route') || ''});
      __closeFuncPanel(); return;
    }
    sendToFlutter('panelAction', {action: action});
    __closeFuncPanel();
  }
  registerBridgeHandler('openFunctionPanel', function(p){
    var ov = document.getElementById('func-overlay');
    if(!ov) return;
    window.__funcCharId = p.charId || '';
    var label = document.getElementById('func-context-label');
    if(label){ label.textContent = (p.contextUsed||0) + ' / ' + (p.contextMax||0) + ' (' + Math.round(p.contextPct||0) + '%)'; }
    var detail = document.getElementById('func-context-detail');
    if(detail){
      var comps = p.components || [];
      detail.innerHTML = '';
      comps.forEach(function(c){
        var row = document.createElement('div');
        row.className = 'func-ctx-row';
        var n = document.createElement('span'); n.textContent = c.name || '';
        var t = document.createElement('span'); t.className = 'func-ctx-tok'; t.textContent = (c.tokens||0) + ' tokens';
        row.appendChild(n); row.appendChild(t);
        detail.appendChild(row);
      });
    }
    var ctx = document.getElementById('func-context');
    if(ctx){ ctx.classList.remove('open'); ctx.onclick = function(){ ctx.classList.toggle('open'); }; }
    var items = ov.querySelectorAll('.func-action');
    for(var i=0;i<items.length;i++){
      (function(el){ el.onclick = function(){ __handleFuncAction(el); }; })(items[i]);
    }
    ov.onclick = function(e){ if(e.target === ov) __closeFuncPanel(); };
      ov.style.display = 'flex';
      requestAnimationFrame(function(){
        requestAnimationFrame(function(){ ov.classList.add('show'); });
      });
  });
  registerBridgeHandler('closeFunctionPanel', function(){ __closeFuncPanel(); });

  function decodeB64Utf8(b64) {
    var binary = atob(b64);
    var bytes = new Uint8Array(binary.length);
    for (var i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
    return new TextDecoder('utf-8').decode(bytes);
  }

  function isRichHtml(s) {
    if (!s) return false;
    return /<style|<script|<!DOCTYPE|<html|<head|<body/i.test(s);
  }

function injectBridge(html, id) {
    var _libs=(typeof window.__KIRA_LIBS!=="undefined")?window.__KIRA_LIBS:{};
    var _libScript="";
    try{
      var _needJq=(html.indexOf("\$(")>=0)||(html.indexOf("jQuery")>=0);
      var _needLodash=(html.indexOf("_.")>=0);
      var _needToastr=(html.indexOf("toastr.")>=0);
      if(_needJq&&_libs.jquery){_libScript+="<script>"+decodeB64Utf8(_libs.jquery)+"<\\/script>";}
      if(_needLodash&&_libs.lodash){_libScript+="<script>"+decodeB64Utf8(_libs.lodash)+"<\\/script>";}
      if(_needToastr&&_libs.toastrJs){if(_libs.toastrCss){_libScript+="<style>"+decodeB64Utf8(_libs.toastrCss)+"<\\/style>";}_libScript+="<script>"+decodeB64Utf8(_libs.toastrJs)+"<\\/script>";}
    }catch(e){parent.postMessage({__thLog:true,text:"[兼容库] 内联失败: "+e},"*");}
  var patch = _libScript + '<style>' +
      'html,body{min-height:0 !important;overflow:visible !important;}' +
      '</style>' +
      '<script>(function(){' +
      'var _s={};try{localStorage.getItem("__t");}catch(e){' +
      'try{Object.defineProperty(window,"localStorage",{configurable:true,value:{' +
      'getItem:function(k){return _s[k]||null;},' +
      'setItem:function(k,v){_s[k]=String(v);},' +
      'removeItem:function(k){delete _s[k];},' +
      'clear:function(){_s={};},' +
      'key:function(i){return Object.keys(_s)[i]||null;},' +
      'get length(){return Object.keys(_s).length;}' +
      '}});parent.postMessage({__thLog:true,text:"[polyfill] localStorage 已用 defineProperty 覆盖成功"},"*");}' +
      'catch(e2){parent.postMessage({__thLog:true,text:"[polyfill] localStorage 覆盖失败: "+e2},"*");}' +
      '}' +
      'var _ss={};try{sessionStorage.getItem("__t");}catch(e){' +
      'try{Object.defineProperty(window,"sessionStorage",{configurable:true,value:{' +
      'getItem:function(k){return _ss[k]||null;},' +
      'setItem:function(k,v){_ss[k]=String(v);},' +
      'removeItem:function(k){delete _ss[k];},' +
      'clear:function(){_ss={};},' +
      'key:function(i){return Object.keys(_ss)[i]||null;},' +
      'get length(){return Object.keys(_ss).length;}' +
      '}});parent.postMessage({__thLog:true,text:"[polyfill] sessionStorage 覆盖成功"},"*");}' +
      'catch(e2){parent.postMessage({__thLog:true,text:"[polyfill] sessionStorage 覆盖失败: "+e2},"*");}' +
      '}' +
      '(function(){' +
      'var _origAddEvt=document.addEventListener.bind(document);' +
      'document.addEventListener=function(type,fn,opts){' +
      'if(type==="DOMContentLoaded"&&document.readyState!=="loading"){' +
      'setTimeout(fn,0);' +
      '}else{' +
      '_origAddEvt(type,fn,opts);' +
      '}' +
      '};' +
      '})();' +
      '(function(){' +
      'var _log=function(level){return function(){' +
      'try{var parts=[];for(var i=0;i<arguments.length;i++){var a=arguments[i];' +
      'parts.push(typeof a==="object"?(function(){try{return JSON.stringify(a);}catch(e){return String(a);}})():String(a));}' +
      'parent.postMessage({__thLog:true,text:"[卡片:"+level+"] "+parts.join(" ")},"*");}catch(e){}' +
      '};};' +
      'var _c=window.console||{};' +
      'console.log=_log("log");console.error=_log("error");console.warn=_log("warn");console.info=_log("info");' +
      'window.onerror=function(msg,src,line,col,err){' +
      'try{parent.postMessage({__thLog:true,text:"[卡片:onerror] "+msg+" @"+line+":"+col+(err&&err.stack?" | "+err.stack:"")},"*");}catch(e){}' +
      'return false;};' +
      'window.addEventListener("unhandledrejection",function(ev){' +
      'try{parent.postMessage({__thLog:true,text:"[卡片:promise未捕获] "+(ev.reason&&ev.reason.message||ev.reason)},"*");}catch(e){}' +
      '});' +
      '})();' +
      'var _id=' + JSON.stringify(id) + ';' +
      'var _debTimer=null,_forceTimer=null,_lastH=0;' +
      'function report(){' +
      'var b=document.body;' +
      'var h=b?Math.ceil(b.getBoundingClientRect().height):0;' +
      'if(!h){h=document.documentElement.scrollHeight||0;}' +
      'if(h>0&&Math.abs(h-_lastH)>4){_lastH=h;parent.postMessage({__cardHeight:true,id:_id,height:h},"*");}' +
      '}' +
      'function scheduledReport(){' +
      'if(_debTimer)clearTimeout(_debTimer);' +
      '_debTimer=setTimeout(function(){_debTimer=null;report();},150);' +
      'if(!_forceTimer){_forceTimer=setTimeout(function(){_forceTimer=null;if(_debTimer){clearTimeout(_debTimer);_debTimer=null;}report();},500);}' +
      '}' +
      'window.addEventListener("load",function(){' +
      'setTimeout(report,200);setTimeout(report,600);setTimeout(report,1500);' +
      '});' +
      'if(typeof ResizeObserver!=="undefined"){' +
      'var _roTarget=document.body||document.documentElement;' +
      'if(_roTarget){' +
      'var ro=new ResizeObserver(function(){scheduledReport();});' +
      'ro.observe(_roTarget);' +
      '}}' +

      'var __thPending={};var __thId=1;' +
      'function __thCall(method,args){' +
      'return new Promise(function(resolve,reject){' +
      'var rid=_id+"_"+(__thId++);' +
      '__thPending[rid]={resolve:resolve,reject:reject};' +
      'setTimeout(function(){if(__thPending[rid]){delete __thPending[rid];reject(new Error("th timeout: "+method));}},30000);' +
      'parent.postMessage({__thLog:true,text:"[iframe] 调用 "+method},"*");' +
      'parent.postMessage({__thRequest:true,frameId:_id,rid:rid,method:method,args:args},"*");' +
      '});' +
      '}' +
      'window.addEventListener("message",function(e){' +
      'var d=e.data;if(!d||!d.__thResponse)return;' +
      'var p=__thPending[d.rid];if(!p)return;delete __thPending[d.rid];' +
      'if(d.ok)p.resolve(d.result);else p.reject(new Error(d.error||"th failed"));' +
      '});' +
      // 第一梯队 API：裸挂 window + TavernHelper 命名空间（规格要求两者都可用）
      'var _TH={};' +
      '_TH.getChatMessages=function(range,option){return __thCall("getChatMessages",[range,option||{}]);};' +
      '_TH.setChatMessage=function(content,index,option){return __thCall("setChatMessage",[content,index,option||{}]);};' +
      '_TH.setChatMessages=function(msgs,option){return __thCall("setChatMessages",[msgs,option||{}]);};' +
      '_TH.createChatMessages=function(msgs,option){return __thCall("createChatMessages",[msgs,option||{}]);};' +
      '_TH.deleteChatMessages=function(ids,option){return __thCall("deleteChatMessages",[ids,option||{}]);};' +
      '_TH.triggerSlash=function(cmd){return __thCall("triggerSlash",[cmd]);};' +
      '_TH.__lastMsgId=0;' +
      '_TH.getCurrentMessageId=function(){return _TH.__lastMsgId;};' +
      '_TH.getVariables=function(option){return __thCall("getVariables",[option||{}]);};' +
      '_TH.setVariables=function(vars,option){return __thCall("setVariables",[vars,option||{}]);};' +
      '_TH.replaceVariables=function(vars,option){return __thCall("replaceVariables",[vars,option||{}]);};' +
      '_TH.getAllVariables=function(){return __thCall("getAllVariables",[]);};' +
      '_TH.getTavernHelperVersion=function(){return "kirakira-compat-1.0";};' +
      '_TH.getLorebookEntries=function(name){return __thCall("getLorebookEntries",[name]);};' +
      '_TH.setLorebookEntries=function(name,entries){return __thCall("setLorebookEntries",[name,entries||[]]);};' +
      '_TH.createLorebookEntry=function(name,entry){return __thCall("createLorebookEntry",[name,entry||{}]);};' +
      '_TH.deleteLorebookEntries=function(name,uids){return __thCall("deleteLorebookEntries",[name,uids||[]]);};' +
      '_TH.getCharacterLorebooks=function(){return __thCall("getCharacterLorebooks",[]);};' +
      '_TH.getLorebooks=function(){return __thCall("getLorebooks",[]);};' +
      '_TH.createLorebook=function(name){return __thCall("createLorebook",[name]);};' +
      // ── 事件总线（iframe 本地实现） ──────────────────
      '_TH.__events={};' +
      '_TH.__eventOn=function(type,listener){(_TH.__events[type]=_TH.__events[type]||[]).push(listener);return {stop:function(){_TH.__eventRemove(type,listener);}};};' +
      '_TH.eventOn=function(type,listener){return _TH.__eventOn(type,listener);};' +
      '_TH.eventMakeLast=function(type,listener){return _TH.__eventOn(type,listener);};' +
      '_TH.eventMakeFirst=function(type,listener){var l=_TH.__events[type]=_TH.__events[type]||[];l.unshift(listener);return {stop:function(){_TH.__eventRemove(type,listener);}};};' +
      '_TH.eventOnce=function(type,listener){var wrap=function(){_TH.__eventRemove(type,wrap);return listener.apply(this,arguments);};return _TH.__eventOn(type,wrap);};' +
      '_TH.eventRemoveListener=function(type,listener){_TH.__eventRemove(type,listener);};' +
      '_TH.__eventRemove=function(type,listener){var l=_TH.__events[type];if(!l)return;var i=l.indexOf(listener);if(i>=0)l.splice(i,1);};' +
      '_TH.eventClearAll=function(){_TH.__events={};};' +
      '_TH.eventEmit=function(type){var args=Array.prototype.slice.call(arguments,1);var l=(_TH.__events[type]||[]).slice();for(var i=0;i<l.length;i++){try{l[i].apply(null,args);}catch(e){console.error("[事件]"+type,e);}}};' +
      '_TH.eventEmitAndWait=function(type){var args=Array.prototype.slice.call(arguments,1);var l=(_TH.__events[type]||[]).slice();var results=[];for(var i=0;i<l.length;i++){try{results.push(l[i].apply(null,args));}catch(e){console.error("[事件]"+type,e);}}return Promise.all(results);};' +
      // tavern_events 常量表
      'window.tavern_events={' +
      'MESSAGE_RECEIVED:"message_received",MESSAGE_UPDATED:"message_updated",MESSAGE_SWIPED:"message_swiped",MESSAGE_DELETED:"message_deleted",MORE_MESSAGES_LOADED:"more_messages_loaded",CHAT_CHANGED:"chat_changed",CHARACTER_MESSAGE_RENDERED:"character_message_rendered",USER_MESSAGE_RENDERED:"user_message_rendered",GENERATION_AFTER_COMMANDS:"generation_after_commands",GENERATION_STARTED:"generation_started",GENERATION_STOPPED:"generation_stopped",GENERATION_ENDED:"generation_ended",STREAM_TOKEN_RECEIVED:"stream_token_received",CONNECTED:"connected",DISCONNECTED:"disconnected",EXTENSION_SETTINGS_LOADED:"extension_settings_loaded",CHARACTER_SELECTED:"character_selected",CHARACTER_DELETED:"character_deleted",CHARACTER_RENAMED:"character_renamed",CHARACTER_CREATED:"character_created",CHAT_DELETED:"chat_deleted",GROUP_UPDATED:"group_updated",PRESET_RENAMED_BEFORE:"preset_renamed_before",MAIN_API_CHANGED:"main_api_changed",WORLDINFO_ENTRIES_LOADED:"worldinfo_entries_loaded",WORLDINFO_SCAN_DONE:"worldinfo_scan_done"' +
      '};' +
      'window.iframe_events={GENERATION_STARTED:"iframe_generation_started",GENERATION_ENDED:"iframe_generation_ended",STREAM_TOKEN_RECEIVED_FULLY:"iframe_stream_token_received_fully",STREAM_TOKEN_RECEIVED_INCREMENTALLY:"iframe_stream_token_received_incrementally"};' +
      // 全部裸挂到 window
      'for(var _k in _TH){if(_TH.hasOwnProperty(_k)){window[_k]=_TH[_k];}}' +
      'window.TavernHelper=_TH;' +
      // ── SillyTavern.getContext() 骨架 ──────────────────
      'var _ctx={' +
      // 已实现能力：接真实事件总线
      'eventSource:{' +
      'on:function(t,l){return _TH.eventOn(t,l);},' +
      'once:function(t,l){return _TH.eventOnce(t,l);},' +
      'emit:function(t){var a=Array.prototype.slice.call(arguments,1);return _TH.eventEmit.apply(_TH,[t].concat(a));},' +
      'removeListener:function(t,l){return _TH.eventRemoveListener(t,l);},' +
      'makeLast:function(t,l){return _TH.eventMakeLast(t,l);},' +
      'makeFirst:function(t,l){return _TH.eventMakeFirst(t,l);}' +
      '},' +
      'eventTypes:window.tavern_events,' +
      // 已实现能力：变量、消息读写走 _TH
      'getChatMessages:function(r,o){return _TH.getChatMessages(r,o);},' +
      'setChatMessage:function(c,i,o){return _TH.setChatMessage(c,i,o);},' +
      // 安全占位：未实现字段给空默认值，读取不崩
      'chat:[],' +
      'characters:[],' +
      'characterId:0,' +
      'groupId:null,' +
      'chatId:"",' +
      'chatMetadata:{},' +
      'extensionSettings:{},' +
      'name1:"You",' +
      'name2:"",' +
      // 安全占位：常被调用的方法给 noop，避免 undefined 调用崩溃
      'saveChat:function(){return Promise.resolve();},' +
      'saveMetadata:function(){return Promise.resolve();},' +
      'reloadCurrentChat:function(){return Promise.resolve();},' +
      'getRequestHeaders:function(){return {"Content-Type":"application/json"};},' +
      'renderExtensionTemplateAsync:function(){return Promise.resolve("");}' +
      '};' +
      'window.SillyTavern={getContext:function(){return _ctx;}};' +
      'window.getContext=function(){return _ctx;};' +
      '})();<\\/script>';
    if (/<head>/i.test(html)) return html.replace(/<head>/i, '<head>' + patch);
    if (/<html/i.test(html)) return html.replace(/<html[^>]*>/, function(m){ return m + patch; });
    if (/<\\\/body>/i.test(html)) return html.replace(/<\\\/body>/i, patch + '</body>');
    return html + patch;
  }

window.addEventListener('message', function(e) {
    var d = e.data;
    if (d && d.__thLog) {
      sendToFlutter('log', { text: d.text });
    }
    if (d && d.__cardHeight) {
      var f = document.querySelector('iframe[data-frame-id="' + d.id + '"]');
      if (f && d.height > 0) {
        f.style.height = (d.height + 4) + 'px';
        f.setAttribute('data-last-height', (d.height + 4) + 'px');
      }
    }
  });

  // ── 酒馆助手 API：顶层中转 ────────────────────────────────────────
  // 收 iframe 的 __thRequest → 走桥的请求-响应到 Flutter →
  // 结果用 __thResponse postMessage 回对应 iframe。
  window.addEventListener('message', function(e) {
    var d = e.data;
    if (!d || !d.__thRequest) return;
    var frameId = d.frameId, rid = d.rid, method = d.method, args = d.args || [];
    var srcWin = e.source;

    function reply(ok, result, error) {
      if (srcWin) srcWin.postMessage({
        __thResponse: true, rid: rid, ok: ok,
        result: result, error: error
      }, '*');
    }

    // method → 桥的请求 type + payload 组装
    var typeMap = {
      getChatMessages: 'th_getMessages',
      setChatMessage:  'th_setMessage',
      triggerSlash:    'th_triggerSlash',
      getVariables:    'th_getVars',
      setVariables:    'th_setVars',
      getLorebookEntries:    'th_wiGetEntries',
      setLorebookEntries:    'th_wiSetEntries',
      createLorebookEntry:   'th_wiCreateEntries',
      deleteLorebookEntries: 'th_wiDeleteEntries',
      getCharacterLorebooks: 'th_wiGetCharLorebooks',
      getLorebooks:          'th_wiGetLorebooks',
      createLorebook:        'th_wiCreateBook'
    };
    sendToFlutter('log', { text: '[TH中转] 收到iframe请求 method=' + method });
    var type = typeMap[method];
    if (!type) { reply(false, null, 'unknown method: ' + method); return; }

    // 把卡片的位置参数拍平成 payload（与各 window.xxx 的约定对齐）
    var payload = {};
    if (method === 'getChatMessages') {
      payload = { start: args[0] || 0, include_swipe: (args[1] && args[1].include_swipe) || false };
    } else if (method === 'setChatMessage') {
      payload = { content: args[0], index: args[1],
        swipe_id: args[2] && args[2].swipe_id, refresh: (args[2] && args[2].refresh) || false };
    } else if (method === 'triggerSlash') {
      payload = { command: args[0] };
    } else if (method === 'getVariables') {
      payload = { option: args[0] || {} };
    } else if (method === 'setVariables') {
      payload = { vars: args[0] || {}, option: args[1] || {} };
    } else if (method === 'getLorebookEntries') {
      payload = { name: args[0] };
    } else if (method === 'setLorebookEntries') {
      payload = { name: args[0], entries: args[1] || [] };
    } else if (method === 'createLorebookEntry') {
      payload = { name: args[0], entries: [args[1] || {}] };
    } else if (method === 'deleteLorebookEntries') {
      payload = { name: args[0], uids: args[1] || [] };
    } else if (method === 'getCharacterLorebooks') {
      payload = {};
    } else if (method === 'getLorebooks') {
      payload = {};
    } else if (method === 'createLorebook') {
      payload = { name: args[0] };
    }

    __sendRequest(type, payload)
      .then(function(res) {
        sendToFlutter('log', { text: '[TH中转] ' + method + ' 成功返回' });
        reply(true, res, null);
      })
      .catch(function(err) {
        sendToFlutter('log', { text: '[TH中转] ' + method + ' 失败: ' + (err && err.message || err) });
        reply(false, null, String(err && err.message || err));
      });
  });


  // iframe虚拟化：屏幕外超过一屏的iframe清空srcdoc，滚回来时恢复
  (function() {
    if (typeof IntersectionObserver === 'undefined') return;
    var obs = new IntersectionObserver(function(entries) {
      entries.forEach(function(entry) {
        var f = entry.target;
        var html = f.getAttribute('data-html');
        if (!html) return;
        if (entry.isIntersecting) {
          // 进入缓冲区：恢复渲染
          if (!f.getAttribute('data-blob-loaded')) {
            var lastH = f.getAttribute('data-last-height');
            if (lastH) f.style.height = lastH;
            var injected2 = injectBridge(html, f.getAttribute('data-frame-id'));
            try {
              var blob2 = new Blob([injected2], {type:'text/html;charset=utf-8'});
              var url2 = URL.createObjectURL(blob2);
              f.setAttribute('data-blob-loaded', '1');
              f.src = url2;
              f.addEventListener('load', function onLoad2(){
                f.removeEventListener('load', onLoad2);
                URL.revokeObjectURL(url2);
              });
            } catch(e2) {
              f.srcdoc = injected2;
            }
          }
        } else {
          // 离开缓冲区：记录高度，清空srcdoc
          var h = f.style.height;
          if (h) f.setAttribute('data-last-height', h);
          f.src = 'about:blank';
          f.removeAttribute('data-blob-loaded');
        }
      });
    }, {
      rootMargin: '100% 0px 100% 0px',
      threshold: 0
    });

    // 监听所有现有和未来的iframe
    function observeFrames() {
      document.querySelectorAll('iframe.card-frame').forEach(function(f) {
        if (!f.getAttribute('data-observed')) {
          f.setAttribute('data-observed', '1');
          obs.observe(f);
        }
      });
    }

    // 新消息追加时自动监听新iframe
    var mo = new MutationObserver(observeFrames);
    mo.observe(document.getElementById('root'), {childList: true, subtree: true});
    observeFrames();
  })();

  // 工具条：折叠态只有一个小胶囊，点开展开一排文字按钮。挂在气泡外面下方。
  function buildActions(id, isLatestAi) {
    var tools = document.createElement('div');
    tools.className = 'msg-tools';
    tools.setAttribute('data-tools-id', id);

    // 折叠入口：三个点
    var toggle = document.createElement('button');
    toggle.className = 'tools-toggle';
    toggle.textContent = '•••';
    toggle.setAttribute('data-toggle', id);
    tools.appendChild(toggle);

    // 展开区
    var exp = document.createElement('div');
    exp.className = 'tools-expanded';
    var items = [
      { a: 'tts',   t: '♪', title: '语音' },
      { a: 'edit',  t: '✎', title: '编辑' },
      { a: 'retry', t: '↻', title: '重试' },
      { a: 'imagegen', t: '▤', title: '生图' }
    ];
    if (isLatestAi) {
      items.push({ a: 'reroll',   t: '⇄', title: '重roll' });
      items.push({ a: 'continue', t: '››', title: '继续' });
    }
    items.push({ a: 'more', t: '⋯', title: '更多' });
    for (var i = 0; i < items.length; i++) {
      var b = document.createElement('button');
      b.className = 'act-btn';
      b.textContent = items[i].t;
      b.setAttribute('title', items[i].title);
      b.setAttribute('data-act', items[i].a);
      b.setAttribute('data-id', id);
      exp.appendChild(b);
    }
    var sp = document.createElement('span');
    sp.className = 'act-spacer';
    exp.appendChild(sp);
    var del = document.createElement('button');
    del.className = 'act-btn act-del';
    del.textContent = '✕';
    del.setAttribute('title', '删除');
    del.setAttribute('data-act', 'delete');
    del.setAttribute('data-id', id);
    exp.appendChild(del);
    // 收起按钮
    var close = document.createElement('button');
    close.className = 'act-btn act-close';
    close.textContent = '∨';
    close.setAttribute('title', '收起');
    close.setAttribute('data-collapse', id);
    exp.appendChild(close);

    tools.appendChild(exp);
    return tools;
  }

  function setMessages(b64, options) {
    try {
      var arr = JSON.parse(decodeB64Utf8(b64));
      var root = document.getElementById('root');
      
      // 头像+名字：存全局，所有气泡共享同一份，不重复解码
      if (options && options.avatars) {
        window.__avatars = options.avatars;
      }
      // initial: 初始渲染，清空root
      if (options && options.initial) {
        root.innerHTML = '';
      }

      for (var i = 0; i < arr.length; i++) {
        var m = arr[i];
        var group = document.createElement('div');
        group.className = 'msg-group ' + m.role;

        // 气泡上方头像+名字（AI左/用户右），system 不加
        var av = window.__avatars;
        if (av && (m.role === 'assistant' || m.role === 'user')) {
          var header = document.createElement('div');
          header.className = 'msg-header';
          var src = m.role === 'user' ? av.user : av.char;
          var nm = m.role === 'user' ? av.userName : av.charName;
          if (src) {
            var img = document.createElement('img');
            img.className = 'msg-avatar';
            img.src = src;
            header.appendChild(img);
          }
          var nameEl = document.createElement('span');
          nameEl.className = 'msg-name';
          nameEl.textContent = nm || '';
          header.appendChild(nameEl);
          group.appendChild(header);
        }

        var wrap = document.createElement('div');
        wrap.className = 'msg ' + m.role;
        wrap.setAttribute('data-id', m.id);

        if (m.reasoning) {
          var r = document.createElement('div');
          r.className = 'reasoning';
          r.innerHTML = m.reasoning;
          wrap.appendChild(r);
        }

        if (isRichHtml(m.html)) {
          var frame = document.createElement('iframe');
          frame.className = 'card-frame';
          frame.style.width = '100%';
          frame.style.height = '300px';
          frame.style.background = 'rgba(255,255,255,0.06)';
          frame.style.borderRadius = '18px';
          frame.setAttribute('data-frame-id', m.id);
          frame.setAttribute('scrolling', 'no');
          frame.setAttribute('data-html', m.html);
          (function(f, html, id){
            var injected = injectBridge(html, id);
            try {
              var blob = new Blob([injected], {type: 'text/html; charset=utf-8'});
              var url = URL.createObjectURL(blob);
              f.src = url;
              f.addEventListener('load', function onLoad(){
                f.removeEventListener('load', onLoad);
                URL.revokeObjectURL(url);
              });
            } catch(e) {
              f.srcdoc = injected;
            }
          })(frame, m.html, m.id);
          group.appendChild(frame);
        } else {
          var c = document.createElement('div');
          c.innerHTML = (m.html && m.html.trim() !== '')
            ? m.html
            : '<div class="thinking"><span class="star">⭐</span>思考中……</div>';
          wrap.appendChild(c);
          group.appendChild(wrap);
        }

        wrap.setAttribute('data-floor', m.floor || 0);
        if (m.floor) {
          group.appendChild(buildFloorTag(m.floor));
        }
        if (m.role === 'assistant' && m.swipeCount && m.swipeCount > 1) {
          group.appendChild(buildSwipeBar(m.id, m.swipeIndex, m.swipeCount));
        }
        group.appendChild(buildActions(m.id, m.isLatestAi));

        // prepend: 追加历史，插入头部
        if (options && options.prepend) {
          root.insertBefore(group, root.firstChild);
        } else {
          root.appendChild(group);
        }
      }

      if (options && !options.prepend) {
        scrollToBottomWhenStable();
      }
    } catch(e) {
      document.getElementById('root').innerText = 'ERR: ' + e;
    }
  }
  // 楼层编号标记：大圆角小长条 #xx
  function buildFloorTag(floor) {
    var tag = document.createElement('div');
    tag.className = 'floor-tag-wrap';
    var pill = document.createElement('span');
    pill.className = 'floor-tag';
    pill.textContent = '#' + floor;
    tag.appendChild(pill);
    return tag;
  }

  // 滚动到指定楼层
  function scrollToFloor(floor) {
    var el = document.querySelector('[data-floor="' + floor + '"]');
    if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  // 版本切换条：‹ 当前/总数 ›
  function buildSwipeBar(id, index, count) {
    var bar = document.createElement('div');
    bar.className = 'swipe-bar';
    var prev = document.createElement('button');
    prev.className = 'swipe-btn';
    prev.textContent = '‹';
    prev.setAttribute('data-act', 'swipePrev');
    prev.setAttribute('data-id', id);
    if (index <= 0) prev.disabled = true;
    var label = document.createElement('span');
    label.className = 'swipe-label';
    label.textContent = (index + 1) + ' / ' + count;
    var next = document.createElement('button');
    next.className = 'swipe-btn';
    next.textContent = '›';
    next.setAttribute('data-act', 'swipeNext');
    next.setAttribute('data-id', id);
    if (index >= count - 1) next.disabled = true;
    bar.appendChild(prev);
    bar.appendChild(label);
    bar.appendChild(next);
    return bar;
  }

  function scrollToBottomWhenStable() {
    var root = document.getElementById('root');

    // 立即滚到当前底部
    function snapBottom() {
      if (!__stickBottom) return; // 用户翻历史时不打扰
      __programScroll++; // 开闸：标记接下来是程序触发的滚动
      var last = root.lastElementChild;
      if (last) {
        last.scrollIntoView({behavior: 'instant', block: 'end'});
      } else {
        window.scrollTo(0, document.body.scrollHeight);
      }
      // 下一帧关闸，容忍这次程序滚动引发的 scroll 事件
      requestAnimationFrame(function () {
        if (__programScroll > 0) __programScroll--;
      });
    }

    snapBottom();

    // 异步内容（iframe 卡片 / 图片）加载完会改变文档高度，
    // 每个加载完成后补滚一次，避免撑开后视口相对上移（发送后"上跳"）
    var media = root.querySelectorAll('iframe, img');
    for (var i = 0; i < media.length; i++) {
      var el = media[i];
      // 已加载完的 img 直接跳过；未完成的挂 load 监听
      if (el.tagName === 'IMG' && el.complete) continue;
      el.addEventListener('load', snapBottom, {once: true});
      el.addEventListener('error', snapBottom, {once: true});
    }

    // 兜底：布局稳定需要几帧，延迟再补滚两次（仍受 __stickBottom 约束）
    requestAnimationFrame(snapBottom);
    setTimeout(snapBottom, 120);
    setTimeout(snapBottom, 400);
  }
  // 智能滚动跟随：记录用户是否贴在底部
  var __stickBottom = true;
  var __programScroll = 0; // 程序滚动闸门：>0 时忽略 scroll 事件，避免程序滚动把自己判成"离底"
  window.addEventListener('scroll', function () {
    if (__programScroll > 0) return; // 程序触发的滚动，不更新 stickBottom
    var nearBottom = (window.innerHeight + window.scrollY) >=
        (document.body.scrollHeight - 40);
    __stickBottom = nearBottom; // 只有真·用户滚动才更新
  });

  // 流式增量追加：只往这条消息的文本节点末尾加字，不重排整页
  function appendToken(id, token) {
    var wrap = document.querySelector('.msg[data-id="' + id + '"]');
    if (!wrap) return;
    var stream = wrap.querySelector('.stream-text');
    if (!stream) {
      wrap.innerHTML = '';
      stream = document.createElement('div');
      stream.className = 'stream-text';
      stream.style.whiteSpace = 'pre-wrap';
      wrap.appendChild(stream);
    }
    stream.textContent += token;
    if (__stickBottom) window.scrollTo(0, document.body.scrollHeight);
  }
  registerBridgeHandler('appendToken', function (p) {
    appendToken(p.id, p.token);
  });

  document.addEventListener('click', function(e) {
    var tgt = e.target;
    if (!tgt || !tgt.closest) return;

    // 展开
    var toggle = tgt.closest('.tools-toggle');
    if (toggle) {
      // 同时只开一个：先收起所有已展开的
      var opened = document.querySelectorAll('.msg-tools.open');
      for (var i = 0; i < opened.length; i++) opened[i].classList.remove('open');
      var box = toggle.closest('.msg-tools');
      if (box) box.classList.add('open');
      return;
    }
    // 收起
    var collapse = tgt.closest('[data-collapse]');
    if (collapse) {
      var box2 = collapse.closest('.msg-tools');
      if (box2) box2.classList.remove('open');
      return;
    }
    // 功能按钮（含气泡工具条 .act-btn 和版本切换 .swipe-btn）
    var b = tgt.closest('.act-btn') || tgt.closest('.swipe-btn');
    if (!b || !b.getAttribute('data-act')) return;
    if (b.disabled) return;
    sendToFlutter('action', {
      id: b.getAttribute('data-id'),
      action: b.getAttribute('data-act')
    });
  });

  registerBridgeHandler('setMessages', function(p) { setMessages(p.data, {initial: p.initial, prepend: p.prepend, avatars: p.avatars}); });
  registerBridgeHandler('scrollToFloor', function(p) { scrollToFloor(p.floor); });
  registerBridgeHandler('setImage', function(p) {
    try {
      var sel = '[data-att-path="' + p.path + '"]';
      var imgs = document.querySelectorAll(sel);
      for (var i = 0; i < imgs.length; i++) {
        (function(img){
          // 图片加载完成后，高度撑开会改变 body 高度；
          // 主动触发 reflow，让 WebView 重新计算滚动边界，否则会卡住无法上滑。
          img.onload = function(){
            void document.body.offsetHeight; // 强制 reflow
            window.dispatchEvent(new Event('resize'));
          };
          img.src = 'data:' + (p.mime || 'image/jpeg') + ';base64,' + p.b64;
        })(imgs[i]);
      }
    } catch(e) {
      parent.postMessage({__thLog:true, text:'[setImage] 失败: ' + e}, '*');
    }
  });
</script>
</body>
</html>
''';
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
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: const Text('✨', style: TextStyle(fontSize: 16)),
    );
  }
}