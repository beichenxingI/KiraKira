// P3-D: 从 assets/chat/chat_stage.html 提取 injectBridge 里 P3-D 新增段的"拼接后实际 JS",
// 并做 node 语法检查。供两件事用:
//   1) 铁律3盲区自证(检查链只验壳里两个 <script> 块, 不验拼出来的 patch 字符串);
//   2) harness 用同一份提取结果注入 iframe, 保证 harness 与真注入逐字一致。
// 提取协议: 从 'var _EC_RETHROW=false;' 字面行起, 到 'for(var _k in _TH)' 行止,
// 只取单引号字符串字面量行(行首允许的空白 + 以 ' 开头), eval 每个字面量后拼接。
const fs = require('fs');
const vm = require('vm');

function extractP3DPatch(stagePath) {
  const src = fs.readFileSync(stagePath, 'utf8');
  const startMark = "'var _EC_RETHROW=false;'";
  const endMark = "'for(var _k in _TH){";
  const si = src.indexOf(startMark);
  const ei = src.indexOf(endMark);
  if (si < 0) throw new Error('未找到起点标记 ' + startMark);
  if (ei < 0) throw new Error('未找到终点标记 ' + endMark);
  if (ei <= si) throw new Error('终点在起点之前, 提取区间非法');
  const region = src.slice(si, ei);
  const lines = region.split('\n');
  let js = '';
  let taken = 0;
  for (const raw of lines) {
    const line = raw.trim();
    if (!line.startsWith("'")) continue; // 注释行/空行跳过
    // 去掉行尾 " +' " 连接符后就是纯 JS 字符串字面量, 交给 eval 按 JS 语义解析
    const litSrc = line.replace(/'\s*\+\s*$/, "'");
    // eslint-disable-next-line no-eval
    js += eval(litSrc);
    taken++;
  }
  return { js, taken };
}

module.exports = { extractP3DPatch };

if (require.main === module) {
  const { js, taken } = extractP3DPatch('assets/chat/chat_stage.html');
  console.log('提取字符串字面量行数:', taken);
  console.log('拼接后 JS 长度:', js.length);
  try {
    new vm.Script(js, { filename: 'p3d_patch.js' });
    console.log('P3-D patch 拼接产物: PARSE OK');
  } catch (e) {
    console.log('P3-D patch 拼接产物: PARSE FAIL =>', e.message);
    process.exit(1);
  }
  // 落盘供报告全文引用与 harness 复用
  fs.writeFileSync('DiaoYan/P3/诊断/out/p3d_patch_extracted.js', js);
  console.log('已写入 DiaoYan/P3/诊断/out/p3d_patch_extracted.js');
  console.log('---- 拼接后 JS 全文 ----');
  console.log(js);
}
