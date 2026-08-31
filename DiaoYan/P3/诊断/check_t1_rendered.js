// T1 rendered(开场白进 iframe 的最终串, 已经过 _normalizeCodeQuotes) 脚本体检
const fs = require('fs');
const vm = require('vm');
const t1 = fs.readFileSync('DiaoYan/P3/诊断/out/T1_greeting_firstmes_6_rendered.txt', 'utf8');
const m = t1.match(/<script>([\s\S]*?)<\/script>/i);
if (!m) { console.log('T1 rendered 无 script'); process.exit(0); }
const body = m[1];
console.log('T1 rendered 脚本体长度:', body.length);
try {
  new vm.Script(body);
  console.log('PARSE: OK');
} catch (e) {
  console.log('PARSE FAIL:', e.message);
}
const hits = body.match(/switchToSecondGreeting/g) || [];
console.log('switchToSecondGreeting 出现次数:', hits.length);
const isDecl = /function\s+switchToSecondGreeting/.test(body);
console.log('定义形式:', isDecl ? 'function switchToSecondGreeting(...) 顶层声明 → 经典脚本 → window 全局 ✓' : '非顶层 function 声明!');
const d = body.match(/function switchToSecondGreeting[\s\S]{0,500}/);
if (d) console.log('定义处上下文:\n', d[0]);
// triggerSlash 用法
const ts = body.match(/triggerSlash[\s\S]{0,80}/);
if (ts) console.log('triggerSlash 用法:', JSON.stringify(ts[0]));
