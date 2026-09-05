// ─────────────────────────────────────────────────────────────────────────
//  KiraKira · Chat Bridge  (WebView ↔ Flutter 统一通信总线)
// ─────────────────────────────────────────────────────────────────────────
//
//  你好，路过的开发者 👋
//
//  我是北辰星（NorthStar），KiraKira 的作者。这是一个基于 NativeTavern
//  衍生、向 SillyTavern 看齐的开源 AI 角色扮演客户端。我做它，是想让手机上
//  跑重前端角色卡这件事，能够真正地流畅、优雅，而不是卡成幻灯片。
//
//  我的设计理念很简单：把复杂留给架构，把顺手留给用户和后来的开发者。
//  如果你正在读这段注释，说明你也在乎这份代码的长期健康 —— 谢谢你，
//  欢迎一起把它做得更好。开源的魅力，就在于此。
//
// ─────────────────────────────────────────────────────────────────────────
//  这座桥是干什么的
// ─────────────────────────────────────────────────────────────────────────
//
//  聊天消息区是一整个全屏 WebView（单渲染引擎架构）。Flutter 是外壳与大脑，
//  WebView 是渲染舞台。两者之间的一切协作 —— 点链接、滚动联动、流式追加
//  token、消息增删 —— 全部只走这一座桥，绝不允许零散地各接各的。
//
//  ⚠️ 铁律：任何跨端通信都必须走 ChatBridge，禁止在别处直接
//     evaluateJavascript / 私开 callHandler。散装接法是屎山的起点。
//     新增交互 = 往路由表里加一个 case，而不是新拉一条线。
//
// ─────────────────────────────────────────────────────────────────────────
//  四条立在前面的规矩（长期稳定的地基，别拆）
// ─────────────────────────────────────────────────────────────────────────
//
//  1. 统一协议格式
//     每条消息都是 { type, payload, id }。
//     - type   : 字符串，决定路由到哪个处理器（见 _BridgeType）。
//     - payload: Map，具体数据，格式由各 type 自行约定。
//     - id     : 可选，用于请求-响应配对（需要回值的调用才带）。
//
//  2. 就绪握手 + 发送队列（防丢消息）
//     WebView 加载完会发 'ready' 握手。握手前 Flutter 要发的指令一律先
//     进 _outbox 队列缓存，握手后一次性冲刷。这样解决"页面还没好就发指令
//     导致消息掉地上"这个此类架构最常见的偶发 bug。
//
//  3. 统一异常兜底（故障隔离）
//     所有入站消息在总入口统一 try-catch。单个 handler 抛异常只会让那一个
//     交互失效，不会拖垮整座桥、更不会白屏。
//
//  4. 高频事件节流
//     滚动等高频回传必须在 WebView 侧先节流再发，别让总线当洪峰搬运工。
//     Flutter 侧这里也对可选的高频 type 做二次防抖兜底。
//
// ─────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// 总线上所有消息的类型。新增交互先在这里登记一个常量，
/// 让路由表有据可查，避免裸字符串散落各处。
class BridgeType {
  BridgeType._();

  // WebView → Flutter（入站）
  static const String ready = 'ready'; // 握手：WebView 准备就绪
  static const String linkTap = 'linkTap'; // 点击外部链接
  static const String scroll = 'scroll'; // 滚动位置回传（高频）
  static const String cardHeight = 'cardHeight'; // iframe 卡片高度上报
  static const String log = 'log'; // WebView 侧调试日志
  static const String action = 'action'; // 气泡操作按钮点击
  static const String modelSelected = 'modelSelected'; // WebView回传:用户选中的模型
  static const String switchConfig = 'switchConfig'; // WebView回传:切换API方案
  static const String panelAction = 'panelAction'; // WebView回传:功能面板按钮点击

  // Flutter → WebView（出站，对应 JS 侧 dispatch 的 handler 名）
  static const String setMessages = 'setMessages';
  static const String appendMessage = 'appendMessage';
  static const String appendToken = 'appendToken';
  static const String updateMessage = 'updateMessage';
  static const String removeMessage = 'removeMessage';
  static const String scrollToFloor = 'scrollToFloor'; // 跳转到指定楼层
  static const String setImage = 'setImage'; // 单独推送图片base64，避免撑爆setMessages
  static const String setGenerating = 'setGenerating'; // 插入"生成中"占位(请求比例)
  static const String clearGenerating = 'clearGenerating'; // 移除"生成中"占位
  static const String setGenerateProgress = 'setGenerateProgress'; // 更新占位符进度
  static const String showModelSheet = 'showModelSheet'; // 弹出模型选择HTML层(带模型数据)
  static const String hideModelSheet = 'hideModelSheet'; // 关闭模型选择HTML层
  static const String openFunctionPanel = 'openFunctionPanel'; // 打开功能面板(带上下文数据)
  static const String closeFunctionPanel = 'closeFunctionPanel'; // 关闭功能面板
  static const String panelClosed = 'panelClosed'; // WebView回传:面板已关闭(同步状态)
  // 世界书 API（入站请求-响应）
  static const String wiGetLorebooks = 'th_wiGetLorebooks';
  static const String wiGetEntries = 'th_wiGetEntries';
  static const String wiSetEntries = 'th_wiSetEntries';
  static const String wiCreateEntries = 'th_wiCreateEntries';
  static const String wiDeleteEntries = 'th_wiDeleteEntries';
  static const String wiGetCharLorebooks = 'th_wiGetCharLorebooks';
  static const String response = 'th_response'; // 请求-响应回传（带 id 配对）

