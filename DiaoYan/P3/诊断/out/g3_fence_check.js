const fs = require('fs');
const s = fs.readFileSync('DiaoYan/P3/诊断/out/T9_both_markers_1_afterRegex.txt', 'utf8');
// 模拟 segs 切段: allMatches 配对 ```html\n...```
const re = /```html\s*\n([\s\S]*?)```/gi;
const matches = [...s.matchAll(re)];
console.log('围栏对数:', matches.length);
matches.forEach((m, i) => {
  console.log('seg[' + i + '] start=' + m.index + ' end=' + (m.index + m[0].length) + ' 内容长=' + m[1].length + ' 含DOCTYPE:', /<!doctype|<!DOCTYPE/i.test(m[1]), ' 含<script:', m[1].includes('<script'));
});
// 围栏间碎片
let cursor = 0;
const frags = [];
for (const m of matches) {
  if (m.index > cursor) frags.push(s.slice(cursor, m.index));
  cursor = m.index + m[0].length;
}
if (cursor < s.length) frags.push(s.slice(cursor));
console.log('围栏外碎片数:', frags.length);
frags.forEach((f, i) => console.log('frag[' + i + '] len=' + f.length + ' :', JSON.stringify(f.slice(0, 60))));
