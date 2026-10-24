'use strict';
// 系统页成对截图驱动（八戒_63）：无头 Chrome（临时用户目录，1280×720）打开 review_system_pages.py 的只读服务，
// 逐页 await __sysRef.run(页名) 后整页截图（含异化工坊的 DOM 叠加层），读数写 <页名>.json。只写输出目录。
// 用法：node review_system_pages.cjs <输出目录> [页名…]（默认全部）；服务须已在 --port（默认 8769）上运行。
const fs = require('fs'), os = require('os'), path = require('path'), {spawn} = require('child_process');
const out = path.resolve(process.argv[2] || '.');
const only = process.argv.slice(3).filter(a => !a.startsWith('--'));
const port = Number((process.argv.find(a => a.startsWith('--port=')) || '--port=8769').slice(7));
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'xiyou-sysref-'));
const dbg = 9300 + Math.floor(Math.random() * 500);
const chrome = spawn(CHROME, ['--headless=new', '--no-first-run', '--no-default-browser-check', '--mute-audio',
  '--remote-debugging-port=' + dbg, '--user-data-dir=' + profile, '--window-size=1280,720',
  '--use-angle=swiftshader', '--enable-unsafe-swiftshader', 'about:blank'], {stdio: 'ignore'});
const sleep = ms => new Promise(r => setTimeout(r, ms));

async function connect() {
  for (let i = 0; i < 100; i++) {
    try {
      const list = await (await fetch(`http://127.0.0.1:${dbg}/json/list`)).json();
      const page = list.find(t => t.type === 'page');
      if (page) return page.webSocketDebuggerUrl;
    } catch (e) { /* 等 Chrome 起来 */ }
    await sleep(200);
  }
  throw new Error('Chrome 调试端口未就绪');
}

async function main() {
  const ws = new WebSocket(await connect());
  await new Promise((ok, ng) => { ws.onopen = ok; ws.onerror = ng; });
  let id = 0; const wait = new Map(); const logs = [];
  ws.onmessage = m => {
    const d = JSON.parse(m.data);
    if (d.id && wait.has(d.id)) { wait.get(d.id)(d); wait.delete(d.id); }
    if (d.method === 'Runtime.exceptionThrown') logs.push('exception ' + JSON.stringify(d.params.exceptionDetails).slice(0, 2000));
    if (d.method === 'Runtime.consoleAPICalled' && d.params.type === 'error') logs.push('console ' + JSON.stringify(d.params.args).slice(0, 2000));
  };
  const send = (method, params = {}) => new Promise(ok => { const n = ++id; wait.set(n, ok); ws.send(JSON.stringify({id: n, method, params})); });
  const evaluate = async (expr, timeout = 180000) => {
    const r = await send('Runtime.evaluate', {expression: expr, awaitPromise: true, returnByValue: true, timeout});
    if (r.result.exceptionDetails) throw new Error(JSON.stringify(r.result.exceptionDetails).slice(0, 3000));
    return r.result.result.value;
  };
  await send('Runtime.enable');
  await send('Emulation.setDeviceMetricsOverride', {width: 1280, height: 720, deviceScaleFactor: 1, mobile: false});
  await send('Page.enable');
  await send('Page.navigate', {url: `http://127.0.0.1:${port}/index.html?item_list_ref=1&sys_review=1`});
  for (let i = 0; i < 600; i++) {
    await sleep(500);
    try { if (await evaluate('!!(window.__sysRef && __sysRef.ready())', 5000)) break; } catch (e) { /* 页面加载中 */ }
  }
  const pages = await evaluate('__sysRef.pages()');
  const result = {pages: {}, logs};
  for (const name of pages) {
    if (only.length && !only.includes(name)) continue;
    const shots = await evaluate(`__sysRef.run(${JSON.stringify(name)})`);
    for (const shot of shots) {
      await evaluate(`__sysRef.show(${JSON.stringify(name)}, ${JSON.stringify(shot)})`);
      await sleep(300);
      const png = await send('Page.captureScreenshot', {format: 'png', clip: {x: 0, y: 0, width: 1280, height: 720, scale: 1}});
      fs.writeFileSync(path.join(out, shot + '.png'), Buffer.from(png.result.data, 'base64'));
      const data = await evaluate(`__sysRef.readout(${JSON.stringify(name)}, ${JSON.stringify(shot)})`);
      fs.writeFileSync(path.join(out, shot + '.json'), JSON.stringify(data, null, 1) + '\n');
      result.pages[shot] = {errors: data.errors || []};
      console.log(shot, (data.errors || []).length ? 'errors ' + data.errors.length : 'ok');
    }
  }
  result.errors = await evaluate('window.__refErrors || []');
  fs.writeFileSync(path.join(out, 'run.json'), JSON.stringify(result, null, 1) + '\n');
  ws.close();
}

main().catch(e => { console.error(e.stack || e); process.exitCode = 1; }).finally(() => {
  chrome.kill('SIGTERM');
  setTimeout(() => fs.rmSync(profile, {recursive: true, force: true}), 500);
});
