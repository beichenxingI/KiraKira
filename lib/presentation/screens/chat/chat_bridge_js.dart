// KiraKira · Chat Bridge (WebView / JS side)
//
// This is the WebView end of the communication bus, strictly symmetric with
// chat_bridge.dart (the Flutter side). Both share one protocol: every message
// is { type, payload, id }.
//
// The iron rule applies here too: anything in the WebView that must notify
// Flutter goes through sendToFlutter(type, payload) only; any command coming
// from Flutter is handled only by a handler registered in __bridgeHandlers.
// No private side channels.
//
// Responsibilities:
//   1. Outbound routing: __bridgeDispatch(json) receives Flutter commands and
//      dispatches them by type.
//   2. Inbound send: sendToFlutter(type, payload) formats and sends to Flutter.
//   3. Handshake: after load, sendToFlutter('ready') triggers the Flutter-side
//      queue flush.
//
// Usage: insert this kChatBridgeJs string into the <script> of _htmlShell.
//
// See the design notes and the four rules at the top of chat_bridge.dart.

/// JS source of the WebView-side communication bus, injected into the chat
/// page HTML <script>.
// The runtime now uses assets/chat/chat_bridge.js instead; this constant is
// inactive and editing it has no effect.
const String kChatBridgeJs = r'''
(function () {
  // Inbound routing table: type -> handler. Business code adds entries via
  // registerBridgeHandler.
  var __bridgeHandlers = {};

  // Registers a handler for a command from Flutter (corresponds to the
  // outbound types in BridgeType).
  window.registerBridgeHandler = function (type, fn) {
    __bridgeHandlers[type] = fn;
  };

  // Outbound routing: Flutter dispatches commands through this function.
  // Flutter's _dispatch sends a jsonEncode({type,payload}) string.
  window.__bridgeDispatch = function (jsonStr) {
    try {
      var msg = JSON.parse(jsonStr);
      var fn = __bridgeHandlers[msg.type];
      if (fn) {
        fn(msg.payload || {});
      } else {
        sendToFlutter('log', { text: 'no JS handler for "' + msg.type + '"' });
      }
    } catch (e) {
      console.error('[dispatch错误] type=' + (jsonStr ? jsonStr.slice(0, 80) : '?') + ' err=' + e + (e && e.stack ? '\n' + e.stack : ''));
      sendToFlutter('log', { text: 'dispatch error: ' + e });
    }
  };

  // Inbound send: every WebView-side notification to Flutter goes through
  // here.
  window.sendToFlutter = function (type, payload) {
    try {
      var msg = { type: type, payload: payload || {} };
      if (window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler('bridge', JSON.stringify(msg));
      }
    } catch (e) {
      // A communication failure must not crash the page; fail silently (the
      // Flutter side times out on its own if nothing arrives).
    }
  };

  // High-frequency event throttler: events such as scroll must be
  // peak-shaved here before sending (rule 4).
  // Usage: throttleSend('scroll', 100, function(){ return {top: ...}; })
  var __throttleTimers = {};
  window.throttleSend = function (type, ms, payloadFn) {
    if (__throttleTimers[type]) return; // already queued within the window; drop
    __throttleTimers[type] = setTimeout(function () {
      __throttleTimers[type] = null;
      sendToFlutter(type, payloadFn());
    }, ms);
  };

  // Handshake: notify Flutter once the page is ready, triggering the send
  // queue flush (rule 2).
  function fireReady() {
    sendToFlutter('ready', {});
  }
  if (document.readyState === 'complete') {
    fireReady();
  } else {
    window.addEventListener('load', fireReady);
  }

  // Tavern helper API: request-response Promise waiting table.
  // Every helper function that needs a return value uses this mechanism:
  // 1. Generate a unique id and store resolve/reject in __pendingRequests
  // 2. Send the request to Flutter via sendToFlutter (carrying the id)
  // 3. Flutter replies with th_response once handled (payload carries the
  //    same id)
  // 4. __bridgeDispatch resolves/rejects by id when th_response arrives
  var __pendingRequests = {};
  var __nextRequestId = 1;

  window.__sendRequest = function __sendRequest(type, payload) {
    return new Promise(function (resolve, reject) {
      var id = 'req_' + (__nextRequestId++);
      __pendingRequests[id] = { resolve: resolve, reject: reject };
      // Timeout fallback: reject after 30 s without a response so the
      // Promise never hangs indefinitely.
      setTimeout(function () {
        if (__pendingRequests[id]) {
          delete __pendingRequests[id];
          reject(new Error('request timeout: ' + type));
        }
      }, 30000);
      sendToFlutter(type, Object.assign({}, payload, { __requestId: id }));
    });
  }

  // th_response dispatch: Flutter returns the result; find the waiting
  // Promise by id.
  registerBridgeHandler('th_response', function (payload) {
    var id = payload.id;
    var pending = __pendingRequests[id];
    if (!pending) return;
    delete __pendingRequests[id];
    if (payload.ok) {
      pending.resolve(payload.result);
    } else {
      pending.reject(new Error(payload.error || 'request failed'));
    }
  });

  // Tavern helper global API.
  // First-tier high-frequency functions covering most interaction-card needs.
  // Function signatures align with SillyTavern's TavernHelper where possible
  // to lower the cost of porting cards.

  /// getChatMessages(startIndex, options?)
  ///   Reads the current session messages. startIndex=0 reads all from the
  ///   start. With options.include_swipe=true it returns the full swipes
  ///   array. Returns Promise<Array>, aligned with TavernHelper format:
  ///   [{ id, role, content, swipes, swipe_id, is_user }, ...]
  window.getChatMessages = function (startIndex, options) {
    return __sendRequest('th_getMessages', {
      start: startIndex || 0,
      include_swipe: (options && options.include_swipe) || false,
    });
  };

  /// setChatMessage(content, index, options?)
  ///   Edits the message content at the given floor (message index) or
  ///   switches its swipe.
  ///   options.swipe_id  : switch to the nth swipe (0-based)
  ///   options.refresh   : true triggers a WebView re-render
  window.setChatMessage = function (content, index, options) {
    return __sendRequest('th_setMessage', {
      index: index,
      content: content,
      swipe_id: options && options.swipe_id,
      refresh: (options && options.refresh) || false,
    });
  };

  /// triggerSlash(command)
  ///   Executes a slash command, e.g. '/send hello' '/setvar key=val' '/gen'.
  ///   Returns Promise<string | null> (/gen-style commands return the
  ///   generation result; the rest return null).
  window.triggerSlash = function (command) {
    return __sendRequest('th_triggerSlash', { command: command });
  };

  /// getVariables(options?)
  ///   Reads the current session variable table. options.key reads a single
  ///   variable only.
  ///   Returns Promise<object | string>.
  window.getVariables = function (options) {
    return __sendRequest('th_getVars', {
      key: options && options.key,
    });
  };

  /// setVariables(vars, options?)
  ///   Writes variables. vars is a { key: value } object.
  ///   Returns Promise<void>.
  window.setVariables = function (vars, options) {
    return __sendRequest('th_setVars', { vars: vars });
  };

})();
''';