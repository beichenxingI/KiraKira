// 定位 regex_7 语法错误的精确位置与原始上下文
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const card = JSON.parse(fs.readFileSync(path.join(__dirname, '..', '..', 'PiuPiuCard_《道渊》v5.2.json'), 'utf8'));
const r7 = card.data.extensions.regex_scripts[7].replaceString;
const doc7 = r7.replace(/^```html\s*\n/, '').replace(/```\s*$/, '');

// P3-D Task 1 后: 逐字复刻生产 normalizeCodeQuotes(块外归一化, 块内原样保留)
function normalizeCodeQuotes(html) {
  const norm = (s) => s.replace(/[‘’‚‛]/g, "'").replace(/[“”„‟＂]/g, '"').replace(/…+/g, '...');
  const re = /<script[^>]*>[\s\S]*?<\/script>|<style[^>]*>[\s\S]*?<\/style>/gi;
  let out = '', last = 0, m;
  while ((m = re.exec(html)) !== null) {
    out += norm(html.slice(last, m.index)) + m[0];
    last = m.index + m[0].length;
  }
  out += norm(html.slice(last));
  return out;
}
const m = normalizeCodeQuotes(doc7).match(/<script>([\s\S]*?)<\/script>/i);
const body = m[1];
console.log('脚本体长度:', body.length);
try { new vm.Script(body, { filename: 'regex7_body.js' }); console.log('PARSE OK'); }
catch (e) { console.log('SYNTAX ERROR 完整:', e.message); if (e.stack) console.log(e.stack.split('\n').slice(0,3).join('\n')); }

// 找所有 “深蓝” 原样位置(在 normalize 前的脚本里找弯曲引号配对)
const rawM = doc7.match(/<script>([\s\S]*?)<\/script>/i);
const rawBody = rawM[1];
let idx = 0, n = 0;
while ((idx = rawBody.indexOf('深蓝', idx)) >= 0 && n < 10) {
  console.log(`\n[raw@${idx}] 上下文±120:`);
  console.log(JSON.stringify(rawBody.substring(idx - 120, idx + 120)));
  idx += 2; n++;
}

// 统计 normalize 后的破坏点: “X”(直引号) 落在直双引号字符串内的估计
// 粗扫: 原身里有 “ 或 ” 的行(弯曲双引号行)
const curlyLines = [];
const lines = rawBody.split('\n');
lines.forEach((ln, i) => {
  const hasCurly = /[“”]/.test(ln);
  if (hasCurly) {
    // 如果该行同时有直双引号,则是高危行(弯曲双引号在直双引号字符串内 → normalize 后炸)
    const straight = (ln.match(/"/g) || []).length;
    curlyLines.push(`  行${i + 1}: 直双引号数=${straight} | ${ln.trim().slice(0, 110)}`);
  }
});
console.log(`\n含弯曲双引号的行数: ${curlyLines.length}, 逐条:`);
console.log(curlyLines.join('\n'));