  // [P3-K2] 提示词管理（入站请求-响应）
  static const String pmGetSections = 'th_pmGetSections';       // 读取当前 sections 列表
  static const String pmToggleSection = 'th_pmToggleSection';   // 切换某 section 开关
  // [P3-K2] 提示词管理（出站推送：Dart → JS）
  static const String pmSectionsChanged = 'pmSectionsChanged';  // sections 列表变化时推给球
  // [P5-8/P1] MVU extensionSettings 持久化(道渊/MVU 面板写回落盘)
  static const String saveExtensionSettings = 'th_saveExtensionSettings';
  // [P5-9/P1] 预设管理 API(狐神读写预设:getPreset/updatePresetWith 等)
  static const String getPresetNames = 'th_getPresetNames';
  static const String getPreset = 'th_getPreset';
  static const String setPreset = 'th_setPreset';
  static const String getLoadedPresetName = 'th_getLoadedPresetName';
}


/// 单条入站消息的处理器签名。
typedef BridgeHandler = void Function(Map<String, dynamic> payload);
/// 带返回值的请求处理器签名。返回 Future，桥用同一 id 把结果回传 WebView。
typedef BridgeRequestHandler = Future<dynamic> Function(
    Map<String, dynamic> payload);

/// WebView ↔ Flutter 的统一通信总线。
///
/// 用法：
///   final bridge = ChatBridge(onLog: (m) => debugPrint('[bridge] $m'));
///   bridge.on(BridgeType.linkTap, (p) => launchUrl(p['url']));
///   // 在 InAppWebView 的 onWebViewCreated 里：
///   bridge.attach(controller);
///   // 发送（握手前会自动排队）：
///   bridge.send(BridgeType.setMessages, {'data': b64});
class ChatBridge {
  ChatBridge({this.onLog});

  /// 可选日志回调。总入口的全局可观测性就靠它 —— 排查线上问题时，
  /// 所有跨端通信在这里一览无余。
  final void Function(String message)? onLog;

  InAppWebViewController? _controller;
  bool _ready = false;

  /// 发送队列：握手完成前的出站指令都先存这里，防丢消息（规矩 2）。
  final List<_OutboundMessage> _outbox = [];

  /// 入站路由表：type -> handler（规矩 1、3 的落点）。
  final Map<String, BridgeHandler> _handlers = {};
  /// 请求-响应路由表：type -> 带返回值的 handler（激活协议里预留的 id 位）。
  final Map<String, BridgeRequestHandler> _requestHandlers = {};

  /// 高频 type 的防抖兜底计时器（规矩 4）。
  final Map<String, Timer> _throttleTimers = {};

  /// 注册一个入站消息处理器。同一 type 重复注册会覆盖，便于热替换逻辑。
  void on(String type, BridgeHandler handler) {
    _handlers[type] = handler;
  }
  /// 注册一个"请求-响应"式处理器。与 on 并存，用于需要回值的调用
  /// （如 getChatMessages / getVariables）。handler 返回的结果会用
  /// 同一 id 回传给 WebView 侧等待的 Promise。
  void onRequest(String type, BridgeRequestHandler handler) {
    _requestHandlers[type] = handler;
  }

  /// 把总线挂到 WebView 控制器上。在 onWebViewCreated 里调用一次。
  ///
  /// WebView 侧只需通过 window.flutter_inappwebview.callHandler('bridge', msg)
  /// 发送，msg 为 { type, payload, id } 的 JSON。
  void attach(InAppWebViewController controller) {
    _controller = controller;
    controller.addJavaScriptHandler(
      handlerName: 'bridge',
      callback: (args) => _onInbound(args),
    );
  }

