// 对照: 卡原始脚本(未 normalize) 与 normalize 后的语法检查 —— 证明破坏由我们引入, 非卡自带
const fs = require('fs');
const vm = require('vm');
const card = JSON.parse(fs.readFileSync('DiaoYan/PiuPiuCard_《道渊》v5.2.json', 'utf8'));
const norm = (s) => s.replace(/[‘’‚‛]/g, "'").replace(/[“”„‟＂]/g, '"').replace(/…+/g, '...');
const grab = (i, isModule) => {
  const doc = card.data.extensions.regex_scripts[i].replaceString.replace(/^```html\s*\n/, '').replace(/```\s*$/, '');
  const re = isModule ? /<script type="module">([\s\S]*?)<\/script>/i : /<script>([\s\S]*?)<\/script>/i;
  return (doc.match(re) || [null, ''])[1];
};
const test = (label, body, isModule) => {
  if (!body) { console.log(label + ': 无脚本'); return; }
  try { isModule ? new vm.SourceTextModule(body) : new vm.Script(body); console.log(label + ': PARSE OK (len=' + body.length + ')'); }
  catch (e) { console.log(label + ': PARSE FAIL => ' + e.message); }
};
const b7 = grab(7, false);
test('regex_7 原始脚本(卡作者所写)', b7, false);
test('regex_7 normalize后(=实际进iframe)', norm(b7), false);
const b5 = grab(5, false);
test('regex_5 原始脚本', b5, false);
test('regex_5 normalize后', norm(b5), false);
const b6 = grab(6, true);
test('regex_6 module 原始', b6, true);
test('regex_6 module normalize后', norm(b6), true);
const b8 = grab(8, false);
test('regex_8(禁用) 原始脚本', b8, false);
test('regex_8(禁用) normalize后', norm(b8), false);
