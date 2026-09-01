const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..', '..');
function read(rel) { return fs.readFileSync(path.join(root, rel), 'utf8'); }
function extractScripts(html) {
  return [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)].map((m) => m[1]);
}
function decodeDartLiteral(value) {
  return value.replace(/\\\\'/g, "'").replace(/\\\\"/g, '"').replace(/\\\\n/g, '\n').replace(/\\\\\\\\/g, '\\');
}
function extractFacade() {
  const source = read('lib/presentation/screens/chat/tavern_helper_facade.dart');
  const start = source.indexOf('String buildTavernHelperFacadeJs');
  const end = source.indexOf('\n  }', start);
  const body = source.slice(start, end < 0 ? source.length : end);
  const parts = [];
  for (const line of body.split(/\r?\n/)) {
    if (/^\s*\/\//.test(line)) continue;
    const match = line.match(/^\s*(?:return\s+)?'((?:\\\\.|[^'])*)'/);
    if (!match) continue;
    try { parts.push(decodeDartLiteral(match[1])); } catch (_) {}
  }
  let js = parts.join('');
  js = js.replace(/\$\{jsonEncode\(frameId\)\}/g, '"harness"')
    .replace(/\$\{jsonEncode\(mvu\.updateMode\)\}/g, '"随AI输出"')
    .replace(/\$\{jsonEncode\(mvu\.jailbreakScheme\)\}/g, '"使用内置破限"')
    .replace(/\$\{jsonEncode\(mvu\.modelSource\)\}/g, '"自定义"')
    .replace(/\$\{jsonEncode\(mvu\.apiUrl\)\}/g, '""')
    .replace(/\$\{jsonEncode\(mvu\.apiKey\)\}/g, '""')
    .replace(/\$\{jsonEncode\(mvu\.modelName\)\}/g, '""')
    .replace(/\$\{mvu\.autoRequest\}/g, 'false')
    .replace(/\$\{mvu\.maxChatHistory\}/g, '20');
  return js;
}
function extractChatStageScripts() { return extractScripts(read('assets/chat/chat_stage.html')); }
module.exports = { root, read, extractScripts, extractFacade, extractChatStageScripts };
