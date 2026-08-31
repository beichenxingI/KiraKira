// P3-F/G1: 端到端灌真卡 harness 生成器(纯诊断,非产品代码)。
// 产物: out/g1_U{1,2,3}_host.html —— 用 Edge headless 跑:
//   msedge.exe --headless=new --virtual-time-budget=20000 --dump-dom out\g1_U1_host.html > out\g1_U1_dom.txt
// 组成:
//   - T2_marker_only_6_rendered.txt = pipeline_repro.dart 用真实 RegexService 产出的 regex_6 状态栏最终文档
//   - patch = extract_inject_bridge_patch.js 从生产 assets/chat/chat_stage.html 真实提取(非仿制品)
//   - 真库 jquery/lodash/toastr/yaml 填入 patch 的 /*_libScript*/ 桩(函数形式 replace, 防 $ 特殊替换, P3-D3 教训)
//   - 探针(仅 harness): 每虚拟秒上报数值节点文本 + typeof window.Mvu + getAllVariables().stat_data
// 用例:
//   U1 有数据: load+300ms 投喂 {__thVars:true,type:'message',data:{stat_data},floor_idx:3,lastMsgId:3,swipe_id:0}
//   U2 无数据: 不投喂
//   U3 晚到:   load+5000ms 才投喂
const fs = require('fs');
const path = require('path');
const { extractPatch } = require('./extract_inject_bridge_patch.js');
const OUT = path.join(__dirname, 'out');

const libs = {
  jquery: fs.readFileSync('assets/libs/jquery.min.js', 'utf8'),
  lodash: fs.readFileSync('assets/libs/lodash.min.js', 'utf8'),
  toastrJs: fs.readFileSync('assets/libs/toastr.min.js', 'utf8'),
  toastrCss: fs.readFileSync('assets/libs/toastr.min.css', 'utf8'),
  yaml: fs.readFileSync('assets/libs/yaml.min.js', 'utf8'),
};
const esc = (s) => s.replace(/<\/script>/gi, '<\\/script>');
let libScript = '';
libScript += '<script>' + esc(libs.jquery) + '<\/script>';
libScript += '<script>' + esc(libs.lodash) + '<\/script>';
libScript += '<style>' + libs.toastrCss + '<\/style>';
libScript += '<script>' + esc(libs.toastrJs) + '<\/script>';
libScript += '<script>' + esc(libs.yaml) + '<\/script>';

// G1-a: stat_data 来源 = 卡 [initvar] 初始 结构(与 run.log 真机 [setVars落] 完全同构), 数值改以可判读
const statData = JSON.parse(fs.readFileSync(path.join(OUT, 'G1_stat_data_real.json'), 'utf8'));
statData['主角']['姓名'] = '测试仙尊';
statData['主角']['生命'] = 77;
statData['主角']['精血'] = 66;
statData['主角']['灵力'] = 55;
statData['主角']['修为'] = 42;
statData['主角']['神识'] = 88;
statData['主角']['道心'] = 33;
const MVU_ENV = {
  __thVars: true, type: 'message',
  data: { stat_data: statData },
  floor_idx: 3, lastMsgId: 3, swipe_id: 0,
};

function buildDoc(rendered) {
  let doc = rendered
    .replace(/https:\/\/fonts\.googleapis\.com/g, 'http://127.0.0.1:9/x')
    .replace(/https:\/\/free-img\.400040\.xyz/g, 'http://127.0.0.1:9/y');
  const patch = extractPatch().replace('/*_libScript*/', function () { return libScript; });
  const probe = '<script>(function(){'
    + 'var ids=["name-value","hp-value","blood-value","mp-value","exp-value","san-value","daoxin-value"];'
    + 'var n=0;'
    + 'setInterval(function(){n++;'
    + 'var parts=[];for(var i=0;i<ids.length;i++){var el=document.getElementById(ids[i]);parts.push(ids[i]+"="+((el&&el.textContent!=="")?el.textContent:"(空)"));}'
    + 'var sv="ERR";try{sv=JSON.stringify((window.getAllVariables&&window.getAllVariables().stat_data)||null);}catch(e){sv="ERR:"+e;}'
    + 'parent.postMessage({testlog:true,text:"[PROBE#"+n+"] Mvu="+(typeof window.Mvu)+" "+parts.join(" ")+" stat_data="+sv.substring(0,150)},"*");'
    + '},1000);'
    + '})();<\/script>';
  if (/<\/body>/i.test(doc)) doc = doc.replace(/<\/body>/i, function () { return probe + '</body>'; });
  else doc += probe;
  if (/<head>/i.test(doc)) doc = doc.replace(/<head>/i, function () { return '<head>' + patch; });
  else doc = patch + doc;
  return doc;
}

function buildHost(label, feedJs) {
  const doc = buildDoc(fs.readFileSync(path.join(OUT, 'T2_marker_only_6_rendered.txt'), 'utf8'));
  const b64 = Buffer.from(doc, 'utf8').toString('base64');
  const host = '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>' + label + '</title></head><body>'
    + '<div id="log">loading</div><iframe id="f" style="width:800px;height:600px"></iframe>'
    + '<script>'
    + 'var out=[];function L(t){out.push(t);document.getElementById("log").textContent=out.join("\\n");}'
    + 'window.addEventListener("message",function(e){if(e.data&&(e.data.testlog||e.data.__thLog))L("[iframe] "+e.data.text);});'
    + 'window.addEventListener("error",function(e){L("[host-onerror] "+(e.message||e.type));},true);'
    + 'var b64=' + JSON.stringify(b64) + ';'
    + 'var bin=atob(b64);var bytes=new Uint8Array(bin.length);for(var i=0;i<bin.length;i++)bytes[i]=bin.charCodeAt(i);'
    + 'var html=new TextDecoder("utf-8").decode(bytes);'
    + 'var f=document.getElementById("f");'
    + 'var blob=new Blob([html],{type:"text/html; charset=utf-8"});var url=URL.createObjectURL(blob);'
    + 'f.addEventListener("load",function(){L("[host] iframe load");' + feedJs
    + 'setTimeout(function(){L("HARVEST_DONE");},10000);});'
    + 'f.src=url;<\/script></body></html>';
  fs.writeFileSync(path.join(OUT, 'g1_' + label + '_host.html'), host, 'utf8');
  console.log(label + ' host 已写, doc=' + doc.length + ' chars, env=' + JSON.stringify(MVU_ENV).length + ' chars');
}

const envJson = JSON.stringify(MVU_ENV);
buildHost('U1', 'setTimeout(function(){f.contentWindow.postMessage(' + envJson + ',"*");L("[host] 已投喂 message 快照 floor_idx=3 lastMsgId=3");},300);');
buildHost('U2', '');
buildHost('U3', 'setTimeout(function(){f.contentWindow.postMessage(' + envJson + ',"*");L("[host] 晚到投喂 message 快照 floor_idx=3 lastMsgId=3");},5000);');
console.log('DONE');
