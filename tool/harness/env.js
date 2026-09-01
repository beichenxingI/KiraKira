const path = require('path');
const { pathToFileURL } = require('url');
const { chromium } = require('playwright');
const { extractFacade } = require('./extract');
const { createBridge } = require('./mock_bridge');

// 真实页面:禁止手写副本,加载 assets/chat/chat_stage.html 本体
const CHAT_STAGE = path.resolve(__dirname, '../../assets/chat/chat_stage.html');

async function makeEnvironment(options = {}) {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const page = await browser.newPage();
  const bridge = createBridge(options.bridge || {});

  // 把页面里的一切都显出来,headless 默认吞掉
  page.on('console', m => console.log('[页面console]', m.type(), m.text()));
  page.on('pageerror', e => console.log('[页面异常]', e.message, '\n', e.stack));
  page.on('frameattached', f => console.log('[iframe挂载]', f.name() || '(匿名)'));

  // 只拦 http(s),file:// 必须放行否则页面自己都加载不了
  await page.route('http://**', route => {
    console.log('[拦截网络]', route.request().url());
    return route.abort();
  });
  await page.route('https://**', route => {
    console.log('[拦截网络]', route.request().url());
    return route.abort();
  });

  // 必须在页面脚本执行前注入:Dart 侧全局 + 桥 stub
  // 真机注入点见 webview_chat_stage.dart:277-287,289-325,329-349
  await page.addInitScript(({ facade }) => {
    window.__ENGINE_FACADE_JS = facade;
    window.__KIRA_PRESET_SCRIPTS = [];
    window.__KIRA_EJS_STUB = '';
    window.__KIRA_EJS_BUNDLE = '';

    window.__harnessBridgeCalls = [];

    // Flutter JavaScriptChannel,真机由 webview 注入
    // 缺它页面停在 chat_stage.html:342
    window.__KIRA_CHAT_BRIDGE__ = {
      postMessage: (msg) => {
        window.__harnessBridgeCalls.push({ raw: msg });
        console.log('[桥出站]', msg);
      },
    };

    // 桥 mock:默认抛错,绝不返回空数组(空数组会让道渊球假绿,
    // 见 daoyuan_helper.js.pretty.js:1440-1444)
    window.__sendRequest = async (type, payload) => {
      window.__harnessBridgeCalls.push({ type, payload });
      throw new Error('No mock response configured for ' + type);
    };
    window.toastr = {
      warning: console.warn, success: console.log,
      info: console.log, error: console.error,
    };
  }, { facade: extractFacade() });

  await page.goto(pathToFileURL(CHAT_STAGE).href);
  await page.waitForLoadState('load');

  return { browser, page, bridge };
}

module.exports = { makeEnvironment };