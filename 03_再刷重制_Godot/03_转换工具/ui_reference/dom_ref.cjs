'use strict';
// DOM 取数驱动（界面 DE 2026-11-06，换源重取 gear_search／power_panel 等 DOM 面板参照用）：
// 起只读服务（serve.py 守卫：拒绝存档路径与写请求），本机 Google Chrome 无头（临时用户目录、1280×720、静音）打开
// index.html?battle_ref=1，等标题就绪后在页面里执行一个取数脚本（脚本是一个 async 函数表达式，参数为 --arg 给的 JSON），
// 返回值（JSON）由本驱动写到输出文件。页面只改自己内存（及临时 Chrome 目录的 localStorage），不碰正式源与玩家存档。
// 用法：node dom_ref.cjs <app.nw> <页面脚本.js> <输出.json> [--arg=参数.json] [--port=8771] [--timeout=秒]
//   例：node dom_ref.cjs …/冻结正式源/v0.62.12/app.nw gear_search_ref.js /tmp/x/gear_search_oracle.json --arg=…/gear_search_oracle.json
const fs = require('fs'), os = require('os'), path = require('path'), {spawn} = require('child_process');
const pos = process.argv.slice(2).filter(a => !a.startsWith('--'));
const opt = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').slice(n.length + 3);
const [app, script, out] = pos;
if (!out) { console.error('用法：node dom_ref.cjs <app.nw> <页面脚本.js> <输出.json> [--arg=参数.json] [--port=8771]'); process.exit(64); }
const port = Number(opt('port') || 8771), timeout = Number(opt('timeout') || 900) * 1000;
const arg = opt('arg') ? JSON.parse(fs.readFileSync(opt('arg'), 'utf8')) : null;
const body = fs.readFileSync(script, 'utf8');
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const shots = fs.mkdtempSync(path.join(os.tmpdir(), 'xiyou-domref-out-'));
const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'xiyou-domref-'));
const server = spawn('python3', ['-I', '-c', `import sys,functools,http.server;sys.path.insert(0,${JSON.stringify(__dirname)});import serve;serve.SHOTS=${JSON.stringify(shots)}
http.server.ThreadingHTTPServer.request_queue_size=256;http.server.ThreadingHTTPServer(('127.0.0.1',${port}),functools.partial(serve.H,directory=${JSON.stringify(path.resolve(app))})).serve_forever()`], {stdio: 'inherit'});
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
  const evaluate = async (expr, awaitPromise = false) => {
    const r = await send('Runtime.evaluate', {expression: expr, returnByValue: true, awaitPromise, timeout});
    if (r.result && r.result.exceptionDetails) throw new Error('页面脚本出错：' + JSON.stringify(r.result.exceptionDetails).slice(0, 3000));
    return r.result && r.result.result && r.result.result.value;
  };
  await send('Runtime.enable');
  await send('Emulation.setDeviceMetricsOverride', {width: 1280, height: 720, deviceScaleFactor: 1, mobile: false});
  for (let i = 0; i < 50; i++) { try { await fetch(`http://127.0.0.1:${port}/index.html`); break; } catch (e) { await sleep(200); } }
  await send('Page.navigate', {url: `http://127.0.0.1:${port}/index.html?battle_ref=1`});
  const ready = `!!(window.__dhRef && window.DataManager && DataManager.isDatabaseLoaded() && window.SceneManager && SceneManager._scene instanceof Scene_Title)`;
  for (let i = 0; i < 240 && !(await evaluate(ready)); i++) await sleep(500);
  if (!(await evaluate(ready))) throw new Error('标题未就绪');
  const json = await evaluate(`(${body})(${JSON.stringify(arg)}).then(r => JSON.stringify(Object.assign(r, {errors: (r.errors || []).concat(window.__refErrors || [])})))`, true);
  if (typeof json !== 'string') throw new Error('页面脚本没有返回读数');
  const r = JSON.parse(json);
  fs.mkdirSync(path.dirname(path.resolve(out)), {recursive: true});
  fs.writeFileSync(out, JSON.stringify(r) + '\n');
  console.log('ok', out, 'errors', r.errors.length);
  ws.close();
}

main().catch(e => { console.error(e.stack || e); process.exitCode = 1; }).finally(() => {
  chrome.kill('SIGTERM'); server.kill('SIGTERM');
  setTimeout(() => { fs.rmSync(profile, {recursive: true, force: true}); fs.rmSync(shots, {recursive: true, force: true}); process.exit(); }, 500);
});
