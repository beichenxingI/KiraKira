// P3-诊断: 在 Node vm 里真实执行卡的 UI 脚本(语法检查 + 沙盒执行),定位首个抛错点
// 运行: node --experimental-vm-modules DiaoYan/P3/诊断/run_card_script.js
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const card = JSON.parse(fs.readFileSync(path.join(__dirname, '..', '..', 'PiuPiuCard_《道渊》v5.2.json'), 'utf8'));
const r6 = card.data.extensions.regex_scripts[6].replaceString;
const r7 = card.data.extensions.regex_scripts[7].replaceString;

// —— 环境仿真: 与我们注入 iframe 的 patch 等价的"有/无"清单 ——
// 有: $,_,toastr,YAML,eventOn系列(挂 window), localStorage 内存polyfill, getCurrentMessageId, triggerSlash, substitudeMacros
// 无: errorCatched, waitGlobalInitialized, Mvu, registerVariableSchema, z  (CARD-ENV2 实测: Mvu=N)
function makeElem(tag) {
  const el = {
    tagName: (tag || 'div').toUpperCase(),
    style: new Proxy({}, { get: () => '', set: () => true }),
    classList: { add() {}, remove() {}, toggle() {}, contains: () => false },
    dataset: {}, children: [], innerHTML: '', textContent: '', value: '',
    setAttribute() {}, getAttribute: () => null, removeAttribute() {},
    appendChild(c) { this.children.push(c); return c; },
    remove() {}, focus() {}, click() {},
    addEventListener(type, fn, opts) { (el.__listeners ||= {})[type] ||= []; el.__listeners[type].push(fn); },
    removeEventListener() {},
    querySelector() { return makeElem(); }, querySelectorAll() { return []; },
    getBoundingClientRect() { return { top: 0, left: 0, bottom: 0, right: 0, width: 0, height: 0 }; },
    closest() { return null; }, contains: () => false,
    insertBefore() {}, insertAdjacentElement() {}, insertAdjacentHTML() {},
    animate() {}, play() { return Promise.reject(new Error('no audio')); }, pause() {},
  };
  return el;
}

function makeSandbox(label) {
  const docListeners = {};
  const documentStub = {
    readyState: 'loading',
    addEventListener(type, fn) { (docListeners[type] ||= []).push(fn); },
    removeEventListener() {},
    createElement: (t) => makeElem(t),
    createElementNS: (ns, t) => makeElem(t),
    querySelector() { return makeElem(); },
    querySelectorAll() { return []; },
    getElementById() { return makeElem(); },
    body: makeElem('body'),
    head: makeElem('head'),
    documentElement: makeElem('html'),
    fonts: { load: () => Promise.resolve() },
    __fire(type) { (docListeners[type] || []).forEach(f => { try { f({ target: documentStub }); } catch (e) { console.log(`[${label}] ${type} 监听器抛错:`, e.message); } }); },
  };
  const store = {};
  const $proxy = function (arg) {
    if (typeof arg === 'function') { try { arg($proxy); } catch (e) { console.log(`[${label}] $(fn) 立即执行抛错:`, e.message); sandbox.__entryThrew = e; } return; }
    return chainObj;
  };
  const chainObj = new Proxy(function () {}, {
    get(t, k) {
      if (k === 'length') return 1;
      if (k === '0') return makeElem();
      if (k === Symbol.toPrimitive) return () => '';
      return (...args) => chainObj;
    },
    apply() { return chainObj; },
  });
  const sandbox = {
    console,
    document: documentStub,
    window: null, // 指向 sandbox 自身
    $: $proxy, jQuery: $proxy,
    _: new Proxy({}, { get: () => () => ({}) }),
    toastr: new Proxy(function () {}, { get: () => () => {}, apply: () => {} }),
    YAML: { parse: (s) => ({}), parseDocument: () => ({ toJS: () => ({}) }), parseAllDocuments: () => [], stringify: () => '' },
    localStorage: {
      getItem: (k) => store[k] ?? null, setItem: (k, v) => { store[k] = String(v); },
      removeItem: (k) => { delete store[k]; }, clear: () => { for (const k in store) delete store[k]; },
      key: (i) => Object.keys(store)[i] ?? null, get length() { return Object.keys(store).length; },
    },
    sessionStorage: null, // 下面指向 localStorage 同款
    navigator: { clipboard: { writeText: () => Promise.resolve() }, maxTouchPoints: 0 },
    location: { href: 'blob:about', reload() {}, assign() {} },
    parent: { postMessage() {}, document: documentStub },
    top: null,
    setTimeout: (fn, ms) => { /* 立即执行,模拟已异步完成 */ if (typeof fn === 'function') { try { fn(); } catch (e) { console.log(`[${label}] setTimeout回调抛错:`, e.message); } } return 1; },
    clearTimeout() {}, setInterval: () => 1, clearInterval() {},
    requestAnimationFrame: (fn) => { try { fn(0); } catch (_) {} return 1; },
    fetch: () => Promise.reject(new Error('no network')),
    alert() {}, confirm: () => false, prompt: () => null,
    Audio: function () { return { play: () => Promise.reject(new Error('no audio')), pause() {}, addEventListener() {} }; },
    Image: function () { return makeElem('img'); },
    ResizeObserver: class { observe() {} unobserve() {} disconnect() {} },
    IntersectionObserver: class { observe() {} unobserve() {} disconnect() {} },
    MutationObserver: class { observe() {} disconnect() {} },
    getComputedStyle: () => ({ marginTop: '0', marginBottom: '0', getPropertyValue: () => '' }),
    URL: { createObjectURL: () => 'blob:x', revokeObjectURL() {} },
    eventOn: () => ({ stop() {} }), eventEmit() {}, eventOnce() {}, eventMakeLast: () => ({ stop() {} }),
    eventMakeFirst: () => ({ stop() {} }), eventRemoveListener() {},
    tavern_events: {}, iframe_events: {},
    getCurrentMessageId: () => '0',
    triggerSlash: (cmd) => { console.log(`[${label}] triggerSlash:`, JSON.stringify(cmd).slice(0, 120)); return Promise.resolve(); },
    substitudeMacros: (t) => t,
    getVariables: () => Promise.resolve({}), setVariables: () => Promise.resolve(),
    SillyTavern: { getContext: () => ({ chat: [], eventSource: { on() {} } }) },
    // 关键: 注入环境里【不存在】的东西 —— 一个都不给:
    //   errorCatched  ← 酒馆助手API,我们没注入
    //   waitGlobalInitialized
    //   Mvu
    //   registerVariableSchema
    __entryThrew: null,
    __docListeners: docListeners,
  };
  sandbox.sessionStorage = sandbox.localStorage;
  sandbox.window = sandbox;
  sandbox.globalThis = sandbox;
  sandbox.self = sandbox;
  const ctx = vm.createContext(sandbox);
  return { sandbox, ctx };
}

