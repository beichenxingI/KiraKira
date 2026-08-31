// P3-诊断: 解剖 regex_6/regex_7 脚本内部结构(模块顶层 vs init 内部分界, 找出会"整段不执行"的原因)
const fs = require('fs');
const path = require('path');
const card = JSON.parse(fs.readFileSync(path.join(__dirname, '..', '..', 'PiuPiuCard_《道渊》v5.2.json'), 'utf8'));
const scripts = card.data.extensions.regex_scripts;

const r6 = scripts[6].replaceString;
console.log('=== regex_6 结构 ===');
const offScript6 = r6.indexOf('<script type="module">');
const offSwitchTab = r6.indexOf('window.switchTab');
const offInitDecl = r6.indexOf('async function init()');
const offInitPlain = r6.indexOf('function init()');
const offEntry = r6.indexOf('$(errorCatched(init))');
const offWaitGlobal = r6.indexOf('waitGlobalInitialized');
console.log('script open:', offScript6, '| window.switchTab:', offSwitchTab, '| async init:', offInitDecl, '| plain init:', offInitPlain, '| $(errorCatched(init)):', offEntry, '| waitGlobalInitialized:', offWaitGlobal);
console.log('script 头 800 字符:');
console.log(r6.substring(offScript6, offScript6 + 800));
console.log('\n--- window.switchTab 上下文(前后100) ---');
console.log(r6.substring(offSwitchTab - 100, offSwitchTab + 900));
console.log('\n--- init() 开头 700 ---');
const i0 = offInitDecl >= 0 ? offInitDecl : offInitPlain;
console.log(r6.substring(i0, i0 + 700));
console.log('\n--- 入口段(最后 700) ---');
console.log(r6.substring(r6.length - 700));

// 顶层执行风险探测: script 区间内, 顶层有哪些直接调用 (粗排: 每行不以 function/if/const 等开头的语句)
console.log('\n--- 顶层可疑调用行(关键字扫描) ---');
const modBody = r6.substring(offScript6, r6.length);
const lines = modBody.split('\n');
const interesting = [];
lines.forEach((ln, i) => {
  const t = ln.trim();
  if (/^\$\(|^toastr\.|^Mvu\.|^eventOn\(|^errorCatched|^await |^window\.Mvu/.test(t)) {
    interesting.push(`  modLine~${i}: ${t.slice(0, 120)}`);
  }
});
console.log(interesting.slice(0, 30).join('\n') || '  (无命中)');

const r7 = scripts[7].replaceString;
console.log('\n=== regex_7 结构 ===');
const s7 = r7.indexOf('<script>');
console.log('script open(offset):', s7, '以其为准的 script 头 200:');
console.log(r7.substring(s7, s7 + 200));
const iMvu = r7.indexOf('async function initMvu');
console.log('\n--- initMvu 区域(前 1200) ---');
console.log(r7.substring(iMvu, iMvu + 1200));
const sb = r7.indexOf("startButton.addEventListener");
console.log('\n--- startButton 绑定上下文(-600..+500) ---');
console.log(r7.substring(sb - 600, sb + 500));

// 公共: 检查 waitGlobalInitialized / errorCatched 在 replaceString 中是否有【定义】
[['regex_6', r6], ['regex_7', r7], ['first_mes', card.data.first_mes]].forEach(([name, txt]) => {
  const defEC = /function errorCatched|errorCatched\s*=\s*function|errorCatched\s*[:=]/.test(txt);
  const defWG = /function waitGlobalInitialized|waitGlobalInitialized\s*=/.test(txt);
  const use = (t, p) => (t.match(p) || []).length;
  console.log(`${name}: errorCatched 无定义=${!defEC}(出现${use(txt, /errorCatched/g)}次)  waitGlobalInitialized 无定义=${!defWG}(出现${use(txt, /waitGlobalInitialized/g)}次)`);
});
