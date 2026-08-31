// $-特殊序列在库源码中的上下文 + 模拟 String.replace 替换字符串语义损坏度
const fs = require('fs');
['jquery.min.js', 'lodash.min.js', 'toastr.min.js', 'yaml.min.js'].forEach(f => {
  const s = fs.readFileSync('assets/libs/' + f, 'utf8');
  const pats = [/\$&/g, /\$'/g, /\$`/g, /\$\d/g];
  console.log('=== ' + f + ' ===');
  pats.forEach(p => {
    let m; let n = 0;
    while ((m = p.exec(s)) !== null && n < 5) {
      console.log(`  [${m.index}] ${JSON.stringify(m[0])} ctx: ${JSON.stringify(s.substring(Math.max(0, m.index - 40), m.index + 40))}`);
      n++;
    }
  });
});

// 实证 replace 语义: V8 对 \$& \$' \$1 的处理
console.log('\n=== String.replace 替换串语义实证(与 injectBridge 同型) ===');
const html = 'BEFORE<head>AFTER';
const patch = 'P1_$&_P2_$1_P3';
const out = html.replace(/<head>/i, '<head>' + patch);
console.log('含 $&/$1 的 patch 注入结果:', JSON.stringify(out));
console.log('结论: $& 被替换成匹配到的 "<head>" 自身; $1 在无捕获组时保持字面量');
