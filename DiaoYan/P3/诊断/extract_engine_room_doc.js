// P3-E/E1: 从 assets/chat/chat_stage.html 的 createEngineRoom 里提取 doc 拼接产物,
// 逐块做 node vm.Script 语法检查。铁律3盲区自证: check_chat_stage.dart 只验壳里
// 两个 <script> 块, 验不到这里拼给引擎房 iframe 的 JS。
//
// 提取规则(照 extract_inject_patch.js 思路):
//   - 从 "function createEngineRoom" 起到 "+ '</body></html>';'" 止;
//   - "var doc =" 行重置缓冲(真实执行语义: 后一个赋值覆盖前一个);
//   - 以 ' 开头(允许前导空白与 "+ " 前缀)的行按单引号字面量 eval 后拼接;
//   - 含 window.__KIRA_LIBS 的三元行(库 base64)跳过, 产出里不体现(库内容与语法无关);
//   - facadeJs 用等长形状的桩代替(真 facade 由 Dart 构建且真机已证活, 不在本检查范围)。
// 产出: 完整 doc HTML → 抽出每个 <script> 块 → new vm.Script() 逐块验语法。
const fs = require('fs');
const vm = require('vm');

const STAGE = 'assets/chat/chat_stage.html';
const OUT_DIR = 'DiaoYan/P3/诊断/out';

function extractEngineRoomDoc(stagePath) {
  const src = fs.readFileSync(stagePath, 'utf8');
  const startMark = 'function createEngineRoom';
  const endMark = "+ '</body></html>';";
  const si = src.indexOf(startMark);
  const ei = src.indexOf(endMark);
  if (si < 0) throw new Error('未找到起点标记 ' + startMark);
  if (ei < 0) throw new Error('未找到终点标记 ' + endMark);
  if (ei <= si) throw new Error('终点在起点之前');
  const region = src.slice(si, ei + endMark.length);
  const lines = region.split('\n');
  let doc = '';
  let taken = 0;
  let skipped = 0;
  let resets = 0;
  for (const raw of lines) {
    const line = raw.trim();
    if (line.startsWith('var doc =')) {
      // 重置: 后一个 var doc 赋值覆盖前一个(真实 JS 语义)
      const lit = line.replace(/^var doc =/, '').replace(/;\s*$/, '');
      doc = eval(lit);
      resets++;
      taken++;
      continue;
    }
    if (!line.startsWith('+')) continue; // 函数头/注释/非拼接行
    if (line.includes('__KIRA_LIBS') || line.includes('decodeB64Utf8')) { skipped++; continue; }
    if (line.includes('facadeJs')) {
      // + '<script>' + facadeJs + '<\/script>' 拆在多行, 只对含 facadeJs 的行做替换
      const m = line.match(/facadeJs/);
      if (m && line.includes("'<script>' + facadeJs")) continue; // 起始行, 下行闭合再处理
    }
    // 把 "+ '<script>' + facadeJs + '<\/script>'" 这类行整体按字面量求值, facadeJs 变量名以桩替换
    let litSrc = line.replace(/^\+\s*/, '').replace(/;\s*$/, '');
    if (litSrc.includes('JSON.stringify(macros)')) {
      litSrc = litSrc.replace(/JSON\.stringify\(macros\)/, 'JSON.stringify({user:"User",char:"Assistant"})');
    }
    if (litSrc.includes('JSON.stringify(window.__KIRA_CHAT_ID')) {
      litSrc = litSrc.replace(/JSON\.stringify\(window\.__KIRA_CHAT_ID\|\|''\)/, "JSON.stringify('test-chat-id')");
    }
    if (!litSrc.startsWith("'")) { skipped++; continue; }
    // 行尾形如 "+ '<\/script>'" 已含在字面量里; 处理 "...' + '...'" 同行多段
    doc += eval(litSrc);
    taken++;
  }
  return { doc, taken, skipped, resets };
}

function extractScripts(doc) {
  const blocks = [];
  const re = /<script>([\s\S]*?)<\/script>/g;
  let m;
  while ((m = re.exec(doc)) !== null) blocks.push(m[1]);
  return blocks;
}

if (require.main === module) {
  const { doc, taken, skipped, resets } = extractEngineRoomDoc(STAGE);
  console.log('字面量行取用:', taken, ' 跳过(库三元/非字面量):', skipped, ' var doc 重置次数:', resets);
  console.log('doc 产物长度:', doc.length);
  fs.mkdirSync(OUT_DIR, { recursive: true });
  fs.writeFileSync(OUT_DIR + '/engine_room_doc.html', doc, 'utf8');
  const blocks = extractScripts(doc);
  console.log('script 块数:', blocks.length);
  let fail = 0;
  blocks.forEach((code, i) => {
    try {
      new vm.Script(code, { filename: 'engine_room_block_' + i + '.js' });
      console.log('block[' + i + '] len=' + code.length + ' : PARSE OK');
    } catch (e) {
      fail++;
      console.log('block[' + i + '] len=' + code.length + ' : PARSE FAIL => ' + e.message);
      const stack = e.stack || '';
      console.log('---- block[' + i + '] 全文 ----');
      console.log(code);
    }
  });
  console.log(fail === 0 ? 'ENGINE ROOM DOC: ALL BLOCKS OK' : 'ENGINE ROOM DOC: ' + fail + ' BLOCK(S) FAILED');
  process.exit(fail === 0 ? 0 : 1);
}

module.exports = { extractEngineRoomDoc, extractScripts };
