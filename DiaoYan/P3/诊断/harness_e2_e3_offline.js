// P3-E harness(离线, 无需浏览器):
//   1. 从生产 chat_stage.html eval 出 injectBridge 的真 patch(与真机注入逐字同源);
//   2. 在 node vm 沙箱里装上 iframe 环境桩(parent/window/document/timers...);
//   3. 模拟主文档 __syncVarsToCard 广播一份假 message 级快照(含 stat_data);
//   4. 断言: window.Mvu 门控挂载 → getMvuData 同步返 stat_data →
//      getAllVariables() 同步返数字 → replaceMvuData 乐观写 →
//      waitGlobalInitialized('Mvu') resolve → 事件转发到 _TH 总线。
// 用法: node harness_e2_e3_offline.js
const fs = require('fs');
const vm = require('vm');
const { extractPatch, extractScripts } = require('./extract_inject_bridge_patch.js');

const patchHtml = extractPatch(); // 真机 card iframe 注入的整段 HTML 片段
const blocks = extractScripts(patchHtml);
if (blocks.length !== 1) throw new Error('期望 patch 内 1 个 <script> 块, 实得 ' + blocks.length);
const patch = blocks[0];

// ── iframe 环境桩 ──
const listeners = {};            // window message 监听器
const timers = [];
const postedToParent = [];       // card → parent 的 postMessage 记录
const parentMessages = [];       // 模拟主文档向 card postMessage 的队列

function makeSandbox() {
  const windowObj = {
    console: { log(){}, error(){}, warn(){}, info(){} },
    navigator: { clipboard: undefined },
    addEventListener: function(type, fn) {
      (listeners[type] = listeners[type] || []).push(fn);
    },
    removeEventListener: function(type, fn) {
      const l = listeners[type] || []; const i = l.indexOf(fn); if (i >= 0) l.splice(i, 1);
    },
    setInterval: function(fn, ms) { timers.push({ fn, ms }); return timers.length; },
    clearInterval: function(id) { if (timers[id - 1]) timers[id - 1].dead = true; },
    setTimeout: function(fn, ms) { timers.push({ fn, ms }); return timers.length; },
    clearTimeout: function(id) { if (timers[id - 1]) timers[id - 1].dead = true; },
    postMessage: null,
    localStorage: { getItem(){ return null; }, setItem(){}, removeItem(){}, clear(){} },
    document: {
      addEventListener: function(){ return undefined; },
      readyState: 'complete',
    },
  };
  windowObj.window = windowObj;
  windowObj.parent = {
    postMessage: function(msg) { postedToParent.push(msg); },
  };
  windowObj.postMessage = function(msg) { postedToParent.push(msg); };
  return windowObj;
}

function dispatchMessage(win, data) {
  (listeners['message'] || []).forEach(fn => fn({ data, source: win.parent }));
}

// ── 1) 执行真 patch ──
const sandbox = makeSandbox();
vm.createContext(sandbox);
vm.runInContext(patch, sandbox, { filename: 'inject_patch.js' });

function log(label) {
  const lines = postedToParent.splice(0).map(m => m && m.text);
  if (lines.length) console.log(label, '→', lines.join(' || '));
}

// ── 2) 主文档广播假快照(含 stat_data 的 message 级 MvuData) ──
const fakeMvuData = {
  stat_data: { 世界: {}, 主角: { 姓名: '韩立', 生命: 87, 灵力: 120, 境界: '筑基' } },
  schema: {},
  initialized_lorebooks: {},
};
dispatchMessage(sandbox, {
  __thVars: true, type: 'message', data: fakeMvuData,
  floor_idx: 3, lastMsgId: 3, swipe_id: 0,
});
dispatchMessage(sandbox, { __thVars: true, type: 'chat', data: { 金币: 5 }, lastMsgId: 3 });

let pass = 0, fail = 0;
function assert(name, cond) {
  if (cond) { pass++; console.log('  PASS', name); }
  else { fail++; console.log('  FAIL', name); }
}

console.log('[T1] 快照到达 → 门控挂载');
log('posted');
assert('window.Mvu 已定义', typeof sandbox.window.Mvu !== 'undefined');
assert('window.Mvu.events.VARIABLE_UPDATE_ENDED', sandbox.window.Mvu && sandbox.window.Mvu.events.VARIABLE_UPDATE_ENDED === 'mag_variable_update_ended');
assert('events.VARIABLE_INITIALIZED 保留官方 typo', sandbox.window.Mvu && sandbox.window.Mvu.events.VARIABLE_INITIALIZED === 'mag_variable_initiailized');

