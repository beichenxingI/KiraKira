// 对管线最终产物 T2_6_rendered.txt 的 module 脚本做语法检查(验证双重炸弹版本)
// 并对 regex_6 rendered 做弯引号行扫描(同 regex_7 的方法学)
const fs = require('fs');
const vm = require('vm');
const t2 = fs.readFileSync('DiaoYan/P3/诊断/out/T2_marker_only_6_rendered.txt', 'utf8');
const m = t2.match(/<script type="module">([\s\S]*?)<\/script>/i);
if (!m) { console.log('T2 rendered 无 module script'); process.exit(1); }
const body = m[1];
console.log('T2 rendered module 脚本体长度:', body.length);
try {
  new vm.SourceTextModule(body);
  console.log('PARSE: OK');
} catch (e) {
  console.log('PARSE FAIL:', e.message);
}
// 弯双引号在直双引号字符串内的危险行统计
const rawCard = JSON.parse(fs.readFileSync('DiaoYan/PiuPiuCard_《道渊》v5.2.json', 'utf8'));
const r6raw = rawCard.data.extensions.regex_scripts[6].replaceString.replace(/^```html\s*\n/, '').replace(/```\s*$/, '');
const mraw = r6raw.match(/<script type="module">([\s\S]*?)<\/script>/i)[1];
let danger = 0;
mraw.split('\n').forEach((ln, i) => {
  if (/[“”]/.test(ln) && /"/.test(ln)) {
    danger++;
    if (danger <= 12) console.log(`  危险行${i + 1}: ${ln.trim().slice(0, 110)}`);
  }
});
console.log('regex_6 module 弯双引号危险行总数:', danger);

// first_mes rendered (T1) 的弯引号危险行
const f1 = rawCard.data.first_mes.replace(/^```html\s*\n/, '').replace(/```\s*$/, '');
const f1s = f1.match(/<script>([\s\S]*?)<\/script>/i)[1];
let d1 = 0;
f1s.split('\n').forEach((ln, i) => { if (/[“”]/.test(ln) && /"/.test(ln)) { d1++; if (d1 <= 8) console.log(`  first_mes 危险行${i + 1}: ${ln.trim().slice(0, 110)}`); } });
console.log('first_mes script 弯双引号危险行总数:', d1);