  /// 入站总入口：统一解析 + 异常兜底（规矩 3）。
  void _onInbound(List<dynamic> args) {
    try {
      if (args.isEmpty) return;
      final raw = args.first;
      final Map<String, dynamic> msg = raw is String
          ? Map<String, dynamic>.from(jsonDecode(raw) as Map)
          : Map<String, dynamic>.from(raw as Map);
      final String type = msg['type'] as String? ?? '';
      final Map<String, dynamic> payload =
          (msg['payload'] as Map?)?.cast<String, dynamic>() ?? {};
      // id 兼容两种位置：顶层 msg['id']，或 payload 里的 __requestId
      // （JS __sendRequest 把 id 塞进了 payload，这里一并认）
      final String? id =
          (msg['id'] as String?) ?? (payload['__requestId'] as String?);

      // 握手：WebView 就绪，冲刷发送队列（规矩 2）。
      if (type == BridgeType.ready) {
        _onReady();
        return;
      }

      onLog?.call('◀ inbound  $type  $payload  ${id ?? ""}');

      // 带 id 且注册了请求处理器 → 走请求-响应路径，处理完回传结果。
      if (id != null) {
        final reqHandler = _requestHandlers[type];
        if (reqHandler != null) {
          _handleRequest(type, id, payload, reqHandler);
          return;
        }
      }

      final handler = _handlers[type];
      if (handler == null) {
        onLog?.call('⚠ no handler for "$type" (ignored)');
        return;
      }
      handler(payload);
    } catch (e, st) {
      // 单个消息出错不拖垮整座桥。
      onLog?.call('✖ inbound error: $e\n$st');
    }
  }
  /// 执行请求处理器并把结果用同一 id 回传。异常也回传，避免 WebView 侧
  /// 的 Promise 永久挂起（规矩 3 的延伸：请求也要有兜底）。
  Future<void> _handleRequest(
    String type,
    String id,
    Map<String, dynamic> payload,
    BridgeRequestHandler handler,
  ) async {
    try {
      final result = await handler(payload);
      send(BridgeType.response, {'id': id, 'ok': true, 'result': result});
    } catch (e) {
      onLog?.call('✖ request error ($type): $e');
      send(BridgeType.response, {'id': id, 'ok': false, 'error': '$e'});
    }
  }

  void _onReady() {
    _ready = true;
    onLog?.call('✔ WebView ready, flushing ${_outbox.length} queued message(s)');
    final queued = List<_OutboundMessage>.from(_outbox);
    _outbox.clear();
    for (final m in queued) {
      _dispatch(m.type, m.payload);
    }
  }
  /// 保险丝：JS ready 信号丢失时（老 WebView 常见），外部超时强制放行。
  /// 已 ready 则直接跳过，对正常机器零影响。
  void markReadyIfMissing() {
    if (_ready) return;              // 新机器早已 ready，直接跳过
    if (_controller == null) return; // 控制器没就绪就不动
    onLog?.call('⏰ ready 信号缺失，超时保险触发，强制放行队列');
    _onReady();                      // 复用同一套握手完成逻辑
  }

  /// 发送出站指令给 WebView。握手未完成则自动入队（规矩 2）。
  void send(String type, Map<String, dynamic> payload) {
    if (!_ready || _controller == null) {
      _outbox.add(_OutboundMessage(type, payload));
      onLog?.call('… queued  $type  (not ready)');
      return;
    }
    _dispatch(type, payload);
  }

  void _dispatch(String type, Map<String, dynamic> payload) {
    try {
      onLog?.call('▶ outbound $type');
      var json = jsonEncode({'type': type, 'payload': payload});
      // [P1-A3] U+2028/U+2029 在 ES2019 之前的 JS 字符串字面量里非法，
      // 而 dart:convert 的 jsonEncode 默认不转义它们 → 旧 Android WebView 上整条注入 SyntaxError。
      // 在最终注入字符串里把它们显式转义为 \u2028 / \u2029（纯防御，不改变协议与语义）。
      json = json
          .replaceAll('\u2028', r'\u2028')
          .replaceAll('\u2029', r'\u2029');
      // WebView 侧实现一个全局 dispatch(jsonString) 做出站路由。
      _controller?.evaluateJavascript(
        source: 'window.__bridgeDispatch(${jsonEncode(json)});',
      );
    } catch (e) {
      onLog?.call('✖ outbound error ($type): $e');
    }
  }

  /// 高频事件的 Flutter 侧防抖兜底（规矩 4）。
  /// 真正的削峰应在 WebView 侧先做，这里只是双保险。
  void throttle(String key, Duration window, void Function() action) {
    _throttleTimers[key]?.cancel();
    _throttleTimers[key] = Timer(window, action);
  }

  /// 页面销毁时清理，防止 Timer 泄漏。
  void dispose() {
    for (final t in _throttleTimers.values) {
      t.cancel();
    }
    _throttleTimers.clear();
    _outbox.clear();
    _handlers.clear();
    _controller = null;
    _ready = false;
  }
}

class _OutboundMessage {
  _OutboundMessage(this.type, this.payload);
  final String type;
  final Map<String, dynamic> payload;
}