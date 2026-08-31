const B = '```';
const re = new RegExp('^' + B + '[a-zA-Z]*\\n([\\s\\S]*?)' + B + '\\s*$');
const s = B + 'html\nDOC6\n' + B + '\n' + B + 'html\nDOC7\n' + B;
const m = s.match(re);
console.log('hit:', !!m);
if (m) console.log('group1=', JSON.stringify(m[1]));
