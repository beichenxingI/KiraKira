// P3-E2/E3: 从 assets/chat/chat_stage.html 的 injectBridge 提取 patch 拼接产物并验语法。
// 做法: patch 区("var patch = _guardErr" 起, 到 "'})();<\/script>' + _guardBlank;" 止)
// 整段是一条合法的 var 赋值表达式 → 在带宿主桩变量(id/floorIdx/_guardErr...)的作用域里
// eval 出完整 patch 字符串 → 抠出每个 <script> 块 → vm.Script 逐块验语法。
// 铁律3盲区自证: check_chat_stage.dart 只验壳里两个 <script> 块, 验不到这个拼接串。
// 用法: node extract_inject_bridge_patch.js
const fs = require('fs');
const vm = require('vm');

const STAGE = 'assets/chat/chat_stage.html';
const OUT_DIR = 'DiaoYan/P3/诊断/out';

function extractPatch() {
  const src = fs.readFileSync(STAGE, 'utf8');
  const lines = src.split('\n');
  let si = -1, ei = -1;
  for (let i = 0; i < lines.length; i++) {
    const t = lines[i].trim();
    if (si < 0 && t.startsWith('var patch = _guardErr')) si = i;
    if (si >= 0 && t.includes("+ _guardBlank")) { ei = i; break; }
  }
  if (si < 0) throw new Error('未找到 patch 起点(var patch = _guardErr)');
  if (ei < 0) throw new Error('未找到 patch 终点(_guardBlank)');
  // 宿主桩变量(对应 injectBridge 作用域)
  var id = 'TEST_CARD_0';
  var floorIdx = 3;
  var _thFloorIdx = 3;
  var _guardErr = '/*_guardErr*/';
  var _guardEnv = '/*_guardEnv*/';
  var _guardBlank = '/*_guardBlank*/';
  var _libScript = '/*_libScript*/';
  var _macros = { user: 'User', char: 'Assistant' };
  const region = lines.slice(si, ei + 1).join('\n');
  const patch = eval(region.replace('var patch =', 'patchValue =')); // eval 赋值表达式, 返回 patch 值
  return patch;
}

function extractScripts(s) {
  const blocks = [];
  const re = /<script>([\s\S]*?)<\/script>/g;
  let m;
  while ((m = re.exec(s)) !== null) blocks.push(m[1]);
  return blocks;
}

if (require.main === module) {
  const patch = extractPatch();
  console.log('patch 总长:', patch.length);
  fs.mkdirSync(OUT_DIR, { recursive: true });
  fs.writeFileSync(OUT_DIR + '/inject_patch_extracted.html', patch, 'utf8');
  const blocks = extractScripts(patch);
  console.log('script 块数:', blocks.length);
  let fail = 0;
  blocks.forEach((code, i) => {
    try {
      new vm.Script(code, { filename: 'inject_patch_block_' + i + '.js' });
      console.log('block[' + i + '] len=' + code.length + ' : PARSE OK');
    } catch (e) {
      fail++;
      console.log('block[' + i + '] len=' + code.length + ' : PARSE FAIL => ' + e.message);
      fs.writeFileSync(OUT_DIR + '/inject_patch_block_' + i + '_fail.js', code, 'utf8');
    }
  });
  console.log(fail === 0 ? 'INJECT PATCH: ALL BLOCKS OK' : 'INJECT PATCH: ' + fail + ' BLOCK(S) FAILED');
  process.exit(fail === 0 ? 0 : 1);
}

module.exports = { extractPatch, extractScripts };
