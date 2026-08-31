const fs = require('fs');
const path = fs.readdirSync('DiaoYan').find(f => f.includes('Vulgar') && f.endsWith('.json'));
const c = JSON.parse(fs.readFileSync('DiaoYan/' + path, 'utf8'));
const fm = c.data.first_mes;
console.log('first_mes len', fm.length);

let re = /```/g, m, i = 0;
while ((m = re.exec(fm))) {
  const near = fm.slice(Math.max(0, m.index - 10), m.index + 10).replace(/\n/g, '\\n');
  console.log('FENCE', i++, '@', m.index, JSON.stringify(near));
}

re = /<intro>|<\/intro>/gi;
while ((m = re.exec(fm))) {
  const near = fm.slice(Math.max(0, m.index - 25), m.index + 35).replace(/\n/g, '\\n');
  console.log('INTRO', m[0], '@', m.index, JSON.stringify(near));
}

re = /<!DOCTYPE|<html|<head|<body/gi;
while ((m = re.exec(fm))) {
  console.log('DOC', m[0], '@', m.index);
}

re = /<scene_body>|<\/scene_body>|<div |<\/div>/gi;
let cnt = 0;
while ((m = re.exec(fm)) && cnt++ < 20) {
  console.log('SCE', m[0], '@', m.index);
}

console.log('--- end ---');
