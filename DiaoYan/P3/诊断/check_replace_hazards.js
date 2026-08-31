// runRegexScript 对 replaceString 的二次改写风险统计($0/$1/{{match}}/{{char}}/{{user}}/$<)
const fs = require('fs');
const vm = require('vm');
const card = JSON.parse(fs.readFileSync('DiaoYan/PiuPiuCard_《道渊》v5.2.json', 'utf8'));
[6, 7, 5, 8].forEach(i => {
  const s = card.data.extensions.regex_scripts[i].replaceString;
  const c = (re) => (s.match(re) || []).length;
  console.log(`regex_${i}: $0=${c(/\$0/g)} $1=${c(/\$1(?![0-9])/g)} {{match}}=${c(/\{\{match\}\}/gi)} {{char}}=${c(/\{\{char\}\}/gi)} {{user}}=${c(/\{\{user\}\}/gi)} $<...>=${c(/\$<([^>]+)>/g)}`);
});
// 顺: first_mes
const f = card.data.first_mes;
const cf = (re) => (f.match(re) || []).length;
console.log(`first_mes: $0=${cf(/\$0/g)} $1=${cf(/\$1(?![0-9])/g)} {{match}}=${cf(/\{\{match\}\}/gi)} {{char}}=${cf(/\{\{char\}\}/gi)} {{user}}=${cf(/\{\{user\}\}/gi)}`);