async function runModule(name, htmlWithNormalize) {
  console.log(`\n${'='.repeat(60)}\n### ${name}\n${'='.repeat(60)}`);
  const m = htmlWithNormalize.match(/<script type="module">([\s\S]*?)<\/script>/i);
  if (!m) { console.log('!! 未找到 <script type="module"> 块'); return; }
  const body = m[1];
  console.log('模块脚本体长度:', body.length);
  // 语法检查
  try {
    new vm.SourceTextModule(body);
    console.log('语法检查: OK(PARSE OK)');
  } catch (e) {
    console.log('语法检查: !!SYNTAX ERROR!! =>', e.message);
    console.log('(整段不执行 —— 首位抛错即在这里, switchTab/init 全部不可能跑到)');
    return;
  }
  // 执行
  const { sandbox, ctx } = makeSandbox(name);
  const mod = new vm.SourceTextModule(body, { context: ctx });
  await mod.link(() => { throw new Error('不应有 import'); });
  try {
    await mod.evaluate();
    console.log('执行结果: 顶层 evaluate 未同步抛错');
  } catch (e) {
    console.log('执行结果: !! 顶层抛错 =>', e.constructor.name + ':', e.message);
    if (e.stack) console.log('  stack(前300):', e.stack.split('\n').slice(0, 4).join(' | '));
  }
  console.log('事后读数: typeof window.switchTab =', typeof sandbox.switchTab,
    '| window.init =', typeof sandbox.init,
    '| $(errorCatched(init)) 抛错 =', sandbox.__entryThrew ? sandbox.__entryThrew.name + ': ' + sandbox.__entryThrew.message : 'null',
    '| __entryThrew=', sandbox.__entryThrew ? sandbox.__entryThrew.message : '无');
}

async function runClassic(name, htmlWithNormalize) {
  console.log(`\n${'='.repeat(60)}\n### ${name}\n${'='.repeat(60)}`);
  const m = htmlWithNormalize.match(/<script>([\s\S]*?)<\/script>/i);
  if (!m) { console.log('!! 未找到经典 <script> 块'); return; }
  const body = m[1];
  console.log('经典脚本体长度:', body.length);
  try {
    new vm.Script(body);
    console.log('语法检查: OK');
  } catch (e) {
    console.log('语法检查: !!SYNTAX ERROR!! =>', e.message);
    return;
  }
  const { sandbox, ctx } = makeSandbox(name);
  try {
    vm.runInContext(body, ctx);
    console.log('顶层执行: 未同步抛错');
  } catch (e) {
    console.log('顶层执行: !! 抛错 =>', e.message);
    if (e.stack) console.log('  stack(前300):', e.stack.split('\n').slice(0, 4).join(' | '));
  }
  console.log('手动 fire DOMContentLoaded:');
  sandbox.document.__fire('DOMContentLoaded');
  // 统计 getElementById 绑定: 无法统计(代理), 但至少看 startButton 路径有无抛错(已在 __fire 内打印)
}

// —— 归一化复刻(与 Dart _normalizeCodeQuotes 等价) ——
function normalizeCodeQuotes(html) {
  return html
    .replace(/[‘’‚‛]/g, "'")
    .replace(/[“”„‟＂]/g, '"')
    .replace(/…+/g, '...');
}

(async () => {
  // regex_6 的 module: 先走真实 Dart 管线产物? 等价 —— 直接用 replaceString(围栏内=完整文档) + 归一化
  const doc6 = r6.replace(/^```html\s*\n/, '').replace(/```\s*$/, '');
  await runModule('regex_6 module (normalize后)', normalizeCodeQuotes(doc6));
  await runModule('regex_6 module (未normalize对照)', doc6);

  const doc7 = r7.replace(/^```html\s*\n/, '').replace(/```\s*$/, '');
  await runClassic('regex_7 classic script (normalize后)', normalizeCodeQuotes(doc7));

  const fm = card.data.first_mes.replace(/^```html\s*\n/, '').replace(/```\s*$/, '');
  await runClassic('first_mes classic script (原样)', fm);
  console.log('\nDONE');
})();
