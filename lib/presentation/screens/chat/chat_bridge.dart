// KiraKira · Chat Bridge — unified WebView <-> Flutter communication bus.
//
// What this bridge does:
//
//   The chat message area is one full-screen WebView (single rendering engine
//   architecture). Flutter is the shell and brain; the WebView is the rendering
//   stage. All cooperation between the two — link taps, scroll syncing,
//   streaming token appends, message add/remove — goes through this single
//   bridge. Ad-hoc wiring elsewhere is forbidden.
//
//   Iron rule: every cross-boundary message must go through ChatBridge. Do not
//   call evaluateJavascript or open private callHandlers elsewhere. Adding an
//   interaction means adding a case to the routing table, not a new one-off line.
//
// Four long-standing rules (the stable foundation; do not dismantle them):
//
//   1. Unified protocol format
//      Every message is { type, payload, id }.
//      - type   : string; selects the handler (see _BridgeType).
//      - payload: Map; the data, whose format each type defines itself.
//      - id     : optional; pairs request with response (only calls that need
//                 a return value carry it).
//
//   2. Ready handshake + send queue (prevents dropped messages)
//      The WebView sends a 'ready' handshake when loading completes. Any
//      outbound command issued before the handshake is cached in the _outbox
//      queue and flushed in one pass afterwards. This eliminates the most
//      common intermittent bug of this architecture: commands sent before the
//      page is ready being dropped on the floor.
//
//   3. Unified exception fallback (fault isolation)
//      All inbound messages are wrapped in one try-catch at the entry point. A
//      handler that throws disables only that one interaction; it cannot take
//      down the bridge or blank the screen.
//
//   4. High-frequency event throttling
//      High-frequency reports such as scroll must be throttled on the WebView
//      side before sending; the bus must not carry flood-peak traffic. The
//      Flutter side also applies a debounce fallback for opt-in high-frequency
//      types.

import 'dart:async';
import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// All message types on the bus. Register a constant here first for any new
/// interaction so the routing table has a single source of truth and raw
/// strings do not scatter across the codebase.
class BridgeType {
  BridgeType._();

  // WebView -> Flutter (inbound)
  static const String ready = 'ready'; // handshake: WebView is ready
  static const String linkTap = 'linkTap'; // external link tapped
  static const String scroll = 'scroll'; // scroll position report (high frequency)
  static const String cardHeight = 'cardHeight'; // iframe card height report
  static const String log = 'log'; // WebView-side debug log
  static const String action = 'action'; // message bubble action button tapped
  static const String dialogResult = 'dialogResult'; // WebView -> Flutter: HTML dialog result (paired by callbackId)
  static const String modelSelected = 'modelSelected'; // WebView -> Flutter: model selected by the user
  static const String switchConfig = 'switchConfig'; // WebView -> Flutter: API scheme switched
  static const String panelAction = 'panelAction'; // WebView -> Flutter: function panel button tapped

  // Flutter -> WebView (outbound; corresponds to the handler names dispatched on the JS side)
  static const String setMessages = 'setMessages';
  static const String appendMessage = 'appendMessage';
  static const String appendToken = 'appendToken';
  static const String updateMessage = 'updateMessage';
  static const String removeMessage = 'removeMessage';
  static const String scrollToFloor = 'scrollToFloor'; // jump to a given floor
  static const String scrollToBottom = 'scrollToBottom'; // scroll to latest message (JS-side handler, also used as fallback for the scroll-to-bottom button)
  static const String keyboardInsets = 'keyboardInsets'; // keyboard visibility push: JS adds/removes bottom padding on body so the latest message hidden by the keyboard can scroll into view
  static const String topBarInsets = 'topBarInsets'; // top bar visibility push: JS adjusts body padding-top to give the top bar's strip of space to the message area (without resizing the platform view)
  // HTML dialog system: dialogs render inside the WebView together with messages,
  // avoiding the hardware composer overhead of stacking Flutter layers
  static const String showConfirm = 'showConfirm'; // Dart->JS: HTML confirm dialog
  static const String showPrompt = 'showPrompt'; // Dart->JS: HTML input dialog
  static const String showBottomSheet = 'showBottomSheet'; // Dart->JS: HTML bottom selection sheet
  static const String setImage = 'setImage'; // push image base64 separately to keep setMessages payloads small
  static const String setMessageTranslation = 'setMessageTranslation'; // push a message translation (rendered as light small text below the bubble)
  static const String setGenerating = 'setGenerating'; // insert a "generating" placeholder (per request)
  static const String clearGenerating = 'clearGenerating'; // remove the "generating" placeholder
  static const String setGenerateProgress = 'setGenerateProgress'; // update placeholder progress
  static const String showModelSheet = 'showModelSheet'; // open the model selection HTML layer (with model data)
  static const String hideModelSheet = 'hideModelSheet'; // close the model selection HTML layer
  static const String openFunctionPanel = 'openFunctionPanel'; // open the function panel (with context data)
  static const String closeFunctionPanel = 'closeFunctionPanel'; // close the function panel
  static const String panelClosed = 'panelClosed'; // WebView -> Flutter: panel closed (state sync)
  // Worldbook API (inbound request-response)
  static const String wiGetLorebooks = 'th_wiGetLorebooks';
  static const String wiGetEntries = 'th_wiGetEntries';
  static const String wiSetEntries = 'th_wiSetEntries';
  static const String wiCreateEntries = 'th_wiCreateEntries';
  static const String wiDeleteEntries = 'th_wiDeleteEntries';
  static const String wiGetCharLorebooks = 'th_wiGetCharLorebooks';
  static const String response = 'th_response'; // request-response reply (paired by id)

