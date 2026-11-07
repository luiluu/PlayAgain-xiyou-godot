'use strict';
// 变速齿轮实测（battlefix2）：无头 Chrome 打开 serve.py 的只读服务（127.0.0.1:8766，冻结正式源），量原版真实秒数：
//  ① 主循环每真实秒的 updateScene 次数；② 地图事件「等待 60 帧」（Game_Interpreter 230）；③ 玩家走 10 格（移动路线，穿透，不奔跑）；
//  ④ 战斗夹具 4 人里第一位角色普通攻击：BattleManager.startAction → endAction。只建内存新局，不读写存档。
// 用法：python3 -I serve.py <app.nw> <输出目录> &  然后  node speed_gear_ref.cjs <输出.json>
const fs = require('fs'), os = require('os'), path = require('path'), {spawn} = require('child_process');
const outFile = path.resolve(process.argv[2] || 'speed_gear_ref.json');
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'xiyou-gear-'));
const dbg = 9300 + Math.floor(Math.random() * 500);
const chrome = spawn(CHROME, ['--headless=new', '--no-first-run', '--no-default-browser-check', '--mute-audio',
  '--remote-debugging-port=' + dbg, '--user-data-dir=' + profile, '--window-size=1280,720',
  '--use-angle=swiftshader', '--enable-unsafe-swiftshader', 'about:blank'], {stdio: 'ignore'});
const sleep = ms => new Promise(r => setTimeout(r, ms));

const PAGE = `(async function(){
  const sleep=ms=>new Promise(r=>setTimeout(r,ms));
  const until=async(f,ms=60000)=>{const t=performance.now();while(!f()){if(performance.now()-t>ms)throw new Error('超时 '+f+' '+JSON.stringify({dm:typeof DataManager,db:window.DataManager&&DataManager.isDatabaseLoaded(),scene:window.SceneManager&&SceneManager._scene&&SceneManager._scene.constructor.name,started:window.SceneManager&&SceneManager._scene&&SceneManager._scene.isActive(),gs:!!window.$gameSystem,err:(window.__refErrors||[]).slice(0,3)}));await sleep(20);}};
  await until(()=>window.DataManager&&DataManager.isDatabaseLoaded()&&window.$gameSystem&&SceneManager._scene&&!(SceneManager._scene instanceof Scene_Boot)&&SceneManager._scene.isActive(),120000);
  await sleep(2000);
  const out={scene:SceneManager._scene.constructor.name,deltaTime:SceneManager._deltaTime,gear:$gameSystem._drill_SG_speed};
  let n=0;const up=SceneManager.updateScene;
  const hooks=[];
  SceneManager.updateScene=function(){n++;up.apply(this,arguments);hooks.forEach(h=>h());};
  // ① 每秒 updateScene 次数（3 秒）
  let t0=performance.now(),n0=n;await sleep(3000);out.updatesPerSec=(n-n0)*1000/(performance.now()-t0);
  // ② 等待 60 帧
  const it=new Game_Interpreter();it.setup([{code:230,indent:0,parameters:[60]},{code:0,indent:0,parameters:[]}],0);
  const w={start:null,end:null,frames:0};
  hooks.push(()=>{if(w.end!==null)return;if(w.start===null)w.start=performance.now();it.update();w.frames++;if(!it.isRunning())w.end=performance.now();});
  await until(()=>w.end!==null);hooks.length=0;
  out.wait60={ms:w.end-w.start,updates:w.frames};
  // ③ 走 10 格：地图 5，(10,10) 起向右，穿透，不奔跑
  ConfigManager.alwaysDash=false;
  SceneManager.goto(Scene_Base);DataManager.setupNewGame();
  for(let i=1;i<5000;i++)$gameVariables._data[i]=0;
  Game_Map.prototype.updateInterpreter=function(){};
  $gameScreen.clear();$gameMessage.clear();
  DataManager.loadMapData(5);await until(()=>DataManager.isMapLoaded());
  $gameMap.setup(5);$gamePlayer.locate(10,10);$gamePlayer.setDirection(6);SceneManager.goto(Scene_Map);
  await until(()=>{if(SceneManager._scene instanceof Scene_Map)$gameMessage.clear();return SceneManager._scene instanceof Scene_Map&&SceneManager._scene.isActive()&&ImageManager.isReady();});
  SceneManager._scene.isBusy=function(){return false;};$gameMessage.clear();
  await sleep(500);
  $gamePlayer.setThrough(true);
  const list=[];for(let i=0;i<10;i++)list.push({code:3});list.push({code:0});
  const m={start:null,end:null,frames:0,x0:$gamePlayer.x};
  hooks.push(()=>{if(m.start===null||m.end!==null)return;m.frames++;if(!$gamePlayer.isMoveRouteForcing()&&!$gamePlayer.isMoving())m.end=performance.now();});
  m.start=performance.now();$gamePlayer.forceMoveRoute({list:list,repeat:false,skippable:true,wait:false});
  await until(()=>m.end!==null);hooks.length=0;
  out.move10={ms:m.end-m.start,updates:m.frames,tiles:$gamePlayer.x-m.x0,moveSpeed:$gamePlayer.realMoveSpeed(),distancePerFrame:$gamePlayer.distancePerFrame(),dashing:$gamePlayer.isDashing()};
  // ④ 战斗夹具普通攻击
  const btn=t=>[...document.querySelectorAll('button')].find(b=>b.textContent===t);
  btn('战斗夹具 4 人').click();
  window.__gearPartial=out;
  await until(()=>SceneManager._scene instanceof Scene_Battle&&SceneManager._scene._actorCommandWindow&&SceneManager._scene._actorCommandWindow.active,60000).catch(e=>{out.battleFail={phase:BattleManager._phase,msg:$gameMessage.isBusy(),texts:$gameMessage._texts,sub:BattleManager._subject&&BattleManager._subject.name(),actor:BattleManager.actor()&&BattleManager.actor().name(),busy:SceneManager._scene.isBusy&&SceneManager._scene.isBusy(),spr:SceneManager._scene._spriteset&&SceneManager._scene._spriteset.isBusy()};throw new Error(JSON.stringify(out));});
  await sleep(300);
  const actor=BattleManager.actor();const a={start:null,end:null,frames:0,speed:ConfigManager.battleAniSpeed,animation:ConfigManager.CombatSkillAnimation,actor:actor.actorId()};
  const sa=BattleManager.startAction,ea=BattleManager.endAction;
  BattleManager.startAction=function(){if(a.start===null&&this._subject===actor){a.start=performance.now();a.f0=n;}return sa.apply(this,arguments);};
  BattleManager.endAction=function(){if(a.start!==null&&a.end===null&&this._subject===actor){a.end=performance.now();a.frames=n-a.f0;}return ea.apply(this,arguments);};
  btn('测量普通攻击').click();
  await until(()=>a.end!==null,60000);
  out.attack={ms:a.end-a.start,updates:a.frames,speed:a.speed,animation:a.animation,actor:a.actor};
  out.errors=window.__refErrors||[];
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
  fs.writeFileSync(outFile, JSON.stringify(runs[0], null, 1) + '\n');
  console.log(JSON.stringify(runs[0]));
}

main().catch(e => { console.error(e); process.exitCode = 1; }).finally(() => {
  chrome.kill();
  setTimeout(() => fs.rmSync(profile, {recursive: true, force: true}), 1000);
});
