const fs = require('fs');
const card = JSON.parse(fs.readFileSync('DiaoYan/PiuPiuCard_《道渊》v5.2.json', 'utf8'));
const d = card.data || card;
const book = (d.character_book && d.character_book.entries) || [];
for (const e of book) {
  if (e.comment === '状态栏' || (e.content || '').includes('每次回复都必须在文本底部生成')) {
    console.log('=== entry:', e.comment, 'constant:', e.constant, 'position:', e.position, '===');
    console.log(e.content.slice(0, 800));
    break;
  }
}