  // Prompt management (inbound request-response)
  static const String pmGetSections = 'th_pmGetSections';       // read the current section list
  static const String pmToggleSection = 'th_pmToggleSection';   // toggle a section on/off
  // Prompt management (outbound push: Dart -> JS)
  static const String pmSectionsChanged = 'pmSectionsChanged';  // pushed to the frontend when the section list changes
  // MVU extensionSettings persistence (Daoyuan/MVU panel write-back to disk)
  static const String saveExtensionSettings = 'th_saveExtensionSettings';
  // Preset management API (Hushen preset read/write: getPreset/updatePresetWith etc.)
  static const String getPresetNames = 'th_getPresetNames';
  static const String getPreset = 'th_getPreset';
  static const String setPreset = 'th_setPreset';
  static const String getLoadedPresetName = 'th_getLoadedPresetName';
  // Generation control (Hushen auto-advance/stop)
  static const String generate = 'th_generate';
  static const String stopGeneration = 'th_stopGeneration';

  // Settings panel, rendered as a dialog (Dart->JS outbound + JS->Dart inbound)
  static const String openSettingsPanel = 'openSettingsPanel';    // Dart->JS: open the settings panel (with panel name + title + initial data)
  static const String closeSettingsPanel = 'closeSettingsPanel';   // Dart->JS: close the settings panel
  static const String settingsPanelAction = 'settingsPanelAction'; // JS->Dart: in-panel action (save/toggle/select/delete etc.)
  static const String settingsPanelClosed = 'settingsPanelClosed'; // JS->Dart: panel closed (state sync)
  static const String settingsPanelData = 'settingsPanelData';     // Dart->JS: push updated data (e.g. after an async operation completes)

  // Layout variable injection + dynamic island notifications + input bar + STT bridging (all over ChatBridge)
  static const String layoutVars = 'layoutVars';       // Dart->JS: injects --keyboard-height / --status-bar-height / --nav-bar-height / --app-viewport-height / --safe-area-* CSS variables
  static const String showToast = 'showToast';         // Dart->JS: triggers bottom dynamic island notification (icon+text)
  static const String inputBarState = 'inputBarState'; // Dart->JS: pushes input bar state (generating/hasInput/attachments/sttEnabled etc.) for the WebView to render button states
  static const String sttResult = 'sttResult';         // Dart->JS: pushes STT recognition result (text) for the WebView to fill into the textarea
  static const String sendResult = 'sendResult';       // Dart->JS: pushes send result (success/failure + reason); WebView shows a toast
  // JS->Dart inbound
  static const String inputSend = 'inputSend';         // JS->Dart: send button tapped in the WebView input bar (payload.text)
  static const String inputStop = 'inputStop';         // JS->Dart: stop button tapped in the WebView input bar
  static const String inputUpload = 'inputUpload';     // JS->Dart: image upload button tapped in the WebView
  static const String inputFunc = 'inputFunc';         // JS->Dart: function menu button tapped in the WebView
  static const String openSessionImages = 'openSessionImages'; // JS->Dart: WebView requests opening the session images page
  static const String sttStart = 'sttStart';           // JS->Dart: long press in the WebView starts STT
  static const String sttStop = 'sttStop';             // JS->Dart: release in the WebView stops STT
  static const String inputRemoveAttachment = 'inputRemoveAttachment'; // JS->Dart: WebView input bar removes a pending image attachment (index)
}


/// Handler signature for a single inbound message.
typedef BridgeHandler = void Function(Map<String, dynamic> payload);
/// Request handler signature with a return value. Returns a Future; the bridge
/// sends the result back to the WebView under the same id.
typedef BridgeRequestHandler = Future<dynamic> Function(
    Map<String, dynamic> payload);

