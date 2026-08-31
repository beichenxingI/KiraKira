// regex_6 module: 严格 DOM 存根(querySelector/getElementById → null, 贴近真实缺月表)
// 问题: 顶层语句在 $(errorCatched(init)) 之前是否就会被 null.addEventListener 杀死?
const fs = require('fs');
const vm = require('vm');
const r6 = JSON.parse(fs.readFileSync('DiaoYan/PiuPiuCard_《道渊》v5.2.json', 'utf8')).data.extensions.regex_scripts[6].replaceString;
const doc6 = r6.replace(/^```html\s*\n/, '').replace(/```\s*$/, '');
const body = doc6.match(/<script type="module">([\s\S]*?)<\/script>/i)[1];

// 即将真实 DOM:iframe 文档里 SELECTOR 命不命中—we 不知道;两种世界都试
async function runVariant(label, qselReturnNull) {
  const chainObj = new Proxy(function () {}, {
    get(t, k) {
      if (k === 'length') return qselReturnNull ? 0 : 1;
      if (k === Symbol.toPrimitive) return () => '';
      return (...a) => chainObj;
    },
    apply() { return chainObj; },
  });
  const $p = function (arg) {
    if (typeof arg === 'function') { try { arg($p); } catch (e) { console.log(`[${label}] $(fn)体抛错:`, e.message); } return; }
    return chainObj;
  };
  const el = {
    style: new Proxy({}, { get: () => '', set: () => true }),
    classList: { add() {}, remove() {}, toggle() {}, contains: () => false },
    addEventListener() {}, removeEventListener() {},
    appendChild(c) { return c; }, setAttribute() {}, getAttribute: () => null,
    querySelector() { return qselReturnNull ? null : Object.create(el); },
    querySelectorAll() { return []; },
    getBoundingClientRect: () => ({ top: 0, bottom: 0, width: 0, height: 0 }),
    innerHTML: '', textContent: '', value: '', dataset: {}, remove() {},
  };
  const nullish = qselReturnNull ? null : () => Object.create(el);
  const sandbox = {
    console, window: null, document: {
      readyState: 'loading',
      addEventListener() {}, removeEventListener() {},
      createElement: () => Object.create(el), createElementNS: () => Object.create(el),
      querySelector: qselReturnNull ? () => null : (() => Object.create(el)),
      querySelectorAll: () => [],
      getElementById: qselReturnNull ? () => null : (() => Object.create(el)),
      body: Object.create(el), head: Object.create(el), documentElement: Object.create(el),
    },
    $: $p, jQuery: $p,
    _: new Proxy({}, { get: () => () => chainObj }),
    toastr: new Proxy(function () {}, { get: () => () => {}, apply: () => {} }),
    localStorage: { getItem: () => null, setItem() {}, removeItem() {}, clear() {}, key: () => null, length: 0 },
    sessionStorage: { getItem: () => null, setItem() {}, removeItem() {}, clear() {}, key: () => null, length: 0 },
    navigator: { maxTouchPoints: 3 }, location: { href: 'blob:x', reload() {} },
    parent: { postMessage() {} }, top: null,
    setTimeout: (fn) => { if (typeof fn === 'function') { try { fn(); } catch (e) { console.log(`[${label}] setTimeout抛错:`, e.message); } } return 1; },
    clearTimeout() {}, setInterval: () => 1, clearInterval() {},
    requestAnimationFrame: () => 1, fetch: () => Promise.reject(new Error('x')),
    alert() {}, confirm: () => false,
    ResizeObserver: class { observe() {} }, MutationObserver: class { observe() {} }, IntersectionObserver: class { observe() {} },
    getComputedStyle: () => ({ marginTop: '0', marginBottom: '0' }),
    URL: { createObjectURL: () => 'blob:x', revokeObjectURL() {} },
    eventOn: () => ({ stop() {} }), eventEmit() {},
    getCurrentMessageId: () => '0', triggerSlash: () => Promise.resolve(), substitudeMacros: (t) => t,
    getAllVariables: () => Promise.resolve({}), // 我们环境的实际形态(Promise)
    tavern_events: {}, iframe_events: {},
  };
  sandbox.window = sandbox; sandbox.self = sandbox; sandbox.globalThis = sandbox;
  const ctx = vm.createContext(sandbox);
  try {
    const mod = new vm.SourceTextModule(body, { context: ctx });
    await mod.link(() => { throw new Error('no import'); });
    await mod.evaluate();
    console.log(`[${label}] evaluate 完成,未抛错`);
  } catch (e) {
    console.log(`[${label}] !!顶层抛错 => ${e.name}: ${e.message}`);
    const m = (e.stack || '').match(/vm:module\(0\):(\d+)/);
    if (m) {
      const ln = +m[1];
      const lines = body.split('\n');
      console.log(`  抛错行 ${ln}: ${JSON.stringify(lines[ln - 1] || '').slice(0, 160)}`);
      console.log(`  上下文: ${JSON.stringify(lines[ln - 2] || '')} `);
    }
  }
  console.log(`[${label}] 事后: typeof window.switchTab =`, typeof sandbox.switchTab, '| typeof window.init =', typeof sandbox.init);
}

(async () => {
  await runVariant('宽松DOM(全代理elem)', false);
  await runVariant('严格DOM(querySelector全null)', true);
})();
