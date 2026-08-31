// regex_6: populateCharacterData 数据来源 + init() 内执行顺序
const fs = require('fs');
const card = JSON.parse(fs.readFileSync('DiaoYan/PiuPiuCard_《道渊》v5.2.json', 'utf8'));
const r6 = card.data.extensions.regex_scripts[6].replaceString;

const i = r6.indexOf('function populateCharacterData');
console.log('populateCharacterData 定义位置:', i);
console.log(r6.substring(i, i + 700));
console.log('\n=== init() 体内关键行(执行顺序) ===');
const initStart = r6.indexOf('async function init()');
const end = r6.indexOf('$(errorCatched(init))');
const initBody = r6.substring(initStart, end);
const keys = ['waitGlobalInitialized', 'loadWxSettings', 'fairyGuide.init', 'initMap', 'populateCharacterData', 'eventOn', "on('click'", 'Mvu'];
initBody.split('\n').forEach((ln, k) => {
  const t = ln.trim();
  if (keys.some(kk => t.includes(kk)) && /[a-zA-Z]/.test(t) && !/^[\/*]/.test(t)) {
    console.log(String(k).padStart(4), t.slice(0, 115));
  }
});