/// Unified WebView <-> Flutter communication bus.
///
/// Usage:
///   final bridge = ChatBridge(onLog: (m) => debugPrint('[bridge] $m'));
///   bridge.on(BridgeType.linkTap, (p) => launchUrl(p['url']));
///   // inside InAppWebView's onWebViewCreated:
///   bridge.attach(controller);
///   // send (automatically queued before the handshake):
///   bridge.send(BridgeType.setMessages, {'data': b64});
class ChatBridge {
  ChatBridge({this.onLog});

  /// Optional log callback. It is the entry point's global observability:
  /// all cross-boundary traffic is visible here when diagnosing production
  /// issues.
  final void Function(String message)? onLog;

  InAppWebViewController? _controller;
  bool _ready = false;

  /// Send queue: outbound commands issued before the handshake completes are
  /// stored here to prevent message loss (rule 2).
  final List<_OutboundMessage> _outbox = [];

  /// Inbound routing table: type -> handler (where rules 1 and 3 land).
  final Map<String, BridgeHandler> _handlers = {};
  /// Request-response routing table: type -> handler with a return value
  /// (activates the id slot reserved by the protocol).
  final Map<String, BridgeRequestHandler> _requestHandlers = {};

  /// Debounce fallback timers for high-frequency types (rule 4).
  final Map<String, Timer> _throttleTimers = {};

  /// Registers an inbound message handler. Re-registering the same type
  /// overwrites the previous one, allowing hot replacement of logic.
  void on(String type, BridgeHandler handler) {
    _handlers[type] = handler;
  }
  /// Registers a request-response handler. Coexists with [on] for calls that
  /// need a return value (e.g. getChatMessages / getVariables). The handler's
  /// result is sent back to the waiting WebView Promise under the same id.
  void onRequest(String type, BridgeRequestHandler handler) {
    _requestHandlers[type] = handler;
  }

  /// Attaches the bus to the WebView controller. Call once in
  /// onWebViewCreated.
  ///
  /// The WebView side only sends via
  /// window.flutter_inappwebview.callHandler('bridge', msg), where msg is the
  /// JSON of { type, payload, id }.
  void attach(InAppWebViewController controller) {
    _controller = controller;
    controller.addJavaScriptHandler(
      handlerName: 'bridge',
      callback: (args) => _onInbound(args),
    );
  }

  /// Single inbound entry point: unified parsing + exception fallback (rule 3).
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
      // id is accepted in either location: top-level msg['id'], or
      // __requestId inside the payload (JS __sendRequest puts the id into the
      // payload, so both are recognized here).
      final String? id =
          (msg['id'] as String?) ?? (payload['__requestId'] as String?);

      // Handshake: the WebView is ready, flush the send queue (rule 2).
      if (type == BridgeType.ready) {
        _onReady();
        return;
      }

      onLog?.call('◀ inbound  $type  $payload  ${id ?? ""}');

      // Has an id and a registered request handler -> take the
      // request-response path and send the result back once handled.
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
      // A single failing message must not take down the whole bridge.
      onLog?.call('✖ inbound error: $e\n$st');
    }
  }
  /// Runs the request handler and sends the result back under the same id.
  /// Errors are sent back too, so the WebView-side Promise never hangs
  /// permanently (rule 3 extended: requests need a fallback as well).
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
  /// Fuse: when the JS ready signal is lost (common on old WebViews), an
  /// external timeout force-flushes the queue. If already ready it is a
  /// no-op, with zero impact on healthy pages.
  void markReadyIfMissing() {
    if (_ready) return;              // already ready, skip
    if (_controller == null) return; // controller not ready, do nothing
    onLog?.call('⏰ ready 信号缺失，超时保险触发，强制放行队列');
    _onReady();                      // reuse the same handshake-complete logic
  }

  /// Sends an outbound command to the WebView. Queued automatically until the
  /// handshake completes (rule 2).
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
      // U+2028/U+2029 are illegal in JS string literals before ES2019, and
      // dart:convert's jsonEncode does not escape them by default, so on old
      // Android WebViews the whole injected line becomes a SyntaxError.
      // Escape them explicitly as \u2028 / \u2029 in the final injected string
      // (purely defensive; protocol and semantics unchanged).
      json = json
          .replaceAll('\u2028', r'\u2028')
          .replaceAll('\u2029', r'\u2029');
      // The WebView side implements a global dispatch(jsonString) as the
      // outbound router.
      _controller?.evaluateJavascript(
        source: 'window.__bridgeDispatch(${jsonEncode(json)});',
      );
    } catch (e) {
      onLog?.call('✖ outbound error ($type): $e');
    }
  }

  /// Flutter-side debounce fallback for high-frequency events (rule 4).
  /// Real peak-shaving belongs on the WebView side; this is only a
  /// second line of defense.
  void throttle(String key, Duration window, void Function() action) {
    _throttleTimers[key]?.cancel();
    _throttleTimers[key] = Timer(window, action);
  }

  /// Cleans up on page teardown to prevent Timer leaks.
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