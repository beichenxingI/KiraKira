// 端到端浏览器验证: 用管线真实输出(rendered) + 等效 injectBridge + 真实 jquery/lodash/yaml 库
// 在 Edge headless 中加载 blob iframe, 收集 iframe 内错误/日志
// 产物: DiaoYan/P3/诊断/out/browser_harness_T5.html 与 ..._T2.html
const fs = require('fs');
const path = require('path');
const OUT = path.join(__dirname, 'out');

const libs = {
  jquery: fs.readFileSync('assets/libs/jquery.min.js', 'utf8'),
  lodash: fs.readFileSync('assets/libs/lodash.min.js', 'utf8'),
  toastr: fs.readFileSync('assets/libs/toastr.min.js', 'utf8'),
  yaml: fs.readFileSync('assets/libs/yaml.min.js', 'utf8'),
};
const toastrCss = fs.readFileSync('assets/libs/toastr.min.css', 'utf8');

// 等效 injectBridge 的最小 patch(库 + 错误捕手 + DOMContentLoaded patch + localStorage polyfill)
function makePatch() {
  const esc = (s) => s.replace(/<\/script>/gi, '<\\/script>');
  return {
    guard: '<script>(function(){'
      + 'window.onerror=function(m,s,l,c){parent.postMessage({testlog:true,text:"CARD-ERR: "+m+" @"+l+":"+c},"*");return false;};'
      + 'window.addEventListener("unhandledrejection",function(ev){parent.postMessage({testlog:true,text:"CARD-ERR(rejection): "+(ev.reason&&ev.reason.message||ev.reason)},"*");});'
      + 'var _s={};try{localStorage.getItem("__t");}catch(e){Object.defineProperty(window,"localStorage",{configurable:true,value:{getItem:function(k){return _s[k]||null;},setItem:function(k,v){_s[k]=String(v);},removeItem:function(k){delete _s[k];},clear:function(){_s={};},key:function(i){return Object.keys(_s)[i]||null;},get length(){return Object.keys(_s).length;}}});}'
      + 'var _oa=document.addEventListener.bind(document);document.addEventListener=function(t,f,o){if(t==="DOMContentLoaded"&&document.readyState!=="loading"){setTimeout(f,0);}else{_oa(t,f,o);}};'
      + '})();<\/script>',
    libs:
      '<script>' + esc(libs.jquery) + '<\/script>'
      + '<script>' + esc(libs.lodash) + '<\/script>'
      + '<style>' + toastrCss + '<\/style>'
      + '<script>' + esc(libs.toastr) + '<\/script>'
      + '<script>' + esc(libs.yaml) + '<\/script>',
  };
}

function buildHostHtml(label, renderedPath) {
  const rendered = fs.readFileSync(renderedPath, 'utf8');
  const patch = makePatch();
  // 等效 injectBridge 的 patch 注入位(chat_stage.html:777-780)
  let injected;
  if (/<head>/i.test(rendered)) injected = rendered.replace(/<head>/i, '<head>' + patch.guard + patch.libs);
  else if (/<html/i.test(rendered)) injected = rendered.replace(/<html[^>]*>/i, (m) => m + patch.guard + patch.libs);
  else injected = rendered + patch.guard + patch.libs;
  fs.writeFileSync(path.join(OUT, `${label}_injected_doc.html`), injected, 'utf8');
  const b64 = Buffer.from(injected, 'utf8').toString('base64');
  const host = '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>T</title></head><body>'
    + '<div id="log"></div><iframe id="f" style="width:800px;height:600px"></iframe>'
    + '<script>'
    + 'var out=[];function L(t){out.push(t);document.getElementById("log").textContent=out.join("\n");}'
    + 'window.addEventListener("message",function(e){if(e.data&&e.data.testlog)L("[iframe] "+e.data.text);});'
    + 'var b64=' + JSON.stringify(b64) + ';'
    + 'var bin=atob(b64);var bytes=new Uint8Array(bin.length);for(var i=0;i<bin.length;i++)bytes[i]=bin.charCodeAt(i);'
    + 'var html=new TextDecoder("utf-8").decode(bytes);'
    + 'var f=document.getElementById("f");'
    + 'var blob=new Blob([html],{type:"text/html; charset=utf-8"});var url=URL.createObjectURL(blob);f.src=url;'
    + 'f.addEventListener("load",function(){L("[host] load");setTimeout(function(){'
    + 'L("[host] 总结: 卡片 window.switchTab 存在性(跨域无法直读,改探 DOM click 可行性略)");'
    + 'document.title="HARVEST";'
    + '},4000);});'
    + '<\/script></body></html>';
  return host;
}

const t5 = buildHostHtml('T5_rendered', path.join(OUT, 'T5_chongsu_6_rendered.txt'));
fs.writeFileSync(path.join(OUT, 'browser_harness_T5.html'), t5, 'utf8');
const t2 = buildHostHtml('T2_rendered', path.join(OUT, 'T2_marker_only_6_rendered.txt'));
fs.writeFileSync(path.join(OUT, 'browser_harness_T2.html'), t2, 'utf8');
console.log('harness 已生成:');
console.log('  out/browser_harness_T5.html (regex_7 开局界面 rendered)');
console.log('  out/browser_harness_T2.html (regex_6 状态栏 rendered)');
