// P3-诊断 Task A: 解剖卡 JSON(只读,零改动)
// 用法: node DiaoYan/P3/诊断/analyze_card.js
const fs = require('fs');
const path = require('path');

const CARD = path.join(__dirname, '..', '..', 'PiuPiuCard_《道渊》v5.2.json');
const OUT = path.join(__dirname, 'out');
fs.mkdirSync(OUT, { recursive: true });

const raw = fs.readFileSync(CARD, 'utf8');
const card = JSON.parse(raw);
const data = card.data || card;

console.log('=== 卡顶字段 ===');
console.log('card keys:', Object.keys(card).join(','));
console.log('data keys:', Object.keys(data).join(','));
console.log('name:', JSON.stringify(data.name));

const scripts = (data.extensions && data.extensions.regex_scripts) || [];
console.log('\n=== A1. regex_scripts 共 ' + scripts.length + ' 条 ===');

const markerCounts = (s) => {
  const count = (re) => (s.match(re) || []).length;
  return {
    len_chars: s.length,
    len_bytes_utf8: Buffer.byteLength(s, 'utf8'),
    '<script': count(/<script/gi),
    '</script>': count(/<\/script>/gi),
    '<style': count(/<style/gi),
    '</style>': count(/<\/style>/gi),
    '```html': count(/```html/gi),
    '```': count(/```/g),
    'errorCatched': count(/errorCatched/g),
    '$(': count(/\$\(/g),
    'function init': count(/function init/g),
    'StatusPlaceHolderImpl': count(/StatusPlaceHolderImpl/g),
  };
};

scripts.forEach((s, i) => {
  console.log(`\n--- [${i}] ${s.scriptName} ---`);
  console.log('  keys:', Object.keys(s).join(','));
  console.log('  has id:', typeof s.id, s.id ? String(s.id).slice(0, 40) : '(无)');
  console.log('  disabled:', s.disabled, '| markdownOnly:', s.markdownOnly, '| promptOnly:', s.promptOnly, '| runOnEdit:', s.runOnEdit);
  console.log('  placement:', JSON.stringify(s.placement), '(元素类型:', (Array.isArray(s.placement) ? s.placement.map(x => typeof x).join(',') : typeof s.placement), ')');
  console.log('  minDepth:', s.minDepth, '| maxDepth:', s.maxDepth, '| order:', s.order, '| substituteRegex:', s.substituteRegex);
  console.log('  trimStrings:', JSON.stringify(s.trimStrings));
  const fr = s.findRegex || '';
  console.log('  findRegex length:', fr.length);
  console.log('  findRegex 前200字符:', JSON.stringify(fr.slice(0, 200)));
  const rs = s.replaceString || '';
  const mc = markerCounts(rs);
  console.log('  replaceString:', JSON.stringify(mc));
});

// ==== A2. UI 脚本结构骨架 ====
const uiIdx = [];
scripts.forEach((s, i) => {
  const rs = s.replaceString || '';
  if (/<script/i.test(rs) && /errorCatched|\$\(|function init/.test(rs)) uiIdx.push(i);
});
console.log('\n=== A2. 含前端代码的脚本 index:', uiIdx.join(','), '===');

const skeleton = (s, name) => {
  const rs = s.replaceString;
  const lines = [];
  lines.push(`##### ${name} 骨架 (总长 ${rs.length} 字符)`);
  // 找所有 <style, </style>, <script, </script>, ``` , errorCatched, $(errorCatched(init))
  const events = [];
  const push = (re, tag) => {
    let m;
    const r = new RegExp(re.source, re.flags.includes('g') ? re.flags : re.flags + 'g');
    while ((m = r.exec(rs)) !== null) {
      events.push({ off: m.index, tag, txt: m[0].slice(0, 60) });
      if (m[0].length === 0) r.lastIndex++;
    }
  };
  push(/<style[^>]*>/gi, 'STYLE_OPEN');
  push(/<\/style>/gi, 'STYLE_CLOSE');
  push(/<script[^>]*>/gi, 'SCRIPT_OPEN');
  push(/<\/script>/gi, 'SCRIPT_CLOSE');
  push(/```[a-zA-Z]*/g, 'FENCE');
  push(/errorCatched/g, 'errorCatched');
  push(/function init\s*\(/g, 'FUNC_INIT');
  events.sort((a, b) => a.off - b.off);
  // 限制 FENCE 只打带语言标记或前后文
  events.forEach(e => {
    const ctx = rs.slice(Math.max(0, e.off - 0), Math.min(rs.length, e.off + 60)).replace(/\r/g, '');
    lines.push(`  [${e.off}] ${e.tag}: ${JSON.stringify(ctx.slice(0, 60))}`);
  });
  return lines.join('\n');
};

uiIdx.forEach(i => {
  const txt = skeleton(scripts[i], `[${i}] ${scripts[i].scriptName}`);
  const f = path.join(OUT, `A2_skeleton_${i}.txt`);
  fs.writeFileSync(f, txt, 'utf8');
  console.log(`骨架已写 ${f} (事件条数=${txt.split('\n').length - 1})`);
  console.log(txt);
  // 头/尾 200 字符
  const rs = scripts[i].replaceString;
  console.log(`  [${i}] replaceString 头200:`, JSON.stringify(rs.slice(0, 200)));
  console.log(`  [${i}] replaceString 尾200:`, JSON.stringify(rs.slice(-200)));
});

// ==== A3. first_mes ====
const firstMes = data.first_mes || '';
console.log('\n=== A3. first_mes ===');
console.log('总长(字符):', firstMes.length, '| UTF-8字节:', Buffer.byteLength(firstMes, 'utf8'));
fs.writeFileSync(path.join(OUT, 'A3_first_mes_full.txt'), firstMes, 'utf8');
{
  const events = [];
  const push = (re, tag) => {
    let m;
    const r = new RegExp(re.source, re.flags.includes('g') ? re.flags : re.flags + 'g');
    while ((m = r.exec(firstMes)) !== null) {
      events.push({ off: m.index, tag, txt: m[0] });
      if (m[0].length === 0) r.lastIndex++;
    }
  };
  push(/```[a-zA-Z]*/g, 'FENCE');
  push(/<script[^>]*>/gi, 'SCRIPT_OPEN');
  push(/<\/script>/gi, 'SCRIPT_CLOSE');
  push(/<style[^>]*>/gi, 'STYLE_OPEN');
  push(/<StatusPlaceHolderImpl\s*\/?>/g, ' StatusPlaceHolder');
  push(/errorCatched/g, 'errorCatched');
  events.sort((a, b) => a.off - b.off);
  console.log('事件列表:');
  events.forEach(e => {
    const ctxStart = Math.max(0, e.off - 40);
    const ctx = firstMes.slice(ctxStart, Math.min(firstMes.length, e.off + 60)).replace(/\r/g, '');
    console.log(`  [${e.off}] ${e.tag}: ...${JSON.stringify(ctx)}...`);
  });
  console.log('头200:', JSON.stringify(firstMes.slice(0, 200)));
  console.log('尾200:', JSON.stringify(firstMes.slice(-200)));
}

// ==== A4. 确认按钮"是" ====
console.log('\n=== A4. 确认按钮搜索 ===');
const searchIn = (hay, label) => {
  const patterns = [/>是</g, /\bid\s*=\s*["'][^"']*(confirm|yes|ok)[^"']*["']/gi, /addEventListener\(['"]click/g, /\.on\(['"]click/g, /onclick\s*=/gi];
  patterns.forEach(p => {
    let m; const r = p;
    while ((m = r.exec(hay)) !== null) {
      const ctx = hay.slice(Math.max(0, m.index - 150), Math.min(hay.length, m.index + 150)).replace(/\r/g, '').replace(/\n/g, '\\n');
      console.log(`  [${label} @${m.index}] /${p.source}/ => ...${JSON.stringify(ctx)}...`);
      if (m[0].length === 0) r.lastIndex++;
    }
  });
};
uiIdx.forEach(i => searchIn(scripts[i].replaceString, `regex_${i}`));
searchIn(firstMes, 'first_mes');

// ==== 交叉验证: 与 P3-0 提取文件是否一致 ====
console.log('\n=== 交叉验证: 样本解剖 提取文件 vs JSON ===');
const anatDir = path.join(__dirname, '..', '样本解剖');
if (fs.existsSync(anatDir)) {
  [6, 7].forEach(i => {
    const files = fs.readdirSync(anatDir).filter(f => f.startsWith(`regex_${i}_`));
    if (files.length) {
      const content = fs.readFileSync(path.join(anatDir, files[0]), 'utf8');
      const rs = scripts[i].replaceString;
      const idx = content.indexOf(rs.slice(0, 500));
      console.log(`  regex_${i}: 提取文件=${files[0]}, 文件长度=${content.length}, replaceString长度=${rs.length}, 文件内含replaceString头部=${idx >= 0}`);
    }
  });
}
console.log('\nDONE');
