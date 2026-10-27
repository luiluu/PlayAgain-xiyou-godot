'use strict';
// 权能遗忘四页：隔离 Chrome 新局、真实物品入口和选择窗。服务与截图都仅本车道输出。
// node review_power_books.cjs <输出目录> [--port=8777]
const fs = require('fs'), os = require('os'), path = require('path'), {spawn} = require('child_process');
const out = path.resolve(process.argv[2] || '.');
const port = Number((process.argv.find(a => a.startsWith('--port=')) || '--port=8777').slice(7));
fs.mkdirSync(out,{recursive:true});
const source=path.resolve(__dirname,'../../02_内容与素材/冻结正式源/app.nw');
const server=spawn('python3',['-u',path.join(__dirname,'review_power_books.py'),source,out,'--port',String(port)],{stdio:['ignore','inherit','inherit']});
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
    try { if (await evaluate('!!(window.__powerRef && __powerRef.ready())', 5000)) break; } catch (e) { /* 页面加载中 */ }
  }
  if(!await evaluate('!!(window.__powerRef && __powerRef.ready())'))throw Error('native page not ready');
  await evaluate('__powerRef.setup()');
  const steps=[['power_0_actors',null],['power_1_skills',0],['power_2_confirm',0],['power_3_result',0]];
  const result={pages:{},logs};
  for(const [name,index] of steps){
    if(index!==null)await evaluate(`__powerRef.pick(${index})`);
    const data=await evaluate('__powerRef.read()');
    fs.writeFileSync(path.join(out,name+'.json'),JSON.stringify(data,null,1)+'\n');
    const png=await send('Page.captureScreenshot',{format:'png',clip:{x:0,y:0,width:1280,height:720,scale:1}});
    fs.writeFileSync(path.join(out,name+'.png'),Buffer.from(png.result.data,'base64'));
    result.pages[name]={errors:data.errors};console.log(name,'ok');
  }
  result.errors=await evaluate('window.__refErrors || []');
  fs.writeFileSync(path.join(out,'run.json'),JSON.stringify(result,null,1)+'\n');
  if(logs.length||result.errors.length||Object.values(result.pages).some(x=>x.errors.length))throw Error('native runtime errors');
  ws.close();
}

main().catch(e => { console.error(e.stack || e); process.exitCode = 1; }).finally(() => {
  chrome.kill('SIGTERM');
  server.kill('SIGTERM');
  setTimeout(() => fs.rmSync(profile, {recursive: true, force: true}), 500);
});
