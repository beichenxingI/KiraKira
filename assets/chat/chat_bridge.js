
(function () {
  // ── 入站路由表：type -> handler。业务侧用 registerBridgeHandler 往里加。
  var __bridgeHandlers = {};

  // 注册一个来自 Flutter 的指令处理器（对应 BridgeType 里的出站类型）。
  window.registerBridgeHandler = function (type, fn) {
    __bridgeHandlers[type] = fn;
  };

  // ── 出站路由：Flutter 通过 evaluateJavascript 调这个函数下发指令。
  //    Flutter 侧 _dispatch 发的是 jsonEncode({type,payload}) 的字符串。
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

  // ── 入站发送：WebView 里一切要通知 Flutter 的事，统一走这里。
  window.sendToFlutter = function (type, payload) {
    try {
      var msg = { type: type, payload: payload || {} };
      if (window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler('bridge', JSON.stringify(msg));
      }
    } catch (e) {
      // 通信失败不该让页面崩，静默即可（Flutter 侧收不到自会超时处理）。
    }
  };

  // ── 高频事件节流器：滚动等必须先在这里削峰再发（规矩 4）。
  //    用法：throttleSend('scroll', 100, function(){ return {top: ...}; })
  var __throttleTimers = {};
  window.throttleSend = function (type, ms, payloadFn) {
    if (__throttleTimers[type]) return; // 窗口内已排队，丢弃
    __throttleTimers[type] = setTimeout(function () {
      __throttleTimers[type] = null;
      sendToFlutter(type, payloadFn());
    }, ms);
  };

  // ── 握手：页面就绪后通知 Flutter，触发发送队列冲刷（规矩 2）。
  function fireReady() {
    sendToFlutter('ready', {});
  }
  if (document.readyState === 'complete') {
    fireReady();
  } else {
    window.addEventListener('load', fireReady);
  }

  // ── 酒馆助手 API：请求-响应 Promise 等待表 ────────────────────────
  //    每个需要返回值的助手函数都走这套机制：
  //    1. 生成唯一 id，把 resolve/reject 存进 __pendingRequests
  //    2. 调用 sendToFlutter 把请求发给 Flutter（携带 id）
  //    3. Flutter 处理完发回 th_response（payload 里带同一 id）
  //    4. __bridgeDispatch 收到 th_response 后按 id resolve/reject
  var __pendingRequests = {};
  var __nextRequestId = 1;

  window.__sendRequest = function __sendRequest(type, payload) {
    return new Promise(function (resolve, reject) {
      var id = 'req_' + (__nextRequestId++);
      __pendingRequests[id] = { resolve: resolve, reject: reject };
      // 超时兜底：30 秒未回应就 reject，避免 Promise 永久挂起
      setTimeout(function () {
        if (__pendingRequests[id]) {
          delete __pendingRequests[id];
          reject(new Error('request timeout: ' + type));
        }
      }, 30000);
      sendToFlutter(type, Object.assign({}, payload, { __requestId: id }));
    });
  }

  // th_response 分发：Flutter 回传结果，按 id 找到等待的 Promise
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

  // ── 酒馆助手全局 API ──────────────────────────────────────────────
  //    第一档高频函数，覆盖绝大多数交互卡的需求。
  //    函数签名尽量向 SillyTavern 的 TavernHelper 对齐，
  //    降低卡片移植成本。

  /// getChatMessages(startIndex, options?)
  ///   读取当前会话消息。startIndex=0 表示从头读全部。
  ///   options.include_swipe=true 时返回完整 swipes 数组。
  ///   返回 Promise<Array>，格式与酒馆助手对齐：
  ///   [{ id, role, content, swipes, swipe_id, is_user }, ...]
  window.getChatMessages = function (startIndex, options) {
    return __sendRequest('th_getMessages', {
      start: startIndex || 0,
      include_swipe: (options && options.include_swipe) || false,
    });
  };

  /// setChatMessage(content, index, options?)
  ///   修改指定楼层的消息内容或切换 swipe。
  ///   options.swipe_id  : 切换到第几个 swipe（从 0 开始）
  ///   options.refresh   : true 时触发 WebView 重渲染
  window.setChatMessage = function (content, index, options) {
    return __sendRequest('th_setMessage', {
      index: index,
      content: content,
      swipe_id: options && options.swipe_id,
      refresh: (options && options.refresh) || false,
    });
  };

  /// triggerSlash(command)
  ///   执行斜杠命令，如 '/send 你好' '/setvar key=val' '/gen'。
  ///   返回 Promise<string | null>（/gen 类返回生成结果，其余返回 null）。
  window.triggerSlash = function (command) {
    return __sendRequest('th_triggerSlash', { command: command });
  };

  /// getVariables(options?)
  ///   读取当前会话变量表。options.key 指定只读单个变量。
  ///   返回 Promise<object | string>。
  window.getVariables = function (options) {
    return __sendRequest('th_getVars', {
      key: options && options.key,
    });
  };

  /// setVariables(vars, options?)
  ///   写入变量。vars 为 { key: value } 的对象。
  ///   返回 Promise<void>。
  window.setVariables = function (vars, options) {
    return __sendRequest('th_setVars', { vars: vars });
  };

})();
