// P3-F/G1 harness v3: 双向探针。
//  - probe-A(head): 自身 setInterval 心跳 + 响应 host 的 __probePing(即时全量回报)
//    + unload 监听 + document.open/write 检测 → 判断 iframe 文档是否被替换
//  - host: feed 后每 500ms 发一次 __probePing, 收到 probe 报文即记录
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
  + 'parent.postMessage({testlog:true,text:"[REPORT:"+tag+"] Mvu="+(typeof window.Mvu)+" "+parts.join(" ")+" stat_data="+sv.substring(0,120)},"*");'
  + '}'
  + 'var tick=0;'
  + 'var iv=setInterval(function(){tick++;try{parent.postMessage({testlog:true,text:"[TICK "+tick+"]"},"*");}catch(e){}},1000);'
  + 'window.addEventListener("message",function(e){var d=e.data;if(!d||!d.__probePing)return;try{report("ping"+d.seq);}catch(err){parent.postMessage({testlog:true,text:"[REPORT-ERR] "+err},"*");}});'
  + 'window.addEventListener("unload",function(){try{parent.postMessage({testlog:true,text:"[probe] UNLOAD"},"*");}catch(e){}});'
  + 'try{var _do=document.open;document.open=function(){parent.postMessage({testlog:true,text:"[probe] document.open() 被调用"},"*");return _do.apply(document,arguments);};}catch(e){}'
  + 'try{var _dw=document.write;document.write=function(){parent.postMessage({testlog:true,text:"[probe] document.write() 被调用"},"*");return _dw.apply(document,arguments);};}catch(e){}'
  + 'parent.postMessage({testlog:true,text:"[probe-installed] readyState="+document.readyState},"*");'
  + '})();<\/script>';

function buildDoc(rendered) {
  let doc = rendered
    .replace(/https:\/\/fonts\.googleapis\.com/g, 'http://127.0.0.1:9/x')
    .replace(/https:\/\/free-img\.400040\.xyz/g, 'http://127.0.0.1:9/y');
  const patch = extractPatch().replace('/*_libScript*/', function () { return libScript + PROBE; });
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
    + 'var seq=0,piv=null;'
    + 'f.addEventListener("load",function(){L("[host] iframe load");' + feedJs
    + 'piv=setInterval(function(){seq++;try{f.contentWindow.postMessage({__probePing:true,seq:seq},"*");}catch(e){}},500);'
    + 'setTimeout(function(){clearInterval(piv);L("HARVEST_DONE");},9000);});'
    + 'f.src=url;<\/script></body></html>';
  fs.writeFileSync(path.join(OUT, 'g1_' + label + '_host.html'), host, 'utf8');
  console.log(label + ' host 已写, doc=' + doc.length + ' chars');
}

const envJson = JSON.stringify(MVU_ENV);
buildHost('U1', 'setTimeout(function(){f.contentWindow.postMessage(' + envJson + ',"*");L("[host] 已投喂 message 快照 floor_idx=3 lastMsgId=3");},300);');
buildHost('U2', '');
buildHost('U3', 'setTimeout(function(){f.contentWindow.postMessage(' + envJson + ',"*");L("[host] 晚到投喂 message 快照 floor_idx=3 lastMsgId=3");},5000);');
console.log('DONE');
