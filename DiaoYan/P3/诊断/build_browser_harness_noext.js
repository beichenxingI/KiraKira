// 生成"断外网"变体 harness: 把外网 URL 重写到 127.0.0.1:9(快速连接失败), JS 逐字保留
// [P3-D 更新] _TH 段不再手写仿制品: errorCatched/waitGlobalInitialized 的 JS 由
// extract_inject_patch.js 直接从 assets/chat/chat_stage.html 提取(eval 每个字符串字面量
// 后拼接), 与真 injectBridge 注入的 patch 逐字同源; 组装式仿品只剩 _TH={}/_id/for-in 挂窗
// 三行骨架, 形状与真 patch 一致(_TH 在真 patch 655 行为 var _TH={}, _id 为其闭包变量)。
const fs = require('fs');
const path = require('path');
const { extractP3DPatch } = require('./extract_inject_patch.js');
const P3D = extractP3DPatch('assets/chat/chat_stage.html');
const OUT = path.join(__dirname, 'out');

const libs = {
  jquery: fs.readFileSync('assets/libs/jquery.min.js', 'utf8'),
  lodash: fs.readFileSync('assets/libs/lodash.min.js', 'utf8'),
  toastr: fs.readFileSync('assets/libs/toastr.min.js', 'utf8'),
  yaml: fs.readFileSync('assets/libs/yaml.min.js', 'utf8'),
};
const toastrCss = fs.readFileSync('assets/libs/toastr.min.css', 'utf8');

function makePatch(label) {
  const esc = (s) => s.replace(/<\/script>/gi, '<\\/script>');
  return {
    guard: '<script>(function(){'
      + 'window.__ranScripts=[];'
      + 'var _ed = window.onerror;'
      + 'window.onerror=function(m,s,l,c){parent.postMessage({testlog:true,text:"CARD-ERR: "+String(m)+" @"+l+":"+c},"*");return false;};'
      + 'window.addEventListener("unhandledrejection",function(ev){parent.postMessage({testlog:true,text:"CARD-ERR(rejection): "+(ev.reason&&ev.reason.message||ev.reason)},"*");});'
      + 'var _s={};try{localStorage.getItem("__t");}catch(e){Object.defineProperty(window,"localStorage",{configurable:true,value:{getItem:function(k){return _s[k]||null;},setItem:function(k,v){_s[k]=String(v);},removeItem:function(k){delete _s[k];},clear:function(){_s={};},key:function(i){return Object.keys(_s)[i]||null;},get length(){return Object.keys(_s).length;}}});}'
      + 'var _oa=document.addEventListener.bind(document);document.addEventListener=function(t,f,o){if(t==="DOMContentLoaded"&&document.readyState!=="loading"){setTimeout(f,0);}else{_oa(t,f,o);}};'
      + 'parent.postMessage({testlog:true,text:"[patch] 已执行(库注入应由后续script完成)"},"*");'
      + '})();<\/script>',
    libs:
      '<script>' + esc(libs.jquery) + '<\/script>'
      + '<script>' + esc(libs.lodash) + '<\/script>'
      + '<style>' + toastrCss + '<\/style>'
      + '<script>' + esc(libs.toastr) + '<\/script>'
      + '<script>' + esc(libs.yaml) + '<\/script>'
      + '<script>(function(){parent.postMessage({testlog:true,text:"[patch2] lib装载后: $="+(typeof window.$)+" _="+(typeof window._)+" toastr="+(typeof window.toastr)+" YAML="+(typeof window.YAML)},"*");})();<\/script>',
    // P3-D 新增: 与真 injectBridge 同源的 _TH 段(extract 自 chat_stage.html 逐字 eval 拼接)
    th:
      '<script>var _TH={};var _id=' + JSON.stringify(label) + ';'
      + P3D.js
      + 'for(var _k in _TH){if(_TH.hasOwnProperty(_k)){window[_k]=_TH[_k];}}'
      + 'parent.postMessage({testlog:true,text:"[patch3] _TH已挂窗: errorCatched="+(typeof window.errorCatched)+" waitGlobalInitialized="+(typeof window.waitGlobalInitialized)},"*");'
      + '<\/script>',
  };
}

function buildHost(label, renderedPath) {
  let rendered = fs.readFileSync(renderedPath, 'utf8');
  // 断外网变体: 仅重写 URL, 不动 JS 逻辑一行
  const before = rendered.length;
  rendered = rendered.replace(/https:\/\/fonts\.googleapis\.com/g, 'http://127.0.0.1:9/x')
    .replace(/https:\/\/free-img\.400040\.xyz/g, 'http://127.0.0.1:9/y');
  console.log(`${label}: URL重写 ${before}->${rendered.length} 字符`);
  const patch = makePatch(label);
  let injected;
  if (/<head>/i.test(rendered)) injected = rendered.replace(/<head>/i, '<head>' + patch.guard + patch.libs + patch.th);
  else injected = rendered + patch.guard + patch.libs + patch.th;
  fs.writeFileSync(path.join(OUT, `${label}_injected_doc.html`), injected, 'utf8');
  const b64 = Buffer.from(injected, 'utf8').toString('base64');
  const host = '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>T</title></head><body>'
    + '<div id="log">loading</div><iframe id="f" style="width:800px;height:600px"></iframe>'
    + '<script>var out=[];function L(t){out.push(t);document.getElementById("log").textContent=out.join("\\n");}'
    + 'window.addEventListener("message",function(e){if(e.data&&(e.data.testlog||e.data.__thLog))L("[iframe] "+e.data.text);});'
    + 'window.addEventListener("error",function(e){L("[host-onerror] "+(e.message||e.type));},true);'
    + 'var b64=' + JSON.stringify(b64) + ';'
    + 'var bin=atob(b64);var bytes=new Uint8Array(bin.length);for(var i=0;i<bin.length;i++)bytes[i]=bin.charCodeAt(i);'
    + 'var html=new TextDecoder("utf-8").decode(bytes);'
    + 'var f=document.getElementById("f");var blob=new Blob([html],{type:"text/html; charset=utf-8"});var url=URL.createObjectURL(blob);'
    + 'f.addEventListener("load",function(){L("[host] iframe load");'
    + 'setTimeout(function(){L("HARVEST_DONE");},6000);});'
    + 'f.src=url;<\/script></body></html>';
  fs.writeFileSync(path.join(OUT, `browser_harness_${label}.html`), host, 'utf8');
  console.log(`${label} harness 已写`);
}

buildHost('T5_noext', path.join(OUT, 'T5_chongsu_6_rendered.txt'));
buildHost('T2_noext', path.join(OUT, 'T2_marker_only_6_rendered.txt'));