console.log('[T2] getMvuData 同步返回数据');
const got = sandbox.window.Mvu.getMvuData({ type: 'message', message_id: 3 });
assert('同步返对象(非 Promise)', got && typeof got.then !== 'function');
assert('stat_data.主角.生命 === 87', got && got.stat_data && got.stat_data.主角 && got.stat_data.主角.生命 === 87);
const got2 = sandbox.window.Mvu.getMvuData({ type: 'message', message_id: 'latest' });
assert("message_id='latest' → lastMsgId=3", got2 && got2.stat_data && got2.stat_data.主角.生命 === 87);
const got3 = sandbox.window.Mvu.getMvuData({ type: 'message', message_id: -1 });
assert('message_id=-1 深度索引 → 楼层3', got3 && got3.stat_data && got3.stat_data.主角.生命 === 87);
const got4 = sandbox.window.Mvu.getMvuData({ type: 'chat' });
assert('type=chat 返回 chat 快照', got4 && got4.金币 === 5);

console.log('[T3] getAllVariables 同步叠加(global→chat→message)');
const all = sandbox.window.getAllVariables();
assert('同步返对象', all && typeof all.then !== 'function');
assert('叠加 stat_data', all && all.stat_data && all.stat_data.主角.生命 === 87);
assert('chat 变量在场', all && all.金币 === 5);

console.log('[T4] replaceMvuData 乐观更新 + 走桥');
let bridgeCall = null;
sandbox.window.__thPending && (sandbox.window.__thPending = {});
// 劫持 __thCall 的落点: 直接从 postedToParent 里抓 __thRequest
const gotBefore = sandbox.window.Mvu.getMvuData({ type: 'message', message_id: 3 });
const p = sandbox.window.Mvu.replaceMvuData(Object.assign({}, gotBefore, { stat_data: { 主角: { 生命: 99 } } }), { type: 'message', message_id: 3 });
assert('replaceMvuData 返 Promise', p && typeof p.then === 'function');
const after = sandbox.window.Mvu.getMvuData({ type: 'message', message_id: 3 });
assert('乐观更新立刻可读 生命=99', after && after.stat_data && after.stat_data.主角.生命 === 99);
const reqMsg = postedToParent.find(m => m && m.__thRequest && m.method === 'setVariables');
assert('桥请求 setVariables 已发', !!reqMsg);
assert('桥请求 option.message_id=3(数字)', reqMsg && reqMsg.args[1] && reqMsg.args[1].message_id === 3);
postedToParent.length = 0;

console.log('[T5] waitGlobalInitialized("Mvu") 立即 resolve');
// 挂载已发生 → 走同步分支 Promise.resolve(window.Mvu), 微任务内必 resolve
(async () => {
  const v = await sandbox.window.waitGlobalInitialized('Mvu');
  assert('waitGlobalInitialized resolve 出 facade', v && v.events && typeof v.getMvuData === 'function');
  finish();
})();
function finish() {
  console.log('');
  console.log('==== ' + (fail === 0 ? 'ALL ' + pass + ' ASSERTS PASSED' : fail + ' FAILED / ' + pass + ' PASSED') + ' ====');
  process.exit(fail === 0 ? 0 : 1);
}

console.log('[T6] MVU 事件中继 → 本地总线');
let fired = 0;
sandbox.window.eventOn('mag_variable_update_ended', () => { fired++; });
dispatchMessage(sandbox, { __thEvent: true, type: 'mag_variable_update_ended', args: [fakeMvuData, fakeMvuData] });
assert('eventOn 注册的监听被点火 x1', fired === 1);
log('posted');

console.log('[T7] 未门控前 Mvu 不存在(时序门)');
const sandbox2 = makeSandbox();
vm.createContext(sandbox2);
vm.runInContext(patch, sandbox2, { filename: 'inject_patch.js' });
assert('无快照 → window.Mvu 保持 undefined', typeof sandbox2.window.Mvu === 'undefined');
dispatchMessage(sandbox2, { __thVars: true, type: 'chat', data: { x: 1 } });
assert('仅 chat 快照(无 stat_data) → Mvu 仍 undefined', typeof sandbox2.window.Mvu === 'undefined');
log('posted2');
// T7 结束但 T5 的异步断言在微任务里 → 用定时器兜底退出
setTimeout(() => finish(), 200);
