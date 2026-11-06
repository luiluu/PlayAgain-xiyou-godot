'use strict';
// 无头点按钮驱动（CV 2026-11-06，换源重取原版参照用）：只有页面按钮、没有无头驱动的取数夹具（如 review_actor_book.js「重放人物图鉴」），
// 用本机 Google Chrome 无头（临时用户目录、1280×720、静音）打开对应只读服务的页面，等按钮出现后点它，再等输出目录里出现读数文件。
// 用法：node headless_button.cjs <端口> <查询串> <按钮文字> <输出目录> <成功文件名> [失败文件名] [--timeout=秒]
//   例：python3 -I review_actor_book.py <app.nw> <目录> &  然后
//       node headless_button.cjs 8767 'actor_book_review=1' 重放人物图鉴 <目录> actor_book_replay.json actor_book_failure.json
// 只读：不写输出目录以外的文件（读数由服务的 POST /__ref_json 写）。
const fs = require('fs'), os = require('os'), path = require('path'), {spawn} = require('child_process');
const [port, query, label, outDir, okName, failName] = process.argv.slice(2).filter(a => !a.startsWith('--'));
const timeout = Number((process.argv.find(a => a.startsWith('--timeout=')) || '--timeout=900').slice(10)) * 1000;
if (!okName) { console.error('用法：node headless_button.cjs <端口> <查询串> <按钮文字> <输出目录> <成功文件名> [失败文件名]'); process.exit(64); }
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'xiyou-btnref-'));
const dbg = 9800 + Math.floor(Math.random() * 150);
const chrome = spawn(CHROME, ['--headless=new', '--no-first-run', '--no-default-browser-check', '--mute-audio',
  '--remote-debugging-port=' + dbg, '--user-data-dir=' + profile, '--window-size=1280,720',
  '--use-angle=swiftshader', '--enable-unsafe-swiftshader', 'about:blank'], {stdio: 'ignore'});
const sleep = ms => new Promise(r => setTimeout(r, ms));

async function main() {
  let wsUrl;
  for (let i = 0; i < 100 && !wsUrl; i++) {
    try { const page = (await (await fetch(`http://127.0.0.1:${dbg}/json/list`)).json()).find(t => t.type === 'page'); if (page) wsUrl = page.webSocketDebuggerUrl; } catch (e) { /* 等 Chrome */ }
    if (!wsUrl) await sleep(200);
  }
  if (!wsUrl) throw new Error('Chrome 调试端口未就绪');
  const ws = new WebSocket(wsUrl);
  await new Promise((ok, ng) => { ws.onopen = ok; ws.onerror = ng; });
  let id = 0; const wait = new Map();
  ws.onmessage = m => { const d = JSON.parse(m.data); if (d.id && wait.has(d.id)) { wait.get(d.id)(d); wait.delete(d.id); } };
  const send = (method, params = {}) => new Promise(ok => { const n = ++id; wait.set(n, ok); ws.send(JSON.stringify({id: n, method, params})); });
  const evaluate = async expr => (await send('Runtime.evaluate', {expression: expr, returnByValue: true})).result.result?.value;
  await send('Runtime.enable');
  await send('Emulation.setDeviceMetricsOverride', {width: 1280, height: 720, deviceScaleFactor: 1, mobile: false});
  await send('Page.navigate', {url: `http://127.0.0.1:${port}/index.html?${query}`});
  const find = `Array.from(document.querySelectorAll('button')).find(b => b.textContent === ${JSON.stringify(label)})`;
  for (let i = 0; i < 240 && !(await evaluate(`!!(${find})`)); i++) await sleep(500);
  if (!(await evaluate(`!!(${find})`))) throw new Error('按钮没出现：' + label);
  await evaluate(`${find}.click(), true`);
  const start = Date.now();
  while (Date.now() - start < timeout) {
    if (fs.existsSync(path.join(outDir, okName))) { console.log('ok', okName, await evaluate(`(${find} || {}).textContent`)); ws.close(); return; }
    if (failName && fs.existsSync(path.join(outDir, failName))) throw new Error('页面报失败：' + fs.readFileSync(path.join(outDir, failName), 'utf8').slice(0, 2000));
    await sleep(1000);
  }
  throw new Error('等读数超时');
}

main().catch(e => { console.error(e.stack || e); process.exitCode = 1; }).finally(() => {
  chrome.kill('SIGTERM');
  setTimeout(() => fs.rmSync(profile, {recursive: true, force: true}), 500);
});
