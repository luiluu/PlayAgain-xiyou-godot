'use strict';
// 战斗节奏逐帧（rules-pace1）：无头 Chrome 打开 serve.py 的只读服务（127.0.0.1:8766，冻结正式源），战斗夹具 4 人、敌群 2，
// 角色指令窗一出就普通攻击敌人 1（同 battle_pace_oracle）。记每次 makeActionOrders 前后各人的 agi／speed／行动、
// startAction／endAction 的 updateScene 帧、行动序列逐条（帧、行动者、指令名）、对战斗者放的动画；frames／calls（ui-pace2）
// 逐帧记 BattleManager 阶段、日志窗等待与方法队列、各种 isBusy，以及本帧调到的 BattleManager 方法。只建内存新局，不读写存档。
// 用法：python3 -I serve.py <app.nw> <输出目录> &  然后  node battle_pace_ref.cjs <输出.json>
const fs = require('fs'), os = require('os'), path = require('path'), {spawn} = require('child_process');
const outFile = path.resolve(process.argv[2] || 'gb9_ref.json');
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'xiyou-gb9-'));
const dbg = 9300 + Math.floor(Math.random() * 500);
const chrome = spawn(CHROME, ['--headless=new', '--no-first-run', '--no-default-browser-check', '--mute-audio',
  '--remote-debugging-port=' + dbg, '--user-data-dir=' + profile, '--window-size=1280,720',
  '--use-angle=swiftshader', '--enable-unsafe-swiftshader', 'about:blank'], {stdio: 'ignore'});
const sleep = ms => new Promise(r => setTimeout(r, ms));

const PAGE = `(async function(){
  const sleep=ms=>new Promise(r=>setTimeout(r,ms));
  const until=async(f,ms=60000)=>{const t=performance.now();while(!f()){if(performance.now()-t>ms)throw new Error('超时 '+f);await sleep(20);}};
  await until(()=>window.DataManager&&DataManager.isDatabaseLoaded()&&window.$gameSystem&&SceneManager._scene&&!(SceneManager._scene instanceof Scene_Boot)&&SceneManager._scene.isActive(),120000);
  await sleep(1500);
  const btn=t=>[...document.querySelectorAll('button')].find(b=>b.textContent===t);
  btn('战斗夹具 4 人').click();
  await until(()=>SceneManager._scene instanceof Scene_Battle&&SceneManager._scene._actorCommandWindow&&SceneManager._scene._actorCommandWindow.active,60000);
  let n=0;const out={frames:[],shots:{},order:null};
  let interp=null,mark=0,want={};
  const up=SceneManager.updateScene;
  SceneManager.updateScene=function(){n++;up.apply(this,arguments);const s=SceneManager._scene;if(!(s instanceof Scene_Battle))return;
    if(interp){interp.update();const ss=s._spriteset,mw=s._messageWindow;
      out.frames.push([n-mark,interp._index,+$gameScreen.brightness().toFixed(4),+ss._fadeSprite.opacity.toFixed(4),+$gameScreen.flashColor()[3].toFixed(4),+ss._flashSprite.opacity.toFixed(4),$gameMessage.isBusy()?1:0,mw.openness]);
      const k=n-mark; if(want[k]){out.shots[want[k]]=k;__refShot(want[k]);}
    }};
  const frames=async m=>{const t=n+m;await until(()=>n>=t,60000);};
  await frames(30);
  __refShot('gb9_input');
  // 层次：场景 children 次序（spriteset、hudField、Star_Record、windowLayer）与 spriteset 里 baseSprite／图片／闪烁／黑幕
  const s=SceneManager._scene,ss=s._spriteset;
  out.order={scene:s.children.map(c=>c===ss?'spriteset':c===s._windowLayer?'windowLayer':c===s._hudField?'hudField':(c.constructor&&c.constructor.name)),
    spriteset:ss.children.map(c=>c===ss._baseSprite?'base':c===ss._pictureContainer?'pictures':c===ss._timerSprite?'timer':c===ss._flashSprite?'flash':c===ss._fadeSprite?'fade':(c.constructor&&c.constructor.name))};
  // 221 → 101（敌群 825 第 30 回合的第一句，位置 1 中间）→ 222
  const list=[{code:221,indent:0,parameters:[]},{code:101,indent:0,parameters:['',0,0,1,'']},{code:401,indent:0,parameters:['天空中的圣雷积攒到了极限']},{code:222,indent:0,parameters:[]},
    {code:224,indent:0,parameters:[[255,0,0,170],30,false]},{code:230,indent:0,parameters:[40]},{code:0,indent:0,parameters:[]}];
  want={12:'gb9_fade_f12',24:'gb9_fade_f24'};
  interp=new Game_Interpreter();interp.setup(list,0);mark=n;
  await frames(110);
  const mw0=s._messageWindow;out.mw={open:mw0.openness,pause:mw0.pause,text:!!mw0._textState,busy:$gameMessage.isBusy(),vis:mw0.visible,y:mw0.y,idx:interp._index,wait:interp._waitCount,mode:interp._waitMode};
  __refShot('gb9_fade_message');out.shots.gb9_fade_message=n-mark;
  const t0=n-mark;
  s._messageWindow.terminateMessage();
  await until(()=>interp._index>=4||n-mark>600,60000);
  const k=n-mark; want[k+5]='gb9_flash_f5'; want[k+15]='gb9_flash_f15';
  await until(()=>!interp.isRunning()||n-mark>900,60000);
  out.msgClosed=t0;out.n=n;out.errors=window.__refErrors||[];
  return out;
})()`;
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
  let id = 0; const wait = new Map();
  ws.onmessage = m => { const d = JSON.parse(m.data); if (d.id && wait.has(d.id)) { wait.get(d.id)(d); wait.delete(d.id); } };
  const send = (method, params = {}) => new Promise(ok => { const n = ++id; wait.set(n, ok); ws.send(JSON.stringify({id: n, method, params})); });
  await send('Runtime.enable');
  await send('Emulation.setDeviceMetricsOverride', {width: 1280, height: 720, deviceScaleFactor: 1, mobile: false});
  await send('Page.enable');
  await send('Page.navigate', {url: 'http://127.0.0.1:8766/index.html?battle_ref=1'});
  await sleep(3000);
  const runs = [];
  const r = await send('Runtime.evaluate', {expression: PAGE, awaitPromise: true, returnByValue: true, timeout: 600000});
  if (r.result.exceptionDetails) throw new Error(JSON.stringify(r.result.exceptionDetails).slice(0, 3000));
  runs.push(r.result.result.value);
  fs.writeFileSync(outFile, JSON.stringify(runs[0]) + '\n');
  console.log('ok', outFile);
}

main().catch(e => { console.error(e); process.exitCode = 1; }).finally(() => {
  chrome.kill();
  setTimeout(() => fs.rmSync(profile, {recursive: true, force: true}), 1000);
});
