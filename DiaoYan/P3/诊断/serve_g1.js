// P3-F/G1: 本地静态服务器 —— 让 harness 跑在 http://127.0.0.1 上,
// blob iframe 继承同源 origin, 消除 SecurityError harness 伪影。
// 用法: node serve_g1.js [port]  (默认 8931), Ctrl+C 停止
const http = require('http');
const fs = require('fs');
const path = require('path');
const OUT = path.join(__dirname, 'out');
const port = parseInt(process.argv[2] || '8931', 10);
http.createServer((req, res) => {
  const name = decodeURIComponent(req.url.split('?')[0]).replace(/^\/+/, '');
  const f = path.join(OUT, name || 'index.html');
  if (!f.startsWith(OUT) || !fs.existsSync(f)) { res.writeHead(404); res.end('404 ' + name); return; }
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end(fs.readFileSync(f));
}).listen(port, '127.0.0.1', () => console.log('serving ' + OUT + ' at http://127.0.0.1:' + port));
