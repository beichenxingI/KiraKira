// P3-F/G1 harness v6 = v5 + U1p(预置快照):
//  虚拟时间下 blob iframe 内 setInterval 不走(实测 TICK=0), 卡 init 的
//  waitGlobalInitialized 轮询停摆。U1p 把快照在 patch 尾同步预置
//  (window.__thVars.message[3]=env + __thArmMvu()), 模拟真机
//  "存量快照推送/索取先于模块求值"的场景 → waitGlobalInitialized 首行
//  typeof window.Mvu!=='undefined' 同步 resolve → init 无定时器依赖走完。
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

const PROBE = '<script>(function(){'
  + 'var ids=["name-value","hp-value","blood-value","mp-value","exp-value","san-value","daoxin-value"];'
  + 'function report(tag){'
  + 'var parts=[];for(var i=0;i<ids.length;i++){var el=document.getElementById(ids[i]);parts.push(ids[i]+"="+((el&&el.textContent!=="")?el.textContent:"(空)"));}'
  + 'var sv="ERR";try{sv=JSON.stringify((window.getAllVariables&&window.getAllVariables().stat_data)||null);}catch(e){sv="ERR:"+e;}'
  + 'parent.postMessage({testlog:true,text:"[REPORT:"+tag+"] Mvu="+(typeof window.Mvu)+" "+parts.join(" ")+" stat_data="+(sv==="null"?"null":"HAS(stat_data)")},"*");'
  + '}'
  + 'window.addEventListener("message",function(e){var d=e.data;if(!d||!d.__probePing)return;try{report("ping"+d.seq);}catch(err){parent.postMessage({testlog:true,text:"[REPORT-ERR] "+err},"*");}});'
  + 'window.addEventListener("load",function(){try{report("onload");}catch(e){}});'
  + 'parent.postMessage({testlog:true,text:"[probe-installed] readyState="+document.readyState},"*");'
  + '})();<\/script>';

// 预置快照片段(仅 harness, 非产品): 与 __thVars 信封处理等价的同步写法
function presetSnippet() {
  return '<script>(function(){'
    + 'try{'
    + 'window.__thVars.message[' + MVU_ENV.floor_idx + ']=' + JSON.stringify(MVU_ENV.data) + ';'
    + 'window.__thVars.swipes[' + MVU_ENV.floor_idx + ']=0;'
    + 'window.__thVars.lastMsgId=' + MVU_ENV.lastMsgId + ';'
    + 'if(typeof __thArmMvu==="function"){__thArmMvu();parent.postMessage({testlog:true,text:"[preset] 快照已预置, __thArmMvu 已调"},"*");}'
    + 'else{parent.postMessage({testlog:true,text:"[preset] __thArmMvu 不存在!"},"*");}'
    + '}catch(e){parent.postMessage({testlog:true,text:"[preset-ERR] "+e},"*");}'
    + '})();<\/script>';
}

function buildDoc(rendered, preset) {
  let doc = rendered
    .replace(/https:\/\/fonts\.googleapis\.com/g, 'http://127.0.0.1:9/x')
    .replace(/https:\/\/free-img\.400040\.xyz/g, 'http://127.0.0.1:9/y');
  const patch = extractPatch().replace('/*_libScript*/', function () { return libScript + PROBE + (preset ? presetSnippet() : ''); });
  if (/<head>/i.test(doc)) doc = doc.replace(/<head>/i, function () { return '<head>' + patch; });
  else doc = patch + doc;
  return doc;
}

function buildHost(label, renderedPath, feedJs, preset) {
  const doc = buildDoc(fs.readFileSync(path.join(OUT, renderedPath), 'utf8'), preset);
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
    + 'var seq=0,piv=null;'
    + 'f.addEventListener("load",function(){L("[host] iframe load");' + feedJs
    + 'piv=setInterval(function(){seq++;try{f.contentWindow.postMessage({__probePing:true,seq:seq},"*");}catch(e){}},200);'
    + 'setTimeout(function(){clearInterval(piv);L("HARVEST_DONE");},6000);});'
    + 'f.src=url;<\/script></body></html>';
  fs.writeFileSync(path.join(OUT, 'g1_' + label + '_host.html'), host, 'utf8');
  console.log(label + ' host 已写');
}

const envJson = JSON.stringify(MVU_ENV);
// U1p: 预置快照(patch 内同步), 无动态投喂 —— 验证 DOM 数字(主判据)
buildHost('U1p', 'T2_marker_only_6_rendered.txt', '', true);
// U1d: 动态投喂(load+300ms) —— 已跑过 v5, 此处保留同款作对照
buildHost('U1d', 'T2_marker_only_6_rendered.txt', 'setTimeout(function(){f.contentWindow.postMessage(' + envJson + ',"*");L("[host] 已投喂 message 快照 floor_idx=3 lastMsgId=3");},300);', false);
// U2: 无数据
buildHost('U2', 'T2_marker_only_6_rendered.txt', '', false);
// U3: 晚到 5s
buildHost('U3', 'T2_marker_only_6_rendered.txt', 'setTimeout(function(){f.contentWindow.postMessage(' + envJson + ',"*");L("[host] 晚到投喂 message 快照 floor_idx=3 lastMsgId=3");},5000);', false);
console.log('DONE');
