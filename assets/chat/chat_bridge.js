
(function () {
  // Inbound routing table: type -> handler. Feature code registers via registerBridgeHandler.
  var __bridgeHandlers = {};

  // Register a handler for a Flutter command (mirrors an outbound BridgeType).
  window.registerBridgeHandler = function (type, fn) {
    __bridgeHandlers[type] = fn;
  };

  // Outbound routing: Flutter dispatches commands by calling this via evaluateJavascript.
  // _dispatch on the Flutter side sends a jsonEncode({type,payload}) string.
  window.__bridgeDispatch = function (jsonStr) {
    var msg;
    try {
      msg = JSON.parse(jsonStr);
    } catch (e) {
      // Entry JSON.parse has its own guard: keeps parse errors out of handler logic and
      // stops the exception from bubbling up and killing the whole dispatch.
      var s = (typeof jsonStr === 'string') ? jsonStr : String(jsonStr);
      console.error('[WV-9] DISPATCH-PARSE-FAIL len=' + s.length + ' ' + e);
      try {
        var root = document.getElementById('root');
        if (root && !root.firstChild) {
          var dbg = document.createElement('div');
          dbg.className = 'msg system';
          dbg.style.color = '#B8BEC8';
          dbg.textContent = '收到无法解析的指令（已忽略）。';
          root.appendChild(dbg);
        }
      } catch (_dbg) {}
      return;
    }
    try {
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

  // Inbound send: everything in the WebView that must notify Flutter goes through here.
  window.sendToFlutter = function (type, payload) {
    try {
      // Perf: drop debug-log traffic in release builds at the source. Every
      // sendToFlutter('log') used to cross the bridge (jsonDecode + onLog debugPrint
      // on the Dart side); the 'log' handler is pure observability — no functional
      // behavior depends on it — so log noise only needs to exist in debug builds.
      // window.__kiraDebug is baked in from kDebugMode (see chat_stage.html head)
      // and is assigned before this script runs (bridge is embedded further down).
      if (type === 'log' && !window.__kiraDebug) return;
      var msg = { type: type, payload: payload || {} };
      if (window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler('bridge', JSON.stringify(msg));
      }
    } catch (e) {
      // A comms failure must never crash the page; fail silently (the Flutter side times out on its own).
    }
  };

  // Throttle for high-frequency events: scroll etc. must be peak-clamped here before sending (rule 4).
  // Usage: throttleSend('scroll', 100, function(){ return {top: ...}; })
  var __throttleTimers = {};
  window.throttleSend = function (type, ms, payloadFn) {
    if (__throttleTimers[type]) return; // already queued in this window; drop
    __throttleTimers[type] = setTimeout(function () {
      __throttleTimers[type] = null;
      sendToFlutter(type, payloadFn());
    }, ms);
  };

  // Handshake: notify Flutter once the page is ready so it flushes its send queue (rule 2).
  function fireReady() {
    sendToFlutter('ready', {});
  }
  if (document.readyState === 'complete') {
    fireReady();
  } else {
    window.addEventListener('load', fireReady);
  }

  // Tavern Helper API: request/response pending table.
  // Every helper that returns a value uses this mechanism:
  // 1. Generate a unique id and store resolve/reject in __pendingRequests
  // 2. Send the request to Flutter via sendToFlutter (carrying the id)
  // 3. Flutter replies with th_response (payload carries the same id)
  // 4. __bridgeDispatch resolves/rejects the matching entry on th_response
  var __pendingRequests = {};
  var __nextRequestId = 1;

  window.__sendRequest = function __sendRequest(type, payload) {
    return new Promise(function (resolve, reject) {
      var id = 'req_' + (__nextRequestId++);
      __pendingRequests[id] = { resolve: resolve, reject: reject };
      // Timeout fallback: reject after 120s so the Promise never hangs forever.
      // Raised from 30s to 120s because th_popup waits on user dialog interaction,
      // and 30s would spuriously kill confirmation dialogs.
      setTimeout(function () {
        if (__pendingRequests[id]) {
          delete __pendingRequests[id];
          reject(new Error('request timeout: ' + type));
        }
      }, 120000);
      sendToFlutter(type, Object.assign({}, payload, { __requestId: id }));
    });
  }

  // th_response dispatch: Flutter returns a result; look up the waiting Promise by id.
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

  // Tavern Helper global API.
  // First-tier, high-frequency functions covering most interaction cards.
  // Signatures follow SillyTavern's TavernHelper as closely as possible to
  // keep card porting cost low.

  /// getChatMessages(startIndex, options?)
  ///   Read the current chat messages. startIndex=0 reads everything from the start.
  ///   options.include_swipe=true returns the full swipes array.
  ///   Returns Promise<Array> in Tavern Helper format:
  ///   [{ id, role, content, swipes, swipe_id, is_user }, ...]
  window.getChatMessages = function (startIndex, options) {
    return __sendRequest('th_getMessages', {
      start: startIndex || 0,
      include_swipe: (options && options.include_swipe) || false,
    });
  };

  /// setChatMessage(content, index, options?)
  ///   Edit the message at the given floor index, or switch its swipe.
  ///   options.swipe_id  : switch to this swipe (0-based)
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
  ///   Run a slash command, e.g. '/send hello' '/setvar key=val' '/gen'.
  ///   Returns Promise<string | null> (/gen-class commands return the generated
  ///   result; the others return null).
  window.triggerSlash = function (command) {
    return __sendRequest('th_triggerSlash', { command: command });
  };

  /// getVariables(options?)
  ///   Read the current chat variable table. options.key reads a single variable.
  ///   Returns Promise<object | string>.
  window.getVariables = function (options) {
    return __sendRequest('th_getVars', {
      key: options && options.key,
    });
  };

  /// setVariables(vars, options?)
  ///   Write variables. vars is a { key: value } object.
  ///   Returns Promise<void>.
  window.setVariables = function (vars, options) {
    return __sendRequest('th_setVars', { vars: vars });
  };

})();
