const fs = require('fs');
for (const u of ['U1p', 'U2', 'U3', 'U1d']) {
  const s = fs.readFileSync('DiaoYan/P3/诊断/out/g1_' + u + '_dom.txt', 'utf8');
  const m = s.match(/<div id="log">([\s\S]*?)<\/div>/);
  console.log('########## ' + u + ' ##########');
  if (!m) { console.log('NO LOG DIV'); continue; }
  const lines = m[1].split('\n');
  const uniq = [];
  const seen = new Set();
  for (const l of lines) {
    if (l.includes('REPORT:ping')) continue;
    const key = l.replace(/\d+/g, '#');
    if (seen.has(key)) continue;
    seen.add(key);
    uniq.push(l);
  }
  uniq.forEach(l => console.log(l.slice(0, 900)));
  const reps = lines.filter(l => l.includes('REPORT'));
  if (reps.length) console.log('[REPORT x' + reps.length + ', 最后一条] ' + reps[reps.length - 1].slice(0, 900));
}
