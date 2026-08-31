// P3-D Task 1 验证: 找 T5 rendered 产物里的 "" 双引号炸弹行(旧 normalize 的产物)
const fs = require('fs');
const t = fs.readFileSync('DiaoYan/P3/诊断/out/T5_chongsu_6_rendered.txt', 'utf8');
const BOMB = '"' + '"'; // 相邻两个直双引号
const lines = t.split('\n');
const hits = [];
lines.forEach((l, i) => { if (l.includes(BOMB)) hits.push(i + 1); });
console.log('T5 rendered 中 "" 碰撞行数:', hits.length);
hits.slice(0, 5).forEach((n) => console.log('  行' + n + ': ' + JSON.stringify(lines[n - 1].slice(0, 110))));
const idx = t.indexOf('真·深蓝加点');
const lineStart = t.lastIndexOf('\n', idx) + 1;
const lineEnd = t.indexOf('\n', idx);
console.log('深蓝行(rendered 原样):', JSON.stringify(t.slice(lineStart, lineEnd).slice(0, 110)));
